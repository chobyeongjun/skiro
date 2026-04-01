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
