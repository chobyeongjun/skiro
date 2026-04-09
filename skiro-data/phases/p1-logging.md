# p1-logging.md — 데이터 로깅
# skiro-data | logging 트리거 시 | ~580 tok

## STM32 SD카드 로깅 (FATFS + SPI)

```c
// 파일명: YYYYMMDD_HHMMSS.csv
// 헤더 1회 작성 후 루프에서 데이터 추가

void logging_init(void) {
    f_mount(&SDFatFS, "", 1);
    char filename[32];
    // RTC에서 시간 읽기
    RTC_TimeTypeDef sTime;
    RTC_DateTypeDef sDate;
    HAL_RTC_GetTime(&hrtc, &sTime, RTC_FORMAT_BIN);
    HAL_RTC_GetDate(&hrtc, &sDate, RTC_FORMAT_BIN);
    snprintf(filename, sizeof(filename), "%02d%02d%02d_%02d%02d%02d.csv",
             sDate.Year, sDate.Month, sDate.Date,
             sTime.Hours, sTime.Minutes, sTime.Seconds);
    f_open(&SDFile, filename, FA_CREATE_ALWAYS | FA_WRITE);
    f_printf(&SDFile, "tick,pos,vel,current,temp\r\n");  // 헤더
}

// 제어 루프 내 (9ms 주기):
void logging_write(float pos, float vel, float curr, float temp) {
    static uint32_t log_tick = 0;
    // 매 10번째 호출만 기록 (로깅 주파수: 111Hz/10 = ~11Hz)
    if(++log_tick % 10 == 0) {
        f_printf(&SDFile, "%lu,%.4f,%.4f,%.4f,%.2f\r\n",
                 HAL_GetTick(), pos, vel, curr, temp);
        // 비동기 flush (매 100번째마다)
        if(log_tick % 100 == 0) f_sync(&SDFile);
    }
}
```

## ROS2 rosbag2 로깅

```bash
# 녹화
ros2 bag record -o session_20260404 \
    /hw/motor/state /hw/imu/data /hw/load_cell/force /hw/gait/phase

# 재생
ros2 bag play session_20260404

# 정보 확인
ros2 bag info session_20260404

# CSV 변환 (ros2_bag_to_csv 또는 직접)
python3 -c "
import sqlite3, pandas as pd
conn = sqlite3.connect('session_20260404/session_20260404_0.db3')
topics = pd.read_sql('SELECT * FROM topics', conn)
print(topics)
"
```

## Python 실시간 로거 (Jetson)

```python
import csv, time, threading
from pathlib import Path
from datetime import datetime

class DataLogger:
    def __init__(self, fields, rate_hz=100):
        ts = datetime.now().strftime('%Y%m%d_%H%M%S')
        self.path = Path(f'data/{ts}.csv')
        self.path.parent.mkdir(exist_ok=True)
        self.fields = fields
        self.dt = 1.0 / rate_hz
        self._buf = []
        self._lock = threading.Lock()
        
        with open(self.path, 'w', newline='') as f:
            csv.DictWriter(f, fieldnames=fields).writeheader()
    
    def log(self, **kwargs):
        kwargs['timestamp'] = time.time()
        with self._lock:
            self._buf.append(kwargs)
        if len(self._buf) >= 100:  # 배치 플러시
            self.flush()
    
    def flush(self):
        with self._lock:
            buf, self._buf = self._buf, []
        with open(self.path, 'a', newline='') as f:
            w = csv.DictWriter(f, fieldnames=['timestamp'] + self.fields)
            w.writerows(buf)
```

## C3D 파일 로딩 (모션캡처 / 3D 데이터)

```python
import c3d
import numpy as np

def load_c3d(filepath):
    """
    C3D (Coordinate 3D) 파일 로드 — VICON 등 광학 모션캡처 표준 포맷
    Returns:
        markers: dict {marker_name: (N_frames, 3) array in mm}
        meta: {rate, n_frames}
    """
    with open(filepath, 'rb') as f:
        reader = c3d.Reader(f)
        marker_names = [p.strip().decode() for p in reader.point_labels]
        
        markers_raw = []
        for i, points, analog in reader.read_frames():
            markers_raw.append(points[:, :3])
        
        markers_arr = np.array(markers_raw)
    
    markers = {name: markers_arr[:, i, :]
               for i, name in enumerate(marker_names)}
    
    return markers, {'rate': reader.point_rate, 'n_frames': len(markers_raw)}

def fill_marker_gaps(marker_data, max_gap_frames=10):
    """마커 소실 구간 (0,0,0) 선형 보간"""
    data = marker_data.copy()
    missing = np.all(data == 0, axis=1)
    if not missing.any():
        return data
    
    from scipy.ndimage import label
    gaps, n_gaps = label(missing)
    for g in range(1, n_gaps + 1):
        idx = np.where(gaps == g)[0]
        if len(idx) <= max_gap_frames:
            start, end = idx[0] - 1, idx[-1] + 1
            if start >= 0 and end < len(data):
                for j in range(3):
                    data[idx, j] = np.interp(idx, [start, end],
                                              [data[start, j], data[end, j]])
    return data
```

## 관절각 계산 (세그먼트 벡터 기반)

```python
def compute_joint_angle(prox_a, dist_a, prox_b, dist_b):
    """
    두 세그먼트 간 관절각 계산
    각 포인트: (3,) array (mm)
    Returns: 관절 굴곡 각도 (degrees), 0=신전, 양수=굴곡
    """
    vec_a = dist_a - prox_a
    vec_b = dist_b - prox_b
    cos_angle = np.dot(vec_a, vec_b) / (
        np.linalg.norm(vec_a) * np.linalg.norm(vec_b) + 1e-9)
    angle = np.degrees(np.arccos(np.clip(cos_angle, -1, 1)))
    return 180 - angle
```
