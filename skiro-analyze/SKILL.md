---
name: skiro-analyze
description: |
  Robot experiment data analysis — control performance (RMSE, bandwidth,
  tracking error), force-displacement curves, frequency response (FFT, PSD,
  Bode), and statistical condition comparison (t-test, ANOVA). Generates
  paper-ready matplotlib figures and LaTeX tables (IEEE, JNER format).
  For robot/sensor/actuator data only — NOT for business analytics, stock
  data, or web metrics. For gait-specific analysis (GCP, heel strike,
  stride time), use /skiro-gait instead.
  Keywords: RMSE, tracking error, bandwidth, FFT, PSD, force, torque,
  t-test, ANOVA, matplotlib, LaTeX, paper figure, condition comparison,
  robot data, control performance, effect size. (skiro)
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

## Phase 0: Context

1. Read hardware.yaml for sensor specs, control frequencies, safety limits.
2. Scan for data files:
   ```bash
   find . -name "*.csv" -o -name "*.bag" -o -name "*.h5" 2>/dev/null | head -20
   ```
3. Load learnings for "analysis", "statistics", "figure" tags.
4. Read `references/analysis-methods.md` for formulas and templates.

## Phase 1: Analysis Goal

AskUserQuestion: "What do you want to analyze?"
A) Control performance (tracking error, RMSE, bandwidth)
B) Trajectory analysis (path, velocity, acceleration, smoothness)
C) Force / torque analysis (profile, peak, work, hysteresis)
D) Frequency analysis (FFT, PSD, Bode plot)
E) Compare conditions (A vs B statistical comparison)
F) Custom analysis (describe what you need)

## Phase 2: Data Loading + Column Mapping

1. Load the data file(s).
2. Auto-detect column meanings from names:
   - `Des` / `Desired` / `Cmd` / `Ref` → setpoint
   - `Act` / `Actual` / `Meas` / `Fb` → measured value
   - `Err` / `Error` → tracking error
   - Column suffix → unit: `_N` = Newtons, `_Nm` = Newton-meters, `_deg` = degrees, `_rad` = radians, `_mps` = m/s, `_rpm` = RPM, `_A` = Amps, `_V` = Volts, `_W` = Watts, `_Hz` = Hertz
3. Auto-detect time column: `time`, `Time_ms`, `timestamp`, `t`
4. Show mapping to user:
   "I mapped these columns: [table]. Correct?"
   If wrong → AskUserQuestion to fix mapping.
5. **Mapping fallback**: if no columns match known patterns, show full column list
   and ask: "Which columns are desired/actual/error? Select from the list."

## Phase 3: Compute Metrics

Based on selected analysis type:

### A) Control Performance
- **RMSE**: `sqrt(mean((desired - actual)²))`
- **Max tracking error**: `max(|desired - actual|)`
- **Mean absolute error**: `mean(|desired - actual|)`
- **Settling time** (2% / 5% band)
- **Bandwidth** (-3dB frequency from input→output transfer function)
- **Steady-state error**

### B) Trajectory
- Position / velocity / acceleration profiles (numerical differentiation)
- Path length (cumulative distance)
- Smoothness: normalized jerk metric (SPARC or log dimensionless jerk)
- Workspace utilization

### C) Force / Torque
- Peak force, mean force, RMS force
- Impulse (integral of force × time)
- Work done (integral of force × displacement)
- Force-displacement hysteresis loop area
- Force profile as function of time or cycle percentage

### D) Frequency
- FFT magnitude spectrum (remove DC component first)
- Power Spectral Density (Welch method)
- Bode plot if input+output available (magnitude + phase)
- Dominant frequencies identification

### E) Condition Comparison
1. Identify conditions from filenames or ask user.
2. Compute descriptive stats: mean ± SD for each metric per condition.
3. **Normality test (Shapiro-Wilk)** → select parametric or non-parametric test.
   - **WARNING**: Shapiro-Wilk is unreliable for n > 50 (almost always rejects).
     For n > 50: use D'Agostino-Pearson (`scipy.stats.normaltest`) or visual
     QQ-plot + skewness/kurtosis check instead.
   - For n < 8: Shapiro-Wilk has low power, consider non-parametric by default.
   ```python
   from scipy import stats
   if n <= 50:
       _, p_norm = stats.shapiro(data)
   else:
       _, p_norm = stats.normaltest(data)  # D'Agostino-Pearson
   is_normal = p_norm > 0.05
   ```
4. **Paired vs Independent auto-detection**:
   - **Paired**: same subjects measured in both conditions (same N, matched order)
     → Check: `len(condition_a) == len(condition_b)` AND filenames share subject IDs
   - **Independent**: different subjects per condition (different N or unmatched)
   - **When ambiguous**: AskUserQuestion "Are these paired measurements (same subjects
     in both conditions) or independent groups?"
5. Run appropriate test:
   - 2 paired conditions → paired t-test or Wilcoxon signed-rank
   - 2 independent conditions → independent t-test (Welch's) or Mann-Whitney U
   - 3+ paired conditions → repeated-measures ANOVA or Friedman
   - 3+ independent conditions → one-way ANOVA or Kruskal-Wallis
6. Effect size: Cohen's d (2 groups) or η² (3+ groups)
7. Generate comparison table with p-values and significance markers.

## Phase 4: Visualization + Paper Output

Generate matplotlib scripts following academic style from `references/analysis-methods.md`.

### Figure Generation Rules:
- One `.py` script per figure (reusable)
- Save to `analysis/figures/` directory
- IEEE single-column: 3.5" wide. Double-column: 7.16" wide.
- All axes labeled with units: "Force (N)", "Time (s)"
- Legend if multiple series
- Grid: light, alpha=0.3
- DPI: 300 for publication

### LaTeX Table Generation:
- Format: IEEE or JNER (ask user preference)
- Include: mean ± SD, p-values, significance markers
- Save to `analysis/tables/` as `.tex` file
- Also show as markdown in terminal for quick review

### Statistical Annotation on Figures:
- Bracket + asterisk between compared conditions
- `*` p<0.05, `**` p<0.01, `***` p<0.001, `ns` p≥0.05

## Phase 5: Summary + Next Step

Present results concisely:
- Key metrics with values and units
- Statistical significance summary
- Generated files list (figures + tables)

Log analysis decisions as learnings (e.g., "Welch's t-test used because unequal variance").

Next step:
- More analysis → continue or try /skiro-gait for gait-specific
- Results look good → /skiro-retro for experiment retrospective
- Need paper figures → refine with specific requests
