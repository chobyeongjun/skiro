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
