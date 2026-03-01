#!/usr/bin/env wish
# demo-readonly-select.tcl -- Readonly select mode demo
#
# Shows the difference between disabled mode (no selection)
# and select mode (keyboard blocked, but mouse selection allowed).

tcl::tm::path add [file join [file dirname [info script]] .. lib]
package require ruledtext 1.1

wm title . "Readonly Select Mode Demo"
wm geometry . 900x600

# -- Toolbar --
ttk::frame .tb
pack .tb -fill x -padx 6 -pady {6 2}

ttk::label .tb.l -text "Mode:" -font {TkDefaultFont 9 bold}

ttk::button .tb.normal -text "Normal" -command {
    ruledtext setReadonly .ed 0
    .st configure -text "Mode: Normal (full editing enabled)"
}
ttk::button .tb.select -text "Select" -command {
    ruledtext setReadonly .ed select
    .st configure -text "Mode: Select (keyboard blocked, mouse selection allowed)"
}
ttk::button .tb.disabled -text "Disabled" -command {
    ruledtext setReadonly .ed 1
    .st configure -text "Mode: Disabled (no editing, no selection)"
}

ttk::separator .tb.sep -orient vertical

ttk::button .tb.insert -text "Insert Text" -command {
    set txt [ruledtext textwidget .ed]
    set time [clock format [clock seconds] -format "%H:%M:%S"]
    ruledtext insertText .ed end "\[$time\] Log entry added programmatically\n"
}

ttk::button .tb.quit -text "Quit" -command exit

pack .tb.l .tb.normal .tb.select .tb.disabled -side left -padx 3
pack .tb.sep -side left -padx 8 -fill y -pady 2
pack .tb.insert -side left -padx 4
pack .tb.quit -side right

# -- Widget --
ruledtext create .ed
pack .ed -fill both -expand 1 -padx 6 -pady {2 6}

# -- Status --
ttk::label .st -text "Mode: Normal (full editing enabled)" \
    -foreground #666666 -anchor w
pack .st -fill x -padx 8 -pady {0 6}

# -- Content --
set txt [ruledtext textwidget .ed]

$txt insert end "Readonly Select Mode Demo\n"
$txt insert end "========================\n\n"
$txt insert end "This demo shows the three readonly modes:\n\n"
$txt insert end "1. Normal (default):\n"
$txt insert end "   - Full keyboard editing\n"
$txt insert end "   - Mouse selection\n"
$txt insert end "   - Cursor visible\n\n"
$txt insert end "2. Select mode:\n"
$txt insert end "   - Keyboard editing BLOCKED\n"
$txt insert end "   - Mouse selection ALLOWED\n"
$txt insert end "   - Cursor visible\n"
$txt insert end "   - Useful for viewers, help windows, log displays\n\n"
$txt insert end "3. Disabled mode:\n"
$txt insert end "   - Keyboard editing BLOCKED\n"
$txt insert end "   - Mouse selection BLOCKED\n"
$txt insert end "   - Cursor not visible\n"
$txt insert end "   - Traditional readonly\n\n"
$txt insert end "Try the buttons:\n"
$txt insert end "  - Click 'Select' and try to type (blocked)\n"
$txt insert end "  - But you can still select text with mouse!\n"
$txt insert end "  - Click 'Insert Text' to add entries programmatically\n"
$txt insert end "  - Click 'Disabled' to see traditional readonly\n\n"
$txt insert end "Sample log entries:\n"
$txt insert end "-------------------\n"

for {set i 1} {$i <= 10} {incr i} {
    set time [clock format [expr {[clock seconds] - $i * 60}] \
        -format "%H:%M:%S"]
    ruledtext insertText .ed end "\[$time\] Log entry $i\n"
}

focus $txt
