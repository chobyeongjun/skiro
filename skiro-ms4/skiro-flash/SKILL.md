# skiro-flash — SKILL.md
# v0.5 MS4 | 단일 파일 유지 (모듈화 불필요) | ~1684 tok 수준

## 역할
펌웨어 빌드 및 플래시 절차를 안내한다.
.skiro_safety_gate 존재를 전제 조건으로 요구한다.

## 트리거 감지
```
"플래시", "flash", "업로드", "firmware", "펌웨어", "굽기",
"CubeIDE", "bin 파일", "ST-Link", "OpenOCD", "esptool"
```

## 사전 조건 (절대 준수)

```bash
# 1. safety gate 확인
ls .skiro_safety_gate || { echo "BLOCKED: skiro-safety 먼저 실행"; exit 1; }

# 2. hwtest 완료 확인
ls .skiro_hwtest_pass 2>/dev/null || echo "WARNING: hwtest 미완료"

# 3. git 상태 확인 (미커밋 변경사항 있으면 경고)
git status --short && git diff --stat HEAD
```

## STM32 플래시 절차 (CubeIDE)

### CubeMX → CubeIDE 워크플로 (NUCLEO-L432KC 기준)
```
1. CubeMX 6.17.0에서 .ioc 파일 열기
2. Project Manager → Generate Code
3. CubeIDE 2.1.1에서 프로젝트 Import
4. Build: Project → Build Project (Ctrl+B)
5. Flash: Run → Debug As → STM32 MCU C/C++ Application
   또는 Run → Run As → STM32 MCU C/C++ Application (디버그 없이)

ST-Link 업그레이드 확인:
  STM32CubeProgrammer → Firmware upgrade
  → v3.3.3 이상 권장
```

### OpenOCD (CLI 플래시)
```bash
openocd -f interface/stlink.cfg \
        -f target/stm32l4x.cfg \
        -c "program build/firmware.bin verify reset exit 0x08000000"
```

### Teensy 4.1 (Teensyduino)
```bash
# Arduino IDE + Teensyduino
# 또는 CLI:
teensy_loader_cli --mcu=TEENSY41 -w -s firmware.hex
```

## Jetson (L4T 36.4.0) 배포

```bash
# Python 패키지 업데이트 (venv_dl)
source ~/venv_dl/bin/activate
pip install -e . --break-system-packages

# ROS2 패키지 빌드
cd ~/ros2_ws
colcon build --packages-select hw_control
source install/setup.bash

# 절대 금지:
# apt upgrade   ← JetPack 스택 파괴 위험
# pip install outside venv  ← 시스템 Python 오염
```

## 플래시 후 검증

```bash
# STM32: UART 출력 확인
# PuTTY: COM4, 115200, 8N1
# 기대: "System initialized. Waiting for CAN..."

# Teensy: 시리얼 모니터
# 기대: 주기적 상태 출력

# ROS2:
ros2 topic list | grep hw/
ros2 topic hz /hw/motor/state   # 기대: ~111 Hz
```

## current-experiment.json 업데이트

```json
{ "status": "flashed", "flashed_at": "<ISO-8601>", "target": "<MCU>" }
```
