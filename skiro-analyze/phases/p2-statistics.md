# p2-statistics.md — 통계 분석
# skiro-analyze | stats 트리거 시 | ~560 tok

## 기본 통계 검정 (Python)

```python
from scipy import stats
import numpy as np

def analyze_experiment(group_a, group_b, alpha=0.05):
    """
    group_a, group_b: 1D array (측정값)
    Returns: 검정 결과 딕셔너리
    """
    results = {}
    
    # 1. 정규성 검정 (n < 50: Shapiro-Wilk)
    _, p_norm_a = stats.shapiro(group_a)
    _, p_norm_b = stats.shapiro(group_b)
    normal = (p_norm_a > alpha) and (p_norm_b > alpha)
    results['normality'] = {'group_a': p_norm_a, 'group_b': p_norm_b, 'passed': normal}
    
    # 2. 주요 검정
    if normal:
        # 등분산 검정
        _, p_var = stats.levene(group_a, group_b)
        equal_var = p_var > alpha
        
        # 독립 t-test 또는 Welch's t-test
        t_stat, p_val = stats.ttest_ind(group_a, group_b, equal_var=equal_var)
        test_name = 'Independent t-test' if equal_var else "Welch's t-test"
    else:
        # Mann-Whitney U (비모수)
        t_stat, p_val = stats.mannwhitneyu(group_a, group_b, alternative='two-sided')
        test_name = 'Mann-Whitney U'
    
    results['test'] = {'name': test_name, 'statistic': t_stat, 'p_value': p_val}
    results['significant'] = p_val < alpha
    
    # 3. 효과 크기 (Cohen's d)
    pooled_std = np.sqrt((np.std(group_a)**2 + np.std(group_b)**2) / 2)
    cohen_d = (np.mean(group_a) - np.mean(group_b)) / (pooled_std + 1e-9)
    results['effect_size'] = {
        'cohens_d': cohen_d,
        'interpretation': 'small' if abs(cohen_d) < 0.5
                          else 'medium' if abs(cohen_d) < 0.8 else 'large'
    }
    
    return results

def report(results):
    """결과 출력"""
    t = results['test']
    print(f"검정: {t['name']}")
    print(f"  통계량: {t['statistic']:.4f}")
    print(f"  p값: {t['p_value']:.4f}")
    print(f"  유의: {'YES (p<0.05)' if results['significant'] else 'NO'}")
    e = results['effect_size']
    print(f"  Cohen's d: {e['cohens_d']:.3f} ({e['interpretation']})")
```

## Paired t-test (Within-subject, H-Grow 기준)

```python
def analyze_within_subject(device_off, device_on, alpha=0.05):
    """
    device_off, device_on: 동일 피험자 쌍별 측정값
    H-Grow: GDI device_off vs device_on
    """
    diff = np.array(device_on) - np.array(device_off)
    
    # Paired t-test (정규성 가정)
    t_stat, p_val = stats.ttest_rel(device_on, device_off)
    
    # 또는 Wilcoxon (비모수)
    w_stat, p_wil = stats.wilcoxon(device_on, device_off)
    
    delta = np.mean(diff)
    ci = stats.t.interval(0.95, len(diff)-1,
                          loc=delta, scale=stats.sem(diff))
    
    print(f"평균 차이 (on-off): {delta:.2f} (95% CI: {ci[0]:.2f}–{ci[1]:.2f})")
    print(f"Paired t-test: t={t_stat:.3f}, p={p_val:.4f}")
    print(f"Wilcoxon:      W={w_stat:.1f}, p={p_wil:.4f}")
    print(f"목표 달성: {'YES' if delta >= 6.5 else 'NO'} (기준: +6.5 GDI)")
    
    return {'delta': delta, 'ci_95': ci, 'p_ttest': p_val, 'p_wilcoxon': p_wil}
```
