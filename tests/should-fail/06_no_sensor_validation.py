# should-fail/06_no_sensor_validation.py
# BUG: No sensor range check — NaN/inf/out-of-range values fed to controller.
# CHECKLIST: #6 Sensor Validation — no range-checking of sensor readings.
# Python host-side control for AK60-6 via USB Serial to Teensy.

import serial
import struct
import time

SERIAL_PORT = "/dev/ttyACM0"
BAUD_RATE = 115200
MAX_TORQUE = 6.0  # Nm
KP = 50.0
KD = 2.0

def read_motor_state(ser: serial.Serial) -> dict:
    """Read position/velocity/torque from Teensy."""
    data = ser.read(12)
    pos, vel, torque = struct.unpack('<fff', data)
    # BUG: No validation — pos could be NaN, inf, or wildly out of range
    # BUG: No check for stuck sensor (same value repeated)
    # BUG: No check for noise spike (sudden jump > physical possibility)
    return {"position": pos, "velocity": vel, "torque": torque}


def compute_torque(state: dict, target_pos: float) -> float:
    """PD controller — feeds raw sensor data directly."""
    error = target_pos - state["position"]       # NaN if position is NaN
    d_error = -state["velocity"]                  # NaN if velocity is NaN
    torque = KP * error + KD * d_error            # NaN propagates
    return max(-MAX_TORQUE, min(MAX_TORQUE, torque))  # clamp does NOT catch NaN


def send_torque(ser: serial.Serial, torque: float):
    ser.write(struct.pack('<f', torque))


def main():
    ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=0.01)
    time.sleep(2)
    target = 1.0  # rad

    while True:
        state = read_motor_state(ser)
        # BUG: state["position"] could be NaN — no check before using
        torque = compute_torque(state, target)
        # BUG: if torque is NaN, clamp returns NaN, sent to motor
        send_torque(ser, torque)
        time.sleep(0.001)


if __name__ == "__main__":
    main()
