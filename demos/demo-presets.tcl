#!/usr/bin/env wish
# demo-presets.tcl -- Paper presets and vertical lines
#
# All presets are built into ruledtext-x.x.tm.


tcl::tm::path add [file join [file dirname [info script]] .. lib]
#package require ruledtext 1.1
puts "ruledtext: [package require ruledtext]"

wm title . "Paper Presets"
wm geometry . 750x550

# -- Toolbar --
ttk::frame .tb
pack .tb -fill x -padx 6 -pady {6 2}

ttk::label .tb.l -text "Preset:" -font {TkDefaultFont 10 bold}

ttk::combobox .tb.sel -state readonly -width 14 \
    -values [ruledtext presetNames]
.tb.sel set "college"

ttk::button .tb.apply -text "Apply" -command {
    ruledtext preset .ed [.tb.sel get]
    .st configure -text "Preset: [.tb.sel get]"
}

# Quick-access buttons for most common presets
ttk::button .tb.college -text "College"  -command { .tb.sel set college;  .tb.apply invoke }
ttk::button .tb.squared -text "Squared"  -command { .tb.sel set squared;  .tb.apply invoke }
ttk::button .tb.ledger  -text "Ledger"   -command { .tb.sel set ledger;   .tb.apply invoke }
ttk::button .tb.dark    -text "Dark"     -command { .tb.sel set dark;     .tb.apply invoke }

ttk::button .tb.quit -text "Quit" -command exit

pack .tb.l .tb.sel .tb.apply -side left -padx {0 4}
pack .tb.college .tb.squared .tb.ledger .tb.dark \
    -side left -padx 2
pack .tb.quit -side right

# Also apply on combobox selection
bind .tb.sel <<ComboboxSelected>> { .tb.apply invoke }

# -- Widget --
ruledtext create .ed
pack .ed -fill both -expand 1 -padx 6 -pady {2 6}

# -- Status --
ttk::label .st -text "Preset: college" \
    -foreground #666666 -anchor w
pack .st -fill x -padx 8 -pady {0 6}

# -- Content --
set txt [ruledtext textwidget .ed]
$txt insert end "Paper Presets\n"
$txt insert end "=============\n\n"
$txt insert end "Available presets:\n\n"
foreach name [ruledtext presetNames] {
    switch $name {
        college  { set desc "Blue lines, red margin" }
        vintage  { set desc "Aged paper, brown tones" }
        minimal  { set desc "Light grey, no margin" }
        dark     { set desc "Dark background, muted lines" }
        green    { set desc "Eco paper, green lines" }
        squared  { set desc "Square grid (char width = line height)" }
        graph    { set desc "Fine square grid, smaller font" }
        columns  { set desc "3 columns, tab-synced" }
        ledger   { set desc "Date|Text|Debit|Credit, tab-synced" }
        music    { set desc "Staff-style horizontal lines" }
        todo     { set desc "Checkbox column, tab-synced" }
        default  { set desc "" }
    }
    $txt insert end [format "  %-10s  %s\n" $name $desc]
}
$txt insert end "\nSelect from dropdown or click buttons.\n"
$txt insert end "Presets with 'tabs' sync Tab key to vertical lines.\n\n"
$txt insert end "Try 'ledger' or 'columns', then type with Tab:\n"
$txt insert end "Date\tDescription\tDebit\tCredit\n"
$txt insert end "01.03.\tOffice supplies\t45.00\t\n"
$txt insert end "02.03.\tClient payment\t\t1200.00\n"
$txt insert end "03.03.\tSoftware license\t299.00\t\n\n"
for {set i 1} {$i <= 20} {incr i} {
    $txt insert end "Line $i for scrolling...\n"
}

focus $txt
