// Teensy 4.1 + AK60-6 state machine controller
// BUG: Missing ERROR and E_STOP states, undefined transition possible
#include <FlexCAN_T4.h>

FlexCAN_T4<CAN1, RX_SIZE_256, TX_SIZE_16> can1;

enum State { IDLE, CALIBRATING, RUNNING };
// MISSING: E_STOP, ERROR states

State state = IDLE;
float motor_offset = 0.0f;
float max_torque = 6.0f;  // Nm

void handle_idle() {
    // Wait for start command
    if (Serial.available()) {
        char c = Serial.read();
        if (c == 'c') state = CALIBRATING;
        if (c == 'r') state = RUNNING;  // BUG: skip calibration
    }
}

void handle_calibrating() {
    // Read current position as zero offset
    motor_offset = read_motor_position(0x01);
    Serial.println("Calibrated. offset=" + String(motor_offset));
    state = RUNNING;  // Always transitions to running, even if calibration fails
}

void handle_running() {
    float pos = read_motor_position(0x01) - motor_offset;
    float vel = read_motor_velocity(0x01);
    float torque = 30.0f * (0.0f - pos) - 1.5f * vel;
    torque = constrain(torque, -max_torque, max_torque);
    send_torque(0x01, torque);
}

void loop() {
    switch (state) {
        case IDLE:        handle_idle(); break;
        case CALIBRATING: handle_calibrating(); break;
        case RUNNING:     handle_running(); break;
        // No default case — undefined state = no motor control
        // No ERROR recovery path
        // No E_STOP state
    }
    delayMicroseconds(500);
}
