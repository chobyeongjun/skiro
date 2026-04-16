---
title: skiro 논문 작업 워크플로우
created: 2026-04-16
updated: 2026-04-16
sources: []
tags: [skiro, paper, workflow, cowork]
summary: skiro COWORK MCP를 사용한 논문 작업 전체 워크플로우
confidence_score: 0.95
---

# [[skiro 논문 작업 워크플로우]]

## Phase 1: 논문 시작 (구조 설계)

논문을 새로 시작할 때 COWORK (claude.ai)에서:

```
"이 프로젝트로 논문 쓰고 싶어"
```

Claude가 순서대로 실행:
1. `cowork_paper_state(action="list")` — 기존 논문 있나 확인
2. `cowork_scan_experiments(project_path="~/연구폴더")` — 실험 전체 현황 파악
3. `cowork_get_learnings(format="paper")` — 방법론 변경 이력
4. `skiro_vault_search(folder:"10_Wiki/Decisions")` — 과거 설계 결정 참조
5. Claude가 title, contributions, sections 제안
6. 사용자 확인 후: `cowork_paper_state(action="set", paper_id="...", state={...})`
7. `cowork_paper_check(paper_id="...")` — 일관성 검증 (필수)

## Phase 2: 섹션 작성

```
"Methods 섹션 쓰자"
```

1. `cowork_paper_state(action="get")` — 현재 구조 로드
2. `cowork_paper_data(section="methods")` — 해당 섹션 데이터만 추출
3. Code MCP: `skiro_vault_read(note="...", section="Core Content")` — vault 부분 로드
4. Claude가 초안 작성
5. `cowork_paper_state(action="update", state={completion_pct:45})` — 부분 갱신만

**핵심 규칙: 전체 노트/데이터 절대 로드 금지. 섹션 단위로만.**

## Phase 3: 이어서 작업 (다음 세션)

```
"어제 하던 논문 이어서"
```

1. `cowork_paper_state(action="list")` — 논문 목록
2. `cowork_paper_state(action="get", paper_id="...")` — 상태 복원
3. `cowork_paper_check(...)` — gap 확인
4. "완성도 67%. 빠진 것: ablation study. 무엇부터?"

## Phase 4: 새 실험 추가 후 갱신

Claude Code에서 실험 끝나면:
```
skiro_archive_experiment(name="2026-04-16-...", source_dir="...", description="...")
```

COWORK에서:
1. `cowork_scan_experiments(...)` — 새 실험 감지
2. `cowork_paper_state(action="update", ...)` — 해당 섹션만 갱신
3. `cowork_paper_check(...)` — 재검증

## Phase 5: 미팅/출판 준비

발표 데이터 선별:
```
cowork_promote_data(experiment_path="...", from_tier="raw", to_tier="ppt", files=[...])
```

출판용 figure 선정:
```
cowork_promote_data(from_tier="ppt", to_tier="paper", files=[...])
```

Figure 생성은 PaperBanana 등 외부 도구 가능. 생성 후 `skiro_save_artifact(category="figure")`로 등록.

## paper_state 액션 정리

| Action | 용도 | paper_id |
|--------|------|----------|
| `list` | 모든 논문 조회 | 불필요 |
| `get` | 상태 읽기 | 필수 |
| `set` | 전체 덮어쓰기 (새 논문) | 필수 |
| `update` | 부분 병합 (기존값 유지) | 필수 |

## state 스키마

```json
{
  "title": "string (set 시 필수)",
  "contributions": ["기여 1", "기여 2"],
  "sections": [
    { "name": "필수", "status": "done|draft|todo", "key_experiments": ["exp-id"] }
  ],
  "key_figures": ["figure 파일명"],
  "completion_pct": "0-100",
  "gaps": [
    { "description": "필수", "priority": "high|medium|low", "type": "experiment|writing" }
  ]
}
```

## 안전 장치

- JSON 파일 원자적 쓰기 (tmp+rename) — 크래시 시 깨지지 않음
- 스키마 검증 — completion_pct 0-100, 배열 타입, 필수 필드
- `paper_check` — 실험 존재 여부, figure 등록 여부, 완성도 일관성, gap 우선순위 체크
