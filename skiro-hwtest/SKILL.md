---
name: skiro-hwtest
description: |
  Generate and run hardware test scripts for motors, sensors, cameras,
  communication buses. Auto-generates hardware.yaml by searching official
  datasheets online — users just name their hardware, skiro finds the specs.
  Keywords (EN/KR): hardware test/하드웨어 테스트, motor test/모터 테스트,
  sensor test/센서 테스트, calibration/캘리브레이션, wiring/배선,
  connection test/연결 확인, hardware.yaml, datasheet/데이터시트,
  setup/셋업/세팅, 하드웨어 설정, 새 프로젝트. (skiro)
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
# macOS/Linux
chmod +x ~/.claude/skills/skiro/bin/skiro-learnings 2>/dev/null || true
~/.claude/skills/skiro/bin/skiro-learnings search "hardware" 2>/dev/null || true
~/.claude/skills/skiro/bin/skiro-learnings search "test" 2>/dev/null || true
```
```powershell
# Windows
pwsh "$HOME\.claude\skills\skiro\bin\skiro-learnings.ps1" search "hardware" 2>$null
pwsh "$HOME\.claude\skills\skiro\bin\skiro-learnings.ps1" search "test" 2>$null
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
- Be runnable standalone: `python3 tests/hardware/test_motor.py`

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

## Wrong Skill? Redirect
If the user's request does not match this skill, DO NOT attempt it.
Instead, explain what this skill does and redirect to the correct one:
- Want to verify code safety? → "/skiro-safety audits limits, watchdog, e-stop, timing."
- Want to build a GUI? → "/skiro-gui handles desktop GUI development."
- Want to analyze data? → "/skiro-analyze does RMSE, FFT, statistics."
- Want to flash firmware? → "/skiro-flash builds and uploads firmware to MCU."
- Want to set up BLE/WiFi/Serial? → "/skiro-comm handles robot communication setup."
- Want to plan an experiment? → "/skiro-plan handles experiment design and brainstorming."
- Want to manage data files? → "/skiro-data handles data collection, validation, and format conversion."
- Want gait analysis? → "/skiro-gait does gait cycle, heel strike, temporal-spatial parameters."
- Want experiment retrospective? → "/skiro-retro summarizes results and generates paper packets."
