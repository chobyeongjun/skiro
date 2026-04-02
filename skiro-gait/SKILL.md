---
name: skiro-gait
description: |
  Gait analysis for walking robots and exoskeletons. Extends /skiro-analyze
  with gait-specific capabilities: gait cycle percentage (GCP) calculation,
  heel strike (HS) and heel off (HO) event detection, temporal-spatial
  parameters (stride time, cadence, stance/swing ratio, double support),
  gait cycle normalization of force/position/angle profiles, and symmetry
  analysis. Supports IMU-based, force-based, and camera-based gait detection.
  Generates paper-ready gait parameter tables and normalized profile figures.
  Keywords (EN/KR): gait/보행, GCP, heel strike/힐 스트라이크,
  heel off, stride/스트라이드, cadence/케이던스, stance/입각기,
  swing/유각기, 보행 주기, walking/걷기, exoskeleton/외골격,
  treadmill/트레드밀, symmetry/대칭성, double support/양하지 지지,
  gait speed/보행 속도, 정규화, 보행 분석. (skiro)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
  - WebSearch
---

Read VOICE.md before responding.

This skill extends /skiro-analyze. For general metrics (RMSE, FFT, condition
comparison, LaTeX tables), use /skiro-analyze directly. This skill adds
gait-specific event detection and temporal-spatial parameter computation.

## Phase 0: Context

1. Read hardware.yaml — look for `gait:` section.
   If present: load thresholds (HS ratio, HO angle, step time limits).
   If absent: ask for detection method below.
2. Load learnings for "gait", "stride", "hs", "ho" tags.

AskUserQuestion: "What is your research/clinical question?"
A) 낙상 위험 평가 (Fall risk assessment)
B) 보조 장치 효과 평가 (Assistive device evaluation)
C) 재활 진행 추적 (Rehabilitation progress tracking)
D) 에너지 효율 분석 (Energy efficiency analysis)
E) 전체 분석 (Comprehensive — all metrics)
F) 직접 지정 (I'll specify which metrics)

### Biomechanical Metric Selection Guide
Based on research question, auto-select the most relevant metrics:

| Research Goal | Priority Metrics | Biomechanical Rationale |
|--------------|-----------------|----------------------|
| **낙상 위험** | Stride time CV, toe clearance, double support % | CV >6% = fall risk indicator (Hausdorff et al., 2001). Low toe clearance (<10mm) = trip risk (Winter, 1992). Increased double support = compensatory stability strategy. |
| **보조 효과** | Symmetry index, stance %, cadence, gait speed | SI quantifies bilateral balance improvement (Robinson et al., 1987). Stance % closer to 60% = normalized loading. Increased cadence/speed = functional improvement. |
| **재활 추적** | Gait speed, stride length, cadence (longitudinal) | Gait speed is the "6th vital sign" (Fritz & Lusardi, 2009). MCID for gait speed: 0.1-0.2 m/s. Stride length reflects confidence in weight bearing. |
| **에너지 효율** | Stance/swing ratio, stride time, gait speed | Optimal stance/swing ≈ 60/40 (Perry & Burnfield, 2010). Deviation increases metabolic cost. Self-selected speed minimizes cost of transport. |
| **전체 분석** | All of the above | Complete temporal-spatial profile for comprehensive assessment. |

AskUserQuestion: "How is gait detected in your system?"
A) IMU-based (shank/foot angle + angular velocity)
B) Force sensor / loadcell (vertical force threshold)
C) Foot switches / pressure sensors
D) Camera-based (pose estimation keypoints)
E) GCP is already computed (column in CSV)
F) Not sure — help me choose

For A/B/C/D: will compute events from raw data.
For E: will use existing GCP column directly.

## Phase 1: Data Loading + Column Mapping

1. Load CSV file(s).
2. Search for gait-related columns:
   - `GCP`, `gcp`, `Gait_Cycle`, `Phase` → pre-computed GCP
   - `L_GCP`, `R_GCP` → bilateral GCP
   - `Pitch`, `Roll`, `Gyro`, `Gx`, `Gy`, `Gz` → IMU for event detection
   - `Force`, `Force_N`, `Fz`, `GRF` → force for event detection
   - `StepTime`, `Step_Time` → pre-computed step time
   - `HO_GCP` → heel-off timing within cycle
3. Auto-estimate sample rate from timestamp column.
4. Confirm mapping with user.

## Phase 2: Gait Event Detection

### A) IMU-Based Detection
**Sensor placement must be known** — ask user: shank, foot, or thigh?
Default assumption: shank-mounted IMU (sagittal plane pitch).

Heel Off (HO):
- Pitch angle ≥ HO_angle_threshold (default: 2.5°)
- AND angular velocity ≥ HO_angvel_threshold (default: 40°/s)
- Minimum interval between events: 300ms (debounce)
- Apply low-pass filter (Butterworth 2nd order, 20Hz cutoff) before detection

Heel Strike (HS):
- During swing phase: track peak angular velocity (= max abs(gyro) in current swing)
- HS detected when: gyro drops below swing_peak × HS_ratio (default: 0.08)
- swing_peak = maximum angular velocity magnitude within the current swing phase only
- Search window: only check after HO + 200ms minimum swing time
- Note: sign of gyro depends on sensor orientation — verify direction first

### B) Force-Based Detection
Heel Strike: force crosses upward through threshold (typically 10-20% body weight)
Heel Off: force crosses downward through threshold

### C) Foot Switch
Contact ON → stance start (HS equivalent)
Contact OFF → swing start (HO equivalent)

### D) Camera-Based
Heel keypoint velocity reversal → HS
Toe-off keypoint → HO
(Requires pose estimation output with foot keypoints)

### E) Pre-Computed
Use existing GCP column. Detect HS as GCP reset (prev > 0.8, current < 0.2).

Output: arrays of HS timestamps and HO timestamps for each side (L/R if bilateral).

## Phase 3: Temporal-Spatial Parameters

Compute from detected events:

| Parameter | Formula | Unit |
|-----------|---------|------|
| Stride Time | HS[n+1] - HS[n] (same foot) | s |
| Step Time | HS_L[n] - HS_R[n] (contralateral) | s |
| Cadence | 120 / mean(Stride Time) OR 60 / mean(Step Time) | steps/min |
| Stance % | (HO - HS) / Stride Time × 100 | % |
| Swing % | 100 - Stance % | % |
| Double Support % | (IDS + TDS) / Stride × 100; IDS=HS_ipsi→HO_contra, TDS=HS_contra→HO_ipsi | % |
| Gait Speed | distance / time (if available) | m/s |
| Step Length | gait speed × step time (if speed available) | m |
| Stride Time CV | SD(stride_time) / mean(stride_time) × 100 | % |
| Gait Speed CV | SD(gait_speed) / mean(gait_speed) × 100 | % |
| Toe Clearance | min foot height during swing phase (if available) | mm |

### Variability Metrics
```python
# Coefficient of Variation — lower = more consistent gait
stride_cv = np.std(stride_times, ddof=1) / np.mean(stride_times) * 100
# Interpretation: CV < 3% = healthy adult, 3-6% = mild variability,
# >6% = high variability (fall risk indicator)

# Toe clearance (requires foot position data during swing)
# Minimum vertical distance of toe marker during mid-swing (40-60% of swing)
for stride in strides:
    swing_data = stride[swing_start:swing_end]
    mid_swing = swing_data[int(0.4*len(swing_data)):int(0.6*len(swing_data))]
    toe_clearance = np.min(mid_swing['foot_z'])  # mm
# Interpretation: healthy ~15-25mm, <10mm = trip risk
```

### Symmetry Index
```
SI = |Left - Right| / (0.5 × (Left + Right)) × 100
```
Compute for: stride time, step time, stance %, swing %, peak force.
SI < 10% = symmetric, 10-15% = mild asymmetry, >15% = significant asymmetry.

### Quality Filtering
- Reject strides with time outside valid range (default: 0.2–3.0s)
- Reject first N strides (default: 2) — transition from standing
- Report: total strides detected, strides accepted, strides rejected (with reasons)

## Phase 4: Gait Cycle Normalization

Normalize each stride to 0–100% of gait cycle:
1. Extract data between consecutive HS events (one full stride)
2. Resample each stride to 101 points (0%, 1%, ..., 100%)
3. Compute mean ± SD across all valid strides
4. For bilateral: align L and R to respective HS events

This creates the classic "gait cycle profile" for any variable
(force, angle, velocity, GCP, etc.).

## Phase 5: Statistical Analysis + Paper Output

Use /skiro-analyze patterns for statistics:
- Condition comparison: paired t-test or Wilcoxon (per parameter)
- Effect size: Cohen's d
- Generate comparison table (mean ± SD, p-value, significance)

### Gait-Specific Figures:
1. **GCP-Normalized Profile**: mean ± SD band, X = 0–100% GCP, Y = variable
   - Multiple conditions as different colors with transparent SD bands
2. **Temporal-Spatial Bar Chart**: grouped bars for L vs R, condition comparison
3. **Symmetry Radar Chart**: SI values for each parameter
4. **Stride-by-Stride Variability**: individual strides overlaid with mean

### LaTeX Table:
IEEE / JNER / Gait & Posture format (ask preference).
Include all temporal-spatial parameters with mean ± SD per condition.

### BibTeX Suggestions:
Suggest relevant references based on analysis type:
- IMU gait detection: Salarian et al., Sabatini et al.
- Force-based: Winter, "Biomechanics and Motor Control"
- Symmetry index: Robinson et al., 1987
- GCP normalization: Kirtley, "Clinical Gait Analysis"

## Phase 6: Summary + Next Step

Report:
- Strides analyzed: N per side
- Key parameters: stride time, cadence, stance %, symmetry
- Significant differences (if conditions compared)
- Generated files

Log gait-specific findings as learnings.

Next: /skiro-retro for full experiment retrospective.
