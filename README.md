# ruledtext

**Ruled Text Widget for Tcl/Tk** — Create notebook paper-style text widgets with horizontal lines, vertical lines, margins, presets, and PDF export.

[![Tcl/Tk](https://img.shields.io/badge/Tcl%2FTk-8.6.9%2B-blue)](https://www.tcl.tk/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.1-orange)](CHANGES.md)

Single Tcl module (`ruledtext-1.1.tm`) for creating text widgets
with horizontal lines, vertical lines, left/right margin, paper
presets, tab sync, readonly mode, and named fonts.

## Quick Start

```tcl
tcl::tm::path add /path/to/ruledtext/lib
package require ruledtext 1.1

ruledtext create .ed
pack .ed -fill both -expand 1

set txt [ruledtext textwidget .ed]
$txt insert end "Hello World\n"
```

Or direct source (still works):

```tcl
source -encoding utf-8 ruledtext-1.1.tm
ruledtext create .ed
```

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
No TclOO, no dependencies beyond Tk.

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

## Files

```
ruledtext/
  lib/
    ruledtext-1.1.tm         Main module (945 lines)
    ruledtext/
      pdf-1.1.tm             PDF export module (399 lines)
  demos/
    demo-presets.tcl          All 11 presets with tab example
    demo-split.tcl            Two instances, readonly, insertunfocussed
    demo-tablines.tcl         Tab stops aligned with vertical lines
    demo-pdf-export.tcl       PDF export with all visual settings
    demo-readonly-select.tcl  Readonly select mode
    demo-vgrid-resize.tcl     VGrid resize behavior
    demo-font-metrics.tcl     Font metrics and line spacing
    demo-margin-toggle.tcl    Left/right margin, line range, pattern
    demo-log-viewer.tcl       Log viewer with readonly select mode
  test/
    test_ruledtext.tcl        Unit tests (43 tests)
    test_pdf.tcl              PDF export tests (14 tests)
    README.md                 Test documentation
  doc/
    manual.md                 API reference manual (25 procs)
    technical.md              Architecture and internals
  README.md                   This file
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

