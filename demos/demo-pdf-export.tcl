#!/usr/bin/env wish
# demo-pdf-export.tcl -- Export ruledtext widget to PDF
#
# Requires: pdf4tcl 0.9+ (installed separately)
# Uses ruledtext::pdf module for export.
#
# Demonstrates that all visual features are reproduced in PDF:
# presets, line range, vline range, line pattern, margin.

tcl::tm::path add [file join [file dirname [info script]] .. lib]
package require ruledtext 1.1
package require ruledtext::pdf 1.1

wm title . "PDF Export Demo"
wm geometry . 820x620

# -- Toolbar row 1: Preset + Export --
ttk::frame .tb1
pack .tb1 -fill x -padx 6 -pady {6 0}

ttk::label .tb1.l -text "Preset:" -font {TkDefaultFont 9 bold}

ttk::combobox .tb1.sel -state readonly -width 12 \
    -values [ruledtext presetNames]
.tb1.sel set "college"

ttk::button .tb1.apply -text "Apply" -command {
    ruledtext preset .ed [.tb1.sel get]
    .st configure -text "Preset: [.tb1.sel get]"
}
bind .tb1.sel <<ComboboxSelected>> { .tb1.apply invoke }

ttk::separator .tb1.sep -orient vertical

ttk::button .tb1.pdf -text "Export PDF" -command exportPDF
ttk::button .tb1.quit -text "Quit" -command exit

pack .tb1.l .tb1.sel .tb1.apply -side left -padx {0 4}
pack .tb1.sep -side left -padx 8 -fill y -pady 2
pack .tb1.pdf -side left -padx 4
pack .tb1.quit -side right

# -- Toolbar row 2: Line range + VLine range --
ttk::frame .tb2
pack .tb2 -fill x -padx 6 -pady {2 0}

ttk::label .tb2.l -text "H-Range:" -font {TkDefaultFont 9 bold}
ttk::button .tb2.hfull -text "Full" -command {
    ruledtext setLineRange .ed 0 0
    .st configure -text "H-Lines: full width"
}
ttk::button .tb2.hmargin -text "From margin" -command {
    set mx $::ruledtext::state(.ed,cfg,marginx)
    ruledtext setLineRange .ed $mx 0
    .st configure -text "H-Lines: from margin ($mx px)"
}

ttk::separator .tb2.sep1 -orient vertical

ttk::label .tb2.l2 -text "V-Range:" -font {TkDefaultFont 9 bold}
ttk::button .tb2.vfull -text "Full" -command {
    ruledtext setVLineRange .ed 0 0
    .st configure -text "V-Lines: full height"
}
ttk::button .tb2.vinset -text "Inset 20" -command {
    ruledtext setVLineRange .ed 20 0
    .st configure -text "V-Lines: from 20px to bottom"
}

ttk::separator .tb2.sep2 -orient vertical

ttk::label .tb2.l3 -text "L-Margin:" -font {TkDefaultFont 9 bold}
ttk::button .tb2.mon -text "On" -command {
    ruledtext toggleMargin .ed 1
    .st configure -text "Left margin: ON"
}
ttk::button .tb2.moff -text "Off" -command {
    ruledtext toggleMargin .ed 0
    .st configure -text "Left margin: OFF"
}

ttk::separator .tb2.sep3 -orient vertical

ttk::label .tb2.l4 -text "R-Margin:" -font {TkDefaultFont 9 bold}
ttk::button .tb2.rmon -text "On" -command {
    ruledtext toggleRMargin .ed 1
    .st configure -text "Right margin: ON"
}
ttk::button .tb2.rmoff -text "Off" -command {
    ruledtext toggleRMargin .ed 0
    .st configure -text "Right margin: OFF"
}

pack .tb2.l .tb2.hfull .tb2.hmargin -side left -padx 2
pack .tb2.sep1 -side left -padx 6 -fill y -pady 2
pack .tb2.l2 .tb2.vfull .tb2.vinset -side left -padx 2
pack .tb2.sep2 -side left -padx 6 -fill y -pady 2
pack .tb2.l3 .tb2.mon .tb2.moff -side left -padx 2
pack .tb2.sep3 -side left -padx 6 -fill y -pady 2
pack .tb2.l4 .tb2.rmon .tb2.rmoff -side left -padx 2

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
ttk::button .tb3.rainbow -text "Rainbow" -command {
    ruledtext setLinePattern .ed \
        {"#e08080" "#e0b060" "#c0c060" "#60c060" "#6080e0" "#a060c0"}
    .st configure -text "Pattern: rainbow"
}

pack .tb3.l .tb3.uniform .tb3.alt .tb3.every5 .tb3.staff .tb3.rainbow \
    -side left -padx 2

# -- Widget --
ruledtext create .ed
pack .ed -fill both -expand 1 -padx 6 -pady {2 6}

# -- Status --
ttk::label .st -text "Ready" -foreground #666666 -anchor w
pack .st -fill x -padx 8 -pady {0 6}

# -- Content --
set txt [ruledtext textwidget .ed]

$txt insert end "PDF Export Demo\n"
$txt insert end "===============\n\n"
$txt insert end "All visual settings are reproduced in the PDF:\n"
$txt insert end "  - Presets (color, font, background, margins)\n"
$txt insert end "  - H-Line range (setLineRange)\n"
$txt insert end "  - V-Line range (setVLineRange)\n"
$txt insert end "  - Line pattern (setLinePattern)\n"
$txt insert end "  - Left margin position and color\n"
$txt insert end "  - Right margin position and color\n\n"
$txt insert end "Steps to test:\n"
$txt insert end "  1. Choose a preset\n"
$txt insert end "  2. Adjust line range / pattern / margin\n"
$txt insert end "  3. Click 'Export PDF'\n"
$txt insert end "  4. Compare PDF with widget on screen\n\n"

$txt insert end "Tab example (apply 'ledger' first):\n"
$txt insert end "Date\tDescription\tDebit\tCredit\n"
$txt insert end "01.03.\tOffice supplies\t\t45.00\t\n"
$txt insert end "02.03.\tClient payment\t\t1200.00\n"
$txt insert end "03.03.\tSoftware license\t\t299.00\t\n\n"

$txt insert end "Presets: [join [ruledtext presetNames] {, }]\n\n"

for {set i 1} {$i <= 40} {incr i} {
    $txt insert end "Line $i for pagination test...\n"
}

$txt insert end "\nEnd of content.\n"

# -- Export command --
proc exportPDF {} {
    set preset [.tb1.sel get]
    set filename "ruledtext-${preset}.pdf"

    set dir [file dirname [info script]]
    set outpath [file join $dir $filename]

    .st configure -text "Exporting to $filename ..."
    update

    if {[catch {
        set pages [ruledtext exportPDF .ed $outpath \
            -title "ruledtext -- $preset"]
        .st configure -text \
            "Exported: $filename ($pages page[expr {$pages > 1 ? {s} : {}}])"
    } err]} {
        .st configure -text "Error: $err"
        tk_messageBox -icon error -title "PDF Export" \
            -message "Export failed:\n$err"
    }
}

# Apply initial preset
ruledtext preset .ed college

focus $txt
