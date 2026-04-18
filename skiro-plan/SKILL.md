---
description: "실험/개발 계획 수립. 목표, 위험 분석, 프로토콜 구조화, current-experiment.json 생성. 키워드: 계획, plan, 오늘 뭐 할까, 실험 설계, 어떻게 접근, 순서 잡아줘"
---

# skiro-plan — SKILL.md core
# v0.5 MS4 | ~480 tok

## 역할
로봇 엔지니어의 실험/개발 세션을 구조화된 계획으로 전환한다.
안전 분석(skiro-safety)과 회고(skiro-retro)의 입력을 생성한다.

## 트리거 감지
```
"계획", "plan", "오늘 뭐 할까", "실험 설계", "어떻게 접근",
"테스트 방법", "순서 잡아줘", "뭐부터", "실험 준비"
```

## Phase 0 — 복잡도 분류 & 모듈 로딩

| 유형 | 조건 | 로드할 파일 |
|------|------|-------------|
| simple | 단일 기능, 30분 이내 | p1-template-simple.md |
| hardware | 물리 하드웨어 포함 | p1-template-simple.md + p2-hw-risk.md |
| experiment | 데이터 수집/검증 | p1-template-simple.md + p3-experiment.md |
| milestone | 마일스톤 수준 | p1-template-simple.md + p2-hw-risk.md + p3-experiment.md |

분류 규칙:
- 모터/액추에이터/하드웨어 언급 → hardware 이상
- 측정/비교/검증 언급 → experiment 이상
- MS, 마일스톤, 발표, 제출 언급 → milestone

## current-experiment.json 생성

계획 수립 후:
```json
{
  "id": "<YYYYMMDD-HH>",
  "title": "<한 줄 제목>",
  "type": "<simple|hardware|experiment|milestone>",
  "status": "planned",
  "created_at": "<ISO-8601>",
  "goals": ["<목표1>", "<목표2>"],
  "risks": ["<위험1>"],
  "safety_required": true
}
```
