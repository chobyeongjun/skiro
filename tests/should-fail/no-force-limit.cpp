// should-fail/no-force-limit.cpp
// BUG: Motor torque command sent without any force/torque limit check.
// CHECKLIST: #1 Actuator Limits — no max value check BEFORE sending.

#include "motor_driver.h"
#include "controller.h"

MotorDriver motor;
PIDController pid(50.0, 0.0, 2.0);  // Kp, Ki, Kd

float target_position = 0.0;  // rad
float measured_position = 0.0;
float measured_velocity = 0.0;

void control_update() {
    measured_position = motor.read_position();
    measured_velocity = motor.read_velocity();

    float error = target_position - measured_position;
    float torque = pid.compute(error, measured_velocity);

    // BUG: No torque/force limit.
    // pid.compute() can return arbitrary values (e.g., 500 Nm on large error).
    // Motor driver receives unclamped command directly.
    motor.set_torque(torque);
}

void setup() {
    motor.init();
    pid.reset();
}

void loop() {
    if (new_command_available()) {
        target_position = read_command();
    }
    control_update();
    delay_us(1000);  // 1kHz loop
}
