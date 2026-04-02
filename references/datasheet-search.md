# Datasheet Search Guide

How to find and extract hardware specifications from manufacturer datasheets.
Read this when auto-generating hardware.yaml in /skiro-hwtest.

## Search Strategy

1. **Search query pattern:** `"{exact model name}" datasheet specifications`
2. **Fallback:** `"{manufacturer} {model}" technical data`
3. **Verify source:** prefer manufacturer's official site over third-party resellers

## Motor / Actuator Specs to Extract

| Field | Where to find | Common units |
|-------|--------------|-------------|
| max_torque | "Continuous torque" or "Rated torque" | Nm |
| peak_torque | "Peak torque" or "Stall torque" | Nm |
| max_velocity | "No-load speed" or "Max speed" | rad/s (convert from RPM: RPM × π/30) |
| gear_ratio | "Gear ratio" or "Reduction" | dimensionless |
| rated_voltage | "Nominal voltage" | V |
| rated_current | "Continuous current" or "Rated current" | A |
| interface | "Communication" or "Protocol" | CAN / RS485 / PWM / etc. |

### Common Motor Manufacturers

| Manufacturer | URL pattern | Notes |
|-------------|-------------|-------|
| T-Motor | store.tmotor.com | AK series (AK60-6, AK80-9, etc.) — CAN protocol |
| Robotis (Dynamixel) | emanual.robotis.com | XM/XH/XW series — RS485/TTL |
| Maxon | maxongroup.com | EC/RE series — look for "technical data" PDF |
| Oriental Motor | orientalmotor.com | Stepper/servo — look for "specifications" tab |
| Faulhaber | faulhaber.com | Brushless DC — "technical data" section |

### Unit Conversion Reference
- RPM → rad/s: multiply by π/30 (≈ 0.10472)
- oz-in → Nm: multiply by 0.00706
- lb-ft → Nm: multiply by 1.3558
- mNm → Nm: divide by 1000

## Sensor Specs to Extract

| Field | Where to find | Common units |
|-------|--------------|-------------|
| sample_rate | "Output data rate" or "ODR" or "Bandwidth" | Hz |
| range | "Full-scale range" or "Measurement range" | varies (g, °/s, N, Pa) |
| resolution | "Resolution" or "Sensitivity" or "ADC bits" | bits or physical units |
| interface | "Digital interface" or "Communication" | I2C / SPI / UART / Analog |

### Common Sensor Manufacturers

| Manufacturer | Products | Notes |
|-------------|----------|-------|
| InvenSense (TDK) | MPU-6050, ICM-42688 | IMU — check "Product Specification" PDF |
| Bosch | BNO055, BMI270, BMP390 | IMU/Pressure — "BST datasheet" |
| STMicroelectronics | LSM6DSO, LIS3DH | IMU/Accel — search st.com |
| TE Connectivity | Load cells (FX1901, FC22) | Force — "product datasheet" |
| CUI Devices | AMT102, AMT103 | Encoder — "datasheet" tab |
| Honeywell | FSS series, TBP series | Force/Pressure sensors |

## Camera Specs to Extract

| Field | Where to find |
|-------|--------------|
| resolution | "Image resolution" or "Output resolution" |
| fps | "Frame rate" at the target resolution |
| depth | "Stereo" or "Depth sensing" or "3D" capability |
| interface | "Connectivity" (USB3, GMSL2, CSI, GigE) |

### Common Robot Camera Manufacturers

| Manufacturer | Products |
|-------------|----------|
| Stereolabs | ZED 2, ZED X, ZED X Mini — stereolabs.com/docs |
| Intel RealSense | D435i, D455, L515 — intelrealsense.com |
| Luxonis | OAK-D, OAK-D Lite — docs.luxonis.com |
| FLIR / Teledyne | Blackfly, Chameleon — flir.com |

## MCU Specs to Extract

| Field | Where to find |
|-------|--------------|
| clock_mhz | "CPU frequency" or "Clock speed" |
| ram_kb | "SRAM" or "RAM" |
| flash_kb | "Flash memory" or "Program memory" |
| framework | Depends: Arduino-compatible? STM32HAL? ESP-IDF? |
| build_tool | arduino-cli / platformio / cmake / idf.py |

### Common MCU Platforms

| Platform | Build tool | Framework | Spec page |
|----------|-----------|-----------|-----------|
| Teensy 4.x | arduino-cli (teensy addon) | arduino | pjrc.com/teensy/teensy41.html |
| STM32 (Nucleo, Discovery) | platformio / cmake | stm32hal / arduino |
| ESP32 | idf.py / platformio | esp-idf / arduino |
| Arduino Mega/Due | arduino-cli | arduino |
| Raspberry Pi Pico | cmake / platformio | pico-sdk / micropython |

## Verification Checklist

After extracting specs, verify:
- [ ] Units are correct and consistent (all torque in Nm, all speed in rad/s)
- [ ] Values match between multiple sources (cross-reference 2+ sources)
- [ ] Continuous vs peak ratings are distinguished (don't mix them)
- [ ] Interface protocol matches what's actually wired (not just what's possible)
- [ ] Voltage/current ratings are compatible with the power supply
