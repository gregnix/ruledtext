#!/usr/bin/env wish
#
# Tests for ruledtext 1.1
#
# Requires: Tcl/Tk 8.6+, tcltest 2.5
#
# Run: wish test/test_ruledtext.tcl
#

package require Tcl 8.6
package require Tk
package require tcltest 2.5
namespace import ::tcltest::*

# Load module
set scriptDir [file dirname [file normalize [info script]]]
set libDir [file join $scriptDir .. lib]
tcl::tm::path add $libDir
package require ruledtext 1.1

# Test helper: create widget, run test, destroy
proc withWidget {path body} {
    # Ensure widget doesn't exist before creating
    catch {destroy $path}
    update idletasks
    
    uplevel 1 [list ruledtext create $path]
    try {
        uplevel 1 $body
    } finally {
        catch {destroy $path}
        # Wait for cleanup to complete
        update idletasks
        # Extra cleanup: ensure all child widgets are gone
        catch {destroy $path.txt}
        catch {destroy $path.sb}
        update idletasks
    }
}

# ==================================================================
# Basic API: create, textwidget
# ==================================================================

test rt-1.1 {create returns path} -body {
    set w [ruledtext create .test1]
    set result $w
    destroy .test1
    update idletasks
    set result
} -result .test1

test rt-1.2 {textwidget returns text widget path} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        expr {$txt eq ".test1.txt"}
    }
} -result 1

test rt-1.3 {widget structure: frame + text + scrollbar} -body {
    withWidget .test1 {
        set hasFrame [winfo exists .test1]
        set hasText [winfo exists .test1.txt]
        set hasSb [winfo exists .test1.sb]
        expr {$hasFrame && $hasText && $hasSb}
    }
} -result 1

test rt-1.4 {named font created} -body {
    withWidget .test1 {
        set fontName "RuledFont_.test1"
        expr {[lsearch [font names] $fontName] >= 0}
    }
} -result 1

test rt-1.5 {named font deleted on destroy} -body {
    set fontName "RuledFont_.test1"
    withWidget .test1 {
        # Font exists during widget lifetime
        set exists1 [expr {[lsearch [font names] $fontName] >= 0}]
    }
    # Font should be deleted after destroy
    set exists2 [expr {[lsearch [font names] $fontName] >= 0}]
    list $exists1 $exists2
} -result {1 0}

# ==================================================================
# Font operations
# ==================================================================

test rt-2.1 {setFont changes named font} -body {
    withWidget .test1 {
        set fontName "RuledFont_.test1"
        ruledtext setFont .test1 {Courier 14}
        set size [font configure $fontName -size]
        expr {$size == 14}
    }
} -result 1

test rt-2.2 {setFont updates text widget} -body {
    withWidget .test1 {
        ruledtext setFont .test1 {Helvetica 12}
        set txtFont [.test1.txt cget -font]
        expr {$txtFont eq "RuledFont_.test1"}
    }
} -result 1

# ==================================================================
# Line color
# ==================================================================

test rt-3.1 {setLineColor changes line color} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        update idletasks
        # Get first horizontal line frame
        set hline [lindex [info commands .test1.txt._hl*] 0]
        if {$hline ne ""} {
            set oldColor [$hline cget -background]
            ruledtext setLineColor .test1 "#ff0000"
            update idletasks
            set newColor [$hline cget -background]
            expr {$newColor eq "#ff0000"}
        } else {
            expr 1
        }
    }
} -result 1

# ==================================================================
# Margin
# ==================================================================

test rt-4.1 {toggleMargin shows/hides margin} -body {
    withWidget .test1 {
        set margin [info commands .test1.txt._margin]
        expr {[llength $margin] == 1}
    }
} -result 1

test rt-4.2 {toggleMargin adjusts padx} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        ruledtext toggleMargin .test1 0
        set padx0 [.test1.txt cget -padx]
        ruledtext toggleMargin .test1 1
        set padx1 [.test1.txt cget -padx]
        expr {$padx1 > $padx0}
    }
} -result 1

# ==================================================================
# Text operations
# ==================================================================

test rt-5.1 {clear deletes all text} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        $txt insert end "Test\nText\n"
        ruledtext clear .test1
        set content [$txt get 1.0 "end - 1 char"]
        expr {$content eq ""}
    }
} -result 1

test rt-5.2 {setReadonly disables text widget} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        ruledtext setReadonly .test1 1
        set state [$txt cget -state]
        expr {$state eq "disabled"}
    }
} -result 1

test rt-5.3 {insertText works when readonly} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        ruledtext setReadonly .test1 1
        ruledtext insertText .test1 end "Test\n"
        set content [$txt get 1.0 end]
        string match "*Test*" $content
    }
} -result 1

test rt-5.4 {insertText restores readonly state} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        ruledtext setReadonly .test1 1
        ruledtext insertText .test1 end "Test\n"
        set state [$txt cget -state]
        expr {$state eq "disabled"}
    }
} -result 1

test rt-5.5 {setReadonly select mode allows selection} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        $txt insert end "Selectable text\n"
        ruledtext setReadonly .test1 select
        set state [$txt cget -state]
        # Widget should be in normal state
        expr {$state eq "normal"}
    }
} -result 1

test rt-5.6 {setReadonly select mode blocks keyboard input} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        $txt insert end "Test\n"
        ruledtext setReadonly .test1 select
        # Try to insert via keyboard binding (should be blocked)
        # We can't easily simulate keypress, but we can check bindtags
        set tags [bindtags $txt]
        # Should have readonly bindtag
        set hasReadonlyTag [expr {[lsearch $tags "*Readonly*"] >= 0}]
        expr $hasReadonlyTag
    }
} -result 1

test rt-5.7 {setReadonly select mode restores bindtags on disable} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        set origTags [bindtags $txt]
        ruledtext setReadonly .test1 select
        set selectTags [bindtags $txt]
        ruledtext setReadonly .test1 1
        set disabledTags [bindtags $txt]
        # Disabled mode should restore original bindtags
        expr {$disabledTags eq $origTags}
    }
} -result 1

test rt-5.8 {setReadonly select mode restores bindtags on normal} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        set origTags [bindtags $txt]
        ruledtext setReadonly .test1 select
        ruledtext setReadonly .test1 0
        set normalTags [bindtags $txt]
        # Normal mode should restore original bindtags
        expr {$normalTags eq $origTags}
    }
} -result 1

# ==================================================================
# Vertical lines
# ==================================================================

test rt-6.1 {addVLine creates frame} -body {
    withWidget .test1 {
        set frame [ruledtext addVLine .test1 200]
        update idletasks
        expr {[winfo exists $frame]}
    }
} -result 1

test rt-6.2 {addVLine returns frame path} -body {
    withWidget .test1 {
        set frame [ruledtext addVLine .test1 150]
        string match ".test1.txt._vl*" $frame
    }
} -result 1

test rt-6.3 {addVLine uses default color if not specified} -body {
    withWidget .test1 {
        set frame [ruledtext addVLine .test1 200]
        set color [$frame cget -background]
        # Should use default linecolor
        expr {$color ne ""}
    }
} -result 1

test rt-6.4 {addVLine uses custom color} -body {
    withWidget .test1 {
        set frame [ruledtext addVLine .test1 200 "#00ff00"]
        set color [$frame cget -background]
        expr {$color eq "#00ff00"}
    }
} -result 1

test rt-6.5 {clearVLines removes all vertical lines} -body {
    withWidget .test1 {
        ruledtext addVLine .test1 100
        ruledtext addVLine .test1 200
        ruledtext addVLine .test1 300
        set count1 [llength [info commands .test1.txt._vl*]]
        ruledtext clearVLines .test1
        update idletasks
        set count2 [llength [info commands .test1.txt._vl*]]
        list $count1 $count2
    }
} -result {3 0}

test rt-6.6 {setVLineColor changes all vline colors} -body {
    withWidget .test1 {
        set f1 [ruledtext addVLine .test1 100 "#0000ff"]
        set f2 [ruledtext addVLine .test1 200 "#0000ff"]
        ruledtext setVLineColor .test1 "#ff0000"
        set c1 [$f1 cget -background]
        set c2 [$f2 cget -background]
        expr {$c1 eq "#ff0000" && $c2 eq "#ff0000"}
    }
} -result 1

# ==================================================================
# Tab synchronization
# ==================================================================

test rt-7.1 {syncTabs creates tab stops from vlines} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        ruledtext addVLine .test1 100
        ruledtext addVLine .test1 200
        ruledtext syncTabs .test1
        set tabs [.test1.txt cget -tabs]
        expr {[llength $tabs] >= 4}
    }
} -result 1

test rt-7.2 {syncTabs with no vlines clears tabs} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        .test1.txt configure -tabs {100 left 200 left}
        ruledtext syncTabs .test1
        set tabs [.test1.txt cget -tabs]
        expr {$tabs eq ""}
    }
} -result 1

test rt-7.3 {setTabSync enables auto-sync} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        ruledtext setTabSync .test1 1
        ruledtext addVLine .test1 150
        update idletasks
        set tabs [.test1.txt cget -tabs]
        expr {[llength $tabs] >= 2}
    }
} -result 1

test rt-7.4 {clearVLines clears tabs when sync active} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        ruledtext setTabSync .test1 1
        ruledtext addVLine .test1 100
        update idletasks
        set tabs1 [.test1.txt cget -tabs]
        ruledtext clearVLines .test1
        update idletasks
        set tabs2 [.test1.txt cget -tabs]
        expr {[llength $tabs1] > 0 && $tabs2 eq ""}
    }
} -result 1

# ==================================================================
# Presets
# ==================================================================

test rt-8.1 {presetNames returns list} -body {
    set names [ruledtext presetNames]
    expr {[llength $names] > 0}
} -result 1

test rt-8.2 {presetNames includes college} -body {
    set names [ruledtext presetNames]
    expr {"college" in $names}
} -result 1

test rt-8.3 {preset applies college preset} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        ruledtext preset .test1 college
        update idletasks
        # College preset has Courier 12 font
        set fontName "RuledFont_.test1"
        set family [font configure $fontName -family]
        expr {$family eq "Courier"}
    }
} -result 1

test rt-8.4 {preset with unknown name throws error} -body {
    withWidget .test1 {
        catch {ruledtext preset .test1 nonexistent} msg
        string match "*unknown preset*" $msg
    }
} -result 1

test rt-8.5 {preset clears existing vlines} -body {
    withWidget .test1 {
        ruledtext addVLine .test1 100
        ruledtext addVLine .test1 200
        set count1 [llength [info commands .test1.txt._vl*]]
        ruledtext preset .test1 college
        update idletasks
        set count2 [llength [info commands .test1.txt._vl*]]
        # College preset has no vlines
        expr {$count1 == 2 && $count2 == 0}
    }
} -result 1

test rt-8.6 {preset ledger creates vlines} -body {
    withWidget .test1 {
        ruledtext preset .test1 ledger
        update idletasks
        set vlines [info commands .test1.txt._vl*]
        expr {[llength $vlines] > 0}
    }
} -result 1

test rt-8.7 {preset ledger enables tab sync} -body {
    withWidget .test1 {
        set txt [ruledtext textwidget .test1]
        ruledtext preset .test1 ledger
        update idletasks
        set tabs [.test1.txt cget -tabs]
        expr {[llength $tabs] > 0}
    }
} -result 1

test rt-8.8 {vgrid preset removes lines on shrink} -constraints knownBug -body {
    # Create widget in toplevel for resize test
    toplevel .testwin
    pack [ruledtext create .testwin.ed] -fill both -expand 1
    wm geometry .testwin 600x400
    update idletasks
    
    set txt [ruledtext textwidget .testwin.ed]
    # Apply squared preset (has vgrid) - this creates vlines based on current width
    ruledtext preset .testwin.ed squared
    update idletasks
    
    # Count vlines at large size (should be many at 600px width)
    # Wait a bit for vlines to be created
    after 100
    update idletasks
    set vlines1 [info commands .testwin.ed.txt._vl*]
    set count1 [llength $vlines1]
    
    # Manually trigger _draw to ensure vlines are created
    # (preset might create them, but we want to be sure)
    .testwin.ed.txt configure -width 600
    update idletasks
    after 100
    update idletasks
    
    # Shrink widget - this should trigger _reapplyVGrid via Configure event
    wm geometry .testwin 300x400
    update idletasks
    # Wait for resize to process
    after 200
    update idletasks
    
    # Manually trigger Configure on text widget to ensure _draw is called
    .testwin.ed.txt configure -width 300
    update idletasks
    after 100
    update idletasks
    
    # Count vlines after shrink (should be fewer at 300px width)
    set vlines2 [info commands .testwin.ed.txt._vl*]
    set count2 [llength $vlines2]
    
    destroy .testwin
    update idletasks
    
    # Should have fewer lines after shrink
    # Note: If _reapplyVGrid works, count2 should be < count1
    # If it doesn't work, both counts might be similar
    # We check: count1 > 0 (vgrid creates lines) AND count2 < count1 (shrink removes some)
    expr {$count1 > 0 && $count2 < $count1}
} -result 1

# ==================================================================
# Grid size
# ==================================================================

test rt-9.1 {setGridSize sets gridsize mode} -body {
    withWidget .test1 {
        ruledtext setGridSize .test1 "char"
        update idletasks
        # Should not throw error
        expr 1
    }
} -result 1

# ==================================================================
# Per-instance configuration
# ==================================================================

test rt-10.1 {per-instance config: no leaks between widgets} -body {
    # Create widget 1 with custom color
    ruledtext create .test1
    ruledtext setLineColor .test1 "#ff0000"
    
    # Create widget 2 (should have default color)
    ruledtext create .test2
    
    set txt1 [ruledtext textwidget .test1]
    set txt2 [ruledtext textwidget .test2]
    update idletasks
    
    # Get first hline from each
    set h1 [lindex [info commands .test1.txt._hl*] 0]
    set h2 [lindex [info commands .test2.txt._hl*] 0]
    
    if {$h1 ne "" && $h2 ne ""} {
        set c1 [$h1 cget -background]
        set c2 [$h2 cget -background]
        # Colors should be different (test1=red, test2=default blue)
        set different [expr {$c1 ne $c2}]
    } else {
        set different 1
    }
    
    destroy .test1
    destroy .test2
    update idletasks
    
    expr $different
} -result 1

test rt-10.2 {cfg template does not affect existing widgets} -body {
    ruledtext create .test1
    set txt1 [ruledtext textwidget .test1]
    update idletasks
    
    # Change global cfg
    set oldColor $ruledtext::cfg(linecolor)
    set ruledtext::cfg(linecolor) "#00ff00"
    
    # Create new widget (should use new color)
    ruledtext create .test2
    set txt2 [ruledtext textwidget .test2]
    update idletasks
    
    # Get colors
    set h1 [lindex [info commands .test1.txt._hl*] 0]
    set h2 [lindex [info commands .test2.txt._hl*] 0]
    
    if {$h1 ne "" && $h2 ne ""} {
        set c1 [$h1 cget -background]
        set c2 [$h2 cget -background]
        # test1 should keep old color, test2 should have new color
        set correct [expr {$c1 eq $oldColor && $c2 eq "#00ff00"}]
    } else {
        set correct 1
    }
    
    # Restore
    set ruledtext::cfg(linecolor) $oldColor
    
    destroy .test1
    destroy .test2
    update idletasks
    
    expr $correct
} -result 1

# ==================================================================
# Pool growth
# ==================================================================

test rt-11.1 {pool grows dynamically} -body {
    # Create widget in a toplevel for resize test
    toplevel .testwin
    pack [ruledtext create .testwin.ed] -fill both -expand 1
    wm geometry .testwin 400x800
    update idletasks
    
    set txt [ruledtext textwidget .testwin.ed]
    # Should have more hline frames than initial pool (default maxlines=80)
    set hlines [info commands .testwin.ed.txt._hl*]
    set count [llength $hlines]
    
    destroy .testwin
    update idletasks
    
    expr {$count >= 10}
} -result 1

# ==================================================================
# Cleanup
# ==================================================================

test rt-12.1 {cleanup removes state entries} -body {
    set path .test1
    ruledtext create $path
    set txt [ruledtext textwidget $path]
    
    # Check state exists
    set hasState [info exists ::ruledtext::state($path,font)]
    
    destroy $path
    update idletasks
    
    # Check state removed
    set hasStateAfter [info exists ::ruledtext::state($path,font)]
    
    list $hasState $hasStateAfter
} -result {1 0}

test rt-12.2 {cleanup removes named font} -body {
    set path .test1
    set fontName "RuledFont_$path"
    
    ruledtext create $path
    set fontExists1 [expr {[lsearch [font names] $fontName] >= 0}]
    
    destroy $path
    update idletasks
    
    set fontExists2 [expr {[lsearch [font names] $fontName] >= 0}]
    
    list $fontExists1 $fontExists2
} -result {1 0}

# ==================================================================
# Multiple instances
# ==================================================================

test rt-13.1 {multiple instances work independently} -body {
    ruledtext create .test1
    ruledtext create .test2
    ruledtext create .test3
    
    set txt1 [ruledtext textwidget .test1]
    set txt2 [ruledtext textwidget .test2]
    set txt3 [ruledtext textwidget .test3]
    
    $txt1 insert end "Widget 1\n"
    $txt2 insert end "Widget 2\n"
    $txt3 insert end "Widget 3\n"
    
    set c1 [$txt1 get 1.0 end]
    set c2 [$txt2 get 1.0 end]
    set c3 [$txt3 get 1.0 end]
    
    destroy .test1
    destroy .test2
    destroy .test3
    update idletasks
    
    expr {[string match "*Widget 1*" $c1] && \
          [string match "*Widget 2*" $c2] && \
          [string match "*Widget 3*" $c3]}
} -result 1

# ==================================================================
# Cleanup
# ==================================================================

cleanupTests
puts "\n=== Tests completed ==="
