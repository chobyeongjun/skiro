---
description: "세션/실험 회고. 교훈 정리, learnings JSONL 기록, 논문 paper packet 생성. 키워드: 회고, retro, 정리, 마무리, 오늘 결과, 배운 것, 다음에는, 실험 끝"
---

# skiro-retro — SKILL.md core
# v0.5 MS4 | ~420 tok

## 역할
세션/실험 종료 후 회고를 구조화하고 교훈을 learnings JSONL에 저장한다.
계획(skiro-plan)의 결과를 평가하고 다음 세션의 입력을 생성한다.

## 트리거 감지
```
"회고", "retro", "정리", "마무리", "오늘 결과", "어땠어",
"배운 것", "다음에는", "세션 종료", "실험 끝"
```

## Phase 0 — 회고 깊이 분류 & 모듈 로딩

| 깊이 | 조건 | 로드 |
|------|------|------|
| quick | 30분 이하 세션 or 결과 없음 | p1-quick.md |
| standard | 일반 개발 세션 | p1-quick.md + p2-analysis.md |
| deep | 실험 데이터 있음 or CRITICAL 발생 | p1-quick.md + p2-analysis.md + p3-deep.md |

## current-experiment.json 업데이트

회고 완료 후:
```json
{
  "status": "completed",
  "completed_at": "<ISO-8601>",
  "outcome": "success|partial|fail",
  "retro_depth": "<quick|standard|deep>"
}
```
