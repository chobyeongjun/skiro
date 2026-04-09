# skiro-safety — SKILL.md core
# v0.5 MS4 | 모듈화 버전 | ~580 tok

## 역할
로봇 엔지니어의 코드/계획/실험에 대해 구조적 안전 분석을 수행한다.
하드웨어 손상, 모터 과전류, 데이터 레이스, ISR 충돌을 사전 차단한다.

---

## 트리거 감지 (Phase 0 진입 조건)
아래 키워드/패턴 중 하나라도 포함되면 즉시 이 스킬을 활성화한다.

```
코드 리뷰 요청: "안전", "검토", "확인해줘", "리뷰", "괜찮아?", "올려도 돼?"
작업 유형:      flash, 펌웨어, firmware, 모터, motor, CAN, ISR, 인터럽트
하드웨어:       AK60, AK80, Teensy, STM32, Jetson, NUCLEO, 액추에이터
실험:           실험, experiment, 테스트, hwtest, 올린다, deploy
```

---

## Phase 0 — 복잡도 스코어링 & 모듈 로딩

### 0-1. 스코어 산출
분석 대상 파일이 있으면 아래 명령을 실행한다.
```bash
skiro-complexity <파일경로> --json
```
파일이 없거나(계획 단계, 구두 설명) 스크립트 오류 시: **tier=full** 으로 fallback.

### 0-2. 모듈 로딩 라우팅 테이블

| tier | score | 반드시 Read | 조건부 Read |
|------|-------|-------------|-------------|
| fast | < 30  | p1-scope, p2-checklist | — |
| partial | 30–79 | p1-scope, p2-checklist | p3-fork §A, p4-gate §subset |
| full | ≥ 80 | p1-scope, p2-checklist, p3-fork, p4-gate | domain skill |

**Read 순서 (반드시 준수)**:
1. `skiro-safety/phases/p1-scope.md`
2. `skiro-safety/phases/p2-checklist.md`
3. (partial/full) `skiro-safety/phases/p3-fork.md`
4. (partial/full) `skiro-safety/phases/p4-gate.md`

---

## Phase 흐름 개요

```
Phase 0: 복잡도 측정 → 모듈 로딩
Phase 1: grep 패턴 스캔 (p1-scope에서 정의)
Phase 2: CRITICAL/WARNING 체크리스트 (p2-checklist에서 정의)
Phase 3: fork agent 분석 — score ≥ 30 시 (p3-fork에서 정의)
Phase 4-6: merge → gate → learnings 저장 (p4-gate에서 정의)
Phase 7: 결과 리포트 & current-experiment.json 업데이트
Phase 8: 다음 세션 learnings 로드 지시
```

---

## 빠른 판단 기준 (모든 tier 공통)

```
BLOCK (절대 통과 불가):
  - 모터/액추에이터 제어 코드에 전류/토크 상한 없음
  - ISR 내 malloc / new / printf 사용
  - 안전 게이트 없는 enable_power() 직접 호출
  - .skiro_safety_gate 파일 없는 상태로 flash 진행

CRITICAL 승격 조건 (MS1 규칙, 항상 적용):
  WARNING + 모터 제어 관련 = 자동 CRITICAL 승격
```

---

## current-experiment.json 연동

Phase 0 시작 시 `.skiro/current-experiment.json` 존재 확인.
```json
{ "status": "safety_in_progress", "tier": "<tier>", "score": <N> }
```
Phase 완료 시:
- 통과 → `"status": "safety_checked"`
- 차단 → `"status": "blocked", "block_reason": "<사유>"`
