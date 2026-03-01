#!/usr/bin/env wish
# demo-margin-toggle.tcl -- Margin, line range, and line pattern demo
#
# Shows left/right margin controls, horizontal/vertical line range,
# and cyclic color patterns for horizontal lines.

tcl::tm::path add [file join [file dirname [info script]] .. lib]
package require ruledtext 1.1

wm title . "Margin & Lines Demo"
wm geometry . 850x620

# -- Toolbar row 1: Left Margin --
ttk::frame .tb1
pack .tb1 -fill x -padx 6 -pady {6 0}

ttk::label .tb1.l -text "L-Margin:" -font {TkDefaultFont 9 bold}
ttk::button .tb1.on -text "Show" -command {
    ruledtext toggleMargin .ed 1
    .st configure -text "Left margin: ON"
}
ttk::button .tb1.off -text "Hide" -command {
    ruledtext toggleMargin .ed 0
    .st configure -text "Left margin: OFF"
}
ttk::button .tb1.p40 -text "40" -width 3 -command {
    ruledtext setMarginX .ed 40
    .st configure -text "Left margin at 40px"
}
ttk::button .tb1.p55 -text "55" -width 3 -command {
    ruledtext setMarginX .ed 55
    .st configure -text "Left margin at 55px (default)"
}
ttk::button .tb1.red -text "Red" -command {
    ruledtext setMarginColor .ed "#e88080"
}
ttk::button .tb1.blue -text "Blue" -command {
    ruledtext setMarginColor .ed "#8080e8"
}

ttk::separator .tb1.sep -orient vertical

ttk::label .tb1.r -text "R-Margin:" -font {TkDefaultFont 9 bold}
ttk::button .tb1.ron -text "Show" -command {
    ruledtext toggleRMargin .ed 1
    .st configure -text "Right margin: ON"
}
ttk::button .tb1.roff -text "Hide" -command {
    ruledtext toggleRMargin .ed 0
    .st configure -text "Right margin: OFF"
}
ttk::button .tb1.r20 -text "20" -width 3 -command {
    ruledtext setRMarginX .ed 20
    .st configure -text "Right margin at 20px from right"
}
ttk::button .tb1.r40 -text "40" -width 3 -command {
    ruledtext setRMarginX .ed 40
    .st configure -text "Right margin at 40px from right"
}
ttk::button .tb1.rred -text "Red" -command {
    ruledtext setRMarginColor .ed "#e88080"
}
ttk::button .tb1.rblue -text "Blue" -command {
    ruledtext setRMarginColor .ed "#8080e8"
}

pack .tb1.l .tb1.on .tb1.off .tb1.p40 .tb1.p55 .tb1.red .tb1.blue \
    -side left -padx 1
pack .tb1.sep -side left -padx 6 -fill y -pady 2
pack .tb1.r .tb1.ron .tb1.roff .tb1.r20 .tb1.r40 .tb1.rred .tb1.rblue \
    -side left -padx 1

# -- Toolbar row 2: Line range --
ttk::frame .tb2
pack .tb2 -fill x -padx 6 -pady {2 0}

ttk::label .tb2.l -text "H-Range:" -font {TkDefaultFont 9 bold}
ttk::button .tb2.full -text "Full" -command {
    ruledtext setLineRange .ed 0 0
    .st configure -text "H-Lines: full width"
}
ttk::button .tb2.fromm -text "From margin" -command {
    set mx $::ruledtext::state(.ed,cfg,marginx)
    ruledtext setLineRange .ed $mx 0
    .st configure -text "H-Lines: from margin to right"
}

ttk::separator .tb2.sep -orient vertical

ttk::label .tb2.l2 -text "V-Range:" -font {TkDefaultFont 9 bold}
ttk::button .tb2.vfull -text "Full" -command {
    ruledtext setVLineRange .ed 0 0
    .st configure -text "V-Lines: full height"
}
ttk::button .tb2.vinset -text "Inset 20" -command {
    ruledtext setVLineRange .ed 20 0
    .st configure -text "V-Lines: from 20px to bottom"
}

pack .tb2.l .tb2.full .tb2.fromm -side left -padx 2
pack .tb2.sep -side left -padx 6 -fill y -pady 2
pack .tb2.l2 .tb2.vfull .tb2.vinset -side left -padx 2

# -- Toolbar row 3: Line pattern --
ttk::frame .tb3
pack .tb3 -fill x -padx 6 -pady {2 2}

ttk::label .tb3.l -text "Pattern:" -font {TkDefaultFont 9 bold}
ttk::button .tb3.uniform -text "Uniform" -command {
    ruledtext setLinePattern .ed {}
    .st configure -text "Pattern: uniform"
}
ttk::button .tb3.alt -text "Alternating" -command {
    ruledtext setLinePattern .ed {"#d0d8e8" "#b0c0d8"}
    .st configure -text "Pattern: alternating"
}
ttk::button .tb3.every5 -text "Every 5th" -command {
    ruledtext setLinePattern .ed \
        {"#e0e0e0" "#e0e0e0" "#e0e0e0" "#e0e0e0" "#a0a0d0"}
    .st configure -text "Pattern: every 5th darker"
}
ttk::button .tb3.staff -text "Staff" -command {
    ruledtext setLinePattern .ed \
        {"#b0b0b0" "#b0b0b0" "#b0b0b0" "#b0b0b0" "#b0b0b0" "" "" ""}
    .st configure -text "Pattern: music staff (5 on, 3 off)"
}

ttk::separator .tb3.sep -orient vertical
ttk::button .tb3.quit -text "Quit" -command exit

pack .tb3.l .tb3.uniform .tb3.alt .tb3.every5 .tb3.staff -side left -padx 2
pack .tb3.sep -side left -padx 6 -fill y -pady 2
pack .tb3.quit -side right

# -- Widget --
ruledtext create .ed
pack .ed -fill both -expand 1 -padx 6 -pady {2 6}

# -- Status --
ttk::label .st -text "L-Margin: ON (55px) | R-Margin: OFF" \
    -foreground #666666 -anchor w
pack .st -fill x -padx 8 -pady {0 6}

# -- Content --
set txt [ruledtext textwidget .ed]

$txt insert end "Margin & Lines Demo\n"
$txt insert end "===================\n\n"
$txt insert end "Row 1: Left margin + Right margin\n"
$txt insert end "  Show/Hide, Position, Color for each side\n\n"
$txt insert end "Row 2: H-Line range (left-right), V-Line range (top-bottom)\n"
$txt insert end "Row 3: H-Line pattern (cyclic color per line)\n\n"
$txt insert end "API:\n"
$txt insert end "  ruledtext toggleMargin .ed 1           ;# left margin on\n"
$txt insert end "  ruledtext toggleRMargin .ed 1          ;# right margin on\n"
$txt insert end "  ruledtext setRMarginX .ed 30           ;# 30px from right\n"
$txt insert end "  ruledtext setRMarginColor .ed \"#e8a0a0\" ;# color\n\n"

for {set i 1} {$i <= 30} {incr i} {
    $txt insert end "Line $i: Sample text for demonstration.\n"
}

focus $txt
