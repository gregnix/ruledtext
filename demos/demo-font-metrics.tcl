#!/usr/bin/env wish
# demo-font-metrics.tcl -- Font metrics and line spacing demo
#
# Shows how font changes affect line spacing and grid alignment.

tcl::tm::path add [file join [file dirname [info script]] .. lib]
package require ruledtext 1.1

wm title . "Font Metrics Demo"
wm geometry . 750x550

# -- Toolbar --
ttk::frame .tb
pack .tb -fill x -padx 6 -pady {6 2}

ttk::label .tb.l -text "Font:" -font {TkDefaultFont 9 bold}

ttk::button .tb.small -text "Small (10)" -command {
    ruledtext setFont .ed {Courier 10}
    updateMetrics
}
ttk::button .tb.medium -text "Medium (12)" -command {
    ruledtext setFont .ed {Courier 12}
    updateMetrics
}
ttk::button .tb.large -text "Large (16)" -command {
    ruledtext setFont .ed {Courier 16}
    updateMetrics
}
ttk::button .tb.huge -text "Huge (20)" -command {
    ruledtext setFont .ed {Courier 20}
    updateMetrics
}

ttk::separator .tb.sep -orient vertical

ttk::button .tb.helvetica -text "Helvetica" -command {
    ruledtext setFont .ed {Helvetica 12}
    updateMetrics
}
ttk::button .tb.times -text "Times" -command {
    ruledtext setFont .ed {Times 12}
    updateMetrics
}

ttk::button .tb.quit -text "Quit" -command exit

pack .tb.l .tb.small .tb.medium .tb.large .tb.huge -side left -padx 2
pack .tb.sep -side left -padx 8 -fill y -pady 2
pack .tb.helvetica .tb.times -side left -padx 2
pack .tb.quit -side right

# -- Widget --
ruledtext create .ed
pack .ed -fill both -expand 1 -padx 6 -pady {2 6}

# -- Status --
ttk::label .st -text "Font: Courier 12" -foreground #666666 -anchor w
pack .st -fill x -padx 8 -pady {0 6}

# -- Content --
set txt [ruledtext textwidget .ed]

proc updateMetrics {} {
    set txt [ruledtext textwidget .ed]
    set font [$txt cget -font]
    set actual [font actual $font]
    set family [dict get $actual -family]
    set size [dict get $actual -size]
    set linespace [font metrics $font -linespace]
    set ascent [font metrics $font -ascent]
    set descent [font metrics $font -descent]
    
    .st configure -text "Font: $family $size | Linespace: ${linespace}px | Ascent: ${ascent}px | Descent: ${descent}px"
}

$txt insert end "Font Metrics Demo\n"
$txt insert end "==================\n\n"
$txt insert end "This demo shows how font changes affect line spacing:\n\n"
$txt insert end "Line spacing is calculated from font metrics:\n"
$txt insert end "  linespace = ascent + descent + leading\n\n"
$txt insert end "Horizontal lines are positioned at:\n"
$txt insert end "  y = first_line_y + 1.5 * linespace\n"
$txt insert end "  (factor 1.5 places lines between text rows)\n\n"
$txt insert end "Try different font sizes:\n"
$txt insert end "  - Small (10pt) → tight grid\n"
$txt insert end "  - Medium (12pt) → default\n"
$txt insert end "  - Large (16pt) → wide grid\n"
$txt insert end "  - Huge (20pt) → very wide grid\n\n"
$txt insert end "Or try different font families:\n"
$txt insert end "  - Courier (monospace)\n"
$txt insert end "  - Helvetica (sans-serif)\n"
$txt insert end "  - Times (serif)\n\n"
$txt insert end "Watch the status bar for metrics!\n\n"
$txt insert end "Sample text with uniform font:\n"
$txt insert end "--------------------------------\n"

for {set i 1} {$i <= 20} {incr i} {
    $txt insert end "Line $i: The quick brown fox jumps over the lazy dog.\n"
}

updateMetrics
focus $txt
