// should-fail/03_no_watchdog.cpp
// BUG: No communication timeout / watchdog.
// CHECKLIST: #3 Watchdog — no timeout on command reception.
// If the host PC crashes, motor keeps running last command forever.

#include <FlexCAN_T4.h>

FlexCAN_T4<CAN1, RX_SIZE_256, TX_SIZE_16> can1;

const uint32_t MOTOR_ID = 0x01;
const float MAX_TORQUE = 6.0f;  // Nm

float last_command_torque = 0.0f;

void on_serial_receive() {
    if (Serial.available() >= 4) {
        union { float f; uint8_t b[4]; } u;
        Serial.readBytes(u.b, 4);
        last_command_torque = constrain(u.f, -MAX_TORQUE, MAX_TORQUE);
        // BUG: No timestamp recorded for last received command
    }
}

void send_torque(float torque_nm) {
    CAN_message_t msg;
    msg.id = MOTOR_ID;
    msg.len = 8;
    pack_mit_command(msg.buf, 0.0f, 0.0f, 0.0f, 0.0f, torque_nm);
    can1.write(msg);
}

void setup() {
    Serial.begin(115200);
    can1.begin();
    can1.setBaudRate(1000000);
}

void loop() {
    on_serial_receive();

    // BUG: Keeps sending last_command_torque even if Serial disconnected.
    // No timeout check. Motor runs indefinitely with stale command.
    send_torque(last_command_torque);
    delayMicroseconds(1000);
}
