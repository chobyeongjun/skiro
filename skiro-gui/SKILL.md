---
name: skiro-gui
description: |
  Robot GUI development assistant. Handles layout, styling, and interaction
  for any GUI framework: PyQt5/6, PySide, Tkinter, Kivy, Dear ImGui, Flutter,
  or web dashboards. Understands natural language layout instructions like
  "move this left", "make this bigger", "put a chart here", "these two overlap".
  Detects layout overlap and responsive issues. Enforces design consistency
  (spacing rhythm, color palette, typography hierarchy).
  Use when building or modifying robot control interfaces, data dashboards,
  experiment UIs, or any desktop/embedded GUI. Also use when the user describes
  visual changes in natural language or complains about overlapping widgets.
  Keywords: GUI, UI, layout, widget, plot, style, design, PyQt, Tkinter,
  dashboard, button, panel, tab, sidebar, responsive, overlap, move, resize,
  bigger, smaller, collapsible, dark theme, glassmorphism. (skiro)
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

## Phase 5: Verification

Ask user to verify:
"Please resize the window to a small size and check if everything is still visible. Any overlap or cutoff?"

If issues found → iterate from Phase 2.

## Phase 6: Learn + Next Step

Log any layout fixes as learnings.
If this was part of a larger workflow:
- Building new UI → continue coding
- Pre-experiment check → /skiro-safety
