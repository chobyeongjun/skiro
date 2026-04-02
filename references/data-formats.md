# Robot Data Formats Guide

Reference for parsing, validating, and managing robot experiment data.
Read this when working with /skiro-data.

## CSV Data

### Auto-Detection
1. Read first line → if contains letters, it's a header
2. Detect delimiter: try comma, tab, semicolon, space (in order)
3. Count columns in header vs first data row — must match
4. Detect time column: look for "time", "timestamp", "t", "Time_ms" (case-insensitive)

### Common Column Naming Patterns
| Pattern | Meaning | Example |
|---------|---------|---------|
| `Des` or `Desired` | Setpoint/command | L_DesForce_N |
| `Act` or `Actual` | Measured value | L_ActForce_N |
| `Err` or `Error` | Tracking error | L_ErrForce_N |
| `_N` suffix | Force in Newtons | L_ActForce_N |
| `_Nm` suffix | Torque in Newton-meters | L_Torque_Nm |
| `_deg` suffix | Angle in degrees | L_ActPos_deg |
| `_rad` suffix | Angle in radians | Joint1_rad |
| `_mps` suffix | Velocity in m/s | L_ActVel_mps |
| `_A` suffix | Current in Amperes | L_ActCurr_A |
| `_Hz` suffix | Frequency | Freq_Hz |
| `L_` / `R_` prefix | Left / Right side | L_GCP, R_GCP |
| `_x` / `_y` / `_z` suffix | Axis | Accel_x, Accel_y |

### Validation Rules
| Check | Condition | Severity |
|-------|-----------|----------|
| NaN/Inf | Any column has NaN or Inf | WARNING |
| Timestamp gap | Gap > 5× expected period | WARNING |
| Sample rate drift | mean period ± 10% | WARNING |
| Stuck sensor | Same value for > 100 consecutive samples | WARNING |
| Range violation | Value outside sensor range (from hardware.yaml) | WARNING |
| Missing columns | Expected column not found | ERROR |
| Empty file | No data rows | ERROR |
| Corrupted row | Column count mismatch | ERROR |

### Sample Rate Estimation
```python
# From timestamp column (assuming milliseconds)
dt = np.diff(time_ms)
estimated_hz = 1000.0 / np.median(dt)
# Use median, not mean (robust to gaps)
```

## ROS Bag Data

### ROS 2 (mcap / db3)
```bash
# List topics
ros2 bag info <bag_path>

# Extract to CSV
ros2 bag play <bag_path> --read-ahead-queue-size 1000
# Or use rosbag2 Python API:
# from rosbags.rosbag2 import Reader
# from rosbags.typesys import get_typestore
```

### ROS 1 (legacy .bag)
```bash
# List topics
rosbag info file.bag

# Extract specific topic to CSV
rostopic echo -b file.bag -p /imu/data > imu_data.csv
```

### Common ROS Topics for Robots
| Topic pattern | Message type | Contains |
|--------------|-------------|----------|
| `/imu/data` | sensor_msgs/Imu | orientation, angular_vel, linear_accel |
| `/joint_states` | sensor_msgs/JointState | position, velocity, effort |
| `/cmd_vel` | geometry_msgs/Twist | linear, angular velocity command |
| `/odom` | nav_msgs/Odometry | pose, twist |
| `/force_torque` | geometry_msgs/WrenchStamped | force xyz, torque xyz |
| `/camera/image_raw` | sensor_msgs/Image | raw image |
| `/tf` | tf2_msgs/TFMessage | transforms |

## HDF5 Data

### Structure Exploration
```python
import h5py
with h5py.File('data.h5', 'r') as f:
    def print_tree(name, obj):
        print(name, type(obj).__name__, getattr(obj, 'shape', ''))
    f.visititems(print_tree)
```

### Common HDF5 Layouts for Robot Data
- Flat: `/time`, `/force`, `/position` (each a 1D or 2D array)
- Grouped: `/experiment/trial_01/force`, `/experiment/trial_01/imu`
- Timestamped: `/2024-01-15/trial_1/data`

## MATLAB .mat Data

### Reading .mat Files
```python
# For .mat v5 (MATLAB ≤ 7.2) — use scipy
import scipy.io
mat = scipy.io.loadmat('data.mat')
# mat is a dict: keys = variable names, values = numpy arrays
# Skip metadata keys starting with '__'
for key in mat:
    if not key.startswith('__'):
        print(f"{key}: shape={mat[key].shape}, dtype={mat[key].dtype}")

# For .mat v7.3 (HDF5-based, MATLAB ≥ 7.3) — use h5py
import h5py
with h5py.File('data.mat', 'r') as f:
    for key in f.keys():
        print(f"{key}: shape={f[key].shape}")
    data = f['force'][:]  # Load into numpy array
```

### Common .mat Structures in Biomechanics
| Variable pattern | Meaning | Shape |
|-----------------|---------|-------|
| `data` or `trial_data` | Main data matrix | (N_samples, N_channels) |
| `time` or `t` | Timestamp vector | (N_samples, 1) |
| `labels` or `ch_names` | Channel names | (1, N_channels) cell array |
| `fs` or `Fs` or `srate` | Sample rate (Hz) | scalar |
| `events` or `markers` | Event timestamps | (N_events, 1) |

### .mat → CSV Conversion
```python
import scipy.io
import pandas as pd
import numpy as np

mat = scipy.io.loadmat('data.mat')
data = mat['data']  # (N, M) array
# Channel names: .mat stores as nested array
labels = [str(l[0]) for l in mat['labels'][0]]
df = pd.DataFrame(data, columns=labels)
df.to_csv('data.csv', index=False)
```

### Pitfalls
- MATLAB 1-indexed → Python 0-indexed (event timestamps!)
- `.mat` cell arrays become nested numpy object arrays
- `.mat v7.3` requires h5py, NOT scipy.io.loadmat
- Strings in `.mat` are stored as uint16 arrays (decode needed)

## EDF/BDF (European Data Format / BioSemi Data Format)

Standard formats for biosignal recording (EMG, EEG, EOG).
EDF = 16-bit, BDF = 24-bit (higher resolution).

### Reading EDF/BDF
```python
# Requires: pip install mne  (or pip install pyedflib)
import mne

# MNE (recommended — handles both EDF and BDF)
raw = mne.io.read_raw_edf('data.edf', preload=True)  # or read_raw_bdf
print(f"Channels: {raw.ch_names}")
print(f"Sample rate: {raw.info['sfreq']} Hz")
print(f"Duration: {raw.times[-1]:.1f} s")

# Get data as numpy array
data = raw.get_data()  # shape: (n_channels, n_samples)
times = raw.times       # shape: (n_samples,)

# Extract specific channels
emg_data = raw.copy().pick_channels(['EMG1', 'EMG2']).get_data()
```

### Alternative: pyedflib (lighter than MNE)
```python
import pyedflib
f = pyedflib.EdfReader('data.edf')
n_channels = f.signals_in_file
labels = f.getSignalLabels()
fs = [f.getSampleFrequency(i) for i in range(n_channels)]
# Note: EDF allows different sample rates per channel!
signals = [f.readSignal(i) for i in range(n_channels)]
f.close()
```

### EDF/BDF Characteristics
| Feature | EDF | BDF |
|---------|-----|-----|
| Resolution | 16-bit | 24-bit |
| Extension | `.edf` | `.bdf` |
| Max channels | 256 (header limited) | 256 |
| Per-channel sample rate | Yes (different per channel) | Yes |
| Annotations | EDF+ only | BDF+ only |

### EDF → CSV Conversion
```python
import mne
import pandas as pd

raw = mne.io.read_raw_edf('data.edf', preload=True)
df = pd.DataFrame(raw.get_data().T, columns=raw.ch_names)
df.insert(0, 'time_s', raw.times)
df.to_csv('data.csv', index=False)
```

## MCAP (ROS 2 Modern Log Format)

MCAP is the default recording format for ROS 2 (replacing db3).
High-performance, self-contained, supports multiple serializations.

### Reading MCAP
```python
# Requires: pip install mcap mcap-ros2-support
from mcap_ros2.reader import read_ros2_messages

# List topics and message counts
from mcap.reader import make_reader
with open('data.mcap', 'rb') as f:
    reader = make_reader(f)
    summary = reader.get_summary()
    for channel_id, channel in summary.channels.items():
        schema = summary.schemas[channel.schema_id]
        print(f"  {channel.topic} [{schema.name}]")

# Read messages from specific topic
for msg in read_ros2_messages('data.mcap', topics=['/imu/data']):
    imu = msg.ros_msg
    print(f"t={msg.log_time_ns/1e9:.3f} "
          f"ax={imu.linear_acceleration.x:.3f}")
```

### MCAP → CSV Conversion
```python
from mcap_ros2.reader import read_ros2_messages
import pandas as pd

rows = []
for msg in read_ros2_messages('data.mcap', topics=['/joint_states']):
    js = msg.ros_msg
    row = {'time_ns': msg.log_time_ns}
    for i, name in enumerate(js.name):
        row[f'{name}_pos'] = js.position[i]
        row[f'{name}_vel'] = js.velocity[i]
        row[f'{name}_eff'] = js.effort[i]
    rows.append(row)
df = pd.DataFrame(rows)
df.to_csv('joint_states.csv', index=False)
```

### MCAP vs db3
| Feature | MCAP | SQLite db3 |
|---------|------|-----------|
| Performance | Fast (memory-mapped) | Slower (SQL queries) |
| File size | Smaller (compression) | Larger |
| Self-contained | Yes (schema embedded) | Needs metadata.yaml |
| Seeking | O(1) indexed | O(n) scan |
| ROS 2 default | Humble+ | Foxy/Galactic |

## Serial Data Capture

### Basic Pattern (pyserial)
```python
import serial
ser = serial.Serial(port, baudrate, timeout=1)
# Read line-by-line for text protocols
line = ser.readline().decode('ascii', errors='ignore').strip()
# Read bytes for binary protocols
data = ser.read(packet_size)
```

### Common Embedded Serial Protocols
| Pattern | Example | Detection |
|---------|---------|-----------|
| CSV-like | `123.4,567.8,901.2\n` | Lines with commas/tabs + numbers |
| Custom prefix | `SW19c<d0>n<d1>n...` | Fixed prefix + delimiter-separated values |
| Binary packed | `0xAA 0x55 [payload] [checksum]` | Header bytes + fixed length |
| JSON | `{"force": 12.3, "pos": 45.6}\n` | Lines starting with `{` |
| Protobuf | Binary, schema required | Known message type |

## File Naming Convention

Recommended: `YYMMDD_SubjectID_Condition_Trial.{ext}`

Examples:
- `260402_S01_AssistON_T1.csv`
- `260402_S01_AssistOFF_T1.csv`
- `260402_S01_Baseline_T1.bag`

### Directory Structure
```
data/
├── raw/              # Original files (NEVER modify)
│   ├── 260402_S01/
│   └── 260402_S02/
├── processed/        # Cleaned, filtered, synchronized
│   ├── 260402_S01/
│   └── 260402_S02/
└── analysis/         # Figures, tables, statistics
    ├── figures/
    └── tables/
```

## Integrity Report Format

After validation, produce a summary like:
```
=== Data Integrity Report ===
File: 260402_S01_AssistON_T1.csv
Columns: 81 (all present)
Rows: 125,000
Duration: 1125.0 s (18.75 min)
Sample rate: 111.1 ± 0.3 Hz
NaN count: 0
Timestamp gaps (>50ms): 2 at rows [45123, 89001]
Range violations: R_ActForce_N exceeded 300N at rows [12045-12048]
Overall: PASS (2 warnings)
```
