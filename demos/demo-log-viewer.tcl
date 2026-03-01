#!/usr/bin/env wish
# demo-log-viewer.tcl -- Log viewer with readonly select mode
#
# Demonstrates readonly select mode for a log viewer use case.
# Users can select and copy log entries, but cannot edit.

tcl::tm::path add [file join [file dirname [info script]] .. lib]
package require ruledtext 1.1

wm title . "Log Viewer Demo"
wm geometry . 800x600

# -- Toolbar --
ttk::frame .tb
pack .tb -fill x -padx 6 -pady {6 2}

ttk::label .tb.l -text "Log Level:" -font {TkDefaultFont 9 bold}

ttk::button .tb.info -text "INFO" -command {
    addLogEntry "INFO" "Information message"
}
ttk::button .tb.warn -text "WARN" -command {
    addLogEntry "WARN" "Warning message"
}
ttk::button .tb.error -text "ERROR" -command {
    addLogEntry "ERROR" "Error message"
}

ttk::separator .tb.sep -orient vertical

ttk::button .tb.clear -text "Clear Log" -command {
    ruledtext clear .ed
    set txt [ruledtext textwidget .ed]
    $txt insert end "Log Viewer\n"
    $txt insert end "==========\n\n"
    $txt insert end "This is a log viewer using readonly select mode.\n"
    $txt insert end "You can select and copy text, but cannot edit.\n\n"
    $txt insert end "Click buttons to add log entries:\n\n"
}

ttk::button .tb.quit -text "Quit" -command exit

pack .tb.l .tb.info .tb.warn .tb.error -side left -padx 2
pack .tb.sep -side left -padx 8 -fill y -pady 2
pack .tb.clear -side left -padx 4
pack .tb.quit -side right

# -- Widget --
ruledtext create .ed
pack .ed -fill both -expand 1 -padx 6 -pady {2 6}

# Set readonly select mode (keyboard blocked, selection allowed)
ruledtext setReadonly .ed select

# -- Status --
ttk::label .st -text "Mode: Readonly Select (keyboard blocked, mouse selection allowed)" \
    -foreground #666666 -anchor w
pack .st -fill x -padx 8 -pady {0 6}

# -- Content --
set txt [ruledtext textwidget .ed]

$txt insert end "Log Viewer\n"
$txt insert end "==========\n\n"
$txt insert end "This is a log viewer using readonly select mode.\n"
$txt insert end "You can select and copy text, but cannot edit.\n\n"
$txt insert end "Click buttons to add log entries:\n\n"

# Configure tags for log levels
$txt tag configure info -foreground #0066cc
$txt tag configure warn -foreground #ff8800
$txt tag configure error -foreground #cc0000 -font {Courier 11 bold}

proc addLogEntry {level message} {
    set txt [ruledtext textwidget .ed]
    set time [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    set entry "$time \[$level\] $message\n"
    ruledtext insertText .ed end $entry $level
    # Auto-scroll to bottom
    $txt see end
}

# Add some initial entries
addLogEntry "INFO" "Application started"
addLogEntry "INFO" "Configuration loaded"
addLogEntry "WARN" "Deprecated API used"
addLogEntry "INFO" "Database connection established"
addLogEntry "ERROR" "Failed to load plugin"
addLogEntry "INFO" "User logged in"

focus $txt
