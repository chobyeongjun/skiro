// should-fail/printf-in-isr.cpp
// BUG: Blocking I/O (printf, serial write) called inside ISR.
// CHECKLIST: #5 Control Loop Timing — no blocking calls in real-time path.

#include "motor_driver.h"
#include <cstdio>

MotorDriver motor;
volatile float encoder_count = 0;

// Timer ISR — fires at 1kHz for control loop
void timer_isr() {
    float pos = motor.read_position();
    float vel = motor.read_velocity();
    float torque = compute_control(pos, vel);
    torque = clamp(torque, -10.0f, 10.0f);
    motor.set_torque(torque);

    // BUG: printf inside ISR — blocks on UART TX buffer full.
    // On typical MCU, printf takes 50-500us depending on string length.
    // This exceeds the ISR budget and delays other interrupts.
    printf("t=%lu pos=%.3f vel=%.3f tau=%.3f\n",
           micros(), pos, vel, torque);

    // BUG: Serial write in ISR — same blocking problem
    serial_write_float(pos);
    serial_write_float(vel);
    serial_write_float(torque);
    serial_flush();  // Waits until TX buffer is empty
}

void encoder_isr() {
    encoder_count++;
    // BUG: printf inside encoder ISR
    printf("enc=%f\n", encoder_count);
}

void setup() {
    motor.init();
    attach_timer_interrupt(timer_isr, 1000);   // 1kHz
    attach_encoder_interrupt(encoder_isr);
}

void loop() {
    // Main loop just idles
    delay_ms(100);
}
