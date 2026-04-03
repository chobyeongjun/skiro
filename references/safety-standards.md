# Safety Standards for Robotics

> 로봇 안전 표준 요약. ISO 15066, ISO 13482, ISO 10218, IEC 61508 등.
> 각 표준의 핵심 요구사항, 코드 레벨 체크 패턴, grep 감지 포함.

---

## 목차

1. [ISO 10218 — 산업용 로봇 안전](#1-iso-10218--산업용-로봇-안전)
2. [ISO 15066 — 협동 로봇 안전](#2-iso-15066--협동-로봇-안전)
3. [ISO 13482 — 개인 케어 로봇 안전](#3-iso-13482--개인-케어-로봇-안전)
4. [IEC 61508 — 기능 안전](#4-iec-61508--기능-안전)
5. [ISO 13849 — 안전 관련 제어 시스템](#5-iso-13849--안전-관련-제어-시스템)
6. [코드 레벨 안전 체크리스트](#6-코드-레벨-안전-체크리스트)

---

## 1. ISO 10218 — 산업용 로봇 안전

### 개요

- **ISO 10218-1**: 로봇 본체 안전 요구사항
- **ISO 10218-2**: 로봇 시스템/통합 안전 요구사항

### 핵심 안전 기능

#### SS01: 비상 정지 (Emergency Stop)

모든 로봇은 카테고리 0 또는 1 정지 기능 필수.

- **카테고리 0**: 즉시 전원 차단 (제어 없는 정지)
- **카테고리 1**: 제어된 감속 후 전원 차단

```c
// BAD — 비상 정지 없음
void main_loop(void) {
    while (1) {
        run_control();
    }
}

// GOOD — 비상 정지 경로 구현
volatile bool estop_pressed = false;

void estop_isr(void) {
    estop_pressed = true;
    disable_all_motor_drivers();  // 하드웨어 레벨 차단
}

void main_loop(void) {
    while (1) {
        if (estop_pressed) {
            controlled_stop();        // Cat. 1 소프트웨어 정지
            wait_for_operator_reset(); // 수동 리셋 필요
            continue;
        }
        run_control();
    }
}
```

**grep 감지:** `grep -rLn "estop\|e_stop\|emergency_stop\|EMERGENCY" --include="*.c" --include="*.cpp" --include="*.h"`

---

#### SS02: 보호 정지 (Protective Stop)

안전 관련 조건 감지 시 자동 정지 (인간 감지, 힘 초과 등).

```c
// BAD — 보호 정지 미구현
void control_loop(void) {
    float force = read_force();
    float cmd = compute_control(force);
    set_motor(cmd);
}

// GOOD
void control_loop(void) {
    float force = read_force();

    // 보호 정지 조건 확인
    if (fabsf(force) > FORCE_LIMIT_N) {
        protective_stop(REASON_FORCE_EXCEEDED);
        return;
    }
    if (joint_velocity > VELOCITY_LIMIT) {
        protective_stop(REASON_VELOCITY_EXCEEDED);
        return;
    }

    float cmd = compute_control(force);
    set_motor(cmd);
}
```

**grep 감지:** `grep -rn "set_motor\|motor_set\|write_torque" --include="*.c" --include="*.cpp" -B 10 | grep -v "force_limit\|FORCE_LIMIT\|velocity_limit\|protective_stop\|safety_check"`

---

#### SS03: 속도 및 힘 모니터링

축별 속도 제한 + 접촉 힘 모니터링 필수.

```c
// 속도 모니터링
typedef struct {
    float position_limit_min;
    float position_limit_max;
    float velocity_limit;       // rad/s
    float torque_limit;         // Nm
} JointSafetyLimits;

bool check_joint_safety(int joint_id, float pos, float vel, float torque) {
    JointSafetyLimits *lim = &joint_limits[joint_id];

    if (pos < lim->position_limit_min || pos > lim->position_limit_max) {
        log_safety("joint %d position out of range: %.3f", joint_id, pos);
        return false;
    }
    if (fabsf(vel) > lim->velocity_limit) {
        log_safety("joint %d velocity exceeded: %.3f", joint_id, vel);
        return false;
    }
    if (fabsf(torque) > lim->torque_limit) {
        log_safety("joint %d torque exceeded: %.3f", joint_id, torque);
        return false;
    }
    return true;
}
```

**grep 감지:** `grep -rn "velocity\|torque\|force" --include="*.c" --include="*.h" | grep -i "limit\|max\|threshold" | head -20`

---

## 2. ISO 15066 — 협동 로봇 안전

### 개요

인간-로봇 협업 시 허용 충돌 에너지 및 힘/압력 한계를 규정.

### 4가지 협업 운전 모드

| 모드 | 설명 | 핵심 요구사항 |
|------|------|---------------|
| SMS | Safety-rated Monitored Stop | 인간 접근 시 완전 정지 |
| HG | Hand Guiding | 인간이 직접 로봇 조작 |
| SSM | Speed & Separation Monitoring | 거리에 따라 속도 조절 |
| PFL | Power & Force Limiting | 힘/압력 한계 내 접촉 허용 |

---

### SS04: PFL 모드 — 힘/압력 한계

신체 부위별 허용 힘/압력 (준정적/순간 구분).

```c
// ISO 15066 신체 부위별 허용 힘 (준정적, N)
typedef struct {
    float quasi_static_force;  // 준정적 힘 한계 (N)
    float transient_force;     // 순간 힘 한계 (N)
    float quasi_static_pressure; // 준정적 압력 (N/cm^2)
    float transient_pressure;    // 순간 압력 (N/cm^2)
} BodyPartLimits;

// 대표 값 (ISO/TS 15066 Table A.2 기반 범위)
static const BodyPartLimits limits[] = {
    [SKULL]     = { 130, 260, 25, 50 },
    [FACE]      = { 65,  130, 11, 22 },
    [CHEST]     = { 140, 280, 12, 24 },
    [HAND]      = { 140, 280, 36, 72 },
    [FOREARM]   = { 150, 300, 19, 38 },
    [UPPER_ARM] = { 150, 300, 15, 30 },
    [THIGH]     = { 220, 440, 25, 50 },
};

bool check_pfl_compliance(float contact_force, float contact_area,
                          BodyPart part, bool is_transient) {
    const BodyPartLimits *lim = &limits[part];
    float force_limit = is_transient ? lim->transient_force : lim->quasi_static_force;
    float pressure_limit = is_transient ? lim->transient_pressure : lim->quasi_static_pressure;
    float pressure = contact_force / contact_area;

    return (contact_force <= force_limit) && (pressure <= pressure_limit);
}
```

**grep 감지:** `grep -rn "force_limit\|FORCE_LIMIT\|max_force\|contact_force" --include="*.c" --include="*.h" | grep -v "body_part\|ISO\|15066\|quasi_static\|transient"`

---

### SS05: SSM 모드 — 속도-거리 관계

인간과의 거리가 줄어들면 로봇 속도를 줄여야 함.

```c
// ISO 15066 SSM 최소 보호 거리 공식:
// S_p = S_h + S_r + S_s + C + Z_d + Z_r
// S_h: 인간 이동 거리
// S_r: 로봇 정지 거리
// S_s: 로봇 반응 시간 중 이동 거리
// C: 침입 거리 (센서 불확실성)
// Z_d, Z_r: 로봇/인간 크기 여유

float compute_max_robot_speed(float distance_to_human,
                              float human_speed,
                              float robot_stop_time,
                              float safety_margin) {
    // 보호 거리 역산: 거리가 주어졌을 때 허용 최대 속도
    float available_dist = distance_to_human - safety_margin
                          - human_speed * robot_stop_time;
    if (available_dist <= 0.0f) return 0.0f;  // 정지

    float max_speed = available_dist / robot_stop_time;
    return fminf(max_speed, ROBOT_MAX_SPEED);
}
```

**grep 감지:** `grep -rn "distance.*human\|human.*distance\|separation" --include="*.c" --include="*.cpp" | grep -v "speed\|velocity\|limit\|safety"`

---

### SS06: 충돌 에너지 제한

충돌 시 운동 에너지 한계. E = 0.5 * m_eff * v^2.

```python
# 유효 질량과 속도로 충돌 에너지 계산
def check_collision_energy(m_robot_eff, v_robot, m_human_eff=40.0):
    """m_human_eff: ISO 15066 기본 유효 질량 (체간)"""
    m_reduced = (m_robot_eff * m_human_eff) / (m_robot_eff + m_human_eff)
    energy = 0.5 * m_reduced * v_robot**2

    # 신체 부위별 에너지 한계 (근사 — 정확한 값은 ISO/TS 15066 참조)
    energy_limits = {
        'chest': 2.4,     # J (예시 — 실제 설계 시 표준 원문 참조)
        'hand': 4.0,
        'forearm': 3.0,
    }

    for part, limit in energy_limits.items():
        if energy > limit:
            return False, f"energy {energy:.2f}J exceeds {part} limit {limit}J"
    return True, f"energy {energy:.2f}J within limits"
```

**grep 감지:** `grep -rn "energy\|m_eff\|effective_mass" --include="*.c" --include="*.cpp" --include="*.py" | grep -i "collision\|contact\|impact"`

---

## 3. ISO 13482 — 개인 케어 로봇 안전

### 개요

비산업용 개인 케어 로봇 (이동 서빙, 보행 보조, 착용형 로봇) 안전 요구사항.

### 핵심 요구사항

#### SS07: 위험 식별 및 리스크 평가

모든 운전 모드에서의 위험을 식별하고 리스크를 줄여야 함.

```python
# 리스크 평가 구조
class HazardAssessment:
    def __init__(self):
        self.hazards = []

    def add_hazard(self, name, severity, probability, mode):
        """
        severity: 1(무시) ~ 4(치명적)
        probability: 1(거의 없음) ~ 5(빈번)
        mode: 'normal', 'maintenance', 'fault', 'transport'
        """
        risk = severity * probability
        self.hazards.append({
            'name': name,
            'severity': severity,
            'probability': probability,
            'risk': risk,
            'mode': mode,
            'mitigation': None
        })

    def get_unmitigated(self):
        return [h for h in self.hazards
                if h['risk'] > 6 and h['mitigation'] is None]
```

---

#### SS08: 착용형 로봇 특수 요구사항

인체에 밀착하는 로봇의 추가 안전 조건.

```c
// 착용형 로봇 안전 한계
#define WEARABLE_MAX_TORQUE_NM      15.0f   // 관절 토크 제한
#define WEARABLE_MAX_VELOCITY_RPS   2.0f    // 관절 속도 제한 (rad/s)
#define WEARABLE_MAX_ROM_RAD        2.5f    // 가동 범위 제한 (rad)
#define WEARABLE_MISALIGN_LIMIT_MM  15.0f   // 축 불일치 허용 한계

bool check_wearable_safety(float torque, float velocity,
                           float position, float alignment_error) {
    if (fabsf(torque) > WEARABLE_MAX_TORQUE_NM) return false;
    if (fabsf(velocity) > WEARABLE_MAX_VELOCITY_RPS) return false;
    if (fabsf(position) > WEARABLE_MAX_ROM_RAD) return false;
    if (alignment_error > WEARABLE_MISALIGN_LIMIT_MM) return false;
    return true;
}
```

**grep 감지:** `grep -rn "MAX_TORQUE\|MAX_VELOCITY\|ROM\|range_of_motion\|misalign" --include="*.c" --include="*.h" | grep -i "wearable\|exo\|assist"`

---

#### SS09: 안정성 — 전도 방지

이동 로봇의 전도 방지 요구사항.

```c
// 이동 로봇 안정성 체크
bool check_stability(float center_of_mass_x, float center_of_mass_y,
                     float support_polygon[][2], int num_vertices) {
    // CoM이 지지 다각형 내에 있는지 확인
    return point_in_polygon(center_of_mass_x, center_of_mass_y,
                           support_polygon, num_vertices);
}

// 경사면 안전 체크
#define MAX_SAFE_INCLINE_DEG  10.0f
bool check_incline_safety(float pitch_deg, float roll_deg) {
    float total_incline = sqrtf(pitch_deg*pitch_deg + roll_deg*roll_deg);
    return total_incline < MAX_SAFE_INCLINE_DEG;
}
```

**grep 감지:** `grep -rn "center_of_mass\|CoM\|stability\|tipover\|tip_over" --include="*.c" --include="*.cpp" | head -10`

---

## 4. IEC 61508 — 기능 안전

### 개요

안전 무결성 수준(SIL)을 정의. SIL 1(낮음) ~ SIL 4(높음).

### 핵심 코드 레벨 요구사항

#### SS10: 안전 기능의 자가 진단

안전 관련 하드웨어/소프트웨어는 자체 진단 필수.

```c
// 센서 자가 진단
typedef enum {
    SENSOR_OK,
    SENSOR_RANGE_ERROR,
    SENSOR_STUCK,
    SENSOR_DISCONNECTED,
    SENSOR_RATE_ERROR
} SensorHealth;

SensorHealth diagnose_sensor(float value, float prev_value,
                             float min_range, float max_range,
                             uint32_t unchanged_cycles) {
    // 범위 체크
    if (value < min_range || value > max_range)
        return SENSOR_RANGE_ERROR;

    // 고착 감지 (모터 동작 중 값 불변)
    if (unchanged_cycles > MAX_UNCHANGED_CYCLES)
        return SENSOR_STUCK;

    // 변화율 체크 (물리적으로 불가능한 변화)
    float rate = fabsf(value - prev_value);
    if (rate > MAX_PHYSICAL_RATE)
        return SENSOR_RATE_ERROR;

    return SENSOR_OK;
}
```

**grep 감지:** `grep -rn "read_sensor\|get_sensor" --include="*.c" --include="*.cpp" -A 5 | grep -v "diagnos\|health\|valid\|range\|check\|stuck\|fault"`

---

#### SS11: 이중화 (Redundancy)

SIL 2 이상은 독립적인 이중 채널 필수.

```c
// BAD — 단일 채널 안전 판단
bool is_safe = check_force(force_sensor_1);

// GOOD — 이중화 + 비교
float force_1 = read_force_sensor(SENSOR_CH_A);
float force_2 = read_force_sensor(SENSOR_CH_B);

// 크로스 체크
if (fabsf(force_1 - force_2) > SENSOR_DISAGREEMENT_THRESHOLD) {
    log_safety("sensor disagreement: ch_a=%.1f ch_b=%.1f", force_1, force_2);
    enter_safe_state();
    return;
}
float force = (force_1 + force_2) / 2.0f;
```

**grep 감지:** `grep -rn "force_sensor\|read_force\|force_ch" --include="*.c" --include="*.h" | grep -v "sensor_2\|ch_b\|channel_b\|redundan\|backup"`

---

#### SS12: 안전 기능 응답 시간

감지 → 반응까지의 최대 시간 보장.

```c
// 안전 기능 타이밍 요구사항
#define SAFETY_DETECTION_TIME_MS     5    // 위험 감지까지
#define SAFETY_REACTION_TIME_MS     10    // 정지 명령까지
#define SAFETY_STOP_TIME_MS        100    // 완전 정지까지
#define TOTAL_SAFETY_TIME_MS       115    // 전체 (위 합산)

// 검증: 안전 루프가 요구 주기 내에 실행되는지
void safety_monitor_task(void) {
    TickType_t start = xTaskGetTickCount();

    bool safe = check_all_safety_conditions();
    if (!safe) {
        trigger_protective_stop();
    }

    TickType_t elapsed = xTaskGetTickCount() - start;
    if (elapsed > pdMS_TO_TICKS(SAFETY_DETECTION_TIME_MS)) {
        log_error("safety loop exceeded deadline: %lu ms", elapsed);
    }
}
```

**grep 감지:** `grep -rn "safety.*task\|safety.*loop\|safety.*monitor" --include="*.c" | grep -v "deadline\|timing\|response_time\|elapsed\|timeout"`

---

## 5. ISO 13849 — 안전 관련 제어 시스템

### 개요

제어 시스템의 안전 관련 부분 성능 수준 (PLa ~ PLe) 정의.

### 핵심 아키텍처 패턴

#### SS13: 카테고리별 아키텍처

| 카테고리 | 구조 | 특징 |
|---------|------|------|
| B | 단일 채널 | 기본 안전 원칙 |
| 1 | 단일 채널 + 검증된 부품 | 높은 MTTF |
| 2 | 단일 채널 + 자가 테스트 | 주기적 테스트 |
| 3 | 이중 채널 + 크로스 모니터링 | 단일 결함 허용 |
| 4 | 이중 채널 + 축적 결함 감지 | 다중 결함 허용 |

```c
// 카테고리 3 구현 예시: 이중 채널 + 크로스 모니터링
typedef struct {
    float channel_a_value;
    float channel_b_value;
    uint32_t disagreement_count;
} DualChannelMonitor;

SafetyAction dual_channel_check(DualChannelMonitor *mon,
                                float sensor_a, float sensor_b) {
    mon->channel_a_value = sensor_a;
    mon->channel_b_value = sensor_b;

    if (fabsf(sensor_a - sensor_b) > CHANNEL_THRESHOLD) {
        mon->disagreement_count++;
        if (mon->disagreement_count > MAX_DISAGREEMENTS) {
            return SAFETY_STOP;  // 지속적 불일치 → 정지
        }
        return SAFETY_WARN;
    }
    mon->disagreement_count = 0;
    return SAFETY_OK;
}
```

---

#### SS14: 안전 관련 소프트웨어 요구사항

```c
// ISO 13849 소프트웨어 요구사항 체크리스트 코드 패턴

// 1. 프로그램 시퀀스 모니터링 — watchdog
static uint32_t safety_sequence_counter = 0;
void safety_check_sequence(void) {
    safety_sequence_counter++;
    if (safety_sequence_counter != expected_sequence) {
        enter_safe_state();
    }
}

// 2. 데이터 무결성 — CRC 체크
bool verify_safety_params(void) {
    uint32_t stored_crc = safety_params.crc;
    uint32_t computed_crc = crc32(&safety_params, sizeof(safety_params) - 4);
    return stored_crc == computed_crc;
}

// 3. 플로시블리티 체크 — 물리적 타당성
bool plausibility_check(float position, float velocity, float dt) {
    float expected_change = velocity * dt;
    float actual_change = position - prev_position;
    return fabsf(actual_change - expected_change) < PLAUSIBILITY_THRESHOLD;
}
```

**grep 감지:** `grep -rn "safety_param\|SAFETY_PARAM" --include="*.c" --include="*.h" | grep -v "crc\|CRC\|checksum\|hash\|verify\|integrity"`

---

## 6. 코드 레벨 안전 체크리스트

### 필수 안전 기능 확인 grep 명령

```bash
# === 1. 비상 정지 구현 확인 ===
echo "--- E-Stop 구현 ---"
grep -rn "estop\|e_stop\|emergency" --include="*.c" --include="*.h"
echo "--- E-Stop 누락 파일 ---"
grep -rLn "estop\|e_stop\|emergency" --include="*.c" | grep -i "motor\|control\|main"

# === 2. 힘/토크 제한 확인 ===
echo "--- 힘 제한 ---"
grep -rn "FORCE_LIMIT\|force_limit\|MAX_FORCE\|max_force\|torque_limit\|MAX_TORQUE" --include="*.c" --include="*.h"

# === 3. 속도 제한 확인 ===
echo "--- 속도 제한 ---"
grep -rn "VELOCITY_LIMIT\|velocity_limit\|MAX_SPEED\|max_speed\|speed_limit" --include="*.c" --include="*.h"

# === 4. 워치독 확인 ===
echo "--- 워치독 ---"
grep -rn "watchdog\|IWDG\|WDT\|wdt" --include="*.c" --include="*.h"

# === 5. 센서 건강 체크 ===
echo "--- 센서 유효성 검사 ---"
grep -rn "sensor.*health\|sensor.*valid\|sensor.*check\|sensor.*fault" --include="*.c" --include="*.h"

# === 6. 이중화 확인 ===
echo "--- 이중화 ---"
grep -rn "channel_a\|channel_b\|redundan\|dual_channel\|cross_check" --include="*.c" --include="*.h"

# === 7. 안전 상태 정의 ===
echo "--- 안전 상태 ---"
grep -rn "safe_state\|SAFE_STATE\|enter_safe\|safety_stop" --include="*.c" --include="*.h"
```

---

### 안전 기능 미구현 감지

```bash
# 위험한 패턴: 안전 기능 없는 모터 제어 코드
echo "=== 위험: 제한 없는 모터 명령 ==="
grep -rn "set_torque\|set_current\|set_pwm\|motor_write" --include="*.c" --include="*.cpp" -B 5 | \
    grep -v "limit\|clamp\|CLAMP\|max\|min\|safety\|check\|if\s*("

echo "=== 위험: 비상 정지 없는 제어 파일 ==="
for f in $(grep -rln "motor\|actuator\|servo" --include="*.c" --include="*.cpp"); do
    if ! grep -q "estop\|e_stop\|emergency\|safe_state" "$f"; then
        echo "NO ESTOP: $f"
    fi
done

echo "=== 위험: 타임아웃 없는 통신 ==="
grep -rn "receive\|recv\|read" --include="*.c" --include="*.cpp" | \
    grep -i "can\|uart\|spi\|i2c\|serial" | \
    grep -v "timeout\|TIMEOUT\|timer\|deadline"
```

---

## 표준 간 관계 요약

```
ISO 10218 (산업용 로봇)
    ├── ISO 15066 (협동 로봇 보충)
    │     └── 힘/압력 한계 테이블
    └── ISO 13849 (제어 시스템 안전)
          └── 성능 수준 (PL)

ISO 13482 (개인 케어 로봇)
    ├── 이동 로봇
    ├── 보행 보조 로봇
    └── 착용형 로봇

IEC 61508 (기능 안전 — 범산업)
    └── SIL 수준
        └── ISO 13849의 PL과 대응
```

| PL (ISO 13849) | SIL (IEC 61508) | 적용 예시 |
|----------------|-----------------|-----------|
| PLa | — | 단순 보조 기능 |
| PLb | SIL 1 | 경미한 부상 방지 |
| PLc | SIL 1 | 가벼운 부상 방지 |
| PLd | SIL 2 | 심각한 부상 방지 |
| PLe | SIL 3 | 치명적 부상 방지 |

---

## 심각도 등급

| 등급 | 패턴 | 영향 |
|------|-------|------|
| CRITICAL | SS01, SS02, SS04, SS10, SS11, SS12 | 인명 안전 직결 |
| HIGH | SS03, SS05, SS06, SS08, SS13, SS14 | 안전 시스템 품질 |
| MEDIUM | SS07, SS09 | 리스크 관리/문서화 |
