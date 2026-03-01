#!/usr/bin/env wish
#
# Tests for ruledtext::pdf 1.1
#
# Requires: Tcl/Tk 8.6+, tcltest 2.5, pdf4tcl 0.9+
#
# Run: wish test/test_pdf.tcl
#

package require Tcl 8.6
package require Tk
package require tcltest 2.5
namespace import ::tcltest::*

# Load modules
set scriptDir [file dirname [file normalize [info script]]]
set libDir [file join $scriptDir .. lib]
tcl::tm::path add $libDir

if {[catch {package require ruledtext 1.1}]} {
    puts "ERROR: Cannot load ruledtext 1.1"
    exit 1
}

if {[catch {package require ruledtext::pdf 1.1}]} {
    puts "SKIP: ruledtext::pdf not available (pdf4tcl missing?)"
    exit 0
}

# Test helper
proc withWidget {path body} {
    # Ensure widget doesn't exist before creating
    catch {destroy $path}
    update idletasks
    
    uplevel 1 [list ruledtext create $path]
    try {
        uplevel 1 $body
    } finally {
        catch {destroy $path}
        update idletasks
        # Extra cleanup: ensure all child widgets are gone
        catch {destroy $path.txt}
        catch {destroy $path.sb}
        update idletasks
    }
}

# ==================================================================
# PDF Export
# ==================================================================

test pdf-1.1 {exportPDF creates file} -body {
    set testFile [file join [::tcltest::temporaryDirectory] "test_ruledtext.pdf"]
    if {[file exists $testFile]} { file delete $testFile }
    
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        $txt insert end "Test PDF Export\n"
        $txt insert end "Line 2\n"
        
        set pages [ruledtext exportPDF .test1 $testFile]
        expr {$pages > 0 && [file exists $testFile]}
    }
} -result 1

test pdf-1.2 {exportPDF with title} -body {
    set testFile [file join [::tcltest::temporaryDirectory] "test_ruledtext_title.pdf"]
    if {[file exists $testFile]} { file delete $testFile }
    
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        $txt insert end "Content\n"
        
        set pages [ruledtext exportPDF .test1 $testFile -title "Test Title"]
        expr {$pages > 0 && [file exists $testFile]}
    }
} -result 1

test pdf-1.3 {exportPDF with custom paper size} -body {
    set testFile [file join [::tcltest::temporaryDirectory] "test_ruledtext_letter.pdf"]
    if {[file exists $testFile]} { file delete $testFile }
    
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        $txt insert end "Test\n"
        
        set pages 0
        if {![catch {
            set pages [ruledtext exportPDF .test1 $testFile -paper letter]
        }]} {
            expr {$pages > 0}
        } else {
            expr 0
        }
    }
} -result 1

test pdf-1.4 {exportPDF with vertical lines} -body {
    set testFile [file join [::tcltest::temporaryDirectory] "test_ruledtext_vlines.pdf"]
    if {[file exists $testFile]} { file delete $testFile }
    
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        $txt insert end "Column1\tColumn2\n"
        ruledtext addVLine .test1 200
        ruledtext addVLine .test1 400
        
        set pages [ruledtext exportPDF .test1 $testFile]
        expr {$pages > 0 && [file exists $testFile]}
    }
} -result 1

test pdf-1.5 {exportPDF with preset} -body {
    set testFile [file join [::tcltest::temporaryDirectory] "test_ruledtext_preset.pdf"]
    if {[file exists $testFile]} { file delete $testFile }
    
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        $txt insert end "Test with college preset\n"
        ruledtext preset .test1 college
        
        set pages [ruledtext exportPDF .test1 $testFile]
        expr {$pages > 0 && [file exists $testFile]}
    }
} -result 1

test pdf-1.6 {exportPDF pagination with many lines} -body {
    set testFile [file join [::tcltest::temporaryDirectory] "test_ruledtext_pages.pdf"]
    if {[file exists $testFile]} { file delete $testFile }
    
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        for {set i 1} {$i <= 100} {incr i} {
            $txt insert end "Line $i\n"
        }
        
        set pages [ruledtext exportPDF .test1 $testFile]
        expr {$pages >= 2}
    }
} -result 1

test pdf-1.7 {exportPDF unknown option throws error} -body {
    set testFile [file join [::tcltest::temporaryDirectory] "test_ruledtext_error.pdf"]
    
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        $txt insert end "Test\n"
        
        catch {
            ruledtext exportPDF .test1 $testFile -bogus value
        } msg
        string match "*unknown option*" $msg
    }
} -result 1

# ==================================================================
# Helper functions
# ==================================================================

test pdf-2.1 {_hexToRGB converts hex to RGB} -body {
    set rgb [ruledtext::pdf::_hexToRGB "#ff0000"]
    set r [lindex $rgb 0]
    set g [lindex $rgb 1]
    set b [lindex $rgb 2]
    # #ff0000 = red = (1.0, 0.0, 0.0)
    expr {$r >= 0.99 && $g < 0.01 && $b < 0.01}
} -result 1

test pdf-2.2 {_hexToRGB handles 3-digit hex} -body {
    set rgb [ruledtext::pdf::_hexToRGB "#f00"]
    expr {[llength $rgb] == 3}
} -result 1

test pdf-2.3 {_mapFont maps Courier} -body {
    set fonts [ruledtext::pdf::_mapFont "Courier"]
    expr {[lindex $fonts 0] eq "Courier"}
} -result 1

test pdf-2.4 {_mapFont maps Times} -body {
    set fonts [ruledtext::pdf::_mapFont "Times"]
    expr {[lindex $fonts 0] eq "Times-Roman"}
} -result 1

test pdf-2.5 {_sanitize removes Unicode} -body {
    set text "Test\u2022Bullet"
    set cleaned [ruledtext::pdf::_sanitize $text]
    expr {[string first "*" $cleaned] >= 0}
} -result 1

test pdf-2.6 {exportPDF handles negative font size (pixels)} -body {
    set testFile [file join [::tcltest::temporaryDirectory] "test_ruledtext_negfont.pdf"]
    if {[file exists $testFile]} { file delete $testFile }
    
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        # Use negative font size (pixels)
        ruledtext setFont .test1 {Courier -14}
        $txt insert end "Test with pixel font size\n"
        
        # Should not throw error and should create PDF
        set pages 0
        if {![catch {
            set pages [ruledtext exportPDF .test1 $testFile]
        }]} {
            expr {$pages > 0 && [file exists $testFile]}
        } else {
            expr 0
        }
    }
} -result 1

test pdf-2.7 {exportPDF converts pixel font size correctly} -body {
    set testFile [file join [::tcltest::temporaryDirectory] "test_ruledtext_pixelfont.pdf"]
    if {[file exists $testFile]} { file delete $testFile }
    
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        # Use negative font size (pixels) - should be converted to points
        ruledtext setFont .test1 {Courier -12}
        $txt insert end "Test\n"
        
        # Should work without error (conversion happens internally)
        set success 0
        if {![catch {
            set pages [ruledtext exportPDF .test1 $testFile]
            set success [expr {$pages > 0}]
        }]} {
            expr $success
        } else {
            expr 0
        }
    }
} -result 1

# ==================================================================
# Cleanup
# ==================================================================

cleanupTests
puts "\n=== PDF Tests completed ==="
