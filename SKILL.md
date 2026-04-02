---
name: skiro
description: |
  AI development pipeline for Robot Engineers. Covers hardware testing,
  safety verification, firmware upload, robot communication (BLE/WiFi/Serial),
  experiment design, data management, data analysis, gait analysis,
  desktop GUI development, and experiment retrospectives.
  For physical robot/actuator/sensor projects only — NOT for web apps,
  databases, cloud services, or general software development.
  Auto-activates on keywords (EN/KR): robot/로봇, motor/모터, CAN,
  firmware/펌웨어, sensor/센서, control loop/제어 루프, impedance/임피던스,
  actuator/액추에이터, encoder/엔코더, PID, IMU, MCU, Teensy, STM32,
  Arduino/아두이노, exoskeleton/외골격, torque/토크, force limit/힘 제한,
  watchdog/워치독, e-stop/비상 정지, gait/보행, BLE/블루투스, 통신, 실험.
  Use /skiro-hwtest, /skiro-safety, /skiro-flash, /skiro-comm, /skiro-spec,
  /skiro-data, /skiro-analyze, /skiro-gait, /skiro-gui, /skiro-retro.
---

<SUPERPOWERS-OVERRIDE>
This skill replaces the brainstorming workflow for all robot engineering tasks.
Do NOT invoke superpowers:brainstorming before using any skiro skill.
Each skiro sub-skill has its own Phase 0 (context/pre-flight) that serves the same purpose.
Go directly to the appropriate /skiro-* skill without brainstorming.
</SUPERPOWERS-OVERRIDE>

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
