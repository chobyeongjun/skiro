# p2-sensor-test.md — 센서 테스트
# skiro-hwtest | sensor/full tier | ~490 tok

## IMU 테스트

```bash
# 정지 상태 기준값 확인
# 가속도: x≈0, y≈0, z≈9.81 m/s²
# 각속도: 모두 ≈ 0 rad/s (노이즈 ±0.01)

# ZED X Mini IMU
python3 -c "
import pyzed.sl as sl
cam = sl.Camera()
init_params = sl.InitParameters()
cam.open(init_params)
sensors = sl.SensorsData()
cam.get_sensors_data(sensors, sl.TIME_REFERENCE.CURRENT)
imu = sensors.get_imu_data()
print('accel:', imu.get_linear_acceleration())
print('gyro:', imu.get_angular_velocity())
"
```

**합격 기준**: 가속도 z ∈ [9.71, 9.91], 각속도 절댓값 < 0.05 rad/s.

## 로드셀 테스트 (LSB205)

```
영점 확인: 하중 없을 때 출력 < ±0.5% FS
선형성: 알려진 하중 3점 측정 → 오차 < 1% FS
샘플레이트: 설정값과 실제 측정값 일치 확인
```

## ADC / 내부 온도 (STM32L432KC)

```c
// L4 시리즈 온도 계산 공식
uint16_t TS_CAL1 = *((uint16_t*)0x1FFF75A8);  // 30°C 교정값
uint16_t TS_CAL2 = *((uint16_t*)0x1FFF75CA);  // 130°C 교정값
float temp = (110.0f - 30.0f) / (TS_CAL2 - TS_CAL1) * (adc_val - TS_CAL1) + 30.0f;
// 합격: 실온(20~30°C) 범위 내
```

## 센서 테스트 결과 기록

```
[HWTEST] 센서 확인
  IMU: OK / FAIL (가속도: <값>, 각속도: <값>)
  로드셀: OK / FAIL
  ADC/온도: OK / FAIL (<값>°C)
  전체: PASS / FAIL
```
