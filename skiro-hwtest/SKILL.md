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
