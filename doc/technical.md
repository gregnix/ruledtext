# ruledtext -- Technical Documentation

Detailed technical documentation of the ruledtext module.
Architecture, coordinate systems, pitfalls, design decisions.

Procedural by design: zero dependencies beyond Tk, low barrier
to entry, simple `source`-and-go. For OOP → TclOO.
This module intentionally avoids it.

---

## 1. Architecture

### 1.1 Core Concept

The Tk text widget cannot draw lines. Canvas overlays fail because
Tk doesn't support transparent backgrounds and event forwarding
is error-prone.

**Solution:** 1px frames are placed over the text widget via `place`.
Frames are lightweight, don't need event forwarding, and `place`
positions relative to the text widget window.

### 1.2 Rejected Approaches

| Approach | Problem |
|----------|---------|
| Canvas under text widget | Text background is opaque, completely covers canvas |
| Canvas over text widget | Blocks all mouse events, event forwarding fragile |
| Embedded windows in text | Changes text content, breaks indices |
| `-spacing1`/`-spacing3` tags | Creates spacing, but no visible lines |
| `$txt tag configure -bgstipple` | No line effect, only patterns |

### 1.3 Why place + frame

```
+--[ ttk::frame $path ]---------------------------+
|  +--[ text $path.txt ]------------------------+  |
|  |                                            |  |
|  |  [frame _hl0] -------- 1px, full width     |  |
|  |  Text Line 1                               |  |
|  |  [frame _hl1] -------- 1px, full width     |  |
|  |  Text Line 2                               |  |
|  |  [frame _hl2] -------- 1px, full width     |  |
|  |  ...                                       |  |
|  |                                            |  |
|  |  [frame _margin] | 1px vertical            |  |
|  |  [frame _vl1]    | 1px vertical            |  |
|  |  [frame _vl2]    | 1px vertical            |  |
+--------------------------------------------+  |
|  +--[ ttk::scrollbar $path.sb ]--+               |
+--------------------------------------------------+
```

- Frames are children of `$path.txt` → `place -in` works
- `raise` lifts frames above text
- Frames don't receive events (1px wide/high, no relief)
- `::place` instead of `place` due to namespace shadowing (see 5.1)

### 1.4 Widget Hierarchy

```
$path                   ttk::frame (Container)
├── $path.txt           text (Main widget)
│   ├── $path.txt._hl0  frame (horizontal line 0)
│   ├── $path.txt._hl1  frame (horizontal line 1)
│   ├── ...             frame (Pool: maxlines items)
│   ├── $path.txt._margin  frame (margin)
│   ├── $path.txt._vl1  frame (vertical line 1)
│   └── $path.txt._vl2  frame (vertical line 2, ...)
└── $path.sb            ttk::scrollbar
```

### 1.5 State Management

All instance data is stored in the `ruledtext::state` array:

| Key | Type | Description |
|-----|------|-------------|
| `$path,cfg,linecolor` | Color | Per-instance line color |
| `$path,cfg,margincolor` | Color | Per-instance margin color |
| `$path,cfg,marginx` | Integer | Per-instance margin position |
| `$path,cfg,showmargin` | Boolean | Per-instance margin on/off |
| `$path,cfg,paperbg` | Color | Per-instance background |
| `$path,cfg,maxlines` | Integer | Initial pool size |
| `$path,cfg,taboffset` | Integer | Tab offset fallback |
| `$path,cfg,linefrom` | Integer | H-line start x (0 = left edge) |
| `$path,cfg,lineto` | Integer | H-line end x (0 = right edge) |
| `$path,cfg,vlinefrom` | Integer | V-line start y (0 = top edge) |
| `$path,cfg,vlineto` | Integer | V-line end y (0 = bottom edge) |
| `$path,cfg,linepattern` | List | Cyclic color list ({} = uniform) |
| `$path,hpool` | List | Frame paths of horizontal lines |
| `$path,hcount` | Integer | Current pool size |
| `$path,margin` | String | Frame path of margin line |
| `$path,vlines` | List | Pairs `{frame x}` of all vertical lines |
| `$path,vcount` | Integer | Counter for unique vline names |
| `$path,synctabs` | Boolean | Auto tab sync active? |
| `$path,gridsize` | String | `""` = linespace, `"char"` = char width |
| `$path,afterid` | String | ID of pending `after` call |
| `$path,font` | String | Name of named font |
| `$path,lastpreset` | String | Last preset (for resize reapply) |
| `$path,readonly_tag` | String | Bindtag for readonly select mode (optional) |
| `$path,orig_bindtags` | List | Original bindtags before readonly select (optional) |

Global `ruledtext::cfg` serves only as **default template**.
On `create`, cfg is copied to `state($path,cfg,*)`.
After that, all instances are independent. Setters like
`setLineColor` only change `state($path,cfg,linecolor)`.

```tcl
# Safe: different colors without resetting
set ruledtext::cfg(linecolor) "#ff0000"
ruledtext create .a
set ruledtext::cfg(linecolor) "#0000ff"
ruledtext create .b
# .a has red, .b has blue lines -- no leak
```

### 1.6 Lifecycle

```
create
  ├── copy cfg → state($path,cfg,*)
  ├── font create (Named Font)
  ├── text widget + scrollbar
  ├── _growPool (initial hline frames)
  ├── margin frame
  ├── bind events + <Destroy>
  └── after idle → _draw
runtime
  ├── events → _sched → after 16ms → _draw
  ├── _draw: sync, position hlines, margin, vlines
  ├── _draw: _growPool if needed (dynamic)
  └── _draw: _reapplyVGrid if resize + vgrid preset
destroy
  └── _cleanup
      ├── after cancel
      ├── font delete
      ├── readonly bindtag cleanup (if exists)
      └── array unset state($path,*)
```

---

## 2. Coordinate Systems

### 2.1 Three Reference Systems in Text Widget

Understanding coordinate systems was the hardest problem during
development. There are three reference points:

```
Widget Edge                    Text Edge
|                              |
|<-- borderwidth -->|<-- padx -->|<-- Text Content -->
|                              |
|  place -x measures          |  -tabs measures
|  from here                  |  from here
```

**1. Widget Window (place -x)**
- Origin: left top corner of entire text widget window
- Includes `borderwidth` and `padx`
- Used by: `place -x`, `winfo width`

**2. Text Content Area (-tabs)**
- Origin: left edge after `borderwidth` AND `padx`
- Used by: `-tabs`, `@x,y` indices

**3. Display Lines (dlineinfo)**
- Origin: left top corner of widget window (like place)
- Used by: `dlineinfo`, `bbox`

### 2.2 Calculating Tab Position

Vertical lines are positioned via `place -x` (System 1).
Tab stops measure from the text area (System 2).
The difference is `borderwidth` (not `padx`!).

```
tabpos = vline_x - borderwidth + offset
```

**Why not padx?**
`-tabs` measures from the point where text can start. That is
after `borderwidth` AND after `padx`. But `place -x` measures
from the widget edge, so only before `borderwidth`. Since `padx`
is added equally to both systems, it cancels out.

Wrong thinking:
```
place -x = borderwidth + padx + textposition
-tabs    = textposition
→ tabs = place_x - borderwidth - padx    ← WRONG
```

Correct:
```
place -x:  measures from widget edge (before borderwidth)
-tabs:     measures from text area (after borderwidth)
padx:      shifts both equally
→ tabs = place_x - borderwidth              ← CORRECT
```

### 2.3 Offset Variants

| Goal | Offset | Result |
|------|--------|--------|
| Text 1px right of line | `+ 1` | Exact alignment |
| Text centered in column | `+ (colwidth/2) + 2` | Visually centered |
| Text directly at line | `+ 0` | Text starts on line |

`syncTabs` uses centering (colwidth/2 + 2).
`demo-tablines.tcl` uses +1 for exact alignment.

---

## 3. Horizontal Lines

### 3.1 Pool System

On `create`, `cfg(maxlines)` (default 80) frames are pre-created.
`_draw` shows needed ones via `place` and hides the rest via `place forget`.

**Dynamic Growth (v1.1):**
If the window needs more lines than the pool has,
`_draw` automatically calls `_growPool`:

```tcl
set needed [expr {int(($H - $y) / $lineH) + 2}]
if {$needed > [llength $pool]} {
    _growPool $path $needed
    set pool $state($path,hpool)
}
```

**Why Pool + Growth instead of purely dynamic?**
- `frame create` + `destroy` on every redraw would be too slow
- Pool: only `place`/`place forget` per frame → fast
- Growth: no silent line loss on large windows/small fonts
- Frames are only added, never removed (pool doesn't shrink)

### 3.2 Line Spacing

```tcl
set lineH [font metrics $font -linespace]
```

`-linespace` = Ascent + Descent + Leading. This is the natural
line spacing of the font.

**Factor 1.5:** The first line starts at `ay + 1.5 * lineH`,
where `ay` is the Y-offset of the first visible line
(from `dlineinfo @0,0`). Factor 1.5 positions lines
**between** text rows, not on them.

### 3.3 Scroll Synchronization

```tcl
while {$y > $lineH} { set y [expr {$y - $lineH}] }
```

The start position is "recalculated" upward so that
lines appear correctly at the top edge when text is
scrolled. Result: lines move seamlessly with the text.

### 3.4 Grid Modes

| Mode | `state($path,gridsize)` | Horizontal Spacing |
|------|------------------------|-------------------|
| Normal | `""` | `font metrics -linespace` |
| Char | `"char"` | `font measure "M"` (em width) |

Char mode exists for experiments, but is **not**
recommended for square grids (see 4.2).

### 3.5 Line Range

Horizontal lines can be restricted to a sub-region using
`setLineRange $path $from $to`. In `_draw`:

```tcl
set hx $state($path,cfg,linefrom)
set hto $state($path,cfg,lineto)
set hw [expr {($hto > 0 ? $hto : $W) - $hx}]
# place each frame at -x $hx -width $hw
```

`0` as end value means right widget edge. This is useful
for notebook paper where lines start at the margin:

```tcl
ruledtext setLineRange .ed 55 0   ;# start at margin
```

Presets reset both to 0 (full width) and can define
`linefrom`/`lineto` as preset dict keys.

### 3.6 Line Pattern

`setLinePattern` assigns a cyclic color list to horizontal
lines. In `_draw`, each line's color is determined by
`$used % $plen`:

```tcl
set pattern $state($path,cfg,linepattern)
set plen [llength $pattern]
# in the loop:
set pc [lindex $pattern [expr {$used % $plen}]]
if {$pc eq ""} { place forget $f; continue }
$f configure -background $pc
```

An empty string `""` in the pattern makes that line
invisible (the frame is `place forget`'d, leaving a gap).
When the pattern is cleared (`{}`), `setLinePattern`
restores the uniform `linecolor` on all pool frames.

The `music` preset uses this to create a 5-on-3-off
staff pattern:

```tcl
linepattern {"#b0b0b0" "#b0b0b0" "#b0b0b0" "#b0b0b0" "#b0b0b0" "" "" ""}
```

PDF export reproduces both line range and line pattern.

---

## 4. Vertical Lines and Square Grids

### 4.1 Dynamic Vertical Lines

Unlike horizontal lines (pool), vertical lines are
created and destroyed dynamically:

```tcl
# Create:
set f [frame $path.txt._vl$count -width 1 ...]
lappend state($path,vlines) [list $f $x]

# Destroy:
place forget $f
destroy $f
```

Each vline has a unique number (`vcount`) so that
Tk widget paths don't collide.

### 4.2 Square Grid (squared/graph)

**Problem:** First implementation used different metrics:
- Horizontal: `font metrics -linespace` ≈ 17px (Courier 12)
- Vertical: `font measure "M"` ≈ 9-10px (em width)
- Result: rectangles instead of squares

**Solution:** Both axes use `font metrics -linespace`:

```tcl
set step [font metrics $font -linespace]
for {set x $step} {$x < $W} {incr x $step} {
    addVLine $path $x [dict get $p linecolor]
}
```

Same value for horizontal and vertical spacing = squares.

### 4.3 VGrid Shrink (v1.1)

When a vgrid preset (`squared`, `graph`) is applied and the widget
is resized smaller, `_reapplyVGrid` automatically removes lines
outside the visible area:

```tcl
foreach vl $state($path,vlines) {
    set x [lindex $vl 1]
    if {$x < $W} {
        lappend vlinesToKeep $vl
    } else {
        # Remove line outside visible area
        set f [lindex $vl 0]
        if {[winfo exists $f]} {
            destroy $f
        }
    }
}
```

This prevents lines from extending beyond the widget edge when
the window is made smaller.

### 4.4 Vertical Line Range (v1.1)

Vertical lines and the margin line can be restricted to a
sub-region using `setVLineRange $path $from $to`. In `_draw`:

```tcl
set vy $state($path,cfg,vlinefrom)
set vto $state($path,cfg,vlineto)
set vh [expr {($vto > 0 ? $vto : $H) - $vy}]

# margin: place at -y $vy -height $vh
# vlines: place at -y $vy -height $vh
```

`0` as end value means bottom widget edge. This applies to
the margin line and all vertical lines equally.

PDF export reproduces the vertical range by computing
`vy1`/`vy2` offsets from `areaY`.

---

## 5. Tab Synchronization

### 5.1 Tk -tabs Syntax

The `-tabs` option of the text widget expects a Tcl list
of alternating position and alignment values:

```tcl
$txt configure -tabs {100 left 250 left 400 left}
```

**Three pitfalls that all occurred:**

#### Pitfall 1: Point Suffix `p`

```tcl
# WRONG: "138p" = 138 Points (1/72 inch), not pixels
# At 96 dpi: 1 Point = 1.333 pixels
# Deviation grows with value!
lappend tabs "${tabpos}p left"

# CORRECT: no suffix = pixels
lappend tabs $tabpos left
```

| Suffix | Unit | 1px at 96dpi |
|--------|------|--------------|
| (none) | Pixels | 1.0 |
| `p` | Points (1/72") | 0.75 |
| `m` | Millimeters | ~0.26 |
| `c` | Centimeters | ~0.026 |
| `i` | Inches | ~0.01 |

#### Pitfall 2: String Instead of List Elements

```tcl
# WRONG: ONE list element "138 left" → Tk error
#   "bad screen distance 138 left"
lappend tabs "${tabpos} left"

# CORRECT: TWO separate list elements
lappend tabs $tabpos left
```

`lappend` with one argument adds **one** element.
The string `"138 left"` contains a space, but is still
a single list element (quoted).
Tk expects two separate elements: `138` and `left`.

#### Pitfall 3: padx Subtraction

```tcl
# WRONG: padx is subtracted twice
set tabpos [expr {$x - $padx - $bw + $offset}]

# CORRECT: only borderwidth
set tabpos [expr {$x - $bw + $offset}]
```

See section 2.2 for complete explanation.

### 5.2 tabstyle

| Value | Behavior |
|-------|----------|
| `tabular` (Default) | Tabs jump to next position right of current point |
| `wordprocessor` | Tabs jump to absolute position (like Word) |

`wordprocessor` is correct for column layouts because the
tab position is independent of previous text. With `tabular`,
long text in column 1 can shift the tab position of column 2.

Presets with `tabs 1` automatically set `-tabstyle wordprocessor`.
On preset change, it's reset to `tabular`.

### 5.3 syncTabs Algorithm

```
1. Collect all x positions from state($path,vlines)
2. Sort ascending
3. Calculate colwidth = position[1] - position[0]
4. offset = (colwidth / 2) + 2
5. For each position: tabpos = x - borderwidth + offset
6. $txt configure -tabs $tabs
```

---

## 6. Named Fonts

### 6.1 Why Named Fonts

```tcl
# Without named font: font change requires manual update
$txt configure -font {Courier 14}
# Tags with own font must be changed separately!

# With named font: one call changes everything
font configure $fontname -size 14
# All widgets and tags with this font update automatically
```

### 6.2 Implementation

```tcl
# create:
set state($path,font) "RuledFont_$path"
font create $state($path,font) {*}[font actual {Courier 12}]

# setFont:
font configure $state($path,font) {*}[font actual $fontspec]

# cleanup:
catch { font delete $state($path,font) }
```

`font actual` normalizes the font specification into a dict
that `font configure` accepts directly:

```tcl
font actual {Courier 12}
# → -family Courier -size 12 -weight normal -slant roman ...
```

### 6.3 Font Name Collisions

The font name contains the widget path (`RuledFont_.ed`).
This makes multiple instances independent. Dots in the path
are allowed in font names.

---

## 7. Lifecycle and Cleanup

### 7.1 The Problem

Without cleanup, when `destroy .ed` is called, the following data remains:
- `state(.ed,hpool)` → list with paths to no longer existing widgets
- `state(.ed,font)` → named font occupies memory
- `state(.ed,afterid)` → `after` callback references destroyed widget
- `state(.ed,readonly_tag)` → bindtag remains (if readonly select was used)

With many instances (e.g., notebook tabs), memory grows.

### 7.2 The Solution

```tcl
bind $path <Destroy> +[list ruledtext::_cleanup $path]
```

**Important:** `+` before the command so other `<Destroy>` bindings
are not overwritten.

`_cleanup` does four things:
1. `after cancel` for pending redraws
2. `font delete` for the named font
3. Cleanup readonly bindtag if it exists
4. `array unset` for all `state($path,*)` entries

### 7.3 Order on Destroy

Tk destroys widgets top-down. When `$path` is destroyed:
1. `<Destroy>` fires on `$path`
2. `_cleanup` cleans up state
3. Tk destroys `$path.txt` and all child frames automatically

That's why `_cleanup` binds to `$path` (the container), not
to `$path.txt`.

---

## 8. Redraw Throttling

### 8.1 Problem

Without throttling, `<Configure>`, `<KeyRelease>`, `<MouseWheel>`
generate dozens of redraws per second. Each redraw calculates positions
and calls `place` for up to 80+ frames.

### 8.2 Solution: after 16ms + Destroy Guard

```tcl
proc ruledtext::_sched {path} {
    variable state
    if {![info exists state($path,afterid)]} return
    if {$state($path,afterid) ne ""} return
    set state($path,afterid) \
        [after 16 [list ruledtext::_draw $path]]
}
```

16ms ≈ 60fps. Multiple events within 16ms generate
only one redraw. `_draw` sets `afterid` to `""` at the start,
so the next event can schedule a new redraw again.

**Destroy Guard:** `_sched` checks `info exists state($path,afterid)`.
If the widget is destroyed between schedule and draw,
the state no longer exists → no access to dead path.
`_draw` has `winfo exists $txt` as a second safeguard.

### 8.3 Event Binding Chaining (v1.1)

`<Configure>` and `<KeyRelease>` don't support the `+` prefix
for appending bindings. To avoid overwriting external bindings,
we manually chain them:

```tcl
# Configure: Chain with existing binding if any
set existingConfigure [bind $path.txt <Configure>]
if {$existingConfigure ne ""} {
    bind $path.txt <Configure> "$existingConfigure; [list ruledtext::_sched $path]"
} else {
    bind $path.txt <Configure> [list ruledtext::_sched $path]
}

# Also bind on frame to catch frame resize
bind $path <Configure> +[list ruledtext::_sched $path]
```

This ensures that external bindings on the text widget are preserved
and our redraw scheduling is added without overwriting them.

### 8.4 $txt sync

```tcl
$txt sync
```

Before `dlineinfo @0,0` in `_draw`. Forces the text widget
to complete its layout calculation. Without `sync`, `dlineinfo`
can return stale or inaccurate values on large documents,
because Tk performs layout calculation asynchronously.

**Cost:** Minimal on small documents. On very large documents
(>10000 lines), `sync` can briefly block.

---

## 9. Readonly Mode

### 9.1 The Pattern

```tcl
proc ruledtext::setReadonly {path {readonly 1}} {
    $path.txt configure -state [expr {$readonly ? "disabled" : "normal"}]
}
```

### 9.2 Why Not Permanently Disabled?

`-state disabled` prevents **all** changes, including
programmatic ones. For display widgets (log viewer, help)
the state must be temporarily set to `normal`.

`insertText` encapsulates this pattern: check state → normal →
insert → back to disabled.

### 9.3 Readonly Select Mode (v1.1)

For viewer use cases where mouse selection is needed but keyboard
editing should be blocked, use `setReadonly .ed select`:

```tcl
proc ruledtext::setReadonly {path {readonly 1}} {
    variable state
    set txt $path.txt
    
    if {$readonly eq "select"} {
        # Select mode: block keyboard editing but allow mouse selection
        # Keep widget in normal state, block key bindings
        $txt configure -state normal
        
        # Store original bindtags if not already stored
        if {![info exists state($path,orig_bindtags)]} {
            set state($path,orig_bindtags) [bindtags $txt]
        }
        
        # Create readonly bindtag if it doesn't exist
        if {![info exists state($path,readonly_tag)]} {
            set state($path,readonly_tag) "RuledTextReadonly_$path"
            bind $state($path,readonly_tag) <KeyPress> {break}
            bind $state($path,readonly_tag) <KeyRelease> {break}
        }
        
        # Add readonly tag to bindtags (before Text bindings)
        set tags [bindtags $txt]
        if {$state($path,readonly_tag) ni $tags} {
            set tags [linsert $tags 0 $state($path,readonly_tag)]
            bindtags $txt $tags
        }
    } elseif {$readonly} {
        # Disabled mode: traditional readonly (no editing, no selection)
        $txt configure -state disabled
        # Restore original bindtags if we were in select mode
        if {[info exists state($path,orig_bindtags)]} {
            bindtags $txt $state($path,orig_bindtags)
            unset state($path,orig_bindtags)
        }
    } else {
        # Normal mode: full editing
        $txt configure -state normal
        # Restore original bindtags if we were in select mode
        if {[info exists state($path,orig_bindtags)]} {
            bindtags $txt $state($path,orig_bindtags)
            unset state($path,orig_bindtags)
        }
    }
}
```

**Modes:**
- `setReadonly .ed 1` - Disabled mode: no editing, no selection
- `setReadonly .ed select` - Select mode: no keyboard editing, but mouse selection allowed
- `setReadonly .ed 0` - Normal mode: full editing enabled

### 9.4 Effects on Bindings

| Feature | normal | disabled | select |
|---------|--------|----------|--------|
| Keyboard input | Yes | No | No |
| Mouse selection | Yes | No | Yes |
| Cursor visible | Yes | No | Yes |
| `$txt insert` | Yes | No (Error) | Yes |
| `$txt see` | Yes | Yes | Yes |
| `$txt get` | Yes | Yes | Yes |
| Tags/Marks | Yes | Yes | Yes |

---

## 10. -insertunfocussed hollow

### 10.1 Purpose

In split views (two ruledtext instances side by side), the
inactive widget shows the cursor as a hollow frame. The user
sees where the cursor is in both panels.

### 10.2 Options (since Tk 8.6.9)

| Value | Behavior |
|-------|----------|
| `none` | Cursor invisible (default) |
| `hollow` | Cursor as empty frame |
| `solid` | Cursor fully visible (no blink) |

### 10.3 Limitation

Only relevant for `text` widgets. `ttk::entry` doesn't have this option.
For older Tk versions (<8.6.9), the option is silently ignored.

---

## 11. source -encoding utf-8

### 11.1 The Problem

```
Windows system: cp1252 (Western European)
Tcl 8.6 source: reads with system encoding
→ UTF-8 bytes interpreted as cp1252
→ "ü" (UTF-8: c3 bc) becomes "Ã¼" (cp1252: c3=Ã, bc=¼)
```

### 11.2 The Rule

```tcl
# ALWAYS:
source -encoding utf-8 ruledtext.tcl

# NEVER:
source ruledtext.tcl
```

Available since Tcl 8.5. In Tcl 9, UTF-8 is the default,
`-encoding utf-8` doesn't hurt.

### 11.3 Where It Breaks

- Comments with umlauts: No runtime error, but wrong characters
- Strings with umlauts: Wrong output
- `package provide` with special characters: Package not found
- Regular expressions with Unicode classes: Unexpected matches

### 11.4 Tcl 9 Stricter

Tcl 9 is **strict UTF-8**. Invalid byte sequences generate
errors instead of silent corruption. The tcl8 profile (silent
handling as ISO8859-1) exists only for backward compatibility.

---

## 12. Presets

### 12.1 Preset Dict Structure

Each preset is a Tcl dict with optional keys:

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `linecolor` | Color | Yes | Horizontal line color |
| `paperbg` | Color | Yes | Background color |
| `margincolor` | Color | Yes | Margin color |
| `showmargin` | Boolean | Yes | Margin on/off |
| `font` | Fontspec | Yes | Font |
| `fg` | Color | No | Text color (default: black) |
| `vgrid` | Boolean | No | Square grid |
| `vcols` | List | No | Fixed column positions (pixels) |
| `vcolor` | Color | No | Column line color |
| `tabs` | Boolean | No | Enable tab sync |
| `gridsize` | String | No | `"char"` for em width |
| `linefrom` | Integer | No | H-line start x (default: 0) |
| `lineto` | Integer | No | H-line end x (0 = right edge) |
| `vlinefrom` | Integer | No | V-line start y (default: 0) |
| `vlineto` | Integer | No | V-line end y (0 = bottom edge) |
| `linepattern` | List | No | Cyclic color pattern ({} = uniform) |

### 12.2 Preset Application Order

```
1. clearVLines          → remove old vertical lines
2. gridsize reset       → back to linespace
3. linefrom/lineto      → reset to 0 (full width)
4. vlinefrom/vlineto    → reset to 0 (full height)
5. linepattern          → reset to {} (uniform)
6. tabs reset           → -tabs {} -tabstyle tabular
7. setLineColor         → color horizontal lines
8. paperbg              → set background
9. margincolor          → margin color
10. toggleMargin        → margin on/off
11. setFont             → change font (named font)
12. fg/insertbackground → text color
13. linefrom/lineto     → if in preset dict
14. vlinefrom/vlineto   → if in preset dict
15. linepattern         → if in preset dict
16. gridsize            → if "char" in preset
17. vgrid               → create square grid
18. vcols               → create column lines
19. tabstyle + tabsync  → tab synchronization
20. _draw               → redraw
```

Order is important: font must be set before vgrid so that
`font metrics -linespace` returns the correct value.

---

## 13. Known Limitations

### 13.1 Uniform Font Only

The module assumes uniform font size.
If tags with other font sizes are used, line spacing
no longer matches. For mixed-font support, `dlineinfo`
would need to be queried per line (as in textlines.tcl,
the predecessor module).

### 13.2 Square Grid on Resize (partially solved)

`squared`/`graph` presets create vertical lines based on
widget width. On resize, the grid **grows** automatically
(via `_reapplyVGrid` in `_draw`). When **shrinking**, excess
lines remain — they extend beyond the visible area but don't
disturb. For complete redraw: reapply preset.

**Update (v1.1):** `_reapplyVGrid` now removes lines outside
the visible area when shrinking, so excess lines are cleaned up.

### 13.3 place and Scrollbar

`place` positions relative to the visible area of the
text widget. When scrolling, frames do **not** move
automatically. That's why `_draw` is called on every scroll event.
The throttling (16ms) prevents overload.

### 13.4 Readonly Blocks Mouse Selection (partially solved)

`-state disabled` also prevents text selection via mouse.
For viewers that need selection, a `bindtags`-based approach
would be better (KeyPress → break, mouse unchanged). This is
now implemented as `setReadonly .ed select` mode (v1.1).

---

## 14. PDF Export

### 14.1 Namespace Design (v1.1)

All PDF helper functions are in the `ruledtext::pdf::` namespace
instead of `ruledtext::` to keep the main namespace clean:

```tcl
proc ruledtext::pdf::_hexToRGB {hex} { ... }
proc ruledtext::pdf::_colorToRGB {color} { ... }
proc ruledtext::pdf::_mapFont {family} { ... }
proc ruledtext::pdf::_sanitize {text} { ... }
proc ruledtext::pdf::_defaultPageLabel {} { ... }
proc ruledtext::pdf::_renderTabLine {pdf line ...} { ... }
```

### 14.2 Fontsize Conversion (v1.1)

Negative font sizes (pixels) are converted to points using DPI-aware
scaling:

```tcl
if {$fontSize < 0} {
    # Negative = pixels, convert to points via DPI/Tk scaling
    set pixels [expr {abs($fontSize)}]
    if {[catch {tk scaling} scaling]} {
        set scaling 1.0
    }
    set fontSize [expr {$pixels * 72.0 / (96.0 * $scaling)}]
}
```

This ensures correct conversion on HiDPI displays (1.5x, 2x scaling).

### 14.3 Line Range and Pattern in PDF (v1.1)

The PDF export reads all range and pattern cfg values from the
widget state and applies them to the rendered PDF:

**Horizontal line range** (`linefrom`/`lineto`):
```tcl
set hx1 [expr {$areaX + $linefrom}]
set hx2 [expr {$lineto > 0 ? $areaX + $lineto : $areaRight}]
$pdf line $hx1 $ly $hx2 $ly
```

**Line pattern** (`linepattern`):
Each line's color is determined by `$i % $plen`. Empty strings
are skipped (`continue`), producing gaps identical to the widget.

**Vertical line range** (`vlinefrom`/`vlineto`):
```tcl
set vy1 [expr {$areaY + $vlinefrom}]
set vy2 [expr {$vlineto > 0 ? $areaY + $vlineto : $areaY + $areaH}]
# margin and vlines use vy1/vy2 instead of areaY/areaY+areaH
```

---

## 15. Files and Distribution

### 15.1 File Overview

| File | Lines | Description |
|------|-------|-------------|
| `lib/ruledtext-1.1.tm` | ~870 | Tcl module |
| `lib/ruledtext/pdf-1.1.tm` | ~385 | PDF export module |
| `demos/demo-presets.tcl` | 86 | All 11 presets with tab example |
| `demos/demo-split.tcl` | 107 | Two instances, readonly, insertunfocussed |
| `demos/demo-tablines.tcl` | 57 | Tab stops exactly at vertical lines |
| `demos/demo-pdf-export.tcl` | 185 | PDF export with all visual settings |
| `demos/demo-font-metrics.tcl` | 103 | Font metrics and line spacing |
| `demos/demo-log-viewer.tcl` | 91 | Log viewer with readonly select mode |
| `demos/demo-margin-toggle.tcl` | 161 | Margin, line range, line pattern |
| `demos/demo-readonly-select.tcl` | 90 | Readonly modes comparison |
| `demos/demo-vgrid-resize.tcl` | 85 | VGrid resize behavior |
| `test/test_ruledtext.tcl` | ~650 | Unit tests (43 tests) |
| `test/test_pdf.tcl` | ~240 | PDF export tests (14 tests) |
| `README.md` | ~700 | User documentation |
| `doc/technical.md` | ~1040 | Technical documentation |
| `doc/manual.md` | ~250 | API reference manual |
| `CHANGES.md` | ~155 | Version history |


### 15.2 Proc Overview

**Public:**

| Proc | Description |
|------|-------------|
| `create` | Create widget |
| `textwidget` | Return text widget path |
| `setFont` | Change font (named font) |
| `setLineColor` | Horizontal line color (per instance) |
| `setLineRange` | Horizontal line start/end position |
| `setLinePattern` | Cyclic color pattern for horizontal lines |
| `toggleMargin` | Margin on/off (per instance) |
| `setMarginX` | Margin position in pixels |
| `setMarginColor` | Margin line color |
| `clear` | Clear content |
| `setReadonly` | Readonly mode (disabled/select/normal) |
| `insertText` | Insert text (even when readonly) |
| `setGridSize` | Grid mode |
| `addVLine` | Add vertical line (pixels) |
| `clearVLines` | Remove all vertical lines |
| `setVLineColor` | Color of all vertical lines |
| `setVLineRange` | Vertical line start/end position |
| `syncTabs` | Synchronize tab stops |
| `setTabSync` | Auto-sync on/off |
| `presetNames` | List of all preset names |
| `preset` | Apply preset |
| `exportPDF` | Export to PDF (requires ruledtext::pdf) |

**Internal:**

| Proc | Description |
|------|-------------|
| `_sched` | Schedule redraw (throttle) |
| `_onScroll` | Scrollbar callback |
| `_cleanup` | Destroy handler |
| `_draw` | Core routine: position lines |
| `_growPool` | Dynamically extend pool |
| `_reapplyVGrid` | Extend vgrid on resize |

---

## 16. Dependencies and Distribution

- **Tcl/Tk 8.6+** (for `-insertunfocussed`, `$txt sync`)
- **No external packages** (only `package require Tk`)
- **No TclOO** (intentionally procedural)
- **No Canvas** (only text + frame + place)
- **pdf4tcl 0.9+** (optional, for PDF export)

### Distribution as Tcl Module

```
ruledtext/
  lib/
    ruledtext-1.1.tm
    ruledtext/
      pdf-1.1.tm
```

Load:

```tcl
tcl::tm::path add /path/to/modules
package require ruledtext 1.1
package require ruledtext::pdf 1.1  ;# optional
```

No `pkgIndex.tcl` needed. The filename encodes name and version.
Direct `source -encoding utf-8 ruledtext-1.1.tm` also works.

### namespace ensemble

The module exports all public procs as an ensemble:

```tcl
ruledtext create .ed            ;# Ensemble style
ruledtext::create .ed           ;# Explicit (still valid)
```
