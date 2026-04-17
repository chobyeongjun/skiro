---
title: skiro Obsidian Setup
tags: [skiro, meta, setup]
summary: Recommended Obsidian plugins and Dataview queries for skiro vault.
confidence_score: 0.9
---

# skiro Obsidian Setup

이 노트는 skiro vault를 Obsidian에서 효과적으로 사용하기 위한 **플러그인 + Dataview 쿼리 참조**다.

## Vault Structure

```
<vault>/
├── 00_Meta/templates/       ← Templater 템플릿 위치
├── 10_ClaudeMemory/          ← (선택) Claude Code 메모리 복사본
├── 20_Learnings/             ← skiro-md-sync.py가 자동 기록
│   └── <category>/<date>-<slug>.md
├── 20_Meta/skiro/            ← skiro harness 참조 노트 (install이 복사)
├── 30_Projects/              ← 프로젝트별 상세 노트
├── 40_Areas/                 ← 영역 지식 (robotics, control, ...)
└── 99_Daily/                 ← 일일 노트
```

`20_Learnings/`는 skiro가 쓴다. 다른 폴더는 사용자가 자유롭게 구성.

## Recommended Plugins

| Plugin | 용도 | 필수? |
|--------|------|-------|
| Obsidian Git | vault를 git repo로 자동 sync | 권장 (여러 머신 사용 시 필수) |
| Templater | 실험/미팅 템플릿 자동 삽입 | 권장 |
| Dataview | `20_Learnings/` 쿼리/집계 | 권장 |
| Periodic Notes | 일일 노트 자동화 | 선택 |
| Paste image rename | 이미지 파일명 정리 | 선택 |

### Plugin 설정 요점

**Obsidian Git**
- Vault backup interval: 5 min
- Auto pull interval: 5 min
- Sync on startup: on
- Commit message: `vault: {{date}} {{hostname}}`

**Templater**
- Template folder: `00_Meta/templates`
- Trigger Templater on new file creation: on
- 위 `skiro/templates/vault/*-template.md` 파일을 해당 폴더로 복사해 사용

**Dataview**
- Enable Inline Queries: on
- Enable JavaScript Queries: on (복잡한 집계 필요 시)

## Dataview Queries (복붙용)

아무 노트에나 넣으면 바로 렌더링된다.

### 이번 주 learnings
````
```dataview
LIST
FROM "20_Learnings"
WHERE file.ctime >= date(today) - dur(1 week)
SORT file.ctime DESC
```
````

### Unsolved learnings
````
```dataview
TABLE category, severity, count, last_seen
FROM "20_Learnings"
WHERE status = "unsolved"
SORT count DESC, last_seen DESC
```
````

### 반복된 learnings (count >= 3) — promote 후보
````
```dataview
TABLE category, severity, count, last_seen, file.link
FROM "20_Learnings"
WHERE count >= 3
SORT count DESC
```
````

### 카테고리별 learning 분포
````
```dataview
TABLE length(rows) as "Count"
FROM "20_Learnings"
GROUP BY category
SORT length(rows) DESC
```
````

### 진행 중인 실험
````
```dataview
TABLE date, project
FROM #experiment
WHERE status = "running"
```
````

### 최근 미팅의 Action Items
````
```dataview
TASK
FROM "99_Daily" OR #meeting
WHERE !completed
GROUP BY file.link
```
````

## MOC (Map of Content) 추천

`99_Daily/MOC.md`를 만들고 위 쿼리들을 모아두면 대시보드로 쓸 수 있다.

## skiro 와의 상호작용

- **skiro-md-sync.py**: `~/.skiro/learnings.jsonl` → `20_Learnings/<category>/*.md` 자동 복제
  - `skiro_record_problem` / `skiro_record_solution` 호출 후 자동 실행
  - `skiro-learnings add` / `solve` 호출 후 자동 실행
  - vault_path 미설정 시 silent no-op

- **수동 sync 실행**: `python3 ~/skiro/bin/skiro-md-sync.py`

- **Dataview 쿼리가 비었을 때 확인사항**:
  1. `20_Learnings/` 폴더 존재 여부
  2. frontmatter `category`, `severity`, `status` 필드 확인
  3. `status = "unsolved"` 쿼리에서 따옴표 필수

## 주의

- `20_Learnings/` 폴더 이름 변경 시 모든 Dataview 쿼리 + sync 경로 깨짐
- skiro가 생성한 md 파일은 sync가 재실행되면 **덮어쓰기**됨. 수동 메모는 다른 폴더에
- Obsidian Git이 commit할 때 `.obsidian/workspace*` 는 제외 (`.gitignore` 추가)
