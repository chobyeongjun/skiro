// should-fail/no-timeout.cpp
// BUG: Communication receive has no timeout — blocks forever if peer disconnects.
// CHECKLIST: #3 Watchdog — serial/network loss must not cause hang.

#include "motor_driver.h"
#include "comm.h"

MotorDriver motor;
SerialComm serial_comm;

const float MAX_TORQUE = 10.0;  // Nm

struct CommandPacket {
    float target_position;  // rad
    float target_velocity;  // rad/s
    float feedforward_torque;  // Nm
};

CommandPacket read_command() {
    CommandPacket pkt;
    // BUG: Blocking read with no timeout.
    // If the host PC crashes or cable disconnects, this blocks forever.
    // The motor continues last command because we never reach set_torque(0).
    uint8_t buf[12];
    serial_comm.read_bytes(buf, 12);  // Blocks until 12 bytes received

    memcpy(&pkt.target_position, &buf[0], 4);
    memcpy(&pkt.target_velocity, &buf[4], 4);
    memcpy(&pkt.feedforward_torque, &buf[8], 4);
    return pkt;
}

void setup() {
    motor.init();
    serial_comm.init(115200);
    // BUG: No timeout configured on serial port
    // serial_comm.set_timeout(100);  // This line is missing
}

void loop() {
    // BUG: If read_command blocks, the control loop stops.
    // Motor holds last position/torque command indefinitely.
    CommandPacket cmd = read_command();

    float torque = compute_control(cmd);
    torque = clamp(torque, -MAX_TORQUE, MAX_TORQUE);
    motor.set_torque(torque);
}
