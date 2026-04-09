# Motor Control Bug Patterns

> 모터 제어에서 반복적으로 발생하는 실수 패턴 모음.
> 범용 DC/BLDC/스테퍼 모터 제어에 적용. 각 패턴에 코드 예시, grep 감지 포함.

## INDEX
<!-- skiro: machine-readable index for selective loading -->
<!-- skiro: machine-readable index. Line = actual line number in this file. -->
| ID | 패턴 | 트리거 키워드 | Line |
|----|------|-------------|------|
| M01 | 토크 제한 없음 | set_torque, set_current, set_force, CLAMP, MAX_TORQUE | 48 |
| M02 | 전류 제한 소프트웨어 의존 | MAX_CURRENT, current_limit, overcurrent, disable_motor | 67 |
| M03 | PWM 듀티 100% 허용 | set_pwm_duty, CCR, duty, ARR, MAX_DUTY | 90 |
| M04 | 급격한 명령 변화 | set_velocity, set_position, rate_limit, ramp, slew | 113 |
| M05 | 적분기 와인드업 | integral, anti-windup, CLAMP, INTEGRAL_MAX | 140 |
| M06 | 미분 항 Derivative Kick | prev_error, last_error, derivative, measurement | 162 |
| M07 | 미분 항 필터 없음 | prev_measurement, derivative, alpha, lpf, filter | 178 |
| M08 | dt = 0 처리 없음 | dt, delta_t, divide, derivative | 196 |
| M09 | 게인 스케줄링 없음 | Kp, Ki, Kd, gain_schedule, lookup | 215 |
| M10 | 제어 루프-필터 불일치 | CUTOFF, cutoff_freq, CONTROL_FREQ, nyquist | 238 |
| M11 | 엔코더 오버플로우 | encoder_count, prev_count, int16_t, overflow, wrap | 258 |
| M12 | 엔코더 방향 오류 | direction, count, deadband, dead_band, threshold | 276 |
| M13 | 다중 회전 추적 없음 | encoder_raw, CPR, multi_turn, total_counts, angle | 297 |
| M14 | 브레이크/코스팅 혼동 | stop_motor, motor_stop, brake, coast, set_both_low | 318 |
| M15 | 방향 전환 데드타임 없음 | set_direction, REVERSE, FORWARD, dead_time, ramp | 341 |
| M16 | Enable 핀 누락 | motor_init, motor_enable, motor_disable, EN_PIN | 365 |
| M17 | 통신 타임아웃 없음 | can_send, spi_write, timeout, comm_fail, safe_state | 391 |
| M18 | 온도 모니터링 없음 | temperature, temp_limit, overtemp, thermal, derate | 422 |
| M19 | 소프트 리밋 없음 | set_position, set_angle, JOINT_MIN, JOINT_MAX, CLAMP | 452 |
| M20 | 엔코더 단선 미감지 | encoder, disconnect, unchanged_count, FAULT_ENCODER | 472 |
| M21 | 전원 차단 안전 상태 미정의 | motor_init, restore_last_state, clear_all_commands | 498 |
| M22 | 과속도 보호 없음 | motor_speed, read_speed, MAX_SPEED_RPM, overspeed | 521 |

---

## 카테고리

1. [토크/전류 제한](#1-토크전류-제한)
2. [PID 제어](#2-pid-제어)
3. [엔코더/피드백](#3-엔코더피드백)
4. [모터 드라이버 인터페이스](#4-모터-드라이버-인터페이스)
5. [안전/보호](#5-안전보호)

---

## 1. 토크/전류 제한

### M01: 토크/힘 제한 없는 제어 출력

PID 출력을 직접 모터에 전달하면 과도한 토크/전류 발생.

```c
// BAD — 제한 없는 출력
float torque_cmd = pid_compute(&pid, setpoint, feedback);
motor_set_torque(torque_cmd);  // torque_cmd가 무한대가 될 수 있음

// GOOD — 반드시 클램핑
float torque_cmd = pid_compute(&pid, setpoint, feedback);
torque_cmd = CLAMP(torque_cmd, -MAX_TORQUE_NM, MAX_TORQUE_NM);
motor_set_torque(torque_cmd);
```

**grep 감지:** `grep -rn "set_torque\|set_current\|write_pwm\|set_force" --include="*.c" --include="*.cpp" -B 3 | grep -v "clamp\|CLAMP\|limit\|min\|max\|constrain\|saturate"`

---

### M02: 전류 제한의 소프트웨어 의존

하드웨어 전류 제한 없이 소프트웨어만으로 보호.

```c
// BAD — 소프트웨어 전류 제한만 의존
if (measured_current > MAX_CURRENT) {
    set_pwm(0);  // 소프트웨어가 죽으면 보호 불가
}

// GOOD — 하드웨어 + 소프트웨어 이중 보호
// 1) 하드웨어: 비교기 회로로 과전류 시 드라이버 자동 셧다운
// 2) 소프트웨어: 추가 모니터링
if (measured_current > SW_CURRENT_LIMIT) {
    disable_motor();
    log_fault(FAULT_OVERCURRENT);
}
```

**grep 감지:** `grep -rn "MAX_CURRENT\|current_limit\|overcurrent" --include="*.c" --include="*.h" | grep -v "hardware\|hw_\|comparator\|fuse"`

---

### M03: PWM 듀티사이클 100% 허용

듀티 100%는 부트스트랩 커패시터 충전 불가 → 하이사이드 FET 드롭아웃.

```c
// BAD
void set_pwm_duty(float duty) {
    TIM->CCR1 = (uint32_t)(duty * TIM->ARR);  // duty=1.0 허용
}

// GOOD — 최대 듀티 제한
#define MAX_DUTY  0.95f
void set_pwm_duty(float duty) {
    if (duty > MAX_DUTY) duty = MAX_DUTY;
    if (duty < 0.0f) duty = 0.0f;
    TIM->CCR1 = (uint32_t)(duty * TIM->ARR);
}
```

**grep 감지:** `grep -rn "CCR[0-9]\s*=\|duty\s*\*\s*ARR" --include="*.c" | grep -v "MAX_DUTY\|max_duty\|0\.9"`

---

### M04: 급격한 명령 변화 (Jerk 미제한)

위치/속도 명령이 순간적으로 크게 변하면 기계적 충격.

```c
// BAD
motor_set_velocity(target_velocity);  // 즉시 변경

// GOOD — Rate limiter 적용
float limited_velocity = rate_limit(
    current_cmd, target_velocity, MAX_ACCEL * dt);
motor_set_velocity(limited_velocity);

float rate_limit(float current, float target, float max_change) {
    float delta = target - current;
    if (delta > max_change) delta = max_change;
    if (delta < -max_change) delta = -max_change;
    return current + delta;
}
```

**grep 감지:** `grep -rn "set_velocity\|set_position\|set_speed" --include="*.c" --include="*.cpp" -B 3 | grep -v "rate_limit\|ramp\|slew\|accel\|smooth"`

---

## 2. PID 제어

### M05: 적분기 와인드업

큰 에러가 오래 지속되면 적분 항이 과도하게 쌓여 오버슈트.

```c
// BAD
pid->integral += error * dt;
float output = Kp*error + Ki*pid->integral + Kd*derivative;

// GOOD — Anti-windup 클램핑
pid->integral += error * dt;
pid->integral = CLAMP(pid->integral, -INTEGRAL_MAX, INTEGRAL_MAX);
// 또는 조건부 적분 (출력 포화 시 적분 중지)
if (fabsf(output) < OUTPUT_MAX) {
    pid->integral += error * dt;
}
```

**grep 감지:** `grep -rn "integral\s*+=\|integral\s*=\s*integral\s*+" --include="*.c" --include="*.cpp" -A 2 | grep -v "clamp\|CLAMP\|limit\|max\|min\|wind"`

---

### M06: 미분 항에 원시 에러 사용 (Derivative Kick)

setpoint 변경 시 에러가 불연속적으로 변해 미분 항이 스파이크.

```c
// BAD — 에러의 미분
float derivative = (error - prev_error) / dt;

// GOOD — 피드백의 미분 (setpoint는 빠지므로 스파이크 없음)
float derivative = -(measurement - prev_measurement) / dt;
```

**grep 감지:** `grep -rn "error\s*-\s*prev_error\|error\s*-\s*last_error" --include="*.c" --include="*.cpp"`

---

### M07: 미분 항 필터 없음

노이즈가 많은 피드백에서 미분이 발산.

```c
// BAD — 필터 없는 미분
float derivative = (measurement - prev_measurement) / dt;

// GOOD — 저역통과 필터 적용
float raw_deriv = (measurement - prev_measurement) / dt;
float alpha = dt / (tau + dt);  // tau = 1/(2*pi*cutoff_freq)
filtered_deriv = alpha * raw_deriv + (1.0f - alpha) * filtered_deriv;
```

**grep 감지:** `grep -rn "prev_measurement\|prev_position\|prev_angle" --include="*.c" --include="*.cpp" -A 2 | grep "/ dt\|/ delta" | grep -v "filter\|alpha\|lpf\|smooth"`

---

### M08: dt = 0 처리 없음

제어 주기가 0일 때 나누기 에러.

```c
// BAD
float derivative = (error - prev_error) / dt;

// GOOD
float derivative = 0.0f;
if (dt > 1e-9f) {
    derivative = (error - prev_error) / dt;
}
```

**grep 감지:** `grep -rn "/ dt\b\|/ delta_t\b" --include="*.c" --include="*.cpp" -B 2 | grep -v "if.*dt\|dt\s*[>!]"`

---

### M09: 게인 스케줄링 없이 넓은 동작 범위

단일 PID 게인으로 전 범위 제어 → 특정 영역에서 불안정.

```c
// BAD
float Kp = 10.0f;  // 모든 속도에서 동일

// GOOD — 속도/부하에 따른 게인 스케줄링
float Kp;
if (motor_speed < LOW_SPEED_THRESH) {
    Kp = KP_LOW_SPEED;
} else if (motor_speed < HIGH_SPEED_THRESH) {
    Kp = KP_MID_SPEED;
} else {
    Kp = KP_HIGH_SPEED;
}
```

**grep 감지:** `grep -rn "float\s\+Kp\s*=\|#define\s\+KP\s" --include="*.c" --include="*.h" | grep -v "schedule\|table\|lookup\|array"`

---

### M10: 제어 루프 주기와 필터 불일치

필터 시정수가 제어 주기보다 짧으면 필터가 무의미.

```c
// BAD — 1kHz 제어 루프에서 10kHz 컷오프 필터
#define CONTROL_FREQ  1000  // Hz
#define FILTER_CUTOFF 10000 // Hz — 나이퀴스트 위반

// GOOD — 컷오프 < 제어 주파수/2
#define CONTROL_FREQ  1000  // Hz
#define FILTER_CUTOFF 200   // Hz (나이퀴스트 500Hz 이하)
```

**grep 감지:** `grep -rn "CUTOFF\|cutoff_freq\|filter_freq" --include="*.c" --include="*.h" -A 2 | grep "[0-9]"`

---

## 3. 엔코더/피드백

### M11: 엔코더 카운트 오버플로우 미처리

16/32비트 카운터 wrap-around에서 속도 계산 오류.

```c
// BAD
int16_t velocity = current_count - previous_count;
// count가 32767 → -32768로 점프하면 velocity 잘못됨

// GOOD — overflow-safe 차이 계산
int16_t velocity = (int16_t)(current_count - previous_count);
// int16_t 뺄셈은 자동으로 2's complement wrap 처리
```

**grep 감지:** `grep -rn "count\s*-\s*prev.*count\|encoder.*-.*last" --include="*.c" --include="*.cpp" | grep -v "int16_t\|overflow\|wrap"`

---

### M12: 노이즈로 인한 엔코더 방향 오류

저속에서 노이즈 카운트가 방향 반전을 유발.

```c
// BAD — 단순 차이로 방향 판단
int direction = (count > prev_count) ? 1 : -1;

// GOOD — 데드밴드 적용
int diff = count - prev_count;
if (abs(diff) < ENCODER_DEADBAND) {
    velocity = 0;
} else {
    velocity = diff;
}
```

**grep 감지:** `grep -rn "direction.*count\|count.*direction" --include="*.c" --include="*.cpp" | grep -v "deadband\|dead_band\|threshold"`

---

### M13: 다중 회전 추적 없음

절대 엔코더 범위를 초과하는 회전을 추적하지 않음.

```c
// BAD
float angle = (float)encoder_raw / CPR * 360.0f;  // 0~360도만

// GOOD — 누적 회전 추적
static int32_t total_counts = 0;
int16_t delta = (int16_t)(encoder_raw - prev_raw);
total_counts += delta;
float angle = (float)total_counts / CPR * 360.0f;  // 연속 각도
```

**grep 감지:** `grep -rn "encoder_raw\s*/\s*CPR\|raw.*360" --include="*.c" --include="*.cpp" | grep -v "total\|accumulated\|multi_turn"`

---

## 4. 모터 드라이버 인터페이스

### M14: 브레이크 모드/코스팅 모드 혼동

모터 정지 시 Hi-Z(코스팅)와 브레이크(양쪽 로우)를 구분하지 않으면 로봇이 미끄러짐.

```c
// BAD — 항상 PWM 0으로만 정지
void stop_motor(void) {
    set_pwm(0);  // 코스팅 → 관성으로 계속 움직임
}

// GOOD — 용도에 따라 구분
void brake_motor(void) {
    set_both_low();  // 양쪽 FET LOW → 동적 브레이크
}
void coast_motor(void) {
    set_both_hiz();  // Hi-Z → 프리휠
}
```

**grep 감지:** `grep -rn "stop_motor\|motor_stop\|pwm.*=.*0" --include="*.c" | grep -v "brake\|coast\|mode"`

---

### M15: 모터 방향 전환 시 데드타임 없음

정방향→역방향 순간 전환은 슈팅(shoot-through) 위험.

```c
// BAD
void reverse_motor(void) {
    set_direction(REVERSE);  // 즉시 반전 → 모터/드라이버 스트레스
    set_pwm(duty);
}

// GOOD — 감속 → 정지 → 역방향
void reverse_motor(void) {
    ramp_to_zero();
    delay_us(DEADTIME_US);  // 데드타임 대기
    set_direction(REVERSE);
    ramp_to_target();
}
```

**grep 감지:** `grep -rn "set_direction\|REVERSE\|FORWARD" --include="*.c" --include="*.cpp" -B 3 | grep -v "ramp\|dead_time\|delay\|decel"`

---

### M16: Enable 핀 제어 누락

드라이버 Enable 핀을 제어하지 않으면 초기화 중 모터 오동작.

```c
// BAD
void motor_init(void) {
    configure_pwm();
    configure_encoder();
    // enable 핀 미제어 → 드라이버가 이미 활성 상태일 수 있음
}

// GOOD
void motor_init(void) {
    motor_disable();          // 먼저 비활성화
    configure_pwm();
    configure_encoder();
    set_pwm(0);              // PWM 0 확인
    motor_enable();           // 안전하게 활성화
}
```

**grep 감지:** `grep -rn "motor_init\|Motor_Init\|init_motor" --include="*.c" -A 10 | grep -v "disable\|enable.*LOW\|EN_PIN"`

---

### M17: 통신 타임아웃 없는 모터 드라이버

CAN/SPI 모터 드라이버와의 통신 실패 시 마지막 명령으로 계속 동작.

```c
// BAD
void motor_control_loop(void) {
    float cmd = compute_control();
    can_send_torque(cmd);  // 실패해도 모터는 이전 명령 유지
}

// GOOD — 타임아웃 기반 안전 정지
void motor_control_loop(void) {
    float cmd = compute_control();
    if (!can_send_torque(cmd)) {
        comm_fail_count++;
        if (comm_fail_count > MAX_COMM_FAILS) {
            enter_safe_state();  // 통신 연속 실패 → 안전 정지
        }
    } else {
        comm_fail_count = 0;
    }
}
```

**grep 감지:** `grep -rn "can_send\|spi_write.*motor\|uart_send.*cmd" --include="*.c" -A 2 | grep -v "if\|fail\|error\|timeout\|retry"`

---

## 5. 안전/보호

### M18: 온도 모니터링 없음

모터/드라이버 온도를 감시하지 않아 과열 손상.

```c
// BAD
void control_loop(void) {
    motor_set_torque(pid_output);
    // 온도 확인 없음
}

// GOOD
void control_loop(void) {
    float temp = read_motor_temperature();
    if (temp > MOTOR_TEMP_WARN) {
        derate_torque_limit(temp);
    }
    if (temp > MOTOR_TEMP_CRITICAL) {
        disable_motor();
        log_fault(FAULT_OVERTEMP);
        return;
    }
    motor_set_torque(pid_output);
}
```

**grep 감지:** `grep -rLn "temperature\|temp_limit\|overtemp\|thermal" --include="*.c" --include="*.h"`

---

### M19: 위치 제한(소프트 리밋) 없음

조인트 가동 범위를 소프트웨어에서 체크하지 않아 기구 파손.

```c
// BAD
motor_set_position(target_position);

// GOOD — 소프트 리밋 적용
if (target_position < JOINT_MIN_POS || target_position > JOINT_MAX_POS) {
    log_warning("position out of range: %.2f", target_position);
    target_position = CLAMP(target_position, JOINT_MIN_POS, JOINT_MAX_POS);
}
motor_set_position(target_position);
```

**grep 감지:** `grep -rn "set_position\|set_angle\|move_to" --include="*.c" --include="*.cpp" -B 3 | grep -v "CLAMP\|clamp\|limit\|min\|max\|range\|bound"`

---

### M20: 엔코더 단선 미감지

엔코더 케이블 단선 시 위치 피드백이 0으로 고정 → 모터 폭주.

```c
// BAD
float velocity = compute_velocity(encoder_count);
// 단선 시 encoder_count 불변 → velocity=0 → PID 출력 최대

// GOOD — 엔코더 헬스 체크
static uint32_t unchanged_count = 0;
if (encoder_count == prev_count && motor_cmd > MIN_CMD_THRESH) {
    unchanged_count++;
    if (unchanged_count > ENCODER_TIMEOUT_CYCLES) {
        log_fault(FAULT_ENCODER_DISCONNECT);
        disable_motor();
    }
} else {
    unchanged_count = 0;
}
```

**grep 감지:** `grep -rn "encoder\|position_feedback" --include="*.c" | grep -v "health\|check\|disconnect\|timeout\|fault\|valid"`

---

### M21: 전원 차단 시 안전 상태 미정의

전원 복구 시 모터가 마지막 명령으로 재시작.

```c
// BAD — 부팅 시 이전 상태 복원
void motor_init(void) {
    restore_last_state();  // 마지막 명령이 full torque였으면 위험
}

// GOOD — 항상 안전 상태에서 시작
void motor_init(void) {
    motor_disable();
    clear_all_commands();
    set_torque(0.0f);
    // 오퍼레이터 입력 대기
}
```

**grep 감지:** `grep -rn "motor_init\|Motor_Init" --include="*.c" -A 10 | grep "restore\|resume\|last_state"`

---

### M22: 과속도 보호 없음

속도 루프 이상 시 모터가 최대 속도로 회전.

```c
// BAD
float speed = read_motor_speed();
// 과속도 체크 없음

// GOOD
float speed = read_motor_speed();
if (fabsf(speed) > MAX_SPEED_RPM) {
    disable_motor();
    log_fault(FAULT_OVERSPEED);
}
```

**grep 감지:** `grep -rn "motor_speed\|read_speed\|get_velocity" --include="*.c" -A 5 | grep -v "MAX_SPEED\|overspeed\|speed_limit\|max_rpm"`

---

## 빠른 참조 — 전체 grep 스캔

```bash
# 모터 제어 코드 전체 스캔
echo "=== M01: 토크 제한 없음 ==="
grep -rn "set_torque\|set_current\|set_force" --include="*.c" --include="*.cpp" -B 3 | grep -v "clamp\|CLAMP\|limit\|min\|max"

echo "=== M05: 적분기 와인드업 ==="
grep -rn "integral\s*+=" --include="*.c" --include="*.cpp" -A 2 | grep -v "clamp\|CLAMP\|limit\|max\|min\|wind"

echo "=== M06: Derivative kick ==="
grep -rn "error\s*-\s*prev_error\|error\s*-\s*last_error" --include="*.c" --include="*.cpp"

echo "=== M17: 통신 타임아웃 없음 ==="
grep -rn "can_send\|spi_write.*motor" --include="*.c" -A 2 | grep -v "if\|fail\|error\|timeout"

echo "=== M19: 위치 제한 없음 ==="
grep -rn "set_position\|set_angle" --include="*.c" --include="*.cpp" -B 3 | grep -v "CLAMP\|limit\|min\|max"

echo "=== M20: 엔코더 단선 미감지 ==="
grep -rn "encoder" --include="*.c" | grep -v "health\|check\|disconnect\|timeout\|fault"
```

---

## 심각도 등급

| 등급 | 패턴 | 영향 |
|------|-------|------|
| CRITICAL | M01, M02, M15, M18, M20, M21, M22 | 하드웨어 손상/안전 위험 |
| HIGH | M03, M04, M05, M14, M16, M17, M19 | 제어 오동작/기구 파손 |
| MEDIUM | M06-M10, M11-M13 | 제어 품질 저하 |
