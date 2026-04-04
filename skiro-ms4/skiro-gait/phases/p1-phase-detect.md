# p1-phase-detect.md — 보행 위상 감지
# skiro-gait | always load | ~680 tok

## 보행 주기 정의

```
보행 주기 (Gait Cycle) = Heel Strike(HS) → 다음 HS
  Stance Phase: HS(0%) → Toe Off(TO, ~60%)
  Swing Phase:  TO(60%) → 다음 HS(100%)

서브 이벤트:
  Loading Response:   0–10%   (체중 부하)
  Mid Stance:        10–30%  (단일 지지)
  Terminal Stance:   30–50%  (발뒤꿈치 들림)
  Pre-Swing:         50–60%  (발가락 이지)
  Initial Swing:     60–73%
  Mid Swing:         73–87%
  Terminal Swing:    87–100%
```

## Heel Strike / Toe Off 감지 알고리즘

### 방법 1: 수직 지면반력(GRF) 기반 (Gold Standard)
```python
THRESHOLD_HS = 20  # N (힘판 기준)
THRESHOLD_TO = 10  # N

def detect_hs_to(grf_z, threshold_hs=20, threshold_to=10):
    """
    Returns: list of (event_type, frame_index)
    """
    events = []
    in_stance = False
    for i, f in enumerate(grf_z):
        if not in_stance and f > threshold_hs:
            events.append(('HS', i))
            in_stance = True
        elif in_stance and f < threshold_to:
            events.append(('TO', i))
            in_stance = False
    return events
```

### 방법 2: IMU 가속도 기반 (웨어러블, H-Grow)
```python
import numpy as np
from scipy.signal import find_peaks

def detect_hs_imu(accel_vertical, fs=100):
    """
    수직 가속도 피크 = Heel Strike
    fs: 샘플링 주파수 (Hz)
    """
    # 버터워스 저역통과 필터 (20Hz)
    from scipy.signal import butter, filtfilt
    b, a = butter(4, 20/(fs/2), btype='low')
    accel_f = filtfilt(b, a, accel_vertical)
    
    # 피크 감지 (최소 간격: 0.4s = 보행 속도 1.5m/s 기준)
    min_dist = int(0.4 * fs)
    peaks, _ = find_peaks(accel_f, height=0.5, distance=min_dist)
    return peaks  # HS 프레임 인덱스

def detect_to_imu(gyro_sagittal, fs=100):
    """
    시상면 각속도 극소값 = Toe Off
    """
    from scipy.signal import find_peaks
    valleys, _ = find_peaks(-gyro_sagittal, height=0.3, distance=int(0.3*fs))
    return valleys
```

### 방법 3: 영상 기반 (ZED + YOLO26s, H-Walker)
```python
# 발뒤꿈치 y좌표의 극소값 = HS (바닥 접촉)
# 발가락 y좌표의 극소값에서 극대값으로 전환 = TO

def detect_hs_to_vision(heel_y_3d, toe_y_3d, threshold=0.02):
    """
    heel_y_3d: 뒤꿈치 수직 좌표 시계열 (미터)
    threshold: 바닥 접촉 판정 높이 (m)
    """
    hs_frames = np.where(np.diff((heel_y_3d < threshold).astype(int)) > 0)[0]
    to_frames  = np.where(np.diff((toe_y_3d < threshold).astype(int)) < 0)[0]
    return hs_frames, to_frames
```

## 시공간 파라미터 계산

```python
def compute_spatiotemporal(hs_times, to_times, step_length_m):
    """모든 시간 단위: 초"""
    stride_times = np.diff(hs_times[::2])  # 동측 HS간 시간
    cadence = 60.0 / np.mean(stride_times)  # steps/min
    gait_speed = np.mean(step_length_m) * cadence / 60  # m/s
    
    stance_pct = []
    for i in range(min(len(hs_times), len(to_times))):
        s = (to_times[i] - hs_times[i]) / stride_times[i % len(stride_times)] * 100
        stance_pct.append(s)
    
    return {
        'cadence': cadence,
        'gait_speed': gait_speed,
        'stride_time_mean': np.mean(stride_times),
        'stance_pct_mean': np.mean(stance_pct),
        'swing_pct_mean': 100 - np.mean(stance_pct)
    }
```
