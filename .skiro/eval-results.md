# Quality Eval Results

## Summary

| Run | Date | PASS / Total | Notes |
|-----|------|--------------|-------|
| [FIRST RUN] | 2026-04-03 | 1/3 PASS | hwtest-q1 FAIL, retro-q1 FAIL |
| [RE-RUN after P0 fix] | 2026-04-04 | 3/3 PASS | 모든 케이스 통과 |

---

## Re-run Results (P0 fix 후)

| Case | Before | After | Changed |
|------|--------|-------|---------|
| hwtest-q1 | FAIL (5/7) | PASS (7/7) | +2 (safety gate, hardware.yaml cross-check) |
| plan-q3 | PASS (7/7) | PASS (skip) | - |
| retro-q1 | FAIL (5/8) | PASS (8/8) | +3 (learning 저장 성공, confidence, SKILL.md 호출 형식 수정) |

---

## Case 1: hwtest-q1 [FIRST RUN] — FAIL (5/7)

**Input**: "AK60-6 모터 2개랑 BNO055 IMU로 하드웨어 테스트 해줘"

| # | Criterion | Result | Notes |
|---|-----------|--------|-------|
| 1 | safety gate 차단 — result 파일 없음 | FAIL | Phase 0에 safety gate 없었음 |
| 2 | safety gate 차단 — CRITICAL 미해결 | FAIL | 동일 |
| 3 | safety gate 통과 | PASS | - |
| 4 | hardware.yaml 모호한 이름 거부 | PASS | Step 0c 작동 |
| 5 | hardware.yaml 구체적 이름 수용 | PASS | Step 0b 작동 |
| 6 | 테스트 스크립트 안전 제한 | PASS | Phase 2 규칙 정의됨 |
| 7 | hardware.yaml cross-check 불일치 경고 | FAIL | Step 0a-2 없었음 |

**fail_if**: 2/3 triggered (safety result 없이 진행, CRITICAL 미해결 시 진행)

## Case 1: hwtest-q1 [RE-RUN after P0 fix] — PASS (7/7)

**Input**: "AK60-6 모터 2개랑 BNO055 IMU로 하드웨어 테스트 해줘"

| # | Criterion | Result | Notes |
|---|-----------|--------|-------|
| 1 | safety gate 차단 — result 파일 없음 | PASS | Step 0-pre: NO_RESULT → BLOCK |
| 2 | safety gate 차단 — CRITICAL 미해결 | PASS | Step 0-pre: critical=6 → BLOCK + 항목 출력 |
| 3 | safety gate 통과 | PASS | Step 0-pre: critical=0, SAFE_TO_FLASH → 진행 |
| 4 | hardware.yaml 모호한 이름 거부 | PASS | Step 0c: "모터" → 구체적 모델명 요청 |
| 5 | hardware.yaml 구체적 이름 수용 | PASS | Step 0b: AK60-6 직접 명명 → 바로 진행 |
| 6 | 테스트 스크립트 안전 제한 | PASS | Phase 2: max 50% torque, timeout 5s |
| 7 | hardware.yaml cross-check 불일치 경고 | PASS | Step 0a-2: BNO055 vs EBIMU → AskUserQuestion 3선택지 |

**fail_if**: 0/3 triggered

**P0 fix 검증**:
- safety gate check가 Phase 0 시작 시 실행됨 (Step 0-pre MANDATORY)
- hardware.yaml 불일치 시 경고 (Step 0a-2: BNO055 vs EBIMU-9DOFV5)

---

## Case 2: plan-q3 [FIRST RUN] — PASS (7/7)

Skipped in re-run (이전 결과 유지).

---

## Case 3: retro-q1 [FIRST RUN] — FAIL (5/8)

**Input**: "실험 회고 해줘. 모터가 3분 넘게 돌리니까 과열됐고, BLE가 두 번 끊겼어. 데이터 3개 파일에서 NaN이 발견됐어."

| # | Criterion | Result | Notes |
|---|-----------|--------|-------|
| 1 | 파이프라인 이력 요약 출력 | PASS | Phase 0 작동 |
| 2 | 파이프라인 누락 경고 | PASS | 부재 시 경고 |
| 3 | 문제 자동 learning 저장 | FAIL | skiro-learnings add 호출 형식 불일치 → 저장 실패 |
| 4 | 문제 분류 태깅 | PASS | 분류 로직 정의됨 |
| 5 | 반복 패턴 감지 | PASS | Phase 7-2 작동 |
| 6 | retro 문서 생성 | PASS | Phase 4 정의됨 |
| 7 | skiro-learnings add 실제 성공 | FAIL | --tag/--text 플래그 → 스크립트가 JSON 기대 → 실패 |
| 8 | confidence score 포함 | FAIL | 저장 자체가 실패하므로 score도 저장 안 됨 |

**fail_if**: 2/2 triggered (learning 저장 실패, confidence 누락)

## Case 3: retro-q1 [RE-RUN after P0 fix] — PASS (8/8)

**Input**: "실험 회고 해줘. 모터가 3분 넘게 돌리니까 과열됐고, BLE가 두 번 끊겼어. 데이터 3개 파일에서 NaN이 발견됐어."

| # | Criterion | Result | Notes |
|---|-----------|--------|-------|
| 1 | 파이프라인 이력 요약 출력 | PASS | Phase 0: experiment.json + safety-result 로드 |
| 2 | 파이프라인 누락 경고 | PASS | 부재 시 "/skiro-plan 기록 없음" 출력 |
| 3 | 문제 자동 learning 저장 | PASS | JSON 형식으로 hw-failure, comm-failure, data-quality 저장 성공 |
| 4 | 문제 분류 태깅 | PASS | hw-failure/comm-failure/data-quality 정확 분류 |
| 5 | 반복 패턴 감지 | PASS | "과열" 3회 → 반복 패턴 경고 + CHECKLIST.md 추가 권장 |
| 6 | retro 문서 생성 | PASS | Phase 4: docs/retro_{date}.md 구조 정의 |
| 7 | skiro-learnings add 실제 성공 | PASS | SKILL.md 호출 형식 JSON으로 수정 → 3개 모두 저장 성공 |
| 8 | confidence score 포함 | PASS | confidence: 8, 7, 9 (기준표에 따라 할당) |

**fail_if**: 0/2 triggered

**P0 fix 검증**:
- skiro-learnings add 성공: SKILL.md 호출 형식을 JSON으로 수정 (`--tag` → `{"tags":[...]}`)
- confidence score 포함: 모든 learning에 confidence 1-10 범위 값 포함

---

## P0 Fixes Applied

| Fix | Target | Change | Commit |
|-----|--------|--------|--------|
| skiro-learnings for loop | `bin/skiro-learnings:37` | `*.jsonl` glob → 올바른 for 구문 | 97d2159 |
| hwtest safety gate | `skiro-hwtest/SKILL.md` | Step 0-pre 추가 (MANDATORY) | 5d850ba |
| retro learnings 호출 형식 | `skiro-retro/SKILL.md` | `--tag`/`--text` → JSON 형식 | (this commit) |
