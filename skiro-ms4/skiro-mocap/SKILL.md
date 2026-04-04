# skiro-mocap — SKILL.md core
# v0.5 MS4 | ~340 tok

## 역할
모션 캡처 데이터 수집, 처리, 로봇 시스템과의 통합을 지원한다.
VICON, ZED, IMU 기반 동작 분석을 포괄한다.

## 트리거 감지
```
"mocap", "모션캡처", "VICON", "마커", "marker", "궤적", "trajectory",
"ZED", "3D 좌표", "포즈", "pose", "관절 위치", "skeleton"
```

## Phase 0 — 시스템 분류 & 모듈 로딩

| 시스템 | 조건 | 로드 |
|--------|------|------|
| vicon | VICON, C3D, 광학 | p1-vicon.md |
| zed | ZED SDK, GMSL2, 스테레오 | p2-zed.md |
| imu | IMU 기반 관절각 추정 | p3-imu-mocap.md |
