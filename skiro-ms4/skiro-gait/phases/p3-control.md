# p3-control.md — 보행 보조 제어
# skiro-gait | control 트리거 시 | ~640 tok

## H-Walker 제어 아키텍처

```
outer loop: ILC (stride-to-stride feedforward)
  ↓ tau_ff 생성
inner loop: Impedance Control (111Hz)
  ↓ tau_total = tau_ff + tau_impedance
  ↓
CAN TX → AK60-6 Motors (1kHz)
```

## Impedance Control (Inner Loop, 111Hz)

```cpp
// 임피던스 제어 (Tustin 이산화 권장)
struct ImpedanceController {
    float K;   // 강성 (N·m/rad)
    float B;   // 댐핑 (N·m·s/rad)
    float M;   // 관성 (N·m·s²/rad)
    float dt;  // 샘플 시간 (1/111 ≈ 9ms)
    
    float q_prev, qd_prev, qdd;
    
    float compute(float q_des, float q_meas, float qd_meas) {
        float q_err  = q_des - q_meas;
        float qd_err = 0.0f - qd_meas;  // 속도 목표 = 0 (위치 제어)
        
        // Tustin (bilinear transform)
        qdd = (2.0f/dt) * (qd_meas - qd_prev) - qdd;
        qd_prev = qd_meas;
        
        float tau = M * qdd + B * qd_err + K * q_err;
        
        // 포화 (안전 상한)
        const float TAU_MAX = 15.0f;  // Nm
        tau = fmaxf(-TAU_MAX, fminf(TAU_MAX, tau));
        return tau;
    }
};
```

## ILC (Iterative Learning Control, Stride-to-Stride)

```matlab
% MATLAB: ILC 업데이트 법칙
% e(k) = q_des(k) - q_meas(k)  (k번째 보행 주기 오차)
% u(k+1) = u(k) + L * e(k)     (피드포워드 업데이트)

function u_next = ILC_update(u_prev, e_k, L, gamma)
    % L: 학습률 (0 < L < 1, 보통 0.3–0.7)
    % gamma: 망각 인자 (0.95–1.0, 1.0이면 완전 기억)
    u_next = gamma * u_prev + L * e_k;
    
    % 수렴 조건: ||I - L*G|| < 1 (G: 플랜트 전달함수)
    % 실용적 안전 상한: |u_next| < TAU_MAX
    u_next = max(-15, min(15, u_next));
end
```

## 보조 전략 (H-Grow Physical AI 출력)

```python
# Physical AI 출력: IMU 입력 → 보조력 프로파일
# end-to-end 정책 (진단 아님, 최적 보조 탐색)

class AssistancePolicy:
    """
    입력: IMU 시계열 (가속도 + 각속도, 6DoF × T)
    출력: 보조력 프로파일 (무릎 굴곡/신전 Nm × T)
    실시간 추론 불필요 — stride 단위 업데이트
    """
    def __init__(self, model_path):
        import torch
        self.model = torch.load(model_path)
        self.model.eval()
    
    def predict(self, imu_sequence):
        import torch
        with torch.no_grad():
            x = torch.FloatTensor(imu_sequence).unsqueeze(0)
            force_profile = self.model(x).numpy().squeeze()
        return force_profile  # shape: (T,) Nm
```

## 안전 제한 (보조 제어 공통)

```
무릎 굴곡 지원:   0 ~ +12 Nm (신전 방향 양수)
무릎 신전 저항:   0 ~ -5 Nm
최대 보조 속도:   제어 주기 간 변화량 ≤ 2 Nm/step
비상 해제:        GRF < 10N이고 보행 없음 → 3초 내 보조력 0으로 감속
```
