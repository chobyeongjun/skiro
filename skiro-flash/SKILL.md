---
name: skiro-flash
description: |
  Build and upload firmware to MCU (Teensy, STM32, Arduino, ESP32).
  Enforces pre-flash safety check and git commit. For embedded firmware
  only — NOT for web deploy, Docker, cloud, or CI/CD deployment.
  Keywords (EN/KR): flash/플래시, firmware/펌웨어, upload/업로드,
  빌드, 컴파일, 보드에 올려줘, MCU 프로그래밍, burn, Teensy,
  platformio, arduino-cli, 펌웨어 업로드. (skiro)
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
Save session.

Next step suggestions:
- Flash successful → /skiro-hwtest to verify hardware behavior
- Need communication setup → /skiro-comm
- Ready for experiment → /skiro-spec

### Auto-Suggestion on Code Changes
When working outside of /skiro-flash (e.g., editing firmware code), detect
firmware file modifications and proactively suggest re-building:

```bash
# Check for recent firmware changes
git diff --name-only HEAD 2>/dev/null | grep -E '\.(ino|cpp|h|c)$|platformio\.ini' | head -5
```

If firmware files were modified since last flash:
→ Display: "Firmware files changed since last build. Run /skiro-flash to verify."
→ Do NOT auto-build. Always wait for user confirmation.
