---
name: skiro
description: |
  AI development harness for Robot Engineers. Covers the full robot development
  lifecycle: hardware testing, safety verification, firmware upload, communication
  (CAN/BLE/WiFi/Serial), experiment design, data management, analysis,
  GUI development, and experiment retrospectives.
  For physical robot/actuator/sensor projects only — NOT for web apps,
  databases, cloud services, or general software development.
  Auto-activates on keywords (EN/KR): robot/로봇, motor/모터, CAN,
  firmware/펌웨어, sensor/센서, control loop/제어 루프, impedance/임피던스,
  actuator/액추에이터, encoder/엔코더, PID, IMU, MCU, Teensy, STM32,
  Arduino/아두이노, torque/토크, force limit/힘 제한,
  watchdog/워치독, e-stop/비상 정지, BLE/블루투스, 통신, 실험.
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
| BLE 연결, 블루투스, WiFi, 시리얼, CAN, 통신, 연결 끊김 | /skiro-comm | "로봇이랑 연결", "BLE 안 됨" |
| 실험 설계, 프로토콜, 실험 계획 | /skiro-plan | "실험 계획 세워줘" |
| 데이터 정리, CSV, 로깅, SD카드, C3D, 필터, FFT, 센서융합 | /skiro-data | "데이터 정리해줘", "CSV 확인", "C3D 로딩" |
| RMSE, 통계, 조건 비교, 분석, Bode, 수렴 | /skiro-analyze | "RMSE 구해줘", "조건 비교 분석" |
| GUI, 위젯, 레이아웃, 버튼, 대시보드, PyQt | /skiro-gui | "GUI 만들어줘", "버튼 위치 바꿔" |
| 실험 회고, 논문 정리, paper packet | /skiro-retro | "실험 정리해줘", "논문 패킷 만들어" |

### 중복 매칭 해소 규칙
- "데이터 분석" → /skiro-analyze (분석이 주)
- "데이터 정리" → /skiro-data (정리가 주)
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
├── CAN/BLE/WiFi/Serial 통신?       → /skiro-comm
├── 실험 설계/프로토콜?             → /skiro-plan
├── 데이터 수집/정리/필터/시각화?   → /skiro-data
├── 데이터 분석 (RMSE/통계)?        → /skiro-analyze
├── GUI 개발 (PyQt/Tkinter)?        → /skiro-gui
├── 실험 회고/논문 정리?            → /skiro-retro
└── 논문 작성 (COWORK 연계)?        → /skiro-retro → paper_packet/ → claude.ai
```

## Available Commands

| Command | What it does | When to use |
|---------|-------------|-------------|
| /skiro-hwtest | Hardware test + **auto hardware.yaml** | New project, new hardware |
| /skiro-safety | Verify code: limits, watchdog, e-stop | Before flash, before experiments |
| /skiro-flash | Build + upload firmware to MCU | After code changes |
| /skiro-comm | CAN/BLE/WiFi/Serial communication setup | Robot ↔ PC connection |
| /skiro-plan | Design experiment protocol | Planning experiments |
| /skiro-data | Data pipeline: logging, filtering, sensor fusion, visualization | Data collection → processing |
| /skiro-analyze | Analysis: RMSE, Bode, stats, paper figures | Analyze results |
| /skiro-gui | Desktop GUI (PyQt, Tkinter) | Build robot control UI |
| /skiro-retro | Retrospective + **Paper Packet** | After experiments + analysis |

## Workflow

```
/skiro-hwtest ──→ /skiro-plan ──→ /skiro-safety ──→ /skiro-flash
(hardware setup)   (experiment)    (code verify)     (firmware)
       │                                                │
       └──→ /skiro-comm (CAN/BLE/Serial)               │
                  │                                [experiment]
                  └──→ /skiro-gui (control UI)          │
                                              /skiro-data ──→ /skiro-analyze ──→ /skiro-retro
                                              (data pipeline)  (analysis)        (retrospective)
```

Each skill recommends the next step when it finishes.

## Architecture

```
┌─────────────────────────────────────────────┐
│  Skills (user-invocable)                     │
│  hwtest │ safety │ flash │ comm │ plan       │
│  data   │ analyze│ gui   │ retro             │
├─────────────────────────────────────────────┤
│  References (Claude domain knowledge)        │
│  motor-control-patterns │ sensor-integration │
│  safety-standards │ realtime-pitfalls        │
│  impedance-control │ datasheet-search        │
├─────────────────────────────────────────────┤
│  Automation (hooks + MCP)                    │
│  complexity analysis │ safety gate           │
│  problem/solution tracking │ sessions        │
├─────────────────────────────────────────────┤
│  State (per-project)                         │
│  hardware.yaml │ CHECKLIST.md │ VOICE.md     │
│  learnings.jsonl │ .skiro_safety_gate        │
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
