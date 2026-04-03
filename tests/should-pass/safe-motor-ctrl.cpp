// should-pass/safe-motor-ctrl.cpp
// SAFE: Motor control with all CRITICAL checklist items satisfied.
// Generic motor driver — no MCU/motor-specific dependencies.

#include "motor_driver.h"
#include "comm.h"
#include "watchdog.h"

// --- Constants (adapt to your motor's datasheet) ---
const float MAX_TORQUE = 10.0;          // Nm
const float TORQUE_SLEW_RATE = 50.0;    // Nm/s — max rate of change
const uint32_t COMM_TIMEOUT_US = 100000; // 100 ms
const float DT = 0.001f;                // 1kHz control loop

// --- State machine: all required states present ---
enum RobotState { IDLE, CALIBRATING, RUNNING, E_STOP, ERROR };
volatile RobotState state = IDLE;

MotorDriver motor;
CommInterface comm;
Watchdog wdt;

volatile uint32_t last_cmd_time_us = 0;
volatile float commanded_torque = 0.0f;
float current_torque = 0.0f;

// --- E-stop ISR: sets zero torque immediately, no communication needed ---
void estop_isr() {
    state = E_STOP;
    motor.set_torque(0.0f);
}

float clamp(float val, float lo, float hi) {
    if (val < lo) return lo;
    if (val > hi) return hi;
    return val;
}

float apply_slew_rate(float target, float current, float dt) {
    float max_delta = TORQUE_SLEW_RATE * dt;
    float delta = clamp(target - current, -max_delta, max_delta);
    return current + delta;
}

// --- Timer ISR: 1kHz control loop (no blocking calls) ---
void control_isr() {
    wdt.kick();  // Reset watchdog

    if (state == E_STOP || state == ERROR) {
        motor.set_torque(0.0f);
        return;
    }

    if (state != RUNNING) return;

    // Communication watchdog
    uint32_t elapsed = micros() - last_cmd_time_us;
    if (elapsed > COMM_TIMEOUT_US) {
        state = ERROR;
        motor.set_torque(0.0f);
        current_torque = 0.0f;
        return;
    }

    // Rate limiter: no instant jumps
    current_torque = apply_slew_rate(commanded_torque, current_torque, DT);

    // Hard limit BEFORE sending
    current_torque = clamp(current_torque, -MAX_TORQUE, MAX_TORQUE);

    motor.set_torque(current_torque);
}

void setup() {
    motor.init();
    comm.init(115200);
    wdt.init(200000);  // 200ms hardware watchdog

    // Hardware e-stop button
    configure_estop_pin(ESTOP_PIN, estop_isr);

    last_cmd_time_us = micros();
    attach_timer_interrupt(control_isr, 1000);  // 1kHz
    state = RUNNING;
}

void loop() {
    // Non-blocking command receive
    if (comm.available() >= 4) {
        float cmd = comm.read_float();
        commanded_torque = cmd;
        last_cmd_time_us = micros();
    }

    // ERROR recovery: only via explicit reset command
    if (state == ERROR && comm.available()) {
        char c = comm.read_char();
        if (c == 'R') {
            current_torque = 0.0f;
            commanded_torque = 0.0f;
            last_cmd_time_us = micros();
            state = RUNNING;
        }
    }
}
