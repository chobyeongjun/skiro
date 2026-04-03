# Quality Eval — 스킬 출력 품질 평가

`evals/`(트리거 정확도)와 별개로, 스킬이 **올바른 출력**을 내는지 평가하는 테스트 세트.

## evals/ vs tests/quality-eval/

| 디렉토리 | 평가 대상 | 예시 |
|----------|----------|------|
| `evals/` | 트리거 정확도 — 이 요청이 해당 스킬을 트리거하는가? | "force limit 확인" → skiro-safety 트리거? |
| `tests/quality-eval/` | 출력 품질 — 스킬이 올바른 결과를 내는가? | skiro-safety가 10개 버그를 모두 탐지하는가? |

## 파일 목록

| 파일 | 대상 스킬 | 핵심 검증 |
|------|----------|----------|
| `skiro-safety-fork-eval.json` | skiro-safety | Phase 3 fork agent 트리거/스킵, 승격 규칙, MULTI-SOURCE, 오탐 방지 |
| `skiro-hwtest-quality-eval.json` | skiro-hwtest | safety gate 차단, hardware.yaml 자동 생성, 모호한 이름 거부 |
| `skiro-plan-quality-eval.json` | skiro-plan | 실험 컨텍스트 JSON 저장, 프로토콜 문서, 안전 우려 자동 감지 |
| `skiro-retro-quality-eval.json` | skiro-retro | 파이프라인 이력 요약, 문제 자동 learning 저장, 반복 패턴 감지 |

## 실행 방법

수동 평가: 각 JSON의 테스트 케이스를 순서대로 실행하고 expected 결과와 비교.

```bash
# 예: skiro-safety fork eval
# 1. tests/should-pass/에 /skiro-safety 실행 → CRITICAL 0 확인
# 2. tests/should-fail/에 /skiro-safety 실행 → CRITICAL 10 확인
# 3. Phase 3 specialist 트리거 여부 확인
```
