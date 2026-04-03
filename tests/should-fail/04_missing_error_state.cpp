// should-fail/04_missing_error_state.cpp
// BUG: State machine has no ERROR or E_STOP state.
// CHECKLIST: #4 State Machine Integrity — missing required states.

#include <FlexCAN_T4.h>

FlexCAN_T4<CAN1, RX_SIZE_256, TX_SIZE_16> can1;

// BUG: Only 3 states — no E_STOP, no ERROR state
enum MotorState {
    IDLE,
    CALIBRATING,
    RUNNING
};

MotorState state = IDLE;

void handle_state() {
    switch (state) {
        case IDLE:
            // Wait for start command
            if (Serial.read() == 's') {
                state = CALIBRATING;
            }
            break;

        case CALIBRATING:
            run_encoder_calibration();
            state = RUNNING;  // BUG: No check if calibration succeeded
            break;

        case RUNNING:
            float torque = compute_control();
            torque = constrain(torque, -6.0f, 6.0f);
            send_motor_can(torque);
            break;

        // BUG: No default case — undefined enum values silently ignored
    }
}

void setup() {
    Serial.begin(115200);
    can1.begin();
    can1.setBaudRate(1000000);
}

void loop() {
    handle_state();
    delay(1);
}
