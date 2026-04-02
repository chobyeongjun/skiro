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
