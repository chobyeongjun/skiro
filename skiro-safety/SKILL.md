---
name: skiro-safety
description: |
  Verify and audit robot code for safety: actuator limits, watchdog, e-stop,
  state machine, control loop timing, communication protocols. Code review
  and verification only — NOT for building GUI, plotting data, or writing
  new features. Blocks firmware upload if CRITICAL items fail.
  Keywords (EN/KR): safety check/안전 검증, verify limits/제한 확인,
  watchdog/워치독, e-stop/비상 정지, 토크 제한, 안전성 점검,
  코드 검증, 타임아웃, state machine/상태 머신. (skiro)
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
   # macOS/Linux
   chmod +x ~/.claude/skills/skiro/bin/skiro-learnings 2>/dev/null || true
   ~/.claude/skills/skiro/bin/skiro-learnings search "safety" 2>/dev/null || true
   ~/.claude/skills/skiro/bin/skiro-learnings search "limit" 2>/dev/null || true
   ```
   ```powershell
   # Windows
   pwsh "$HOME\.claude\skills\skiro\bin\skiro-learnings.ps1" search "safety" 2>$null
   pwsh "$HOME\.claude\skills\skiro\bin\skiro-learnings.ps1" search "limit" 2>$null
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

## Wrong Skill? Redirect
If the user's request does not match this skill, DO NOT attempt it.
Instead, explain what this skill does and redirect to the correct one:
- Want to build a GUI? → "/skiro-gui handles desktop GUI development."
- Want to analyze experiment data? → "/skiro-analyze does RMSE, FFT, statistics."
- Want to plan an experiment? → "/skiro-plan handles experiment design and brainstorming."
- Want to flash firmware? → "/skiro-flash builds and uploads firmware to MCU."
- Want to test hardware? → "/skiro-hwtest generates and runs hardware test scripts."
- Want to manage data files? → "/skiro-data handles data collection, validation, and format conversion."
- Want to set up BLE/WiFi/Serial? → "/skiro-comm handles robot communication setup."
- Want gait analysis? → "/skiro-gait does gait cycle, heel strike, temporal-spatial parameters."
- Want experiment retrospective? → "/skiro-retro summarizes results and generates paper packets."
