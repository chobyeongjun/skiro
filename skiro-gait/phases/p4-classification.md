# p4-classification.md — 보행 패턴 분류
# skiro-gait | classification 트리거 시 | ~550 tok

## 분류 파이프라인 (H-Grow Physical AI 기초)

```python
import numpy as np
from sklearn.preprocessing import StandardScaler

class GaitClassifier:
    """
    ARLAB gait classification v3.0 기반
    Rolling STD + AutoCorrelation 특징 추출
    """
    def __init__(self, window_sec=3.0, fs=100):
        self.window = int(window_sec * fs)
        self.fs = fs
        self.scaler = StandardScaler()
    
    def extract_features(self, accel, gyro):
        """
        accel, gyro: (N, 3) array
        Returns: feature vector
        """
        features = []
        
        # Rolling STD (보행 주기성 측도)
        for sig in [accel[:, 0], accel[:, 2], gyro[:, 1]]:
            stds = []
            for i in range(0, len(sig) - self.window, self.window // 2):
                stds.append(np.std(sig[i:i+self.window]))
            features.extend([np.mean(stds), np.std(stds)])
        
        # AutoCorrelation (주기 추정)
        accel_mag = np.linalg.norm(accel, axis=1)
        ac = np.correlate(accel_mag - accel_mag.mean(),
                          accel_mag - accel_mag.mean(), mode='full')
        ac = ac[len(ac)//2:]
        ac /= ac[0]
        
        # 첫 번째 피크 = 보행 주기 추정
        from scipy.signal import find_peaks
        peaks, _ = find_peaks(ac, height=0.3, distance=int(0.4*self.fs))
        if len(peaks) > 0:
            features.append(peaks[0] / self.fs)      # 주기 (s)
            features.append(ac[peaks[0]])              # 피크 높이 (규칙성)
        else:
            features.extend([0.0, 0.0])
        
        return np.array(features)
    
    def classify(self, features):
        """
        Returns: label (str), confidence (float)
        Label: 'normal', 'hemiplegia', 'diplegia', 'crouch', 'stiff_knee'
        """
        # 모델 추론 (학습된 분류기 사용)
        raise NotImplementedError("학습된 모델 연결 필요")
```

## H-Grow 1차년도 분류 목표

```
분류 대상: GMFCS I–III CP 아동 보행 패턴
  - 정상 보행 (대조군)
  - 경직형 편마비 (hemiplegia)
  - 경직형 양지마비 (diplegia)
  - Crouch gait (과도한 무릎 굴곡)
  - Stiff-knee gait (무릎 굴곡 부족)

라벨링 방법:
  - 임상의(박문석 PI) 검토 + 동작 분석 시스템(VICON) 기준

데이터 구조 (횡단 DB):
  subject_id, age, weight, height, GMFCS, diagnosis,
  imu_file, gait_label, gdi_score, session_date
```

## SCONE 연동 (Digital Twin)

```python
# SCONE 시뮬레이션 출력 → 분류 입력
# SCONE: musculoskeletal simulation (OpenSim 기반)
# 목표: 실측 보행 패턴 재현 + 보조력 효과 예측

def load_scone_output(sto_file):
    """
    SCONE .sto 파일 → pandas DataFrame
    컬럼: time, joint_angles×9, muscle_forces×N
    """
    import pandas as pd
    return pd.read_csv(sto_file, sep='\t', skiprows=11)
```
