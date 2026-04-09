# p1-realtime.md — 실시간 데이터 GUI
# skiro-gui | realtime 트리거 시 | ~620 tok

## PyQt6 + pyqtgraph 실시간 플롯

```python
import sys
import numpy as np
from PyQt6.QtWidgets import QApplication, QMainWindow, QWidget, QVBoxLayout
from PyQt6.QtCore import QTimer
import pyqtgraph as pg

class RealtimePlotter(QMainWindow):
    """
    다채널 실시간 플롯 (H-Walker 모터 상태 표시용)
    """
    def __init__(self, channels: list, window_sec=10, fs=111):
        super().__init__()
        self.channels = channels
        self.n_pts = int(window_sec * fs)
        self.fs = fs
        
        # 데이터 버퍼 (링 버퍼)
        self.data = {ch: np.zeros(self.n_pts) for ch in channels}
        
        # 레이아웃
        central = QWidget()
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)
        
        # pyqtgraph
        self.plots = {}
        self.curves = {}
        colors = ['cyan', 'yellow', 'lime', 'red', 'magenta', 'white']
        
        for i, ch in enumerate(channels):
            pw = pg.PlotWidget(title=ch)
            pw.setYRange(-30, 30)  # 기본 범위 (조절 가능)
            pw.showGrid(x=True, y=True, alpha=0.3)
            pw.setBackground('k')
            curve = pw.plot(pen=colors[i % len(colors)])
            layout.addWidget(pw)
            self.plots[ch] = pw
            self.curves[ch] = curve
        
        # 업데이트 타이머
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_plot)
        self.timer.start(int(1000 / fs))  # ms
    
    def push_data(self, ch, value):
        """외부에서 데이터 푸시"""
        self.data[ch] = np.roll(self.data[ch], -1)
        self.data[ch][-1] = value
    
    def update_plot(self):
        for ch in self.channels:
            self.curves[ch].setData(self.data[ch])
    
    def set_yrange(self, ch, y_min, y_max):
        self.plots[ch].setYRange(y_min, y_max)

if __name__ == '__main__':
    app = QApplication(sys.argv)
    win = RealtimePlotter(['pos_1', 'vel_1', 'curr_1', 'pos_2'])
    win.show()
    sys.exit(app.exec())
```

## 상태 표시 패널 (색상 코드)

```python
from PyQt6.QtWidgets import QLabel
from PyQt6.QtGui import QColor, QPalette

STATUS_COLORS = {
    'OK':       '#00CC00',  # 초록
    'WARNING':  '#FFA500',  # 주황
    'ERROR':    '#CC0000',  # 빨강
    'OFFLINE':  '#555555',  # 회색
    'ESTOP':    '#FF0000',  # 빨강 (비상)
}

def set_status_label(label: QLabel, status: str, text: str = None):
    color = STATUS_COLORS.get(status, '#FFFFFF')
    label.setStyleSheet(f'background-color: {color}; color: black; '
                        f'padding: 4px; border-radius: 4px;')
    label.setText(text or status)
```
