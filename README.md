# skiro

**AI Development Harness for Robot Engineers**

Claude Code harness (Hooks + MCP + References) for robot/firmware development.
Auto-tracks problems, solutions, code complexity, and file artifacts — no manual commands.

---

## Install

### macOS / Linux

```bash
git clone https://github.com/chobyeongjun/skiro ~/skiro
bash ~/skiro/install.sh --project /path/to/your/robot/project
```

### Windows (PowerShell)

> **Prerequisites**: [Git for Windows](https://git-scm.com/download/win) must be installed (provides `sh` for hooks).

```powershell
git clone https://github.com/chobyeongjun/skiro $HOME\skiro
powershell -ExecutionPolicy Bypass -File $HOME\skiro\install.ps1 -Project "C:\path\to\your\project"
```

### What the installer does

| Step | macOS/Linux | Windows |
|------|-------------|---------|
| 1 | `chmod +x` (permissions) | — (not needed) |
| 2 | `npm install` | `npm install` |
| 3 | PATH → `~/.zshrc` or `~/.bashrc` | PATH → User Environment Variable |
| 4 | hooks → `~/.claude/settings.json` | hooks → `~/.claude/settings.json` (via `sh`) |
| 5 | `claude mcp add skiro` | `claude mcp add skiro` |
| 6 | CLAUDE.md → project | CLAUDE.md → project |

### Verify

```bash
claude mcp list | grep skiro
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

**MCP Tools** (9 tools, called by Claude automatically):

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
| `cowork_scan_experiments` | 실험/미팅 데이터 전체 스캔 |
| `cowork_paper_state` | 논문 설계 상태 영구 저장/로드 |

Details: [cowork/README.md](cowork/README.md)

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
