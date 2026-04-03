// should-pass/01_safe_torque_control.cpp
// SAFE: Complete torque control with all CRITICAL checklist items satisfied.
// Teensy 4.1 + AK60-6 CAN motor, MIT protocol.

#include <FlexCAN_T4.h>

FlexCAN_T4<CAN1, RX_SIZE_256, TX_SIZE_16> can1;

// --- Constants (from AK60-6 datasheet) ---
const uint32_t MOTOR_ID       = 0x01;
const float MAX_TORQUE         = 6.0f;    // Nm — rated continuous torque
const float MAX_VELOCITY       = 38.2f;   // rad/s
const float MAX_POSITION       = 12.5f;   // rad
const float TORQUE_SLEW_RATE   = 20.0f;   // Nm/s — max rate of change
const uint32_t WATCHDOG_TIMEOUT_US = 100000;  // 100 ms

// --- State machine ---
enum MotorState {
    IDLE,
    CALIBRATING,
    RUNNING,
    E_STOP,
    ERROR
};
volatile MotorState state = IDLE;

// --- E-stop hardware ---
const int ESTOP_PIN = 2;  // Hardware e-stop button, active LOW

// --- Communication watchdog ---
volatile uint32_t last_cmd_time_us = 0;
float commanded_torque = 0.0f;
float current_torque = 0.0f;

// --- E-stop ISR (hardware interrupt, no communication needed) ---
void estop_isr() {
    state = E_STOP;
    send_zero_torque();
}

void send_zero_torque() {
    CAN_message_t msg;
    msg.id = MOTOR_ID;
    msg.len = 8;
    pack_mit_command(msg.buf, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f);
    can1.write(msg);
}

void send_torque(float torque_nm) {
    // Actuator limit check BEFORE sending
    torque_nm = constrain(torque_nm, -MAX_TORQUE, MAX_TORQUE);

    CAN_message_t msg;
    msg.id = MOTOR_ID;
    msg.len = 8;
    pack_mit_command(msg.buf, 0.0f, 0.0f, 0.0f, 0.0f, torque_nm);
    can1.write(msg);
}

float apply_slew_rate(float target, float current, float dt_s) {
    float max_delta = TORQUE_SLEW_RATE * dt_s;
    float delta = target - current;
    if (delta > max_delta) delta = max_delta;
    if (delta < -max_delta) delta = -max_delta;
    return current + delta;
}

void on_serial_receive() {
    if (Serial.available() >= 4) {
        union { float f; uint8_t b[4]; } u;
        Serial.readBytes(u.b, 4);
        commanded_torque = u.f;
        last_cmd_time_us = micros();
    }
}

void control_loop_1khz() {
    if (state == E_STOP || state == ERROR) {
        send_zero_torque();
        return;
    }

    // Watchdog: check communication timeout
    uint32_t elapsed = micros() - last_cmd_time_us;
    if (elapsed > WATCHDOG_TIMEOUT_US) {
        state = ERROR;
        send_zero_torque();
        return;
    }

    // Rate limiter: no instant jumps
    current_torque = apply_slew_rate(commanded_torque, current_torque, 0.001f);

    // Limit check before send
    send_torque(current_torque);
}

IntervalTimer controlTimer;

void setup() {
    Serial.begin(115200);
    can1.begin();
    can1.setBaudRate(1000000);

    pinMode(ESTOP_PIN, INPUT_PULLUP);
    attachInterrupt(digitalPinToInterrupt(ESTOP_PIN), estop_isr, FALLING);

    last_cmd_time_us = micros();
    controlTimer.begin(control_loop_1khz, 1000);  // 1kHz
    state = RUNNING;
}

void loop() {
    on_serial_receive();

    // State recovery: ERROR -> IDLE only via explicit reset command
    if (state == ERROR && Serial.available()) {
        char c = Serial.read();
        if (c == 'R') {
            state = IDLE;
            current_torque = 0.0f;
            commanded_torque = 0.0f;
            last_cmd_time_us = micros();
            state = RUNNING;
        }
    }
}
