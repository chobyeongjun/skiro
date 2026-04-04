# p2-filtering.md — 신호 처리 & 필터
# skiro-data | filtering 트리거 시 | ~620 tok

## 버터워스 저역통과 필터 (Python/MATLAB)

```python
from scipy.signal import butter, filtfilt
import numpy as np

def butter_lowpass(data, cutoff_hz, fs_hz, order=4):
    """
    data: 1D array
    cutoff_hz: 차단 주파수 (Hz)
    fs_hz: 샘플링 주파수 (Hz)
    """
    nyq = 0.5 * fs_hz
    normal_cutoff = cutoff_hz / nyq
    b, a = butter(order, normal_cutoff, btype='low', analog=False)
    return filtfilt(b, a, data)  # 위상 지연 없음 (양방향)

# 예시: IMU 가속도 필터 (100Hz 샘플, 20Hz 차단)
accel_filtered = butter_lowpass(accel_raw, cutoff_hz=20, fs_hz=100)
```

```matlab
% MATLAB 등가 코드
fs = 100; fc = 20;
[b, a] = butter(4, fc/(fs/2), 'low');
accel_filtered = filtfilt(b, a, accel_raw);
```

## 이동평균 필터 (STM32 실시간)

```c
// 링 버퍼 기반 이동평균 (N=10)
#define MA_SIZE 10
typedef struct {
    float buf[MA_SIZE];
    uint8_t idx;
    float sum;
    bool full;
} MovingAvg;

float MA_update(MovingAvg *ma, float val) {
    ma->sum -= ma->buf[ma->idx];
    ma->buf[ma->idx] = val;
    ma->sum += val;
    ma->idx = (ma->idx + 1) % MA_SIZE;
    if(!ma->full && ma->idx == 0) ma->full = true;
    return ma->sum / (ma->full ? MA_SIZE : (ma->idx + 1));
}
```

## 칼만 필터 (1D, 위치/속도 추정)

```python
class KalmanFilter1D:
    """
    상태: [position, velocity]
    측정: position (IMU 적분 or 엔코더)
    """
    def __init__(self, dt, process_noise=0.01, meas_noise=0.1):
        import numpy as np
        self.dt = dt
        self.F = np.array([[1, dt], [0, 1]])  # 상태 전이
        self.H = np.array([[1, 0]])             # 측정 행렬
        self.Q = process_noise * np.eye(2)     # 프로세스 노이즈
        self.R = np.array([[meas_noise]])       # 측정 노이즈
        self.P = np.eye(2)                     # 오차 공분산
        self.x = np.zeros(2)                   # 상태 추정
    
    def predict(self):
        self.x = self.F @ self.x
        self.P = self.F @ self.P @ self.F.T + self.Q
    
    def update(self, z):
        import numpy as np
        S = self.H @ self.P @ self.H.T + self.R
        K = self.P @ self.H.T @ np.linalg.inv(S)  # 칼만 이득
        self.x = self.x + K @ (np.array([z]) - self.H @ self.x)
        self.P = (np.eye(2) - K @ self.H) @ self.P
        return self.x[0], self.x[1]  # position, velocity
```

## FFT / 스펙트럼 분석

```python
import numpy as np

def compute_psd(signal, fs):
    """Power Spectral Density (Welch method)"""
    from scipy.signal import welch
    freqs, psd = welch(signal, fs=fs, nperseg=256)
    return freqs, psd

def dominant_frequency(signal, fs):
    """주요 주파수 (보행 주기 추정에 사용)"""
    freqs, psd = compute_psd(signal, fs)
    # 보행 주파수 범위: 0.5–3 Hz
    mask = (freqs >= 0.5) & (freqs <= 3.0)
    dominant = freqs[mask][np.argmax(psd[mask])]
    return dominant  # Hz
```
