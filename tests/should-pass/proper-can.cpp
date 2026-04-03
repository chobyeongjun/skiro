// should-pass/proper-can.cpp
// SAFE: CAN communication with unique IDs, timeout, error handling, CRC.
// Generic CAN bus — works with any CAN-capable MCU.

#include "can_bus.h"
#include "motor_driver.h"
#include "watchdog.h"

CANBus can;
Watchdog wdt;

// Unique CAN IDs — no conflicts
const uint32_t LEFT_HIP_ID   = 0x01;
const uint32_t RIGHT_HIP_ID  = 0x02;
const uint32_t LEFT_KNEE_ID  = 0x03;
const uint32_t RIGHT_KNEE_ID = 0x04;

const float MAX_TORQUE = 10.0;                // Nm
const uint32_t CAN_TIMEOUT_US = 50000;        // 50ms per motor
const int CMD_BUFFER_SIZE = 16;

struct MotorState {
    float position;        // rad
    float velocity;        // rad/s
    float torque;          // Nm
    uint32_t last_seen_us; // timestamp of last valid response
    bool online;
};

MotorState motors[4];
const uint32_t motor_ids[4] = {
    LEFT_HIP_ID, RIGHT_HIP_ID, LEFT_KNEE_ID, RIGHT_KNEE_ID
};

// Ring buffer with bounds check
struct CmdRingBuffer {
    CANMessage buf[CMD_BUFFER_SIZE];
    volatile int head;
    volatile int tail;

    bool push(const CANMessage& msg) {
        int next = (head + 1) % CMD_BUFFER_SIZE;
        if (next == tail) return false;  // Buffer full — drop, don't overflow
        buf[head] = msg;
        head = next;
        return true;
    }

    bool pop(CANMessage& msg) {
        if (head == tail) return false;  // Empty
        msg = buf[tail];
        tail = (tail + 1) % CMD_BUFFER_SIZE;
        return true;
    }
};

CmdRingBuffer rx_buffer;

uint8_t compute_crc8(const uint8_t* data, int len) {
    uint8_t crc = 0x00;
    for (int i = 0; i < len; i++) {
        crc ^= data[i];
        for (int j = 0; j < 8; j++) {
            crc = (crc & 0x80) ? (crc << 1) ^ 0x07 : (crc << 1);
        }
    }
    return crc;
}

bool validate_can_message(const CANMessage& msg) {
    if (msg.len < 8) return false;

    // CRC check: last byte is CRC of first 7 bytes
    uint8_t expected_crc = compute_crc8(msg.data, 7);
    if (msg.data[7] != expected_crc) return false;

    return true;
}

int find_motor_index(uint32_t id) {
    for (int i = 0; i < 4; i++) {
        if (motor_ids[i] == id) return i;
    }
    return -1;
}

void can_rx_isr(const CANMessage& msg) {
    rx_buffer.push(msg);  // Bounded push, no overflow
}

void process_rx() {
    CANMessage msg;
    while (rx_buffer.pop(msg)) {
        if (!validate_can_message(msg)) continue;  // CRC fail — discard

        int idx = find_motor_index(msg.id);
        if (idx < 0) continue;  // Unknown ID — ignore

        unpack_motor_state(msg.data, &motors[idx]);
        motors[idx].last_seen_us = micros();
        motors[idx].online = true;
    }
}

void check_motor_timeouts() {
    uint32_t now = micros();
    for (int i = 0; i < 4; i++) {
        if (now - motors[i].last_seen_us > CAN_TIMEOUT_US) {
            motors[i].online = false;
        }
    }
}

void send_motor_cmd(int idx, float torque) {
    if (!motors[idx].online) {
        torque = 0.0f;  // Offline motor gets zero torque
    }
    torque = clamp(torque, -MAX_TORQUE, MAX_TORQUE);

    CANMessage msg;
    msg.id = motor_ids[idx];
    msg.len = 8;
    pack_motor_command(msg.data, torque);
    msg.data[7] = compute_crc8(msg.data, 7);  // Append CRC
    can.send(msg);
}

void setup() {
    can.init(1000000);  // 1 Mbps
    can.on_receive(can_rx_isr);
    wdt.init(200000);

    for (int i = 0; i < 4; i++) {
        motors[i].last_seen_us = micros();
        motors[i].online = false;
    }
}

void loop() {
    wdt.kick();
    process_rx();
    check_motor_timeouts();

    for (int i = 0; i < 4; i++) {
        float torque = compute_joint_control(i, motors[i]);
        send_motor_cmd(i, torque);
    }

    delay_us(1000);
}
