# p3-spi-i2c.md — SPI/I2C 가이드
# skiro-comm | SPI/I2C 트리거 시 | ~420 tok

## STM32 SPI 설정

```c
// HAL SPI 기본 패턴 (풀링)
uint8_t tx_buf[4], rx_buf[4];
HAL_GPIO_WritePin(CS_PORT, CS_PIN, GPIO_PIN_RESET);  // CS LOW
HAL_SPI_TransmitReceive(&hspi1, tx_buf, rx_buf, 4, HAL_MAX_DELAY);
HAL_GPIO_WritePin(CS_PORT, CS_PIN, GPIO_PIN_SET);    // CS HIGH

// 주의: CS 핀은 HAL이 관리하지 않음 → 수동으로 제어
// DMA 사용 시: HAL_SPI_TransmitReceive_DMA()
```

### 주요 설정 (CubeMX)
```
Mode: Full-Duplex Master
Data Size: 8 Bits
Clock Polarity (CPOL): Low (모드 0/1) or High (모드 2/3)
Clock Phase (CPHA): 1 Edge (모드 0/2) or 2 Edge (모드 1/3)
Prescaler: APB2 / N → 원하는 클럭 주파수
NSS: Software (수동 CS)
```

## STM32 I2C 설정

```c
// HAL I2C 기본 패턴
uint8_t dev_addr = 0x68 << 1;  // 7-bit 주소를 8-bit로 변환
uint8_t reg_addr = 0x3B;
uint8_t data[6];

HAL_I2C_Mem_Read(&hi2c1, dev_addr, reg_addr,
                  I2C_MEMADD_SIZE_8BIT, data, 6, HAL_MAX_DELAY);
```

### 속도 설정
```
Standard Mode: 100 kHz
Fast Mode:     400 kHz (권장)
Fast Mode+:    1 MHz (HAL_I2C_Master_Transmit_DMA 필요)
```

## 공통 디버깅 패턴

```c
// SPI: MISO가 항상 0이면 → CS 극성 확인, CPOL/CPHA 확인
// I2C: HAL_I2C_Master_Transmit 리턴 != HAL_OK → 주소 확인 (7-bit vs 8-bit)
// I2C: 스캔
for(uint8_t addr=1; addr<127; addr++) {
    if(HAL_I2C_IsDeviceReady(&hi2c1, addr<<1, 1, 10) == HAL_OK)
        printf("Found: 0x%02X\r\n", addr);
}
```
