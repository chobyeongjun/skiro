# p3-motor-test.md — 모터 테스트
# skiro-hwtest | motor/full tier | ~560 tok

## AK60-6 모터 안전 테스트 절차

### 필수 전제
```
□ 모터 기계적으로 고정됨 (자유 회전 상태에서만 테스트)
□ 전류 상한 하드웨어 설정 확인
□ 비상 정지 버튼 손 닿는 곳에 있음
□ 로그 기록 준비 완료
```

### 단계 1: 통신 확인 (전류 0)
```c
// MIT 모드, 제로 명령
motor_cmd.kp = 0; motor_cmd.kd = 0;
motor_cmd.q = 0;  motor_cmd.qd = 0;
motor_cmd.tau = 0;
CAN_send_motor_cmd(&hcan, MOTOR_ID, &motor_cmd);
// 기대: 모터 응답 패킷 수신 (위치/속도/전류 = 0±노이즈)
```

### 단계 2: 저전류 댐핑 테스트 (Kd 소량)
```c
motor_cmd.kp = 0; motor_cmd.kd = 0.1f;  // 작은 댐핑만
motor_cmd.tau = 0;
// 손으로 축 천천히 돌렸을 때 저항감 느껴지면 정상
// 전류 측정: < 0.5A
```

### 단계 3: 위치 제어 소각도 테스트
```c
// ±5° 이내 소각도 이동만
float target_pos = current_pos + DEG_TO_RAD(3.0f);
motor_cmd.kp = 5.0f; motor_cmd.kd = 0.5f;
motor_cmd.q = target_pos;
// 3° 이동 후 정지, 전류 < 2A
```

### 비상 정지 절차
```c
void emergency_stop_all(void) {
    for(int id = 1; id <= NUM_MOTORS; id++) {
        motor_set_zero_cmd(id);     // 토크 0
        motor_disable(id);           // 모터 오프
    }
    HAL_GPIO_WritePin(ENABLE_PORT, ENABLE_PIN, GPIO_PIN_RESET);
}
```

## 모터 테스트 결과 기록

```
[HWTEST] 모터 확인
  CAN 통신: OK / FAIL
  단계 1 (통신): 전류 <값>A → OK / FAIL
  단계 2 (댐핑): 반응감 YES/NO → OK / FAIL
  단계 3 (위치): 오차 <값>° → OK / FAIL
  최대 측정 전류: <값>A (상한 <값>A의 <N>%)
  전체: PASS / FAIL
```
