# Skiro Safety Checklist

Universal safety verification for robot software. Adapt thresholds via hardware.yaml.

## CRITICAL (must pass, blocks /skiro-flash)

### 1. Actuator Limits
- [ ] Every motor/actuator command has max value check BEFORE sending
- [ ] Limits match datasheet specs (from hardware.yaml or verified manually)
- [ ] Rate limiter exists: no instant jumps from 0 to max
- [ ] Evidence: cite file:line for each limit check

### 2. Emergency Stop
- [ ] E-stop path exists (hardware preferred, software as backup)
- [ ] E-stop sets all actuator commands to zero/safe state
- [ ] E-stop reachable from every control state
- [ ] E-stop does NOT require communication to work

### 3. Watchdog / Communication Timeout
- [ ] No command within timeout -> auto-stop
- [ ] Timeout value defined and reasonable (typically 100ms or less)
- [ ] Serial/CAN/network loss -> graceful degradation, not crash

### 4. State Machine Integrity
- [ ] All states defined (IDLE, CALIBRATING, RUNNING, E_STOP, ERROR)
- [ ] No undefined state transitions possible
- [ ] ERROR state recoverable only through explicit reset

## WARNING (should fix, does not block)

### 5. Control Loop Timing
- [ ] No blocking calls inside control loop (sleep, print, malloc, file I/O)
- [ ] No dynamic memory allocation in real-time path
- [ ] Loop frequency is measured, not assumed

### 6. Sensor Validation
- [ ] Sensor readings are range-checked (NaN, zero, out-of-range)
- [ ] Calibration values loaded, not hardcoded
- [ ] Sensor failure detected (stuck value, noise spike)

### 7. Communication Protocol
- [ ] Message format has checksum/CRC
- [ ] Byte order is explicit (little/big endian)
- [ ] Buffer overflow protection on receive
- [ ] Message IDs do not conflict (especially CAN bus)

### 8. Units and Constants
- [ ] All physical quantities have units in comments (N, rad, m/s, Nm, Hz)
- [ ] No magic numbers, all constants named and documented
- [ ] Coordinate frames documented

## INFO (nice to have)

### 9. Code Quality
- [ ] Functions are single-purpose and testable
- [ ] Error handling exists (not just happy path)
- [ ] Logging sufficient for post-experiment debugging
- [ ] Configuration is external (yaml/json), not hardcoded
