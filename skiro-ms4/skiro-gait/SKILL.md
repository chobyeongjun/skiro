# skiro-gait — SKILL.md core
# v0.5 MS4 | ~380 tok

## 역할
보행 분석, 보행 재활 로봇 제어, 보행 패턴 분류를 지원한다.
H-Walker(성인 보행 재활), H-Grow(소아 CP 보조)에 특화.

## 트리거 감지
```
"보행", "gait", "stride", "걸음", "스윙", "swing", "stance",
"GDI", "cadence", "step detect", "보행 위상", "보행 패턴",
"GMFCS", "CP", "뇌성마비", "편마비"
```

## Phase 0 — 작업 유형 분류 & 모듈 로딩

| 유형 | 조건 | 로드 |
|------|------|------|
| detection | 보행 위상 감지, 이벤트 검출 | p1-phase-detect.md |
| analysis | GDI, 시공간 파라미터 분석 | p2-analysis.md |
| control | 보행 보조력 제어, ILC | p3-control.md |
| classification | 패턴 분류, ML | p1-phase-detect.md + p4-classification.md |
