#!/usr/bin/env bash
# setup-skiro.sh v2.0.0
# Self-contained installer for Skiro — AI Development Pipeline for Robot Engineers
# Usage: bash setup-skiro.sh
# Tries git clone first; falls back to heredoc generation if clone fails.

set -euo pipefail

SKIRO_DIR="$HOME/.claude/skills/skiro"
REPO_URL="https://github.com/chobyeongjun/skiro.git"
VERSION="2.0.0"
USED_GIT=false

echo "============================================"
echo " Skiro v${VERSION} Installer"
echo "============================================"

# ── Step 1: Try git clone ────────────────────────────────────────────
if command -v git >/dev/null 2>&1; then
  echo "[1/4] Trying git clone from ${REPO_URL} ..."
  if git clone "$REPO_URL" "$SKIRO_DIR" 2>/dev/null; then
    echo "      git clone succeeded."
    USED_GIT=true
  else
    echo "      git clone failed (no network or repo not public). Falling back to heredoc install."
  fi
else
  echo "[1/4] git not found. Using heredoc install."
fi

# ── Step 2: Heredoc file generation (skipped if git clone succeeded) ─
if [ "$USED_GIT" = false ]; then
  echo "[1/4] Generating files from heredocs ..."
  mkdir -p \
    "$SKIRO_DIR/bin" \
    "$SKIRO_DIR/templates" \
    "$SKIRO_DIR/references" \
    "$SKIRO_DIR/evals" \
    "$SKIRO_DIR/skiro-safety" \
    "$SKIRO_DIR/skiro-hwtest" \
    "$SKIRO_DIR/skiro-flash" \
    "$SKIRO_DIR/skiro-spec" \
    "$SKIRO_DIR/skiro-retro" \
    "$SKIRO_DIR/skiro-gui" \
    "$SKIRO_DIR/skiro-data" \
    "$SKIRO_DIR/skiro-analyze" \
    "$SKIRO_DIR/skiro-gait"

  # ── SKILL.md ──────────────────────────────────────────────────────
  cat > "$SKIRO_DIR/SKILL.md" << 'ENDOFFILE'
---
name: skiro
description: |
  AI development pipeline for Robot Engineers. Covers safety verification,
  hardware testing (with auto-generated hardware.yaml from datasheets),
  firmware management, experiment design, data collection, analysis,
  GUI development, and experiment retrospectives for any robot platform.
  Auto-activates on keywords: robot, motor, CAN, firmware, sensor, control
  loop, impedance, safety, experiment, calibration, force limit, watchdog,
  e-stop, actuator, encoder, PID, IMU, GUI, data, CSV, gait, analysis.
  Use /skiro-safety for code verification, /skiro-hwtest for hardware tests
  and auto hardware.yaml, /skiro-flash for firmware, /skiro-spec for
  experiment design, /skiro-retro for retrospectives, /skiro-gui for GUI
  development, /skiro-data for data management, /skiro-analyze for analysis,
  /skiro-gait for gait-specific analysis.
---

# Skiro — AI Development Pipeline for Robot Engineers
Skills + Robot. Built for real hardware, real experiments, real papers.

## Available Commands

| Command | What it does | When to use |
|---------|-------------|-------------|
| /skiro-hwtest | Hardware test + **auto hardware.yaml from datasheets** | New project, new hardware, setup |
| /skiro-safety | Verify code correctness: limits, watchdog, logic | Before flashing, before experiments |
| /skiro-flash | Build + upload firmware to MCU | Firmware changes |
| /skiro-spec | Design experiment protocol | Planning a new experiment |
| /skiro-data | Data collection, validation, organization | Download from robot, validate data |
| /skiro-analyze | Universal data analysis (RMSE, FFT, stats) | Analyze results, compare conditions |
| /skiro-gait | Gait analysis (extends /skiro-analyze) | Walking robot / exoskeleton projects |
| /skiro-gui | GUI development (layout, styling, responsive) | Build or fix robot UI |
| /skiro-retro | Experiment retrospective + paper data | After experiments |

## Workflow

```
                   ┌── /skiro-gui (GUI work, anytime)
                   │
/skiro-hwtest ────→ /skiro-spec ──→ /skiro-safety ──→ /skiro-flash
(auto hardware.yaml)  (experiment)    (code verify)     (firmware)
                                                           │
                                                      [experiment]
                                                           │
                                    /skiro-data ──→ /skiro-analyze ──→ /skiro-retro
                                    (collect data)   (analysis)         (retrospective)
                                                        │
                                                   /skiro-gait
                                                   (gait-specific)
```

Each skill recommends the next step when it finishes.

## Architecture

```
┌─────────────────────────────────────────────┐
│  Domain Extensions                           │
│  ┌─────────────┐                             │
│  │ skiro-gait  │  Gait analysis              │
│  └──────┬──────┘                             │
│         │ extends                             │
│  ┌──────┴─────────────────────────────────┐  │
│  │ skiro-analyze  │ Universal analysis     │  │
│  └────────────────────────────────────────┘  │
├─────────────────────────────────────────────┤
│  Core Skills                                 │
│  hwtest │ safety │ flash │ spec │ retro      │
│  gui    │ data                               │
├─────────────────────────────────────────────┤
│  Infrastructure                              │
│  hardware.yaml │ CHECKLIST.md │ VOICE.md     │
│  learnings     │ sessions     │ references/  │
└─────────────────────────────────────────────┘
```

## Getting Started

1. Run `/skiro-hwtest` — tell it your hardware, it generates hardware.yaml
2. The rest of the pipeline follows naturally

## Session Handoff
Starting a new chat? Say "이전 작업 이어서" or "continue last session".
Skiro saves session summaries to ~/.skiro/sessions/ automatically.

## Read these ONLY when needed
| Topic | File |
|-------|------|
| Voice and tone | VOICE.md |
| Safety checklist | CHECKLIST.md |
| Hardware config template | hardware.yaml.template |
| Datasheet search guide | references/datasheet-search.md |
| GUI layout rules | references/gui-layout-rules.md |
| Data format guide | references/data-formats.md |
| Analysis methods | references/analysis-methods.md |
ENDOFFILE

  # ── VOICE.md ──────────────────────────────────────────────────────
  cat > "$SKIRO_DIR/VOICE.md" << 'ENDOFFILE'
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

  # ── CHECKLIST.md ──────────────────────────────────────────────────
  cat > "$SKIRO_DIR/CHECKLIST.md" << 'ENDOFFILE'
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

### 9. Data Logging Integrity
- [ ] Log file header written before data rows
- [ ] Timestamp column increments monotonically
- [ ] Log flush/sync frequency prevents data loss on power failure
- [ ] File naming includes date and avoids overwrite of existing files
- [ ] SD card / storage full condition handled gracefully

### 10. Power and Voltage Safety
- [ ] Motor driver voltage matches power supply rating
- [ ] Reverse polarity protection exists or is documented as absent
- [ ] Brownout / under-voltage detection triggers safe shutdown
- [ ] Current limiting exists (hardware fuse or software limit)

## INFO (nice to have)

### 11. Code Quality
- [ ] Functions are single-purpose and testable
- [ ] Error handling exists (not just happy path)
- [ ] Logging sufficient for post-experiment debugging
- [ ] Configuration is external (yaml/json), not hardcoded

### 12. GUI Safety (if applicable)
- [ ] GUI thread never blocks on hardware communication
- [ ] Hardware commands sent via dedicated thread/queue, not UI thread
- [ ] Connection loss displayed clearly in UI (not silent failure)
- [ ] User confirmation required before destructive operations (motor enable, data delete)

### 13. Experiment Reproducibility
- [ ] All tunable parameters saved with data (gains, thresholds, modes)
- [ ] Firmware version or git hash logged at experiment start
- [ ] hardware.yaml committed in repo alongside experiment data
- [ ] Random seeds fixed and documented (if applicable)
ENDOFFILE

  # ── hardware.yaml.template ────────────────────────────────────────
  cat > "$SKIRO_DIR/hardware.yaml.template" << 'ENDOFFILE'
# Skiro Hardware Configuration Template
# ─────────────────────────────────────
# DO NOT fill this file manually!
# Run /skiro-hwtest → it will search datasheets online
# and auto-generate hardware.yaml for your project.
#
# Or copy this to hardware.yaml and fill manually if preferred.

project: ""         # Project name (e.g., "H-Walker", "Quadrotor", "6-DOF Arm")

# ── Motors / Actuators ──────────────────────────────────────────
motors: []
#  - name: ""              # Exact model (e.g., AK60-6, Dynamixel XM430-W350, Maxon EC-i 40)
#    interface: ""          # CAN / RS485 / Serial / PWM / EtherCAT / I2C
#    max_torque: 0          # Nm (continuous, from datasheet)
#    peak_torque: 0         # Nm (peak/stall, from datasheet)
#    max_velocity: 0        # rad/s (no-load)
#    gear_ratio: 0          # e.g., 6.0 for AK60-6
#    rated_voltage: 0       # V
#    rated_current: 0       # A (continuous)
#    encoder_resolution: 0  # counts per revolution
#    can_id: 0              # CAN bus ID (if applicable)
#    quantity: 1            # Number of this motor in the system
#    datasheet: ""          # URL to official datasheet

# ── Sensors ─────────────────────────────────────────────────────
sensors: []
#  - name: ""              # Exact model (e.g., MPU-6050, BNO055, LSB205, AMT102)
#    type: ""              # imu / loadcell / encoder / lidar / force_torque / pressure / temperature
#    interface: ""          # I2C / SPI / ADC / Serial / USB / Analog
#    sample_rate: 0         # Hz (max or configured)
#    range: ""              # Measurement range (e.g., "±16g", "0-500N", "±2000°/s")
#    resolution: ""         # Measurement resolution (e.g., "16-bit", "0.01N")
#    address: ""            # I2C address (e.g., "0x28"), SPI CS pin, or Serial port
#    quantity: 1
#    datasheet: ""

# ── Cameras ─────────────────────────────────────────────────────
cameras: []
#  - name: ""              # Exact model (e.g., ZED X Mini, RealSense D435i, OAK-D Lite)
#    interface: ""          # USB3 / GMSL2 / CSI / GigE / MIPI
#    resolution: ""         # e.g., "1920x1080", "640x480"
#    fps: 0                 # Max frame rate at above resolution
#    depth: false           # true if stereo/depth capable
#    compute: ""            # Companion compute (e.g., "Jetson Orin NX", "Raspberry Pi 5")
#    quantity: 1
#    datasheet: ""

# ── MCU / Compute ───────────────────────────────────────────────
mcu:
  name: ""                  # Exact model (e.g., Teensy 4.1, STM32H743, ESP32-S3, Arduino Mega)
  framework: ""             # arduino / stm32hal / esp-idf / micropython / zephyr / freertos
  build_tool: ""            # arduino-cli / platformio / cmake / idf.py / make
  upload_command: ""        # Full build+upload command (use {port} placeholder for serial port)
  clock_mhz: 0             # CPU clock frequency
  ram_kb: 0                 # SRAM size in KB
  flash_kb: 0              # Flash size in KB

# ── Communication ───────────────────────────────────────────────
communication:
  serial_baud: 0            # Primary serial baud rate
  can_baud: 0              # CAN bus baud rate (if applicable)
  wireless: ""              # BLE / WiFi / LoRa / ZigBee / none
  ros_version: ""           # ros1 / ros2 / none

# ── Safety Limits ───────────────────────────────────────────────
safety:
  max_force: 0              # N (software force limit)
  max_torque: 0             # Nm (software torque limit)
  max_velocity: 0           # rad/s or m/s (software velocity limit)
  watchdog_timeout: 100     # ms (communication timeout → auto-stop)
  control_loop_hz: 0        # Hz (main control loop frequency)
  e_stop_type: ""           # hardware / software / both

# ── Domain-Specific (optional) ──────────────────────────────────
# Add domain-specific sections as needed. Examples:
#
# gait:                     # For walking robots / exoskeletons
#   ho_angle_thresh: 0      # deg
#   hs_ratio: 0             # fraction
#   min_step_time: 0        # s
#   max_step_time: 0        # s
#
# flight:                   # For drones / UAVs
#   max_thrust: 0           # N (per motor)
#   battery_capacity: 0     # mAh
#   max_altitude: 0         # m
#
# manipulation:             # For robotic arms
#   workspace_radius: 0     # m
#   payload_capacity: 0     # kg
#   dof: 0                  # degrees of freedom
ENDOFFILE

  # ── LICENSE ───────────────────────────────────────────────────────
  cat > "$SKIRO_DIR/LICENSE" << 'ENDOFFILE'
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

  # ── README.md ─────────────────────────────────────────────────────
  cat > "$SKIRO_DIR/README.md" << 'ENDOFFILE'
<p align="center">
  <img src="https://img.shields.io/badge/skiro-v2.0.0-blue?style=for-the-badge" alt="version"/>
  <img src="https://img.shields.io/badge/platform-Win%20%7C%20Mac%20%7C%20Linux-green?style=for-the-badge" alt="platform"/>
  <img src="https://img.shields.io/badge/license-MIT-orange?style=for-the-badge" alt="license"/>
  <img src="https://img.shields.io/badge/Claude%20Code-compatible-blueviolet?style=for-the-badge" alt="claude"/>
  <img src="https://img.shields.io/badge/skills-9-brightgreen?style=for-the-badge" alt="skills"/>
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
- **Auto hardware.yaml** — Searches datasheets online and generates config
- **Experiment Pipeline** — Design -> Safety -> Test -> Flash -> Retro -> Paper
- **Session Handoff** — Continue where you left off
- **Cross-Platform** — Windows, macOS, Linux. No binary dependencies.
- **9 Specialized Skills** — Each focused on one phase of the pipeline

## Commands

| Command | What it does |
|---------|-------------|
| `/skiro-hwtest` | Hardware test + **auto hardware.yaml from datasheets** |
| `/skiro-safety` | Verify code: limits, watchdog, e-stop, timing |
| `/skiro-flash` | Build + upload firmware (safety gate) |
| `/skiro-spec` | Design experiment protocol |
| `/skiro-data` | Data collection, validation, organization |
| `/skiro-analyze` | Universal analysis: RMSE, FFT, stats, paper figures |
| `/skiro-gait` | Gait analysis: GCP, heel strike, cadence, symmetry |
| `/skiro-gui` | GUI development: layout, styling, real-time plots |
| `/skiro-retro` | Experiment retrospective + paper data |

## Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/chobyeongjun/skiro/main/setup-skiro.sh)
```

Or manual:
```bash
git clone https://github.com/chobyeongjun/skiro.git ~/.claude/skills/skiro
chmod +x ~/.claude/skills/skiro/bin/*
```

Windows:
```powershell
git clone https://github.com/chobyeongjun/skiro.git "$env:USERPROFILE\.claude\skills\skiro"
```

## Workflow

```
                   ┌── /skiro-gui (GUI work, anytime)
                   │
/skiro-hwtest ────→ /skiro-spec ──→ /skiro-safety ──→ /skiro-flash
(auto hardware.yaml)  (experiment)    (code verify)     (firmware)
                                                           │
                                                      [experiment]
                                                           │
                                    /skiro-data ──→ /skiro-analyze ──→ /skiro-retro
                                    (collect data)   (analysis)         (retrospective)
                                                        │
                                                   /skiro-gait
                                                   (gait-specific)
```

## Hardware Configuration

`/skiro-hwtest` auto-generates `hardware.yaml` by searching datasheets online.
Or copy `hardware.yaml.template` and fill manually:

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

  # ── .gitignore ────────────────────────────────────────────────────
  cat > "$SKIRO_DIR/.gitignore" << 'ENDOFFILE'
.DS_Store
Thumbs.db
.vscode/
.idea/
ENDOFFILE

  # ── bin/skiro-learnings ───────────────────────────────────────────
  cat > "$SKIRO_DIR/bin/skiro-learnings" << 'ENDOFFILE'
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

  # ── bin/skiro-session ─────────────────────────────────────────────
  cat > "$SKIRO_DIR/bin/skiro-session" << 'ENDOFFILE'
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

  # ── templates/session-handoff.md ──────────────────────────────────
  cat > "$SKIRO_DIR/templates/session-handoff.md" << 'ENDOFFILE'
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

  # ── references/datasheet-search.md ───────────────────────────────
  cat > "$SKIRO_DIR/references/datasheet-search.md" << 'ENDOFFILE'
# Datasheet Search Guide

How to find and extract hardware specifications from manufacturer datasheets.
Read this when auto-generating hardware.yaml in /skiro-hwtest.

## Search Strategy

1. **Search query pattern:** `"{exact model name}" datasheet specifications`
2. **Fallback:** `"{manufacturer} {model}" technical data`
3. **Verify source:** prefer manufacturer's official site over third-party resellers

## Motor / Actuator Specs to Extract

| Field | Where to find | Common units |
|-------|--------------|-------------|
| max_torque | "Continuous torque" or "Rated torque" | Nm |
| peak_torque | "Peak torque" or "Stall torque" | Nm |
| max_velocity | "No-load speed" or "Max speed" | rad/s (convert from RPM: RPM × π/30) |
| gear_ratio | "Gear ratio" or "Reduction" | dimensionless |
| rated_voltage | "Nominal voltage" | V |
| rated_current | "Continuous current" or "Rated current" | A |
| interface | "Communication" or "Protocol" | CAN / RS485 / PWM / etc. |

### Common Motor Manufacturers

| Manufacturer | URL pattern | Notes |
|-------------|-------------|-------|
| T-Motor | store.tmotor.com | AK series (AK60-6, AK80-9, etc.) — CAN protocol |
| Robotis (Dynamixel) | emanual.robotis.com | XM/XH/XW series — RS485/TTL |
| Maxon | maxongroup.com | EC/RE series — look for "technical data" PDF |
| Oriental Motor | orientalmotor.com | Stepper/servo — look for "specifications" tab |
| Faulhaber | faulhaber.com | Brushless DC — "technical data" section |

### Unit Conversion Reference
- RPM → rad/s: multiply by π/30 (≈ 0.10472)
- oz-in → Nm: multiply by 0.00706
- lb-ft → Nm: multiply by 1.3558
- mNm → Nm: divide by 1000

## Sensor Specs to Extract

| Field | Where to find | Common units |
|-------|--------------|-------------|
| sample_rate | "Output data rate" or "ODR" or "Bandwidth" | Hz |
| range | "Full-scale range" or "Measurement range" | varies (g, °/s, N, Pa) |
| resolution | "Resolution" or "Sensitivity" or "ADC bits" | bits or physical units |
| interface | "Digital interface" or "Communication" | I2C / SPI / UART / Analog |

### Common Sensor Manufacturers

| Manufacturer | Products | Notes |
|-------------|----------|-------|
| InvenSense (TDK) | MPU-6050, ICM-42688 | IMU — check "Product Specification" PDF |
| Bosch | BNO055, BMI270, BMP390 | IMU/Pressure — "BST datasheet" |
| STMicroelectronics | LSM6DSO, LIS3DH | IMU/Accel — search st.com |
| TE Connectivity | Load cells (FX1901, FC22) | Force — "product datasheet" |
| CUI Devices | AMT102, AMT103 | Encoder — "datasheet" tab |
| Honeywell | FSS series, TBP series | Force/Pressure sensors |

## Camera Specs to Extract

| Field | Where to find |
|-------|--------------|
| resolution | "Image resolution" or "Output resolution" |
| fps | "Frame rate" at the target resolution |
| depth | "Stereo" or "Depth sensing" or "3D" capability |
| interface | "Connectivity" (USB3, GMSL2, CSI, GigE) |

### Common Robot Camera Manufacturers

| Manufacturer | Products |
|-------------|----------|
| Stereolabs | ZED 2, ZED X, ZED X Mini — stereolabs.com/docs |
| Intel RealSense | D435i, D455, L515 — intelrealsense.com |
| Luxonis | OAK-D, OAK-D Lite — docs.luxonis.com |
| FLIR / Teledyne | Blackfly, Chameleon — flir.com |

## MCU Specs to Extract

| Field | Where to find |
|-------|--------------|
| clock_mhz | "CPU frequency" or "Clock speed" |
| ram_kb | "SRAM" or "RAM" |
| flash_kb | "Flash memory" or "Program memory" |
| framework | Depends: Arduino-compatible? STM32HAL? ESP-IDF? |
| build_tool | arduino-cli / platformio / cmake / idf.py |

### Common MCU Platforms

| Platform | Build tool | Framework | Spec page |
|----------|-----------|-----------|-----------|
| Teensy 4.x | arduino-cli (teensy addon) | arduino | pjrc.com/teensy/teensy41.html |
| STM32 (Nucleo, Discovery) | platformio / cmake | stm32hal / arduino |
| ESP32 | idf.py / platformio | esp-idf / arduino |
| Arduino Mega/Due | arduino-cli | arduino |
| Raspberry Pi Pico | cmake / platformio | pico-sdk / micropython |

## Verification Checklist

After extracting specs, verify:
- [ ] Units are correct and consistent (all torque in Nm, all speed in rad/s)
- [ ] Values match between multiple sources (cross-reference 2+ sources)
- [ ] Continuous vs peak ratings are distinguished (don't mix them)
- [ ] Interface protocol matches what's actually wired (not just what's possible)
- [ ] Voltage/current ratings are compatible with the power supply
ENDOFFILE

  # ── references/gui-layout-rules.md ───────────────────────────────
  cat > "$SKIRO_DIR/references/gui-layout-rules.md" << 'ENDOFFILE'
# GUI Layout Rules

Rules for building and modifying robot GUI interfaces.
Read this when working on GUI layout, styling, or natural language UI requests.

## Natural Language → Layout Command Mapping

When a user describes a visual change in natural language, map it to a structured action:

### Position / Movement
| User says | Action | Implementation |
|-----------|--------|---------------|
| "move X left/right/up/down" | Reorder widget in layout | Change `addWidget()` order or `grid` row/col |
| "put X next to Y" | Horizontal layout | `QHBoxLayout` / `Row` / `display: flex` |
| "put X below Y" | Vertical layout | `QVBoxLayout` / `Column` / `flex-direction: column` |
| "swap X and Y" | Reorder | Swap widget positions in layout code |
| "center X" | Alignment | `setAlignment(Qt.AlignCenter)` / `justify-content: center` |

### Size / Space
| User says | Action | Implementation |
|-----------|--------|---------------|
| "make X bigger/smaller" | Resize | Adjust `minimumSize` / `maximumSize` / stretch factor |
| "X is too wide/narrow" | Width constraint | `setFixedWidth()` / `setMinimumWidth()` / `max-width` |
| "more space between X and Y" | Spacing | `layout.setSpacing()` / `margin` / `gap` |
| "X is cramped" | Increase padding | Add `setContentsMargins()` / `padding` |
| "make sidebar narrower" | Width reduction | Reduce `setFixedWidth()` or stretch ratio |

### Visibility / Interaction
| User says | Action | Implementation |
|-----------|--------|---------------|
| "make X collapsible" | Toggle visibility | Add collapse button + `setVisible(bool)` |
| "hide X" | Remove from view | `widget.hide()` or remove from layout |
| "X should scroll" | Add scroll area | Wrap in `QScrollArea` / `overflow: auto` |
| "X should be draggable" | Drag support | `QSplitter` for resizable, `eventFilter` for drag |

### Overlap / Responsive Issues
| User says | Action | Implementation |
|-----------|--------|---------------|
| "X and Y overlap" | Fix overlap | Set `minimumSize`, use proper layout manager |
| "breaks on small window" | Responsive fix | Set `minimumSize` on window, add `QScrollArea` |
| "need full screen" | Remove min constraints | Check for hardcoded sizes, use stretch instead |
| "too much empty space" | Fill space | Add stretch factors, use `Expanding` size policy |

### Styling / Theming
| User says | Action | Implementation |
|-----------|--------|---------------|
| "dark theme" / "어두운 테마" | Apply dark palette | `QPalette` + `Fusion` style or global QSS |
| "gradient buttons" | Gradient stylesheet | `qlineargradient` in QSS |
| "color change" / "색 바꿔줘" | Modify palette/stylesheet | Update color dict or CSS variables |
| "transparent" / "반투명" | Opacity/glassmorphism | `rgba()` background + `backdrop-filter: blur` |
| "font bigger" / "글씨 크게" | Font size increase | Update stylesheet font-size |

### Korean Natural Language Patterns (한국어)
| 표현 | 의미 | 매핑 |
|------|------|------|
| "붙여줘" / "갖다 붙여" | Place adjacent | LAYOUT [A,B] adjacent |
| "딱 맞게" | Fit exactly | SIZE target=X fit=exact |
| "여백 좀 줘" | Add padding/margin | SPACE target=X increase |
| "접어줘" / "펼쳐줘" | Collapse/expand | TOGGLE target=X |
| "탭으로 나눠줘" | Split into tabs | CONVERT target=X to=QTabWidget |
| "창 두 개로" | Split into panels | ADD QSplitter |
| "위에 놓아줘" | Place above | MOVE target=X dir=UP |
| "옆에 놓아줘" | Place beside | LAYOUT [A,B] dir=HORIZ |
| "너무 좁아" | Too narrow | RESIZE target=X wider |
| "잘려" / "짤려" | Content clipped | FIX overflow → QScrollArea |

## Framework-Specific Layout Patterns

### PyQt5 / PyQt6 / PySide
```python
# Prevent overlap: ALWAYS set minimum sizes
widget.setMinimumSize(200, 100)

# Use stretch for proportional layouts
layout.addWidget(sidebar, stretch=1)
layout.addWidget(main_area, stretch=3)  # 3:1 ratio

# Responsive: use QSplitter instead of fixed widths
splitter = QSplitter(Qt.Horizontal)
splitter.addWidget(sidebar)
splitter.addWidget(main)
splitter.setSizes([250, 750])  # initial, but user-resizable

# Size policies
widget.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
```

### Tkinter
```python
# Use grid with weight for responsive layouts
root.columnconfigure(0, weight=1, minsize=200)
root.columnconfigure(1, weight=3, minsize=400)

# Pack with fill and expand
frame.pack(fill=tk.BOTH, expand=True)
```

### Web (HTML/CSS)
```css
/* Use flexbox with min-width to prevent overlap */
.container { display: flex; gap: 8px; }
.sidebar { flex: 0 0 250px; min-width: 200px; }
.main { flex: 1; min-width: 400px; }

/* Responsive: wrap on small screens */
@media (max-width: 768px) {
  .container { flex-direction: column; }
}
```

### Flutter
```dart
// Use Expanded with flex for proportional layouts
Row(children: [
  Expanded(flex: 1, child: Sidebar()),
  Expanded(flex: 3, child: MainArea()),
])

// Responsive: use LayoutBuilder
LayoutBuilder(builder: (context, constraints) {
  if (constraints.maxWidth < 600) return MobileLayout();
  return DesktopLayout();
})
```

## Overlap Prevention Checklist

Before delivering any GUI change, verify:

- [ ] **No hardcoded absolute positions** — use layout managers, not `setGeometry()` or `place()`
- [ ] **minimumSize set** on all major panels (sidebar, main area, toolbar)
- [ ] **Window minimumSize set** — prevent window from shrinking past usable size
- [ ] **Stretch factors assigned** — at least one widget should expand to fill space
- [ ] **QScrollArea for overflow** — if content can exceed container, wrap it
- [ ] **Test at 1024×768** — this is the minimum "reasonable" desktop size
- [ ] **Test at 800×600** — if required to work on small displays
- [ ] **No fixed-width containers** unless intentional (toolbars, status bars)
- [ ] **Splitter for user-adjustable** panels (sidebar vs main area)
- [ ] **Text truncation handled** — `elideMode` or wrap, not overflow

## Design Consistency Checklist

Borrowed from design-review best practices:

### Spacing Rhythm
- Use a base unit (4px or 8px) and only use multiples of it
- Consistent margins: inner content → 12-16px, between sections → 24-32px
- Do not mix arbitrary pixel values

### Color
- All colors from a defined palette (dict, CSS variables, theme)
- No hardcoded hex values scattered in code
- Sufficient contrast: text on dark bg ≥ 4.5:1 (WCAG AA)

### Typography
- Maximum 2 font families
- Consistent hierarchy: heading → subheading → body → caption
- Body text ≥ 12px (desktop), ≥ 14px (touch/tablet)

### AI Slop Anti-Patterns (avoid these)
- Purple/blue gradients everywhere
- Uniform rounded corners on everything
- Drop shadows on every element
- Overuse of blur/glassmorphism without purpose
- Generic icon sets with no meaning
- 3-column symmetric card grids
- Gratuitous animation on every interaction
ENDOFFILE

  # ── references/data-formats.md ────────────────────────────────────
  cat > "$SKIRO_DIR/references/data-formats.md" << 'ENDOFFILE'
# Robot Data Formats Guide

Reference for parsing, validating, and managing robot experiment data.
Read this when working with /skiro-data.

## CSV Data

### Auto-Detection
1. Read first line → if contains letters, it's a header
2. Detect delimiter: try comma, tab, semicolon, space (in order)
3. Count columns in header vs first data row — must match
4. Detect time column: look for "time", "timestamp", "t", "Time_ms" (case-insensitive)

### Common Column Naming Patterns
| Pattern | Meaning | Example |
|---------|---------|---------|
| `Des` or `Desired` | Setpoint/command | L_DesForce_N |
| `Act` or `Actual` | Measured value | L_ActForce_N |
| `Err` or `Error` | Tracking error | L_ErrForce_N |
| `_N` suffix | Force in Newtons | L_ActForce_N |
| `_Nm` suffix | Torque in Newton-meters | L_Torque_Nm |
| `_deg` suffix | Angle in degrees | L_ActPos_deg |
| `_rad` suffix | Angle in radians | Joint1_rad |
| `_mps` suffix | Velocity in m/s | L_ActVel_mps |
| `_A` suffix | Current in Amperes | L_ActCurr_A |
| `_Hz` suffix | Frequency | Freq_Hz |
| `L_` / `R_` prefix | Left / Right side | L_GCP, R_GCP |
| `_x` / `_y` / `_z` suffix | Axis | Accel_x, Accel_y |

### Validation Rules
| Check | Condition | Severity |
|-------|-----------|----------|
| NaN/Inf | Any column has NaN or Inf | WARNING |
| Timestamp gap | Gap > 5× expected period | WARNING |
| Sample rate drift | mean period ± 10% | WARNING |
| Stuck sensor | Same value for > 100 consecutive samples | WARNING |
| Range violation | Value outside sensor range (from hardware.yaml) | WARNING |
| Missing columns | Expected column not found | ERROR |
| Empty file | No data rows | ERROR |
| Corrupted row | Column count mismatch | ERROR |

### Sample Rate Estimation
```python
# From timestamp column (assuming milliseconds)
dt = np.diff(time_ms)
estimated_hz = 1000.0 / np.median(dt)
# Use median, not mean (robust to gaps)
```

## ROS Bag Data

### ROS 2 (mcap / db3)
```bash
# List topics
ros2 bag info <bag_path>

# Extract to CSV
ros2 bag play <bag_path> --read-ahead-queue-size 1000
# Or use rosbag2 Python API:
# from rosbags.rosbag2 import Reader
# from rosbags.typesys import get_typestore
```

### ROS 1 (legacy .bag)
```bash
# List topics
rosbag info file.bag

# Extract specific topic to CSV
rostopic echo -b file.bag -p /imu/data > imu_data.csv
```

### Common ROS Topics for Robots
| Topic pattern | Message type | Contains |
|--------------|-------------|----------|
| `/imu/data` | sensor_msgs/Imu | orientation, angular_vel, linear_accel |
| `/joint_states` | sensor_msgs/JointState | position, velocity, effort |
| `/cmd_vel` | geometry_msgs/Twist | linear, angular velocity command |
| `/odom` | nav_msgs/Odometry | pose, twist |
| `/force_torque` | geometry_msgs/WrenchStamped | force xyz, torque xyz |
| `/camera/image_raw` | sensor_msgs/Image | raw image |
| `/tf` | tf2_msgs/TFMessage | transforms |

## HDF5 Data

### Structure Exploration
```python
import h5py
with h5py.File('data.h5', 'r') as f:
    def print_tree(name, obj):
        print(name, type(obj).__name__, getattr(obj, 'shape', ''))
    f.visititems(print_tree)
```

### Common HDF5 Layouts for Robot Data
- Flat: `/time`, `/force`, `/position` (each a 1D or 2D array)
- Grouped: `/experiment/trial_01/force`, `/experiment/trial_01/imu`
- Timestamped: `/2024-01-15/trial_1/data`

## Serial Data Capture

### Basic Pattern (pyserial)
```python
import serial
ser = serial.Serial(port, baudrate, timeout=1)
# Read line-by-line for text protocols
line = ser.readline().decode('ascii', errors='ignore').strip()
# Read bytes for binary protocols
data = ser.read(packet_size)
```

### Common Embedded Serial Protocols
| Pattern | Example | Detection |
|---------|---------|-----------|
| CSV-like | `123.4,567.8,901.2\n` | Lines with commas/tabs + numbers |
| Custom prefix | `SW19c<d0>n<d1>n...` | Fixed prefix + delimiter-separated values |
| Binary packed | `0xAA 0x55 [payload] [checksum]` | Header bytes + fixed length |
| JSON | `{"force": 12.3, "pos": 45.6}\n` | Lines starting with `{` |
| Protobuf | Binary, schema required | Known message type |

## File Naming Convention

Recommended: `YYMMDD_SubjectID_Condition_Trial.{ext}`

Examples:
- `260402_S01_AssistON_T1.csv`
- `260402_S01_AssistOFF_T1.csv`
- `260402_S01_Baseline_T1.bag`

### Directory Structure
```
data/
├── raw/              # Original files (NEVER modify)
│   ├── 260402_S01/
│   └── 260402_S02/
├── processed/        # Cleaned, filtered, synchronized
│   ├── 260402_S01/
│   └── 260402_S02/
└── analysis/         # Figures, tables, statistics
    ├── figures/
    └── tables/
```

## Integrity Report Format

After validation, produce a summary like:
```
=== Data Integrity Report ===
File: 260402_S01_AssistON_T1.csv
Columns: 81 (all present)
Rows: 125,000
Duration: 1125.0 s (18.75 min)
Sample rate: 111.1 ± 0.3 Hz
NaN count: 0
Timestamp gaps (>50ms): 2 at rows [45123, 89001]
Range violations: R_ActForce_N exceeded 300N at rows [12045-12048]
Overall: PASS (2 warnings)
```
ENDOFFILE

  # ── references/analysis-methods.md ───────────────────────────────
  cat > "$SKIRO_DIR/references/analysis-methods.md" << 'ENDOFFILE'
# Robot Data Analysis Methods

Reference for computing control metrics, statistical tests, and paper-ready outputs.
Read this when working with /skiro-analyze or /skiro-gait.

## Control Performance Metrics

### Tracking Error
```python
error = desired - actual
rmse = np.sqrt(np.mean(error**2))
max_error = np.max(np.abs(error))
mean_abs_error = np.mean(np.abs(error))
```

### Settling Time
```python
# Time for response to stay within ±band% of final value
final_value = actual[-100:].mean()  # last 100 samples as steady state
band = 0.02  # 2% band
within_band = np.abs(actual - final_value) < band * abs(final_value)
# Find last time it exits the band
settling_idx = np.where(~within_band)[0][-1] + 1 if np.any(~within_band) else 0
settling_time = time[settling_idx] - time[0]
```

### Bandwidth (-3dB)
```python
from scipy import signal
# Compute frequency response from input/output
f, Pxy = signal.csd(desired, actual, fs=sample_rate, nperseg=1024)
f, Pxx = signal.welch(desired, fs=sample_rate, nperseg=1024)
H = Pxy / Pxx  # Transfer function estimate
H_mag_db = 20 * np.log10(np.abs(H))
# Find -3dB crossing
ref_db = np.max(H_mag_db[:5])  # low-frequency reference (avoid DC bin artifacts)
bandwidth_idx = np.where(H_mag_db < ref_db - 3)[0]
bandwidth_hz = f[bandwidth_idx[0]] if len(bandwidth_idx) > 0 else f[-1]
```

## Frequency Analysis

### FFT
```python
from scipy.fft import fft, fftfreq
N = len(signal_data)
yf = fft(signal_data - np.mean(signal_data))  # remove DC
xf = fftfreq(N, 1/sample_rate)[:N//2]
magnitude = 2.0/N * np.abs(yf[:N//2])
```

### Power Spectral Density (PSD)
```python
from scipy.signal import welch
f, Pxx = welch(signal_data, fs=sample_rate, nperseg=min(1024, len(signal_data)//4))
```

### Bode Plot
```python
# If you have input (command) and output (response)
f, Pxy = signal.csd(input_sig, output_sig, fs=fs, nperseg=1024)
f, Pxx = signal.welch(input_sig, fs=fs, nperseg=1024)
H = Pxy / Pxx
mag_db = 20 * np.log10(np.abs(H))
phase_deg = np.angle(H, deg=True)
```

## Trajectory Analysis

### Smoothness (Jerk Metric)
```python
# Lower jerk = smoother motion
velocity = np.gradient(position, time)
acceleration = np.gradient(velocity, time)
jerk = np.gradient(acceleration, time)
smoothness = -np.log(np.trapz(jerk**2, time) * (duration**3 / path_length**2))
# Log Dimensionless Jerk (Balasubramanian et al., 2012). Note: duration^3, NOT ^5.
```

### Work and Energy
```python
# Work = integral of force × displacement
work = np.trapz(force, displacement)  # Joules if N and m

# Hysteresis = area inside force-displacement loop
# (positive work - negative work)
```

## Statistical Tests

### Decision Tree
```
Is data normally distributed?
├── YES → Are groups paired/matched?
│   ├── YES → Paired t-test (2 groups) / Repeated-measures ANOVA (3+)
│   └── NO  → Independent t-test (2 groups) / One-way ANOVA (3+)
└── NO  → Are groups paired/matched?
    ├── YES → Wilcoxon signed-rank (2) / Friedman (3+)
    └── NO  → Mann-Whitney U (2) / Kruskal-Wallis (3+)
```

### Normality Test
```python
from scipy.stats import shapiro
stat, p = shapiro(data)
is_normal = p > 0.05
```

### Common Tests
```python
from scipy import stats

# Paired t-test (before/after, same subjects)
t, p = stats.ttest_rel(condition_a, condition_b)

# Independent t-test (different groups)
t, p = stats.ttest_ind(group_a, group_b)

# Wilcoxon signed-rank (non-parametric paired)
w, p = stats.wilcoxon(condition_a, condition_b)

# Mann-Whitney U (non-parametric independent)
u, p = stats.mannwhitneyu(group_a, group_b)

# One-way ANOVA
f, p = stats.f_oneway(group_a, group_b, group_c)
```

### Effect Size
```python
# Cohen's d (paired)
diff = condition_a - condition_b
d = np.mean(diff) / np.std(diff, ddof=1)
# Interpretation: 0.2 small, 0.5 medium, 0.8 large

# Cohen's d (independent)
pooled_std = np.sqrt(((n1-1)*s1**2 + (n2-1)*s2**2) / (n1+n2-2))
d = (mean1 - mean2) / pooled_std

# Eta-squared (for ANOVA)
eta_sq = ss_between / ss_total
```

## Paper-Ready Output

### Matplotlib Academic Style
```python
import matplotlib.pyplot as plt
import matplotlib

# IEEE / academic paper style
plt.rcParams.update({
    'font.family': 'serif',
    'font.serif': ['Times New Roman', 'DejaVu Serif'],
    'font.size': 10,
    'axes.labelsize': 11,
    'axes.titlesize': 11,
    'legend.fontsize': 9,
    'xtick.labelsize': 9,
    'ytick.labelsize': 9,
    'figure.figsize': (3.5, 2.5),      # single column
    # 'figure.figsize': (7.16, 3.5),   # double column
    'figure.dpi': 300,
    'savefig.dpi': 300,
    'savefig.bbox': 'tight',
    'lines.linewidth': 1.0,
    'axes.linewidth': 0.5,
    'grid.linewidth': 0.3,
    'axes.grid': True,
    'grid.alpha': 0.3,
})
```

### LaTeX Table Template (IEEE)
```latex
\begin{table}[t]
\caption{Comparison of Gait Parameters}
\label{tab:gait_params}
\centering
\begin{tabular}{lcc}
\hline
Parameter & Assist ON & Assist OFF \\
\hline
Stride Time (s) & $1.12 \pm 0.08$ & $1.18 \pm 0.11$ \\
Cadence (steps/min) & $107.1 \pm 7.6$ & $101.7 \pm 9.4$ \\
Stance (\%) & $62.3 \pm 2.1$ & $63.8 \pm 2.5$ \\
\hline
\multicolumn{3}{l}{\footnotesize Values: mean $\pm$ SD. * $p < 0.05$}
\end{tabular}
\end{table}
```

### LaTeX Table Template (JNER)
```latex
\begin{table*}[t]
\caption{Temporal-spatial gait parameters}
\begin{tabular}{lccccc}
\toprule
& \multicolumn{2}{c}{Assist ON} & \multicolumn{2}{c}{Assist OFF} & \\
\cmidrule(lr){2-3} \cmidrule(lr){4-5}
Parameter & Mean & SD & Mean & SD & $p$-value \\
\midrule
Stride time (s) & 1.12 & 0.08 & 1.18 & 0.11 & 0.023* \\
\bottomrule
\end{tabular}
\end{table*}
```

### Figure Descriptions for Papers
When generating figures, always include:
1. **Title** — what the figure shows
2. **Axes labels** — with units in parentheses, e.g., "Force (N)", "Time (s)"
3. **Legend** — if multiple series
4. **Statistical annotations** — significance markers (*, **, ***) with brackets
5. **Caption text** — brief description suitable for the paper

### Significance Markers
| p-value | Marker |
|---------|--------|
| p < 0.05 | * |
| p < 0.01 | ** |
| p < 0.001 | *** |
| p ≥ 0.05 | ns |
ENDOFFILE

  # ── skiro-safety/SKILL.md ─────────────────────────────────────────
  cat > "$SKIRO_DIR/skiro-safety/SKILL.md" << 'ENDOFFILE'
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

  # ── skiro-hwtest/SKILL.md ─────────────────────────────────────────
  cat > "$SKIRO_DIR/skiro-hwtest/SKILL.md" << 'ENDOFFILE'
---
name: skiro-hwtest
description: |
  Generate and run hardware test scripts for motors, sensors, cameras,
  communication buses. Auto-generates hardware.yaml by searching official
  datasheets online — users just name their hardware, skiro finds the specs.
  Keywords: hardware test, motor test, sensor test, calibration, wiring,
  connection test, hardware.yaml, datasheet, setup, configure. (skiro)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - WebSearch
  - WebFetch
  - AskUserQuestion
---

Read VOICE.md before responding.

## Phase 0: Hardware Discovery + Auto-Config

### Step 0a: Check for existing hardware.yaml
```bash
ls hardware.yaml 2>/dev/null && echo "EXISTS" || echo "MISSING"
```
- EXISTS → load it, proceed to Phase 1 (Test Plan)
- MISSING → start auto-generation workflow below ↓

### Step 0a-1: Load prior learnings FIRST (VOICE.md requires this)
```bash
chmod +x ~/.claude/skills/skiro/bin/skiro-learnings 2>/dev/null || true
~/.claude/skills/skiro/bin/skiro-learnings search "hardware" 2>/dev/null || true
~/.claude/skills/skiro/bin/skiro-learnings search "test" 2>/dev/null || true
```

### Step 0b: Gather hardware information
If the user ALREADY named specific hardware in their request (e.g., "AK60-6 모터 2개"),
skip asking and proceed directly to Step 0c with that information.

Only if hardware is not specified:
AskUserQuestion:
"What hardware does your project use? List motors, sensors, MCU, cameras — model names are ideal but brand names work too."
(Free text. Examples: "AK60-6 motors x2, BNO055 IMU, Teensy 4.1", "Dynamixel servos and Arduino Mega")

### Step 0c: Specificity gate (unchanged — this is critical)
Vague names get challenged. Never proceed with vague hardware names.
- "ZED" → "ZED 2, ZED X, or ZED X Mini? The specs differ significantly."
- "IMU" → "MPU-6050, BNO055, ICM-42688? Each has different ranges and sample rates."
- "motor" → "Which model? AK60-6, Dynamixel XM430, Maxon EC-i 40?"
- "Arduino" → "Arduino Uno, Mega, Due, Nano? Flash/RAM differ."

### Step 0d: Search datasheets and extract specs
Read `references/datasheet-search.md` for search patterns and extraction rules.

For EACH hardware component:
1. WebSearch: `"{exact model name}" datasheet specifications`
2. WebFetch the top result (prefer manufacturer's official page)
3. Extract the specific fields listed in hardware.yaml.template
4. Record the datasheet URL

Cross-reference at least 2 sources when possible. If specs conflict, show both
and ask the user which is correct.

**Multiple instances of the same model** (e.g., "AK60-6 x2"):
- Search specs ONCE (same model = same specs)
- Create SEPARATE entries in hardware.yaml with unique IDs
  (e.g., different CAN IDs for motors, different I2C addresses for sensors)
- Ask user for the specific IDs if not obvious

### Step 0e: Generate hardware.yaml draft
Write the complete hardware.yaml with all extracted specs.
Show it to the user:

AskUserQuestion:
"Here's the hardware.yaml I generated from datasheets. Please verify:"
[show yaml content]
A) Looks correct — save it
B) Some values need correction (tell me which)
C) Search again for a component

### Step 0f: Save hardware.yaml
Write confirmed hardware.yaml to project root.
Log this as a learning: "hardware.yaml generated for {project}".

Load learnings for "test" and "hardware" tags.

---

## Phase 1: Test Plan
Generate test list based on hardware.yaml.
AskUserQuestion: "Which tests?"
A) All components
B) Select specific ones
C) Just motors
D) Just sensors
E) Just communication

## Phase 2: Generate Test Scripts
Standalone scripts in `tests/hardware/test_{component}.py`

Safety rules:
- Motor tests: max 50% rated torque (from hardware.yaml `max_torque`)
- Voltage/current: never exceed rated values
- Camera tests: no motor movement required
- Communication tests: read-only first, write only with confirmation

Each test script must:
- Import only standard libraries + the minimum driver needed
- Print clear PASS/FAIL with measured values and expected ranges
- Have a timeout (default 5s per test)
- Be runnable standalone: `python tests/hardware/test_motor.py`

## Phase 3: Run Tests (with permission)
AskUserQuestion before running on real hardware:
"Ready to run tests on real hardware. Confirm?"
A) Run all selected tests
B) Run one at a time (with confirmation between each)
C) Just generate scripts, I'll run manually

## Phase 4: Results + Learnings
Report PASS/FAIL for each test with:
- Measured value vs expected range
- file:line reference for the test
FAIL items → log learning automatically via skiro-learnings add.

## Phase 5: Next Step
All PASS → /skiro-safety then /skiro-flash
FAIL → fix hardware, re-run /skiro-hwtest
ENDOFFILE

  # ── skiro-flash/SKILL.md ──────────────────────────────────────────
  cat > "$SKIRO_DIR/skiro-flash/SKILL.md" << 'ENDOFFILE'
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

  # ── skiro-spec/SKILL.md ───────────────────────────────────────────
  cat > "$SKIRO_DIR/skiro-spec/SKILL.md" << 'ENDOFFILE'
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

  # ── skiro-retro/SKILL.md ──────────────────────────────────────────
  cat > "$SKIRO_DIR/skiro-retro/SKILL.md" << 'ENDOFFILE'
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

  # ── skiro-gui/SKILL.md ────────────────────────────────────────────
  cat > "$SKIRO_DIR/skiro-gui/SKILL.md" << 'ENDOFFILE'
---
name: skiro-gui
description: |
  Robot GUI development assistant. Handles layout, styling, and interaction
  for any GUI framework: PyQt5/6, PySide, Tkinter, Kivy, Dear ImGui, Flutter,
  or web dashboards. Understands natural language layout instructions like
  "move this left", "make this bigger", "put a chart here", "these two overlap".
  Detects layout overlap and responsive issues. Enforces design consistency
  (spacing rhythm, color palette, typography hierarchy).
  Use when building or modifying robot control interfaces, data dashboards,
  experiment UIs, or any desktop/embedded GUI. Also use when the user describes
  visual changes in natural language or complains about overlapping widgets.
  Keywords: GUI, UI, layout, widget, plot, style, design, PyQt, Tkinter,
  dashboard, button, panel, tab, sidebar, responsive, overlap, move, resize,
  bigger, smaller, collapsible, dark theme, glassmorphism. (skiro)
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

## Phase 0: Context

1. Detect GUI framework:
   ```bash
   grep -rl "PyQt5\|PyQt6\|PySide\|tkinter\|Tkinter\|kivy\|imgui\|flutter\|React\|Vue" . --include="*.py" --include="*.dart" --include="*.js" --include="*.ts" 2>/dev/null | head -5
   ```
2. Find existing design system files:
   - `styles.py`, `theme.py`, `colors.py`, `constants.py` (Python GUI)
   - `DESIGN.md` (if exists)
   - `.css`, `.scss`, `tailwind.config` (web)
   - `theme.dart` (Flutter)
3. Load learnings for "gui", "layout", "design" tags.
4. Read `references/gui-layout-rules.md` for framework-specific patterns.

## Phase 1: Understand the Request

### Natural Language Interpretation
The user often describes UI changes in casual language. Map their words to actions:

**Position words** → layout reorder:
- "move X left/right" → change widget order in horizontal layout
- "put X above/below Y" → change vertical order
- "swap these two" → exchange positions

**Size words** → resize:
- "bigger/smaller" → adjust minimumSize, stretch, or fixed dimensions
- "too wide/narrow/tall/short" → constrain the offending dimension
- "cramped" → increase padding/margins
- "too much empty space" → reduce margins or add stretch

**Overlap complaints** → layout fix:
- "X and Y overlap" → check for missing layout manager or fixed positioning
- "breaks on small window" → add minimumSize to window + QScrollArea
- "need fullscreen" → check for unnecessary size constraints

**Feature requests** → widget modification:
- "make X collapsible" → add toggle button + setVisible()
- "add scrollbar to X" → wrap in scroll container
- "drag to resize X" → use QSplitter or equivalent

If the request is ambiguous:
AskUserQuestion: "Which widget are you referring to? Can you describe where it is on screen?"

## Phase 2: Layout Analysis

Before making changes, analyze current state:

1. **Widget hierarchy**: trace the parent→child tree from the target widget to the window
2. **Layout manager type**: QHBoxLayout/QVBoxLayout/QGridLayout/QFormLayout or none
3. **Size constraints**: check for `setFixedSize`, `setMinimumSize`, `setMaximumSize`
4. **Size policies**: `QSizePolicy.Expanding` vs `Fixed` vs `Preferred`
5. **Stretch factors**: `layout.addWidget(w, stretch=N)`
6. **Splitters**: any `QSplitter` for user-resizable areas?

Report findings concisely: "sidebar is 280px fixed width in QHBoxLayout, main area has stretch=1"

## Phase 3: Apply Changes

Follow framework-specific patterns from `references/gui-layout-rules.md`.

### Universal Rules (all frameworks):
- **Never use absolute positioning** for main layout — use layout managers
- **Always set minimumSize** on major panels (prevents overlap)
- **Use stretch/flex** for proportional layouts, not fixed pixels
- **Add QScrollArea/overflow:auto** when content might exceed container
- **QSplitter** for user-adjustable panel boundaries
- **Test at 1024×768** mentally — will it still work?

### PyQt5/6 Specific:
```python
# Good: proportional with minimum
splitter = QSplitter(Qt.Horizontal)
sidebar.setMinimumWidth(200)
sidebar.setMaximumWidth(400)
main.setMinimumWidth(500)
splitter.addWidget(sidebar)
splitter.addWidget(main)
splitter.setStretchFactor(0, 1)   # sidebar: flex 1
splitter.setStretchFactor(1, 3)   # main: flex 3

# Bad: fixed pixels
sidebar.setFixedWidth(280)  # breaks on small screens
```

### Common Fixes:
| Problem | Fix |
|---------|-----|
| Widgets overlap on resize | Add `minimumSize` to both, use layout manager |
| Content cut off | Wrap in `QScrollArea` |
| Sidebar too dominant | Reduce stretch factor or add `maximumWidth` |
| Everything squished | Check parent has `Expanding` policy |
| Can't resize panels | Replace fixed layout with `QSplitter` |
| Panel collapses to 0px | `splitter.setCollapsible(index, False)` |
| Need collapsible panel | Toggle button + `widget.setVisible(bool)` + parent `layout.update()` |

### Collapsible Panel Pattern (PyQt5):
```python
# Toggle button in toolbar/sidebar
self.toggle_btn = QPushButton("◀")
self.toggle_btn.setFixedWidth(24)
self.toggle_btn.clicked.connect(self._toggle_panel)

def _toggle_panel(self):
    visible = not self.panel.isVisible()
    self.panel.setVisible(visible)
    self.toggle_btn.setText("▶" if not visible else "◀")
```

### Dark Theme Pattern (PyQt5):
```python
# Option A: QPalette (lightweight, no external deps)
app.setStyle("Fusion")
palette = QPalette()
palette.setColor(QPalette.Window, QColor(13, 13, 15))        # background
palette.setColor(QPalette.WindowText, QColor(220, 220, 220))  # text
palette.setColor(QPalette.Base, QColor(26, 26, 36))           # input bg
palette.setColor(QPalette.Button, QColor(34, 34, 58))         # button bg
palette.setColor(QPalette.Highlight, QColor(76, 158, 255))    # selection
app.setPalette(palette)

# Option B: Global stylesheet (more control, heavier)
app.setStyleSheet(open("styles.qss").read())
```

### Gradient Button Pattern (PyQt5):
```python
btn.setStyleSheet("""
    QPushButton {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
            stop:0 #4C9EFF, stop:1 #2DD4BF);
        color: white; border: none; border-radius: 6px; padding: 8px 16px;
    }
    QPushButton:pressed { background: #3A7BD5; }
""")
```

## Phase 4: Design Consistency Check

After layout changes, verify design consistency:

### Spacing Rhythm
- All margins/paddings should be multiples of a base unit (4px or 8px)
- Flag inconsistent spacing: "margin: 13px" → suggest "margin: 12px (3×4)"

### Color Consistency
- All colors should come from a defined palette/dict
- Flag hardcoded hex values: `color="#3a7bd5"` → should reference palette

### Typography
- Max 2 font families in the entire app
- Consistent size hierarchy: title > heading > body > caption

### Overuse Warnings (not banned — flag only when excessive)
These are valid design choices, but overuse creates "AI slop" feeling:
- Drop shadow on EVERY widget → use only on elevated cards/modals
- Animation on EVERY interaction → reserve for state transitions
- Gradient on EVERY button → use for primary actions only, flat for secondary
- Inconsistent border-radius → pick 2-3 values and stick to them
- Color-only status indicators → always add text/icon for accessibility
**If the user explicitly requests these styles, apply them without objection.**

## Phase 4B: Real-Time Plot Integration

When adding live data plots to a GUI, use `pyqtgraph` (not matplotlib). matplotlib is for static figures; pyqtgraph is designed for real-time updates.

### PyQtGraph Real-Time Plot Pattern:
```python
import pyqtgraph as pg
from PyQt5.QtCore import QTimer
import numpy as np
from collections import deque

class RealtimePlotWidget(pg.PlotWidget):
    """Efficient real-time plot with ring buffer."""
    def __init__(self, max_points=2000, update_ms=33, parent=None):
        super().__init__(parent=parent)
        self.max_points = max_points
        self.data_x = deque(maxlen=max_points)
        self.data_y = deque(maxlen=max_points)
        self.curve = self.plot(pen=pg.mkPen("#4C9EFF", width=2))

        # Anti-aliasing off for performance
        self.setAntialiasing(False)
        self.setDownsampling(auto=True, mode="peak")
        self.setClipToView(True)

        # Timer-driven update (not data-driven!)
        self._timer = QTimer()
        self._timer.timeout.connect(self._update_plot)
        self._timer.start(update_ms)  # ~30 FPS

    def add_point(self, x, y):
        """Thread-safe: call from data thread."""
        self.data_x.append(x)
        self.data_y.append(y)

    def _update_plot(self):
        """Called by QTimer on GUI thread only."""
        if self.data_x:
            self.curve.setData(list(self.data_x), list(self.data_y))
```

### Collapsible Panel + Plot Timing Issue:
When toggling a collapsible panel that contains a plot, `canvas.draw()` can be called before the layout recalculates, causing size mismatch.

**Problem:**
```python
# BAD: draw before layout settles
def _toggle_panel(self):
    self.panel.setVisible(not self.panel.isVisible())
    self.plot_widget.update()  # ← size is still old
```

**Fix:**
```python
# GOOD: defer draw to next event loop cycle
from PyQt5.QtCore import QTimer

def _toggle_panel(self):
    visible = not self.panel.isVisible()
    self.panel.setVisible(visible)
    self.toggle_btn.setText("▶" if not visible else "◀")
    # Defer plot resize to after layout recalculation
    QTimer.singleShot(0, self._resize_plots)

def _resize_plots(self):
    """Called after layout has settled."""
    for plot in self.findChildren(pg.PlotWidget):
        plot.getViewBox().autoRange()
```

### Multi-Channel Plot Panel:
```python
class MultiChannelPlot(QWidget):
    """Stacked real-time plots with shared X-axis."""
    def __init__(self, channels: list[str], parent=None):
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(2)

        self.plots = {}
        prev_plot = None
        for ch_name in channels:
            pw = RealtimePlotWidget(parent=self)
            pw.setLabel("left", ch_name)
            pw.setMinimumHeight(80)
            if prev_plot:
                pw.setXLink(prev_plot)  # Shared X-axis zoom/pan
                pw.hideAxis("bottom")   # Only show X on last plot
            self.plots[ch_name] = pw
            layout.addWidget(pw)
            prev_plot = pw

        # Show X-axis only on last plot
        if channels:
            self.plots[channels[-1]].showAxis("bottom")
            self.plots[channels[-1]].setLabel("bottom", "Time (s)")

# Usage:
# multi = MultiChannelPlot(["Force_N", "Position_deg", "Current_A"])
# multi.plots["Force_N"].add_point(t, force_value)
```

### Performance Guidelines:
| Scenario | Approach |
|----------|----------|
| < 1000 Hz data | Direct QTimer update at 30 FPS |
| 1000-10000 Hz | Downsample in add_point (keep every Nth) |
| > 10000 Hz | Ring buffer + decimation in update |
| Multiple plots | Shared QTimer, batch updates |
| Plot in QTabWidget | Pause timer when tab not visible |

## Phase 5: Verification

Ask user to verify:
"Please resize the window to a small size and check if everything is still visible. Any overlap or cutoff?"

If issues found → iterate from Phase 2.

## Phase 6: Learn + Next Step

Log any layout fixes as learnings.
If this was part of a larger workflow:
- Building new UI → continue coding
- Pre-experiment check → /skiro-safety
ENDOFFILE

  # ── skiro-data/SKILL.md ───────────────────────────────────────────
  cat > "$SKIRO_DIR/skiro-data/SKILL.md" << 'ENDOFFILE'
---
name: skiro-data
description: |
  Robot data collection and management pipeline. Handles data download from
  embedded storage (SD card, flash), serial data capture, data validation,
  format conversion, and backup. Supports CSV, ROS bag, HDF5, binary logs.
  Verifies data integrity: timestamps, NaN, gaps, sample rate, sensor range.
  Use when collecting experiment data, downloading from robot, validating
  datasets, organizing files, or converting between formats.
  Keywords: data, CSV, SD card, download, log, logging, export, column,
  ROS bag, HDF5, serial, backup, integrity, sample rate, timestamp,
  validate, organize, convert, NaN, gap, missing data. (skiro)
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

1. Read hardware.yaml for MCU, sensors, sample rates, interfaces.
   No hardware.yaml: proceed, but warn "Run /skiro-hwtest first for full validation."
2. Detect data format: scan target directory for file extensions.
   ```bash
   ls *.csv *.bag *.db3 *.h5 *.hdf5 *.bin *.dat 2>/dev/null | head -20
   ```
3. Load learnings for "data", "csv", "download" tags.
4. Read `references/data-formats.md` for format-specific parsing patterns.

## Phase 1: Data Source

AskUserQuestion: "Where is your data coming from?"
A) SD card on MCU (download via USB Serial)
B) Local files already on disk
C) ROS bag recording
D) Live serial capture
E) Other (describe)

## Phase 2: Data Collection

### A) SD Card Download
1. Check if logging is active (if MCU firmware supports query).
   If active: "Stop logging before downloading to prevent corruption."
2. **Determine serial protocol first:**
   - Check project firmware code for SD transfer commands (grep for "LIST", "GET", "ls", "cat")
   - If found: use project's protocol
   - If not found: AskUserQuestion "What serial commands does your firmware use for SD file transfer? (e.g., `ls`, `get <filename>`, or XModem?)"
3. Detect serial port:
   ```bash
   ls /dev/tty.usb* /dev/cu.usb* /dev/ttyACM* /dev/ttyUSB* 2>/dev/null
   ```
4. List files on SD using the detected protocol.
5. AskUserQuestion: "Which files to download?" [show file list]
6. Download via pyserial — handle EOF/end-of-transfer markers.
7. Verify: file size matches expected, basic parse check.

### B) Local Files
1. List files in specified directory.
2. Detect format from extension and content.
3. Proceed directly to Phase 3 (validation).

### C) ROS Bag
1. Detect bag format:
   ```bash
   # ROS 2 (SQLite3-based .db3)
   file *.db3 2>/dev/null
   # ROS 1 (.bag)
   file *.bag 2>/dev/null
   ```
2. Get bag info and extract to CSV using rosbags library.
3. AskUserQuestion: "Which topics to extract?" [show topic list]
4. After extraction: auto-proceed to Phase 3 (integrity validation).

### D) Serial Capture
1. Detect serial port: `ls /dev/tty* | grep -i "usb\|acm\|teensy"`
2. Confirm baud rate (from hardware.yaml or ask).
3. Start capture → file.
4. AskUserQuestion: "Recording... Press enter to stop."

## Phase 3: Data Integrity Validation

Run these checks on every data file. Report as a table.

| Check | Method | Severity |
|-------|--------|----------|
| Header present | First row contains non-numeric text | ERROR if missing |
| Column count consistent | All rows same column count | ERROR if mismatch |
| NaN/Inf detection | `np.isnan` or string "nan" per column | WARNING, report % |
| Timestamp continuity | `diff(time)` > 5× median(diff) | WARNING, report gaps |
| Sample rate consistency | `1/median(diff(time))` ± 10% | WARNING |
| Stuck sensor | Same value > 100 consecutive samples | WARNING |
| Range violation | Value outside sensor spec (from hardware.yaml) | WARNING |
| File not empty | At least 10 data rows | ERROR |
| Time reversal | time[i+1] < time[i] (timer overflow) | ERROR |
| File truncation | Last row has fewer columns than header | WARNING |
| Encoding error | Non-UTF8 bytes or BOM present | WARNING |
| Duplicate timestamps | time[i] == time[i+1] | WARNING |

Format output as integrity report.

## Phase 4: File Organization

Suggest naming convention: `YYMMDD_SubjectID_Condition_Trial.{ext}`

AskUserQuestion: "Want me to rename and organize these files?"
A) Yes, auto-organize
B) Just suggest, I'll do it manually
C) Skip

## Phase 5: Summary + Next Step

Log any data issues as learnings via skiro-learnings add.

Next step suggestions:
- Data looks clean → /skiro-analyze or /skiro-gait
- Data has issues → fix and re-validate
- Need more data → plan next experiment with /skiro-spec
ENDOFFILE

  # ── skiro-analyze/SKILL.md ────────────────────────────────────────
  cat > "$SKIRO_DIR/skiro-analyze/SKILL.md" << 'ENDOFFILE'
---
name: skiro-analyze
description: |
  Universal robot data analysis. Computes control performance metrics
  (tracking error, RMSE, bandwidth), trajectory analysis, force-displacement
  curves, frequency response (FFT, PSD, Bode), and statistical comparison
  between experimental conditions. Generates paper-ready matplotlib figures
  and LaTeX tables (IEEE, JNER format). Works with any CSV, ROS bag, or HDF5
  robot data. Use when analyzing experiment results, computing metrics,
  comparing conditions, or preparing figures and tables for papers.
  Keywords: analyze, trajectory, force, torque, RMSE, tracking error,
  bandwidth, frequency, FFT, PSD, statistics, t-test, ANOVA, comparison,
  figure, plot, matplotlib, LaTeX, paper, table, effect size. (skiro)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
  - WebSearch
---

Read VOICE.md before responding.

## Phase 0: Context

1. Read hardware.yaml for sensor specs, control frequencies, safety limits.
2. Scan for data files:
   ```bash
   find . -name "*.csv" -o -name "*.bag" -o -name "*.h5" 2>/dev/null | head -20
   ```
3. Load learnings for "analysis", "statistics", "figure" tags.
4. Read `references/analysis-methods.md` for formulas and templates.

## Phase 1: Analysis Goal

AskUserQuestion: "What do you want to analyze?"
A) Control performance (tracking error, RMSE, bandwidth)
B) Trajectory analysis (path, velocity, acceleration, smoothness)
C) Force / torque analysis (profile, peak, work, hysteresis)
D) Frequency analysis (FFT, PSD, Bode plot)
E) Compare conditions (A vs B statistical comparison)
F) Custom analysis (describe what you need)

## Phase 2: Data Loading + Column Mapping

1. Load the data file(s).
2. Auto-detect column meanings from names.
3. Auto-detect time column.
4. Show mapping to user for confirmation.

## Phase 3: Compute Metrics

Based on selected analysis type (RMSE, trajectory, force, frequency, or condition comparison).
Use formulas from `references/analysis-methods.md`.

## Phase 4: Visualization + Paper Output

Generate matplotlib scripts following academic style.
IEEE single-column: 3.5" wide. Double-column: 7.16" wide.
DPI: 300. All axes labeled with units.

## Phase 5: Summary + Next Step

Log analysis decisions as learnings.
Next: /skiro-gait for gait-specific or /skiro-retro for experiment retrospective.
ENDOFFILE

  # ── skiro-gait/SKILL.md ───────────────────────────────────────────
  cat > "$SKIRO_DIR/skiro-gait/SKILL.md" << 'ENDOFFILE'
---
name: skiro-gait
description: |
  Gait analysis for walking robots and exoskeletons. Extends /skiro-analyze
  with gait-specific capabilities: gait cycle percentage (GCP) calculation,
  heel strike (HS) and heel off (HO) event detection, temporal-spatial
  parameters (stride time, cadence, stance/swing ratio, double support),
  gait cycle normalization of force/position/angle profiles, and symmetry
  analysis. Supports IMU-based, force-based, and camera-based gait detection.
  Generates paper-ready gait parameter tables and normalized profile figures.
  Keywords: gait, GCP, heel strike, heel off, stride, cadence, stance, swing,
  step time, gait cycle, walking, exoskeleton, treadmill, overground,
  symmetry index, double support, gait speed, normalization. (skiro)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
  - WebSearch
---

Read VOICE.md before responding.

This skill extends /skiro-analyze. For general metrics (RMSE, FFT, condition
comparison, LaTeX tables), use /skiro-analyze directly. This skill adds
gait-specific event detection and temporal-spatial parameter computation.

## Phase 0: Context

1. Read hardware.yaml — look for `gait:` section.
   If present: load thresholds (HS ratio, HO angle, step time limits).
   If absent: ask for detection method below.
2. Load learnings for "gait", "stride", "hs", "ho" tags.

AskUserQuestion: "How is gait detected in your system?"
A) IMU-based (shank/foot angle + angular velocity)
B) Force sensor / loadcell (vertical force threshold)
C) Foot switches / pressure sensors
D) Camera-based (pose estimation keypoints)
E) GCP is already computed (column in CSV)
F) Not sure — help me choose

## Phase 1: Data Loading + Column Mapping

Search for gait-related columns: GCP, L_GCP, R_GCP, Pitch, Roll, Gyro, Force, StepTime, HO_GCP.
Auto-estimate sample rate from timestamp column.

## Phase 2: Gait Event Detection

### A) IMU-Based Detection
Heel Off (HO): Pitch ≥ HO_angle_threshold (default: 2.5°) AND angular velocity ≥ 40°/s.
Heel Strike (HS): gyro drops below swing_peak × HS_ratio (default: 0.08).
Apply low-pass filter (Butterworth 2nd order, 20Hz cutoff) before detection.

### B) Force-Based Detection
Heel Strike: force crosses upward through threshold (10-20% body weight).
Heel Off: force crosses downward through threshold.

### C) Foot Switch
Contact ON → stance start. Contact OFF → swing start.

### D) Camera-Based
Heel keypoint velocity reversal → HS. Toe-off keypoint → HO.

### E) Pre-Computed
Use existing GCP column. Detect HS as GCP reset (prev > 0.8, current < 0.2).

## Phase 3: Temporal-Spatial Parameters

Stride Time, Step Time, Cadence, Stance %, Swing %, Double Support %, Gait Speed.

Symmetry Index: SI = |Left - Right| / (0.5 × (Left + Right)) × 100
SI < 10% = symmetric, 10-15% = mild asymmetry, >15% = significant asymmetry.

Quality filtering: reject strides outside 0.2–3.0s, reject first 2 strides.

## Phase 4: Gait Cycle Normalization

Normalize each stride to 0–100% of gait cycle (101 points).
Compute mean ± SD across all valid strides.

## Phase 5: Statistical Analysis + Paper Output

Use /skiro-analyze patterns. Generate gait-specific figures:
GCP-normalized profile, temporal-spatial bar chart, symmetry radar chart.

BibTeX suggestions: Salarian et al. (IMU), Winter (force), Robinson et al. 1987 (symmetry index).

## Phase 6: Summary + Next Step

Log gait-specific findings as learnings.
Next: /skiro-retro for full experiment retrospective.
ENDOFFILE

  # ── evals/*.json ──────────────────────────────────────────────────
  # (Eval files for trigger testing — abbreviated versions for the installer)

  cat > "$SKIRO_DIR/evals/skiro.json" << 'ENDOFFILE'
[
  {"query": "로봇 팔에 AK60 모터 달아서 impedance control 하려는데 세팅 도와줘", "should_trigger": true},
  {"query": "Teensy 4.1에서 CAN 통신으로 모터 제어하는 코드 작성해줘", "should_trigger": true},
  {"query": "exoskeleton 실험 프로토콜 작성해야 해", "should_trigger": true},
  {"query": "IMU 데이터 분석해서 gait cycle 구해줘", "should_trigger": true},
  {"query": "모터 토크 제한이 안 걸려있는 것 같아, 안전 검증해줘", "should_trigger": true},
  {"query": "hardware.yaml 만들어줘, T-Motor AK60-6 사용해", "should_trigger": true},
  {"query": "SD 카드에서 실험 데이터 다운받아서 정리해줘", "should_trigger": true},
  {"query": "보행 보조 로봇 GUI 만들어줘, PyQt5로", "should_trigger": true},
  {"query": "PID 게인 튜닝 결과 RMSE 비교해줘", "should_trigger": true},
  {"query": "펌웨어 컴파일하고 보드에 업로드해줘", "should_trigger": true},
  {"query": "React로 로그인 페이지 만들어줘", "should_trigger": false},
  {"query": "Python pandas로 주식 데이터 분석해줘", "should_trigger": false},
  {"query": "Docker 컨테이너 설정 도와줘", "should_trigger": false},
  {"query": "Next.js 프로젝트 초기 세팅해줘", "should_trigger": false},
  {"query": "SQL 쿼리 최적화해줘", "should_trigger": false},
  {"query": "Git merge conflict 해결해줘", "should_trigger": false},
  {"query": "AWS Lambda 함수 배포해줘", "should_trigger": false},
  {"query": "이 논문 요약해줘", "should_trigger": false},
  {"query": "TypeScript interface 타입 정의해줘", "should_trigger": false},
  {"query": "CI/CD 파이프라인 만들어줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-trigger-eval.json" << 'ENDOFFILE'
[
  {"query": "로봇 코드 도와줘. 모터 제어 관련이야", "should_trigger": true},
  {"query": "임피던스 제어 구현해줘", "should_trigger": true},
  {"query": "CAN 통신 코드 작성해줘. AK60 모터용", "should_trigger": true},
  {"query": "센서 데이터 읽는 코드 짜줘. IMU 가속도계", "should_trigger": true},
  {"query": "PID 제어기 튜닝 도와줘", "should_trigger": true},
  {"query": "엑소스켈레톤 프로젝트 시작해야 해. 전체적인 구조 잡아줘", "should_trigger": true},
  {"query": "로봇 실험 준비해야 해. 뭐부터 하면 될까", "should_trigger": true},
  {"query": "Teensy 코드에서 제어 루프 최적화해줘", "should_trigger": true},
  {"query": "force sensor 값이 이상해. 디버깅 도와줘", "should_trigger": true},
  {"query": "admittance control 구현하려는데 어떤 접근이 좋을까", "should_trigger": true},
  {"query": "React 컴포넌트 만들어줘", "should_trigger": false},
  {"query": "SQL 쿼리 최적화해줘", "should_trigger": false},
  {"query": "Docker compose 설정 도와줘", "should_trigger": false},
  {"query": "Python Flask API 만들어줘", "should_trigger": false},
  {"query": "Git merge conflict 해결해줘", "should_trigger": false},
  {"query": "TypeScript 타입 에러 고쳐줘", "should_trigger": false},
  {"query": "AWS Lambda 함수 배포해줘", "should_trigger": false},
  {"query": "데이터베이스 스키마 설계해줘", "should_trigger": false},
  {"query": "CI/CD 파이프라인 구성해줘", "should_trigger": false},
  {"query": "Next.js 페이지 라우팅 설정해줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-safety.json" << 'ENDOFFILE'
[
  {"query": "모터 토크 제한 코드 확인해줘, 안전한지 검증해", "should_trigger": true},
  {"query": "e-stop 로직이 제대로 동작하는지 봐줘", "should_trigger": true},
  {"query": "watchdog timer가 제대로 설정되어 있는지 확인해줘", "should_trigger": true},
  {"query": "force limit이 50N으로 설정되어 있는지 검증해줘", "should_trigger": true},
  {"query": "state machine에서 비정상 전환이 없는지 확인해줘", "should_trigger": true},
  {"query": "CAN 통신 타임아웃 처리가 안전한지 봐줘", "should_trigger": true},
  {"query": "actuator limit이 하드웨어 스펙 범위 안에 있는지 확인", "should_trigger": true},
  {"query": "비상 정지 시 모터가 즉시 꺼지는지 검증해줘", "should_trigger": true},
  {"query": "제어 루프 주기가 안전 기준 안에 있는지 확인해줘", "should_trigger": true},
  {"query": "실험 전에 코드 안전성 점검해줘", "should_trigger": true},
  {"query": "모터 PID 게인 튜닝해줘", "should_trigger": false},
  {"query": "CSV 데이터에서 RMSE 구해줘", "should_trigger": false},
  {"query": "GUI에 비상 정지 버튼 추가해줘", "should_trigger": false},
  {"query": "보행 분석에서 stride time 구해줘", "should_trigger": false},
  {"query": "펌웨어 보드에 업로드해줘", "should_trigger": false},
  {"query": "실험 프로토콜 작성해줘", "should_trigger": false},
  {"query": "SD 카드 데이터 다운로드해줘", "should_trigger": false},
  {"query": "hardware.yaml 자동 생성해줘", "should_trigger": false},
  {"query": "실험 retrospective 작성해줘", "should_trigger": false},
  {"query": "matplotlib으로 force-displacement 그래프 그려줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-safety-trigger-eval.json" << 'ENDOFFILE'
[
  {"query": "이 코드에서 force limit 확인해줘. AK60 모터 최대 토크가 넘는지 체크해야 해", "should_trigger": true},
  {"query": "watchdog timer가 제대로 동작하는지 검증해줘", "should_trigger": true},
  {"query": "e-stop 로직 리뷰해줘. 비상정지 시 모든 액추에이터가 즉시 멈추는지 확인", "should_trigger": true},
  {"query": "제어 루프 타이밍 안전성 점검해줘. 1kHz 루프인데 deadline miss가 있을 수 있어", "should_trigger": true},
  {"query": "CAN 통신에서 타임아웃 처리가 안 되어 있는 것 같아. 안전 코드 리뷰 부탁", "should_trigger": true},
  {"query": "state machine에서 FAULT 상태로 전환되는 조건이 빠져있는 것 같아", "should_trigger": true},
  {"query": "모터 전류 제한이 소프트웨어에서 제대로 설정되어 있는지 확인해줘", "should_trigger": true},
  {"query": "safety check 돌려줘. 내일 실험 전에 코드 검증 필요해", "should_trigger": true},
  {"query": "이 로봇 코드 안전한지 봐줘. 특히 max torque 설정이 걱정돼", "should_trigger": true},
  {"query": "emergency stop이 눌렸을 때 모터 드라이버 disable 되는지 확인해줘", "should_trigger": true},
  {"query": "Teensy에 펌웨어 업로드해줘", "should_trigger": false},
  {"query": "실험 프로토콜 작성해줘. 보행 실험이야", "should_trigger": false},
  {"query": "CSV 데이터에서 NaN 체크해줘", "should_trigger": false},
  {"query": "PyQt5로 모터 제어 GUI 만들어줘", "should_trigger": false},
  {"query": "RMSE 계산해줘. tracking error 분석이야", "should_trigger": false},
  {"query": "하드웨어 테스트 스크립트 만들어줘. IMU 센서 동작 확인용", "should_trigger": false},
  {"query": "실험 끝났어. 뭐가 잘못됐는지 정리해줘", "should_trigger": false},
  {"query": "gait cycle percentage 계산해줘", "should_trigger": false},
  {"query": "SD카드에서 데이터 다운로드해야 해", "should_trigger": false},
  {"query": "PID 게인 튜닝 도와줘. Kp=10, Ki=0.1로 시작하려고", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-hwtest.json" << 'ENDOFFILE'
[
  {"query": "AK60-6 모터 테스트 코드 만들어줘", "should_trigger": true},
  {"query": "hardware.yaml 자동 생성해줘, Dynamixel XM430 사용해", "should_trigger": true},
  {"query": "IMU 센서 연결 테스트해줘", "should_trigger": true},
  {"query": "CAN 통신 연결 확인 스크립트 만들어줘", "should_trigger": true},
  {"query": "새 프로젝트 세팅이야, 하드웨어 구성 잡아줘", "should_trigger": true},
  {"query": "로드셀 캘리브레이션 코드 작성해줘", "should_trigger": true},
  {"query": "모터 datasheet 찾아서 스펙 정리해줘", "should_trigger": true},
  {"query": "엔코더 분해능 테스트해줘", "should_trigger": true},
  {"query": "I2C 센서 배선 확인하고 테스트 코드 만들어줘", "should_trigger": true},
  {"query": "새로운 모터 장착했는데 하드웨어 설정 도와줘", "should_trigger": true},
  {"query": "토크 제한 안전 검증해줘", "should_trigger": false},
  {"query": "펌웨어 컴파일하고 업로드해줘", "should_trigger": false},
  {"query": "실험 데이터 분석해줘", "should_trigger": false},
  {"query": "보행 분석 GCP 구해줘", "should_trigger": false},
  {"query": "실험 프로토콜 작성해줘", "should_trigger": false},
  {"query": "GUI 레이아웃 수정해줘", "should_trigger": false},
  {"query": "데이터 CSV로 변환해줘", "should_trigger": false},
  {"query": "실험 retrospective 정리해줘", "should_trigger": false},
  {"query": "RMSE 계산해서 표로 만들어줘", "should_trigger": false},
  {"query": "모터 PID 제어 코드 최적화해줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-hwtest-trigger-eval.json" << 'ENDOFFILE'
[
  {"query": "AK60-6 모터 테스트 스크립트 만들어줘. CAN으로 연결되어 있어", "should_trigger": true},
  {"query": "hardware.yaml 자동 생성해줘. T-Motor AK60-6이랑 Bosch BNO055 IMU 쓰고 있어", "should_trigger": true},
  {"query": "IMU 센서 캘리브레이션 테스트 해야 해", "should_trigger": true},
  {"query": "모터 연결 확인용 테스트 코드 짜줘. 아직 배선이 맞는지 모르겠어", "should_trigger": true},
  {"query": "Dynamixel XM430 데이터시트에서 스펙 찾아서 hardware.yaml에 넣어줘", "should_trigger": true},
  {"query": "새로운 센서 붙였는데 제대로 값 나오는지 테스트해야 해. I2C 로드셀이야", "should_trigger": true},
  {"query": "CAN bus 통신 테스트 스크립트 필요해. 모터 3개 동시에 읽어야 해", "should_trigger": true},
  {"query": "하드웨어 셋업 처음부터 해야 해. 어떤 순서로 테스트하면 될까", "should_trigger": true},
  {"query": "엔코더 분해능 테스트해줘. 1회전에 몇 카운트 나오는지 확인", "should_trigger": true},
  {"query": "모터 datasheet 검색해줘. Maxon EC-i 40 스펙 찾아야 해", "should_trigger": true},
  {"query": "safety check 돌려줘. force limit 확인해야 해", "should_trigger": false},
  {"query": "펌웨어 빌드하고 Teensy에 올려줘", "should_trigger": false},
  {"query": "실험 데이터 분석해줘. RMSE 계산 필요해", "should_trigger": false},
  {"query": "GUI에서 모터 상태 표시하는 위젯 만들어줘", "should_trigger": false},
  {"query": "보행 실험 프로토콜 설계해줘", "should_trigger": false},
  {"query": "SD카드에서 CSV 파일 내려받아줘", "should_trigger": false},
  {"query": "gait cycle 정규화해줘", "should_trigger": false},
  {"query": "지난 실험 retrospective 해줘", "should_trigger": false},
  {"query": "matplotlib으로 force-displacement 그래프 그려줘", "should_trigger": false},
  {"query": "watchdog timer 구현 검증해줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-flash.json" << 'ENDOFFILE'
[
  {"query": "Teensy에 펌웨어 업로드해줘", "should_trigger": true},
  {"query": "Arduino 코드 컴파일하고 보드에 올려줘", "should_trigger": true},
  {"query": "STM32에 firmware flash해줘", "should_trigger": true},
  {"query": "빌드하고 MCU에 deploy해줘", "should_trigger": true},
  {"query": "코드 수정했으니까 보드에 다시 burn해줘", "should_trigger": true},
  {"query": "ESP32에 프로그램 올려줘", "should_trigger": true},
  {"query": "펌웨어 빌드 에러 수정하고 다시 업로드해줘", "should_trigger": true},
  {"query": "platformio로 빌드하고 플래시해줘", "should_trigger": true},
  {"query": "Teensy Loader CLI로 hex 파일 업로드해줘", "should_trigger": true},
  {"query": "수정한 코드 MCU에 프로그래밍해줘", "should_trigger": true},
  {"query": "모터 안전 검증해줘", "should_trigger": false},
  {"query": "하드웨어 테스트 코드 만들어줘", "should_trigger": false},
  {"query": "실험 데이터 분석해줘", "should_trigger": false},
  {"query": "GUI 만들어줘", "should_trigger": false},
  {"query": "실험 프로토콜 설계해줘", "should_trigger": false},
  {"query": "CSV 데이터 검증해줘", "should_trigger": false},
  {"query": "보행 분석해줘", "should_trigger": false},
  {"query": "Docker 이미지 빌드하고 배포해줘", "should_trigger": false},
  {"query": "Python 코드 실행해줘", "should_trigger": false},
  {"query": "Git push해줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-flash-trigger-eval.json" << 'ENDOFFILE'
[
  {"query": "Teensy 4.1에 펌웨어 업로드해줘", "should_trigger": true},
  {"query": "코드 빌드하고 플래시해줘. Arduino CLI 사용해", "should_trigger": true},
  {"query": "STM32에 firmware burn 해야 해", "should_trigger": true},
  {"query": "MCU 프로그래밍 해줘. 컴파일 후 바로 업로드", "should_trigger": true},
  {"query": "flash 해줘. Teensy에 올려야 해", "should_trigger": true},
  {"query": "ESP32에 코드 deploy 해줘", "should_trigger": true},
  {"query": "firmware upload 해줘. 수정한 코드를 MCU에 넣어야 해", "should_trigger": true},
  {"query": "빌드하고 보드에 올려줘", "should_trigger": true},
  {"query": "Arduino Mega에 스케치 업로드해줘", "should_trigger": true},
  {"query": "platformio로 빌드해서 Teensy에 플래시해줘", "should_trigger": true},
  {"query": "모터 테스트 스크립트 만들어줘", "should_trigger": false},
  {"query": "safety check 돌려줘", "should_trigger": false},
  {"query": "실험 프로토콜 설계해줘", "should_trigger": false},
  {"query": "CSV 데이터 검증해줘", "should_trigger": false},
  {"query": "GUI 레이아웃 수정해줘", "should_trigger": false},
  {"query": "이 펌웨어 코드에서 버그 찾아줘", "should_trigger": false},
  {"query": "임베디드 C 코드 리팩토링해줘", "should_trigger": false},
  {"query": "Teensy에서 시리얼 데이터 캡처해줘", "should_trigger": false},
  {"query": "CAN 통신 프로토콜 구현해줘", "should_trigger": false},
  {"query": "RMSE 분석해줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-spec.json" << 'ENDOFFILE'
[
  {"query": "impedance control 실험 프로토콜 설계해줘", "should_trigger": true},
  {"query": "실험 조건 3가지로 나눠서 test plan 만들어줘", "should_trigger": true},
  {"query": "데이터 수집 계획 세워줘, 어떤 변수를 기록할지", "should_trigger": true},
  {"query": "보행 실험 프로토콜 작성해줘", "should_trigger": true},
  {"query": "통계 분석을 위한 sample size 계산해줘", "should_trigger": true},
  {"query": "실험 설계에서 독립변수와 종속변수 정리해줘", "should_trigger": true},
  {"query": "반복 횟수랑 랜덤화 방법 정해줘", "should_trigger": true},
  {"query": "안전 기준 포함해서 실험 계획 세워줘", "should_trigger": true},
  {"query": "피험자 동의서 포함된 실험 protocol 만들어줘", "should_trigger": true},
  {"query": "실험 조건별 데이터 수집 변수 정의해줘", "should_trigger": true},
  {"query": "실험 데이터 RMSE 분석해줘", "should_trigger": false},
  {"query": "실험 retrospective 작성해줘", "should_trigger": false},
  {"query": "모터 안전 검증해줘", "should_trigger": false},
  {"query": "하드웨어 테스트해줘", "should_trigger": false},
  {"query": "펌웨어 업로드해줘", "should_trigger": false},
  {"query": "GUI 만들어줘", "should_trigger": false},
  {"query": "CSV 데이터 변환해줘", "should_trigger": false},
  {"query": "보행 cycle에서 heel strike 검출해줘", "should_trigger": false},
  {"query": "matplotlib 그래프 스타일 수정해줘", "should_trigger": false},
  {"query": "논문 표 LaTeX로 만들어줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-spec-trigger-eval.json" << 'ENDOFFILE'
[
  {"query": "보행 실험 프로토콜 설계해줘. 5명 피험자, 3가지 조건", "should_trigger": true},
  {"query": "실험 계획서 작성해줘. 독립변수 종속변수 정리 필요해", "should_trigger": true},
  {"query": "test plan 만들어줘. 임피던스 제어 비교 실험이야", "should_trigger": true},
  {"query": "실험 설계 도와줘. 몇 명이 필요한지 통계적 파워 계산도 해줘", "should_trigger": true},
  {"query": "data collection plan 세워줘. 어떤 센서에서 뭘 수집할지 정리", "should_trigger": true},
  {"query": "실험 프로토콜 짜줘. 트레드밀 vs 지상보행 비교야", "should_trigger": true},
  {"query": "experiment design 해줘. 조건 간 순서 효과 어떻게 통제하지?", "should_trigger": true},
  {"query": "IRB 제출용 실험 절차서 초안 작성해줘", "should_trigger": true},
  {"query": "within-subject 디자인으로 실험 설계해줘. counterbalancing 포함", "should_trigger": true},
  {"query": "실험 조건별 샘플 사이즈 계산해줘. effect size 0.5 기준", "should_trigger": true},
  {"query": "실험 끝났어. 결과 분석해줘", "should_trigger": false},
  {"query": "safety check 해줘", "should_trigger": false},
  {"query": "데이터 다운로드해줘", "should_trigger": false},
  {"query": "펌웨어 올려줘", "should_trigger": false},
  {"query": "GUI 만들어줘", "should_trigger": false},
  {"query": "retrospective 해줘. 뭐가 잘못됐는지 정리", "should_trigger": false},
  {"query": "RMSE 계산해줘", "should_trigger": false},
  {"query": "gait cycle percentage 분석해줘", "should_trigger": false},
  {"query": "하드웨어 테스트 돌려줘", "should_trigger": false},
  {"query": "matplotlib으로 그래프 그려줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-retro.json" << 'ENDOFFILE'
[
  {"query": "오늘 실험 결과 정리하고 retrospective 작성해줘", "should_trigger": true},
  {"query": "실험에서 뭐가 잘못됐는지 분석해줘", "should_trigger": true},
  {"query": "lessons learned 정리해줘", "should_trigger": true},
  {"query": "실험 결과를 논문 데이터 형식으로 정리해줘", "should_trigger": true},
  {"query": "이번 실험 세션 요약해줘", "should_trigger": true},
  {"query": "what went wrong 분석해줘", "should_trigger": true},
  {"query": "실험 결과 paper data로 정리해줘", "should_trigger": true},
  {"query": "retro 작성해줘, 이번 실험 문제점 위주로", "should_trigger": true},
  {"query": "실험 교훈 정리해서 learnings에 저장해줘", "should_trigger": true},
  {"query": "지난 실험 대비 개선점 분석해줘", "should_trigger": true},
  {"query": "실험 프로토콜 설계해줘", "should_trigger": false},
  {"query": "데이터 FFT 분석해줘", "should_trigger": false},
  {"query": "보행 분석 GCP 구해줘", "should_trigger": false},
  {"query": "모터 안전 검증해줘", "should_trigger": false},
  {"query": "하드웨어 테스트해줘", "should_trigger": false},
  {"query": "GUI 레이아웃 수정해줘", "should_trigger": false},
  {"query": "펌웨어 업로드해줘", "should_trigger": false},
  {"query": "CSV 데이터 다운로드해줘", "should_trigger": false},
  {"query": "weekly standup 정리해줘", "should_trigger": false},
  {"query": "코드 리뷰해줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-retro-trigger-eval.json" << 'ENDOFFILE'
[
  {"query": "지난 실험 retrospective 해줘. 뭐가 잘못됐는지 정리하고 싶어", "should_trigger": true},
  {"query": "실험 끝났는데 결과가 이상해. lessons learned 정리해줘", "should_trigger": true},
  {"query": "what went wrong 분석해줘. 모터가 중간에 멈췄거든", "should_trigger": true},
  {"query": "실험 결과 요약해서 논문용으로 정리해줘. retro 형식으로", "should_trigger": true},
  {"query": "오늘 실험 회고 해야 해. 성공한 것, 실패한 것, 개선점", "should_trigger": true},
  {"query": "지난주 실험 데이터 리뷰하고 교훈 정리해줘", "should_trigger": true},
  {"query": "paper-ready structured output으로 실험 결과 정리해줘", "should_trigger": true},
  {"query": "실험 retro 해줘. 센서 노이즈가 예상보다 심했어", "should_trigger": true},
  {"query": "이번 sprint 실험들 전체적으로 돌아보자. 뭘 배웠는지 정리", "should_trigger": true},
  {"query": "실험 문제 분석해줘. 왜 tracking error가 이렇게 큰지 원인 파악", "should_trigger": true},
  {"query": "실험 프로토콜 새로 짜줘", "should_trigger": false},
  {"query": "데이터 분석해줘. RMSE 계산", "should_trigger": false},
  {"query": "safety check 해줘", "should_trigger": false},
  {"query": "GUI 만들어줘", "should_trigger": false},
  {"query": "펌웨어 플래시해줘", "should_trigger": false},
  {"query": "하드웨어 테스트 돌려줘", "should_trigger": false},
  {"query": "gait cycle 분석해줘", "should_trigger": false},
  {"query": "SD카드에서 데이터 가져와줘", "should_trigger": false},
  {"query": "FFT 분석해서 주파수 응답 봐줘", "should_trigger": false},
  {"query": "코드 리뷰해줘. 제어 루프 로직", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-gui.json" << 'ENDOFFILE'
[
  {"query": "로봇 제어 GUI 만들어줘 PyQt5로", "should_trigger": true},
  {"query": "대시보드에 실시간 플롯 추가해줘", "should_trigger": true},
  {"query": "버튼이 겹쳐서 안 보여, 레이아웃 수정해줘", "should_trigger": true},
  {"query": "GUI에 다크 테마 적용해줘", "should_trigger": true},
  {"query": "위젯을 왼쪽으로 옮겨줘", "should_trigger": true},
  {"query": "사이드바에 collapsible 패널 추가해줘", "should_trigger": true},
  {"query": "실험 UI에 탭 추가해줘", "should_trigger": true},
  {"query": "차트가 너무 작아, 크기 키워줘", "should_trigger": true},
  {"query": "Tkinter로 센서 모니터링 화면 만들어줘", "should_trigger": true},
  {"query": "GUI 응답이 느려, 스레드 분리해줘", "should_trigger": true},
  {"query": "React 컴포넌트 스타일링해줘", "should_trigger": false},
  {"query": "모터 토크 안전 검증해줘", "should_trigger": false},
  {"query": "펌웨어 업로드해줘", "should_trigger": false},
  {"query": "실험 데이터 RMSE 분석해줘", "should_trigger": false},
  {"query": "보행 분석해줘", "should_trigger": false},
  {"query": "CSS flexbox 레이아웃 수정해줘", "should_trigger": false},
  {"query": "Figma 디자인 구현해줘", "should_trigger": false},
  {"query": "하드웨어 테스트해줘", "should_trigger": false},
  {"query": "데이터 CSV 변환해줘", "should_trigger": false},
  {"query": "실험 프로토콜 작성해줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-gui-trigger-eval.json" << 'ENDOFFILE'
[
  {"query": "PyQt5로 모터 제어 GUI 만들어줘. 슬라이더랑 실시간 그래프 필요해", "should_trigger": true},
  {"query": "GUI에서 버튼이 겹쳐. overlap 해결해줘", "should_trigger": true},
  {"query": "대시보드 레이아웃 수정해줘. 왼쪽에 사이드바, 오른쪽에 차트", "should_trigger": true},
  {"query": "이 위젯 좀 더 크게 만들어줘. 그래프가 너무 작아서 안 보여", "should_trigger": true},
  {"query": "다크 테마 적용해줘. 글래스모피즘 스타일로", "should_trigger": true},
  {"query": "collapsible 패널 추가해줘. 설정 영역을 접을 수 있게", "should_trigger": true},
  {"query": "Tkinter로 간단한 실험 UI 만들어줘. Start/Stop 버튼이랑 상태 표시", "should_trigger": true},
  {"query": "GUI 디자인 일관성 맞춰줘. 폰트 사이즈랑 색상 통일", "should_trigger": true},
  {"query": "탭 레이아웃으로 바꿔줘. 모터 탭, 센서 탭, 로그 탭", "should_trigger": true},
  {"query": "로봇 제어 인터페이스 만들어줘. 조이스틱 입력이랑 상태 모니터링", "should_trigger": true},
  {"query": "CSV 데이터 검증해줘", "should_trigger": false},
  {"query": "safety check 돌려줘", "should_trigger": false},
  {"query": "펌웨어 플래시해줘", "should_trigger": false},
  {"query": "실험 프로토콜 설계해줘", "should_trigger": false},
  {"query": "RMSE 계산해서 논문용 표 만들어줘", "should_trigger": false},
  {"query": "gait cycle 분석해줘", "should_trigger": false},
  {"query": "웹 API 엔드포인트 만들어줘. REST API", "should_trigger": false},
  {"query": "matplotlib으로 figure 그려줘. 분석용 그래프", "should_trigger": false},
  {"query": "CLI 도구 만들어줘. 커맨드라인 인터페이스", "should_trigger": false},
  {"query": "하드웨어 테스트 스크립트 작성해줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-data.json" << 'ENDOFFILE'
[
  {"query": "SD 카드에서 실험 데이터 다운받아줘", "should_trigger": true},
  {"query": "시리얼 포트로 데이터 캡처해줘", "should_trigger": true},
  {"query": "CSV 파일에 NaN이 있는지 검증해줘", "should_trigger": true},
  {"query": "ROS bag을 CSV로 변환해줘", "should_trigger": true},
  {"query": "데이터 timestamp가 연속적인지 확인해줘", "should_trigger": true},
  {"query": "실험 데이터 백업하고 정리해줘", "should_trigger": true},
  {"query": "sample rate가 맞는지 검증해줘", "should_trigger": true},
  {"query": "HDF5 파일에서 특정 채널 추출해줘", "should_trigger": true},
  {"query": "로깅 코드 추가해줘, 센서값 CSV로 저장", "should_trigger": true},
  {"query": "데이터 파일 구조 정리해줘, 날짜별로", "should_trigger": true},
  {"query": "데이터 RMSE 분석해줘", "should_trigger": false},
  {"query": "보행 분석 GCP 구해줘", "should_trigger": false},
  {"query": "모터 안전 검증해줘", "should_trigger": false},
  {"query": "하드웨어 테스트해줘", "should_trigger": false},
  {"query": "GUI 만들어줘", "should_trigger": false},
  {"query": "펌웨어 업로드해줘", "should_trigger": false},
  {"query": "실험 프로토콜 설계해줘", "should_trigger": false},
  {"query": "pandas로 주식 데이터 정리해줘", "should_trigger": false},
  {"query": "matplotlib 그래프 그려줘", "should_trigger": false},
  {"query": "실험 retrospective 작성해줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-data-trigger-eval.json" << 'ENDOFFILE'
[
  {"query": "SD카드에서 실험 데이터 내려받아야 해. USB 시리얼로 연결되어 있어", "should_trigger": true},
  {"query": "CSV 데이터 무결성 검증해줘. NaN이랑 timestamp gap 확인 필요", "should_trigger": true},
  {"query": "ROS bag에서 /imu/data 토픽 CSV로 추출해줘", "should_trigger": true},
  {"query": "시리얼 포트에서 데이터 캡처해줘. 115200 baud", "should_trigger": true},
  {"query": "데이터 파일 정리해줘. 날짜별로 폴더 구조 만들고 싶어", "should_trigger": true},
  {"query": "HDF5 파일을 CSV로 변환해줘", "should_trigger": true},
  {"query": "실험 데이터 백업 구조 만들어줘. raw/processed/analysis 폴더", "should_trigger": true},
  {"query": "이 데이터 sample rate 확인해줘. 일정한지 체크", "should_trigger": true},
  {"query": "데이터 로깅 설정해줘. Teensy에서 SD카드에 쓰는 방식", "should_trigger": true},
  {"query": "바이너리 로그 파일 파싱해줘. 포맷은 [timestamp(4B), force(2B), angle(2B)]", "should_trigger": true},
  {"query": "RMSE 계산해줘", "should_trigger": false},
  {"query": "safety check 돌려줘", "should_trigger": false},
  {"query": "gait cycle percentage 계산해줘", "should_trigger": false},
  {"query": "GUI 만들어줘", "should_trigger": false},
  {"query": "펌웨어 올려줘", "should_trigger": false},
  {"query": "실험 프로토콜 설계해줘", "should_trigger": false},
  {"query": "matplotlib으로 tracking error 그래프 그려줘", "should_trigger": false},
  {"query": "t-test 돌려줘. 두 조건 비교", "should_trigger": false},
  {"query": "FFT 분석해줘. 주파수 응답 확인", "should_trigger": false},
  {"query": "retrospective 해줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-analyze.json" << 'ENDOFFILE'
[
  {"query": "로봇 팔 tracking error RMSE 구해줘", "should_trigger": true},
  {"query": "제어 성능 bandwidth 분석해줘", "should_trigger": true},
  {"query": "force-displacement 커브 그려줘", "should_trigger": true},
  {"query": "FFT 분석해서 주파수 응답 봐줘", "should_trigger": true},
  {"query": "두 조건 t-test로 비교해줘", "should_trigger": true},
  {"query": "실험 결과 matplotlib figure 만들어줘", "should_trigger": true},
  {"query": "LaTeX 표로 실험 결과 정리해줘, IEEE 형식", "should_trigger": true},
  {"query": "trajectory tracking error 프로파일 그려줘", "should_trigger": true},
  {"query": "3개 조건 ANOVA로 비교해줘", "should_trigger": true},
  {"query": "PSD 분석해서 진동 성분 확인해줘", "should_trigger": true},
  {"query": "gait cycle percentage 구해줘", "should_trigger": false},
  {"query": "heel strike 검출해줘", "should_trigger": false},
  {"query": "stride time 구해줘", "should_trigger": false},
  {"query": "모터 안전 검증해줘", "should_trigger": false},
  {"query": "하드웨어 테스트해줘", "should_trigger": false},
  {"query": "GUI 만들어줘", "should_trigger": false},
  {"query": "데이터 CSV 변환해줘", "should_trigger": false},
  {"query": "펌웨어 업로드해줘", "should_trigger": false},
  {"query": "실험 프로토콜 설계해줘", "should_trigger": false},
  {"query": "주식 차트 분석해줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-analyze-trigger-eval.json" << 'ENDOFFILE'
[
  {"query": "tracking error RMSE 계산해줘. reference vs actual position 데이터 있어", "should_trigger": true},
  {"query": "FFT 분석해줘. 제어 입력의 주파수 응답 보고 싶어", "should_trigger": true},
  {"query": "두 실험 조건 통계 비교해줘. paired t-test 필요해", "should_trigger": true},
  {"query": "force-displacement 커브 그려줘. 논문에 넣을 figure", "should_trigger": true},
  {"query": "bandwidth 측정해줘. -3dB cutoff frequency 찾아야 해", "should_trigger": true},
  {"query": "matplotlib으로 paper-ready figure 만들어줘. IEEE 포맷", "should_trigger": true},
  {"query": "ANOVA 돌려줘. 3가지 제어 방식 비교 실험이야", "should_trigger": true},
  {"query": "PSD 분석해줘. 진동 주파수 성분 확인하고 싶어", "should_trigger": true},
  {"query": "LaTeX 표 만들어줘. 실험 결과 정리해서 JNER 포맷으로", "should_trigger": true},
  {"query": "effect size 계산해줘. Cohen's d 필요해", "should_trigger": true},
  {"query": "gait cycle percentage 계산해줘. heel strike 검출 필요", "should_trigger": false},
  {"query": "stride time이랑 cadence 구해줘", "should_trigger": false},
  {"query": "보행 대칭성 분석해줘. symmetry index", "should_trigger": false},
  {"query": "SD카드에서 데이터 다운로드해줘", "should_trigger": false},
  {"query": "GUI 만들어줘", "should_trigger": false},
  {"query": "safety check 돌려줘", "should_trigger": false},
  {"query": "펌웨어 올려줘", "should_trigger": false},
  {"query": "실험 프로토콜 설계해줘", "should_trigger": false},
  {"query": "CSV 파일 NaN 체크해줘. 무결성 검증", "should_trigger": false},
  {"query": "retrospective 해줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-gait.json" << 'ENDOFFILE'
[
  {"query": "gait cycle percentage 구해줘", "should_trigger": true},
  {"query": "heel strike 검출해줘, IMU 데이터로", "should_trigger": true},
  {"query": "stride time이랑 cadence 구해줘", "should_trigger": true},
  {"query": "stance phase랑 swing phase 비율 분석해줘", "should_trigger": true},
  {"query": "보행 데이터 gait cycle로 정규화해줘", "should_trigger": true},
  {"query": "좌우 대칭성 지수 구해줘, symmetry index", "should_trigger": true},
  {"query": "double support time 계산해줘", "should_trigger": true},
  {"query": "treadmill 보행 데이터에서 heel off 검출해줘", "should_trigger": true},
  {"query": "exoskeleton 보행 실험 gait parameter 분석해줘", "should_trigger": true},
  {"query": "GCP 기반으로 force profile 정규화해줘", "should_trigger": true},
  {"query": "로봇 팔 RMSE 분석해줘", "should_trigger": false},
  {"query": "force-displacement 커브 그려줘", "should_trigger": false},
  {"query": "FFT 분석해줘", "should_trigger": false},
  {"query": "모터 안전 검증해줘", "should_trigger": false},
  {"query": "하드웨어 테스트해줘", "should_trigger": false},
  {"query": "GUI 만들어줘", "should_trigger": false},
  {"query": "데이터 CSV 변환해줘", "should_trigger": false},
  {"query": "펌웨어 업로드해줘", "should_trigger": false},
  {"query": "t-test로 조건 비교해줘", "should_trigger": false},
  {"query": "matplotlib 그래프 스타일 수정해줘", "should_trigger": false}
]
ENDOFFILE

  cat > "$SKIRO_DIR/evals/skiro-gait-trigger-eval.json" << 'ENDOFFILE'
[
  {"query": "gait cycle percentage 계산해줘. IMU 데이터에서 heel strike 검출 필요", "should_trigger": true},
  {"query": "stride time이랑 cadence 분석해줘. 트레드밀 보행 데이터야", "should_trigger": true},
  {"query": "stance phase랑 swing phase 비율 구해줘", "should_trigger": true},
  {"query": "보행 대칭성 분석해줘. 좌우 symmetry index 계산", "should_trigger": true},
  {"query": "heel strike 이벤트 검출해줘. 가속도계 데이터에서", "should_trigger": true},
  {"query": "GCP로 정규화해줘. force profile을 gait cycle percentage 기준으로", "should_trigger": true},
  {"query": "double support time 계산해줘. 양발 지지 구간 분석", "should_trigger": true},
  {"query": "exoskeleton 보행 데이터 분석해줘. 보조 전후 비교", "should_trigger": true},
  {"query": "walking speed variability 구해줘. stride time의 CV", "should_trigger": true},
  {"query": "heel off 시점 검출해줘. force plate 데이터에서", "should_trigger": true},
  {"query": "RMSE 계산해줘. tracking error 분석", "should_trigger": false},
  {"query": "FFT 분석해줘. 주파수 응답 확인", "should_trigger": false},
  {"query": "force-displacement 커브 그려줘", "should_trigger": false},
  {"query": "두 조건 t-test 비교해줘. 일반 로봇 실험", "should_trigger": false},
  {"query": "bandwidth 측정해줘", "should_trigger": false},
  {"query": "SD카드 데이터 다운로드해줘", "should_trigger": false},
  {"query": "GUI 만들어줘", "should_trigger": false},
  {"query": "safety check 돌려줘", "should_trigger": false},
  {"query": "펌웨어 플래시해줘", "should_trigger": false},
  {"query": "PSD 분석해줘. 로봇 팔 진동 주파수 성분", "should_trigger": false}
]
ENDOFFILE

  echo "      Heredoc file generation complete."
fi  # end of "if USED_GIT = false"

# ── Step 3: Set permissions ──────────────────────────────────────────
echo "[2/4] Setting permissions ..."
chmod +x "$SKIRO_DIR/bin/skiro-learnings" 2>/dev/null || true
chmod +x "$SKIRO_DIR/bin/skiro-session" 2>/dev/null || true

# ── Step 4: Create flat copies of sub-skill SKILL.md files ───────────
echo "[3/4] Creating flat skill copies ..."
for skill in safety hwtest flash spec retro gui data analyze gait; do
  FLAT_DIR="$HOME/.claude/skills/skiro-$skill"
  mkdir -p "$FLAT_DIR"
  if [ -f "$SKIRO_DIR/skiro-$skill/SKILL.md" ]; then
    cp "$SKIRO_DIR/skiro-$skill/SKILL.md" "$FLAT_DIR/SKILL.md"
    echo "      skiro-$skill -> $FLAT_DIR/SKILL.md"
  else
    echo "      WARNING: $SKIRO_DIR/skiro-$skill/SKILL.md not found, skipping."
  fi
done

# ── Step 5: Git init if heredoc install ─────────────────────────────
if [ "$USED_GIT" = false ]; then
  echo "[4/4] Initializing git repo ..."
  cd "$SKIRO_DIR"
  git init -q
  git add -A
  git commit -q -m "Initial heredoc install v${VERSION}"
  cd - > /dev/null
else
  echo "[4/4] Skipping git init (cloned from remote)."
fi

# ── Summary ─────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo " Skiro v${VERSION} installed successfully!"
echo "============================================"
echo ""
echo "Location : $SKIRO_DIR"
echo "Skills   : 9 (safety hwtest flash spec retro gui data analyze gait)"
echo "Binaries : bin/skiro-learnings  bin/skiro-session"
echo ""
echo "Flat copies:"
for skill in safety hwtest flash spec retro gui data analyze gait; do
  echo "  ~/.claude/skills/skiro-$skill/SKILL.md"
done
echo ""
echo "Quick start:"
echo "  Open Claude Code and type: /skiro-hwtest"
echo ""
