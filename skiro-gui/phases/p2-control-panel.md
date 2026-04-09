# p2-control-panel.md — 제어 패널 GUI
# skiro-gui | control 트리거 시 | ~540 tok

## 게인 조정 패널 (PyQt6)

```python
from PyQt6.QtWidgets import (QWidget, QGridLayout, QLabel,
                               QDoubleSpinBox, QPushButton, QGroupBox)
from PyQt6.QtCore import pyqtSignal

class GainPanel(QGroupBox):
    """
    임피던스 제어 게인 조정 패널
    게인 변경 시 시그널 발생 → 제어 스레드에 전달
    """
    gains_changed = pyqtSignal(dict)  # {'kp': float, 'kd': float, ...}
    
    def __init__(self, gains_config: dict):
        """
        gains_config: {'kp': (default, min, max, step), ...}
        """
        super().__init__("Impedance Gains")
        layout = QGridLayout(self)
        self.spinboxes = {}
        
        for row, (name, (default, lo, hi, step)) in enumerate(gains_config.items()):
            layout.addWidget(QLabel(name), row, 0)
            sb = QDoubleSpinBox()
            sb.setRange(lo, hi)
            sb.setSingleStep(step)
            sb.setValue(default)
            sb.setDecimals(3)
            layout.addWidget(sb, row, 1)
            self.spinboxes[name] = sb
        
        apply_btn = QPushButton("Apply")
        apply_btn.clicked.connect(self._on_apply)
        layout.addWidget(apply_btn, len(gains_config), 0, 1, 2)
    
    def _on_apply(self):
        gains = {name: sb.value() for name, sb in self.spinboxes.items()}
        self.gains_changed.emit(gains)

# 사용 예:
# panel = GainPanel({
#     'Kp': (10.0, 0.0, 500.0, 1.0),
#     'Kd': (0.5,  0.0, 5.0,   0.1),
#     'tau_ff': (0.0, -18.0, 18.0, 0.1)
# })
```

## 비상 정지 버튼 (항상 최상단 표시)

```python
from PyQt6.QtWidgets import QPushButton
from PyQt6.QtCore import Qt

class EStopButton(QPushButton):
    def __init__(self, estop_callback):
        super().__init__("⚠ E-STOP")
        self.setStyleSheet("""
            QPushButton {
                background-color: #CC0000;
                color: white;
                font-size: 18px;
                font-weight: bold;
                border-radius: 8px;
                padding: 12px;
            }
            QPushButton:pressed {
                background-color: #880000;
            }
        """)
        self.setMinimumHeight(60)
        self.clicked.connect(estop_callback)
        # 키보드 단축키: Space
        self.setShortcut(Qt.Key.Key_Space)
```
