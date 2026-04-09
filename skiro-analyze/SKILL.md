# skiro-analyze — SKILL.md core
# v0.6 | ~360 tok

## 역할
실험 결과 및 시스템 성능 분석을 지원한다.
Bode 플롯, 주파수 응답, 제어 성능, 통계 분석, ILC 수렴 분석을 포괄한다.

## 트리거 감지
```
"분석", "analyze", "Bode", "주파수 응답", "대역폭",
"성능", "오차", "RMSE", "통계", "t-test", "유의", "수렴",
"ILC", "임피던스", "대칭", "symmetry"
```

## Phase 0 — 분석 유형 & 모듈 로딩

| 유형 | 조건 | 로드 |
|------|------|------|
| control | Bode, 제어 성능, 안정성, ILC 수렴 | p1-control-analysis.md |
| stats | 통계 검정, 실험 결과, 대칭성 | p2-statistics.md |
