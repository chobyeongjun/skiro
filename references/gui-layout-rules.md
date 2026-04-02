# GUI Layout Rules

Rules for building and modifying robot GUI interfaces.
Read this when working on GUI layout, styling, or natural language UI requests.

## Natural Language → Layout Command Mapping

When a user describes a visual change in natural language, map it to a structured action:

### Position / Movement
| User says | Action | Implementation |
|-----------|--------|---------------|
| "move X left/right/up/down" | Reorder widget in layout | Change `addWidget()` order or `grid` row/col |
| "put X next to Y" | Horizontal layout | `QHBoxLayout` / `Row` / `display: flex` |
| "put X below Y" | Vertical layout | `QVBoxLayout` / `Column` / `flex-direction: column` |
| "swap X and Y" | Reorder | Swap widget positions in layout code |
| "center X" | Alignment | `setAlignment(Qt.AlignCenter)` / `justify-content: center` |

### Size / Space
| User says | Action | Implementation |
|-----------|--------|---------------|
| "make X bigger/smaller" | Resize | Adjust `minimumSize` / `maximumSize` / stretch factor |
| "X is too wide/narrow" | Width constraint | `setFixedWidth()` / `setMinimumWidth()` / `max-width` |
| "more space between X and Y" | Spacing | `layout.setSpacing()` / `margin` / `gap` |
| "X is cramped" | Increase padding | Add `setContentsMargins()` / `padding` |
| "make sidebar narrower" | Width reduction | Reduce `setFixedWidth()` or stretch ratio |

### Visibility / Interaction
| User says | Action | Implementation |
|-----------|--------|---------------|
| "make X collapsible" | Toggle visibility | Add collapse button + `setVisible(bool)` |
| "hide X" | Remove from view | `widget.hide()` or remove from layout |
| "X should scroll" | Add scroll area | Wrap in `QScrollArea` / `overflow: auto` |
| "X should be draggable" | Drag support | `QSplitter` for resizable, `eventFilter` for drag |

### Overlap / Responsive Issues
| User says | Action | Implementation |
|-----------|--------|---------------|
| "X and Y overlap" | Fix overlap | Set `minimumSize`, use proper layout manager |
| "breaks on small window" | Responsive fix | Set `minimumSize` on window, add `QScrollArea` |
| "need full screen" | Remove min constraints | Check for hardcoded sizes, use stretch instead |
| "too much empty space" | Fill space | Add stretch factors, use `Expanding` size policy |

### Styling / Theming
| User says | Action | Implementation |
|-----------|--------|---------------|
| "dark theme" / "어두운 테마" | Apply dark palette | `QPalette` + `Fusion` style or global QSS |
| "gradient buttons" | Gradient stylesheet | `qlineargradient` in QSS |
| "color change" / "색 바꿔줘" | Modify palette/stylesheet | Update color dict or CSS variables |
| "transparent" / "반투명" | Opacity/glassmorphism | `rgba()` background + `backdrop-filter: blur` |
| "font bigger" / "글씨 크게" | Font size increase | Update stylesheet font-size |

### Korean Natural Language Patterns (한국어)
| 표현 | 의미 | 매핑 |
|------|------|------|
| "붙여줘" / "갖다 붙여" | Place adjacent | LAYOUT [A,B] adjacent |
| "딱 맞게" | Fit exactly | SIZE target=X fit=exact |
| "여백 좀 줘" | Add padding/margin | SPACE target=X increase |
| "접어줘" / "펼쳐줘" | Collapse/expand | TOGGLE target=X |
| "탭으로 나눠줘" | Split into tabs | CONVERT target=X to=QTabWidget |
| "창 두 개로" | Split into panels | ADD QSplitter |
| "위에 놓아줘" | Place above | MOVE target=X dir=UP |
| "옆에 놓아줘" | Place beside | LAYOUT [A,B] dir=HORIZ |
| "너무 좁아" | Too narrow | RESIZE target=X wider |
| "잘려" / "짤려" | Content clipped | FIX overflow → QScrollArea |

## Framework-Specific Layout Patterns

### PyQt5 / PyQt6 / PySide
```python
# Prevent overlap: ALWAYS set minimum sizes
widget.setMinimumSize(200, 100)

# Use stretch for proportional layouts
layout.addWidget(sidebar, stretch=1)
layout.addWidget(main_area, stretch=3)  # 3:1 ratio

# Responsive: use QSplitter instead of fixed widths
splitter = QSplitter(Qt.Horizontal)
splitter.addWidget(sidebar)
splitter.addWidget(main)
splitter.setSizes([250, 750])  # initial, but user-resizable

# Size policies
widget.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
```

### Tkinter
```python
# Use grid with weight for responsive layouts
root.columnconfigure(0, weight=1, minsize=200)
root.columnconfigure(1, weight=3, minsize=400)

# Pack with fill and expand
frame.pack(fill=tk.BOTH, expand=True)
```

### Web (HTML/CSS)
```css
/* Use flexbox with min-width to prevent overlap */
.container { display: flex; gap: 8px; }
.sidebar { flex: 0 0 250px; min-width: 200px; }
.main { flex: 1; min-width: 400px; }

/* Responsive: wrap on small screens */
@media (max-width: 768px) {
  .container { flex-direction: column; }
}
```

### Flutter
```dart
// Use Expanded with flex for proportional layouts
Row(children: [
  Expanded(flex: 1, child: Sidebar()),
  Expanded(flex: 3, child: MainArea()),
])

// Responsive: use LayoutBuilder
LayoutBuilder(builder: (context, constraints) {
  if (constraints.maxWidth < 600) return MobileLayout();
  return DesktopLayout();
})
```

## Overlap Prevention Checklist

Before delivering any GUI change, verify:

- [ ] **No hardcoded absolute positions** — use layout managers, not `setGeometry()` or `place()`
- [ ] **minimumSize set** on all major panels (sidebar, main area, toolbar)
- [ ] **Window minimumSize set** — prevent window from shrinking past usable size
- [ ] **Stretch factors assigned** — at least one widget should expand to fill space
- [ ] **QScrollArea for overflow** — if content can exceed container, wrap it
- [ ] **Test at 1024×768** — this is the minimum "reasonable" desktop size
- [ ] **Test at 800×600** — if required to work on small displays
- [ ] **No fixed-width containers** unless intentional (toolbars, status bars)
- [ ] **Splitter for user-adjustable** panels (sidebar vs main area)
- [ ] **Text truncation handled** — `elideMode` or wrap, not overflow

## Design Consistency Checklist

Borrowed from design-review best practices:

### Spacing Rhythm
- Use a base unit (4px or 8px) and only use multiples of it
- Consistent margins: inner content → 12-16px, between sections → 24-32px
- Do not mix arbitrary pixel values

### Color
- All colors from a defined palette (dict, CSS variables, theme)
- No hardcoded hex values scattered in code
- Sufficient contrast: text on dark bg ≥ 4.5:1 (WCAG AA)

### Typography
- Maximum 2 font families
- Consistent hierarchy: heading → subheading → body → caption
- Body text ≥ 12px (desktop), ≥ 14px (touch/tablet)

### AI Slop Anti-Patterns (avoid these)
- Purple/blue gradients everywhere
- Uniform rounded corners on everything
- Drop shadows on every element
- Overuse of blur/glassmorphism without purpose
- Generic icon sets with no meaning
- 3-column symmetric card grids
- Gratuitous animation on every interaction
