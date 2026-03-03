# ruledtext

**Ruled Text Widget for Tcl/Tk** — Create notebook paper-style text widgets with horizontal lines, vertical lines, margins, presets, and PDF export.

[![Tcl/Tk](https://img.shields.io/badge/Tcl%2FTk-8.6.9%2B-blue)](https://www.tcl.tk/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.1-orange)](CHANGES.md)

Single Tcl module (`ruledtext-1.1.tm`) for creating text widgets
with horizontal lines, vertical lines, left/right margin, paper
presets, tab sync, readonly mode, and named fonts.


## Features

- **Horizontal lines** with configurable color, range, and cyclic
  color patterns (alternating, staff notation, rainbow)
- **Left and right margin** lines with independent position and color
- **Vertical lines** (dynamic) with color and range control
- **11 built-in presets:** college, vintage, minimal, dark, green,
  squared, graph, columns, ledger, music, todo
- **Tab synchronization** with vertical line positions
- **Readonly mode** with three options: normal, disabled, select
  (mouse selection allowed, keyboard blocked)
- **PDF export** with full visual fidelity (lines, margins, patterns,
  tabs, pagination, i18n page labels)
- **Named fonts** with automatic line spacing update
- **Per-instance configuration** -- multiple widgets, no leaks
- **Dynamic pool growth** -- handles any window size
- **Resize-aware** square grid presets

## Technique

1px frames placed over the text widget via `place`.
Horizontal spacing from `font metrics -linespace`,
factor 1.5 positions lines between text rows.
Uses namespace ensemble for clean API.

## Links
- [A vertical line in a text widget](https://wiki.tcl-lang.org/page/A+vertical+line+in+a+text+widget)
- [place](https://www.tcl-lang.org/man/tcl/TkCmd/place.html)
- [text](https://www.tcl-lang.org/man/tcl/TkCmd/text.html)


## Usage Examples

```tcl
# Presets
ruledtext preset .ed college       ;# blue lines, red margin
ruledtext preset .ed music         ;# staff notation (5-on-3-off)
ruledtext preset .ed ledger        ;# accounting columns with tabs

# Margins
ruledtext toggleMargin .ed 1       ;# left margin on
ruledtext toggleRMargin .ed 1      ;# right margin on
ruledtext setRMarginX .ed 40       ;# 40px from right edge

# Line patterns
ruledtext setLinePattern .ed {"#d0d8e8" "#b0c0d8"}   ;# alternating
ruledtext setLineRange .ed 55 0                        ;# from margin to right

# Readonly with selection
ruledtext setReadonly .ed select
ruledtext insertText .ed end "Programmatic text\n"

# PDF export
package require ruledtext::pdf 1.1
ruledtext exportPDF .ed "output.pdf" -paper a4 -title "Document"
```

## API Overview

27 public procs via `ruledtext` ensemble:

| Group | Procs |
|-------|-------|
| Widget | `create`, `textwidget` |
| Font | `setFont` |
| H-Lines | `setLineColor`, `setLineRange`, `setLinePattern`, `setGridSize` |
| L-Margin | `toggleMargin`, `setMarginX`, `setMarginColor` |
| R-Margin | `toggleRMargin`, `setRMarginX`, `setRMarginColor` |
| V-Lines | `addVLine`, `clearVLines`, `setVLineColor`, `setVLineRange` |
| Content | `clear`, `insertText`, `setReadonly` |
| Tabs | `syncTabs`, `setTabSync` |
| Presets | `presetNames`, `preset` |
| Export | `exportPDF` |

See `doc/manual.md` for the full API reference with syntax,
parameters, examples, configuration defaults, and design decisions.

See `doc/technical.md` for architecture, coordinate systems,
pool management, and implementation details.


## Requirements

- **Tcl/Tk 8.6.9+** (for `-insertunfocussed`, `$txt sync`)
- **pdf4tcl 0.9+** (optional, for PDF export via `ruledtext::pdf`)

