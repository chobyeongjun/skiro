---
name: skiro-comm
description: |
  Robot communication setup and debugging. Handles BLE (bleak), WiFi
  (TCP/UDP/MQTT), and USB Serial (pyserial) connections between robot
  hardware and desktop software. Includes protocol design, packet
  parsing, and GUI integration patterns (QThread + signal/slot).
  For communication layer only — NOT for GUI layout (/skiro-gui),
  data analysis (/skiro-analyze), or firmware upload (/skiro-flash).
  Keywords (EN/KR): BLE/블루투스, WiFi/와이파이, serial/시리얼,
  통신, 무선, 연결, 끊김, bleak, socket/소켓, MQTT, pyserial,
  protocol/프로토콜, packet/패킷, notify, baud rate/보드레이트,
  로봇 연결, 데이터 전송, 수신. (skiro)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - WebSearch
  - AskUserQuestion
---

Read VOICE.md before responding.

## Phase 0: Communication Discovery

1. Check existing communication code:
   ```bash
   grep -rl "bleak\|BleakClient\|asyncio.*ble\|bluetooth" . --include="*.py" 2>/dev/null | head -5
   grep -rl "socket\|mqtt\|paho" . --include="*.py" 2>/dev/null | head -5
   grep -rl "serial\|pyserial\|Serial(" . --include="*.py" --include="*.ino" --include="*.cpp" 2>/dev/null | head -5
   ```
2. Read hardware.yaml for `communication:` section.
3. Load learnings for "ble", "wifi", "serial", "communication" tags.

AskUserQuestion: "What communication method does your robot use?"
A) BLE (Bluetooth Low Energy)
B) WiFi (TCP/UDP/MQTT)
C) USB Serial
D) Multiple (describe)
E) Not sure — help me choose

### Communication Selection Guide:
| Method | Best for | Range | Bandwidth | Latency |
|--------|---------|-------|-----------|---------|
| BLE | Wearable/portable robots, low power | ~10m | ~1 Mbps | 10-30ms |
| WiFi TCP | Reliable data, file transfer | ~50m | ~100 Mbps | 5-20ms |
| WiFi UDP | Low-latency control, streaming | ~50m | ~100 Mbps | 1-5ms |
| MQTT | IoT, pub/sub, multiple clients | WAN | varies | 50-200ms |
| USB Serial | Tethered MCU, debugging, highest reliability | cable | ~1 Mbps | <1ms |

## Phase 1: BLE (Bluetooth Low Energy)

### Scanning + Connection (bleak library)
```python
"""BLE robot communication. Requires: pip install bleak"""
import asyncio
from bleak import BleakClient, BleakScanner

async def scan_devices(timeout=5.0):
    """Scan for nearby BLE devices."""
    devices = await BleakScanner.discover(timeout=timeout)
    for d in devices:
        print(f"  {d.name or 'Unknown'} [{d.address}] RSSI={d.rssi}")
    return devices

async def connect_and_discover(address: str):
    """Connect and list all services/characteristics."""
    async with BleakClient(address) as client:
        print(f"Connected: {client.is_connected}")
        for service in client.services:
            print(f"Service: {service.uuid}")
            for char in service.characteristics:
                props = ", ".join(char.properties)
                print(f"  Char: {char.uuid} [{props}]")
        return client.services
```

### Read / Write / Notify
```python
# UUIDs — must match firmware (Arduino BLE, nRF, ESP32 BLE)
SERVICE_UUID = "0000ffe0-0000-1000-8000-00805f9b34fb"
CHAR_TX_UUID = "0000ffe1-0000-1000-8000-00805f9b34fb"  # Robot → PC (notify)
CHAR_RX_UUID = "0000ffe2-0000-1000-8000-00805f9b34fb"  # PC → Robot (write)

async def start_notify(client: BleakClient, callback):
    """Subscribe to notifications from robot."""
    await client.start_notify(CHAR_TX_UUID, callback)

def on_data_received(sender, data: bytearray):
    """Callback: parse incoming BLE data."""
    # data is raw bytes — parse according to your protocol
    values = struct.unpack('<fff', data[:12])  # Example: 3 floats
    print(f"Received: {values}")

async def send_command(client: BleakClient, cmd: bytes):
    """Send command to robot."""
    await client.write_gatt_char(CHAR_RX_UUID, cmd, response=True)
```

### BLE Reconnection Pattern
```python
import asyncio
from bleak import BleakClient

class BLEConnection:
    """Robust BLE connection with auto-reconnect."""
    def __init__(self, address, on_data, on_disconnect=None):
        self.address = address
        self.on_data = on_data
        self.on_disconnect = on_disconnect
        self.client = None
        self._running = False

    async def connect(self, max_retries=5, retry_delay=2.0):
        for attempt in range(max_retries):
            try:
                self.client = BleakClient(
                    self.address,
                    disconnected_callback=self._handle_disconnect
                )
                await self.client.connect()
                await self.client.start_notify(CHAR_TX_UUID, self.on_data)
                self._running = True
                print(f"BLE connected (attempt {attempt + 1})")
                return True
            except Exception as e:
                print(f"BLE connect failed: {e}, retry in {retry_delay}s")
                await asyncio.sleep(retry_delay)
        return False

    def _handle_disconnect(self, client):
        self._running = False
        if self.on_disconnect:
            self.on_disconnect()
        # Auto-reconnect in background
        asyncio.ensure_future(self.connect())

    async def send(self, data: bytes):
        if self.client and self.client.is_connected:
            await self.client.write_gatt_char(CHAR_RX_UUID, data, response=True)

    async def disconnect(self):
        self._running = False
        if self.client:
            await self.client.disconnect()
```

### Common BLE Issues:
| Problem | Cause | Fix |
|---------|-------|-----|
| "Device not found" | Device not advertising or out of range | Check firmware BLE advertising code, reduce distance |
| "Service not found" | UUID mismatch between firmware and Python | Print discovered services, compare UUIDs |
| Notify stops working | MTU too small or connection dropped | Set `mtu_size` in connect, add reconnect logic |
| Data corruption | Packet split across BLE frames | Add packet framing (start/end markers) |
| Slow throughput | Default MTU (23 bytes) | Request larger MTU: `await client.mtu_size` |

## Phase 2: WiFi Communication

### TCP Client (reliable, ordered)
```python
import socket

def tcp_connect(host: str, port: int):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((host, port))
    sock.settimeout(5.0)  # 5s timeout
    return sock

def tcp_send_receive(sock, data: bytes) -> bytes:
    sock.sendall(data)
    return sock.recv(4096)
```

### UDP Client (low-latency, no guarantee)
```python
import socket

def udp_send(host: str, port: int, data: bytes):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(data, (host, port))

def udp_receive(port: int, timeout=1.0) -> bytes:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(('', port))
    sock.settimeout(timeout)
    data, addr = sock.recvfrom(4096)
    return data
```

### MQTT (pub/sub, multiple clients)
```python
"""MQTT communication. Requires: pip install paho-mqtt"""
import paho.mqtt.client as mqtt

client = mqtt.Client()
client.connect("broker_ip", 1883)

# Subscribe to robot data
client.subscribe("robot/sensors")
client.on_message = lambda c, u, msg: print(f"{msg.topic}: {msg.payload}")

# Publish commands
client.publish("robot/cmd", b"start")
client.loop_start()
```

## Phase 3: USB Serial

```python
"""Serial communication. Requires: pip install pyserial"""
import serial
import struct

def serial_connect(port: str, baud: int = 115200) -> serial.Serial:
    ser = serial.Serial(port, baud, timeout=1.0)
    return ser

def serial_read_line(ser) -> str:
    """For text-based protocols (CSV-like)."""
    return ser.readline().decode('ascii', errors='ignore').strip()

def serial_read_packet(ser, header=b'\xAA\x55', payload_len=12) -> bytes:
    """For binary protocols with known header."""
    while True:
        if ser.read(1) == header[0:1]:
            if ser.read(1) == header[1:2]:
                return ser.read(payload_len)
```

**Port auto-detection:**
```bash
# macOS
ls /dev/cu.usb* /dev/tty.usb* 2>/dev/null
# Linux
ls /dev/ttyACM* /dev/ttyUSB* 2>/dev/null
```

## Phase 4: Protocol Design

When designing a custom communication protocol:

### Packet Structure
```
[HEADER][LENGTH][CMD_ID][PAYLOAD][CHECKSUM]
 2 bytes  1 byte  1 byte  N bytes   1 byte
```

```python
import struct

def build_packet(cmd_id: int, payload: bytes) -> bytes:
    header = b'\xAA\x55'
    length = len(payload)
    checksum = (cmd_id + length + sum(payload)) & 0xFF
    return header + struct.pack('<BB', length, cmd_id) + payload + bytes([checksum])

def parse_packet(raw: bytes) -> tuple[int, bytes]:
    if raw[:2] != b'\xAA\x55':
        raise ValueError("Invalid header")
    length, cmd_id = struct.unpack('<BB', raw[2:4])
    payload = raw[4:4+length]
    checksum = raw[4+length]
    expected = (cmd_id + length + sum(payload)) & 0xFF
    if checksum != expected:
        raise ValueError(f"Checksum mismatch: {checksum} != {expected}")
    return cmd_id, payload
```

### Common Robot Protocol Commands:
| CMD_ID | Name | Payload | Description |
|--------|------|---------|-------------|
| 0x01 | MOTOR_CMD | float32 × N | Torque/position commands |
| 0x02 | SENSOR_DATA | float32 × N | Sensor readings from robot |
| 0x03 | STATUS | uint8 | Robot state (IDLE/RUN/ERROR) |
| 0x04 | CONFIG | key-value | Parameter update |
| 0x05 | E_STOP | none | Emergency stop |
| 0xFF | HEARTBEAT | uint32 timestamp | Keep-alive |

## Phase 5: GUI Integration

### BLE + PyQt5 (QThread pattern)
```python
from PyQt5.QtCore import QThread, pyqtSignal
import asyncio

class BLEWorker(QThread):
    """Run BLE event loop in background thread."""
    data_received = pyqtSignal(bytes)  # Signal to GUI thread
    connection_changed = pyqtSignal(bool)

    def __init__(self, address):
        super().__init__()
        self.address = address
        self._loop = None

    def run(self):
        self._loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self._loop)
        self._loop.run_until_complete(self._ble_main())

    async def _ble_main(self):
        conn = BLEConnection(
            self.address,
            on_data=lambda s, d: self.data_received.emit(bytes(d)),
            on_disconnect=lambda: self.connection_changed.emit(False)
        )
        connected = await conn.connect()
        self.connection_changed.emit(connected)
        # Keep running until thread is stopped
        while not self.isInterruptionRequested():
            await asyncio.sleep(0.1)
        await conn.disconnect()

# In MainWindow:
# self.ble_worker = BLEWorker("AA:BB:CC:DD:EE:FF")
# self.ble_worker.data_received.connect(self.on_ble_data)
# self.ble_worker.connection_changed.connect(self.on_ble_status)
# self.ble_worker.start()
```

### Serial + PyQt5 (QThread pattern)
```python
class SerialWorker(QThread):
    data_received = pyqtSignal(str)  # or bytes
    error_occurred = pyqtSignal(str)

    def __init__(self, port, baud=115200):
        super().__init__()
        self.port = port
        self.baud = baud

    def run(self):
        try:
            ser = serial.Serial(self.port, self.baud, timeout=0.1)
            while not self.isInterruptionRequested():
                line = ser.readline().decode('ascii', errors='ignore').strip()
                if line:
                    self.data_received.emit(line)
            ser.close()
        except Exception as e:
            self.error_occurred.emit(str(e))
```

## Phase 6: Troubleshooting

| Symptom | Check | Fix |
|---------|-------|-----|
| No BLE devices found | Is device advertising? | Check firmware `BLE.advertise()` |
| BLE connected but no data | Notify not started | `start_notify()` on correct UUID |
| Serial port busy | Another process using it | `lsof /dev/cu.usbmodem*` |
| WiFi timeout | Firewall blocking port | Check `iptables`/firewall rules |
| Data garbled | Baud rate mismatch | Match firmware and Python baud |
| Packets split | No framing protocol | Add header/length/checksum |

## Phase 7: Next Step

- Communication working → /skiro-gui for control interface
- Need data logging → /skiro-data
- Pre-experiment check → /skiro-safety

## Wrong Skill? Redirect
If the user's request does not match this skill, DO NOT attempt it.
Instead, explain what this skill does and redirect to the correct one:
- Want to build a GUI (layout, widgets, styling)? → "/skiro-gui handles desktop GUI development. This skill only handles the communication backend."
- Want to analyze data? → "/skiro-analyze does RMSE, FFT, statistics."
- Want to flash firmware? → "/skiro-flash builds and uploads firmware to MCU."
- Want to verify code safety? → "/skiro-safety audits limits, watchdog, e-stop, timing."
- Want to test hardware? → "/skiro-hwtest generates and runs hardware test scripts."
- Want to plan an experiment? → "/skiro-plan handles experiment design and brainstorming."
- Want to manage data files? → "/skiro-data handles data collection, validation, and format conversion."
- Want gait analysis? → "/skiro-gait does gait cycle, heel strike, temporal-spatial parameters."
- Want experiment retrospective? → "/skiro-retro summarizes results and generates paper packets."
