#!/usr/bin/env bash
# Skiro v0.1.0 Setup Script
# Run: cd ~/Desktop/ARLAB/skiro && bash setup-skiro.sh
set -euo pipefail

echo "⚡ Setting up Skiro v0.1.0..."

# Clean up any bad symlink commits
rm -f skiro 2>/dev/null || true
git rm skiro 2>/dev/null || true

# Create directories
mkdir -p bin skiro-safety skiro-hwtest skiro-flash skiro-spec skiro-retro templates

# ═══════════════════════════════════════════
# SKILL.md — Main entry point
# ═══════════════════════════════════════════
cat > SKILL.md << 'ENDOFFILE'
---
name: skiro
description: |
  AI development pipeline for Robot Engineers. Covers safety verification,
  hardware testing, firmware management, experiment design, and experiment
  retrospectives for any robot platform. Auto-activates on keywords: robot,
  motor, CAN, firmware, sensor, control loop, impedance, safety, experiment,
  calibration, force limit, watchdog, e-stop, actuator, encoder, PID, IMU.
  Use /skiro-safety for code verification, /skiro-hwtest for hardware tests,
  /skiro-flash for firmware, /skiro-spec for experiment design,
  /skiro-retro for experiment retrospectives.
---

# Skiro — AI Development Pipeline for Robot Engineers
Skills + Robot. Built for real hardware, real experiments, real papers.

## Available Commands
| Command | What it does | When to use |
|---------|-------------|-------------|
| /skiro-safety | Verify code correctness: limits, watchdog, logic | Before flashing, before experiments |
| /skiro-hwtest | Generate hardware test scripts | New hardware, after wiring changes |
| /skiro-flash | Build + upload firmware | Firmware changes |
| /skiro-spec | Design experiment protocol | Planning a new experiment |
| /skiro-retro | Experiment retrospective + paper data | After experiments |

## Workflow
/skiro-spec -> /skiro-safety -> /skiro-hwtest -> /skiro-flash -> experiment -> /skiro-retro
Each skill recommends the next step when it finishes.

## Session Handoff
Starting a new chat? Say "이전 작업 이어서" or "continue last session".
Skiro saves session summaries to ~/.skiro/sessions/ automatically.

## Read these ONLY when needed
| Topic | File |
|-------|------|
| Voice and tone | VOICE.md |
| Safety checklist | CHECKLIST.md |
| Hardware config | hardware.yaml in project root |
ENDOFFILE

# ═══════════════════════════════════════════
# VOICE.md
# ═══════════════════════════════════════════
cat > VOICE.md << 'ENDOFFILE'
# Skiro Voice

You are a senior robotics engineer. You ship hardware+software systems that work
in the real world, not in simulation demos.

## Tone
- Direct. Energetic. Precise.
- Name the file, the line, the value, the unit. Always.
- "motor_ctrl.cpp:42, MAX_FORCE is 70N" not "the force limit looks fine"
- Numbers have units. Always. 18Nm, 111Hz, 70N, 115200baud.
- If you are not sure, say so and ask. Never guess on hardware.

## Rules
- "Looks fine" is banned. Show evidence or say you have not verified.
- "Should work" is banned. Either verify it works or flag as unverified.
- Never assume hardware specs. If user says "ZED camera", ask which model.
  If user says "motor", ask which one. Get the exact model number.
- Connect code to physical consequences: "This missing limit check means
  the motor could output 18Nm instead of the intended 5Nm."
- When something is wrong, say it plainly: "This will break." "This is a bug."
- When something is good, say that too: "Clean implementation." "Solid."

## Anti-patterns
- No AI vocabulary: delve, crucial, robust, comprehensive, furthermore, pivotal.
- No hedging: "might want to consider" -> "do this" or "don't do this"
- No empty praise: "Great question!" -> just answer
- No guessing hardware specs: always verify or ask

## Learnings
When the user says something did not work, a bug occurred, or hardware behaved
unexpectedly, ALWAYS log it. Before answering hardware-related questions,
ALWAYS search learnings for relevant past issues.

## Hardware Respect
Hardware is not software. You cannot undo a bad motor command. You cannot rollback
a burned driver. Every command that touches actuators, power systems, or
communication buses should be treated with the gravity it deserves.
ENDOFFILE

# ═══════════════════════════════════════════
# CHECKLIST.md
# ═══════════════════════════════════════════
cat > CHECKLIST.md << 'ENDOFFILE'
# Skiro Safety Checklist

Universal safety verification for robot software. Adapt thresholds via hardware.yaml.

## CRITICAL (must pass, blocks /skiro-flash)

### 1. Actuator Limits
- [ ] Every motor/actuator command has max value check BEFORE sending
- [ ] Limits match datasheet specs (from hardware.yaml or verified manually)
- [ ] Rate limiter exists: no instant jumps from 0 to max
- [ ] Evidence: cite file:line for each limit check

### 2. Emergency Stop
- [ ] E-stop path exists (hardware preferred, software as backup)
- [ ] E-stop sets all actuator commands to zero/safe state
- [ ] E-stop reachable from every control state
- [ ] E-stop does NOT require communication to work

### 3. Watchdog / Communication Timeout
- [ ] No command within timeout -> auto-stop
- [ ] Timeout value defined and reasonable (typically 100ms or less)
- [ ] Serial/CAN/network loss -> graceful degradation, not crash

### 4. State Machine Integrity
- [ ] All states defined (IDLE, CALIBRATING, RUNNING, E_STOP, ERROR)
- [ ] No undefined state transitions possible
- [ ] ERROR state recoverable only through explicit reset

## WARNING (should fix, does not block)

### 5. Control Loop Timing
- [ ] No blocking calls inside control loop (sleep, print, malloc, file I/O)
- [ ] No dynamic memory allocation in real-time path
- [ ] Loop frequency is measured, not assumed

### 6. Sensor Validation
- [ ] Sensor readings are range-checked (NaN, zero, out-of-range)
- [ ] Calibration values loaded, not hardcoded
- [ ] Sensor failure detected (stuck value, noise spike)

### 7. Communication Protocol
- [ ] Message format has checksum/CRC
- [ ] Byte order is explicit (little/big endian)
- [ ] Buffer overflow protection on receive
- [ ] Message IDs do not conflict (especially CAN bus)

### 8. Units and Constants
- [ ] All physical quantities have units in comments (N, rad, m/s, Nm, Hz)
- [ ] No magic numbers, all constants named and documented
- [ ] Coordinate frames documented

## INFO (nice to have)

### 9. Code Quality
- [ ] Functions are single-purpose and testable
- [ ] Error handling exists (not just happy path)
- [ ] Logging sufficient for post-experiment debugging
- [ ] Configuration is external (yaml/json), not hardcoded
ENDOFFILE

# ═══════════════════════════════════════════
# hardware.yaml.example
# ═══════════════════════════════════════════
cat > hardware.yaml.example << 'ENDOFFILE'
# Skiro Hardware Configuration
# Copy to your project root as hardware.yaml and customize.

motors:
  - name: ""              # e.g., AK60-6, Dynamixel XM430
    interface: ""          # CAN / Serial / PWM / EtherCAT
    max_torque: 0          # Nm (from datasheet)
    max_velocity: 0        # rad/s
    can_id: 0
    datasheet: ""          # path or URL

sensors:
  - name: ""              # e.g., LSB205, MPU-6050, BNO055
    type: ""              # loadcell / imu / encoder
    interface: ""          # ADC / I2C / SPI
    sample_rate: 0         # Hz
    datasheet: ""

cameras:
  - name: ""              # e.g., ZED X Mini, RealSense D435i
    interface: ""          # USB / GMSL2
    resolution: ""
    fps: 0
    datasheet: ""

mcu:
  - name: ""              # e.g., Teensy 4.1, STM32H743
    framework: ""          # arduino / stm32hal
    build_tool: ""         # platformio / cmake
    upload_command: ""     # e.g., "cd firmware && pio run -t upload"

safety:
  max_force: 0             # N
  watchdog_timeout: 100    # ms
  control_loop_hz: 0       # Hz
  e_stop_type: ""          # hardware / software / both
ENDOFFILE

# ═══════════════════════════════════════════
# bin/skiro-learnings
# ═══════════════════════════════════════════
cat > bin/skiro-learnings << 'ENDOFFILE'
#!/usr/bin/env bash
set -euo pipefail
SKIRO_HOME="${SKIRO_HOME:-$HOME/.skiro}"
LEARN_DIR="$SKIRO_HOME/learnings"
mkdir -p "$LEARN_DIR"

CMD="${1:-help}"
shift || true

case "$CMD" in
  search)
    KEYWORD="${1:-}"
    [ -z "$KEYWORD" ] && echo "Usage: skiro-learnings search <keyword>" && exit 1
    grep -ril "$KEYWORD" "$LEARN_DIR"/*.jsonl 2>/dev/null | while read -r f; do
      grep -i "$KEYWORD" "$f" 2>/dev/null
    done | sort -t'"' -k4 -r | head -10
    ;;
  add)
    JSON="${1:-}"
    [ -z "$JSON" ] && echo "Usage: skiro-learnings add '<json>'" && exit 1
    TAG=$(echo "$JSON" | grep -o '"tags":\["[^"]*' | sed 's/"tags":\["//' | tr '[:upper:]' '[:lower:]')
    [ -z "$TAG" ] && TAG="general"
    FILE="$LEARN_DIR/$TAG.jsonl"
    KEY=$(echo "$JSON" | grep -o '"key":"[^"]*' | sed 's/"key":"//')
    if [ -n "$KEY" ] && [ -f "$FILE" ] && grep -q "\"key\":\"$KEY\"" "$FILE" 2>/dev/null; then
      grep -v "\"key\":\"$KEY\"" "$FILE" > "$FILE.tmp" 2>/dev/null || true
      mv "$FILE.tmp" "$FILE"
      echo "Updated: $KEY"
    fi
    if ! echo "$JSON" | grep -q '"ts"'; then
      JSON=$(echo "$JSON" | sed "s/^{/{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",/")
    fi
    echo "$JSON" >> "$FILE"
    echo "Saved to $FILE"
    ;;
  list)
    for f in "$LEARN_DIR"/*.jsonl 2>/dev/null; do
      [ -f "$f" ] || continue
      echo "=== $(basename "$f" .jsonl) ==="
      cat "$f"; echo ""
    done
    ;;
  count)
    TOTAL=0
    for f in "$LEARN_DIR"/*.jsonl 2>/dev/null; do
      [ -f "$f" ] || continue
      C=$(wc -l < "$f" | tr -d ' ')
      TOTAL=$((TOTAL + C))
    done
    echo "$TOTAL"
    ;;
  *) echo "skiro-learnings: search <keyword> | add <json> | list | count" ;;
esac
ENDOFFILE
chmod +x bin/skiro-learnings

# ═══════════════════════════════════════════
# bin/skiro-session
# ═══════════════════════════════════════════
cat > bin/skiro-session << 'ENDOFFILE'
#!/usr/bin/env bash
set -euo pipefail
SKIRO_HOME="${SKIRO_HOME:-$HOME/.skiro}"
CMD="${1:-help}"
shift || true

case "$CMD" in
  save)
    PROJECT="${1:-unknown}"; SUMMARY="${2:-}"
    DIR="$SKIRO_HOME/sessions/$PROJECT"; mkdir -p "$DIR"
    TS=$(date +%Y%m%d-%H%M%S); FILE="$DIR/$TS.md"
    echo "$SUMMARY" > "$FILE"; cp "$FILE" "$DIR/latest.md"
    echo "Session saved: $FILE"
    ;;
  load)
    PROJECT="${1:-unknown}"
    F="$SKIRO_HOME/sessions/$PROJECT/latest.md"
    [ -f "$F" ] && cat "$F" || echo "NO_SESSION"
    ;;
  list)
    PROJECT="${1:-unknown}"
    ls -t "$SKIRO_HOME/sessions/$PROJECT"/*.md 2>/dev/null | head -5 || echo "NO_SESSIONS"
    ;;
  *) echo "skiro-session: save <project> <summary> | load <project> | list <project>" ;;
esac
ENDOFFILE
chmod +x bin/skiro-session

# ═══════════════════════════════════════════
# skiro-safety/SKILL.md
# ═══════════════════════════════════════════
cat > skiro-safety/SKILL.md << 'ENDOFFILE'
---
name: skiro-safety
description: |
  Verify robot code correctness: actuator limits, watchdog, e-stop, state machine,
  control loop timing, communication protocols. Blocks firmware upload if CRITICAL
  items fail. Use before /skiro-flash or before experiments. Keywords: safety, limit,
  watchdog, e-stop, emergency, force limit, max torque, timeout. (skiro)
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
---

Read VOICE.md before responding. Follow its rules exactly.

## Phase 0: Context
1. Read hardware.yaml (if exists) for safety thresholds.
   No hardware.yaml: "No hardware.yaml found. Using conservative defaults."
2. Load relevant learnings:
   ```bash
   chmod +x ~/.claude/skills/skiro/bin/skiro-learnings 2>/dev/null || true
   ~/.claude/skills/skiro/bin/skiro-learnings search "safety" 2>/dev/null || true
   ~/.claude/skills/skiro/bin/skiro-learnings search "limit" 2>/dev/null || true
   ```
   If found: display prior learnings with confidence scores.

## Phase 1: Scope Detection
Find motor/safety-related code:
```bash
grep -rl "motor\|actuator\|torque\|force\|can_send\|serial_write\|e_stop\|watchdog\|limit" src/ firmware/ 2>/dev/null || true
```
No files found: "No motor/safety code found. Nothing to verify."

## Phase 2: Safety Checklist Pass
Read CHECKLIST.md. Apply each item against detected files.
- PASS: cite exact file:line. "motor_ctrl.cpp:42 (if force > 70.0f)"
- FAIL: cite what is missing. "No timeout handler in serial_comm.cpp"
- N/A: explain why.
Confidence 1-10 for each finding. Below 5: do not show.

## Phase 3: Specialist Dispatch (100+ lines of motor/control code)
Launch parallel subagents (model: sonnet):
- Timing specialist: blocking calls in loops >10Hz
- Communication specialist: checksum, byte order, buffer overflow, ID conflicts
Small diff: skip specialists.

## Phase 4: Merge + Confidence
Duplicate findings across sources: boost confidence +1, tag MULTI-SOURCE.
Sort: CRITICAL first.

## Phase 5: Fix-First
- AUTO-FIX: missing unit comments, naming -> fix directly
- ASK: safety-related (limits, watchdog) -> ALWAYS ask user
Present clear summary with fix options A) Fix B) Skip.

## Phase 6: Gate Decision
0 CRITICAL remaining -> SAFE TO FLASH
1+ CRITICAL remaining -> DO NOT FLASH

## Phase 7: Capture Learnings
New issues found -> log via skiro-learnings add.

## Phase 8: Session Save + Next Step
Save session. Recommend /skiro-flash (if PASS) or "fix and re-run" (if FAIL).

## Completion Status
- DONE: All checks passed
- DONE_WITH_CONCERNS: Passed but warnings remain
- BLOCKED: Critical items unresolved
ENDOFFILE

# ═══════════════════════════════════════════
# skiro-hwtest/SKILL.md
# ═══════════════════════════════════════════
cat > skiro-hwtest/SKILL.md << 'ENDOFFILE'
---
name: skiro-hwtest
description: |
  Generate and run hardware test scripts for motors, sensors, cameras,
  communication buses. Keywords: hardware test, motor test, sensor test,
  calibration, wiring, connection test. (skiro)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
---

Read VOICE.md before responding.

## Phase 0: Hardware Discovery
1. Read hardware.yaml. No file: guide user to fill out hardware.yaml.example.
2. Specificity gate: vague names get challenged.
   "ZED" -> "ZED 2, ZED X, or ZED X Mini?"
   "IMU" -> "MPU-6050, BNO055, ICM-42688?"
   Never proceed with vague hardware names.
3. Load learnings for "test" and "hardware" tags.

## Phase 1: Test Plan
Generate test list based on hardware.yaml.
AskUserQuestion: "Which tests?" A) All B) Select C) Just motor D) Just sensors

## Phase 2: Generate Test Scripts
Standalone scripts in tests/hardware/test_{component}.py
Motor tests: max 50% rated torque (safety).

## Phase 3: Run Tests (with permission)
AskUserQuestion before running on real hardware.

## Phase 4: Results + Learnings
Report PASS/FAIL for each. FAIL items -> log learning automatically.

## Phase 5: Next Step
All PASS -> /skiro-safety then /skiro-flash
FAIL -> fix hardware, re-run /skiro-hwtest
ENDOFFILE

# ═══════════════════════════════════════════
# skiro-flash/SKILL.md
# ═══════════════════════════════════════════
cat > skiro-flash/SKILL.md << 'ENDOFFILE'
---
name: skiro-flash
description: |
  Build and upload firmware to MCU (Teensy, STM32, Arduino, etc).
  Enforces pre-flash safety check and git commit.
  Keywords: flash, upload, firmware, deploy, burn, program MCU. (skiro)
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - AskUserQuestion
---

Read VOICE.md before responding.

## Phase 0: Pre-flight
1. Read hardware.yaml for MCU and upload command.
2. Check git status. Uncommitted changes: ask to commit first.

## Phase 1: Safety Gate
Check if /skiro-safety was run. If not: recommend running it first.

## Phase 2: Build
Run build command from hardware.yaml. Fail -> show error, STOP.

## Phase 3: Upload
Build success -> run upload command.

## Phase 4: Post-flash Verification
Basic communication test after upload. Report PASS/FAIL.

## Phase 5: Log + Next Step
Save session. Next: /skiro-hwtest to validate.
ENDOFFILE

# ═══════════════════════════════════════════
# skiro-spec/SKILL.md
# ═══════════════════════════════════════════
cat > skiro-spec/SKILL.md << 'ENDOFFILE'
---
name: skiro-spec
description: |
  Design experiment protocols. Conditions, variables, data collection,
  safety, statistics. Manual invocation only.
  Keywords: experiment design, protocol, test plan, data collection. (skiro)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - WebSearch
  - AskUserQuestion
---

Read VOICE.md before responding.

## Phase 0: Context
Read README.md, CLAUDE.md, existing protocols in docs/.
Load experiment-related learnings.

## Phase 1: Research Question (one at a time)
Ask specific research question via AskUserQuestion.
Push for specificity: "Does the robot help?" is too vague.

## Phase 2: Experimental Design (one question at a time)
1. Experimental conditions?
2. What are you measuring? Primary/secondary outcomes.
3. Participants/test objects? Criteria.
4. Sensors and frequencies? Cross-ref hardware.yaml.
5. Safety stopping criteria?
Smart-skip if already answered.

## Phase 3: Related Work Search (optional)
Offer to search for related experimental protocols.

## Phase 4: Protocol Document
Write to docs/protocol_{date}_{title}.md with full structure:
Research question, design, participants, outcomes, data collection,
procedure, safety, statistical analysis, data naming convention.
AskUserQuestion: A) Approve B) Revise C) Start over

## Phase 5: Next Step
Approved -> /skiro-safety to verify code
ENDOFFILE

# ═══════════════════════════════════════════
# skiro-retro/SKILL.md
# ═══════════════════════════════════════════
cat > skiro-retro/SKILL.md << 'ENDOFFILE'
---
name: skiro-retro
description: |
  Experiment retrospective: data summary, problem analysis, lessons,
  paper-ready structured output. Keywords: retrospective, retro,
  experiment results, what went wrong, lessons learned, paper data. (skiro)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
---

Read VOICE.md before responding.

## Phase 0: Context
Load protocol, session history, ALL learnings.

## Phase 1: Data Inventory
Ask which experiment. Check data completeness.
Report: subjects, conditions, trials, missing data, quality.

## Phase 2: What Happened (one at a time)
1. Main results? Numbers.
2. What went wrong? HW issues, SW bugs, protocol deviations.
3. What surprised you?

## Phase 3: Problem Analysis
For each problem: root cause, impact, prevention, priority.
Log each as a learning via skiro-learnings add.

## Phase 4: Retrospective Document
Write docs/retro_{date}.md with:
Summary, results, problems table, lessons, action items, paper-ready data.

## Phase 5: GitHub Issues (optional)
Offer to create issues for action items.

## Phase 6: Paper Connection
Format key stats for IEEE/JNER LaTeX.
Suggest figure descriptions and BibTeX keys.

## Phase 7: Session Save + Sync Reminder
Save session. Remind: git add -A && git commit && git push
Next: /skiro-spec for next experiment.
ENDOFFILE

# ═══════════════════════════════════════════
# templates/session-handoff.md
# ═══════════════════════════════════════════
cat > templates/session-handoff.md << 'ENDOFFILE'
# Session Handoff
## Project
{project name}
## Date
{YYYY-MM-DD HH:MM}
## What was done
- {task 1}
## Current state
- Working on: {current task}
- Branch: {git branch}
## TODO
- [ ] {remaining task}
## Known issues
- {issue}
## Learnings saved
- {learning}
ENDOFFILE

# ═══════════════════════════════════════════
# .gitignore
# ═══════════════════════════════════════════
cat > .gitignore << 'ENDOFFILE'
.DS_Store
Thumbs.db
.vscode/
.idea/
ENDOFFILE

# ═══════════════════════════════════════════
# LICENSE (MIT)
# ═══════════════════════════════════════════
cat > LICENSE << 'ENDOFFILE'
MIT License

Copyright (c) 2026 Cho Byeongjun

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
ENDOFFILE

# ═══════════════════════════════════════════
# README.md (Fancy)
# ═══════════════════════════════════════════
cat > README.md << 'ENDOFFILE'
<p align="center">
  <img src="https://img.shields.io/badge/skiro-v0.1.0-blue?style=for-the-badge" alt="version"/>
  <img src="https://img.shields.io/badge/platform-Win%20%7C%20Mac%20%7C%20Linux-green?style=for-the-badge" alt="platform"/>
  <img src="https://img.shields.io/badge/license-MIT-orange?style=for-the-badge" alt="license"/>
  <img src="https://img.shields.io/badge/Claude%20Code-compatible-blueviolet?style=for-the-badge" alt="claude"/>
</p>

<h1 align="center">Skiro</h1>
<p align="center"><strong>AI Development Pipeline for Robot Engineers</strong></p>
<p align="center"><em>Skills + Robot = Skiro</em></p>
<p align="center">Stop repeating the same hardware mistakes. Let your AI remember them for you.</p>

---

## What is Skiro?

Skiro turns Claude Code into a **robot-aware development partner**. It knows that
motors have torque limits, communication buses have timing constraints, and firmware
uploads cannot be undone.

```
You:    "Review my motor control code"
Skiro:  Prior learning: AK60 ID conflict (2026-03-15, confidence 9/10)
        CRITICAL motor_ctrl.cpp:42 — force limit check missing
        WARNING  control_loop.cpp:88 — printf blocking call in 111Hz loop
        PASS     watchdog.cpp:15 — timeout 50ms (verified)
        -> 1 critical, 1 warning. Fix now?
```

## Features

- **Safety Verification** — Actuator limits, watchdog, e-stop, timing
- **Learnings System** — Remembers hardware bugs across sessions
- **Hardware-Aware** — Reads hardware.yaml, verifies code against specs
- **Model Routing** — Haiku for search, Sonnet for review, Opus for design
- **Experiment Pipeline** — Design -> Safety -> Test -> Flash -> Retro -> Paper
- **Session Handoff** — Continue where you left off
- **Cross-Platform** — Windows, macOS, Linux. No binary dependencies.

## Commands

| Command | What it does |
|---------|-------------|
| `/skiro-safety` | Verify code: limits, watchdog, e-stop, timing |
| `/skiro-hwtest` | Generate + run hardware test scripts |
| `/skiro-flash` | Build + upload firmware (safety gate) |
| `/skiro-spec` | Design experiment protocol |
| `/skiro-retro` | Experiment retrospective + paper data |

## Installation

```bash
git clone https://github.com/chobyeongjun/skiro.git ~/.claude/skills/skiro
chmod +x ~/.claude/skills/skiro/bin/*
```

Windows:
```powershell
git clone https://github.com/chobyeongjun/skiro.git "$env:USERPROFILE\.claude\skills\skiro"
```

## Hardware Configuration

Copy `hardware.yaml.example` to your project root as `hardware.yaml`:

```yaml
motors:
  - name: AK60-6
    interface: CAN
    max_torque: 18  # Nm
safety:
  max_force: 70     # N
  watchdog_timeout: 100  # ms
```

## Works With

| Tool | Role |
|------|------|
| gstack | Brainstorming, code review, dev retrospectives |
| Superpowers | TDD workflow |
| Context7 | Live library documentation |

## Philosophy

1. Hardware is not software. You cannot undo a bad motor command.
2. AI should remember your mistakes. Humans forget. Logs don't.
3. Evidence, not opinions. Every PASS needs a file:line citation.
4. Simple interface, complex internals. You see PASS/FAIL.
5. Any robot, any platform. Teensy or STM32, CAN or Serial.

## License

MIT

## Author

**Cho Byeongjun** — Robot Engineer, ARLAB, Chung-Ang University
ENDOFFILE

# ═══════════════════════════════════════════
# Symlink
# ═══════════════════════════════════════════
rm -f ~/.claude/skills/skiro 2>/dev/null || true
ln -s "$(pwd)" ~/.claude/skills/skiro
echo "Symlink: ~/.claude/skills/skiro -> $(pwd)"

echo ""
echo "⚡ Skiro v0.1.0 setup complete!"
echo ""
echo "Files created:"
find . -type f -not -path './.git/*' | sort
echo ""
echo "Next: git add -A && git commit -m 'feat: skiro v0.1.0' && git push"
