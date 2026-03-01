#!/usr/bin/env wish
# demo-vgrid-resize.tcl -- VGrid resize behavior demo
#
# Shows how squared/graph presets automatically extend/shrink
# the vertical grid when the widget is resized.

tcl::tm::path add [file join [file dirname [info script]] .. lib]
package require ruledtext 1.1

wm title . "VGrid Resize Demo"
wm geometry . 600x500

# -- Toolbar --
ttk::frame .tb
pack .tb -fill x -padx 6 -pady {6 2}

ttk::label .tb.l -text "Preset:" -font {TkDefaultFont 9 bold}

ttk::combobox .tb.sel -state readonly -width 12 \
    -values {squared graph}
.tb.sel set "squared"

ttk::button .tb.apply -text "Apply" -command {
    ruledtext preset .ed [.tb.sel get]
    .st configure -text "Preset: [.tb.sel get] - Resize window to see grid extend/shrink"
}
bind .tb.sel <<ComboboxSelected>> { .tb.apply invoke }

ttk::separator .tb.sep -orient vertical

ttk::button .tb.wide -text "Wide" -command {
    wm geometry . 800x500
    update idletasks
}
ttk::button .tb.narrow -text "Narrow" -command {
    wm geometry . 400x500
    update idletasks
}

ttk::button .tb.quit -text "Quit" -command exit

pack .tb.l .tb.sel .tb.apply -side left -padx {0 4}
pack .tb.sep -side left -padx 8 -fill y -pady 2
pack .tb.wide .tb.narrow -side left -padx 2
pack .tb.quit -side right

# -- Widget --
ruledtext create .ed
pack .ed -fill both -expand 1 -padx 6 -pady {2 6}

# -- Status --
ttk::label .st -text "Preset: squared - Resize window to see grid extend/shrink" \
    -foreground #666666 -anchor w
pack .st -fill x -padx 8 -pady {0 6}

# -- Content --
set txt [ruledtext textwidget .ed]

$txt insert end "VGrid Resize Demo\n"
$txt insert end "==================\n\n"
$txt insert end "This demo shows how vgrid presets (squared, graph)\n"
$txt insert end "automatically adapt to widget width:\n\n"
$txt insert end "1. Apply 'squared' or 'graph' preset\n"
$txt insert end "2. Resize the window wider → grid extends\n"
$txt insert end "3. Resize the window narrower → excess lines removed\n\n"
$txt insert end "Try:\n"
$txt insert end "  - Click 'Wide' button (800px)\n"
$txt insert end "  - Click 'Narrow' button (400px)\n"
$txt insert end "  - Or manually resize the window\n\n"
$txt insert end "The vertical grid lines adjust automatically.\n"
$txt insert end "No need to reapply the preset!\n\n"
$txt insert end "Technical details:\n"
$txt insert end "  - Grid spacing = font linespace\n"
$txt insert end "  - Lines created on grow\n"
$txt insert end "  - Lines removed on shrink\n"
$txt insert end "  - Handled by _reapplyVGrid in _draw\n\n"

for {set i 1} {$i <= 15} {incr i} {
    $txt insert end "Line $i: Watch the vertical grid as you resize...\n"
}

# Apply initial preset
ruledtext preset .ed squared

focus $txt
