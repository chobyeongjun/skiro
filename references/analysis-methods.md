# Robot Data Analysis Methods

Reference for computing control metrics, statistical tests, and paper-ready outputs.
Read this when working with /skiro-analyze or /skiro-gait.

## Control Performance Metrics

### Tracking Error
```python
error = desired - actual
rmse = np.sqrt(np.mean(error**2))
max_error = np.max(np.abs(error))
mean_abs_error = np.mean(np.abs(error))
```

### Settling Time
```python
# Time for response to stay within ±band% of final value
final_value = actual[-100:].mean()  # last 100 samples as steady state
band = 0.02  # 2% band
within_band = np.abs(actual - final_value) < band * abs(final_value)
# Find last time it exits the band
settling_idx = np.where(~within_band)[0][-1] + 1 if np.any(~within_band) else 0
settling_time = time[settling_idx] - time[0]
```

### Bandwidth (-3dB)
```python
from scipy import signal
# Compute frequency response from input/output
f, Pxy = signal.csd(desired, actual, fs=sample_rate, nperseg=1024)
f, Pxx = signal.welch(desired, fs=sample_rate, nperseg=1024)
H = Pxy / Pxx  # Transfer function estimate
H_mag_db = 20 * np.log10(np.abs(H))
# Find -3dB crossing
ref_db = np.max(H_mag_db[:5])  # low-frequency reference (avoid DC bin artifacts)
bandwidth_idx = np.where(H_mag_db < ref_db - 3)[0]
bandwidth_hz = f[bandwidth_idx[0]] if len(bandwidth_idx) > 0 else f[-1]
```

## Frequency Analysis

### FFT
```python
from scipy.fft import fft, fftfreq
N = len(signal_data)
yf = fft(signal_data - np.mean(signal_data))  # remove DC
xf = fftfreq(N, 1/sample_rate)[:N//2]
magnitude = 2.0/N * np.abs(yf[:N//2])
```

### Power Spectral Density (PSD)
```python
from scipy.signal import welch
f, Pxx = welch(signal_data, fs=sample_rate, nperseg=min(1024, len(signal_data)//4))
```

### Bode Plot
```python
# If you have input (command) and output (response)
f, Pxy = signal.csd(input_sig, output_sig, fs=fs, nperseg=1024)
f, Pxx = signal.welch(input_sig, fs=fs, nperseg=1024)
H = Pxy / Pxx
mag_db = 20 * np.log10(np.abs(H))
phase_deg = np.angle(H, deg=True)
```

## Trajectory Analysis

### Smoothness (Jerk Metric)
```python
# Lower jerk = smoother motion
velocity = np.gradient(position, time)
acceleration = np.gradient(velocity, time)
jerk = np.gradient(acceleration, time)
smoothness = -np.log(np.trapz(jerk**2, time) * (duration**3 / path_length**2))
# Log Dimensionless Jerk (Balasubramanian et al., 2012). Note: duration^3, NOT ^5.
```

### Work and Energy
```python
# Work = integral of force × displacement
work = np.trapz(force, displacement)  # Joules if N and m

# Hysteresis = area inside force-displacement loop
# (positive work - negative work)
```

## Statistical Tests

### Decision Tree
```
Is data normally distributed?
├── YES → Are groups paired/matched?
│   ├── YES → Paired t-test (2 groups) / Repeated-measures ANOVA (3+)
│   └── NO  → Independent t-test (2 groups) / One-way ANOVA (3+)
└── NO  → Are groups paired/matched?
    ├── YES → Wilcoxon signed-rank (2) / Friedman (3+)
    └── NO  → Mann-Whitney U (2) / Kruskal-Wallis (3+)
```

### Normality Test
```python
from scipy.stats import shapiro
stat, p = shapiro(data)
is_normal = p > 0.05
```

### Common Tests
```python
from scipy import stats

# Paired t-test (before/after, same subjects)
t, p = stats.ttest_rel(condition_a, condition_b)

# Independent t-test (different groups)
t, p = stats.ttest_ind(group_a, group_b)

# Wilcoxon signed-rank (non-parametric paired)
w, p = stats.wilcoxon(condition_a, condition_b)

# Mann-Whitney U (non-parametric independent)
u, p = stats.mannwhitneyu(group_a, group_b)

# One-way ANOVA
f, p = stats.f_oneway(group_a, group_b, group_c)
```

### Effect Size
```python
# Cohen's d (paired)
diff = condition_a - condition_b
d = np.mean(diff) / np.std(diff, ddof=1)
# Interpretation: 0.2 small, 0.5 medium, 0.8 large

# Cohen's d (independent)
pooled_std = np.sqrt(((n1-1)*s1**2 + (n2-1)*s2**2) / (n1+n2-2))
d = (mean1 - mean2) / pooled_std

# Eta-squared (for ANOVA)
eta_sq = ss_between / ss_total
```

## Paper-Ready Output

### Matplotlib Academic Style
```python
import matplotlib.pyplot as plt
import matplotlib

# IEEE / academic paper style
plt.rcParams.update({
    'font.family': 'serif',
    'font.serif': ['Times New Roman', 'DejaVu Serif'],
    'font.size': 10,
    'axes.labelsize': 11,
    'axes.titlesize': 11,
    'legend.fontsize': 9,
    'xtick.labelsize': 9,
    'ytick.labelsize': 9,
    'figure.figsize': (3.5, 2.5),      # single column
    # 'figure.figsize': (7.16, 3.5),   # double column
    'figure.dpi': 300,
    'savefig.dpi': 300,
    'savefig.bbox': 'tight',
    'lines.linewidth': 1.0,
    'axes.linewidth': 0.5,
    'grid.linewidth': 0.3,
    'axes.grid': True,
    'grid.alpha': 0.3,
})
```

### LaTeX Table Template (IEEE)
```latex
\begin{table}[t]
\caption{Comparison of Gait Parameters}
\label{tab:gait_params}
\centering
\begin{tabular}{lcc}
\hline
Parameter & Assist ON & Assist OFF \\
\hline
Stride Time (s) & $1.12 \pm 0.08$ & $1.18 \pm 0.11$ \\
Cadence (steps/min) & $107.1 \pm 7.6$ & $101.7 \pm 9.4$ \\
Stance (\%) & $62.3 \pm 2.1$ & $63.8 \pm 2.5$ \\
\hline
\multicolumn{3}{l}{\footnotesize Values: mean $\pm$ SD. * $p < 0.05$}
\end{tabular}
\end{table}
```

### LaTeX Table Template (JNER)
```latex
\begin{table*}[t]
\caption{Temporal-spatial gait parameters}
\begin{tabular}{lccccc}
\toprule
& \multicolumn{2}{c}{Assist ON} & \multicolumn{2}{c}{Assist OFF} & \\
\cmidrule(lr){2-3} \cmidrule(lr){4-5}
Parameter & Mean & SD & Mean & SD & $p$-value \\
\midrule
Stride time (s) & 1.12 & 0.08 & 1.18 & 0.11 & 0.023* \\
\bottomrule
\end{tabular}
\end{table*}
```

### Figure Descriptions for Papers
When generating figures, always include:
1. **Title** — what the figure shows
2. **Axes labels** — with units in parentheses, e.g., "Force (N)", "Time (s)"
3. **Legend** — if multiple series
4. **Statistical annotations** — significance markers (*, **, ***) with brackets
5. **Caption text** — brief description suitable for the paper

### Significance Markers
| p-value | Marker |
|---------|--------|
| p < 0.05 | * |
| p < 0.01 | ** |
| p < 0.001 | *** |
| p ≥ 0.05 | ns |
