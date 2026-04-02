<p align="center">
  <img src="https://img.shields.io/badge/skiro-v0.1.0-blue?style=for-the-badge" alt="version"/>
  <img src="https://img.shields.io/badge/platform-Win%20%7C%20Mac%20%7C%20Linux-green?style=for-the-badge" alt="platform"/>
  <img src="https://img.shields.io/badge/license-MIT-orange?style=for-the-badge" alt="license"/>
  <img src="https://img.shields.io/badge/Claude%20Code-compatible-blueviolet?style=for-the-badge" alt="claude"/>
</p>

<h1 align="center">Skiro</h1>
<p align="center"><strong>AI Development Pipeline for Robot Engineers</strong></p>
<p align="center"><em>Skills + Robot = Skiro</em></p>
<p align="center">Stop repeating the same hardware mistakes. Let your AI remember them for you.</p>

---

## What is Skiro?

Skiro turns Claude Code into a **robot-aware development partner**. It knows that
motors have torque limits, communication buses have timing constraints, and firmware
uploads cannot be undone.

```
You:    "Review my motor control code"
Skiro:  Prior learning: AK60 ID conflict (2026-03-15, confidence 9/10)
        CRITICAL motor_ctrl.cpp:42 — force limit check missing
        WARNING  control_loop.cpp:88 — printf blocking call in 111Hz loop
        PASS     watchdog.cpp:15 — timeout 50ms (verified)
        -> 1 critical, 1 warning. Fix now?
```

## Features

- **Safety Verification** — Actuator limits, watchdog, e-stop, timing
- **Learnings System** — Remembers hardware bugs across sessions
- **Hardware-Aware** — Reads hardware.yaml, verifies code against specs
- **Model Routing** — Haiku for search, Sonnet for review, Opus for design
- **Experiment Pipeline** — Design -> Safety -> Test -> Flash -> Retro -> Paper
- **Session Handoff** — Continue where you left off
- **Cross-Platform** — Windows, macOS, Linux. No binary dependencies.

## Commands

| Command | What it does |
|---------|-------------|
| `/skiro-safety` | Verify code: limits, watchdog, e-stop, timing |
| `/skiro-hwtest` | Generate + run hardware test scripts |
| `/skiro-flash` | Build + upload firmware (safety gate) |
| `/skiro-plan` | Design experiment protocol |
| `/skiro-retro` | Experiment retrospective + paper data |

## Installation

### macOS / Linux

```bash
git clone https://github.com/chobyeongjun/skiro.git ~/.claude/skills/skiro
chmod +x ~/.claude/skills/skiro/bin/*
```

Or use the installer script:
```bash
bash setup-skiro.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/chobyeongjun/skiro.git "$HOME\.claude\skills\skiro"
```

Or use the PowerShell installer (auto-downloads if git is unavailable):
```powershell
powershell -ExecutionPolicy Bypass -File setup-skiro.ps1
```

**Windows utility scripts** are in `bin/` with `.ps1` extension:
```powershell
# Manage hardware learnings
pwsh bin/skiro-learnings.ps1 search "motor"
pwsh bin/skiro-learnings.ps1 add '{"key":"ak60-torque","tags":["motor"],"text":"AK60 max 18Nm"}'
pwsh bin/skiro-learnings.ps1 list
pwsh bin/skiro-learnings.ps1 count

# Session handoff
pwsh bin/skiro-session.ps1 save myproject "Completed motor calibration"
pwsh bin/skiro-session.ps1 load myproject
pwsh bin/skiro-session.ps1 list myproject
```

## Hardware Configuration

Copy `hardware.yaml.example` to your project root as `hardware.yaml`:

```yaml
motors:
  - name: AK60-6
    interface: CAN
    max_torque: 18  # Nm
safety:
  max_force: 70     # N
  watchdog_timeout: 100  # ms
```

## Works With

| Tool | Role |
|------|------|
| gstack | Brainstorming, code review, dev retrospectives |
| Superpowers | TDD workflow |
| Context7 | Live library documentation |

## Philosophy

1. Hardware is not software. You cannot undo a bad motor command.
2. AI should remember your mistakes. Humans forget. Logs don't.
3. Evidence, not opinions. Every PASS needs a file:line citation.
4. Simple interface, complex internals. You see PASS/FAIL.
5. Any robot, any platform. Teensy or STM32, CAN or Serial.

## License

MIT

## Author

**Cho Byeongjun** — Robot Engineer, ARLAB, Chung-Ang University
