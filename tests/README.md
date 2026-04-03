# skiro-safety Eval Test Cases

`/skiro-safety` 스킬의 버그 탐지 능력을 평가하는 테스트 케이스.
특정 MCU/모터에 종속되지 않는 범용 로보틱스 코드 패턴.

## 사용법

```bash
# should-fail 코드에 /skiro-safety 실행 → CRITICAL/WARNING 리포트 기대
# should-pass 코드에 /skiro-safety 실행 → 이슈 없음 기대
```

## should-fail/ (10개 — 잡아야 하는 버그)

| 파일 | 체크리스트 항목 | 버그 설명 |
|------|----------------|-----------|
| `no-force-limit.cpp` | #1 Actuator Limits | PID 출력을 클램프 없이 모터에 직접 전달. 큰 오차 시 500Nm 등 과도한 토크 발생 |
| `malloc-in-loop.cpp` | #5 Control Loop Timing | 1kHz 제어 루프 안에서 `malloc`/`new` 사용. 힙 단편화로 비결정적 지연 발생 |
| `no-watchdog.cpp` | #3 Watchdog | 하드웨어/소프트웨어 워치독 없음. 루프 hang 시 모터가 마지막 명령으로 무한 동작 |
| `printf-in-isr.cpp` | #5 Control Loop Timing | ISR 안에서 `printf`, `serial_flush` 등 블로킹 I/O. 인터럽트 지연으로 제어 타이밍 붕괴 |
| `can-id-duplicate.cpp` | #7 Communication Protocol | 두 모터에 동일 CAN ID (0x01) 할당. 응답 충돌, 명령 혼선 |
| `blocking-delay.cpp` | #5 Control Loop Timing | 제어 루프 안에서 `delay_ms(10)`, `serial_flush_blocking()`. 1kHz 루프가 실제 ~90Hz로 저하 |
| `no-timeout.cpp` | #3 Watchdog | 시리얼 수신이 블로킹 — 호스트 연결 끊기면 루프 전체가 멈춤 |
| `unsafe-impedance.py` | #1 Actuator Limits | 음수 댐핑 (B=-5), 패시비티 조건 미충족. 시스템이 에너지를 주입해 진동 발산 |
| `race-condition.cpp` | #5 Control Loop Timing | ISR-메인루프 공유 변수에 `volatile` 없음, 크리티컬 섹션 없음. torn read 발생 가능 |
| `no-estop.cpp` | #2 Emergency Stop | E-STOP 핀, ISR, 상태 모두 없음. 모터 폭주 시 전원 차단 외 방법 없음 |

## should-pass/ (4개 — 안전한 코드)

| 파일 | 설명 |
|------|------|
| `safe-motor-ctrl.cpp` | 토크 클램프, 슬루레이트 제한, 통신 워치독, 하드웨어 E-STOP ISR, 상태머신(IDLE/CALIBRATING/RUNNING/E_STOP/ERROR), 에러 복구 프로토콜 |
| `proper-can.cpp` | 고유 CAN ID 4개, CRC8 검증, 수신 링버퍼(오버플로우 방지), 모터별 타임아웃, 오프라인 모터 자동 제로토크 |
| `stable-impedance.py` | 임피던스 파라미터 사전 검증(K≥0, B>0, M>0), 감쇠비 체크(ζ≥0.5), NaN/inf 가드, 토크 클램프 |
| `safe-isr.cpp` | 최소 ISR(카운터 증가만), volatile 변수, 더블버퍼, 크리티컬 섹션으로 multi-word 복사, 메인루프에서 로깅 |

## 체크리스트 매핑

- **#1 Actuator Limits**: `no-force-limit.cpp`, `unsafe-impedance.py`
- **#2 Emergency Stop**: `no-estop.cpp`
- **#3 Watchdog / Timeout**: `no-watchdog.cpp`, `no-timeout.cpp`
- **#5 Control Loop Timing**: `malloc-in-loop.cpp`, `printf-in-isr.cpp`, `blocking-delay.cpp`, `race-condition.cpp`
- **#7 Communication Protocol**: `can-id-duplicate.cpp`
