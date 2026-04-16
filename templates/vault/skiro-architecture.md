---
title: skiro 아키텍처
created: 2026-04-16
updated: 2026-04-16
sources: []
tags: [skiro, architecture, mcp, hooks]
summary: skiro harness의 전체 구조 — 설치, 작동, 구성 요소
confidence_score: 0.95
---

# [[skiro 아키텍처]]

## 핵심 구조

```
~/skiro/                          ← 한 곳에 설치 (어디든 OK)
  ├── bin/                        ← hooks + Code MCP 서버 (13 tools)
  ├── cowork/                     ← COWORK MCP 서버 (9 tools, claude.ai용)
  └── templates/
      ├── CLAUDE.md.template      ← 프로젝트별 규칙
      └── vault/                  ← Obsidian vault 노트 템플릿

~/.skiro/                         ← 글로벌 데이터
  ├── config.json                 ← vault_path 등 설정
  ├── learnings.jsonl             ← 문제-해결 이력
  ├── artifacts.jsonl             ← 파일 등록 이력
  └── papers/                     ← 논문 설계 상태 (per paper JSON)

~/.claude/settings.json           ← hooks 등록 (install 시 자동)
~/project/CLAUDE.md               ← 프로젝트별 규칙 (모델 라우팅 등)
```

## Hooks (자동 실행)

| Hook | 이벤트 | 역할 |
|------|--------|------|
| skiro-hook-session | 세션 시작 | learnings 로드, 프로젝트 감지, 아키텍처 staleness |
| skiro-hook-complexity | 파일 Write/Edit | 복잡도 분석, 참조 표시, blast radius, 과거 에러 |
| skiro-hook-gate | Bash 명령 | flash/hwtest 안전 게이트 차단 |
| skiro-hook-prompt | 사용자 메시지 | 문제/해결 패턴 감지 |
| skiro-hook-error | Bash 출력 | 에러 자동 기록 |

## Code MCP 도구 (13개)

**학습/추적**: record_problem, record_solution, list_learnings, search_learnings
**분석**: analyze_complexity, map_codebase
**안전**: safety_gate_create
**파일**: save_artifact, find_artifact
**실험**: archive_experiment (→ ~/research/experiments/{name}/raw/)
**Vault**: vault_search, vault_read, vault_write

## COWORK MCP 도구 (9개)

**조회**: list_artifacts, get_learnings, project_summary, read_file
**논문**: paper_data, paper_state (list/get/set/update), paper_check
**실험**: scan_experiments, promote_data (raw→ppt→paper)

## 모델 라우팅 (CLAUDE.md)

| 작업 | 모델 | 기준 |
|------|------|------|
| 파일 탐색, 검색 | **haiku** | 읽기 전용 |
| 단순 코딩, 단일 파일 | **sonnet** | 로직 단순 |
| 복잡 코딩, 다중 파일, 분석 | **opus** | 아키텍처, 디버깅 |

complexity score 연동: <3 → haiku/sonnet, 3-6 → sonnet, >6 → opus

## Second Brain (Obsidian 연동)

원칙: Claude context에 전체 로드 금지. 항상 부분 참조만.

1. `vault_search(tags/query)` → 관련 노트 검색
2. `vault_read(note, section)` → 필요한 섹션만 로드
3. `vault_write(...)` → 새 인사이트 vault에 기록

설정: `~/.skiro/config.json` → `vault_path`

## 설치/이전

```bash
# 설치
bash ~/skiro/install.sh --project ~/my-project --vault ~/vault

# 백업
bash ~/skiro/bin/skiro-backup.sh ~/backup.tar.gz

# 새 컴퓨터 복원
tar xzf backup.tar.gz -C ~/
bash ~/skiro/install.sh --vault ~/vault
```

Vault는 별도 git 백업: `cd ~/vault && git push`

## 3-tier 실험 데이터

```
실험 끝 (Code) → skiro_archive_experiment → raw/
COWORK에서:
  cowork_promote_data(raw→ppt)    ← 발표용
  cowork_promote_data(ppt→paper)  ← 출판용
```
