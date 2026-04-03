// Teensy 4.1 + AK60-6 force control with load cell
// BUG: No sensor validation — NaN/spike/stuck detection missing
#include <FlexCAN_T4.h>
#include <HX711.h>

FlexCAN_T4<CAN1, RX_SIZE_256, TX_SIZE_16> can1;
HX711 loadcell;

const int HX711_DOUT = 2;
const int HX711_CLK = 3;

float force_setpoint = 5.0f;   // N
float max_torque = 6.0f;       // Nm
float force_to_torque = 0.05f; // Nm/N lever arm
float kp_force = 2.0f;

void setup() {
    can1.begin();
    can1.setBaudRate(1000000);
    loadcell.begin(HX711_DOUT, HX711_CLK);
    loadcell.set_scale(420.0f);  // Hardcoded calibration
    loadcell.tare();
    enable_motor(0x01);
}

void loop() {
    // Read force sensor — no validation at all
    float force = loadcell.get_units();

    // BUG: force could be NaN if HX711 disconnects
    // BUG: force could spike to +-1000N on noise
    // BUG: force could be stuck at 0 if wire broken

    float error = force_setpoint - force;
    float torque = kp_force * error * force_to_torque;
    torque = constrain(torque, -max_torque, max_torque);

    // If force is NaN, constrain() returns NaN -> motor gets garbage
    send_torque(0x01, torque);

    delayMicroseconds(1000);  // 1kHz
}
