// should-fail/01_no_torque_limit.cpp
// BUG: Torque command sent directly without max value check.
// CHECKLIST: #1 Actuator Limits — no max value check BEFORE sending.
// AK60-6 rated torque: 6 Nm, peak: 12 Nm

#include <FlexCAN_T4.h>

FlexCAN_T4<CAN1, RX_SIZE_256, TX_SIZE_16> can1;

struct AK60Command {
    uint32_t id;
    float position;   // rad
    float velocity;   // rad/s
    float kp;
    float kd;
    float torque_ff;  // Nm
};

void send_motor_command(const AK60Command& cmd) {
    CAN_message_t msg;
    msg.id = cmd.id;
    msg.len = 8;

    uint16_t p_int  = float_to_uint(cmd.position, -12.5f, 12.5f, 16);
    uint16_t v_int  = float_to_uint(cmd.velocity, -45.0f, 45.0f, 12);
    uint16_t kp_int = float_to_uint(cmd.kp, 0.0f, 500.0f, 12);
    uint16_t kd_int = float_to_uint(cmd.kd, 0.0f, 5.0f, 12);
    uint16_t t_int  = float_to_uint(cmd.torque_ff, -12.0f, 12.0f, 12);

    msg.buf[0] = p_int >> 8;
    msg.buf[1] = p_int & 0xFF;
    msg.buf[2] = v_int >> 4;
    msg.buf[3] = ((v_int & 0xF) << 4) | (kp_int >> 8);
    msg.buf[4] = kp_int & 0xFF;
    msg.buf[5] = kd_int >> 4;
    msg.buf[6] = ((kd_int & 0xF) << 4) | (t_int >> 8);
    msg.buf[7] = t_int & 0xFF;

    // BUG: No torque limit check — user can send 100 Nm
    can1.write(msg);
}

void loop() {
    AK60Command cmd;
    cmd.id = 0x01;
    cmd.position = 0.0f;
    cmd.velocity = 0.0f;
    cmd.kp = 50.0f;
    cmd.kd = 2.0f;
    cmd.torque_ff = read_desired_torque();  // Could return ANY value
    send_motor_command(cmd);
    delay(1);
}
