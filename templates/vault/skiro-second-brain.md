---
title: skiro Second Brain 사용법
created: 2026-04-16
updated: 2026-04-16
sources: []
tags: [skiro, obsidian, vault, second-brain, memory]
summary: Obsidian vault를 Claude의 외부 메모리로 사용하는 방법과 규칙
confidence_score: 0.95
---

# [[skiro Second Brain 사용법]]

## 핵심 원칙

Claude의 context window는 유한하다. 모든 지식을 context에 넣으면 터진다.
대신 **Obsidian vault를 외부 메모리로** 사용한다.

| 구분 | 저장 위치 | Claude가 하는 것 |
|------|----------|----------------|
| 논문 설계 상태 | `~/.skiro/papers/{id}.json` | paper_state get/set/update |
| 기술 지식 | vault `10_Wiki/` | vault_search → vault_read(section만) |
| 설계 결정 | vault `10_Wiki/Decisions/` | vault_search(tags) |
| 실험 데이터 | `~/research/experiments/` | scan_experiments |
| 에러/해결 | `~/.skiro/learnings.jsonl` | get_learnings |
| 파일 이력 | `~/.skiro/artifacts.jsonl` | list_artifacts |

## 사용 규칙 (Claude가 지켜야 하는 것)

### 1. 전체 로드 절대 금지

```
# 나쁜 예 ❌
vault_read(note="big-note")                    # 노트 전체 로드

# 좋은 예 ✅
vault_search(tags: ["motor"])                  # 검색 먼저
vault_read(note="ak60-motor", section="Spec")  # 섹션만 로드
```

### 2. 세션 시작 시 복원 패턴

```
paper_state(action="get")           # 논문 상태 복원
scan_experiments(...)               # 실험 현황
vault_search(query="프로젝트명")      # 관련 노트 인덱스만
```

세션이 바뀌어도 state는 파일에 있으므로 다시 시작 가능.

### 3. 세션 끝날 때 저장 패턴

```
paper_state(action="update", ...)   # 변경분만 저장
vault_write(...)                    # 새 인사이트 기록
```

### 4. Vault 노트 검색 우선순위

| 상황 | 검색 방법 |
|------|----------|
| 하드웨어 코드 수정 중 | `vault_search(tags: ["motor","sensor","can-bus"])` |
| 설계 결정 필요 | `vault_search(folder: "10_Wiki/Decisions")` |
| 프로젝트 컨텍스트 | `vault_search(query: "프로젝트명")` |
| 과거 실험 참조 | `vault_search(tags: ["experiment", "실험키워드"])` |
| 기술 스펙 확인 | `vault_search(folder: "10_Wiki/Topics")` |

### 5. Vault 쓰기: 언제?

- 실험 끝났을 때 → `vault_write(path: "00_Raw/experiments/...")`
- 중요한 결정했을 때 → `vault_write(path: "10_Wiki/Decisions/...")`
- 트러블슈팅 기록 → `vault_write(path: "00_Raw/troubleshooting/...")`
- 미팅 노트 → `vault_write(path: "00_Raw/meetings/...")`

## Vault 노트 형식

```yaml
---
title: 노트 제목
created: 2026-04-16
updated: 2026-04-16
sources: []
tags: [태그1, 태그2]
summary: 한 줄 요약
confidence_score: 0.7
---
```

- `tags`: vault_search에서 필터링에 사용됨
- `summary`: 검색 결과에 미리보기로 표시됨
- `confidence_score`: 높을수록 검색 결과 상위 (0.0-1.0)

## 설정

```bash
# vault 경로 설정
bash ~/skiro/install.sh --vault ~/0xhenry.dev/vault

# 확인
cat ~/.skiro/config.json
# → { "vault_path": "/Users/.../vault" }
```

환경변수로도 가능: `SKIRO_VAULT=/path/to/vault`

## Vault 백업

```bash
cd ~/0xhenry.dev/vault
git add -A && git commit -m "vault backup" && git push
```

skiro 데이터 백업은 별도:
```bash
bash ~/skiro/bin/skiro-backup.sh ~/backup.tar.gz
```
