# p1-comm-test.md — 통신 테스트
# skiro-hwtest | always load | ~520 tok

## CAN 버스 통신 확인

```bash
# Linux (SocketCAN)
ip link show can0
candump can0 -n 10   # 10 프레임 수신 확인

# STM32 (HAL)
# UART → 별도 터미널에서 수신 확인
# CAN loopback test (내부 루프백 모드)
hcan.Init.Mode = CAN_MODE_LOOPBACK;
```

**합격 기준**: 10 프레임 내 에러 없이 수신, 버스 OFF 상태 아님.

## UART/시리얼 통신 확인

```bash
# Linux
cat /dev/ttyUSB0    # 또는 ttyACM0
stty -F /dev/ttyUSB0 115200

# Windows (PuTTY)
# COM4, 115200, 8N1, 흐름제어 없음
```

**합격 기준**: `printf` 출력이 터미널에 정상 수신됨.

## USB / 이더넷 연결 확인

```bash
# Jetson
ping chobb0-jetson.local
ssh chobb0@chobb0-jetson.local "echo connected"

# ZED 카메라
python3 -c "import pyzed.sl as sl; cam=sl.Camera(); print(cam.open())"
```

## 통신 테스트 결과 기록

```
[HWTEST] 통신 확인
  CAN: OK / FAIL (에러: <내용>)
  UART: OK / FAIL
  USB/ETH: OK / FAIL
  전체: PASS / FAIL
```
