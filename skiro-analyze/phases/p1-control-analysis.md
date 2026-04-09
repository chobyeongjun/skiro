# p1-control-analysis.md — 제어 시스템 분석
# skiro-analyze | control 트리거 시 | ~680 tok

## Bode 플롯 (MATLAB)

```matlab
% H-Walker 임피던스 제어 주파수 응답 측정
% 입력: 위치 명령 (처프 신호)
% 출력: 실제 위치 (엔코더)

% 1. 처프 신호 생성 (0.1 ~ 30 Hz, 30초)
fs = 1000;  % 샘플링: 1kHz (CAN TX)
t = 0:1/fs:30;
f_start = 0.1; f_end = 30;
chirp_sig = chirp(t, f_start, 30, f_end, 'logarithmic');

% 2. MATLAB에서 FRF 계산 (tfestimate)
[Txy, f] = tfestimate(input_log, output_log, [], [], [], fs);

% 3. Bode 플롯
figure;
subplot(2,1,1);
semilogx(f, 20*log10(abs(Txy)));
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
grid on; title('Bode Plot - Impedance Controller');
xline(10, '--r', 'Target BW');  % 목표 대역폭

subplot(2,1,2);
semilogx(f, angle(Txy)*180/pi);
xlabel('Frequency (Hz)'); ylabel('Phase (deg)');
grid on;

% 4. 대역폭 추출 (-3dB point)
mag_db = 20*log10(abs(Txy));
bw_idx = find(mag_db < mag_db(1) - 3, 1);
bw_hz = f(bw_idx);
fprintf('대역폭: %.1f Hz\n', bw_hz);
```

## ILC 수렴 분석

```matlab
function analyze_ILC_convergence(errors_per_stride)
    % errors_per_stride: (N_strides × T_samples) 오차 행렬
    
    rms_per_stride = sqrt(mean(errors_per_stride.^2, 2));
    
    figure;
    semilogy(rms_per_stride, 'b-o');
    xlabel('Stride Number'); ylabel('RMS Error (rad)');
    title('ILC Convergence'); grid on;
    
    % 수렴 판정: 마지막 10 stride에서 변화량 < 5%
    last10 = rms_per_stride(end-9:end);
    cv = std(last10) / mean(last10) * 100;
    if cv < 5
        fprintf('수렴: YES (CV=%.1f%%)\n', cv);
    else
        fprintf('미수렴: NO (CV=%.1f%%) — 학습률 조정 필요\n', cv);
    end
end
```

## 제어 성능 지표

```python
import numpy as np

def compute_control_metrics(q_des, q_meas, dt):
    """
    q_des, q_meas: (N,) array (rad)
    dt: 샘플 시간 (s)
    """
    error = q_des - q_meas
    
    rmse = np.sqrt(np.mean(error**2))
    mae  = np.mean(np.abs(error))
    peak = np.max(np.abs(error))
    
    # 정착 시간 (±5% 범위 내 유지)
    threshold = 0.05 * np.max(np.abs(q_des))
    settled = np.where(np.abs(error) < threshold)[0]
    settle_time = settled[0] * dt if len(settled) > 0 else np.inf
    
    # 오버슈트
    overshoot = (peak - np.max(np.abs(q_des))) / np.max(np.abs(q_des)) * 100
    overshoot = max(0, overshoot)
    
    return {
        'RMSE': rmse,
        'MAE':  mae,
        'Peak': peak,
        'Settle_time': settle_time,
        'Overshoot_pct': overshoot
    }
```
