# p1-vicon.md — VICON 모션캡처
# skiro-mocap | VICON 트리거 시 | ~540 tok

## C3D 파일 처리 (Python)

```python
import c3d
import numpy as np

def load_c3d(filepath):
    """
    Returns:
        markers: dict {marker_name: (N_frames, 3) array in mm}
        analogs: dict {channel_name: (N_frames,) array}
        meta: {rate_markers, rate_analogs, n_frames}
    """
    with open(filepath, 'rb') as f:
        reader = c3d.Reader(f)
        
        marker_names = [p.strip().decode() for p in reader.point_labels]
        analog_names = [p.strip().decode() for p in reader.analog_labels]
        
        markers_raw = []
        analogs_raw = []
        for i, points, analog in reader.read_frames():
            markers_raw.append(points[:, :3])  # XYZ (mm)
            analogs_raw.append(analog)
        
        markers_arr = np.array(markers_raw)  # (N_frames, N_markers, 3)
        
    markers = {name: markers_arr[:, i, :] 
               for i, name in enumerate(marker_names)}
    
    return markers, {}, {
        'rate': reader.point_rate,
        'n_frames': len(markers_raw)
    }

# 갭 채우기 (선형 보간)
def fill_gaps(marker_data, max_gap_frames=10):
    """마커 소실 구간 (0, 0, 0) 선형 보간"""
    data = marker_data.copy()
    missing = np.all(data == 0, axis=1)
    
    if not missing.any():
        return data
    
    # 연속 소실 구간 탐지
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

## 관절각 계산 (세그먼트 기반)

```python
def compute_knee_angle(thigh_prox, thigh_dist, shank_prox, shank_dist):
    """
    각 포인트: (3,) array (mm)
    Returns: knee flexion angle in degrees
    """
    thigh_vec = thigh_dist - thigh_prox
    shank_vec = shank_dist - shank_prox
    
    cos_angle = np.dot(thigh_vec, shank_vec) / (
        np.linalg.norm(thigh_vec) * np.linalg.norm(shank_vec) + 1e-9)
    angle = np.degrees(np.arccos(np.clip(cos_angle, -1, 1)))
    return 180 - angle  # 신전 = 0, 굴곡 = 양수
```
