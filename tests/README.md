# skiro-safety Eval Test Cases

`/skiro-safety`가 올바르게 작동하는지 검증하기 위한 테스트 코드.

- **should-fail/**: 안전 위반이 있는 코드. `/skiro-safety`가 반드시 잡아야 함.
- **should-pass/**: 모든 안전 기준을 통과하는 코드. `/skiro-safety`가 통과시켜야 함.

Target: **Teensy 4.1 + AK60-6 CAN motor** (MIT protocol)

---

## should-fail/ (8 cases)

| # | File | Checklist 위반 | 설명 |
|---|------|----------------|------|
| 1 | `01_no_torque_limit.cpp` | #1 Actuator Limits | 토크 명령에 max 값 체크 없이 CAN 전송. `read_desired_torque()`가 아무 값이나 반환 가능 |
| 2 | `02_no_estop.cpp` | #2 Emergency Stop | E-stop 핀, ISR, disable 함수 전혀 없음. 모터를 정지할 방법이 전원 차단뿐 |
| 3 | `03_no_watchdog.cpp` | #3 Watchdog | Serial 끊겨도 마지막 토크 명령을 무한 반복. timeout 체크 없음 |
| 4 | `04_incomplete_state_machine.cpp` | #4 State Machine | E_STOP, ERROR 상태 없음. IDLE에서 calibration 건너뛰고 RUNNING 직행 가능 |
| 5 | `05_blocking_in_control_loop.cpp` | #5 Control Loop Timing | 1kHz 제어 루프 안에서 SD write, Serial.print, malloc 호출 |
| 6 | `06_no_sensor_validation.cpp` | #6 Sensor Validation | 로드셀 값 NaN/spike/stuck 검증 없음. NaN이 constrain() 통과해서 모터에 전달됨 |
| 7 | `07_no_rate_limit.cpp` | #1 Actuator Limits (rate) | 0→12.5 rad 즉시 점프. rate limiter / trajectory 없음 |
| 8 | `08_can_buffer_overflow.py` | #7 Communication Protocol | CAN ID 충돌 (CMD=REPLY=0x01), recv 무한 블로킹, CRC 없음, byte order 미기재 |

## should-pass/ (3 cases)

| # | File | 설명 |
|---|------|------|
| 1 | `01_safe_impedance_controller.cpp` | 완전한 안전 구현: 토크 clamp + rate limiter, E-stop ISR, watchdog, 5-state machine, 센서 검증 |
| 2 | `02_safe_can_interface.py` | Python CAN 인터페이스: 입력 범위 검증, recv timeout, ID 분리, byte order 문서화, watchdog |
| 3 | `03_safe_data_logger.cpp` | 비차단 로깅: ring buffer로 제어루프와 SD 분리, E-stop, watchdog, 고유 파일명 생성 |

---

## 사용법

```bash
# skiro-safety로 should-fail 코드 검사 (모두 CRITICAL/WARNING 나와야 함)
for f in tests/should-fail/*; do echo "=== $f ===" && /skiro-safety "$f"; done

# skiro-safety로 should-pass 코드 검사 (모두 통과해야 함)
for f in tests/should-pass/*; do echo "=== $f ===" && /skiro-safety "$f"; done
```

## 평가 기준

| 결과 | 의미 |
|------|------|
| should-fail 8/8 탐지 | skiro-safety 정상 작동 |
| should-fail 미탐지 있음 | False Negative — 체크리스트 검증 로직 보강 필요 |
| should-pass 오탐지 있음 | False Positive — 과잉 탐지, 임계값 조정 필요 |
| should-pass 3/3 통과 | 정상 |
