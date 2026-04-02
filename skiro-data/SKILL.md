---
name: skiro-data
description: |
  Robot experiment data management. Validates data integrity (timestamps,
  NaN, gaps, sample rate), converts formats (CSV, ROS bag, HDF5, binary),
  organizes experiment files, and audits datasets. For robot/sensor data
  from MCU or ROS — NOT for web APIs, databases, or business data.
  Use when validating sensor logs, organizing experiment files, converting
  formats, or auditing existing datasets.
  Keywords (EN/KR): data management/데이터 관리, validation/검증,
  CSV, ROS bag, HDF5, format conversion/포맷 변환, 데이터 정리,
  integrity/무결성, sample rate/샘플링 주파수, NaN, 실험 데이터,
  SD 카드, 다운로드, 파일 정리, 데이터셋. (skiro)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
---

Read VOICE.md before responding.

## Phase 0: Context

1. Read hardware.yaml for MCU, sensors, sample rates, interfaces.
   No hardware.yaml: proceed, but warn "Run /skiro-hwtest first for full validation."
2. Detect data format: scan target directory for file extensions.
   ```bash
   ls *.csv *.bag *.db3 *.h5 *.hdf5 *.bin *.dat 2>/dev/null | head -20
   ```
3. Load learnings for "data", "csv", "download" tags.
4. Read `references/data-formats.md` for format-specific parsing patterns.

## Phase 1: Data Source

AskUserQuestion: "Where is your data coming from?"
A) SD card on MCU (download via USB Serial)
B) Local files already on disk
C) ROS bag recording
D) Live serial capture
E) Other (describe)

## Phase 2: Data Collection

### A) SD Card Download
1. Check if logging is active (if MCU firmware supports query).
   If active: "Stop logging before downloading to prevent corruption."
2. **Determine serial protocol first:**
   - Check project firmware code for SD transfer commands (grep for "LIST", "GET", "ls", "cat")
   - If found: use project's protocol
   - If not found: AskUserQuestion "What serial commands does your firmware use for SD file transfer? (e.g., `ls`, `get <filename>`, or XModem?)"
3. Detect serial port:
   ```bash
   ls /dev/tty.usb* /dev/cu.usb* /dev/ttyACM* /dev/ttyUSB* 2>/dev/null
   ```
4. List files on SD using the detected protocol.
5. AskUserQuestion: "Which files to download?" [show file list]
6. Download via pyserial — handle EOF/end-of-transfer markers.
7. Verify: file size matches expected, basic parse check.

### B) Local Files
1. List files in specified directory.
2. Detect format from extension and content.
3. Proceed directly to Phase 3 (validation).

### C) ROS Bag
1. Detect bag format:
   ```bash
   # ROS 2 (SQLite3-based .db3)
   file *.db3 2>/dev/null
   # ROS 1 (.bag)
   file *.bag 2>/dev/null
   ```
2. Get bag info:
   ```bash
   # ROS 2 (if ros2 installed)
   ros2 bag info <path> 2>/dev/null
   # Fallback: use rosbags (no ROS install needed)
   python3 -c "
   from rosbags.rosbag2 import Reader
   with Reader('<path>') as reader:
       for conn in reader.connections:
           print(f'{conn.topic} [{conn.msgtype}] — {conn.msgcount} msgs')
       print(f'Duration: {(reader.duration)/1e9:.1f}s')
   "
   ```
3. AskUserQuestion: "Which topics to extract?" [show topic list]
4. Extract to CSV using `rosbags` (works without ROS installation):

**ROS 2 bag → CSV extraction (rosbags library):**
```python
"""Extract ROS 2 bag topics to CSV. Requires: pip install rosbags"""
import csv
from pathlib import Path
from rosbags.rosbag2 import Reader
from rosbags.typesys import get_typestore, Stores

def extract_topic_to_csv(bag_path: str, topic: str, output_csv: str):
    """Extract a single topic from ROS 2 bag to CSV."""
    typestore = get_typestore(Stores.ROS2_HUMBLE)  # or ROS2_IRON, ROS2_JAZZY
    
    rows = []
    with Reader(bag_path) as reader:
        # Register custom types if needed
        reader.open()
        connections = [c for c in reader.connections if c.topic == topic]
        if not connections:
            raise ValueError(f"Topic '{topic}' not found. Available: "
                           f"{[c.topic for c in reader.connections]}")
        
        for conn, timestamp, rawdata in reader.messages(connections=connections):
            msg = typestore.deserialize_cdr(rawdata, conn.msgtype)
            row = {"timestamp_ns": timestamp}
            # Flatten message fields recursively
            _flatten_msg(msg, "", row)
            rows.append(row)
    
    # Write CSV
    if rows:
        with open(output_csv, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=rows[0].keys())
            writer.writeheader()
            writer.writerows(rows)
        print(f"Wrote {len(rows)} rows to {output_csv}")
    return rows

def _flatten_msg(msg, prefix, row):
    """Recursively flatten a ROS message into a flat dict."""
    import numpy as np
    for field_name in msg.__dataclass_fields__:
        val = getattr(msg, field_name)
        key = f"{prefix}{field_name}" if prefix else field_name
        if hasattr(val, "__dataclass_fields__"):
            _flatten_msg(val, f"{key}.", row)  # Nested message
        elif isinstance(val, (np.ndarray, list, tuple)):
            for i, v in enumerate(val):
                row[f"{key}[{i}]"] = float(v) if isinstance(v, (int, float, np.number)) else str(v)
        else:
            row[key] = val

# Usage:
# extract_topic_to_csv("rosbag2_dir/", "/imu/data", "imu_data.csv")
# extract_topic_to_csv("rosbag2_dir/", "/joint_states", "joints.csv")
```

**ROS 1 bag → CSV extraction:**
```python
"""Extract ROS 1 bag topics to CSV. Requires: pip install rosbags"""
from rosbags.rosbag1 import Reader as Reader1
from rosbags.typesys import get_typestore, Stores

def extract_ros1_topic(bag_path: str, topic: str, output_csv: str):
    typestore = get_typestore(Stores.ROS1_NOETIC)
    rows = []
    with Reader1(bag_path) as reader:
        connections = [c for c in reader.connections.values() if c.topic == topic]
        for conn, timestamp, rawdata in reader.messages(connections=connections):
            msg = typestore.deserialize_ros1(rawdata, conn.msgtype)
            row = {"timestamp_ns": timestamp}
            _flatten_msg(msg, "", row)
            rows.append(row)
    # Same CSV write logic as above
```

**Common message types and expected columns:**
| Message Type | Key Columns |
|-------------|-------------|
| sensor_msgs/Imu | angular_velocity.{x,y,z}, linear_acceleration.{x,y,z}, orientation.{x,y,z,w} |
| sensor_msgs/JointState | position[i], velocity[i], effort[i] |
| geometry_msgs/WrenchStamped | wrench.force.{x,y,z}, wrench.torque.{x,y,z} |
| std_msgs/Float64MultiArray | data[0], data[1], ... |
| nav_msgs/Odometry | pose.position.{x,y,z}, twist.linear.{x,y,z} |

5. After extraction: auto-proceed to Phase 3 (integrity validation) on all generated CSVs.

### D) Serial Capture
1. Detect serial port: `ls /dev/tty* | grep -i "usb\|acm\|teensy"`
2. Confirm baud rate (from hardware.yaml or ask).
3. Start capture → file.
4. AskUserQuestion: "Recording... Press enter to stop."

## Phase 3: Data Integrity Validation

Run these checks on every data file. Report as a table.

| Check | Method | Severity |
|-------|--------|----------|
| Header present | First row contains non-numeric text | ERROR if missing |
| Column count consistent | All rows same column count | ERROR if mismatch |
| NaN/Inf detection | `np.isnan` or string "nan" per column | WARNING, report % |
| Timestamp continuity | `diff(time)` > 5× median(diff) | WARNING, report gaps |
| Sample rate consistency | `1/median(diff(time))` ± 10% | WARNING |
| Stuck sensor | Same value > 100 consecutive samples | WARNING |
| Range violation | Value outside sensor spec (from hardware.yaml) | WARNING |
| File not empty | At least 10 data rows | ERROR |
| Time reversal | time[i+1] < time[i] (timer overflow) | ERROR |
| File truncation | Last row has fewer columns than header | WARNING |
| Encoding error | Non-UTF8 bytes or BOM present | WARNING |
| Duplicate timestamps | time[i] == time[i+1] | WARNING |

Format output as integrity report:
```
=== Data Integrity Report ===
File: experiment_01.csv
Columns: 45 (all present)
Rows: 50,000
Duration: 450.5 s
Sample rate: 111.0 ± 0.5 Hz
Issues:
  - WARNING: NaN in column "Force_N" — 12 values (0.024%)
  - WARNING: Timestamp gap at row 23,456 (45ms gap, expected 9ms)
Overall: PASS (2 warnings)
```

## Phase 4: File Organization

Suggest naming convention: `YYMMDD_SubjectID_Condition_Trial.{ext}`

Suggest directory structure:
```
data/
├── raw/          # Original (never modify)
├── processed/    # Cleaned data
└── analysis/     # Figures, tables
```

AskUserQuestion: "Want me to rename and organize these files?"
A) Yes, auto-organize
B) Just suggest, I'll do it manually
C) Skip

## Phase 5: Summary + Next Step

Report:
- Files collected: count, total size, total duration
- Issues found: count by severity
- Files organized: new paths

Log any data issues as learnings via skiro-learnings add.

Next step suggestions:
- Data looks clean → /skiro-analyze or /skiro-gait
- Data has issues → fix and re-validate
- Need more data → plan next experiment with /skiro-spec
