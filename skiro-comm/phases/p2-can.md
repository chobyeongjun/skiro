# p2-can.md — CAN 버스 구현 가이드
# skiro-comm | CAN 트리거 시 | ~780 tok

## STM32 CAN 설정 (HAL, 1Mbps)

### CubeMX 설정
```
Connectivity → CAN1
  Prescaler: 4
  Time Quanta in Bit Segment 1: 9 Times
  Time Quanta in Bit Segment 2: 6 Times
  ReSynchronization Jump Width: 1 Time
  → 결과: 80MHz / 4 / (1+9+6) = 1.25 Mbps (근사: 1Mbps용 재계산 필요)

실제 1Mbps (APB1=80MHz):
  Prescaler: 5, BS1: 11, BS2: 4 → 80/5/(1+11+4) = 1 Mbps ✓
```

### 필터 설정 (수신 ID 필터링)
```c
CAN_FilterTypeDef canFilter = {0};
canFilter.FilterBank = 0;
canFilter.FilterMode = CAN_FILTERMODE_IDMASK;
canFilter.FilterScale = CAN_FILTERSCALE_32BIT;
canFilter.FilterIdHigh = 0x000 << 5;    // 모든 ID 허용
canFilter.FilterMaskIdHigh = 0x000 << 5;
canFilter.FilterFIFOAssignment = CAN_RX_FIFO0;
canFilter.FilterActivation = ENABLE;
HAL_CAN_ConfigFilter(&hcan1, &canFilter);
HAL_CAN_Start(&hcan1);
HAL_CAN_ActivateNotification(&hcan1, CAN_IT_RX_FIFO0_MSG_PENDING);
```

## AK60-6 MIT 모드 패킷 구조

### TX (8 bytes → 모터로)
```c
typedef struct {
    uint16_t position;   // 0~65535 → -4π ~ 4π rad
    uint16_t velocity;   // 0~4095  → -30 ~ 30 rad/s
    uint16_t kp;         // 0~4095  → 0 ~ 500
    uint16_t kd;         // 0~4095  → 0 ~ 5
    uint16_t tau_ff;     // 0~4095  → -18 ~ 18 Nm
} MIT_cmd_t;

void pack_MIT_cmd(uint8_t *buf, MIT_cmd_t *cmd) {
    buf[0] = cmd->position >> 8;
    buf[1] = cmd->position & 0xFF;
    buf[2] = cmd->velocity >> 4;
    buf[3] = ((cmd->velocity & 0xF) << 4) | (cmd->kp >> 8);
    buf[4] = cmd->kp & 0xFF;
    buf[5] = cmd->kd >> 4;
    buf[6] = ((cmd->kd & 0xF) << 4) | (cmd->tau_ff >> 8);
    buf[7] = cmd->tau_ff & 0xFF;
}
```

### RX (6 bytes ← 모터에서)
```c
typedef struct {
    uint8_t  id;         // 모터 ID
    uint16_t position;   // 응답 위치
    uint12_t velocity;   // 응답 속도
    uint12_t current;    // 응답 전류
} MIT_resp_t;
```

### 값 변환 함수
```c
float uint_to_float(uint32_t x, float lo, float hi, int bits) {
    float span = hi - lo;
    float offset = lo;
    return ((float)x) * span / ((float)((1<<bits)-1)) + offset;
}
uint32_t float_to_uint(float x, float lo, float hi, int bits) {
    float span = hi - lo;
    return (uint32_t)((x - lo) / span * (float)((1<<bits)-1));
}
```

## 모터 제어 명령 (Enable/Disable/Zero)
```c
void motor_enable(CAN_HandleTypeDef *hcan, uint8_t id) {
    uint8_t buf[8] = {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFC};
    CAN_send(hcan, id, buf, 8);
}
void motor_disable(CAN_HandleTypeDef *hcan, uint8_t id) {
    uint8_t buf[8] = {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFD};
    CAN_send(hcan, id, buf, 8);
}
void motor_set_zero(CAN_HandleTypeDef *hcan, uint8_t id) {
    uint8_t buf[8] = {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFE};
    CAN_send(hcan, id, buf, 8);
}
```

## CAN 버스 디버깅

```bash
# Linux SocketCAN
sudo ip link set can0 up type can bitrate 1000000
candump can0        # 모든 프레임 캡처
cansend can0 001#FFFFFFFFFFFFFFFF  # enable 명령 전송

# 버스 오류 확인
ip -details link show can0 | grep -E "berr|error"
```

## 안전 타임아웃
```c
// CAN 수신 타임아웃 (250ms 기본)
uint32_t last_rx_tick = HAL_GetTick();

void HAL_CAN_RxFifo0MsgPendingCallback(CAN_HandleTypeDef *hcan) {
    last_rx_tick = HAL_GetTick();
    // 메시지 처리
}

// 메인 루프에서:
if (HAL_GetTick() - last_rx_tick > CAN_TIMEOUT_MS) {
    emergency_stop_all();  // 타임아웃 → 비상 정지
}
```
