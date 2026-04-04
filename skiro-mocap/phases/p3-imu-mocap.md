# p3-imu-mocap.md — IMU 기반 동작 분석
# skiro-mocap | IMU 트리거 시 | ~480 tok

## 센서 융합 (Madgwick 필터)

```python
import numpy as np

class MadgwickAHRS:
    """
    가속도계 + 자이로스코프 → 쿼터니언 자세 추정
    자기계 없는 버전 (IMU 전용)
    """
    def __init__(self, fs=100, beta=0.1):
        self.fs = fs
        self.dt = 1.0 / fs
        self.beta = beta
        self.q = np.array([1.0, 0.0, 0.0, 0.0])  # 초기 쿼터니언
    
    def update(self, gyr, acc):
        """
        gyr: (3,) rad/s
        acc: (3,) m/s² (정규화됨)
        """
        q = self.q
        
        # 정규화
        acc_norm = np.linalg.norm(acc)
        if acc_norm == 0:
            return
        acc = acc / acc_norm
        
        # 기울기 강하 (Madgwick)
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
        
        # 쿼터니언 적분
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
