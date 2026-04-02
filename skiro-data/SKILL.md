---
name: skiro-data
description: |
  Robot experiment data management. Two modes: (1) Single experiment —
  collect, validate (NaN, gaps, sample rate), convert formats (CSV, ROS bag,
  HDF5, MATLAB .mat, EDF/BDF, MCAP), organize files. (2) Paper dataset
  curation — collect valid trials from multiple experiments, exclude bad
  data with documented reasons, build paper_dataset/ for analysis.
  For robot/sensor data from MCU or ROS — NOT for web APIs, databases,
  or business data. NOT for analysis (/skiro-analyze) or paper writing (/skiro-retro).
  Keywords (EN/KR): data management/데이터 관리, validation/검증,
  CSV, ROS bag, HDF5, format conversion/포맷 변환, 데이터 정리,
  integrity/무결성, sample rate/샘플링 주파수, NaN, 실험 데이터,
  SD 카드, 다운로드, 파일 정리, 데이터셋, paper dataset/논문 데이터,
  유효 데이터, 큐레이션, curation, 데이터 모으기. (skiro)
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

## Phase 5: Summary + Next Step (Single Experiment)

Report:
- Files collected: count, total size, total duration
- Issues found: count by severity
- Files organized: new paths

Log any data issues as learnings via skiro-learnings add.

Next step suggestions:
- Data looks clean → /skiro-analyze or /skiro-gait
- Data has issues → fix and re-validate
- Need more data → plan next experiment with /skiro-plan
- 모든 실험 완료 → Phase 6 (Paper Dataset Curation)

---

## Phase 6: 논문용 데이터 정리 (Paper Dataset)

**언제 쓰나**: 실험 여러 번 끝나고, 논문에 넣을 데이터를 모아 정리할 때.
"논문 데이터 정리해줘", "유효 데이터 모아줘", "분석할 데이터 정리해줘" → 여기로.

### 안전 원칙 (이 Phase 전체에 적용)
```
⚠️  원본 파일은 절대 수정/삭제하지 않는다 — 복사만 한다
⚠️  파일을 옮기거나 이름 바꿀 때 반드시 사용자 확인
⚠️  모든 작업은 기록한다 (어떤 파일을 어디로 복사했는지)
⚠️  분석 결과는 별도 폴더에 저장 — raw와 절대 섞지 않는다
```

### 6-1. 데이터 폴더 확인

AskUserQuestion: "데이터가 있는 폴더를 알려주세요."
(예: `~/Desktop/ARLAB/ARWalker/data/`, 또는 여러 폴더)

폴더 스캔 후 파일 목록 표시:
```bash
find <path> -name "*.csv" -o -name "*.mat" -o -name "*.bag" 2>/dev/null | sort
```

### 6-2. 유효 데이터 선별

두 가지 방법 중 선택:

AskUserQuestion: "유효한 데이터를 어떻게 고를까요?"
A) **자동 필터링** — 내가 각 파일을 검사해서 유효/무효 판단 (추천)
B) **수동 지정** — 유효한 파일을 직접 알려줄게

#### A) 자동 필터링
각 CSV 파일에 대해 자동 검사:

| 검사 항목 | 자동 판단 기준 | 결과 |
|-----------|---------------|------|
| 파일이 비어있지 않은지 | 10행 이상 데이터 | OK / EMPTY |
| 데이터 중간에 끊기지 않았는지 | 타임스탬프 갭 < 1초 이상 연속 | OK / DROPOUT |
| 센서가 멈추지 않았는지 | 같은 값 100개 이상 연속 없음 | OK / STUCK |
| NaN이 너무 많지 않은지 | NaN < 1% | OK / CORRUPTED |
| 충분한 길이인지 | 10초 이상 | OK / TOO_SHORT |

결과를 테이블로 보여주고 사용자 확인:
```
=== 자동 필터링 결과 ===
| # | 파일명 | 길이 | NaN% | 갭 | 센서 | 판정 |
|---|--------|------|------|----|------|------|
| 1 | 260115_S01_AssistON_T1.csv | 180s | 0% | 없음 | OK | ✅ VALID |
| 2 | 260115_S01_AssistON_T2.csv | 45s  | 0% | 없음 | OK | ✅ VALID |
| 3 | 260115_S01_AssistOFF_T1.csv | 3s  | 0% | 없음 | OK | ❌ TOO_SHORT |
| 4 | 260115_S02_test.csv         | 120s | 23% | 있음 | STUCK | ❌ CORRUPTED |
```

AskUserQuestion: "이 판정이 맞나요? 수정할 것 있으면 알려주세요."
A) 맞습니다 → 진행
B) 일부 수정 (예: 3번은 유효, 4번도 포함)

#### B) 수동 지정
파일 목록을 번호와 함께 보여주고:
AskUserQuestion: "유효한 파일 번호를 알려주세요 (예: 1,2,5,6,7)"

### 6-3. 폴더 구조 생성 + 복사

유효 파일만 새 폴더에 **복사** (원본 절대 이동/삭제 안 함):

```
paper_data/
├── raw/                    ← 유효 파일 원본 복사 (절대 수정 금지)
│   ├── S01_AssistON_T1.csv
│   ├── S01_AssistON_T2.csv
│   ├── S01_AssistOFF_T1.csv
│   └── ...
├── processed/              ← 분석용 전처리 결과 (NaN 보간, 필터링 등)
│   └── (나중에 skiro-analyze가 여기에 저장)
├── analysis/               ← 분석 결과 (figure, table, 통계)
│   ├── figures/
│   └── tables/
├── file_log.csv            ← 어떤 파일이 어디서 복사되었는지 기록
├── exclusion_log.csv       ← 제외된 파일 + 제외 이유
└── README.md               ← 데이터셋 설명
```

#### 파일 이름 규칙 (추천)
```
{날짜}_{피험자}_{조건}_{Trial번호}.csv

예시:
  260115_S01_AssistON_T1.csv
  260115_S01_AssistOFF_T1.csv
  260320_S05_Baseline_T3.csv
```

| 필드 | 설명 | 예시 |
|------|------|------|
| 날짜 | YYMMDD | 260115 |
| 피험자 | S + 2자리 번호 | S01, S12 |
| 조건 | 실험 조건 (CamelCase) | AssistON, AssistOFF, Baseline |
| Trial | T + 번호 | T1, T2, T3 |

기존 파일 이름이 다르면:
AskUserQuestion: "파일 이름을 이 규칙으로 바꿀까요?"
A) 네, 복사하면서 이름도 변경
B) 아니요, 원래 이름 유지
C) 다른 규칙 쓸게요 (직접 지정)

### 6-4. file_log.csv 생성

모든 복사 기록 — 나중에 "이 데이터 어디서 온 거지?" 추적용:
```csv
new_name,original_path,copy_date,valid,notes
S01_AssistON_T1.csv,/data/exp_0115/trial1_assist.csv,2026-04-02,true,
S01_AssistOFF_T1.csv,/data/exp_0115/trial1_noassist.csv,2026-04-02,true,
S01_test.csv,/data/exp_0115/test_run.csv,2026-04-02,false,Too short (3s)
```

### 6-5. exclusion_log.csv 생성

제외된 파일과 이유 — 논문 Methods에 직접 활용:
```csv
file,reason,details
260115_S01_AssistOFF_T1.csv,too_short,Duration 3s (minimum 10s)
260115_S02_test.csv,sensor_stuck,Force_N stuck at 0.0 for 500+ samples
260320_S03_AssistON_T2.csv,user_excluded,Protocol deviation (wrong speed)
```

→ 논문에 쓸 문장 자동 생성:
"12 trials were excluded: 4 due to sensor malfunction, 3 due to protocol
deviation, 3 due to insufficient duration, 2 due to communication dropout."

### 6-6. 전처리 데이터 생성 (선택사항)

AskUserQuestion: "분석하기 편하게 전처리를 미리 해둘까요?"
A) 네 — NaN 보간 + 필터링 + 시간 정규화
B) 아니요 — raw만 보관하고 분석할 때 처리
C) 일부만 (어떤 전처리?)

전처리 항목:
- NaN 보간 (linear interpolation)
- 로우패스 필터 (Butterworth, 지정 Hz)
- 시간축 0 기준 정렬 (첫 타임스탬프 = 0)
- 단위 통일 (rad → deg 등)

전처리 결과는 `processed/`에 저장.
**raw/ 파일은 절대 수정 안 함.**

### 6-7. 일관성 검증

모든 유효 파일 간 일관성 최종 확인:

| 항목 | 확인 | 불일치 시 |
|------|------|----------|
| 컬럼 이름 | 모든 파일 동일 | 자동 리네이밍 제안 |
| 컬럼 순서 | 동일 | 자동 재정렬 제안 |
| sample rate | 동일 (±1%) | 리샘플링 제안 |
| 단위 | 동일 | 변환 제안 (rad→deg 등) |
| 타임스탬프 포맷 | 동일 (ms vs s) | 변환 제안 |

### 6-8. 최종 확인

```
=== Paper Data 정리 완료 ===
유효 파일: 24개 (12 subjects × 2 conditions)
제외 파일: 6개 (exclusion_log.csv 참조)
총 데이터: 1.8시간
폴더: paper_data/
  raw/        24 files (원본 복사, 수정 금지)
  processed/  [0 files — 전처리 안 함 / 24 files — 전처리 완료]
  analysis/   [비어있음 — skiro-analyze 후 채워짐]
```

AskUserQuestion: "paper_data/ 확인해주세요."
A) 완료 → /skiro-analyze로 분석 시작
B) 파일 추가/제거 필요
C) 전처리 방식 변경

### 6-9. Next Step

- 분석 시작 → `/skiro-analyze paper_data/raw/` 또는 `/skiro-gait paper_data/raw/`
- 분석 결과는 자동으로 `paper_data/analysis/`에 저장됨
- 모든 분석 완료 → `/skiro-retro`로 paper_packet/ 생성 → COWORK 업로드
- **다시 분석이 필요하면**: raw/는 그대로, processed/ 또는 analysis/만 다시 생성

## Wrong Skill? Redirect
If the user's request does not match this skill, DO NOT attempt it.
Instead, explain what this skill does and redirect to the correct one:
- Want to run statistical analysis (RMSE, FFT, t-test)? → "/skiro-analyze does control performance and statistical analysis."
- Want gait analysis? → "/skiro-gait does gait cycle, heel strike, temporal-spatial parameters."
- Want experiment retrospective? → "/skiro-retro summarizes results and generates paper packets."
- Want to build a GUI? → "/skiro-gui handles desktop GUI development."
- Want to verify code safety? → "/skiro-safety audits limits, watchdog, e-stop, timing."
- Want to flash firmware? → "/skiro-flash builds and uploads firmware to MCU."
- Want to test hardware? → "/skiro-hwtest generates and runs hardware test scripts."
- Want to plan an experiment? → "/skiro-plan handles experiment design and brainstorming."
- Want to set up BLE/WiFi/Serial? → "/skiro-comm handles robot communication setup."
