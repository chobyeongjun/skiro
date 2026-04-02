---
name: skiro-gui
description: |
  Desktop GUI development for robot control interfaces, sensor dashboards,
  and experiment UIs. Specifically for PyQt5/6, PySide, Tkinter, Kivy, or
  Dear ImGui — NOT for web frameworks (React, Vue, Next.js, CSS).
  Understands natural language layout requests like "move this left",
  "make this bigger", "these two overlap". Includes real-time pyqtgraph
  plotting, collapsible panels, dark theme, and overlap detection.
  Use when building or modifying desktop GUIs for robots, motors, sensors,
  or experiment data visualization. NOT for web apps or mobile apps.
  Keywords (EN/KR): PyQt, Tkinter, GUI, widget/위젯, dashboard/대시보드,
  plot/플롯, pyqtgraph, 실시간, panel/패널, sidebar/사이드바,
  collapsible/접기, dark theme/다크 테마, 센서 모니터, 레이아웃,
  버튼, 겹침, 크기 조절, GUI 만들어줘. (skiro)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
---

Read VOICE.md before responding.

## Phase 0: Context

1. Detect GUI framework:
   ```bash
   grep -rl "PyQt5\|PyQt6\|PySide\|tkinter\|Tkinter\|kivy\|imgui\|flutter\|React\|Vue" . --include="*.py" --include="*.dart" --include="*.js" --include="*.ts" 2>/dev/null | head -5
   ```
2. Find existing design system files:
   - `styles.py`, `theme.py`, `colors.py`, `constants.py` (Python GUI)
   - `DESIGN.md` (if exists)
   - `.css`, `.scss`, `tailwind.config` (web)
   - `theme.dart` (Flutter)
3. Load learnings for "gui", "layout", "design" tags.
4. Read `references/gui-layout-rules.md` for framework-specific patterns.
5. **Communication note**: This skill handles UI widgets and layout only.
   For BLE/WiFi/Serial connection logic (bleak, socket, pyserial), use /skiro-comm.
   For GUI↔robot data flow, see /skiro-comm Phase 5 (QThread + signal/slot).

## Phase 1: Understand the Request

### Natural Language Interpretation
The user often describes UI changes in casual language. Map their words to actions:

**Position words** → layout reorder:
- "move X left/right" → change widget order in horizontal layout
- "put X above/below Y" → change vertical order
- "swap these two" → exchange positions

**Size words** → resize:
- "bigger/smaller" → adjust minimumSize, stretch, or fixed dimensions
- "too wide/narrow/tall/short" → constrain the offending dimension
- "cramped" → increase padding/margins
- "too much empty space" → reduce margins or add stretch

**Overlap complaints** → layout fix:
- "X and Y overlap" → check for missing layout manager or fixed positioning
- "breaks on small window" → add minimumSize to window + QScrollArea
- "need fullscreen" → check for unnecessary size constraints

**Feature requests** → widget modification:
- "make X collapsible" → add toggle button + setVisible()
- "add scrollbar to X" → wrap in scroll container
- "drag to resize X" → use QSplitter or equivalent

If the request is ambiguous:
AskUserQuestion: "Which widget are you referring to? Can you describe where it is on screen?"

## Phase 2: Layout Analysis

Before making changes, analyze current state:

1. **Widget hierarchy**: trace the parent→child tree from the target widget to the window
2. **Layout manager type**: QHBoxLayout/QVBoxLayout/QGridLayout/QFormLayout or none
3. **Size constraints**: check for `setFixedSize`, `setMinimumSize`, `setMaximumSize`
4. **Size policies**: `QSizePolicy.Expanding` vs `Fixed` vs `Preferred`
5. **Stretch factors**: `layout.addWidget(w, stretch=N)`
6. **Splitters**: any `QSplitter` for user-resizable areas?

Report findings concisely: "sidebar is 280px fixed width in QHBoxLayout, main area has stretch=1"

## Phase 3: Apply Changes

Follow framework-specific patterns from `references/gui-layout-rules.md`.

### Universal Rules (all frameworks):
- **Never use absolute positioning** for main layout — use layout managers
- **Always set minimumSize** on major panels (prevents overlap)
- **Use stretch/flex** for proportional layouts, not fixed pixels
- **Add QScrollArea/overflow:auto** when content might exceed container
- **QSplitter** for user-adjustable panel boundaries
- **Test at 1024×768** mentally — will it still work?

### PyQt5/6 Specific:
```python
# Good: proportional with minimum
splitter = QSplitter(Qt.Horizontal)
sidebar.setMinimumWidth(200)
sidebar.setMaximumWidth(400)
main.setMinimumWidth(500)
splitter.addWidget(sidebar)
splitter.addWidget(main)
splitter.setStretchFactor(0, 1)   # sidebar: flex 1
splitter.setStretchFactor(1, 3)   # main: flex 3

# Bad: fixed pixels
sidebar.setFixedWidth(280)  # breaks on small screens
```

### Common Fixes:
| Problem | Fix |
|---------|-----|
| Widgets overlap on resize | Add `minimumSize` to both, use layout manager |
| Content cut off | Wrap in `QScrollArea` |
| Sidebar too dominant | Reduce stretch factor or add `maximumWidth` |
| Everything squished | Check parent has `Expanding` policy |
| Can't resize panels | Replace fixed layout with `QSplitter` |
| Panel collapses to 0px | `splitter.setCollapsible(index, False)` |
| Need collapsible panel | Toggle button + `widget.setVisible(bool)` + parent `layout.update()` |

### Collapsible Panel Pattern (PyQt5):
```python
# Toggle button in toolbar/sidebar
self.toggle_btn = QPushButton("◀")
self.toggle_btn.setFixedWidth(24)
self.toggle_btn.clicked.connect(self._toggle_panel)

def _toggle_panel(self):
    visible = not self.panel.isVisible()
    self.panel.setVisible(visible)
    self.toggle_btn.setText("▶" if not visible else "◀")
```

### Dark Theme Pattern (PyQt5):
```python
# Option A: QPalette (lightweight, no external deps)
app.setStyle("Fusion")
palette = QPalette()
palette.setColor(QPalette.Window, QColor(13, 13, 15))        # background
palette.setColor(QPalette.WindowText, QColor(220, 220, 220))  # text
palette.setColor(QPalette.Base, QColor(26, 26, 36))           # input bg
palette.setColor(QPalette.Button, QColor(34, 34, 58))         # button bg
palette.setColor(QPalette.Highlight, QColor(76, 158, 255))    # selection
app.setPalette(palette)

# Option B: Global stylesheet (more control, heavier)
app.setStyleSheet(open("styles.qss").read())
```

### Gradient Button Pattern (PyQt5):
```python
btn.setStyleSheet("""
    QPushButton {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
            stop:0 #4C9EFF, stop:1 #2DD4BF);
        color: white; border: none; border-radius: 6px; padding: 8px 16px;
    }
    QPushButton:pressed { background: #3A7BD5; }
""")
```

### Dear ImGui (Python: pyimgui)

Immediate-mode GUI — redraws every frame. No layout managers;
position and size are set per-frame. Best for fast prototyping and
debug overlays. NOT recommended for polished end-user GUIs.

```python
"""Dear ImGui robot dashboard. Requires: pip install imgui[glfw]"""
import imgui
from imgui.integrations.glfw import GlfwRenderer
import glfw
import OpenGL.GL as gl

def init_imgui():
    if not glfw.init():
        raise RuntimeError("GLFW init failed")
    window = glfw.create_window(1280, 720, "Robot Dashboard", None, None)
    glfw.make_context_current(window)
    imgui.create_context()
    impl = GlfwRenderer(window)
    return window, impl

def main():
    window, impl = init_imgui()
    # State variables (mutable — imgui reads/writes these)
    motor_cmd = [0.0]
    streaming = [False]

    while not glfw.window_should_close(window):
        glfw.poll_events()
        impl.process_inputs()
        imgui.new_frame()

        # --- Robot Control Panel ---
        imgui.begin("Motor Control")
        changed, motor_cmd[0] = imgui.slider_float(
            "Torque (Nm)", motor_cmd[0], -10.0, 10.0)
        if changed:
            pass  # send_command(motor_cmd[0])
        _, streaming[0] = imgui.checkbox("Stream Data", streaming[0])
        if imgui.button("E-STOP", width=200, height=50):
            pass  # emergency_stop()
        imgui.end()

        # --- Sensor Plot ---
        imgui.begin("Sensor Data")
        # imgui.plot_lines for simple inline plot
        import array
        data = array.array('f', [0.0] * 100)  # replace with real data
        imgui.plot_lines("Force", data, graph_size=(0, 80))
        imgui.end()

        # Render
        imgui.render()
        gl.glClear(gl.GL_COLOR_BUFFER_BIT)
        impl.render(imgui.get_draw_data())
        glfw.swap_buffers(window)

    impl.shutdown()
    glfw.terminate()
```

#### ImGui + BLE Data Thread
```python
import threading

# Shared state (lock-free for single-writer patterns)
sensor_data = {'force': 0.0, 'position': 0.0, 'connected': False}

def ble_thread(address):
    """Background thread: receive BLE data, update shared dict."""
    import asyncio
    loop = asyncio.new_event_loop()
    # ... bleak connection (see /skiro-comm Phase 1)
    # In callback: sensor_data['force'] = parsed_value

# In imgui render loop:
# imgui.text(f"Force: {sensor_data['force']:.1f} N")
```

#### ImGui Pros/Cons for Robot GUI
| Pro | Con |
|-----|-----|
| 60 FPS rendering | No persistent widget state |
| Minimal boilerplate | Manual layout (x, y, w, h) |
| GPU-accelerated | Ugly without custom styling |
| Great for debug overlays | Poor text input support |
| C++ imgui code maps 1:1 | Python bindings lag behind C++ |

### Flutter Desktop (Dart)

Cross-platform desktop GUI for polished robot dashboards.
Use when the GUI needs to run on Windows + Mac + Linux with native look.

#### Project Setup
```bash
flutter create --platforms=linux,macos,windows robot_dashboard
cd robot_dashboard
# Add dependencies
flutter pub add flutter_blue_plus   # BLE
flutter pub add fl_chart             # Charts
flutter pub add provider             # State management
```

#### Sensor Dashboard Widget
```dart
// lib/widgets/sensor_card.dart
import 'package:flutter/material.dart';

class SensorCard extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final double? min;
  final double? max;

  const SensorCard({
    required this.label,
    required this.value,
    required this.unit,
    this.min,
    this.max,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final inRange = (min == null || value >= min!) &&
                    (max == null || value <= max!);
    return Card(
      color: inRange ? Colors.grey[900] : Colors.red[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(
              color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Text('${value.toStringAsFixed(1)} $unit',
              style: const TextStyle(
                color: Colors.white, fontSize: 24,
                fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
```

#### BLE Connection (flutter_blue_plus)
```dart
// lib/services/ble_service.dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

class BleService {
  BluetoothDevice? _device;
  StreamSubscription? _dataSub;
  final _dataController = StreamController<List<double>>.broadcast();
  Stream<List<double>> get dataStream => _dataController.stream;

  // Nordic UART Service UUIDs
  static final _nusService = Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
  static final _nusTx = Guid("6e400003-b5a3-f393-e0a9-e50e24dcca9e");
  static final _nusRx = Guid("6e400002-b5a3-f393-e0a9-e50e24dcca9e");

  Future<void> connect(BluetoothDevice device) async {
    _device = device;
    await device.connect(autoConnect: true);
    final services = await device.discoverServices();
    final nus = services.firstWhere((s) => s.uuid == _nusService);
    final txChar = nus.characteristics.firstWhere((c) => c.uuid == _nusTx);
    await txChar.setNotifyValue(true);
    _dataSub = txChar.onValueReceived.listen(_parseData);
  }

  void _parseData(List<int> raw) {
    // Parse "SW19c..." protocol → List<double>
    final str = String.fromCharCodes(raw);
    // ... parsing logic
    _dataController.add([/* parsed values */]);
  }

  Future<void> disconnect() async {
    await _dataSub?.cancel();
    await _device?.disconnect();
  }
}
```

#### Flutter vs PyQt for Robot GUI
| Aspect | Flutter | PyQt5/6 |
|--------|---------|---------|
| Language | Dart | Python |
| Cross-platform | Win/Mac/Linux/mobile | Win/Mac/Linux |
| Hot reload | Yes | No |
| BLE support | flutter_blue_plus | bleak (async) |
| Real-time plots | fl_chart (60fps) | pyqtgraph (optimized) |
| Scientific computing | Limited | numpy/scipy native |
| Packaging | Single binary | pyinstaller/cx_freeze |
| Learning curve | Moderate (Dart) | Low (Python) |

**Recommendation**: PyQt for research/lab use (Python ecosystem). Flutter for distribution to non-technical users (single binary, polished UI).

## Phase 4: Design Consistency Check

After layout changes, verify design consistency:

### Spacing Rhythm
- All margins/paddings should be multiples of a base unit (4px or 8px)
- Flag inconsistent spacing: "margin: 13px" → suggest "margin: 12px (3×4)"

### Color Consistency
- All colors should come from a defined palette/dict
- Flag hardcoded hex values: `color="#3a7bd5"` → should reference palette

### Typography
- Max 2 font families in the entire app
- Consistent size hierarchy: title > heading > body > caption

### Overuse Warnings (not banned — flag only when excessive)
These are valid design choices, but overuse creates "AI slop" feeling:
- Drop shadow on EVERY widget → use only on elevated cards/modals
- Animation on EVERY interaction → reserve for state transitions
- Gradient on EVERY button → use for primary actions only, flat for secondary
- Inconsistent border-radius → pick 2-3 values and stick to them
- Color-only status indicators → always add text/icon for accessibility
**If the user explicitly requests these styles, apply them without objection.**

## Phase 4B: Real-Time Plot Integration

When adding live data plots to a GUI, use `pyqtgraph` (not matplotlib). matplotlib is for static figures; pyqtgraph is designed for real-time updates.

### PyQtGraph Real-Time Plot Pattern:
```python
import pyqtgraph as pg
from PyQt5.QtCore import QTimer
import numpy as np
from collections import deque

class RealtimePlotWidget(pg.PlotWidget):
    """Efficient real-time plot with ring buffer."""
    def __init__(self, max_points=2000, update_ms=33, parent=None):
        super().__init__(parent=parent)
        self.max_points = max_points
        self.data_x = deque(maxlen=max_points)
        self.data_y = deque(maxlen=max_points)
        self.curve = self.plot(pen=pg.mkPen("#4C9EFF", width=2))
        
        # Anti-aliasing off for performance
        self.setAntialiasing(False)
        self.setDownsampling(auto=True, mode="peak")
        self.setClipToView(True)
        
        # Timer-driven update (not data-driven!)
        self._timer = QTimer()
        self._timer.timeout.connect(self._update_plot)
        self._timer.start(update_ms)  # ~30 FPS
    
    def add_point(self, x, y):
        """Thread-safe: call from data thread."""
        self.data_x.append(x)
        self.data_y.append(y)
    
    def _update_plot(self):
        """Called by QTimer on GUI thread only."""
        if self.data_x:
            self.curve.setData(list(self.data_x), list(self.data_y))
```

### Collapsible Panel + Plot Timing Issue:
When toggling a collapsible panel that contains a plot, `canvas.draw()` can be called before the layout recalculates, causing size mismatch.

**Problem:**
```python
# BAD: draw before layout settles
def _toggle_panel(self):
    self.panel.setVisible(not self.panel.isVisible())
    self.plot_widget.update()  # ← size is still old
```

**Fix:**
```python
# GOOD: defer draw to next event loop cycle
from PyQt5.QtCore import QTimer

def _toggle_panel(self):
    visible = not self.panel.isVisible()
    self.panel.setVisible(visible)
    self.toggle_btn.setText("▶" if not visible else "◀")
    # Defer plot resize to after layout recalculation
    QTimer.singleShot(0, self._resize_plots)

def _resize_plots(self):
    """Called after layout has settled."""
    for plot in self.findChildren(pg.PlotWidget):
        plot.getViewBox().autoRange()
```

### Multi-Channel Plot Panel:
```python
class MultiChannelPlot(QWidget):
    """Stacked real-time plots with shared X-axis."""
    def __init__(self, channels: list[str], parent=None):
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(2)
        
        self.plots = {}
        prev_plot = None
        for ch_name in channels:
            pw = RealtimePlotWidget(parent=self)
            pw.setLabel("left", ch_name)
            pw.setMinimumHeight(80)
            if prev_plot:
                pw.setXLink(prev_plot)  # Shared X-axis zoom/pan
                pw.hideAxis("bottom")   # Only show X on last plot
            self.plots[ch_name] = pw
            layout.addWidget(pw)
            prev_plot = pw
        
        # Show X-axis only on last plot
        if channels:
            self.plots[channels[-1]].showAxis("bottom")
            self.plots[channels[-1]].setLabel("bottom", "Time (s)")

# Usage:
# multi = MultiChannelPlot(["Force_N", "Position_deg", "Current_A"])
# multi.plots["Force_N"].add_point(t, force_value)
```

### Performance Guidelines:
| Scenario | Approach |
|----------|----------|
| < 1000 Hz data | Direct QTimer update at 30 FPS |
| 1000-10000 Hz | Downsample in add_point (keep every Nth) |
| > 10000 Hz | Ring buffer + decimation in update |
| Multiple plots | Shared QTimer, batch updates |
| Plot in QTabWidget | Pause timer when tab not visible |

## Phase 5: Verification

Ask user to verify:
"Please resize the window to a small size and check if everything is still visible. Any overlap or cutoff?"

If issues found → iterate from Phase 2.

## Phase 6: Learn + Next Step

Log any layout fixes as learnings.
If this was part of a larger workflow:
- Building new UI → continue coding
- Pre-experiment check → /skiro-safety

## Wrong Skill? Redirect
If the user's request does not match this skill, DO NOT attempt it.
Instead, explain what this skill does and redirect to the correct one:
- Want to build a web app (React, Vue, Next.js)? → "This skill is for desktop GUI only (PyQt, Tkinter, Kivy). Use your web framework directly."
- Want to set up BLE/WiFi/Serial? → "/skiro-comm handles robot communication setup and protocol design."
- Want to analyze data? → "/skiro-analyze does RMSE, FFT, statistics."
- Want to verify code safety? → "/skiro-safety audits limits, watchdog, e-stop, timing."
- Want to flash firmware? → "/skiro-flash builds and uploads firmware to MCU."
- Want to plan an experiment? → "/skiro-plan handles experiment design and brainstorming."
- Want to test hardware? → "/skiro-hwtest generates and runs hardware test scripts."
- Want to manage data files? → "/skiro-data handles data collection, validation, and format conversion."
