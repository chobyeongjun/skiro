# p1-uart.md — UART 구현 가이드
# skiro-comm | UART 트리거 시 | ~640 tok

## STM32 UART 설정 (HAL)

### CubeMX 설정
```
Connectivity → USARTx → Mode: Asynchronous
  Baud Rate: 115200 (표준), 921600 (고속 디버그)
  Word Length: 8 Bits
  Parity: None
  Stop Bits: 1
  Data Direction: Receive and Transmit
  Over Sampling: 16 Samples

DMA 설정 (UART RX DMA 권장):
  DMA Request: USARTx_RX
  Direction: Peripheral To Memory
  Mode: Circular (연속 수신)
  Data Width: Byte
```

### printf 리디렉션 (NUCLEO-L432KC)
```c
// syscalls.c 또는 main.c
#ifdef __GNUC__
int __io_putchar(int ch) {
    HAL_UART_Transmit(&huart2, (uint8_t*)&ch, 1, HAL_MAX_DELAY);
    return ch;
}
#endif
// 주의: HAL_MAX_DELAY = ISR 내부 금지
// 디버그 전용, 타이밍 크리티컬 코드에 사용 금지
```

### DMA 기반 비블로킹 수신
```c
// 링 버퍼 패턴 (IDLE line 감지 + DMA)
HAL_UARTEx_ReceiveToIdle_DMA(&huart2, rx_buf, RX_BUF_SIZE);

void HAL_UARTEx_RxEventCallback(UART_HandleTypeDef *huart, uint16_t Size) {
    if (huart->Instance == USART2) {
        parse_packet(rx_buf, Size);
        HAL_UARTEx_ReceiveToIdle_DMA(&huart2, rx_buf, RX_BUF_SIZE);
    }
}
```

## NUCLEO-L432KC 핀 매핑
```
USART2: PA2(TX) / PA15(RX) — ST-Link 가상 COM 연결
        115200 baud, PuTTY COM4
USART1: PA9(TX) / PA10(RX) — 외부 장치용
```

## 일반 디버그 패턴
```c
// 타임스탬프 포함 로그
printf("[%lu] VAL=%.3f STAT=%d\r\n", HAL_GetTick(), value, status);

// 16진수 버퍼 덤프
for(int i=0; i<len; i++) printf("%02X ", buf[i]);
printf("\r\n");
```
