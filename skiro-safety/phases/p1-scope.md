# p1-scope.md — Phase 1: 패턴 스캔
# skiro-safety | always load | ~880 tok

## 목적
코드 전체를 grep 패턴으로 기계적으로 훑어 CRITICAL/WARNING 후보를 수집한다.
분석이 아니라 **탐색**이다. 판단은 Phase 2에서 한다.

---

## 스캔 규칙

### 원칙
- 코드가 없는 구간(주석, 문자열 리터럴)도 탐지한다 — 오탐보다 미탐이 더 위험하다.
- 탐지 결과는 라인 번호와 함께 기록한다.
- "없는 코드"도 탐지한다: 아래 MUST-EXIST 패턴이 파일에 없으면 MISSING으로 기록.

---

## MUST-EXIST 패턴 (없으면 자동 WARNING)

```
모터/액추에이터 제어 파일:
  □ 전류 상한: (MAX_CURRENT|current_limit|I_MAX|iq_max)
  □ 토크 상한: (MAX_TORQUE|torque_limit|tau_max)
  □ 속도 상한: (MAX_VEL|vel_limit|omega_max)
  □ 비상 정지: (emergency_stop|e_stop|ESTOP|disable_motor|disable_all)

ISR 파일:
  □ 재진입 방지: (__disable_irq|portDISABLE_INTERRUPTS|NVIC_DisableIRQ)
  □ volatile 선언: (volatile\s+\w+\s+\w+)

CAN 통신 파일:
  □ 타임아웃: (timeout|CAN_TIMEOUT|can_timeout)
  □ 에러 핸들러: (CAN_Error|HAL_CAN_ErrorCallback|error_handler)
```

---

## MUST-NOT-EXIST 패턴 (있으면 자동 CRITICAL 후보)

### C/C++ — ISR 내부 금지
```regex
# 동적 할당 (ISR context에서 heap 접근 = 정의되지 않은 동작)
malloc\s*\(|free\s*\(|new\s+|delete\s+

# 블로킹 콜 (ISR에서 대기 = 데드락)
HAL_Delay\s*\(|vTaskDelay\s*\(|usleep\s*\(|sleep\s*\(

# 비ISR-safe printf (버퍼 오염)
printf\s*\(|fprintf\s*\(|std::cout
```
탐지 방법: ISR 함수 범위(`void \w+_IRQHandler` ~ 다음 `}` 밸런스) 내에서 위 패턴 검색.

### C/C++ — 전역
```regex
# 공유 변수 비보호 접근
(?<!volatile\s)\b(g_|shared_|buf_)\w+\s*=   # volatile 없는 전역 쓰기

# 하드코딩 전류값 (상한 변수 없이 직접 수치)
set_current\s*\(\s*[0-9]+\.?[0-9]*\s*\)
send_torque\s*\(\s*[0-9]+\.?[0-9]*\s*\)

# 안전 게이트 우회
#\s*define\s+SAFETY_BYPASS
FORCE_ENABLE|bypass_safety|skip_gate
```

### Python/ROS2
```regex
# 블로킹 spin (비동기 콜백 충돌)
rospy\.spin\(\)|time\.sleep\([0-9]

# 미검증 토픽 직접 publish
pub\.publish\(.*cmd.*\)   # safety check 없는 cmd publish

# 하드코딩 조인트 제한 없는 직접 명령
joint_trajectory.*positions.*=\s*\[
```

### MATLAB
```regex
# 무한 루프 탈출 조건 없음
while\s+true|while\s+1(?!\s*%.*break)

# 행렬 역산 (역행렬 불가 시 Inf/NaN propagation)
inv\s*\(   # pinv 대신 inv 사용
```

---

## 스캔 결과 기록 양식

```
[SCAN] Phase 1 완료
  CRITICAL 후보: <N>개
  WARNING 후보:  <M>개
  MISSING:       <K>개
  → Phase 2로 전달
```

각 후보는 `파일명:라인번호 | 패턴 | 원문(50자 이하)` 형식으로 기록.

---

## 탐지 우선순위 (제한 시간 있을 때)

1. ISR 내부 malloc/free/printf
2. MUST-EXIST 누락 (상한값 없는 모터 제어)
3. 공유 변수 비보호 쓰기
4. CAN 타임아웃/에러 핸들러 누락
5. 하드코딩 수치

우선순위 1–2에서 CRITICAL이 발견되면 나머지 스캔을 계속하되 즉시 BLOCK 플래그를 설정한다.
