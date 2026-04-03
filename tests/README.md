# skiro-safety Eval Test Cases

`/skiro-safety`의 탐지 정확도를 검증하기 위한 범용 로보틱스 코드.
특정 MCU/모터에 종속되지 않는 패턴 — 어떤 로봇 프로젝트에도 적용 가능.

- **should-fail/**: 안전 위반이 있는 코드 (10개). `/skiro-safety`가 반드시 잡아야 함.
- **should-pass/**: 모든 안전 기준을 통과하는 코드 (4개). `/skiro-safety`가 통과시켜야 함.

---

## should-fail/ (10 cases)

| File | Checklist 위반 | 설명 |
|------|----------------|------|
| `no-force-limit.cpp` | #1 Actuator Limits | PD 출력을 clamp 없이 모터에 직접 전송 |
| `malloc-in-loop.cpp` | #5 Control Loop Timing | 실시간 루프 안에서 malloc/new — 비결정적 지연 |
| `no-watchdog.cpp` | #3 Watchdog | 통신 끊겨도 마지막 명령 무한 반복, 타임아웃 없음 |
| `printf-in-isr.cpp` | #5 Control Loop Timing | ISR 안에서 printf, 파일 I/O — 블로킹으로 인터럽트 miss |
| `can-id-duplicate.cpp` | #7 Communication | 같은 CAN ID를 두 노드가 사용 — 프레임 충돌 |
| `blocking-delay.cpp` | #5 Control Loop Timing | 제어 루프에 100ms delay — 1kHz 의도했으나 실제 10Hz |
| `no-timeout.cpp` | #3 Watchdog | recv()에 타임아웃 없음 — 상대방 꺼지면 영구 블로킹 |
| `unsafe-impedance.py` | #1 Limits, #6 Sensor | 음수 댐핑(B<0)으로 에너지 주입, 발산하는 임피던스 제어 |
| `race-condition.cpp` | #5 Control Loop Timing | ISR-메인 공유 변수에 volatile/atomic 없음 — torn read |
| `no-estop.cpp` | #2 Emergency Stop | E-stop 핀, ISR, 안전 상태 전이 전혀 없음 |

## should-pass/ (4 cases)

| File | 설명 |
|------|------|
| `safe-motor-ctrl.cpp` | 완전한 안전 구현: 토크 clamp + rate limiter + watchdog + 5-state machine + e-stop ISR |
| `proper-can.cpp` | CAN 통신: 고유 ID, recv 타임아웃, CRC 검증, byte order 명시, 에러 핸들링 |
| `stable-impedance.py` | 수동성 조건(passivity) 검증된 임피던스 제어 + 센서 검증 + watchdog |
| `safe-isr.cpp` | 짧은 ISR + volatile + critical section + 플래그 기반 지연 처리 |

---

## 사용법

```bash
# should-fail 검사 (10/10 CRITICAL/WARNING 나와야 함)
for f in tests/should-fail/*; do echo "=== $f ===" && /skiro-safety "$f"; done

# should-pass 검사 (4/4 통과해야 함)
for f in tests/should-pass/*; do echo "=== $f ===" && /skiro-safety "$f"; done
```

## 평가 기준

| 결과 | 의미 |
|------|------|
| should-fail 10/10 탐지 | skiro-safety 정상 |
| should-fail 미탐지 있음 | False Negative — 체크리스트 검증 보강 필요 |
| should-pass 오탐지 있음 | False Positive — 과잉 탐지, 임계값 조정 |
| should-pass 4/4 통과 | 정상 |

## 설계 원칙

- **범용**: 특정 MCU(Teensy, STM32), 특정 모터(AK60-6) 종속 없음
- **현실적**: 실제 로봇 프로젝트에서 발생하는 패턴 기반
- **최소 의존**: 추상 인터페이스(`motor_driver.h`, `comm.h`) 사용
- **1 파일 = 1 버그**: 각 should-fail 파일은 정확히 하나의 체크리스트 항목 위반
