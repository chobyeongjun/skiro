---
description: "통신 프로토콜 설계/디버깅. CAN, UART, SPI, I2C, ROS2 DDS. 키워드: CAN, 통신, 프로토콜, UART, 시리얼, 패킷, SPI, I2C, ROS2, DDS, baudrate"
---

# skiro-comm — SKILL.md core
# v0.5 MS4 | ~400 tok

## 역할
로봇 시스템의 통신 프로토콜 설계·구현·디버깅을 지원한다.
CAN, UART, SPI, I2C, Ethernet(ROS2 DDS)을 포괄한다.

## 트리거 감지
```
"CAN", "통신", "프로토콜", "UART", "시리얼", "패킷", "버스",
"SPI", "I2C", "ROS2 topic", "DDS", "baudrate", "ID", "메시지 구조"
```

## Phase 0 — 프로토콜 분류 & 모듈 로딩

| 프로토콜 | 조건 | 로드 |
|---------|------|------|
| UART/시리얼 | UART, printf, serial | p1-uart.md |
| CAN | CAN, AK60, 모터 통신 | p2-can.md |
| SPI/I2C | 센서, ADC, IMU | p3-spi-i2c.md |
| ROS2/DDS | ROS2, topic, pub/sub | p4-ros2.md |

복수 프로토콜 사용 시 해당 파일 모두 로드.
