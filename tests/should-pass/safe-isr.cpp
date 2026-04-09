// should-pass/safe-isr.cpp
// SAFE: Short ISR with volatile variables, flag-based communication,
// critical section for multi-word shared data.

#include "motor_driver.h"

MotorDriver motor;

const float MAX_TORQUE = 10.0;  // Nm

// Shared data: volatile + double-buffer for safe ISR-main communication
struct MotorData {
    float position;   // rad
    float velocity;   // rad/s
    float torque_cmd; // Nm
};

volatile MotorData isr_data = {0.0f, 0.0f, 0.0f};
volatile bool new_data_flag = false;

// Double buffer to avoid torn reads
MotorData main_data = {0.0f, 0.0f, 0.0f};

// --- Encoder ISR: minimal work, set flag only ---
void encoder_isr() {
    // Only update the raw count — no computation in ISR
    increment_encoder_count();
}

// --- Timer ISR (1kHz): short, no blocking, no printf ---
void control_isr() {
    float pos = read_encoder_position();  // Fast register read
    float vel = compute_velocity_from_count();

    float error = 0.0f - pos;
    float torque = 50.0f * error + 2.0f * (0.0f - vel);

    // Clamp before sending
    if (torque > MAX_TORQUE) torque = MAX_TORQUE;
    if (torque < -MAX_TORQUE) torque = -MAX_TORQUE;

    motor.set_torque(torque);

    // Write to shared buffer with flag protocol:
    // Write data first, then set flag.
    // Main loop reads flag first, then data — no torn read if
    // main loop uses critical section for multi-word copy.
    isr_data.position = pos;
    isr_data.velocity = vel;
    isr_data.torque_cmd = torque;
    new_data_flag = true;  // Set AFTER data is fully written
}

void setup() {
    motor.init();
    attach_encoder_interrupt(encoder_isr);
    attach_timer_interrupt(control_isr, 1000);  // 1kHz
}

void loop() {
    if (new_data_flag) {
        // Critical section: disable interrupts for multi-word copy
        disable_interrupts();
        main_data.position = isr_data.position;
        main_data.velocity = isr_data.velocity;
        main_data.torque_cmd = isr_data.torque_cmd;
        new_data_flag = false;
        enable_interrupts();

        // Logging outside critical section — blocking OK in main loop
        log_data(main_data.position, main_data.velocity, main_data.torque_cmd);
    }
    delay_ms(10);  // Logging at 100Hz is fine for main loop
}
