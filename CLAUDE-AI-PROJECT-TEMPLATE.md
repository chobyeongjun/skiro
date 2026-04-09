# skiro MS4 — Claude.ai 프로젝트 설정 가이드

## 설정 목표
Claude.ai 프로젝트에서 skiro를 최소 토큰으로 운영한다.
Claude Code와 동일 repo, 다른 접근 경로.

---

## Project Knowledge 업로드 파일 (필수 5개, ~2,900 tok)

아래 파일만 Project Knowledge에 업로드한다.
phase 파일은 대화 중 필요 시 직접 붙여넣는다.

```
skiro-safety/SKILL.md        (~580 tok)  ← 트리거 + 라우팅 테이블
skiro-plan/SKILL.md          (~480 tok)  ← 계획 코어
skiro-retro/SKILL.md         (~420 tok)  ← 회고 코어
skiro-hwtest/SKILL.md        (~380 tok)  ← hwtest 코어
CHECKLIST.md                 (~860 tok)  ← 전체 체크리스트
```

업로드하지 않는 것:
- phase 파일 (→ 필요 시 대화에 붙여넣기)
- references/ (→ 웹 검색 또는 질문으로 대체)
- bin/ 스크립트 (→ Claude Code에서만 실행)

---

## 세션 시작 프롬프트 (매 세션 복사-붙여넣기)

```
[skiro v0.5 MS4 세션 시작]

오늘 작업: <작업 내용>
관련 파일: <파일명 또는 없음>

최근 learnings (있으면 붙여넣기):
<skiro-learnings list --last 5 출력>

현재 실험 상태 (있으면 붙여넣기):
<.skiro/current-experiment.json 내용>
```

---

## phase 파일 요청 방법

Claude.ai에서 phase 파일이 필요할 때:

```
# 방법 1: 직접 붙여넣기
[아래 내용을 분석에 사용해줘]
<p3-fork.md 전체 내용 붙여넣기>

# 방법 2: Claude에게 요청
"p3-fork.md의 §A ISR 데이터 레이스 체크리스트를 적용해줘"
→ Claude가 기억에서 구조를 재현 (Project Knowledge 기반)
```

---

## 플랫폼별 라우팅 비교

| 기능 | Claude Code | Claude.ai |
|------|------------|-----------|
| complexity 스코어 | `skiro-complexity <file>` 실행 | 코드 보고 수동 추정 |
| phase 로딩 | `Read phases/p3-fork.md` | 대화에 직접 붙여넣기 |
| learnings 저장 | `skiro-learnings add ...` | 세션 말미에 항목 목록 제공 → 수동 실행 |
| safety gate | `.skiro_safety_gate` 파일 생성 | 구두 "통과/차단" 선언 |
| current-experiment.json | 자동 업데이트 | 수동 업데이트 |

---

## Claude.ai 세션 종료 루틴

```
1. 회고 항목 요약 (Claude가 제공)
2. 저장할 learnings 목록 (Claude가 제공)
   → 로컬에서: skiro-learnings add --category ... 실행
3. 다음 세션 첫 번째 할 일 명시
4. current-experiment.json status 업데이트 내용 명시
```

---

## API 운영 (시스템 프롬프트 구성)

```python
# skiro-safety core만 system prompt에 포함
with open('skiro-safety/SKILL.md') as f:
    safety_core = f.read()

# phase는 user message에 동적 삽입
def build_message(code, tier):
    phases = load_phases_for_tier(tier)  # 스코어 기반
    return f"{phases}\n\n분석 대상:\n```c\n{code}\n```"

system = f"""당신은 로봇 엔지니어 AI 어시스턴트입니다.
{safety_core}
"""
```
