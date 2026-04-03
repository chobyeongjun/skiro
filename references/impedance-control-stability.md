# Impedance Control Stability Conditions

> 임피던스/어드미턴스 제어의 안정성 조건, 패시비티, 디지털 구현 함정 모음.
> 로봇 매니퓰레이터, 보행 보조 로봇, 재활 로봇 범용.

---

## 목차

1. [임피던스 제어 기초](#1-임피던스-제어-기초)
2. [패시비티 조건](#2-패시비티-조건)
3. [이산화 안정성](#3-이산화-안정성)
4. [커플링 안정성](#4-커플링-안정성)
5. [파라미터 선택 가이드](#5-파라미터-선택-가이드)
6. [구현 버그 패턴](#6-구현-버그-패턴)

---

## 1. 임피던스 제어 기초

### 목표 임피던스 모델

```
F = M * x_ddot + B * x_dot + K * (x - x_d)
```

- **M**: 가상 관성 (kg 또는 kg*m^2)
- **B**: 가상 감쇠 (N*s/m 또는 N*m*s/rad)
- **K**: 가상 강성 (N/m 또는 N*m/rad)
- **x_d**: 목표 평형점

### 기본 구현

```c
typedef struct {
    float M;     // 가상 관성
    float B;     // 가상 감쇠
    float K;     // 가상 강성
    float x_d;   // 평형 위치
    float x_dot_prev;
} ImpedanceCtrl;

float impedance_compute(ImpedanceCtrl *ic, float x, float x_dot, float dt) {
    float x_ddot = (x_dot - ic->x_dot_prev) / dt;
    ic->x_dot_prev = x_dot;

    float force = ic->M * x_ddot + ic->B * x_dot + ic->K * (x - ic->x_d);
    return force;
}
```

---

## 2. 패시비티 조건

패시비티는 시스템이 에너지를 생성하지 않는 조건. 패시브 시스템은 패시브 환경과 결합 시 항상 안정.

### S01: 양정치 조건 위반

M, B, K 중 하나라도 음수면 에너지 생성 → 불안정.

```c
// BAD — 음수 감쇠 (에너지 주입)
ImpedanceCtrl ic = { .M = 1.0f, .B = -5.0f, .K = 100.0f };

// GOOD — 모든 파라미터 양수
ImpedanceCtrl ic = { .M = 1.0f, .B = 5.0f, .K = 100.0f };

// 검증 함수
bool validate_impedance_params(float M, float B, float K) {
    if (M < 0.0f || B < 0.0f || K < 0.0f) {
        log_error("impedance params must be non-negative: M=%.2f B=%.2f K=%.2f",
                  M, B, K);
        return false;
    }
    return true;
}
```

**grep 감지:** `grep -rn "\.B\s*=\s*-\|\.K\s*=\s*-\|\.M\s*=\s*-\|damping\s*=\s*-\|stiffness\s*=\s*-" --include="*.c" --include="*.cpp" --include="*.py"`

---

### S02: 감쇠비 부족 (Under-damped)

감쇠비 zeta < 1 이면 진동, zeta << 1 이면 발산에 가까운 진동.

```
zeta = B / (2 * sqrt(K * M))
```

```python
# BAD — 매우 낮은 감쇠비
M, B, K = 1.0, 0.1, 1000.0
zeta = B / (2 * (K * M)**0.5)  # zeta = 0.0016 → 극심한 진동

# GOOD — 적절한 감쇠비 (0.7 ~ 1.0)
M = 1.0
K = 1000.0
zeta_target = 0.8
B = 2 * zeta_target * (K * M)**0.5  # B = 50.6

# 검증
def check_damping_ratio(M, B, K, min_zeta=0.4):
    if K <= 0 or M <= 0:
        return True  # K=0이면 진동 없음
    zeta = B / (2 * (K * M)**0.5)
    if zeta < min_zeta:
        print(f"WARNING: damping ratio {zeta:.3f} < {min_zeta} (under-damped)")
        return False
    return True
```

**grep 감지:** `grep -rn "damping_ratio\|zeta\|B\s*/\s*.*sqrt" --include="*.py" --include="*.c" --include="*.cpp"`

---

### S03: 가상 관성이 너무 작음

M이 실제 로봇 관성보다 훨씬 작으면 관성 보상이 필요하고, 이는 노이즈에 취약.

```python
# BAD — 가상 관성 << 실제 관성
M_virtual = 0.01    # 가상 관성
M_robot = 5.0       # 실제 로봇 관성
# 관성 보상 필요: (M_robot - M_virtual) * a → 가속도 노이즈 증폭

# GOOD — 가상 관성 >= 실제 관성
M_virtual = 5.0     # 관성 보상 불필요
# 또는 관성 축소 시 저역 필터 필수
```

**grep 감지:** `grep -rn "virtual_mass\|M_virtual\|inertia\s*=" --include="*.py" --include="*.c" | grep -E "0\.0[0-9]|1e-"`

---

## 3. 이산화 안정성

### S04: 샘플링 주기와 임피던스 대역폭 불일치

나이퀴스트: 제어 대역폭 < 샘플링 주파수 / 2.
실용적: **제어 대역폭 < 샘플링 주파수 / 10**.

```
자연 주파수: omega_n = sqrt(K/M)
필요 샘플링: fs > 10 * omega_n / (2*pi)
```

```python
# BAD
K = 10000.0  # N/m
M = 1.0      # kg
omega_n = (K/M)**0.5   # 100 rad/s = 15.9 Hz
fs = 100     # 100 Hz → fs/omega_n*2pi = 6.3 → 불안정 위험

# GOOD
fs = 1000    # 1000 Hz → fs/omega_n*2pi = 63 → 충분한 여유
# 또는 K를 낮추기
K = 500.0    # omega_n = 22.4 rad/s → 100Hz 제어로 충분
```

```c
// 컴파일 타임 검증
#define CONTROL_FREQ_HZ   1000
#define IMP_K              500.0f
#define IMP_M              1.0f
#define OMEGA_N            sqrtf(IMP_K / IMP_M)
#define MIN_FREQ_RATIO     10.0f
// 런타임 검증
void validate_sampling(float K, float M, float fs) {
    float omega_n = sqrtf(K / M);
    float freq_ratio = fs / (omega_n / (2.0f * M_PI));
    if (freq_ratio < MIN_FREQ_RATIO) {
        log_warning("sampling ratio %.1f < %.1f, reduce K or increase fs",
                    freq_ratio, MIN_FREQ_RATIO);
    }
}
```

**grep 감지:** `grep -rn "stiffness\|IMP_K\|spring_constant" --include="*.c" --include="*.h" --include="*.py" | grep -E "[0-9]{4,}"`

---

### S05: 오일러 적분 불안정

전진 오일러(Forward Euler)는 조건부 안정. 높은 K/M에서 발산.

```python
# BAD — Forward Euler
x_dot += (-B/M * x_dot - K/M * (x - x_d)) * dt
x += x_dot * dt
# 안정 조건: dt < 2*M/B (감쇠만 있을 때)
# K 포함 시 더 엄격: dt < 2/omega_n * min(zeta, 1/zeta) (근사)

# GOOD — Semi-implicit Euler (Symplectic)
x_dot += (-B/M * x_dot - K/M * (x - x_d)) * dt
x += x_dot * dt  # 업데이트된 x_dot 사용 (순서가 중요!)

# BETTER — Tustin (Bilinear) 변환
# s = 2/T * (z-1)/(z+1) 으로 전달 함수 이산화
```

**grep 감지:** `grep -rn "x_dot\s*+=\|velocity\s*+=" --include="*.c" --include="*.cpp" --include="*.py" -A 1 | grep "x\s*+=\|position\s*+="`

---

### S06: 힘 센서 지연 미보상

힘 센서의 디지털 필터 지연이 위상 여유를 줄여 불안정.

```c
// BAD — 필터 지연 무시
float force = read_force_sensor();  // 내부 10차 필터 → 5ms 지연
float cmd = impedance_compute(force, ...);  // 위상 지연으로 진동

// GOOD — 지연 보상 또는 대역폭 제한
// 방법 1: 임피던스 대역폭을 센서 지연의 역수 이하로 제한
// 센서 지연 5ms → 최대 대역폭 ~30Hz
// 방법 2: Smith predictor 또는 위상 보상기
float force_compensated = force + force_derivative * sensor_delay;
```

**grep 감지:** `grep -rn "read_force\|force_sensor\|load_cell" --include="*.c" --include="*.cpp" -A 3 | grep -v "delay\|compensat\|latency\|filter"`

---

## 4. 커플링 안정성

### S07: 환경 임피던스와의 커플링 불안정

로봇이 강성이 높은 환경(벽, 단단한 표면)과 접촉 시 불안정.

```
안정 조건 (Colgate & Hogan, 1988):
B_virtual > K_virtual * T / 2 + sqrt(K_env * M_virtual) (근사)

실용적 규칙:
높은 환경 강성 접촉 시 → B를 충분히 크게
K_virtual을 낮추면 안정 범위 확대
```

```python
# BAD — 높은 K, 낮은 B로 단단한 환경 접촉
K_virtual = 5000  # N/m
B_virtual = 10    # Ns/m
K_env = 50000     # 매우 단단한 환경
# → 접촉 시 불안정 진동

# GOOD — 환경 강성 추정에 따른 B 조정
K_env_estimate = 50000
B_virtual = max(B_min, 2 * (K_virtual * 1.0)**0.5)  # 임계 감쇠 이상
```

**grep 감지:** `grep -rn "K_env\|environment_stiffness\|contact_stiffness" --include="*.py" --include="*.c"`

---

### S08: 비선형 마찰 보상 오류

마찰 보상이 과도하면 네거티브 감쇠 → 자발 진동.

```c
// BAD — 쿨롱 마찰 과보상
float friction_comp = COULOMB_FRICTION * sign(velocity);
if (fabsf(velocity) < 0.01f) {
    friction_comp = COULOMB_FRICTION * sign(force_cmd);
    // 정지 상태에서 양방향 번갈아 보상 → 진동
}

// GOOD — 데드존 + 점진적 보상
float friction_comp = 0.0f;
if (fabsf(velocity) > VELOCITY_THRESHOLD) {
    friction_comp = COULOMB_FRICTION * sign(velocity);
} else {
    friction_comp = COULOMB_FRICTION * velocity / VELOCITY_THRESHOLD;
    // 선형 보간으로 채터링 방지
}
```

**grep 감지:** `grep -rn "friction.*comp\|coulomb\|sign.*velocity" --include="*.c" --include="*.cpp" | grep -v "threshold\|deadzone\|dead_zone\|smooth"`

---

## 5. 파라미터 선택 가이드

### 일반적인 응용 별 범위

| 응용 | M (kg) | B (Ns/m) | K (N/m) | 비고 |
|------|--------|----------|---------|------|
| 재활 로봇 (수동) | 0.5-2.0 | 1-20 | 0-50 | 낮은 K, 높은 M |
| 재활 로봇 (능동) | 0.5-2.0 | 5-50 | 50-500 | 적절한 안내 강성 |
| 협동 로봇 | 1.0-10 | 10-100 | 100-2000 | 인간 접촉 안전 |
| 보행 보조 | 0.5-5.0 | 5-30 | 50-1000 | 보행 주기 고려 |
| 정밀 조립 | 0.1-1.0 | 1-10 | 500-5000 | 높은 K, 높은 fs 필요 |

### 파라미터 검증 체크리스트

```python
def validate_impedance_config(M, B, K, fs, application="general"):
    issues = []

    # 1. 양정치 조건
    if M < 0 or B < 0 or K < 0:
        issues.append("CRITICAL: negative parameter detected")

    # 2. 감쇠비
    if K > 0 and M > 0:
        zeta = B / (2 * (K * M)**0.5)
        if zeta < 0.4:
            issues.append(f"WARNING: under-damped (zeta={zeta:.3f})")
        if zeta > 5.0:
            issues.append(f"INFO: over-damped (zeta={zeta:.3f}), slow response")

    # 3. 샘플링 비율
    if K > 0 and M > 0:
        omega_n = (K / M)**0.5
        fn = omega_n / (2 * 3.14159)
        if fs < 10 * fn:
            issues.append(f"CRITICAL: sampling ratio {fs/fn:.1f} < 10")

    # 4. 가상 관성이 너무 작음
    if M < 0.01:
        issues.append("WARNING: very low virtual inertia, noise sensitive")

    # 5. 에너지 체크 (이산 패시비티)
    T = 1.0 / fs
    if K > 0:
        passivity_limit = B - K * T / 2.0
        if passivity_limit < 0:
            issues.append(f"CRITICAL: discrete passivity violated (B - K*T/2 = {passivity_limit:.3f} < 0)")

    return issues
```

---

## 6. 구현 버그 패턴

### S09: 가속도 수치 미분의 노이즈

가속도 = (v[k] - v[k-1]) / dt 는 노이즈를 극대화.

```c
// BAD — 직접 미분
float accel = (velocity - prev_velocity) / dt;
float force = M * accel + B * velocity + K * (pos - pos_d);

// GOOD — 가속도 항을 피하는 재구성
// M*x_ddot + B*x_dot + K*x = F_ext 를 직접 풀지 말고
// 어드미턴스 형태로: x_d = F_ext → (desired motion)
// 또는 가속도에 강한 저역 필터
float alpha = dt / (0.01f + dt);  // 100Hz 이하 통과
filtered_accel = alpha * raw_accel + (1-alpha) * filtered_accel;
```

**grep 감지:** `grep -rn "accel\s*=.*velocity.*prev\|x_ddot.*=.*x_dot.*prev" --include="*.c" --include="*.cpp" --include="*.py" | grep -v "filter\|lpf\|smooth"`

---

### S10: 힘/토크 센서 드리프트 미보상

온도 등으로 0점이 이동하면 정상 상태에서도 힘 출력.

```python
# BAD — 드리프트 무시
force = read_force_sensor()
torque_cmd = -K * (force / K_env)  # 드리프트 → 지속적 이동

# GOOD — 주기적 0점 보정
force_raw = read_force_sensor()
if is_in_free_space():
    force_offset = 0.999 * force_offset + 0.001 * force_raw  # 느린 추적
force = force_raw - force_offset
```

**grep 감지:** `grep -rn "read_force\|read_torque\|force_sensor" --include="*.c" --include="*.cpp" --include="*.py" -A 3 | grep -v "offset\|bias\|drift\|zero\|tare\|calibrat"`

---

### S11: 좌표계 불일치

힘 센서 좌표계와 제어 좌표계가 달라 힘 방향 반전 → 양성 피드백.

```c
// BAD — 부호 오류 → 양성 피드백 → 불안정
float force_x = force_sensor_x;  // 센서: 밀면 +, 로봇 프레임: 밀면 -
float cmd = K * force_x;  // 미는 방향으로 가속 → 발산!

// GOOD — 좌표 변환 명시
float force_x = -force_sensor_x;  // 센서→로봇 프레임 변환
float cmd = K * force_x;
// 또는 변환 행렬 사용
float F_robot[3];
mat_mul(T_sensor_to_robot, F_sensor, F_robot);
```

**grep 감지:** `grep -rn "force.*=.*sensor\|torque.*=.*sensor" --include="*.c" --include="*.cpp" --include="*.py" | grep -v "transform\|T_\|rotation\|frame\|coord"`

---

### S12: 모드 전환 시 불연속

자유 공간 → 접촉 전환 시 임피던스 파라미터가 불연속적으로 변하면 충격.

```python
# BAD — 접촉 감지 시 즉시 전환
if contact_detected:
    K = K_contact      # 갑자기 높은 강성
    B = B_contact
else:
    K = K_free
    B = B_free

# GOOD — 파라미터 점진적 전환
if contact_detected:
    blend = min(blend + blend_rate * dt, 1.0)
else:
    blend = max(blend - blend_rate * dt, 0.0)
K = K_free + blend * (K_contact - K_free)
B = B_free + blend * (B_contact - B_free)
```

**grep 감지:** `grep -rn "if.*contact\|if.*touch\|if.*collision" --include="*.c" --include="*.cpp" --include="*.py" -A 5 | grep -E "K\s*=|B\s*=|stiffness\s*=|damping\s*=" | grep -v "blend\|smooth\|ramp\|transition\|lerp"`

---

## 심각도 등급

| 등급 | 패턴 | 영향 |
|------|-------|------|
| CRITICAL | S01, S04, S05, S07, S11 | 발산/불안정 → 물리적 위험 |
| HIGH | S02, S03, S06, S08, S12 | 진동/충격 → 제어 품질 저하 |
| MEDIUM | S09, S10 | 드리프트/노이즈 → 정밀도 저하 |
