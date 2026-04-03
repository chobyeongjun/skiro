// should-fail/02_no_estop.cpp
// BUG: No emergency stop mechanism anywhere in the code.
// CHECKLIST: #2 Emergency Stop — no e-stop path exists.

#include <FlexCAN_T4.h>

FlexCAN_T4<CAN1, RX_SIZE_256, TX_SIZE_16> can1;

const float MAX_TORQUE = 6.0f;  // Nm
const uint32_t MOTOR_ID = 0x01;

enum State { IDLE, RUNNING };
State current_state = IDLE;

void enable_motor() {
    CAN_message_t msg;
    msg.id = MOTOR_ID;
    msg.len = 8;
    memset(msg.buf, 0xFF, 8);
    can1.write(msg);
    current_state = RUNNING;
}

void send_torque(float torque_nm) {
    if (torque_nm > MAX_TORQUE) torque_nm = MAX_TORQUE;
    if (torque_nm < -MAX_TORQUE) torque_nm = -MAX_TORQUE;

    CAN_message_t msg;
    msg.id = MOTOR_ID;
    msg.len = 8;
    pack_mit_command(msg.buf, 0.0f, 0.0f, 0.0f, 0.0f, torque_nm);
    can1.write(msg);
}

void setup() {
    can1.begin();
    can1.setBaudRate(1000000);
    enable_motor();
}

// BUG: No e-stop button pin, no e-stop ISR, no safe shutdown path.
// If motor runs away, there is no software or hardware way to stop it.
void loop() {
    float desired = compute_pid_output();
    send_torque(desired);
    delay(1);
}
