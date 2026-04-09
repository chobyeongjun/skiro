# should-fail/unsafe-impedance.py
# BUG: Impedance control with unstable parameters — negative damping and
# stiffness exceeding passivity condition.
# CHECKLIST: #1 Actuator Limits, #6 Sensor Validation — unstable gains.

import math

MAX_TORQUE = 10.0  # Nm
DT = 0.001         # 1kHz

class ImpedanceController:
    def __init__(self):
        # BUG: Negative damping — injects energy into the system.
        # System becomes unstable and oscillates with growing amplitude.
        self.K = 200.0    # Nm/rad — virtual stiffness
        self.B = -5.0     # Nm*s/rad — BUG: negative damping
        self.M = 0.1      # kg*m^2 — virtual inertia

        # BUG: No passivity check. For stable impedance control:
        #   B > 0 (positive damping required)
        #   B^2 >= 4*M*K (critically damped or overdamped)
        # Here: B^2 = 25, 4*M*K = 80 → underdamped AND negative damping

        self.target_pos = 0.0
        self.target_vel = 0.0

    def compute(self, measured_pos, measured_vel):
        pos_error = self.target_pos - measured_pos
        vel_error = self.target_vel - measured_vel

        # BUG: With B < 0, damping term ADDS energy on velocity error.
        # Motor accelerates instead of decelerating.
        torque = self.K * pos_error + self.B * vel_error
        return torque  # BUG: No torque clamp here either


def main():
    ctrl = ImpedanceController()
    ctrl.target_pos = 1.0  # rad

    pos = 0.0
    vel = 0.0

    while True:
        torque = ctrl.compute(pos, vel)
        # BUG: NaN not checked — negative damping can cause divergence
        send_torque_to_motor(torque)

        # Simulate forward dynamics (for illustration)
        acc = torque / ctrl.M
        vel += acc * DT
        pos += vel * DT

        wait_ms(1)


if __name__ == "__main__":
    main()
