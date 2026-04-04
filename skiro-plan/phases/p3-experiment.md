# p3-experiment.md — 실험 계획 심화
# skiro-plan | experiment/milestone tier | ~580 tok

## 실험 설계 원칙

### 독립 변수 / 종속 변수 / 통제 변수
명확하게 분리하지 않으면 데이터 해석이 불가능해진다.
```
독립: 실험자가 변경하는 것 (게인값, 속도 설정, 보조력)
종속: 측정하는 것 (토크, 각도, GDI, 보행 속도)
통제: 일정하게 유지하는 것 (피험자, 환경, 온도)
```

### 샘플 수 계획
```
파일럿: 3회 반복 (패턴 확인용)
검증:   10회 이상 (통계적 의미)
논문:   24명 이상 피험자 (H-Grow IRB 기준)
```

### 데이터 저장 계획
```
파일명 규칙: YYYYMMDD_HHMMSS_<subject>_<condition>_<trial>.<ext>
백업: 실험 당일 외부 저장소 동기화
형식: CSV (원시) + JSON (메타데이터)
```

## 베이스라인 vs 조건 설계

H-Walker / H-Grow 전용:
```
Within-subject crossover (권장):
  Session A: Device-off → Device-on
  Session B: Device-on → Device-off
  Washout: 5분 이상

Between-subject (피험자 수 부족 시):
  Control group + Intervention group
  랜덤 배정 필수
```

## 통계 분석 계획
```
□ 정규성 검정: Shapiro-Wilk (n < 50)
□ 비모수: Wilcoxon signed-rank (정규성 미충족 시)
□ 모수:  Paired t-test (정규성 충족 시)
□ 효과 크기: Cohen's d
□ 유의 수준: α = 0.05
```

## current-experiment.json 확장 (experiment tier)
```json
{
  "experiment": {
    "iv": ["<독립변수>"],
    "dv": ["<종속변수>"],
    "cv": ["<통제변수>"],
    "n_trials": <N>,
    "data_path": "<저장 경로>",
    "baseline_condition": "<설명>"
  }
}
```
