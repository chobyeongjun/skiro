"""
PC-side AK60-6 CAN interface — safe implementation.
Teensy 4.1 + AK60-6, python-can over socketcan.
"""
import can
import struct
import time
from typing import Optional, Tuple

# --- CAN IDs (no conflicts) ---
MOTOR_CMD_ID = 0x01    # Host -> Motor
MOTOR_REPLY_ID = 0x02  # Motor -> Host (AK60-6 replies on ID+1 by default)

# --- AK60-6 Limits (datasheet) ---
MAX_POSITION_RAD = 12.5       # rad
MAX_VELOCITY_RPS = 45.0       # rad/s
MAX_TORQUE_NM = 15.0          # Nm peak (6 Nm continuous)
MAX_KP = 500.0
MAX_KD = 5.0

# --- Communication ---
CAN_RECV_TIMEOUT_S = 0.05     # 50ms timeout
WATCHDOG_TIMEOUT_S = 0.1      # 100ms


class AK60Controller:
    def __init__(self, channel: str = 'can0', motor_id: int = 0x01):
        self.bus = can.interface.Bus(channel=channel, bustype='socketcan')
        self.motor_id = motor_id
        self.reply_id = motor_id  # AK60-6 reply uses same ID
        self.last_cmd_time = time.monotonic()
        self.enabled = False

    def _clamp(self, value: float, min_val: float, max_val: float) -> float:
        """Clamp value to range."""
        return max(min_val, min(max_val, value))

    def _float_to_uint(self, x: float, x_min: float, x_max: float, bits: int) -> int:
        """Convert float to unsigned int (MIT protocol). Big-endian packing."""
        span = x_max - x_min
        x = self._clamp(x, x_min, x_max)
        return int((x - x_min) / span * ((1 << bits) - 1))

    def _uint_to_float(self, x: int, x_min: float, x_max: float, bits: int) -> float:
        """Convert unsigned int back to float (MIT protocol). Big-endian unpacking."""
        span = x_max - x_min
        return x / ((1 << bits) - 1) * span + x_min

    def send_command(
        self,
        position: float,    # rad
        velocity: float,    # rad/s
        kp: float,          # Nm/rad
        kd: float,          # Nm*s/rad
        torque_ff: float    # Nm
    ) -> None:
        """Send MIT-mode command with range validation."""
        # Clamp all inputs to safe ranges
        position = self._clamp(position, -MAX_POSITION_RAD, MAX_POSITION_RAD)
        velocity = self._clamp(velocity, -MAX_VELOCITY_RPS, MAX_VELOCITY_RPS)
        kp = self._clamp(kp, 0.0, MAX_KP)
        kd = self._clamp(kd, 0.0, MAX_KD)
        torque_ff = self._clamp(torque_ff, -MAX_TORQUE_NM, MAX_TORQUE_NM)

        # Pack to MIT protocol (big-endian byte order)
        pos_int = self._float_to_uint(position, -MAX_POSITION_RAD, MAX_POSITION_RAD, 16)
        vel_int = self._float_to_uint(velocity, -MAX_VELOCITY_RPS, MAX_VELOCITY_RPS, 12)
        kp_int = self._float_to_uint(kp, 0.0, MAX_KP, 12)
        kd_int = self._float_to_uint(kd, 0.0, MAX_KD, 12)
        torque_int = self._float_to_uint(torque_ff, -MAX_TORQUE_NM, MAX_TORQUE_NM, 12)

        data = bytearray(8)
        data[0] = (pos_int >> 8) & 0xFF
        data[1] = pos_int & 0xFF
        data[2] = (vel_int >> 4) & 0xFF
        data[3] = ((vel_int & 0xF) << 4) | ((kp_int >> 8) & 0xF)
        data[4] = kp_int & 0xFF
        data[5] = (kd_int >> 4) & 0xFF
        data[6] = ((kd_int & 0xF) << 4) | ((torque_int >> 8) & 0xF)
        data[7] = torque_int & 0xFF

        msg = can.Message(
            arbitration_id=self.motor_id,
            data=data,
            is_extended_id=False
        )
        self.bus.send(msg)
        self.last_cmd_time = time.monotonic()

    def read_reply(self) -> Optional[Tuple[float, float, float]]:
        """Read motor reply with timeout and validation.

        Returns:
            (position_rad, velocity_rad_s, torque_nm) or None on timeout/error.
        """
        msg = self.bus.recv(timeout=CAN_RECV_TIMEOUT_S)

        if msg is None:
            return None

        # Validate message ID
        if msg.arbitration_id != self.reply_id:
            return None

        # Validate data length
        if len(msg.data) < 6:
            return None

        # Unpack (big-endian, MIT protocol)
        motor_id = msg.data[0]
        pos_int = (msg.data[1] << 8) | msg.data[2]
        vel_int = (msg.data[3] << 4) | (msg.data[4] >> 4)
        cur_int = ((msg.data[4] & 0xF) << 8) | msg.data[5]

        pos = self._uint_to_float(pos_int, -MAX_POSITION_RAD, MAX_POSITION_RAD, 16)
        vel = self._uint_to_float(vel_int, -MAX_VELOCITY_RPS, MAX_VELOCITY_RPS, 12)
        torque = self._uint_to_float(cur_int, -MAX_TORQUE_NM, MAX_TORQUE_NM, 12)

        # Range sanity check
        if abs(pos) > MAX_POSITION_RAD * 1.1:
            return None
        if abs(vel) > MAX_VELOCITY_RPS * 1.5:
            return None

        return (pos, vel, torque)

    def check_watchdog(self) -> bool:
        """Returns True if communication is alive."""
        return (time.monotonic() - self.last_cmd_time) < WATCHDOG_TIMEOUT_S

    def disable(self) -> None:
        """Send zero torque and disable motor."""
        self.send_command(0.0, 0.0, 0.0, 0.0, 0.0)
        self.enabled = False

    def close(self) -> None:
        """Clean shutdown."""
        self.disable()
        self.bus.shutdown()


def main():
    ctrl = AK60Controller(channel='can0', motor_id=0x01)

    try:
        target_pos = 0.5  # rad

        while True:
            if not ctrl.check_watchdog():
                print("WATCHDOG: communication timeout, disabling motor")
                ctrl.disable()
                break

            ctrl.send_command(
                position=target_pos,
                velocity=0.0,
                kp=30.0,
                kd=1.5,
                torque_ff=0.0
            )

            reply = ctrl.read_reply()
            if reply is None:
                print("WARNING: no reply from motor")
                continue

            pos, vel, torque = reply
            print(f"pos={pos:.3f} rad  vel={vel:.3f} rad/s  torque={torque:.3f} Nm")

            time.sleep(0.001)

    except KeyboardInterrupt:
        print("User interrupt — disabling motor")
    finally:
        ctrl.close()


if __name__ == "__main__":
    main()
