// Teensy 4.1 + AK60-6 non-blocking data logger
// Safe: logging decoupled from control loop via ring buffer
#include <FlexCAN_T4.h>
#include <SD.h>
#include <TimeLib.h>

FlexCAN_T4<CAN1, RX_SIZE_256, TX_SIZE_16> can1;

// --- Motor Limits (AK60-6 datasheet) ---
const float MAX_TORQUE = 6.0f;          // Nm continuous
const float MAX_VELOCITY = 38.2f;       // rad/s
const float MAX_POSITION = 12.5f;       // rad
const uint8_t MOTOR_ID = 0x01;

// --- Control ---
const float KP = 35.0f;     // Nm/rad
const float KD = 1.8f;      // Nm*s/rad
const float DT = 0.0005f;   // 2kHz (500us)
const float TORQUE_RAMP_RATE = 12.0f;  // Nm/s

// --- Watchdog ---
const unsigned long WATCHDOG_TIMEOUT_US = 100000;  // 100ms

// --- E-Stop ---
const int ESTOP_PIN = 2;

// --- Ring Buffer for Non-blocking Logging ---
struct LogEntry {
    unsigned long timestamp_us;
    float position;    // rad
    float velocity;    // rad/s
    float torque_cmd;  // Nm
};

const int LOG_BUFFER_SIZE = 256;
volatile LogEntry log_buffer[LOG_BUFFER_SIZE];
volatile int log_head = 0;
volatile int log_tail = 0;

// --- State ---
enum State { IDLE, RUNNING, E_STOP, ERROR };
volatile State state = IDLE;
float desired_pos = 0.0f;      // rad
float prev_torque = 0.0f;
unsigned long last_cmd_time = 0;

File logFile;
bool sd_ready = false;

// --- E-Stop ISR ---
void estop_isr() {
    state = E_STOP;
    send_zero_torque(MOTOR_ID);
    disable_motor(MOTOR_ID);
}

// --- Rate Limiter ---
float rate_limit(float target, float prev, float max_rate, float dt) {
    float max_delta = max_rate * dt;
    float delta = constrain(target - prev, -max_delta, max_delta);
    return prev + delta;
}

void setup() {
    can1.begin();
    can1.setBaudRate(1000000);
    Serial.begin(115200);

    // E-Stop hardware interrupt
    pinMode(ESTOP_PIN, INPUT_PULLUP);
    attachInterrupt(digitalPinToInterrupt(ESTOP_PIN), estop_isr, FALLING);

    // SD card init (non-critical — logging optional)
    if (SD.begin(BUILTIN_SDCARD)) {
        // Generate unique filename with date
        char filename[32];
        snprintf(filename, sizeof(filename), "log_%04d%02d%02d_%02d%02d.csv",
                 year(), month(), day(), hour(), minute());
        logFile = SD.open(filename, FILE_WRITE);
        if (logFile) {
            logFile.println("timestamp_us,position_rad,velocity_rad_s,torque_cmd_Nm");
            sd_ready = true;
        }
    }
}

// --- Enqueue log entry (called from control loop, non-blocking) ---
void enqueue_log(unsigned long t, float pos, float vel, float torque) {
    int next_head = (log_head + 1) % LOG_BUFFER_SIZE;
    if (next_head == log_tail) return;  // Buffer full, drop entry (safe)
    log_buffer[log_head] = {t, pos, vel, torque};
    log_head = next_head;
}

// --- Flush log buffer to SD (called from non-RT context) ---
void flush_log_buffer() {
    if (!sd_ready) return;

    int count = 0;
    while (log_tail != log_head && count < 32) {
        LogEntry entry = log_buffer[log_tail];
        logFile.print(entry.timestamp_us);
        logFile.print(",");
        logFile.print(entry.position, 4);
        logFile.print(",");
        logFile.print(entry.velocity, 4);
        logFile.print(",");
        logFile.println(entry.torque_cmd, 4);
        log_tail = (log_tail + 1) % LOG_BUFFER_SIZE;
        count++;
    }

    // Periodic flush (not every iteration)
    static unsigned long last_flush = 0;
    if (millis() - last_flush > 1000) {
        logFile.flush();
        last_flush = millis();
    }
}

void loop() {
    unsigned long now = micros();

    switch (state) {
        case IDLE: {
            if (Serial.available()) {
                char c = Serial.read();
                if (c == 's') {
                    enable_motor(MOTOR_ID);
                    last_cmd_time = now;
                    prev_torque = 0.0f;
                    state = RUNNING;
                }
            }
            flush_log_buffer();
            break;
        }

        case RUNNING: {
            // Watchdog
            if (now - last_cmd_time > WATCHDOG_TIMEOUT_US) {
                send_zero_torque(MOTOR_ID);
                state = E_STOP;
                break;
            }

            // Read target (non-blocking)
            if (Serial.available() >= 4) {
                byte buf[4];
                Serial.readBytes(buf, 4);
                float new_target;
                memcpy(&new_target, buf, 4);
                if (!isnan(new_target) && abs(new_target) <= MAX_POSITION) {
                    desired_pos = new_target;
                    last_cmd_time = now;
                }
            }

            // Read feedback with validation
            float pos = read_motor_position(MOTOR_ID);
            float vel = read_motor_velocity(MOTOR_ID);
            if (isnan(pos) || isnan(vel) || abs(pos) > MAX_POSITION * 1.1f) {
                send_zero_torque(MOTOR_ID);
                state = ERROR;
                break;
            }

            // Compute + clamp + rate limit
            float torque = KP * (desired_pos - pos) - KD * vel;
            torque = constrain(torque, -MAX_TORQUE, MAX_TORQUE);
            torque = rate_limit(torque, prev_torque, TORQUE_RAMP_RATE, DT);
            prev_torque = torque;

            send_torque(MOTOR_ID, torque);

            // Non-blocking log enqueue
            enqueue_log(now, pos, vel, torque);
            break;
        }

        case E_STOP: {
            send_zero_torque(MOTOR_ID);
            disable_motor(MOTOR_ID);
            flush_log_buffer();
            if (Serial.available()) {
                char c = Serial.read();
                if (c == 'r') {
                    prev_torque = 0.0f;
                    state = IDLE;
                }
            }
            break;
        }

        case ERROR: {
            send_zero_torque(MOTOR_ID);
            disable_motor(MOTOR_ID);
            flush_log_buffer();
            if (Serial.available()) {
                char c = Serial.read();
                if (c == 'r') {
                    prev_torque = 0.0f;
                    state = IDLE;
                }
            }
            break;
        }
    }

    delayMicroseconds(500);  // 2kHz control loop
}
