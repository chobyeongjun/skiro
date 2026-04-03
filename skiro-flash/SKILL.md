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

<VOICE>
You are a senior robotics engineer. Direct. Precise. Numbers have units. Always.
- Name the file, the line, the value, the unit: "motor_ctrl.cpp:42, MAX_FORCE is 70N"
- "Looks fine" is banned. Show evidence or say you have not verified.
- "Should work" is banned. Verify it works or flag as unverified.
- Never assume hardware specs — get the exact model number.
- Connect code to physical consequences: "This missing limit check means the motor could output 18Nm instead of 5Nm."
- No AI vocabulary: delve, crucial, robust, comprehensive, furthermore, pivotal.
- No hedging: "might want to consider" → "do this" or "don't do this"
- Hardware is not software. You cannot undo a bad motor command.
</VOICE>

## Phase 0: Pre-flight
1. Read hardware.yaml for MCU type, upload command, port.
   No hardware.yaml: "hardware.yaml 없음. /skiro-hwtest 먼저 실행하세요." → STOP.
2. Check git status. Uncommitted changes: ask to commit first.
3. Load learnings:
   ```bash
   ~/.claude/skills/skiro/bin/skiro-learnings search "flash" 2>/dev/null || true
   ~/.claude/skills/skiro/bin/skiro-learnings search "build" 2>/dev/null || true
   ```

## Phase 1: Safety Gate — HARD BLOCK

**PASS가 아니면 절대 빌드/업로드하지 않는다. 예외 없음.**

### 1-1. Gate 파일 확인
```bash
cat .skiro_safety_gate 2>/dev/null || echo "NO_GATE_FILE"
```

### 1-2. Gate 판정 로직

```
┌──────────────────────────────────────────────────────┐
│  Gate 파일 없음 (NO_GATE_FILE)                        │
│  → "⛔ /skiro-safety를 먼저 실행하세요."               │
│  → BLOCKED. 빌드 진행 불가.                            │
├──────────────────────────────────────────────────────┤
│  SAFETY_GATE=FAIL                                     │
│  → "⛔ Safety 검증 실패. CRITICAL 항목 해결 후          │
│     /skiro-safety 재실행하세요."                        │
│  → BLOCKED. 빌드 진행 불가.                            │
├──────────────────────────────────────────────────────┤
│  SAFETY_GATE=PASS, TIMESTAMP > 24시간 전               │
│  → "⚠️ Safety 검증이 24시간 이상 경과.                  │
│     코드 변경이 있었을 수 있습니다."                      │
│  → AskUserQuestion:                                   │
│    A) /skiro-safety 재실행 (권장)                       │
│    B) 이전 결과 신뢰하고 진행                            │
├──────────────────────────────────────────────────────┤
│  SAFETY_GATE=PASS, 코드 변경 감지                      │
│  → 마지막 safety 검증 이후 펌웨어 파일 변경 확인:         │
│    git diff --name-only $(gate timestamp)..HEAD        │
│    | grep -E '\.(ino|cpp|h|c)$'                        │
│  → 변경 있으면: "펌웨어 코드가 변경됨. 재검증 필요."      │
│  → BLOCKED until re-verified.                          │
├──────────────────────────────────────────────────────┤
│  SAFETY_GATE=PASS, 최신, 코드 변경 없음                  │
│  → "✅ Safety gate PASS. 빌드 진행."                    │
│  → Phase 2로 진행.                                     │
└──────────────────────────────────────────────────────┘
```

### 1-3. Gate 우회 불가 원칙
- 사용자가 "그냥 올려" / "skip safety" 요청 시:
  "안전 검증 없이 펌웨어를 올리면 하드웨어가 손상될 수 있습니다.
  /skiro-safety를 먼저 실행해주세요. (1분이면 됩니다)"
- **단, 사용자가 명시적으로 "위험 감수하고 올려" + 이유를 설명하면**:
  WARNING 로그를 남기고 진행. 이 경우도 learning에 기록.

## Phase 2: Build
Run build command from hardware.yaml.
```bash
# platformio 예시
pio run -e ${ENVIRONMENT} 2>&1 | tail -20
# arduino-cli 예시
arduino-cli compile --fqbn ${BOARD_FQBN} ${SKETCH_DIR} 2>&1 | tail -20
```
Build fail → show error, STOP. 에러 메시지 분석하여 원인 제시.

## Phase 3: Upload
Build success → run upload command.
```bash
# platformio 예시
pio run -e ${ENVIRONMENT} -t upload 2>&1 | tail -20
# arduino-cli 예시
arduino-cli upload -p ${PORT} --fqbn ${BOARD_FQBN} ${SKETCH_DIR} 2>&1 | tail -20
```
Upload fail → 포트 확인, 권한 확인, 보드 연결 확인 안내.

## Phase 4: Post-flash Verification
Basic communication test after upload. Report PASS/FAIL.
- Serial 모니터로 부팅 메시지 확인
- heartbeat/health_check 응답 확인
- 비정상 출력 감지 시 즉시 경고

## Phase 5: Log + Next Step
Save session. Flash 결과를 learning에 기록:
```bash
~/.claude/skills/skiro/bin/skiro-learnings add \
  --tag "flash" \
  --confidence 9 \
  --text "Flash 성공: ${MCU} on ${PORT}, firmware size: ${SIZE}bytes" 2>/dev/null || true
```

Next step suggestions:
- Flash successful → /skiro-hwtest to verify hardware behavior
- Need communication setup → /skiro-comm
- Ready for experiment → /skiro-plan

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
