// should-fail/blocking-delay.cpp
// BUG: Blocking sleep/delay inside control loop.
// CHECKLIST: #5 Control Loop Timing — no blocking calls (sleep) in control loop.

#include "motor_driver.h"
#include "sensor.h"

MotorDriver motor;
ForceSensor force_sensor;

const float MAX_TORQUE = 10.0;  // Nm
const float FORCE_THRESHOLD = 50.0;  // N

void control_loop() {
    float pos = motor.read_position();
    float vel = motor.read_velocity();

    float torque = compute_pd(pos, vel);
    torque = clamp(torque, -MAX_TORQUE, MAX_TORQUE);
    motor.set_torque(torque);

    // BUG: Blocking delay for sensor "settling time"
    // This stalls the entire control loop for 10ms.
    // At 1kHz loop rate, this means the loop runs at ~90 Hz effectively.
    delay_ms(10);

    float force = force_sensor.read();
    if (force > FORCE_THRESHOLD) {
        motor.set_torque(0.0);
        // BUG: Another blocking delay — "debounce"
        delay_ms(100);
    }

    // BUG: Blocking wait for serial transmission
    serial_print("pos=");
    serial_print_float(pos);
    serial_print(" tau=");
    serial_println_float(torque);
    serial_flush_blocking();  // Waits for UART TX to complete
}

void setup() {
    motor.init();
    force_sensor.init();
}

void loop() {
    control_loop();
    // No delay here, but control_loop already has blocking delays inside
}
