// should-fail/can-id-duplicate.cpp
// BUG: Two motors assigned the same CAN ID on the same bus.
// CHECKLIST: #7 Communication Protocol — message IDs must not conflict.

#include "can_bus.h"
#include "motor_driver.h"

CANBus can;

// BUG: Both motors share CAN ID 0x01.
// Motor responses collide, commands are ambiguous.
// One motor may receive the other's torque command.
const uint32_t LEFT_HIP_MOTOR_ID  = 0x01;
const uint32_t RIGHT_HIP_MOTOR_ID = 0x01;  // BUG: same as left hip

const float MAX_TORQUE = 10.0;  // Nm

struct MotorState {
    float position;   // rad
    float velocity;   // rad/s
    float torque;     // Nm
};

MotorState left_state, right_state;

void send_motor_cmd(uint32_t id, float torque) {
    torque = clamp(torque, -MAX_TORQUE, MAX_TORQUE);
    CANMessage msg;
    msg.id = id;
    msg.len = 8;
    pack_motor_command(msg.data, torque);
    can.send(msg);
}

void read_feedback() {
    CANMessage msg;
    if (can.receive(msg)) {
        // BUG: Cannot distinguish left from right — same ID
        if (msg.id == LEFT_HIP_MOTOR_ID) {
            unpack_motor_state(msg.data, &left_state);
            // This also matches RIGHT_HIP_MOTOR_ID...
        }
        if (msg.id == RIGHT_HIP_MOTOR_ID) {
            unpack_motor_state(msg.data, &right_state);
            // Overwrites with whichever response arrives last
        }
    }
}

void setup() {
    can.init(1000000);  // 1 Mbps
}

void loop() {
    read_feedback();

    float left_torque = compute_left_control(left_state);
    float right_torque = compute_right_control(right_state);

    // BUG: Both commands go to the same ID — only one motor responds correctly
    send_motor_cmd(LEFT_HIP_MOTOR_ID, left_torque);
    send_motor_cmd(RIGHT_HIP_MOTOR_ID, right_torque);

    delay_us(1000);
}
