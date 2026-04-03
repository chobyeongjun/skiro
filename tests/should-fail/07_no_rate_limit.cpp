// should-fail/07_no_rate_limit.cpp
// BUG: No rate limiter — instant jump from 0 to max torque/position.
// CHECKLIST: #1 Actuator Limits — no rate limiter, instant jumps allowed.

#include <FlexCAN_T4.h>

FlexCAN_T4<CAN1, RX_SIZE_256, TX_SIZE_16> can1;

const uint32_t MOTOR_ID = 0x01;
const float MAX_TORQUE = 6.0f;   // Nm
const float MAX_POS = 12.5f;     // rad

float current_position = 0.0f;

void send_position_command(float target_pos, float kp, float kd) {
    target_pos = constrain(target_pos, -MAX_POS, MAX_POS);

    CAN_message_t msg;
    msg.id = MOTOR_ID;
    msg.len = 8;
    // BUG: Jumps directly to target_pos without slew rate limit.
    // A command from 0 to 12.5 rad applies max torque instantly,
    // causing mechanical shock and potential gear damage.
    pack_mit_command(msg.buf, target_pos, 0.0f, kp, kd, 0.0f);
    can1.write(msg);
}

void setup() {
    Serial.begin(115200);
    can1.begin();
    can1.setBaudRate(1000000);
    enable_motor(MOTOR_ID);
}

void loop() {
    if (Serial.available()) {
        float new_target = Serial.parseFloat();
        // BUG: Instant step command — no ramp, no trajectory generation
        send_position_command(new_target, 200.0f, 5.0f);
    }
    delay(1);
}
