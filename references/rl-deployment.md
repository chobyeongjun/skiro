# RL Deployment Bug Patterns

> 강화학습 정책의 실제 로봇 배포에서 반복적으로 발생하는 실수 패턴 모음.
> 추론 지연, Sim2Real 전이, 안전/폴백, 보상 설계에 적용. 각 패턴에 코드 예시, grep 감지 포함.

## INDEX
<!-- skiro: machine-readable index. Line = actual line number in this file. -->
| ID | 패턴 | 트리거 키워드 | Line |
|----|------|-------------|------|
| RL01 | 정책 추론 지연 | policy, predict, inference, torch, latency | 34 |
| RL02 | Sim2Real 갭 | sim2real, domain_rand, transfer, rl_ | 161 |
| RL03 | 관찰 정규화 불일치 | obs_norm, running_mean, normalize, VecNormalize | 197 |
| RL04 | 폴백 컨트롤러 없음 | fallback, timeout, policy_fail, safe_action | 302 |
| RL05 | 보상 함수 설계 오류 | reward, compute_reward, reward_fn, shaped | 384 |
| RL06 | 액션 스페이스 설계 오류 | action_space, Box, action_bound, actuator | 351 |
| RL07 | 학습-배포 주파수 불일치 | control_freq, sim_dt, CONTROL_HZ, policy_freq | 120 |
| RL08 | GPU/NPU 추론 최적화 누락 | torch.load, model.eval, onnx, tensorrt | 83 |
| RL09 | 정책 경량화 누락 | distill, teacher, student, onnx_export | 424 |
| RL10 | 상태 추정 품질 미검증 | observation, state_estimate, sensor_fusion | 248 |

---

## 카테고리

1. [추론/배포](#1-추론배포)
2. [Sim2Real 전이](#2-sim2real-전이)
3. [안전/폴백](#3-안전폴백)
4. [보상/학습 설계](#4-보상학습-설계)

---

## 1. 추론/배포

### RL01: 정책 추론 지연 (Policy Inference Latency)

정책 네트워크 추론이 제어 루프 데드라인을 초과하면 오래된 action으로 동작하거나 사이클을 놓침.

```python
# BAD -- model.predict() 시간이 제어 주기 초과
def control_loop():
    while True:
        obs = get_observation()
        action = policy.predict(obs)  # 50ms on Jetson -- 20Hz 루프에서 deadline miss
        robot.send_command(action)
```

```python
# GOOD -- 비동기 추론 + 최신 action 캐시 + deadline 모니터링
import threading, time

latest_action = default_safe_action()
action_lock = threading.Lock()

def inference_thread(policy, obs_queue):
    while True:
        obs = obs_queue.get()
        action = policy.predict(obs)
        with action_lock:
            global latest_action
            latest_action = action

def control_loop():
    deadline = 1.0 / CONTROL_FREQ_HZ  # 5ms for 200Hz
    while True:
        t0 = time.monotonic()
        obs = get_observation()
        obs_queue.put(obs)
        with action_lock:
            action = latest_action
        robot.send_command(action)
        elapsed = time.monotonic() - t0
        if elapsed > deadline:
            log_warning(f"control overrun: {elapsed*1000:.1f}ms > {deadline*1000:.1f}ms")
```

**grep 감지:**
```
grep -rn "predict\|forward\|inference" --include="*.py" -B5 | grep -v "thread\|async\|cache\|deadline\|timeout"
```

---

### RL08: GPU/NPU 추론 최적화 누락

풀 정밀도 PyTorch/TF 모델을 엣지 하드웨어에 그대로 배포하면 10-100배 느린 추론.

```python
# BAD -- 풀 정밀도 PyTorch 추론 (Jetson Nano에서 ~80ms)
import torch
policy = torch.load("policy.pt")
obs_tensor = torch.FloatTensor(obs)
with torch.no_grad():
    action = policy(obs_tensor).numpy()
```

```python
# GOOD -- ONNX Runtime + TensorRT 최적화 (Jetson Nano에서 ~5ms)
import onnxruntime as ort

# 배포 전: torch -> ONNX -> TensorRT
# torch.onnx.export(policy, dummy_input, "policy.onnx")
# trtexec --onnx=policy.onnx --saveEngine=policy.trt --fp16

sess = ort.InferenceSession("policy.onnx",
    providers=['TensorrtExecutionProvider', 'CUDAExecutionProvider'])
input_name = sess.get_inputs()[0].name

def predict_optimized(obs):
    result = sess.run(None, {input_name: obs.astype(np.float32).reshape(1, -1)})
    return result[0].squeeze()
```

**grep 감지:**
```
grep -rn "torch.load\|torch.no_grad\|model.eval\|\.forward(" --include="*.py" | grep -v "onnx\|tensorrt\|tflite\|quantiz\|optimize"
```

---

### RL07: 학습-배포 주파수 불일치

시뮬레이션 dt(50Hz)로 학습한 정책을 다른 주파수(100Hz)로 배포하면 action 시간 스케일 불일치.

```python
# BAD -- 학습 dt와 배포 dt 불일치
# 학습: sim_dt = 0.02 (50Hz), 배포: control_dt = 0.01 (100Hz)
action = policy.predict(obs)
robot.send_command(action)  # 같은 action이 2배 빨리 적용됨
```

```python
# GOOD -- 학습 주파수에 맞춰 skip 또는 dt 스케일링
TRAIN_DT = 0.02    # 50Hz (학습 시 사용한 dt)
DEPLOY_DT = 0.01   # 100Hz (실제 제어 주기)
SKIP_RATIO = round(TRAIN_DT / DEPLOY_DT)

step_counter = 0
cached_action = None

def get_action(obs):
    global step_counter, cached_action
    # 학습 주파수에 맞춰 정책 호출 skip
    if step_counter % SKIP_RATIO == 0:
        cached_action = policy.predict(obs)
    step_counter += 1
    return cached_action

    # 대안: velocity/torque 명령을 dt 비율로 스케일
    # action_scaled = action * (DEPLOY_DT / TRAIN_DT)
```

**grep 감지:**
```
grep -rn "predict\|forward" --include="*.py" -B10 | grep -i "dt\|freq\|hz" | grep -v "match\|ratio\|scale\|skip\|TRAIN_DT"
```

---

## 2. Sim2Real 전이

### RL02: Sim2Real 갭 미대응

시뮬레이션 고정 파라미터로 학습하면 실제 환경의 마찰/질량/지연 변동에 대응 불가.

```python
# BAD -- 시뮬레이션 고정 파라미터로 학습
env = gym.make("RobotArm-v0")
env.set_friction(0.5)      # 단일 마찰 계수
env.set_mass(1.0)          # 단일 질량
policy = train_ppo(env, steps=1_000_000)
# 실제 로봇: 마찰 0.3~0.8, 질량 0.8~1.5 -> 정책 실패
```

```python
# GOOD -- 도메인 랜덤화 + 관찰 적응
from numpy.random import uniform

class DomainRandomizedEnv(gym.Wrapper):
    def reset(self, **kwargs):
        obs, info = super().reset(**kwargs)
        self.unwrapped.set_friction(uniform(0.2, 1.0))
        self.unwrapped.set_mass(uniform(0.7, 1.5))
        self.unwrapped.set_latency(uniform(0.0, 0.02))  # 통신 지연 랜덤화
        return obs, info

env = DomainRandomizedEnv(gym.make("RobotArm-v0"))
policy = train_ppo(env, steps=2_000_000)
```

**grep 감지:**
```
grep -rn "gym.make\|make_env" --include="*.py" -A10 | grep -v "random\|rand\|noise\|domain\|uniform"
```

---

### RL03: 관찰 정규화 불일치 (Observation Normalization Drift)

학습 시 running mean/std를 저장하지 않으면 배포 시 정책 입력 분포가 완전히 달라짐.

```python
# BAD -- 학습 시 정규화 통계를 저장하지 않음
obs_mean = running_mean   # 학습 중 업데이트됨
obs_std = running_std
normalized_obs = (obs - obs_mean) / obs_std

# 배포 시: 저장된 통계 없음 -> 재초기화 -> 분포 불일치
policy.load("policy.pt")
# obs_mean, obs_std = ??? -> 정책 입력 분포 완전히 다름
```

```python
# GOOD -- 학습 시 정규화 통계 저장 + 배포 시 고정
import numpy as np

class ObsNormalizer:
    def __init__(self, shape, clip=10.0):
        self.mean = np.zeros(shape)
        self.var = np.ones(shape)
        self.clip = clip
        self.frozen = False

    def normalize(self, obs):
        return np.clip((obs - self.mean) / np.sqrt(self.var + 1e-8),
                       -self.clip, self.clip)

    def save(self, path):
        np.savez(path, mean=self.mean, var=self.var)

    def load_and_freeze(self, path):
        data = np.load(path)
        self.mean, self.var = data['mean'], data['var']
        self.frozen = True  # 배포 시 통계 업데이트 중지

# 배포
normalizer = ObsNormalizer(obs_shape)
normalizer.load_and_freeze("obs_stats.npz")
action = policy.predict(normalizer.normalize(obs))
```

**grep 감지:**
```
grep -rn "running_mean\|obs_rms\|VecNormalize\|obs_mean\|normalize.*obs" --include="*.py" | grep -v "save\|load\|freeze\|frozen"
```

---

### RL10: 상태 추정 품질 미검증

원시 센서 값을 직접 정책 입력으로 사용하면 노이즈/지연/드롭아웃으로 불안정 동작.

```python
# BAD -- 원시 센서 값을 직접 정책 입력으로 사용
obs = np.array([
    imu.read_accel(),     # 노이즈 +-2 m/s^2
    gps.read_position(),  # 5Hz 업데이트, 지연 200ms
    encoder.read_vel(),   # 스파이크 포함
])
action = policy.predict(obs)
```

```python
# GOOD -- 센서 퓨전 + 유효성 검증 + 정책 관찰 구성
class StateEstimator:
    def __init__(self):
        self.ekf = ExtendedKalmanFilter(state_dim=9)
        self.last_valid_state = np.zeros(9)

    def get_observation(self, sensors):
        # 센서 유효성 검증
        if not sensors.imu.is_valid() or sensors.imu.age_ms() > 10:
            log_warning("IMU data stale or invalid")
            return self.last_valid_state, False

        # EKF 업데이트
        self.ekf.predict(dt=sensors.dt)
        self.ekf.update_imu(sensors.imu.data)
        if sensors.gps.is_fresh(max_age_ms=200):
            self.ekf.update_gps(sensors.gps.data)

        state = self.ekf.state
        self.last_valid_state = state.copy()
        return state, True

# 사용
state, valid = estimator.get_observation(sensors)
if not valid:
    action = fallback_controller.compute(state)
else:
    action = policy.predict(normalizer.normalize(state))
```

**grep 감지:**
```
grep -rn "obs\s*=.*read\|observation.*sensor" --include="*.py" -A3 | grep "predict\|forward\|policy" | grep -v "filter\|ekf\|kalman\|fuse\|valid"
```

---

## 3. 안전/폴백

### RL04: 폴백 컨트롤러 없음 (Missing Fallback Controller)

정책 출력이 위험하거나 추론 실패/타임아웃 시 안전 폴백이 없으면 로봇 손상.

```python
# BAD -- 정책 출력을 직접 로봇에 전달
action = policy.predict(obs)
robot.send_command(action)  # 정책이 관절 한계 초과 명령 가능
```

```python
# GOOD -- 다층 안전 체크 + 폴백
class SafePolicyExecutor:
    def __init__(self, policy, fallback_ctrl, timeout_sec=0.05):
        self.policy = policy
        self.fallback = fallback_ctrl
        self.timeout = timeout_sec
        self.consecutive_failures = 0

    def get_action(self, obs, robot_state):
        try:
            t0 = time.monotonic()
            action = self.policy.predict(obs)
            if time.monotonic() - t0 > self.timeout:
                raise TimeoutError("inference exceeded deadline")

            # Action safety check
            action = np.clip(action, ACTION_MIN, ACTION_MAX)
            if self.is_dangerous(action, robot_state):
                log_warning("policy output dangerous, using fallback")
                return self.fallback.compute(robot_state)

            self.consecutive_failures = 0
            return action
        except Exception as e:
            self.consecutive_failures += 1
            log_error(f"policy failed: {e}")
            if self.consecutive_failures > MAX_CONSECUTIVE_FAILS:
                robot.emergency_stop()
            return self.fallback.compute(robot_state)
```

**grep 감지:**
```
grep -rn "predict\|\.forward(" --include="*.py" -A5 | grep "send_command\|set_torque\|set_position" | grep -v "fallback\|safe\|clip\|limit\|check"
```

---

### RL06: 액션 스페이스 설계 오류

학습 환경과 실제 하드웨어의 action 범위/속도 불일치. 무한 범위나 rate limit 없으면 액추에이터 포화.

```python
# BAD -- 무한 범위 액션 스페이스 + 하드웨어 포화 무시
action_space = gym.spaces.Box(low=-np.inf, high=np.inf, shape=(6,))
# 학습: 시뮬레이터가 클립, 실제: 액추에이터 포화 + 전류 제한 -> 다른 동역학
```

```python
# GOOD -- 실제 액추에이터 범위 반영 + 레이트 리미팅
TORQUE_LIMITS = np.array([50.0, 50.0, 30.0, 20.0, 10.0, 5.0])  # Nm per joint
MAX_DELTA = TORQUE_LIMITS * 0.1  # 10% per step rate limit

action_space = gym.spaces.Box(
    low=-TORQUE_LIMITS, high=TORQUE_LIMITS, dtype=np.float32)

def apply_action(raw_action, prev_action):
    clipped = np.clip(raw_action, -TORQUE_LIMITS, TORQUE_LIMITS)
    delta = np.clip(clipped - prev_action, -MAX_DELTA, MAX_DELTA)
    return prev_action + delta
```

**grep 감지:**
```
grep -rn "action_space\|Box.*low.*high\|act.*clip" --include="*.py" | grep -v "rate_limit\|delta\|smooth\|prev_action\|MAX_DELTA"
```

---

## 4. 보상/학습 설계

### RL05: 보상 함수 설계 오류 (Reward Shaping Pitfalls)

보상 함수가 단일 목적만 반영하면 에이전트가 의도하지 않은 행동을 학습 (reward hacking).

```python
# BAD -- 거리 보상만 사용 -> 장애물 충돌하며 접근
def compute_reward(state):
    dist = np.linalg.norm(state.ee_pos - state.target_pos)
    return -dist  # 장애물 충돌, 관절 한계 초과, 에너지 낭비 무시
```

```python
# GOOD -- 다목적 보상 + 안전 페널티 + 보상 항목 로깅
def compute_reward(state, action, prev_action):
    dist = np.linalg.norm(state.ee_pos - state.target_pos)
    r_dist = -dist

    # 안전 페널티
    r_collision = -10.0 if state.has_collision else 0.0
    r_joint_limit = -5.0 * np.sum(np.abs(state.joint_pos) > JOINT_SOFT_LIMIT)

    # 에너지/스무스 페널티
    r_energy = -0.01 * np.sum(action**2)
    r_jerk = -0.005 * np.sum((action - prev_action)**2)

    reward = r_dist + r_collision + r_joint_limit + r_energy + r_jerk

    # 디버깅: 개별 보상 항목 기록
    log_reward_components(dist=r_dist, collision=r_collision,
                          joint=r_joint_limit, energy=r_energy, jerk=r_jerk)
    return reward
```

**grep 감지:**
```
grep -rn "def.*reward\|compute_reward\|reward_fn" --include="*.py" -A15 | grep -v "collision\|safety\|penalty\|limit\|energy\|smooth\|jerk\|log.*reward"
```

---

### RL09: 정책 경량화 없이 임베디드 배포

대형 모델을 리소스 제약 하드웨어에 그대로 배포하면 메모리/연산 예산 초과.

```python
# BAD -- 대형 모델을 그대로 임베디드 배포
# ResNet-50 backbone: 25M params, 200MB, Jetson에서 150ms
policy = load_model("resnet50_policy.pt")
action = policy(obs)
```

```python
# GOOD -- Teacher-Student 증류 + ONNX export
class StudentPolicy(nn.Module):
    """MLP 3-layer, 64 hidden, <100KB"""
    def __init__(self, obs_dim, act_dim):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(obs_dim, 64), nn.ReLU(),
            nn.Linear(64, 64), nn.ReLU(),
            nn.Linear(64, act_dim), nn.Tanh()
        )

# 증류 학습
teacher = load_model("resnet50_policy.pt")
student = StudentPolicy(obs_dim, act_dim)
for obs_batch in dataset:
    teacher_action = teacher(obs_batch).detach()
    student_action = student(obs_batch)
    loss = F.mse_loss(student_action, teacher_action)
    loss.backward()
    optimizer.step()

# ONNX export for embedded
torch.onnx.export(student, dummy, "student_policy.onnx", opset_version=11)
```

**grep 감지:**
```
grep -rn "load_model\|torch.load\|keras.models.load" --include="*.py" | grep -v "student\|distill\|small\|lite\|pruned\|quantized\|onnx"
```

---

## 빠른 참조 - 전체 grep 스캔

```bash
# RL 배포 위험 전체 스캔
echo "=== RL01: 추론 지연 ==="
grep -rn "predict\|forward\|inference" --include="*.py" -B5 | grep -v "thread\|async\|cache\|deadline"

echo "=== RL02: Sim2Real ==="
grep -rn "gym.make\|make_env" --include="*.py" -A10 | grep -v "random\|rand\|domain"

echo "=== RL03: 정규화 ==="
grep -rn "running_mean\|obs_rms\|VecNormalize" --include="*.py" | grep -v "save\|load\|freeze"

echo "=== RL04: 폴백 ==="
grep -rn "predict\|forward" --include="*.py" -A5 | grep "send_command\|set_torque" | grep -v "fallback\|safe"

echo "=== RL05: 보상 ==="
grep -rn "def.*reward\|compute_reward" --include="*.py" -A15 | grep -v "collision\|safety\|penalty"

echo "=== RL06: 액션 스페이스 ==="
grep -rn "action_space\|Box.*low.*high" --include="*.py" | grep -v "rate_limit\|delta"

echo "=== RL07: 주파수 ==="
grep -rn "predict\|forward" --include="*.py" -B10 | grep -i "dt\|freq\|hz" | grep -v "match\|ratio\|scale"

echo "=== RL08: 최적화 ==="
grep -rn "torch.load\|torch.no_grad\|model.eval" --include="*.py" | grep -v "onnx\|tensorrt\|tflite"

echo "=== RL09: 경량화 ==="
grep -rn "load_model\|torch.load" --include="*.py" | grep -v "student\|distill\|lite\|onnx"

echo "=== RL10: 상태 추정 ==="
grep -rn "obs.*read\|observation.*sensor" --include="*.py" -A3 | grep "predict\|policy" | grep -v "filter\|ekf\|valid"
```

---

## 심각도 등급

| 등급 | 패턴 | 결과 |
|------|------|------|
| CRITICAL | RL04 (폴백 없음), RL06 (액추에이터 포화) | 로봇 파손, 안전 사고 |
| HIGH | RL01 (추론 지연), RL02 (Sim2Real), RL10 (상태 추정) | 배포 실패, 불안정 동작 |
| MEDIUM | RL03 (정규화), RL05 (보상), RL07 (주파수) | 성능 저하, 재학습 필요 |
| LOW | RL08 (최적화), RL09 (경량화) | 효율 손실, 하드웨어 제약 시 블로커 |
