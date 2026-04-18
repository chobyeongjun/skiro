---
description: "로봇 GUI/HMI 설계. 실시간 모니터링, 제어 패널, PyQt, Tkinter, RQt. 키워드: GUI, 인터페이스, 모니터링, 대시보드, 플롯, PyQt, tkinter, 슬라이더, 버튼, 실시간 그래프"
---

# skiro-gui — SKILL.md core
# v0.5 MS4 | ~360 tok

## 역할
로봇 시스템의 GUI/HMI 설계 및 구현을 지원한다.
실시간 모니터링, 제어 패널, 데이터 시각화 GUI를 포괄한다.

## 트리거 감지
```
"GUI", "인터페이스", "모니터링", "대시보드", "플롯 창",
"PyQt", "tkinter", "RQt", "슬라이더", "버튼", "실시간 그래프",
"HMI", "패널", "창", "뷰어"
```

## Phase 0 — GUI 유형 분류 & 모듈 로딩

| 유형 | 조건 | 로드 |
|------|------|------|
| realtime | 실시간 데이터 표시 | p1-realtime.md |
| control | 제어 패널 (슬라이더, 버튼) | p2-control-panel.md |
| rqt | ROS2 RQt 플러그인 | p3-rqt.md |
| web | 웹 기반 대시보드 | p4-web.md |
