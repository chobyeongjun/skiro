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

## Auto-Dispatch (자동 스킬 배정)

사용자가 슬래시 명령 없이 자연어로 요청하면, 아래 규칙으로 자동 배정.
**매칭되면 해당 스킬을 바로 invoke** — 사용자에게 "어떤 스킬을 쓸까요?" 묻지 않는다.

```
사용자 요청 → 키워드/의도 매칭 → 해당 스킬 자동 실행
```

### 매칭 규칙 (우선순위 순)

| 의도 패턴 (한/영) | 스킬 | 예시 |
|-------------------|------|------|
| 하드웨어 테스트, 센서 확인, 모터 테스트, 장비 셋업 | /skiro-hwtest | "IMU 작동 확인해줘", "모터 테스트" |
| 안전 검증, 코드 검토, 리밋 확인, watchdog | /skiro-safety | "이 코드 안전한지 확인", "토크 제한 확인" |
| 펌웨어 업로드, 플래시, 빌드, 컴파일 | /skiro-flash | "펌웨어 올려줘", "빌드해줘" |
| BLE 연결, 블루투스, WiFi, 시리얼, 통신, 연결 끊김 | /skiro-comm | "로봇이랑 연결", "BLE 안 됨" |
| 실험 설계, 프로토콜, 실험 계획 | /skiro-spec | "실험 계획 세워줘" |
| 데이터 다운로드, CSV 검증, NaN, 파일 정리, SD카드 | /skiro-data | "데이터 정리해줘", "CSV 확인" |
| 유효 데이터 모으기, 논문 데이터, 데이터 큐레이션 | /skiro-data Phase 6 | "논문 쓸 데이터 정리", "유효 데이터 모아" |
| RMSE, FFT, 통계, 조건 비교, 그래프, 분석 | /skiro-analyze | "RMSE 구해줘", "조건 비교 분석" |
| GCP, 보행, 힐 스트라이크, stride, 케이던스 | /skiro-gait | "보행 분석해줘", "GCP 계산" |
| GUI, 위젯, 레이아웃, 버튼, 대시보드, PyQt | /skiro-gui | "GUI 만들어줘", "버튼 위치 바꿔" |
| 모캡, Visual3D, TXT→CSV, 모션 캡처, c3d | /skiro-mocap | "Visual3D 변환", "모캡 CSV로 바꿔" |
| 실험 회고, 논문 정리, paper packet, COWORK | /skiro-retro | "실험 정리해줘", "논문 패킷 만들어" |

### 중복 매칭 해소 규칙
- "데이터 분석" → /skiro-analyze (분석이 주)
- "데이터 정리" → /skiro-data (정리가 주)
- "보행 데이터 분석" → /skiro-gait (보행이 키워드면 gait 우선)
- "GUI에서 BLE 연결" → /skiro-comm (통신이 주, GUI는 레이아웃만)
- 불확실하면 → AskUserQuestion으로 확인

### 자동 실행 방식
매칭된 스킬을 사용자에게 알리고 즉시 실행:
"→ /skiro-analyze를 사용합니다."
그 후 해당 스킬의 Phase 0부터 진행.

## Skill Reference

```
What do you want to do?
├── 하드웨어 셋업/테스트?           → /skiro-hwtest
├── 코드 안전 검증?                 → /skiro-safety
├── 펌웨어 빌드/업로드?             → /skiro-flash
├── BLE/WiFi/Serial 통신?           → /skiro-comm
├── 실험 설계/프로토콜?             → /skiro-spec
├── 데이터 정리/검증/변환?          → /skiro-data (Phase 1-5)
├── 논문 데이터 모으기?             → /skiro-data (Phase 6)
├── 데이터 분석 (RMSE/FFT/통계)?    → /skiro-analyze
├── 보행 분석 (GCP/stride/HS)?      → /skiro-gait
├── GUI 개발 (PyQt/Tkinter)?        → /skiro-gui
├── 모캡 데이터 변환 (Visual3D)?    → /skiro-mocap
├── 실험 회고/논문 정리?            → /skiro-retro
└── 논문 작성 (COWORK 연계)?        → /skiro-retro → paper_packet/ → claude.ai
```

## Available Commands

| Command | What it does | When to use |
|---------|-------------|-------------|
| /skiro-hwtest | Hardware test + **auto hardware.yaml** | New project, new hardware |
| /skiro-safety | Verify code: limits, watchdog, e-stop | Before flash, before experiments |
| /skiro-flash | Build + upload firmware to MCU | After code changes |
| /skiro-comm | BLE/WiFi/Serial communication setup | Robot ↔ PC connection |
| /skiro-spec | Design experiment protocol | Planning experiments |
| /skiro-data | Data management + **paper dataset curation** | After data collection / before analysis |
| /skiro-analyze | Analysis: RMSE, FFT, stats, paper figures | Analyze results |
| /skiro-gait | Gait analysis (extends /skiro-analyze) | Walking robot / exoskeleton |
| /skiro-gui | Desktop GUI (PyQt, Tkinter) | Build robot control UI |
| /skiro-mocap | MoCap TXT → CSV (Visual3D) | Motion capture 데이터 변환 |
| /skiro-retro | Retrospective + **Paper Packet → COWORK** | After experiments + analysis |

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
