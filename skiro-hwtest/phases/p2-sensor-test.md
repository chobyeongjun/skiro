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

## 카메라 / 뎁스 센서 테스트 (ZED, RealSense 등)

```python
# ZED 초기화 및 기본 테스트
import pyzed.sl as sl

def test_zed_camera(resolution='HD1080', fps=30):
    """
    ZED 카메라 초기화 & 기본 뎁스 확인
    ZED X Mini 지원 해상도: HD1080, HD1200 (HD720 미지원)
    """
    cam = sl.Camera()
    init_params = sl.InitParameters()
    init_params.camera_resolution = getattr(sl.RESOLUTION, resolution)
    init_params.camera_fps = fps
    init_params.coordinate_units = sl.UNIT.METER
    init_params.depth_mode = sl.DEPTH_MODE.ULTRA
    
    err = cam.open(init_params)
    if err != sl.ERROR_CODE.SUCCESS:
        print(f"[FAIL] ZED open: {err}")
        return False
    
    # 뎁스 맵 확인
    runtime = sl.RuntimeParameters()
    if cam.grab(runtime) == sl.ERROR_CODE.SUCCESS:
        depth = sl.Mat()
        cam.retrieve_measure(depth, sl.MEASURE.DEPTH)
        print(f"[OK] ZED depth: {depth.get_width()}x{depth.get_height()}")
    
    cam.close()
    return True
```

```python
# 3D 포인트 추출 (픽셀 → 월드 좌표)
def get_3d_point(cam, u, v):
    """픽셀 좌표 (u, v) → 3D 좌표 (미터)"""
    point_cloud = sl.Mat()
    cam.retrieve_measure(point_cloud, sl.MEASURE.XYZRGBA)
    x, y, z, _ = point_cloud.get_value(u, v)
    if any(np.isnan([x, y, z])):
        return None
    return np.array([x, y, z])
```

**합격 기준**: ZED open 성공, 뎁스 맵 비어있지 않음, 1m 거리 물체 뎁스 오차 < 5%.

## 센서 테스트 결과 기록

```
[HWTEST] 센서 확인
  IMU: OK / FAIL (가속도: <값>, 각속도: <값>)
  카메라/뎁스: OK / FAIL (해상도, 뎁스 범위)
  로드셀: OK / FAIL
  ADC/온도: OK / FAIL (<값>°C)
  전체: PASS / FAIL
```
