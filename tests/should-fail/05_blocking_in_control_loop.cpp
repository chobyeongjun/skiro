// should-fail/05_blocking_in_control_loop.cpp
// BUG: Blocking calls (Serial.print, SD write, malloc) inside 1kHz control loop.
// CHECKLIST: #5 Control Loop Timing — blocking calls in real-time path.

#include <FlexCAN_T4.h>
#include <SD.h>

FlexCAN_T4<CAN1, RX_SIZE_256, TX_SIZE_16> can1;
File logFile;

const uint32_t MOTOR_ID = 0x01;
const float MAX_TORQUE = 6.0f;

volatile float encoder_position = 0.0f;
float target_position = 0.0f;

void control_loop_1khz() {
    float error = target_position - encoder_position;
    float torque = 50.0f * error;
    torque = constrain(torque, -MAX_TORQUE, MAX_TORQUE);

    send_motor_can(MOTOR_ID, torque);

    // BUG: Serial.print blocks when USB buffer is full (~64 bytes)
    Serial.print("t=");
    Serial.print(millis());
    Serial.print(",pos=");
    Serial.print(encoder_position, 4);
    Serial.print(",torque=");
    Serial.println(torque, 4);

    // BUG: SD card write inside control loop — can take 10-200ms
    logFile.print(millis());
    logFile.print(",");
    logFile.print(encoder_position, 4);
    logFile.print(",");
    logFile.println(torque, 4);
    logFile.flush();  // BUG: flush() blocks until write completes

    // BUG: malloc in real-time path
    char* debug_msg = (char*)malloc(128);
    sprintf(debug_msg, "Debug: pos=%.4f", encoder_position);
    free(debug_msg);
}

IntervalTimer controlTimer;

void setup() {
    Serial.begin(115200);
    can1.begin();
    can1.setBaudRate(1000000);
    SD.begin(BUILTIN_SDCARD);
    logFile = SD.open("experiment.csv", FILE_WRITE);
    controlTimer.begin(control_loop_1khz, 1000);  // 1kHz
}

void loop() {
    if (Serial.available()) {
        target_position = Serial.parseFloat();
    }
}
