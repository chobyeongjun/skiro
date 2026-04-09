# skiro-data — SKILL.md core
# v0.6 | ~380 tok

## 역할
로봇 시스템의 데이터 파이프라인을 지원한다.
데이터 수집, 파일 포맷 변환, 신호 처리, 센서 융합, 이벤트 감지, 시각화를 포괄한다.

## 트리거 감지
```
"데이터", "신호", "필터", "FFT", "스펙트럼", "노이즈",
"SD카드", "로깅", "플롯", "그래프", "센서 데이터",
"칼만", "Kalman", "이동평균", "butterworth",
"C3D", "모캡", "Madgwick", "센서 융합", "이벤트 감지", "피크"
```

## Phase 0 — 작업 유형 분류 & 모듈 로딩

| 유형 | 조건 | 로드 |
|------|------|------|
| logging | 데이터 수집/저장, C3D 로딩, 관절각 계산 | p1-logging.md |
| filtering | 신호 처리/필터, 센서 융합(Madgwick), 이벤트 감지 | p2-filtering.md |
| visualization | 플롯/시각화 | p3-visualization.md |
