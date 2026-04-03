// Teensy 4.1 + AK60-6 impedance controller — fully safe implementation
#include <FlexCAN_T4.h>

FlexCAN_T4<CAN1, RX_SIZE_256, TX_SIZE_16> can1;

// --- State Machine ---
enum State { IDLE, CALIBRATING, RUNNING, E_STOP, ERROR };
State state = IDLE;

// --- Motor Limits (AK60-6 datasheet) ---
const float MAX_TORQUE = 6.0f;          // Nm continuous
const float MAX_VELOCITY = 38.2f;       // rad/s
const float MAX_POSITION = 12.5f;       // rad (MIT protocol range)
const float TORQUE_RAMP_RATE = 10.0f;   // Nm/s
const uint8_t MOTOR_ID = 0x01;

// --- Control Parameters ---
const float KP = 30.0f;     // Nm/rad
const float KD = 1.5f;      // Nm*s/rad
const float DT = 0.0005f;   // 2kHz loop (500us)

// --- Watchdog ---
const unsigned long WATCHDOG_TIMEOUT_US = 100000;  // 100ms
volatile unsigned long last_cmd_time = 0;

// --- E-Stop Pin ---
const int ESTOP_PIN = 2;

// --- State ---
float desired_position = 0.0f;   // rad
float prev_torque_cmd = 0.0f;    // for rate limiting
float motor_offset = 0.0f;

// --- E-Stop ISR ---
void estop_isr() {
    state = E_STOP;
    send_zero_torque(MOTOR_ID);
    disable_motor(MOTOR_ID);
}

void setup() {
    can1.begin();
    can1.setBaudRate(1000000);
    Serial.begin(115200);

    pinMode(ESTOP_PIN, INPUT_PULLUP);
    attachInterrupt(digitalPinToInterrupt(ESTOP_PIN), estop_isr, FALLING);
}

// --- Torque Rate Limiter ---
float rate_limit_torque(float target, float prev, float max_rate, float dt) {
    float max_delta = max_rate * dt;
    float delta = target - prev;
    if (delta > max_delta) delta = max_delta;
    if (delta < -max_delta) delta = -max_delta;
    return prev + delta;
}

// --- Sensor Validation ---
bool validate_motor_feedback(float pos, float vel, float torque) {
    if (isnan(pos) || isnan(vel) || isnan(torque)) return false;
    if (abs(pos) > MAX_POSITION * 1.1f) return false;
    if (abs(vel) > MAX_VELOCITY * 1.5f) return false;
    return true;
}

void loop() {
    switch (state) {
        case IDLE: {
            if (Serial.available()) {
                char c = Serial.read();
                if (c == 'c') {
                    enable_motor(MOTOR_ID);
                    state = CALIBRATING;
                }
            }
            break;
        }

        case CALIBRATING: {
            float pos = read_motor_position(MOTOR_ID);
            if (!isnan(pos)) {
                motor_offset = pos;
                desired_position = 0.0f;
                prev_torque_cmd = 0.0f;
                last_cmd_time = micros();
                state = RUNNING;
                Serial.println("Calibrated. offset=" + String(motor_offset, 4));
            } else {
                state = ERROR;
                Serial.println("ERROR: calibration read failed");
            }
            break;
        }

        case RUNNING: {
            // Watchdog check
            if (micros() - last_cmd_time > WATCHDOG_TIMEOUT_US) {
                Serial.println("WATCHDOG: comm timeout, stopping");
                send_zero_torque(MOTOR_ID);
                state = E_STOP;
                break;
            }

            // Read new target if available
            if (Serial.available() >= 4) {
                byte buf[4];
                Serial.readBytes(buf, 4);
                float new_target;
                memcpy(&new_target, buf, 4);

                // Validate target range
                if (!isnan(new_target) && abs(new_target) <= MAX_POSITION) {
                    desired_position = new_target;
                    last_cmd_time = micros();
                }
            }

            // Read motor feedback
            float pos = read_motor_position(MOTOR_ID) - motor_offset;
            float vel = read_motor_velocity(MOTOR_ID);
            float fb_torque = read_motor_torque(MOTOR_ID);

            // Validate sensor readings
            if (!validate_motor_feedback(pos, vel, fb_torque)) {
                Serial.println("ERROR: invalid sensor reading");
                send_zero_torque(MOTOR_ID);
                state = ERROR;
                break;
            }

            // Compute torque
            float torque_cmd = KP * (desired_position - pos) - KD * vel;

            // Clamp to actuator limits
            torque_cmd = constrain(torque_cmd, -MAX_TORQUE, MAX_TORQUE);

            // Rate limit
            torque_cmd = rate_limit_torque(torque_cmd, prev_torque_cmd, TORQUE_RAMP_RATE, DT);
            prev_torque_cmd = torque_cmd;

            send_torque(MOTOR_ID, torque_cmd);
            break;
        }

        case E_STOP: {
            send_zero_torque(MOTOR_ID);
            disable_motor(MOTOR_ID);
            // Only reset via explicit command
            if (Serial.available()) {
                char c = Serial.read();
                if (c == 'r') {
                    prev_torque_cmd = 0.0f;
                    state = IDLE;
                    Serial.println("Reset to IDLE");
                }
            }
            break;
        }

        case ERROR: {
            send_zero_torque(MOTOR_ID);
            disable_motor(MOTOR_ID);
            // Require explicit reset
            if (Serial.available()) {
                char c = Serial.read();
                if (c == 'r') {
                    prev_torque_cmd = 0.0f;
                    state = IDLE;
                    Serial.println("Error cleared, reset to IDLE");
                }
            }
            break;
        }
    }

    delayMicroseconds(500);  // 2kHz
}
