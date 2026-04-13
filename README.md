# skiro

**AI Development Harness for Robot Engineers**

Claude Code harness (Hooks + MCP + References) for robot/firmware development.
Auto-tracks problems, solutions, code complexity, and file artifacts — no manual commands.

---

## Architecture

```
~/skiro/                          ← 한 곳에 설치 (어디든 OK)
  ├── bin/                        ← hooks + Code MCP 서버
  ├── cowork/                     ← COWORK MCP 서버 (claude.ai용)
  └── templates/CLAUDE.md.template

~/.claude/settings.json           ← hooks + MCP 자동 등록 (install 시)
                                    어떤 프로젝트 열어도 자동 적용

~/project-A/CLAUDE.md             ← 프로젝트별 규칙 (모델 라우팅, artifact 등)
~/project-B/CLAUDE.md
```

**skiro는 한번 설치하면 모든 프로젝트에서 자동 작동.** CLAUDE.md만 프로젝트별로 필요.

---

## Install

### macOS / Linux

```bash
git clone https://github.com/chobyeongjun/skiro ~/skiro
bash ~/skiro/install.sh --project /path/to/your/project --vault ~/your-vault
```

### Windows (PowerShell)

> **Prerequisites**: [Git for Windows](https://git-scm.com/download/win) must be installed (provides `sh` for hooks).

```powershell
git clone https://github.com/chobyeongjun/skiro $HOME\skiro
powershell -ExecutionPolicy Bypass -File $HOME\skiro\install.ps1 -Project "C:\path\to\your\project" -Vault "C:\path\to\vault"
```

### Add to another project (install 후)

```bash
cp ~/skiro/templates/CLAUDE.md.template ~/another-project/CLAUDE.md
```

또는:

```bash
bash ~/skiro/install.sh --project ~/another-project
```

### What the installer does

| Step | macOS/Linux | Windows |
|------|-------------|---------|
| 1 | `chmod +x` (permissions) | — (not needed) |
| 2 | `npm install` | `npm install` |
| 3 | vault → `~/.skiro/config.json` | vault → `~/.skiro/config.json` |
| 4 | PATH → `~/.zshrc` or `~/.bashrc` | PATH → User Environment Variable |
| 5 | hooks → `~/.claude/settings.json` | hooks → `~/.claude/settings.json` (via `sh`) |
| 6 | `claude mcp add skiro` | `claude mcp add skiro` |
| 7 | CLAUDE.md → project | CLAUDE.md → project |

### Verify

```bash
cat ~/.claude/settings.json | grep skiro
claude mcp list | grep skiro
cat ~/.skiro/config.json
```

---

## How it works

**Hooks** (auto-triggered by Claude Code events):

| Hook | Event | What it does |
|------|-------|-------------|
| skiro-hook-session | Session start | Load recent learnings, detect new projects, check architecture staleness |
| skiro-hook-complexity | Write/Edit file | Analyze complexity, show refs, blast radius, past errors for the file |
| skiro-hook-gate | Bash command | Block flash/hwtest if safety gate missing or expired |
| skiro-hook-prompt | User message | Detect problem/solution patterns |
| skiro-hook-error | Bash output | Auto-record errors from command output |

**MCP Tools** (13 tools, called by Claude automatically):

| Tool | Purpose |
|------|---------|
| `skiro_record_problem` | Record a bug/error with category and severity |
| `skiro_record_solution` | Link solution to most recent unsolved problem |
| `skiro_list_learnings` | List recent problems/solutions (filtered) |
| `skiro_search_learnings` | Search past learnings by keyword |
| `skiro_analyze_complexity` | Score code complexity → route safety analysis depth |
| `skiro_map_codebase` | Build dependency graph, identify hub/risk files, blast radius |
| `skiro_safety_gate_create` | Unlock flash/hwtest after passing safety analysis |
| `skiro_save_artifact` | Register any file Claude creates (auto-called) |
| `skiro_find_artifact` | Find previously saved files by keyword/category |
| `skiro_archive_experiment` | Archive experiment data to ~/research/experiments/{name}/raw/ |
| `skiro_vault_search` | Search Obsidian vault notes by keyword/tags/folder |
| `skiro_vault_read` | Read vault note content, section filter, wiki-link extraction |
| `skiro_vault_write` | Create/append notes with frontmatter (experiments, decisions, logs) |

---

## Model routing

CLAUDE.md에 정의된 모델 라우팅 규칙 (서브에이전트 위임 시 자동 적용):

| 작업 유형 | 모델 | 기준 |
|-----------|------|------|
| 파일 탐색, 검색 | **haiku** | 읽기 전용 |
| 단순 코딩, 단일 파일 수정 | **sonnet** | 로직 단순, 파일 1~2개 |
| 복잡한 코딩, 다중 파일, 설계, 분석 | **opus** | 연쇄 변경, 아키텍처, 디버깅 |

complexity score 연동: score < 3 → haiku/sonnet, 3-6 → sonnet, > 6 → opus

---

## Experiment data pipeline

실험 데이터 3-tier 관리:

```
실험 끝 (Claude Code)
  skiro_archive_experiment → ~/research/experiments/{name}/raw/
                                                          ├── raw/     ← 전체 데이터
COWORK (claude.ai)                                        ├── ppt/     ← 발표용 선별
  cowork_promote_data(raw→ppt)                            └── paper/   ← 논문용 선별
  cowork_promote_data(ppt→paper)
```

---

## Obsidian vault integration

Obsidian vault를 지식 베이스로 연동. 코딩 중 하드웨어 스펙, 설계 결정, 실험 기록을 자동 참조.

```
~/.skiro/config.json    ← vault_path 저장 (install --vault 또는 수동 설정)

~/vault/                ← Obsidian vault (어디든 OK)
  ├── 00_Raw/           ← 미정리 메모, 미팅 노트
  ├── 10_Wiki/          ← 정제된 지식
  │   ├── Topics/       ← 기술 주제 (motor, sensor, protocol)
  │   ├── Projects/     ← 프로젝트별 노트
  │   ├── Decisions/    ← 설계 결정 기록
  │   └── Skills/       ← 개인 기술/방법론
  ├── 10_Planning/      ← 계획, 로드맵
  └── 20_Meta/          ← vault 자체 관리
```

Vault 노트 형식 (YAML frontmatter):
```yaml
---
title: AK60 Motor Specs
tags: [motor, bldc, can-bus]
summary: AK60-6 모터의 토크/속도/통신 사양
confidence_score: 0.9
---
```

사용 흐름:
1. 코드 수정 중 → `skiro_vault_search(tags: ["motor"])` → 관련 노트 발견
2. 필요한 노트만 → `skiro_vault_read(note: "ak60-motor")` → 스펙 확인
3. 실험/결정 기록 → `skiro_vault_write(path: "10_Wiki/Decisions/...")` → vault에 저장

---

## Safety gate

No `flash` or `hwtest` command runs without `.skiro_safety_gate`:

```
safety analysis → PASS → gate created → flash allowed
                → FAIL → flash blocked (exit 2)
```

Gate expires after 48h. Warning at 24h.

---

## Learnings

Problems and solutions stored in `~/.skiro/learnings.jsonl` (global).

```bash
skiro-learnings list --last 10
skiro-learnings search "CAN"
skiro-learnings promote 3 --auto   # 3+ repeats → CHECKLIST.md
```

When editing code, related past errors appear automatically (by category matching).

---

## Skills

| Skill | Purpose |
|-------|---------|
| /skiro-hwtest | Hardware test + hardware.yaml generation |
| /skiro-safety | Code safety analysis |
| /skiro-flash | Firmware build + upload |
| /skiro-comm | CAN / BLE / WiFi / Serial |
| /skiro-plan | Experiment planning |
| /skiro-data | Data pipeline: logging, filtering, visualization |
| /skiro-analyze | Control analysis, Bode, statistics |
| /skiro-gui | Desktop GUI (PyQt, Tkinter) |
| /skiro-retro | Retrospective → paper packet for COWORK |

---

## COWORK (claude.ai 연동)

Claude Code에서 저장한 데이터를 claude.ai에서 PPT/논문 작성에 활용:

```bash
cd ~/skiro/cowork && npm install
claude mcp add skiro-cowork -s user -- node ~/skiro/cowork/skiro-cowork-server.mjs
```

| Tool | Purpose |
|------|---------|
| `cowork_list_artifacts` | Code에서 저장한 파일 찾기 |
| `cowork_get_learnings` | 문제-해결 이력 (방법론 변경 근거) |
| `cowork_project_summary` | 미팅/논문용 프로젝트 요약 |
| `cowork_paper_data` | 논문 섹션별 데이터 추출 |
| `cowork_read_file` | 파일 실제 내용 읽기 |
| `cowork_scan_experiments` | 실험/미팅 데이터 전체 스캔 (3-tier) |
| `cowork_paper_state` | 논문 설계 상태 영구 저장/로드 |
| `cowork_promote_data` | raw→ppt→paper 데이터 승격 |

Details: [cowork/README.md](cowork/README.md)

---

## Backup & portability

다른 컴퓨터로 이전 시:

```bash
# 1. 백업 (원본 컴퓨터)
bash ~/skiro/bin/skiro-backup.sh ~/skiro-backup.tar.gz

# 2. 복원 (새 컴퓨터)
tar xzf skiro-backup.tar.gz -C ~/
bash ~/skiro/install.sh --vault ~/your-vault
```

백업에 포함되는 항목:
- `~/skiro/` — harness 코드
- `~/.skiro/` — config, learnings, artifacts, paper states
- `~/.claude/settings.json` — hooks 설정

---

## Requirements

|  | macOS | Linux | Windows |
|--|-------|-------|---------|
| Shell | zsh / bash | bash | Git Bash (for hooks) |
| Node.js | >= 18 | >= 18 | >= 18 |
| Python | 3.x | 3.x | 3.x |
| Claude Code | CLI or Desktop | CLI | CLI or Desktop |

---

## License

MIT
