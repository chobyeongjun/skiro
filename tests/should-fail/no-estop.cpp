// should-fail/no-estop.cpp
// BUG: No emergency stop mechanism — no hardware pin, no software path.
// CHECKLIST: #2 Emergency Stop — e-stop path must exist.

#include "motor_driver.h"
#include "comm.h"

MotorDriver motor_hip;
MotorDriver motor_knee;
CommInterface comm;

const float MAX_TORQUE = 10.0;  // Nm

// BUG: Only 2 states — no E_STOP, no ERROR
enum RobotState { IDLE, RUNNING };
RobotState state = IDLE;

void run_control() {
    float hip_pos = motor_hip.read_position();
    float knee_pos = motor_knee.read_position();

    float hip_torque = compute_hip_control(hip_pos);
    float knee_torque = compute_knee_control(knee_pos);

    hip_torque = clamp(hip_torque, -MAX_TORQUE, MAX_TORQUE);
    knee_torque = clamp(knee_torque, -MAX_TORQUE, MAX_TORQUE);

    motor_hip.set_torque(hip_torque);
    motor_knee.set_torque(knee_torque);
}

void setup() {
    motor_hip.init();
    motor_knee.init();
    comm.init(115200);

    // BUG: No e-stop pin configured.
    // BUG: No e-stop ISR registered.
    // BUG: No way to reach zero-torque state from RUNNING
    //       except power cycling the entire system.

    state = RUNNING;
}

void loop() {
    if (state == RUNNING) {
        run_control();
    }
    // BUG: No e-stop check anywhere in the loop.
    // If motor runs away or human is in danger,
    // there is no programmatic way to stop the actuators.
    delay_us(1000);
}
