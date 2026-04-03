"""
PC-side AK60-6 CAN interface via python-can.
BUG: No CAN message ID conflict check, no buffer overflow protection,
     no checksum, no byte order documentation.
"""
import can
import struct
import time

MOTOR_ID = 0x01
CMD_ID = 0x01      # BUG: Same as MOTOR_ID — ID conflict!
STATUS_ID = 0x01   # BUG: Also same — will collide on bus

bus = can.interface.Bus(channel='can0', bustype='socketcan')

def send_position_command(pos_deg: float, vel_dps: float, kp: float, kd: float, torque_ff: float):
    """Send MIT-mode command to AK60-6."""
    # BUG: No byte order comment — unclear if big/little endian
    # BUG: No range check on inputs
    pos_raw = int((pos_deg / 360.0) * 65535)
    vel_raw = int((vel_dps / 720.0) * 4095)
    kp_raw = int((kp / 500.0) * 4095)
    kd_raw = int((kd / 5.0) * 4095)
    torque_raw = int(((torque_ff + 15.0) / 30.0) * 4095)

    data = bytearray(8)
    data[0] = (pos_raw >> 8) & 0xFF
    data[1] = pos_raw & 0xFF
    data[2] = (vel_raw >> 4) & 0xFF
    data[3] = ((vel_raw & 0xF) << 4) | ((kp_raw >> 8) & 0xF)
    data[4] = kp_raw & 0xFF
    data[5] = (kd_raw >> 4) & 0xFF
    data[6] = ((kd_raw & 0xF) << 4) | ((torque_raw >> 8) & 0xF)
    data[7] = torque_raw & 0xFF

    msg = can.Message(arbitration_id=CMD_ID, data=data, is_extended_id=False)
    bus.send(msg)


def read_motor_status():
    """Read motor reply — no timeout, no validation."""
    # BUG: Blocks forever if motor doesn't reply
    msg = bus.recv()  # No timeout parameter!

    # BUG: No check if msg.arbitration_id matches expected
    # BUG: No CRC/checksum verification
    # BUG: No buffer bounds check on msg.data
    pos = (msg.data[1] << 8) | msg.data[2]
    vel = (msg.data[3] << 4) | (msg.data[4] >> 4)
    current = ((msg.data[4] & 0xF) << 8) | msg.data[5]

    return pos, vel, current


def main():
    print("Starting motor control...")

    while True:
        send_position_command(pos_deg=45.0, vel_dps=0, kp=30, kd=1.5, torque_ff=0)
        pos, vel, cur = read_motor_status()
        print(f"pos={pos} vel={vel} cur={cur}")
        time.sleep(0.001)


if __name__ == "__main__":
    main()
