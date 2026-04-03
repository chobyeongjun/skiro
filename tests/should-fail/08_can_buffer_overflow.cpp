// should-fail/08_can_buffer_overflow.cpp
// BUG: CAN receive buffer overflow — no bounds check on incoming data.
// CHECKLIST: #7 Communication Protocol — no buffer overflow protection.

#include <FlexCAN_T4.h>

FlexCAN_T4<CAN1, RX_SIZE_256, TX_SIZE_16> can1;

// Fixed-size command buffer — no overflow protection
struct CommandPacket {
    uint8_t motor_id;
    float position;
    float velocity;
    float torque;
};

#define CMD_BUFFER_SIZE 8
CommandPacket cmd_buffer[CMD_BUFFER_SIZE];
volatile int cmd_write_idx = 0;

// BUG: No CRC/checksum validation on received CAN frames
// BUG: No check that cmd_write_idx stays within bounds
void on_can_receive(const CAN_message_t& msg) {
    CommandPacket pkt;
    pkt.motor_id = msg.buf[0];

    // Unpack floats from CAN data — no validation
    memcpy(&pkt.position, &msg.buf[1], 4);  // BUG: buf only 8 bytes, reading past bounds if msg.len < 8
    memcpy(&pkt.velocity, &msg.buf[5], 4);  // BUG: reads buf[5..8], out of bounds

    // BUG: No bounds check — cmd_write_idx increments forever
    cmd_buffer[cmd_write_idx] = pkt;  // Buffer overflow when idx >= 8
    cmd_write_idx++;
    // Never resets or wraps around
}

void process_commands() {
    for (int i = 0; i < cmd_write_idx; i++) {
        // BUG: Reads potentially corrupted memory after overflow
        execute_motor_command(cmd_buffer[i]);
    }
    cmd_write_idx = 0;
}

void setup() {
    can1.begin();
    can1.setBaudRate(1000000);
    can1.onReceive(on_can_receive);
}

void loop() {
    process_commands();
    delayMicroseconds(1000);
}
