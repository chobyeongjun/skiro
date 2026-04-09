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

def dominant_frequency(signal, fs, freq_range=(0.5, 3.0)):
    """주요 주파수 추출 (주기적 동작 추정에 사용)"""
    freqs, psd = compute_psd(signal, fs)
    mask = (freqs >= freq_range[0]) & (freqs <= freq_range[1])
    dominant = freqs[mask][np.argmax(psd[mask])]
    return dominant  # Hz
```

## 센서 융합 — Madgwick AHRS

```python
import numpy as np

class MadgwickAHRS:
    """
    가속도계 + 자이로스코프 → 쿼터니언 자세 추정
    자기계 없는 버전 (IMU 전용)
    용도: 로봇 관절각 추정, 자세 추적, 웨어러블 IMU
    """
    def __init__(self, fs=100, beta=0.1):
        self.fs = fs
        self.dt = 1.0 / fs
        self.beta = beta
        self.q = np.array([1.0, 0.0, 0.0, 0.0])
    
    def update(self, gyr, acc):
        """
        gyr: (3,) rad/s
        acc: (3,) m/s² (정규화됨)
        """
        q = self.q
        acc_norm = np.linalg.norm(acc)
        if acc_norm == 0:
            return
        acc = acc / acc_norm
        
        f = np.array([
            2*(q[1]*q[3] - q[0]*q[2]) - acc[0],
            2*(q[0]*q[1] + q[2]*q[3]) - acc[1],
            2*(0.5 - q[1]**2 - q[2]**2) - acc[2]
        ])
        J = np.array([
            [-2*q[2],  2*q[3], -2*q[0], 2*q[1]],
            [ 2*q[1],  2*q[0],  2*q[3], 2*q[2]],
            [ 0,      -4*q[1], -4*q[2], 0     ]
        ])
        step = J.T @ f
        step /= (np.linalg.norm(step) + 1e-9)
        
        q_dot = 0.5 * np.array([
            -q[1]*gyr[0] - q[2]*gyr[1] - q[3]*gyr[2],
             q[0]*gyr[0] + q[2]*gyr[2] - q[3]*gyr[1],
             q[0]*gyr[1] - q[1]*gyr[2] + q[3]*gyr[0],
             q[0]*gyr[2] + q[1]*gyr[1] - q[2]*gyr[0]
        ]) - self.beta * step
        
        self.q += q_dot * self.dt
        self.q /= np.linalg.norm(self.q)
    
    def get_euler(self):
        """Returns: (roll, pitch, yaw) in degrees"""
        q = self.q
        roll  = np.degrees(np.arctan2(2*(q[0]*q[1]+q[2]*q[3]),
                                      1-2*(q[1]**2+q[2]**2)))
        pitch = np.degrees(np.arcsin(2*(q[0]*q[2]-q[3]*q[1])))
        yaw   = np.degrees(np.arctan2(2*(q[0]*q[3]+q[1]*q[2]),
                                      1-2*(q[2]**2+q[3]**2)))
        return roll, pitch, yaw
```

## 주기 신호 이벤트 감지

```python
import numpy as np
from scipy.signal import find_peaks, butter, filtfilt

def detect_periodic_events(signal, fs, method='peak', cutoff_hz=20, min_interval_s=0.4):
    """
    주기적 신호에서 이벤트(피크/밸리) 감지
    용도: 보행 HS/TO, 모터 사이클, 반복 동작 감지
    
    signal: 1D array
    fs: 샘플링 주파수 (Hz)
    method: 'peak' | 'valley' | 'threshold'
    cutoff_hz: 저역통과 필터 차단 주파수
    min_interval_s: 최소 이벤트 간격 (초)
    """
    b, a = butter(4, cutoff_hz / (fs / 2), btype='low')
    filtered = filtfilt(b, a, signal)
    min_dist = int(min_interval_s * fs)
    
    if method == 'peak':
        events, props = find_peaks(filtered, height=0.5, distance=min_dist)
    elif method == 'valley':
        events, props = find_peaks(-filtered, height=0.3, distance=min_dist)
    elif method == 'threshold':
        events = _detect_threshold_crossings(filtered, threshold=0.5)
    
    return events

def detect_threshold_events(signal, threshold_high, threshold_low):
    """
    임계값 기반 이벤트 감지 (힘판, 접촉 센서 등)
    Returns: list of (event_type, frame_index)
    """
    events = []
    active = False
    for i, val in enumerate(signal):
        if not active and val > threshold_high:
            events.append(('ON', i))
            active = True
        elif active and val < threshold_low:
            events.append(('OFF', i))
            active = False
    return events

def compute_cycle_params(event_times):
    """주기 파라미터 계산 (이벤트 시간 배열)"""
    cycle_times = np.diff(event_times)
    return {
        'frequency': 1.0 / np.mean(cycle_times),
        'cycle_time_mean': np.mean(cycle_times),
        'cycle_time_std': np.std(cycle_times),
    }
```
