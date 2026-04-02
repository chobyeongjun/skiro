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
  Keywords (EN/KR): RMSE, tracking error/추적 오차, bandwidth/대역폭,
  FFT, PSD, force/힘, torque/토크, t-test, ANOVA, matplotlib,
  LaTeX, 논문 그래프, 조건 비교, 데이터 분석, 통계, 효과 크기,
  제어 성능, 주파수 분석. (skiro)
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

## Data Safety Rules (모든 Phase에 적용)
```
⚠️  raw 데이터 파일은 절대 수정하지 않는다 — 읽기만 한다
⚠️  분석 결과는 analysis/ 또는 paper_data/analysis/에 저장
⚠️  기존 분석 결과를 덮어쓸 때 반드시 사용자 확인
⚠️  분석에 사용된 파일 목록을 analysis/analysis_log.csv에 기록
```

## Phase 0: Context

1. Read hardware.yaml for sensor specs, control frequencies, safety limits.
2. Scan for data files — **paper_data/ 우선 확인**:
   ```bash
   # paper_data/가 있으면 그 안의 데이터 사용 (skiro-data Phase 6에서 정리된 것)
   ls paper_data/raw/*.csv 2>/dev/null && echo "PAPER_DATA_FOUND"
   # 없으면 일반 스캔
   find . -name "*.csv" -o -name "*.bag" -o -name "*.h5" 2>/dev/null | head -20
   ```
   paper_data/ 발견 시: "정리된 논문 데이터가 있습니다. 이 데이터로 분석할까요?"
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

### Output Directory:
- paper_data/ 존재 시 → `paper_data/analysis/figures/`, `paper_data/analysis/tables/`
- 없으면 → `analysis/figures/`, `analysis/tables/`
- **기존 파일 덮어쓰기 전**: "fig1.png가 이미 존재합니다. 덮어쓸까요?" 확인

### Figure Generation Rules:
- One `.py` script per figure (reusable)
- Save to output directory (위 규칙 참고)
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

## Phase 5: Analysis Log + Summary

### 5-1. analysis_log.csv 기록
분석에 사용된 모든 정보를 기록 — 나중에 "이 그래프 어떤 데이터로 만든 거지?" 추적용:

```csv
timestamp,analysis_type,input_files,output_files,parameters,notes
2026-04-02T15:30,condition_comparison,"paper_data/raw/S01_AssistON_T1.csv;paper_data/raw/S01_AssistOFF_T1.csv","analysis/figures/fig1_force_comparison.png;analysis/tables/table1_results.tex","paired_t_test;alpha=0.05;cohen_d",
```

저장 위치: `analysis/analysis_log.csv` 또는 `paper_data/analysis/analysis_log.csv`
**기존 로그에 append** (덮어쓰기 아님).

### 5-2. Summary
Present results concisely:
- Key metrics with values and units
- Statistical significance summary
- Generated files list (figures + tables)
- 사용된 입력 파일 목록

Log analysis decisions as learnings (e.g., "Welch's t-test used because unequal variance").

### 5-3. Next Step
- More analysis → continue or try /skiro-gait for gait-specific
- Results look good → /skiro-retro for experiment retrospective
- Need paper figures → refine with specific requests
- 재분석 필요 → raw 파일 그대로, analysis/ 결과만 다시 생성
