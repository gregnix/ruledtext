#!/usr/bin/env wish
# demo-split.tcl -- Two ruled widgets side by side
#
# Shows that multiple ruledtext instances work independently
# (own pool, own config). Cursor visible in inactive panel
# thanks to -insertunfocussed hollow.

tcl::tm::path add [file join [file dirname [info script]] .. lib]
#package require ruledtext 1.1
puts "ruledtext: [package require ruledtext]"

wm title . "Split View: Two Ruled Widgets"
wm geometry . 900x550

# -- Toolbar --
ttk::frame .tb
pack .tb -fill x -padx 6 -pady {6 2}

ttk::label .tb.l -text "Left:" -font {TkDefaultFont 9 bold}
ttk::button .tb.lfont -text "Font large" \
    -command { ruledtext setFont .left "Courier 14" }
ttk::button .tb.lcol -text "Green lines" \
    -command { ruledtext setLineColor .left "#d0e8d0" }
ttk::button .tb.lro -text "Readonly" \
    -command { ruledtext setReadonly .left 1 }

ttk::separator .tb.sep -orient vertical

ttk::label .tb.r -text "Right:" -font {TkDefaultFont 9 bold}
ttk::button .tb.rfont -text "Font small" \
    -command { ruledtext setFont .right "Courier 10" }
ttk::button .tb.rcol -text "Orange lines" \
    -command { ruledtext setLineColor .right "#e8d8c0" }
ttk::button .tb.rro -text "Readonly" \
    -command { ruledtext setReadonly .right 1 }

ttk::button .tb.unlock -text "Unlock all" -command {
    ruledtext setReadonly .left 0
    ruledtext setReadonly .right 0
}
ttk::button .tb.quit -text "Quit" -command exit

pack .tb.l .tb.lfont .tb.lcol .tb.lro -side left -padx 3
pack .tb.sep -side left -padx 8 -fill y -pady 2
pack .tb.r .tb.rfont .tb.rcol .tb.rro -side left -padx 3
pack .tb.unlock -side left -padx 8
pack .tb.quit -side right

# -- PanedWindow --
ttk::panedwindow .pw -orient horizontal
pack .pw -fill both -expand 1 -padx 6 -pady {2 6}


set ruledtext::cfg(marginx) 40
# Left: default config
ruledtext create .left
.pw add .left -weight 1

# Right: no margin, different colors
# cfg is per-instance: set template before create, no reset needed
set ruledtext::cfg(showmargin) 0
set ruledtext::cfg(linecolor) "#d8d8d8"
set ruledtext::cfg(paperbg) "#fffff0"
ruledtext create .right
.pw add .right -weight 1

# -- Content --
set ltxt [ruledtext textwidget .left]
$ltxt insert end "Left Widget\n"
$ltxt insert end "===========\n\n"
$ltxt insert end "Red margin at 43px, blue lines.\n"
$ltxt insert end "Per-instance config: right panel has\n"
$ltxt insert end "different colors, no margin.\n\n"
$ltxt insert end "Click in right panel -- cursor stays\n"
$ltxt insert end "visible here as hollow rectangle\n"
$ltxt insert end "(-insertunfocussed hollow).\n\n"
$ltxt insert end "Toolbar buttons:\n"
$ltxt insert end "  Font large  - setFont Courier 14\n"
$ltxt insert end "  Green lines - setLineColor per instance\n"
$ltxt insert end "  Readonly    - disables keyboard input\n"
$ltxt insert end "  Unlock all  - re-enables both panels\n\n"
$ltxt insert end "Named font: changing font size updates\n"
$ltxt insert end "line grid automatically.\n\n"
for {set i 1} {$i <= 20} {incr i} {
    $ltxt insert end "Note $i ...\n"
}

set rtxt [ruledtext textwidget .right]
$rtxt insert end "Right Widget\n"
$rtxt insert end "============\n\n"
$rtxt insert end "No margin, grey lines (#d8d8d8),\n"
$rtxt insert end "light yellow background (#fffff0).\n\n"
$rtxt insert end "cfg was set BEFORE create:\n"
$rtxt insert end "  set ruledtext::cfg(showmargin) 0\n"
$rtxt insert end "  set ruledtext::cfg(linecolor) ...\n"
$rtxt insert end "  set ruledtext::cfg(paperbg) ...\n"
$rtxt insert end "  ruledtext create .right\n\n"
$rtxt insert end "No reset needed -- cfg is copied\n"
$rtxt insert end "per instance on create.\n\n"
$rtxt insert end "Try: Font small, then Orange lines.\n"
$rtxt insert end "Each button changes only this panel.\n\n"
$rtxt insert end "Drag the splitter between panels\n"
$rtxt insert end "to test resize behavior.\n\n"
for {set i 1} {$i <= 20} {incr i} {
    $rtxt insert end "Task $i ...\n"
}

focus $ltxt
