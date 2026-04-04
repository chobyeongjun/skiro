# p3-visualization.md — 시각화
# skiro-data | visualization 트리거 시 | ~480 tok

## Python matplotlib 표준 플롯

```python
import matplotlib.pyplot as plt
import numpy as np

def plot_gait_signals(time, signals_dict, events=None, title="Gait Data"):
    """
    signals_dict: {'label': array, ...}
    events: [('HS', t), ('TO', t), ...] 이벤트 마커
    """
    fig, axes = plt.subplots(len(signals_dict), 1,
                              figsize=(12, 3*len(signals_dict)), sharex=True)
    if len(signals_dict) == 1:
        axes = [axes]
    
    colors = plt.cm.tab10.colors
    for ax, (label, data), color in zip(axes, signals_dict.items(), colors):
        ax.plot(time, data, color=color, linewidth=0.8)
        ax.set_ylabel(label, fontsize=9)
        ax.grid(True, alpha=0.3)
        
        if events:
            for etype, et in events:
                c = 'red' if etype == 'HS' else 'blue'
                ax.axvline(et, color=c, alpha=0.6, linewidth=0.8,
                          linestyle='--' if etype == 'TO' else '-')
    
    axes[-1].set_xlabel('Time (s)')
    axes[0].set_title(title)
    plt.tight_layout()
    return fig

# 저장
fig.savefig('gait_analysis.pdf', dpi=150, bbox_inches='tight')
```

## MATLAB 플롯 (H-Walker 데이터)

```matlab
% 관절 각도 플롯 (보행 주기 정규화)
function plot_joint_cycle(angle_data, fs, hs_frames)
    % angle_data: (N_frames × 1)
    % hs_frames: heel strike 인덱스 배열
    
    n_cycles = length(hs_frames) - 1;
    normalized = zeros(n_cycles, 101);
    
    for i = 1:n_cycles
        seg = angle_data(hs_frames(i):hs_frames(i+1));
        normalized(i,:) = interp1(linspace(0,100,length(seg)), seg, 0:100);
    end
    
    mean_cycle = mean(normalized, 1);
    std_cycle  = std(normalized, 0, 1);
    x = 0:100;
    
    figure; hold on;
    fill([x, fliplr(x)], ...
         [mean_cycle+std_cycle, fliplr(mean_cycle-std_cycle)], ...
         [0.7 0.7 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
    plot(x, mean_cycle, 'b-', 'LineWidth', 2);
    xlabel('Gait Cycle (%)'); ylabel('Angle (deg)');
    title('Joint Angle Profile'); grid on;
end
```
