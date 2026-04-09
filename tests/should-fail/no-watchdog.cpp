// should-fail/no-watchdog.cpp
// BUG: No watchdog timer — if main loop hangs, system runs uncontrolled.
// CHECKLIST: #3 Watchdog — no auto-stop on hang or communication loss.

#include "motor_driver.h"
#include "comm.h"

MotorDriver motor;
CommInterface comm;

const float MAX_TORQUE = 10.0;  // Nm

float last_torque_cmd = 0.0;

void setup() {
    motor.init();
    comm.init(115200);
    // BUG: No hardware or software watchdog configured.
    // If the loop hangs (e.g., blocking I/O, infinite loop in driver),
    // the motor continues executing last command indefinitely.
}

void loop() {
    if (comm.available()) {
        float cmd = comm.read_float();
        last_torque_cmd = clamp(cmd, -MAX_TORQUE, MAX_TORQUE);
    }

    // BUG: No check whether comm is still alive.
    // If host disconnects, last_torque_cmd stays at last value forever.
    motor.set_torque(last_torque_cmd);

    delay_us(1000);

    // BUG: No watchdog kick — if this function takes too long
    // (e.g., motor.set_torque blocks on bus error), nobody detects it.
}
