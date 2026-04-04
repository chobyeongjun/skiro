# p2-analysis.md — GDI 및 보행 지표 분석
# skiro-gait | analysis 트리거 시 | ~590 tok

## GDI (Gait Deviation Index)

### 정의
정상 보행 패턴으로부터의 편차를 나타내는 단일 수치.
GDI = 100 → 정상 보행
GDI < 100 → 정상 대비 편차 (값이 낮을수록 이상)
H-Grow 목표: GDI 개선 ≥ 6.5 포인트 (device-off vs device-on)

### 계산 방법 (Schwartz & Rozumalski, 2008)
```python
import numpy as np

def compute_GDI(joint_angles_patient, normative_data):
    """
    joint_angles_patient: (N_cycles, 9_vars × 51_frames) array
      9 variables: 골반 전후경사/회전/측방경사, 고관절 굴곡/내외전/회전,
                   슬관절 굴곡, 족관절 배측굴곡, 족부 진행각
    normative_data: (9_vars × 51_frames) 정상 평균
    
    Returns: GDI score (float)
    """
    # 각 변수를 51 프레임으로 정규화 (보간)
    from scipy.interpolate import interp1d
    
    diffs = []
    for var_idx in range(9):
        p = joint_angles_patient[:, var_idx*51:(var_idx+1)*51].mean(axis=0)
        n = normative_data[var_idx]
        diffs.append(p - n)
    
    D = np.concatenate(diffs)  # 459 차원 벡터
    GDI = 100 - 10 * np.sqrt(np.dot(D, D) / len(D))
    return GDI
```

### GDI 해석
```
GDI ≥ 100:  정상 범위
80–99:       경미한 편차
60–79:       중등도 편차 (CP GMFCS I–II 전형)
< 60:         심각한 편차 (CP GMFCS III 이상)
```

### GDI-Kinetic (보완 지표)
운동역학(GRF, 관절 모멘트) 기반 추가 지표.
H-Grow 2차 평가 지표 (GDI가 primary).

## 보행 대칭성 지수

```python
def symmetry_index(param_left, param_right):
    """
    SI = 0: 완전 대칭
    SI > 0: 우측 우세
    SI < 0: 좌측 우세
    """
    return (param_right - param_left) / (0.5 * (param_right + param_left)) * 100

def gait_asymmetry(stride_time_L, stride_time_R, step_length_L, step_length_R):
    return {
        'time_SI': symmetry_index(stride_time_L, stride_time_R),
        'length_SI': symmetry_index(step_length_L, step_length_R)
    }
```

## H-Grow 임상 평가 프로토콜

```
Within-session 효과 측정:
  조건 1: Device-off  →  보행 측정 (3회 이상)
  5분 휴식
  조건 2: Device-on   →  보행 측정 (3회 이상)
  
  ΔΔ GDI = GDI(on) - GDI(off)  →  목표: +6.5 이상

GMFCS 분류 (H-Grow 대상: I–III):
  I: 제한 없이 독립 보행 (야외 포함)
  II: 야외·사회적 환경에서 제한
  III: 보조 기구로 독립 보행 (보행기 등)
```
