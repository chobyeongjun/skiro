// should-fail/malloc-in-loop.cpp
// BUG: Dynamic memory allocation inside real-time control loop.
// CHECKLIST: #5 Control Loop Timing — no dynamic memory allocation in real-time path.

#include "motor_driver.h"
#include "sensor.h"

#include <cstdlib>
#include <cstring>

MotorDriver motor;
const float MAX_TORQUE = 10.0;  // Nm

struct LogEntry {
    unsigned long timestamp_us;
    float position;
    float velocity;
    float torque;
};

void control_loop() {
    float pos = motor.read_position();
    float vel = motor.read_velocity();
    float torque = compute_pd(pos, vel);
    torque = clamp(torque, -MAX_TORQUE, MAX_TORQUE);

    motor.set_torque(torque);

    // BUG: malloc in real-time loop — causes non-deterministic latency.
    // Heap fragmentation accumulates over hours of operation.
    // malloc may take 10us-10ms depending on heap state.
    LogEntry* entry = (LogEntry*)malloc(sizeof(LogEntry));
    entry->timestamp_us = micros();
    entry->position = pos;
    entry->velocity = vel;
    entry->torque = torque;
    log_to_buffer(entry);

    // BUG: new[] in real-time path
    char* msg = new char[64];
    snprintf(msg, 64, "pos=%.3f vel=%.3f", pos, vel);
    debug_print(msg);
    delete[] msg;
}

void setup() {
    motor.init();
}

void loop() {
    control_loop();
    delay_us(1000);
}
