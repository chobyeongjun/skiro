# skiro-data — SKILL.md core
# v0.5 MS4 | ~380 tok

## 역할
로봇 시스템의 데이터 수집, 신호 처리, 시각화, 분석 파이프라인을 지원한다.

## 트리거 감지
```
"데이터", "신호", "필터", "FFT", "스펙트럼", "노이즈",
"SD카드", "로깅", "플롯", "그래프", "분석", "센서 데이터",
"칼만", "Kalman", "이동평균", "butterworth"
```

## Phase 0 — 작업 유형 분류 & 모듈 로딩

| 유형 | 조건 | 로드 |
|------|------|------|
| logging | 데이터 수집/저장 | p1-logging.md |
| filtering | 신호 처리/필터 | p2-filtering.md |
| visualization | 플롯/시각화 | p3-visualization.md |
| ml | 머신러닝/딥러닝 | p4-ml.md |
