# skiro

**AI Development Harness for Robot Engineers**

skiro is a Claude Code harness that automatically tracks problems, solutions, and safety analysis during robot/firmware development — without any manual commands.

---

## What it does

When you say *"the motor position jumped"* → Claude records the problem automatically.  
When you say *"fixed it by sending zero command first"* → Claude links the solution automatically.  
When the same problem repeats 3 times → Claude suggests adding it to your CHECKLIST.

No CLI commands. No manual logging. Just talk.

---

## Install

```bash
# 1. Clone
git clone https://github.com/chobyeongjun/skiro ~/skiro

# 2. Install MCP dependencies
cd ~/skiro/bin && npm install

# 3. Add to PATH
echo 'export PATH="$HOME/skiro/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 4. Register MCP server (Claude Code)
claude mcp add skiro -s user -- node ~/skiro/bin/skiro-mcp-server.mjs

# Note: if installed to a custom path, set SKIRO_BIN:
# export SKIRO_BIN=/your/custom/path/skiro/bin
```

Verify:
```bash
claude mcp list | grep skiro
# skiro: node ~/skiro/bin/skiro-mcp-server.mjs - ✓ Connected
```

---

## Add to your project

Add this to `~/.claude/CLAUDE.md` (global) or your project's `CLAUDE.md`:

```markdown
## skiro Harness

Problem detected ("failed", "error", "not working", "안됐어", "버그") → auto-call skiro_record_problem  
Solution found ("fixed", "solved", "it worked", "됐어", "해결됐어") → auto-call skiro_record_solution  
Code file mentioned → auto-call skiro_analyze_complexity  
Session start → auto-call skiro_list_learnings (last 5)

Report format: one line only. "[?] Recorded: ..." or "[✓] Solution linked: ..."
```

---

## MCP Tools

| Tool | Auto-trigger |
|------|-------------|
| `skiro_record_problem` | bug / failure / unexpected behavior detected |
| `skiro_record_solution` | fix / solution found in conversation |
| `skiro_analyze_complexity` | code file mentioned or opened |
| `skiro_list_learnings` | session start or new task begins |

---

## Complexity scoring

`skiro-complexity` analyzes firmware files and routes safety analysis:

```bash
skiro-complexity firmware/main.c --json
```

| Score | Tier | Loads |
|-------|------|-------|
| < 30 | fast | p1-scope, p2-checklist |
| 30–79 | partial | + p3-fork §A, p4-gate |
| ≥ 80 | full | all phases + domain skill |

Scoring factors: LOC, ISR count, threads, CAN nodes, motors, RTOS, shared memory, DMA, control algorithms.

---

## Safety gate

No `flash` or `hwtest` proceeds without `.skiro_safety_gate`:

```
skiro-safety → analysis → PASS → .skiro_safety_gate created → flash allowed
                        → BLOCK → flash refused
```

---

## Learnings

Problems and solutions are stored in `.skiro/learnings.jsonl` per project.

```bash
skiro-learnings list --last 10
skiro-learnings search "CAN"
skiro-learnings promote 3    # show items repeated 3+ times → CHECKLIST candidates
```

---

## Skills

| Skill | Purpose |
|-------|---------|
| skiro-safety | Code safety analysis (ISR, motor limits, CAN timeout) |
| skiro-plan | Experiment planning → current-experiment.json |
| skiro-retro | Session retrospective → learnings |
| skiro-hwtest | Hardware test procedures |
| skiro-flash | Firmware flash procedures |
| skiro-comm | CAN / UART / SPI / ROS2 |
| skiro-gait | Gait analysis, GDI, phase detection |
| skiro-data | Signal filtering, logging, visualization |
| skiro-mocap | VICON, ZED, IMU motion capture |
| skiro-analyze | Bode plot, control metrics, statistics |

---

## Requirements

- macOS / Linux / Windows (WSL)
- Node.js ≥ 18
- Python 3
- Claude Code

---

## License

MIT
