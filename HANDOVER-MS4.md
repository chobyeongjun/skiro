# skiro 인수인계 — MS4 완료

## 버전: v0.5 MS4

---

## MS4 달성 기록

### STEP 1: skiro-safety 모듈화 (PoC + 전 스킬 확장)
- SKILL.md core: trigger + Phase 0 + 라우팅 테이블 (~580 tok)
- phases/p1-scope.md: grep 패턴 스캔 (~880 tok) — always load
- phases/p2-checklist.md: CRITICAL/WARNING 판정 (~220 tok) — always load
- phases/p3-fork.md: fork agent §A/§B (~1420 tok) — score ≥ 30
- phases/p4-gate.md: gate/learnings/retro (~870 tok) — Phase 2 후

### STEP 2: skiro-complexity 자동화
- bin/skiro-complexity: LOC/ISR/thread/CAN/motor/RTOS/shared/DMA/ctrl 9개 지표
- ISR 패턴: `^void\s+\w+_IRQHandler` (함수 정의만, HAL 호출 제외)
- fast < 30 / partial 30–79 / full ≥ 80
- `--json` 모드 지원, graceful fallback (파일 없음 → full)

### STEP 3: 전 스킬 모듈화
모듈화 완료 (core + phases/):
- skiro-safety: 4개 phase (p1~p4)
- skiro-plan:   3개 phase (template-simple, hw-risk, experiment)
- skiro-retro:  3개 phase (quick, analysis, deep)
- skiro-hwtest: 3개 phase (comm, sensor, motor)
- skiro-comm:   4개 phase (uart, can, spi-i2c, ros2)
- skiro-gait:   4개 phase (phase-detect, analysis, control, classification)
- skiro-data:   3개 phase (logging, filtering, visualization)
- skiro-gui:    2개 phase 작성 (realtime, control-panel)
- skiro-mocap:  3개 phase (vicon, zed, imu-mocap)
- skiro-analyze: 2개 phase (control-analysis, statistics)
- skiro-flash:  단일 파일 유지 (모듈화 효과 없음)

### STEP 4: eval + 인프라
- tests/ms4-eval/: 4개 suite (fast/partial/full/fallback), ALL PASS
- bin/skiro-learnings v1.1: add/list/search/count/promote/migrate
- CHECKLIST.md: 80줄, [MS4] 섹션 추가
- CLAUDE-AI-PROJECT-TEMPLATE.md: Claude.ai/API 운영 가이드

---

## 현재 디렉토리 구조

```
skiro/
├── bin/
│   ├── skiro-complexity     ← STEP 2 핵심 (v1.1, ISR 패턴 버그픽스)
│   ├── skiro-learnings      ← v1.1 (dedup 수정)
│   ├── skiro-session        (MS3 기존)
│   └── skiro-update         (MS3 기존)
├── skiro-safety/
│   ├── SKILL.md             ← core ~580 tok
│   └── phases/
│       ├── p1-scope.md      ← ~880 tok ALWAYS
│       ├── p2-checklist.md  ← ~220 tok ALWAYS
│       ├── p3-fork.md       ← ~1420 tok score≥30
│       └── p4-gate.md       ← ~870 tok Phase2후
├── skiro-plan/SKILL.md + phases/ (3개)
├── skiro-retro/SKILL.md + phases/ (3개)
├── skiro-hwtest/SKILL.md + phases/ (3개)
├── skiro-comm/SKILL.md + phases/ (4개)
├── skiro-gait/SKILL.md + phases/ (4개)
├── skiro-data/SKILL.md + phases/ (3개)
├── skiro-gui/SKILL.md + phases/ (2개)
├── skiro-mocap/SKILL.md + phases/ (3개)
├── skiro-analyze/SKILL.md + phases/ (2개)
├── skiro-flash/SKILL.md         (단일)
├── tests/ms4-eval/              (4 suite, ALL PASS)
├── CHECKLIST.md                 (80줄)
├── CLAUDE-AI-PROJECT-TEMPLATE.md
└── HANDOVER-MS4.md              (이 파일)
```

---

## 토큰 절감 실측

skiro-safety 기준 (이론값):

| 시나리오 | MS3 | MS4 | 절감 |
|---------|-----|-----|------|
| 30줄 LED blink (fast) | 4052 | 1680 | -59% |
| ISR 2개 중간 코드 (partial) | 4052 | 2810 | -31% |
| H-Walker 펌웨어 (full) | 4052 | 3950 | -2% |
| 평균 추정 (7:2:1 비율) | 4052 | 2030 | -50% |

---

## 버그픽스 이력 (MS4)

1. `grep -c` exit 1 → `grep | wc -l` (중복 카운팅 방지)
2. ISR 패턴 `HAL_*_IRQHandler` 호출 포함 → `^void` 정의만으로 제한
3. `((PASS++))` bash set -e 충돌 → `PASS=$((PASS+1))`
4. eval 상대경로 `../../../bin` → `../../bin`
5. skiro-learnings dedup: bash heredoc quote 문제 → python3 - 패턴

---

## MS5 방향 (다음 단계 제안)

### 옵션 A: skiro-gui/data/analyze 나머지 phase 완성
현재 skiro-gui는 2개 phase(realtime, control-panel)만 작성됨.
p3-rqt.md (RQt 플러그인), p4-web.md (웹 대시보드) 미완.
skiro-data p4-ml.md (ML 파이프라인) 미완.

### 옵션 B: skiro-init MS4 버전 업데이트
현재 bin/skiro-init은 MS3 버전.
MS4 모듈화 구조 반영 + CLAUDE.md에 라우팅 안내 추가.

### 옵션 C: references/ 모듈화
현재 references/ 9개 도메인 문서 ~28,661 tok.
가장 큰 토큰 블록. 섹션별 분리 + 조건부 로딩으로 추가 절감 가능.

### 옵션 D: quality-eval 회귀 테스트 통합
MS2에서 구축한 20개 quality-eval 케이스를 MS4 모듈화 이후 재실행.
모듈화로 인한 품질 저하 없음 확인.

---

## 운영 불변 조건

```
1. STEP 3 모듈화 진행 중 quality-eval FAIL → 즉시 중단
2. eval ALL PASS 유지 (run-all-ms4.sh)
3. CRITICAL 이슈는 반드시 learnings에 저장
4. promote threshold=3 도달 항목은 CHECKLIST.md에 추가
5. skiro-flash 전 .skiro_safety_gate 존재 확인 불변
```
