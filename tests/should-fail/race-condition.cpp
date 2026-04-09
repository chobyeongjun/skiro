// should-fail/race-condition.cpp
// BUG: ISR and main loop share variables without volatile or atomic protection.
// CHECKLIST: #5 Control Loop Timing — data race in real-time path.

#include "motor_driver.h"

MotorDriver motor;

// BUG: shared_position is read in main loop and written in ISR
// without volatile qualifier or atomic access.
// Compiler may optimize away re-reads in main loop,
// and 32-bit float write is not atomic on all architectures.
float shared_position = 0.0;    // BUG: not volatile
float shared_velocity = 0.0;    // BUG: not volatile
float shared_torque_cmd = 0.0;  // BUG: not volatile

bool new_data_ready = false;    // BUG: not volatile — may never be seen by main loop

const float MAX_TORQUE = 10.0;  // Nm

// ISR: called by encoder hardware interrupt
void encoder_isr() {
    // BUG: Multi-word write without critical section.
    // Main loop could read position mid-update (torn read).
    shared_position = read_encoder_position();  // 32-bit float
    shared_velocity = compute_velocity();
    new_data_ready = true;
    // BUG: No memory barrier — writes may be reordered.
    // Main loop might see new_data_ready=true but stale position.
}

// Timer ISR: 1kHz control
void control_isr() {
    // BUG: Reads shared_position that encoder_isr may be writing NOW.
    // On 8/16-bit MCU, float read is 4 bytes = non-atomic = torn read.
    float pos = shared_position;
    float vel = shared_velocity;

    float torque = 50.0f * (0.0f - pos) + 2.0f * (0.0f - vel);
    torque = clamp(torque, -MAX_TORQUE, MAX_TORQUE);

    // BUG: shared_torque_cmd written here, read in main loop — same race.
    shared_torque_cmd = torque;
    motor.set_torque(torque);
}

void setup() {
    motor.init();
    attach_encoder_interrupt(encoder_isr);
    attach_timer_interrupt(control_isr, 1000);  // 1kHz
}

void loop() {
    // BUG: Reads shared variables without disabling interrupts.
    if (new_data_ready) {
        float pos = shared_position;   // Potentially torn
        float tau = shared_torque_cmd; // Potentially torn
        log_data(pos, tau);
        new_data_ready = false;
    }
    delay_ms(10);
}
