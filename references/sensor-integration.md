# Sensor Integration Patterns

> 센서 퓨전, 캘리브레이션, 데이터 전처리 패턴 모음.
> 로보틱스에서 자주 사용하는 IMU, 엔코더, 힘센서, 거리센서, 카메라 통합.
> 각 패턴에 코드 예시와 grep 감지 포함.

---

## 목차

1. [IMU 통합](#1-imu-통합)
2. [힘/토크 센서](#2-힘토크-센서)
3. [엔코더 통합](#3-엔코더-통합)
4. [센서 퓨전](#4-센서-퓨전)
5. [캘리브레이션](#5-캘리브레이션)
6. [데이터 전처리](#6-데이터-전처리)
7. [통신/동기화](#7-통신동기화)

---

## 1. IMU 통합

### I01: 자이로 드리프트 미보상

자이로스코프만 적분하면 바이어스 때문에 시간에 따라 각도 드리프트.

```python
# BAD — 자이로만 적분
angle += gyro_z * dt  # 바이어스 0.1 deg/s → 1분에 6도 오차

# GOOD — 상보 필터 (자이로 + 가속도계)
alpha = 0.98
angle = alpha * (angle + gyro_z * dt) + (1 - alpha) * accel_angle
# 또는 칼만 필터 / Madgwick 필터
```

**grep 감지:** `grep -rn "angle\s*+=\s*gyro\|angle\s*=\s*angle\s*+\s*gyro" --include="*.c" --include="*.cpp" --include="*.py" | grep -v "accel\|mag\|complement\|kalman\|madgwick\|mahony"`

---

### I02: 가속도계 기반 각도의 진동 문제

동적 움직임 중 가속도계는 중력 + 가속도를 합산 → 각도 오류.

```python
# BAD — 동적 상황에서 가속도계만 사용
pitch = math.atan2(accel_x, accel_z)  # 로봇 이동 중 부정확

# GOOD — 가속도 크기 검증 후 사용
accel_mag = math.sqrt(accel_x**2 + accel_y**2 + accel_z**2)
if abs(accel_mag - 9.81) < 1.0:  # 중력 근처일 때만 신뢰
    accel_valid = True
    pitch_accel = math.atan2(accel_x, accel_z)
else:
    accel_valid = False  # 자이로만 사용
```

**grep 감지:** `grep -rn "atan2.*accel" --include="*.c" --include="*.cpp" --include="*.py" | grep -v "mag\|magnitude\|valid\|check\|norm"`

---

### I03: 자기장 간섭 무시

IMU 근처에 모터, 전선이 있으면 자력계 데이터 오염.

```python
# BAD — 보정 없이 자력계 사용
heading = math.atan2(mag_y, mag_x)

# GOOD — 하드/소프트 아이언 보정
mag_corrected = np.dot(soft_iron_matrix, np.array([mag_x, mag_y, mag_z]) - hard_iron_offset)
heading = math.atan2(mag_corrected[1], mag_corrected[0])
```

**grep 감지:** `grep -rn "atan2.*mag\|heading.*mag" --include="*.c" --include="*.cpp" --include="*.py" | grep -v "calibrat\|correct\|offset\|iron\|compensat"`

---

### I04: IMU 축 정렬 오류

IMU가 기판에 비스듬히 장착되어 좌표축이 로봇 프레임과 불일치.

```c
// BAD — IMU 방향 가정
float pitch = imu_data.pitch;  // IMU가 90도 회전 장착이면 roll과 혼동

// GOOD — 마운팅 회전 보정
// R_body_from_imu를 정의하여 변환
float body_gyro[3];
mat3_mul_vec3(R_body_from_imu, imu_data.gyro, body_gyro);
float body_accel[3];
mat3_mul_vec3(R_body_from_imu, imu_data.accel, body_accel);
```

**grep 감지:** `grep -rn "imu.*pitch\|imu.*roll\|imu.*yaw\|imu_data\." --include="*.c" --include="*.cpp" | grep -v "rotation\|R_\|transform\|mount\|align"`

---

## 2. 힘/토크 센서

### F01: 힘 센서 0점 드리프트

온도 변화로 0점이 이동, 보정하지 않으면 DC 오프셋.

```python
# BAD
force = adc_to_force(read_adc())

# GOOD — 시작 시 태어(tare) + 주기적 재보정
if state == IDLE and abs(velocity) < 0.001:
    force_offset = 0.99 * force_offset + 0.01 * adc_to_force(read_adc())
force = adc_to_force(read_adc()) - force_offset
```

**grep 감지:** `grep -rn "read_adc\|read_force\|get_force" --include="*.c" --include="*.cpp" --include="*.py" -A 2 | grep -v "offset\|tare\|zero\|bias\|calibrat"`

---

### F02: 중력 보상 없음

힘 센서 아래에 질량이 있으면 자세에 따라 중력 성분이 달라짐.

```python
# BAD — 자세 무관하게 원시 힘 사용
force_z = read_force_z()  # 수평: 0, 수직: -mg

# GOOD — 자세에 따른 중력 보상
R = get_rotation_matrix()  # 현재 엔드이펙터 자세
gravity_compensation = R @ np.array([0, 0, -tool_mass * 9.81])
force_compensated = force_raw - gravity_compensation
```

**grep 감지:** `grep -rn "force_z\|force_x\|force_y\|wrench" --include="*.c" --include="*.cpp" --include="*.py" | grep -v "gravity\|compensat\|weight\|mass\s*\*"`

---

### F03: 힘 센서 과부하 미감지

측정 범위 초과 시 데이터가 포화되지만 코드에서 무시.

```c
// BAD
float force = read_force();
apply_impedance_control(force);

// GOOD — 범위 검증
float force = read_force();
if (fabsf(force) > FORCE_SENSOR_MAX_RANGE * 0.95f) {
    log_warning("force sensor near saturation: %.1f N", force);
    if (fabsf(force) >= FORCE_SENSOR_MAX_RANGE) {
        enter_safe_state();  // 센서 포화 → 실제 힘 불명 → 안전 모드
        return;
    }
}
```

**grep 감지:** `grep -rn "read_force\|get_force\|load_cell" --include="*.c" --include="*.cpp" -A 3 | grep -v "range\|saturat\|max\|overflow\|limit"`

---

### F04: 6축 힘/토크 센서 크로스토크

한 축의 힘이 다른 축 측정에 영향, 캘리브레이션 행렬 미적용.

```python
# BAD — 원시 채널 값 직접 사용
Fx = ch0 * scale_x
Fy = ch1 * scale_y
Fz = ch2 * scale_z

# GOOD — 캘리브레이션 행렬 적용
raw = np.array([ch0, ch1, ch2, ch3, ch4, ch5])
wrench = calibration_matrix @ (raw - zero_offset)
# calibration_matrix: 6x6 디커플링 행렬 (제조사 제공)
```

**grep 감지:** `grep -rn "ch[0-5]\s*\*\s*scale\|channel\[.\]\s*\*" --include="*.c" --include="*.cpp" --include="*.py" | grep -v "matrix\|calibrat\|decouple"`

---

## 3. 엔코더 통합

### E01: 전기 노이즈로 인한 카운트 점프

긴 엔코더 케이블이나 모터 PWM 노이즈가 가짜 엣지 생성.

```c
// BAD — 원시 카운트 직접 사용
int32_t velocity = current_count - prev_count;  // 노이즈 스파이크

// GOOD — 이동 중앙값/중앙값 필터
int32_t raw_diff = current_count - prev_count;
velocity = median_filter_3(raw_diff, prev_diff_1, prev_diff_2);
```

**grep 감지:** `grep -rn "count\s*-\s*prev" --include="*.c" --include="*.cpp" -A 1 | grep -v "median\|filter\|smooth\|check\|valid"`

---

### E02: 인덱스 펄스 미활용

절대 위치 리셋 없이 증분 엔코더만 사용 → 누적 오차.

```c
// BAD — 인덱스 펄스 무시
void encoder_isr(void) {
    if (A_rising) count++;
    // 인덱스 핀 무시
}

// GOOD — 인덱스 펄스로 주기적 리셋
void encoder_isr(void) {
    if (A_rising) count++;
    if (index_pulse) {
        int32_t expected = round_to_nearest_revolution(count);
        if (abs(count - expected) > MAX_INDEX_ERROR) {
            log_warning("encoder drift detected: %d", count - expected);
        }
        count = expected;  // 리셋
    }
}
```

**grep 감지:** `grep -rn "encoder.*isr\|encoder.*interrupt\|encoder.*callback" --include="*.c" --include="*.cpp" | grep -v "index\|Z_pin\|home"`

---

## 4. 센서 퓨전

### SF01: 상보 필터 시정수 부적절

알파가 너무 높으면 자이로 드리프트 보상 느림, 너무 낮으면 진동에 취약.

```python
# BAD — 고정 알파, 튜닝 없음
alpha = 0.5  # 너무 낮음 → 가속도계 노이즈에 취약

# GOOD — 물리적으로 의미 있는 시정수
tau = 1.0  # 초: 자이로 신뢰 구간
alpha = tau / (tau + dt)
# tau가 크면 자이로 신뢰 ↑, 작으면 가속도계 신뢰 ↑
angle = alpha * (angle + gyro * dt) + (1 - alpha) * accel_angle
```

**grep 감지:** `grep -rn "alpha\s*=\s*0\.[0-9]" --include="*.c" --include="*.cpp" --include="*.py" -B 2 | grep -i "filter\|complement"`

---

### SF02: 칼만 필터 프로세스 노이즈 미튜닝

Q, R 행렬을 적절히 설정하지 않으면 필터가 센서를 무시하거나 과신뢰.

```python
# BAD — 기본값 사용
Q = np.eye(n) * 0.01  # 프로세스 노이즈 — 의미 없는 기본값
R = np.eye(m) * 0.01  # 측정 노이즈

# GOOD — 물리적 근거
# Q: 모델 불확실성 (가속도 noise * dt^2 등)
# R: 센서 사양서의 노이즈 밀도
accel_noise_density = 0.003  # g/sqrt(Hz), 데이터시트에서
R_accel = (accel_noise_density * 9.81)**2 / fs  # 분산
```

**grep 감지:** `grep -rn "np.eye\|np.identity\|diag" --include="*.py" -A 1 | grep -E "Q\s*=|R\s*=|process_noise|measurement_noise" | grep -v "datasheet\|spec\|density\|variance"`

---

### SF03: 센서 고장 시 퓨전 출력 신뢰

센서 하나가 고장나도 퓨전 결과를 그대로 사용.

```python
# BAD — 이상치 검출 없음
fused = kalman_update(gyro, accel, mag)

# GOOD — 이상치 검출 및 센서 제외
accel_mag = np.linalg.norm(accel)
if abs(accel_mag - 9.81) > 5.0:
    # 가속도계 이상 → 자이로만 사용
    fused = gyro_only_predict()
    sensor_fault_flags |= ACCEL_FAULT
else:
    fused = kalman_update(gyro, accel, mag)
```

**grep 감지:** `grep -rn "kalman_update\|complementary_filter\|madgwick\|mahony" --include="*.c" --include="*.cpp" --include="*.py" | grep -v "fault\|valid\|check\|sanity\|outlier"`

---

## 5. 캘리브레이션

### C01: 캘리브레이션 데이터 만료

한 번 캘리브레이션하고 영구 사용 → 온도/마모에 의한 드리프트.

```python
# BAD
calibration_data = load_calibration("cal_2023.json")

# GOOD — 만료 날짜 확인
cal = load_calibration("cal_latest.json")
days_since_cal = (datetime.now() - cal['timestamp']).days
if days_since_cal > MAX_CAL_AGE_DAYS:
    log_warning(f"calibration is {days_since_cal} days old, recalibrate!")
    if days_since_cal > CRITICAL_CAL_AGE_DAYS:
        raise CalibrationExpiredError()
```

**grep 감지:** `grep -rn "load_calibration\|read_cal\|calibration_file" --include="*.py" --include="*.c" | grep -v "timestamp\|date\|age\|expire\|valid"`

---

### C02: 캘리브레이션 순서 오류

IMU 캘리브레이션 전에 모터를 켜면 진동이 바이어스에 포함.

```python
# BAD — 모터 가동 중 캘리브레이션
start_motors()
calibrate_imu()  # 모터 진동이 가속도계 바이어스에 포함

# GOOD — 정지 상태에서 캘리브레이션
stop_motors()
time.sleep(2.0)  # 진동 감쇠 대기
calibrate_imu()
start_motors()
```

**grep 감지:** `grep -rn "calibrate\|cal_start" --include="*.py" --include="*.c" -B 5 | grep -i "motor.*start\|enable.*motor\|motor.*on"`

---

### C03: 단일 조건 캘리브레이션

하나의 온도/자세에서만 캘리브레이션 → 다른 조건에서 오차.

```python
# BAD
bias = measure_bias_at_rest()  # 25도, 수평에서만

# GOOD — 다중 조건 캘리브레이션
biases = {}
for temp in [15, 25, 35, 45]:
    set_temperature_chamber(temp)
    wait_for_stable_temp()
    biases[temp] = measure_bias()

# 운용 시 온도 기반 보간
current_bias = interpolate_bias(biases, current_temp)
```

**grep 감지:** `grep -rn "bias\s*=\s*measure\|offset\s*=\s*read" --include="*.py" --include="*.c" | grep -v "temp\|temperature\|multi\|interpolat"`

---

## 6. 데이터 전처리

### D01: 필터 초기화 미처리

필터 내부 상태가 0으로 시작하면 초기 transient 발생.

```c
// BAD — 0으로 초기화된 필터
float filtered_value = 0.0f;
void update_filter(float raw) {
    filtered_value = alpha * raw + (1 - alpha) * filtered_value;
    // 첫 번째 읽기에서 큰 점프
}

// GOOD — 첫 값으로 초기화
bool filter_initialized = false;
void update_filter(float raw) {
    if (!filter_initialized) {
        filtered_value = raw;
        filter_initialized = true;
    } else {
        filtered_value = alpha * raw + (1 - alpha) * filtered_value;
    }
}
```

**grep 감지:** `grep -rn "filtered.*=\s*0\.0\|lpf.*=\s*0\|smooth.*=\s*0" --include="*.c" --include="*.cpp" | grep -v "init\|first\|reset"`

---

### D02: 이동 평균에 의한 위상 지연 무시

N-포인트 이동 평균은 (N-1)/2 샘플의 지연 → 제어 루프에서 위상 지연.

```c
// BAD — 제어 루프에서 긴 이동 평균
#define WINDOW 64
float moving_avg(float *buf, int n) {
    float sum = 0;
    for (int i = 0; i < n; i++) sum += buf[i];
    return sum / n;
}
// 64 샘플 @ 1kHz → 31.5ms 지연 → 고대역 제어 불안정

// GOOD — 지연이 적은 필터 (1차 IIR)
// 또는 이동 평균 크기를 제어 대역폭에 맞게 제한
```

**grep 감지:** `grep -rn "moving_avg\|WINDOW\s*=\s*[0-9][0-9]" --include="*.c" --include="*.h" | grep -v "delay_ms\|latency\|phase"`

---

### D03: ADC 분해능과 물리량 매핑 오류

스케일링 팩터에 ADC 비트 수를 잘못 적용.

```c
// BAD — 12비트 ADC를 10비트로 계산
float voltage = adc_raw / 1024.0f * 3.3f;  // 12비트는 4096!

// GOOD
#define ADC_RESOLUTION  4096  // 12-bit
#define ADC_VREF        3.3f
float voltage = (float)adc_raw / ADC_RESOLUTION * ADC_VREF;
```

**grep 감지:** `grep -rn "/ 1024\|/ 1023\|/ 4096\|/ 4095\|/ 65535\|/ 65536" --include="*.c" --include="*.cpp" | grep -v "ADC_RESOLUTION\|ADC_MAX\|define"`

---

### D04: 센서 데이터 타임스탬프 누락

여러 센서 데이터를 모을 때 각각의 시점 정보가 없으면 시간 정렬 불가.

```python
# BAD — 타임스탬프 없는 데이터
data = {'imu': read_imu(), 'force': read_force(), 'encoder': read_encoder()}

# GOOD — 개별 타임스탬프
data = {
    'imu': {'value': read_imu(), 'timestamp': time.monotonic()},
    'force': {'value': read_force(), 'timestamp': time.monotonic()},
    'encoder': {'value': read_encoder(), 'timestamp': time.monotonic()},
}
```

**grep 감지:** `grep -rn "read_imu\|read_force\|read_encoder\|read_sensor" --include="*.py" --include="*.c" | grep -v "timestamp\|time\|clock\|tick"`

---

## 7. 통신/동기화

### T01: 멀티센서 샘플링 동기화 미처리

여러 센서를 순차 읽기하면 시간 차이 발생.

```c
// BAD — 순차 읽기 (각각 1ms 지연)
imu = read_imu();        // t = 0ms
force = read_force();    // t = 1ms
encoder = read_encoder(); // t = 2ms
// 2ms 시간 차이 → 1kHz 제어에서 문제

// GOOD — 동시 트리거 + DMA
trigger_all_sensors();   // 하드웨어 트리거
wait_for_all_ready();
imu = get_imu_buffer();
force = get_force_buffer();
encoder = get_encoder_buffer();  // 모두 같은 시점
```

**grep 감지:** `grep -rn "read_imu\|read_force\|read_encoder" --include="*.c" -A 2 | grep "read_" | head -20`

---

### T02: 센서 I2C 주소 충돌

같은 I2C 버스에 동일 주소 장치 연결.

```c
// BAD — 두 IMU가 같은 기본 주소
imu1 = i2c_read(0x68, ...);  // MPU6050 기본
imu2 = i2c_read(0x68, ...);  // 같은 주소 → 데이터 혼재

// GOOD — AD0 핀으로 주소 변경 확인
#define IMU1_ADDR  0x68  // AD0 = LOW
#define IMU2_ADDR  0x69  // AD0 = HIGH
imu1 = i2c_read(IMU1_ADDR, ...);
imu2 = i2c_read(IMU2_ADDR, ...);
```

**grep 감지:** `grep -rn "0x68\|0x69\|0x1E\|0x53\|0x29" --include="*.c" --include="*.h" | awk -F: '{print $3}' | sort | uniq -d`

---

### T03: SPI 클럭 과속

센서 데이터시트의 최대 SPI 클럭을 초과하면 데이터 오류.

```c
// BAD — 센서 최대 10MHz인데 18MHz로 설정
SPI_InitStruct.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_4;
// 72MHz / 4 = 18MHz → 데이터 오류

// GOOD — 데이터시트 확인 후 설정
// 센서 최대 10MHz → 72MHz / 8 = 9MHz
SPI_InitStruct.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_8;
```

**grep 감지:** `grep -rn "BAUDRATEPRESCALER_2\b\|BAUDRATEPRESCALER_4\b" --include="*.c" --include="*.h"`

---

## 빠른 참조 — 전체 grep 스캔

```bash
echo "=== I01: 자이로 드리프트 ==="
grep -rn "angle.*+=.*gyro" --include="*.c" --include="*.cpp" --include="*.py" | grep -v "accel\|complement\|kalman"

echo "=== F01: 힘 센서 0점 ==="
grep -rn "read_force\|get_force" --include="*.c" --include="*.py" -A 2 | grep -v "offset\|tare\|zero\|bias"

echo "=== D03: ADC 스케일링 ==="
grep -rn "/ 1024\|/ 4096\|/ 65536" --include="*.c" --include="*.cpp" | grep -v "ADC_RESOLUTION\|define"

echo "=== D04: 타임스탬프 누락 ==="
grep -rn "read_imu\|read_force\|read_sensor" --include="*.py" --include="*.c" | grep -v "timestamp\|time\|clock"
```

---

## 심각도 등급

| 등급 | 패턴 | 영향 |
|------|-------|------|
| CRITICAL | F03, SF03, T01 | 안전 위험/제어 불안정 |
| HIGH | I01, I04, F01, F02, F04, E01, D03 | 측정 오류/제어 품질 저하 |
| MEDIUM | I02, I03, E02, SF01, SF02, C01-C03, D01, D02, D04, T02, T03 | 정밀도 저하/유지보수 |
