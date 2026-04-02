---
name: skiro
description: |
  AI development pipeline for Robot Engineers. Covers hardware testing,
  safety verification, firmware upload, robot communication (BLE/WiFi/Serial),
  experiment design, data management, data analysis, gait analysis,
  desktop GUI development, and experiment retrospectives.
  For physical robot/actuator/sensor projects only — NOT for web apps,
  databases, cloud services, or general software development.
  Auto-activates on keywords: robot, motor, CAN, firmware, sensor, control
  loop, impedance, actuator, encoder, PID, IMU, MCU, Teensy, STM32,
  Arduino, exoskeleton, torque, force limit, watchdog, e-stop, gait,
  BLE, Bluetooth, bleak.
  Use /skiro-hwtest, /skiro-safety, /skiro-flash, /skiro-comm, /skiro-spec,
  /skiro-data, /skiro-analyze, /skiro-gait, /skiro-gui, /skiro-retro.
---

# Skiro — AI Development Pipeline for Robot Engineers
Skills + Robot. Built for real hardware, real experiments, real papers.

## Skill Selection Guide

Pick the right skill based on what you need:

```
What do you want to do?
├── 하드웨어 셋업/테스트?           → /skiro-hwtest
├── 코드 안전 검증?                 → /skiro-safety
├── 펌웨어 빌드/업로드?             → /skiro-flash
├── BLE/WiFi/Serial 통신?           → /skiro-comm
├── 실험 설계/프로토콜?             → /skiro-spec
├── 데이터 정리/검증/변환?          → /skiro-data
├── 데이터 분석 (RMSE/FFT/통계)?    → /skiro-analyze
├── 보행 분석 (GCP/stride/HS)?      → /skiro-gait
├── GUI 개발 (PyQt/Tkinter)?        → /skiro-gui
└── 실험 회고/논문 정리?            → /skiro-retro
```

## Available Commands

| Command | What it does | When to use |
|---------|-------------|-------------|
| /skiro-hwtest | Hardware test + **auto hardware.yaml** | New project, new hardware |
| /skiro-safety | Verify code: limits, watchdog, e-stop | Before flash, before experiments |
| /skiro-flash | Build + upload firmware to MCU | After code changes |
| /skiro-comm | BLE/WiFi/Serial communication setup | Robot ↔ PC connection |
| /skiro-spec | Design experiment protocol | Planning experiments |
| /skiro-data | Data management: validate, convert, organize | After data collection |
| /skiro-analyze | Analysis: RMSE, FFT, stats, paper figures | Analyze results |
| /skiro-gait | Gait analysis (extends /skiro-analyze) | Walking robot / exoskeleton |
| /skiro-gui | Desktop GUI (PyQt, Tkinter) | Build robot control UI |
| /skiro-retro | Experiment retrospective + paper data | After experiments |

## Workflow

```
/skiro-hwtest ──→ /skiro-spec ──→ /skiro-safety ──→ /skiro-flash
(hardware setup)   (experiment)    (code verify)     (firmware)
       │                                                │
       └──→ /skiro-comm (BLE/WiFi/Serial)              │
                  │                                [experiment]
                  └──→ /skiro-gui (control UI)          │
                                              /skiro-data ──→ /skiro-analyze ──→ /skiro-retro
                                              (manage data)   (analysis)         (retrospective)
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
│  gui    │ data   │ comm                      │
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
