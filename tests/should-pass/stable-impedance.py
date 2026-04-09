# should-pass/stable-impedance.py
# SAFE: Impedance control with passivity-guaranteed parameters.
# Validates stability conditions before running.

import math
import sys

MAX_TORQUE = 10.0   # Nm
DT = 0.001          # 1kHz


class ImpedanceController:
    def __init__(self, K: float, B: float, M: float):
        """
        K: virtual stiffness (Nm/rad) — must be >= 0
        B: virtual damping (Nm*s/rad) — must be > 0
        M: virtual inertia (kg*m^2) — must be > 0
        """
        # Passivity / stability checks
        if K < 0:
            raise ValueError(f"Stiffness K={K} must be >= 0")
        if B <= 0:
            raise ValueError(f"Damping B={B} must be > 0 for stability")
        if M <= 0:
            raise ValueError(f"Inertia M={M} must be > 0")

        # Check damping ratio: B^2 >= 4*M*K for critically/overdamped
        discriminant = B * B - 4.0 * M * K
        if discriminant < 0:
            zeta = B / (2.0 * math.sqrt(M * K))
            if zeta < 0.5:
                raise ValueError(
                    f"Underdamped: zeta={zeta:.3f} < 0.5. "
                    f"Increase B or decrease K for safer response."
                )

        self.K = K
        self.B = B
        self.M = M
        self.target_pos = 0.0
        self.target_vel = 0.0

    def compute(self, measured_pos: float, measured_vel: float) -> float:
        # Validate sensor inputs
        if math.isnan(measured_pos) or math.isinf(measured_pos):
            return 0.0  # Safe fallback
        if math.isnan(measured_vel) or math.isinf(measured_vel):
            return 0.0

        pos_error = self.target_pos - measured_pos
        vel_error = self.target_vel - measured_vel

        torque = self.K * pos_error + self.B * vel_error

        # NaN guard
        if math.isnan(torque) or math.isinf(torque):
            return 0.0

        # Hard torque limit
        return max(-MAX_TORQUE, min(MAX_TORQUE, torque))


def main():
    # Stable parameters: K=100, B=20, M=1.0
    # zeta = 20 / (2*sqrt(1*100)) = 1.0 → critically damped
    try:
        ctrl = ImpedanceController(K=100.0, B=20.0, M=1.0)
    except ValueError as e:
        print(f"[SAFETY] Impedance parameter error: {e}")
        sys.exit(1)

    ctrl.target_pos = 1.0  # rad

    pos = 0.0
    vel = 0.0

    while True:
        torque = ctrl.compute(pos, vel)
        send_torque_to_motor(torque)

        acc = torque / ctrl.M
        vel += acc * DT
        pos += vel * DT

        wait_ms(1)


if __name__ == "__main__":
    main()
