---
description: "하드웨어 테스트. 센서/모터/통신 확인, hardware.yaml 자동 생성. safety gate 필수. 키워드: 테스트, hwtest, 확인, 동작 확인, 연결 확인, 핑, 센서 확인, 모터 확인"
---

# skiro-hwtest — SKILL.md core
# v0.5 MS4 | ~380 tok

## 역할
하드웨어 테스트 절차를 구조화하고 실행한다.
.skiro_safety_gate 존재를 전제 조건으로 요구한다.

## 트리거 감지
```
"테스트", "hwtest", "확인", "동작 확인", "연결 확인",
"핑", "ping", "통신 확인", "센서 확인", "모터 확인"
```

## Phase 0 — 사전 조건 + 테스트 유형 분류

### 사전 조건 (반드시 확인)
```bash
# .skiro_safety_gate 존재 확인
ls .skiro_safety_gate || { echo "BLOCKED: safety gate 없음"; exit 1; }
```
게이트 없으면 즉시 중단. skiro-safety 먼저 실행하도록 안내.

### 테스트 유형 → 로드할 파일

| 유형 | 조건 | 로드 |
|------|------|------|
| comm | 통신 확인만 | p1-comm-test.md |
| sensor | 센서 데이터 확인 | p1-comm-test.md + p2-sensor-test.md |
| motor | 모터 동작 포함 | p1-comm-test.md + p3-motor-test.md |
| full | 전체 시스템 통합 | p1 + p2 + p3 |
