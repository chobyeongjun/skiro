# p2-checklist.md — Phase 2: 판정 체크리스트
# skiro-safety | always load | ~220 tok

## 목적
Phase 1 탐지 결과를 받아 CRITICAL / WARNING / OK로 확정 판정한다.
승격 규칙을 적용하고 최종 BLOCK 여부를 결정한다.

---

## 판정 기준

### CRITICAL — 즉시 BLOCK
```
□ ISR 내 malloc/free/new/delete 확인됨
□ ISR 내 블로킹 콜(HAL_Delay, vTaskDelay) 확인됨
□ 전류/토크 상한 변수 선언 없이 모터 명령 전송
□ enable_power() / motor_enable() 안전 게이트 없이 호출
□ SAFETY_BYPASS / FORCE_ENABLE 정의 활성화됨
□ .skiro_safety_gate 파일 부재 + flash 시도
```

### WARNING — 경고 후 진행 가능 (확인 필요)
```
□ volatile 없는 전역 공유 변수 감지 (ISR + main 동시 접근 의심)
□ CAN 타임아웃 미처리
□ 비상 정지 루틴 없음
□ 하드코딩 수치(상한 명시 없는 직접 값)
□ pinv 대신 inv 사용 (특이행렬 가능성)
□ ROS cmd publish에 safety check 없음
```

### 승격 규칙 (MS1 영구 규칙)
```
WARNING + (모터 제어 | 액추에이터 | CAN 전송 | 관련 파일) → CRITICAL 자동 승격
```

### OK
Phase 1에서 탐지된 패턴이 컨텍스트상 안전한 경우.
예: ISR 외부의 malloc, 테스트 파일의 printf, 주석 내 키워드.

---

## 판정 결과 양식

```
[SAFETY] Phase 2 판정 완료
  CRITICAL: <N>개
  WARNING:  <M>개 (승격 후 CRITICAL <K>개 포함)
  OK:       <L>개

  BLOCK 여부: YES / NO
  사유: <한 줄>
```

BLOCK=YES → `.skiro_safety_gate` 생성 금지, flash/hwtest 진행 금지.
BLOCK=NO  → `.skiro_safety_gate` 생성 허가, Phase 3+ 진행.
