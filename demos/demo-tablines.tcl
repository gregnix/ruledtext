#!/usr/bin/env wish
# demo-tablines.tcl -- Tab stops aligned with vertical lines
#
# Tab text starts 1px right of each vertical line.
# Type with Tab key to jump between columns.

tcl::tm::path add [file join [file dirname [info script]] .. lib]
#package require ruledtext 1.1
puts "ruledtext: [package require ruledtext]"

wm title . "Tab + Vertical Lines"
wm geometry . 750x500

# -- Widget --
ruledtext create .ed
pack .ed -fill both -expand 1 -padx 6 -pady 6

set txt [ruledtext textwidget .ed]
$txt configure -font {Courier 11}

# -- Vertical lines at fixed positions --
ruledtext toggleMargin .ed 0

# Column layout: |Name|City|Phone|Note
set cols {150 320 460}
foreach x $cols {
    ruledtext addVLine .ed $x "#c0c0c0"
}

# -- Tab sync: text 1px right of vline --
#    -tabs measures from text left (after padx+bw)
#    place -x measures from widget edge (before bw)
set bw [$txt cget -borderwidth]
set tabs {}
foreach x $cols {
    set tabpos [expr {$x - $bw + 1}]
    lappend tabs $tabpos left
}
$txt configure -tabs $tabs -tabstyle wordprocessor

# -- Header --
$txt insert end "Name\tCity\tPhone\tNote\n" header
$txt tag configure header -font {Courier 11 bold} \
    -underline 1

# -- Sample data --
$txt insert end "Alice Miller\tBerlin\t030-12345\tVIP customer\n"
$txt insert end "Manfred Muster\tMunich\t089-55555\tNew contact\n"
$txt insert end "Carol Weber\tHamburg\t040-11111\tCall back Friday\n"
$txt insert end "David Koch\tCologne\t0221-2222\t\n"
$txt insert end "Mechtild Muster\tStuttgart\t0711-3333\tPrefers email\n"

$txt insert end "\n--- Type below with Tab key ---\n\n"
for {set i 1} {$i <= 20} {incr i} {
    $txt insert end "\t\t\t\n"
}

focus $txt
