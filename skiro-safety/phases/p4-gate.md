# p4-gate.md — Phase 4–8: Gate / Report / Learnings
# skiro-safety | partial: §subset | full: all | ~870 tok

## Phase 4 — Safety Gate 생성

### BLOCK=NO (통과) 시

`.skiro_safety_gate` 파일 생성:
```
SAFETY_GATE_PASSED
timestamp: <ISO-8601>
tier: <fast|partial|full>
score: <N>
critical: 0
warnings: <M>
analyst: skiro-safety v0.5
```

이 파일이 없으면 `skiro-hwtest`, `skiro-flash`는 진행을 거부한다.

### BLOCK=YES 시

`.skiro_safety_gate` 생성 금지.
`.skiro_safety_block` 파일 생성:
```
SAFETY_GATE_BLOCKED
timestamp: <ISO-8601>
reason: <CRITICAL 이슈 한 줄 요약>
critical_count: <N>
```

---

## Phase 5 — Learnings 저장 (retro와 연동)

분석 중 발견한 패턴을 `learnings.jsonl`에 추가한다.

**저장 기준**:
- CRITICAL 이슈: 반드시 저장
- WARNING이 CRITICAL로 승격된 케이스: 반드시 저장
- 새로운 grep 패턴으로 잡힌 최초 케이스: 저장
- 알려진 패턴의 반복: 저장 생략 (중복 방지)

**저장 양식**:
```jsonl
{"date":"<YYYY-MM-DD>","skill":"safety","tier":"<tier>","category":"<ISR_race|missing_limit|shared_mem|timing|proto_error>","severity":"CRITICAL|WARNING","pattern":"<감지 패턴>","context":"<파일명 또는 작업명>","lesson":"<한 줄 교훈>","count":1}
```

**promote 확인**:
동일 `category`가 3회 이상 반복되면 CHECKLIST.md 승격 제안:
```
[PROMOTE 제안] <category> 패턴이 3회 감지됨
  → CHECKLIST.md에 추가 권장: "□ <체크 항목>"
```

---

## Phase 6 — current-experiment.json 업데이트

```json
{
  "status": "safety_checked",       // 또는 "blocked"
  "updated_at": "<ISO-8601>",
  "safety": {
    "tier": "<tier>",
    "score": <N>,
    "critical": <N>,
    "warnings": <M>,
    "block": false
  }
}
```

---

## Phase 7 — 결과 리포트

리포트 구조 (모든 tier 공통):

```markdown
## Safety Analysis Report

**대상**: <파일명 또는 작업명>
**Tier**: <fast|partial|full> (score: <N>)
**결과**: ✅ 통과 / 🚫 BLOCK

### CRITICAL (<N>개)
1. [파일:라인] 이슈 설명
   수정 방법: <구체적 코드 또는 절차>

### WARNING (<M>개)
1. [파일:라인] 이슈 설명

### 확인된 안전 조치
- <존재하는 보호 메커니즘 목록>

### 다음 단계
- BLOCK=YES: 위 CRITICAL 수정 후 재분석 요청
- BLOCK=NO:  `skiro-hwtest` 또는 `skiro-flash` 진행 가능
```

---

## Phase 8 — 다음 세션 연속성

세션 종료 전 아래 지시를 남긴다:

```
[다음 세션 시작 시]
1. skiro-learnings list --category safety --last 5 로 최근 교훈 확인
2. CHECKLIST.md safety 섹션 확인
3. promote 대기 항목 있으면 CHECKLIST.md 업데이트
```

---

## §subset (partial tier 적용 범위)

partial tier에서 p4-gate의 적용 범위:
- Phase 4 (gate 생성): **전체 적용**
- Phase 5 (learnings): CRITICAL만 저장, WARNING은 생략
- Phase 6 (json 업데이트): **전체 적용**
- Phase 7 (리포트): WARNING 섹션 축약 가능
- Phase 8 (다음 세션): **전체 적용**
