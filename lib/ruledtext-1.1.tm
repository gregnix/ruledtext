# ruledtext.tcl -- Ruled text widget (notebook paper look)
#
# Technique: 1px frames placed over the text widget.
# Horizontal spacing via font metrics, factor 1.5 places
# lines between text rows. Vertical lines freely positionable.
#
# Per-instance configuration (no global state leaks).
# Named fonts, -insertunfocussed hollow, $txt sync,
# <Destroy> cleanup, dynamic pool growth, resize-aware presets.
#
# Procedural by design: zero dependencies beyond Tk,
# low barrier to entry, simple source-and-use workflow.
# For OOP see TclOO -- this module intentionally avoids it.
#
# Note: Use uniform font size in tags. The line grid is
# based on the base font's linespace metric.
#
# Usage:
#   tcl::tm::path add /path/to/modules
#   package require ruledtext 1.1
#   ruledtext create .ed
#   set txt [ruledtext textwidget .ed]
#
# Or direct source (still works):
#   source -encoding utf-8 ruledtext-1.1.tm
#   ruledtext create .ed
#
# Paper presets:
#   ruledtext preset .ed college
#   ruledtext preset .ed ledger    ;# tab-synced columns
#
# Vertical lines:
#   ruledtext addVLine .ed 200 "#d0d0d0"
#   ruledtext clearVLines .ed
#
# Tab sync (align Tab key with vertical lines):
#   ruledtext setTabSync .ed 1      ;# auto-sync on
#   ruledtext syncTabs .ed          ;# manual one-time sync
#
# Readonly mode:
#   ruledtext setReadonly .ed 1        ;# disabled: no editing, no selection
#   ruledtext setReadonly .ed select   ;# select: no editing, but selection allowed
#   ruledtext setReadonly .ed 0        ;# normal: full editing
#   ruledtext insertText .ed end "text" tag  ;# even when readonly
#
# Margin customization:
#   ruledtext setMarginX .ed 40        ;# move margin to 40px
#   ruledtext setMarginColor .ed "#0000cc"  ;# blue margin
#
# Right margin:
#   ruledtext toggleRMargin .ed 1      ;# show right margin
#   ruledtext setRMarginX .ed 30       ;# 30px from right edge
#   ruledtext setRMarginColor .ed "#e88080" ;# color
#
# Horizontal line range:
#   ruledtext setLineRange .ed 55 0    ;# start at margin, end at right edge
#   ruledtext setLineRange .ed 0 0     ;# full width (default)
#
# Horizontal line pattern:
#   ruledtext setLinePattern .ed {"#d0d8e8" "#b0c0d8"}  ;# alternating
#   ruledtext setLinePattern .ed {}                      ;# uniform (default)
#
# Vertical line range:
#   ruledtext setVLineRange .ed 20 0   ;# start 20px from top, end at bottom
#   ruledtext setVLineRange .ed 0 0    ;# full height (default)
#
# All positions are in pixels, not text units.
#
# Tcl/Tk 8.6+

package require Tk
package provide ruledtext 1.1

namespace eval ruledtext {
    # Default configuration -- copied per instance on create.
    # Safe to change before create, does not leak between instances.
    variable cfg
    array set cfg {
        linecolor    "#c8d8e8"
        margincolor  "#e8a0a0"
        marginx      55
        showmargin   1
        rmarginx     30
        showrmargin  0
        rmargincolor "#e8a0a0"
        paperbg      "#fffff8"
        maxlines     80
        taboffset    0
        linefrom     0
        lineto       0
        vlinefrom    0
        vlineto      0
        linepattern  {}
    }
    variable state

    # Built-in paper presets
    # Each preset: dict with keys linecolor, paperbg, margincolor,
    # showmargin, font, fg (optional), vgrid, vcols, vcolor, tabs
    variable presets
    array set presets {
        college {
            linecolor   "#a8c0e0"
            paperbg     "#fffff8"
            margincolor "#e88080"
            showmargin  1
            font        {Courier 12}
        }
        vintage {
            linecolor   "#c8b890"
            paperbg     "#f5f0e0"
            margincolor "#c0a878"
            showmargin  0
            font        {Times 13}
        }
        minimal {
            linecolor   "#e8e8e8"
            paperbg     "#ffffff"
            margincolor "#dddddd"
            showmargin  0
            font        {Helvetica 11}
        }
        dark {
            linecolor   "#404050"
            paperbg     "#2a2a35"
            margincolor "#505060"
            showmargin  1
            font        {Consolas 12}
            fg          "#d0d0d8"
        }
        green {
            linecolor   "#a8d0a8"
            paperbg     "#f0f8f0"
            margincolor "#80b080"
            showmargin  1
            font        {Courier 11}
        }
        squared {
            linecolor   "#d0d8e0"
            paperbg     "#f8f8ff"
            margincolor "#d0d8e0"
            showmargin  0
            font        {Courier 12}
            vgrid       1
        }
        graph {
            linecolor   "#c0d8c0"
            paperbg     "#f8fff8"
            margincolor "#c0d8c0"
            showmargin  0
            font        {Courier 10}
            vgrid       1
        }
        columns {
            linecolor   "#d8d8d8"
            paperbg     "#ffffff"
            margincolor "#d0d0d0"
            showmargin  0
            font        {Helvetica 11}
            vcols       {220 440}
            vcolor      "#d0d0d0"
            tabs        1
        }
        ledger {
            linecolor   "#d8d8d8"
            paperbg     "#fffff8"
            margincolor "#e0a0a0"
            showmargin  1
            font        {Courier 11}
            vcols       {140 420 520}
            vcolor      "#c0c0c0"
            tabs        1
        }
        music {
            linecolor   "#b0b0b0"
            paperbg     "#fffef0"
            margincolor "#b0b0b0"
            showmargin  0
            font        {Courier 12}
            linepattern {"#b0b0b0" "#b0b0b0" "#b0b0b0" "#b0b0b0" "#b0b0b0" "" "" ""}
        }
        todo {
            linecolor   "#d8e0d8"
            paperbg     "#fcfcf8"
            margincolor "#d8e0d8"
            showmargin  0
            font        {Helvetica 11}
            vcols       {30}
            vcolor      "#c8d0c8"
            tabs        1
        }
    }

    # Ensemble: allows "ruledtext create .ed" instead of "ruledtext::create .ed"
    namespace export create textwidget setFont setLineColor setLineRange \
        setLinePattern toggleMargin setMarginX setMarginColor setVLineRange \
        toggleRMargin setRMarginX setRMarginColor \
        clear setReadonly insertText setGridSize addVLine clearVLines \
        setVLineColor syncTabs setTabSync presetNames preset
    namespace ensemble create
}

# ============================================================
#  Create widget
# ============================================================
proc ruledtext::create {path args} {
    variable cfg
    variable state

    ttk::frame $path

    # Per-instance config -- copy defaults, no cross-instance leaks
    foreach key [array names cfg] {
        set state($path,cfg,$key) $cfg($key)
    }

    # Named font -- font configure updates all widgets at once
    set state($path,font) "RuledFont_$path"
    font create $state($path,font) {*}[font actual {Courier 12}]

    set icfg_showmargin $state($path,cfg,showmargin)
    set icfg_marginx    $state($path,cfg,marginx)
    set icfg_showrmargin $state($path,cfg,showrmargin)
    set icfg_rmarginx    $state($path,cfg,rmarginx)
    set icfg_paperbg    $state($path,cfg,paperbg)
    set icfg_linecolor  $state($path,cfg,linecolor)
    set icfg_margincolor $state($path,cfg,margincolor)

    set lpad [expr {$icfg_showmargin ? $icfg_marginx + 12 : 12}]
    # Note: rpad calculated but not used - Tk text -padx is symmetric only
    # Right margin is visual only (placed via ::place)

    text $path.txt -wrap word -borderwidth 1 -highlightthickness 0 \
        -background $icfg_paperbg \
        -font $state($path,font) \
        -padx $lpad  \
        -pady 6 -undo true \
        -spacing1 0 -spacing2 0 -spacing3 0 \
        -insertunfocussed hollow \
        -yscrollcommand [list ruledtext::_onScroll $path]

    ttk::scrollbar $path.sb -orient vertical \
        -command [list $path.txt yview]

    pack $path.sb  -side right -fill y
    pack $path.txt -side left -fill both -expand 1

    # Horizontal line pool (grows dynamically if needed)
    set state($path,hpool) {}
    set state($path,hcount) 0
    _growPool $path $state($path,cfg,maxlines)

    # Margin line (left)
    set state($path,margin) [frame $path.txt._margin \
        -width 1 -background $icfg_margincolor -borderwidth 0]

    # Margin line (right)
    set state($path,rmargin) [frame $path.txt._rmargin \
        -width 1 -background $state($path,cfg,rmargincolor) -borderwidth 0]

    # Vertical lines (dynamic)
    set state($path,vlines) {}
    set state($path,vcount) 0
    set state($path,synctabs) 0
    set state($path,gridsize) ""
    set state($path,lastpreset) ""

    set state($path,afterid) ""

    # Configure: Chain with existing binding if any
    # Note: <Configure> doesn't support + prefix, so we manually chain
    # Also bind on the frame to catch resize events
    set existingConfigure [bind $path.txt <Configure>]
    if {$existingConfigure ne ""} {
        bind $path.txt <Configure> "$existingConfigure; [list ruledtext::_sched $path]"
    } else {
        bind $path.txt <Configure> [list ruledtext::_sched $path]
    }
    # Also bind on frame to catch frame resize
    bind $path <Configure> +[list ruledtext::_sched $path]
    
    # KeyRelease: Chain with existing binding if any
    set existingKeyRelease [bind $path.txt <KeyRelease>]
    if {$existingKeyRelease ne ""} {
        bind $path.txt <KeyRelease> "$existingKeyRelease; [list ruledtext::_sched $path]"
    } else {
        bind $path.txt <KeyRelease> [list ruledtext::_sched $path]
    }
    
    # Mouse events support + prefix
    bind $path.txt <MouseWheel> "+[list ruledtext::_sched $path]"
    bind $path.txt <Button-4>   "+[list ruledtext::_sched $path]"
    bind $path.txt <Button-5>   "+[list ruledtext::_sched $path]"

    # Cleanup on destroy -- remove state arrays, named font, readonly bindtag
    bind $path <Destroy> +[list ruledtext::_cleanup $path]

    after idle [list ruledtext::_draw $path]
    return $path
}

# ============================================================
#  Pool management (dynamic growth)
# ============================================================
proc ruledtext::_growPool {path needed} {
    variable state
    set have [llength $state($path,hpool)]
    if {$needed <= $have} return
    set linecolor $state($path,cfg,linecolor)
    for {set i $have} {$i < $needed} {incr i} {
        lappend state($path,hpool) \
            [frame $path.txt._hl$i -height 1 \
                -background $linecolor -borderwidth 0]
    }
    set state($path,hcount) [llength $state($path,hpool)]
}

# Recalculate -padx (left side only; Tk text widget padx is symmetric).
# Right margin is visual only (via place), does not affect text padding.
proc ruledtext::_updatePadx {path} {
    variable state
    set lpad [expr {$state($path,cfg,showmargin)  ? $state($path,cfg,marginx) + 12  : 12}]
    $path.txt configure -padx  $lpad
}

# ============================================================
#  Throttle (max once per 16ms)
# ============================================================
proc ruledtext::_sched {path} {
    variable state
    if {![info exists state($path,afterid)]} return
    if {$state($path,afterid) ne ""} return
    set state($path,afterid) \
        [after 16 [list ruledtext::_draw $path]]
}

proc ruledtext::_onScroll {path args} {
    $path.sb set {*}$args
    ruledtext::_sched $path
}

# Cleanup: remove all state entries and named font
proc ruledtext::_cleanup {path} {
    variable state
    # Cancel pending after
    if {[info exists state($path,afterid)] \
            && $state($path,afterid) ne ""} {
        after cancel $state($path,afterid)
    }
    # Delete named font
    if {[info exists state($path,font)]} {
        catch { font delete $state($path,font) }
    }
    # Cleanup readonly bindtag if it exists
    if {[info exists state($path,readonly_tag)]} {
        catch {bind $state($path,readonly_tag) <KeyPress> {}}
        catch {bind $state($path,readonly_tag) <KeyRelease> {}}
    }
    # Remove all state entries for this path
    foreach key [array names state "$path,*"] {
        unset state($key)
    }
}

# ============================================================
#  Core draw routine
# ============================================================
proc ruledtext::_draw {path} {
    variable state

    # Defensive guard -- widget may be destroyed between schedule and draw
    if {![info exists state($path,afterid)]} return
    set state($path,afterid) ""

    set txt $path.txt
    if {![winfo exists $txt] || ![winfo ismapped $txt]} return

    set W [winfo width $txt]
    set H [winfo height $txt]
    if {$W < 20 || $H < 20} return

    # Ensure layout is up to date before querying positions
    $txt sync

    # --- Reapply vgrid preset on resize ---
    # This must happen BEFORE drawing vlines, so we can remove excess lines
    if {[info exists state($path,lastpreset)] \
            && $state($path,lastpreset) ne ""} {
        variable presets
        set pname $state($path,lastpreset)
        if {[info exists presets($pname)]} {
            set p $presets($pname)
            if {[dict exists $p vgrid] && [dict get $p vgrid]} {
                _reapplyVGrid $path $p $W
            }
        }
    }

    # --- Horizontal lines ---
    set pool $state($path,hpool)
    set font [$txt cget -font]

    # Grid size: either font linespace or forced char width
    if {[info exists state($path,gridsize)] \
            && $state($path,gridsize) eq "char"} {
        set lineH [font measure $font "M"]
    } else {
        set lineH [font metrics $font -linespace]
    }
    if {$lineH < 4} return

    set info [$txt dlineinfo @0,0]
    set ay [expr {$info eq "" ? 6 : [lindex $info 1]}]
    set y  [expr {$ay + 1.5 * $lineH}]

    while {$y > $lineH} { set y [expr {$y - $lineH}] }

    # How many lines do we need?
    set needed [expr {int(($H - $y) / $lineH) + 2}]
    if {$needed > [llength $pool]} {
        _growPool $path $needed
        set pool $state($path,hpool)
    }

    set used 0
    set hx $state($path,cfg,linefrom)
    set hto $state($path,cfg,lineto)
    set hw [expr {($hto > 0 ? $hto : $W) - $hx}]
    set pattern $state($path,cfg,linepattern)
    set plen [llength $pattern]
    while {$y < $H && $used < [llength $pool]} {
        set f [lindex $pool $used]
        if {$plen > 0} {
            set pc [lindex $pattern [expr {$used % $plen}]]
            if {$pc eq ""} {
                ::place forget $f
                incr used
                set y [expr {$y + $lineH}]
                continue
            }
            $f configure -background $pc
        }
        ::place $f -in $txt \
            -x $hx -y [expr {int($y)}] -width $hw -height 1
        raise $f
        incr used
        set y [expr {$y + $lineH}]
    }
    for {set i $used} {$i < [llength $pool]} {incr i} {
        ::place forget [lindex $pool $i]
    }

    # --- Vertical line range ---
    set vy $state($path,cfg,vlinefrom)
    set vto $state($path,cfg,vlineto)
    set vh [expr {($vto > 0 ? $vto : $H) - $vy}]

    # --- Margin (left) ---
    set mf $state($path,margin)
    if {$state($path,cfg,showmargin)} {
        ::place $mf -in $txt -x $state($path,cfg,marginx) -y $vy \
            -width 1 -height $vh
        raise $mf
    } else {
        ::place forget $mf
    }

    # --- Margin (right) ---
    set rmf $state($path,rmargin)
    if {$state($path,cfg,showrmargin)} {
        set rx [expr {$W - $state($path,cfg,rmarginx)}]
        if {$rx > 0 && $rx < $W} {
            ::place $rmf -in $txt -x $rx -y $vy \
                -width 1 -height $vh
            raise $rmf
        } else {
            ::place forget $rmf
        }
    } else {
        ::place forget $rmf
    }

    # --- Vertical lines ---
    foreach vl $state($path,vlines) {
        lassign $vl f x
        ::place $f -in $txt -x $x -y $vy \
            -width 1 -height $vh
        raise $f
    }
}

# Regenerate vgrid vertical lines when widget width changed.
# Called from _draw, only for vgrid presets.
proc ruledtext::_reapplyVGrid {path preset W} {
    variable state
    set txt $path.txt
    set font [$txt cget -font]
    set step [font metrics $font -linespace]
    if {$step < 4 || $W < 40} {
        # Widget too small, remove all vlines
        clearVLines $path
        return
    }

    # Count current vgrid lines and find max position
    set currentMax 0
    set vlinesToKeep {}
    foreach vl $state($path,vlines) {
        set x [lindex $vl 1]
        if {$x > $currentMax} { set currentMax $x }
        # Keep lines that are still within visible area
        # Remove lines that are clearly outside the widget width
        if {$x < $W} {
            lappend vlinesToKeep $vl
        } else {
            # Remove line outside visible area
            set f [lindex $vl 0]
            if {[winfo exists $f]} {
                destroy $f
            }
        }
    }
    
    # Update state with kept lines
    set state($path,vlines) $vlinesToKeep

    # Need more lines? (widget grew)
    set needed [expr {int($W / $step) * $step}]
    if {$needed > $currentMax} {
        set linecolor [dict get $preset linecolor]
        for {set x [expr {$currentMax + $step}]} {$x < $W} {incr x $step} {
            addVLine $path $x $linecolor
        }
    }
}

# ============================================================
#  API: Basic
# ============================================================
proc ruledtext::textwidget {path} { return $path.txt }

proc ruledtext::setFont {path fontspec} {
    variable state
    # Update named font -- all widgets using it update automatically
    font configure $state($path,font) {*}[font actual $fontspec]
    after idle [list ruledtext::_draw $path]
}

proc ruledtext::toggleMargin {path show} {
    variable state
    set state($path,cfg,showmargin) $show
    _updatePadx $path
    after idle [list ruledtext::_draw $path]
}

proc ruledtext::setMarginX {path x} {
    variable state
    set state($path,cfg,marginx) $x
    _updatePadx $path
    after idle [list ruledtext::_draw $path]
}

proc ruledtext::setMarginColor {path color} {
    variable state
    set state($path,cfg,margincolor) $color
    $path.txt._margin configure -background $color
}

proc ruledtext::toggleRMargin {path show} {
    variable state
    set state($path,cfg,showrmargin) $show
    _updatePadx $path
    after idle [list ruledtext::_draw $path]
}

proc ruledtext::setRMarginX {path x} {
    variable state
    set state($path,cfg,rmarginx) $x
    _updatePadx $path
    after idle [list ruledtext::_draw $path]
}

proc ruledtext::setRMarginColor {path color} {
    variable state
    set state($path,cfg,rmargincolor) $color
    $path.txt._rmargin configure -background $color
}

proc ruledtext::setLineColor {path color} {
    variable state
    set state($path,cfg,linecolor) $color
    foreach f $state($path,hpool) { $f configure -background $color }
    after idle [list ruledtext::_draw $path]
}

# Set horizontal line start/end position (pixels from left widget edge).
# from=0 means left edge, to=0 means right edge (full width).
proc ruledtext::setLineRange {path from to} {
    variable state
    set state($path,cfg,linefrom) $from
    set state($path,cfg,lineto) $to
    after idle [list ruledtext::_draw $path]
}

# Set vertical line start/end position (pixels from top widget edge).
# from=0 means top edge, to=0 means bottom edge (full height).
# Applies to margin line AND all vlines.
proc ruledtext::setVLineRange {path from to} {
    variable state
    set state($path,cfg,vlinefrom) $from
    set state($path,cfg,vlineto) $to
    after idle [list ruledtext::_draw $path]
}

# Set a cyclic color pattern for horizontal lines.
# Empty list = use linecolor for all (default).
# Empty string "" in the list = skip that line (invisible).
#
# Examples:
#   setLinePattern .ed {}                        ;# uniform (use linecolor)
#   setLinePattern .ed {"#d0d8e8" "#b0c0d8"}     ;# alternating
#   setLinePattern .ed {"#b0b0b0" "#b0b0b0" "#b0b0b0" "#b0b0b0" "#b0b0b0" "" "" ""}
#                                                 ;# music staff (5 on, 3 off)
proc ruledtext::setLinePattern {path pattern} {
    variable state
    set state($path,cfg,linepattern) $pattern
    # When clearing pattern, restore uniform linecolor on all pool frames
    if {[llength $pattern] == 0} {
        set color $state($path,cfg,linecolor)
        foreach f $state($path,hpool) { $f configure -background $color }
    }
    after idle [list ruledtext::_draw $path]
}

proc ruledtext::clear {path} { $path.txt delete 1.0 end }

# Readonly mode
#   ruledtext setReadonly .ed 1        ;# disabled: no editing, no selection
#   ruledtext setReadonly .ed select  ;# select: no editing, but mouse selection allowed
#   ruledtext setReadonly .ed 0       ;# normal: full editing
proc ruledtext::setReadonly {path {readonly 1}} {
    variable state
    set txt $path.txt
    
    if {$readonly eq "select"} {
        # Select mode: block keyboard editing but allow mouse selection
        # Keep widget in normal state, block key bindings
        $txt configure -state normal
        
        # Store original bindtags if not already stored
        if {![info exists state($path,orig_bindtags)]} {
            set state($path,orig_bindtags) [bindtags $txt]
        }
        
        # Create readonly bindtag if it doesn't exist
        if {![info exists state($path,readonly_tag)]} {
            set state($path,readonly_tag) "RuledTextReadonly_$path"
            bind $state($path,readonly_tag) <KeyPress> {break}
            bind $state($path,readonly_tag) <KeyRelease> {break}
        }
        
        # Add readonly tag to bindtags (before Text bindings)
        set tags [bindtags $txt]
        if {$state($path,readonly_tag) ni $tags} {
            set tags [linsert $tags 0 $state($path,readonly_tag)]
            bindtags $txt $tags
        }
    } elseif {$readonly} {
        # Disabled mode: traditional readonly (no editing, no selection)
        $txt configure -state disabled
        
        # Restore original bindtags if we were in select mode
        if {[info exists state($path,orig_bindtags)]} {
            bindtags $txt $state($path,orig_bindtags)
            unset state($path,orig_bindtags)
        }
    } else {
        # Normal mode: full editing
        $txt configure -state normal
        
        # Restore original bindtags if we were in select mode
        if {[info exists state($path,orig_bindtags)]} {
            bindtags $txt $state($path,orig_bindtags)
            unset state($path,orig_bindtags)
        }
    }
}

# Convenience: insert text even when readonly
proc ruledtext::insertText {path args} {
    set txt $path.txt
    set wasDisabled [expr {[$txt cget -state] eq "disabled"}]
    if {$wasDisabled} { $txt configure -state normal }
    $txt insert {*}$args
    if {$wasDisabled} { $txt configure -state disabled }
}

# Set horizontal grid mode: "char" = char width, "" = linespace
proc ruledtext::setGridSize {path mode} {
    variable state
    set state($path,gridsize) $mode
    after idle [list ruledtext::_draw $path]
}

# ============================================================
#  API: Vertical lines
# ============================================================

# Add a vertical line at pixel position x
proc ruledtext::addVLine {path x {color ""}} {
    variable state

    if {$color eq ""} { set color $state($path,cfg,linecolor) }

    incr state($path,vcount)
    set f [frame $path.txt._vl$state($path,vcount) \
        -width 1 -background $color -borderwidth 0]
    lappend state($path,vlines) [list $f $x]

    # Auto-sync tab stops if enabled
    if {[info exists state($path,synctabs)] \
            && $state($path,synctabs)} {
        syncTabs $path
    }

    after idle [list ruledtext::_draw $path]
    return $f
}

# Remove all vertical lines
proc ruledtext::clearVLines {path} {
    variable state
    foreach vl $state($path,vlines) {
        ::place forget [lindex $vl 0]
        destroy [lindex $vl 0]
    }
    set state($path,vlines) {}
    # Clear tabs if sync was active
    if {[info exists state($path,synctabs)] \
            && $state($path,synctabs)} {
        $path.txt configure -tabs {}
    }
}

# Change color of all vertical lines
proc ruledtext::setVLineColor {path color} {
    variable state
    foreach vl $state($path,vlines) {
        [lindex $vl 0] configure -background $color
    }
}

# Sync vertical line positions to text widget tab stops.
#
# -tabs measures from text left edge (after padx+bw).
# place -x measures from widget edge (before bw).
# padx cancels out. Only borderwidth matters:
#   tabpos = vline_x - borderwidth + offset
#
# Usage:
#   ruledtext addVLine .ed 140
#   ruledtext addVLine .ed 420
#   ruledtext syncTabs .ed          ;# one-time sync
#   ruledtext setTabSync .ed 1      ;# auto-sync on addVLine
proc ruledtext::syncTabs {path} {
    variable state
    set txt $path.txt

    if {[llength $state($path,vlines)] == 0} {
        $txt configure -tabs {}
        return
    }

    # Collect x positions, sort ascending
    set positions {}
    foreach vl $state($path,vlines) {
        lappend positions [lindex $vl 1]
    }
    set positions [lsort -integer $positions]

    set bw [$txt cget -borderwidth]
    if {[llength $positions] >= 2} {
        set colwidth [expr {[lindex $positions 1] - [lindex $positions 0]}]
        set offset [expr {($colwidth / 2) + 2}]
    } else {
        set offset [expr {$state($path,cfg,taboffset) + 2}]
    }
    set tabs {}
    foreach x $positions {
        set tabpos [expr {$x - $bw + $offset}]
        if {$tabpos > 0} {
            lappend tabs $tabpos left
        }
    }

    $txt configure -tabs $tabs
}

# Enable/disable automatic tab sync when adding vlines
proc ruledtext::setTabSync {path enabled} {
    variable state
    set state($path,synctabs) $enabled
    if {$enabled} { syncTabs $path }
}

# ============================================================
#  API: Paper presets
# ============================================================

# List available preset names
proc ruledtext::presetNames {} {
    variable presets
    return [lsort [array names presets]]
}

# Apply a named preset
proc ruledtext::preset {path name} {
    variable presets
    variable state

    if {![info exists presets($name)]} {
        error "unknown preset \"$name\", available: [presetNames]"
    }

    set p $presets($name)
    set txt $path.txt

    # Remember preset for resize-aware reapply
    set state($path,lastpreset) $name

    # Clear existing vertical lines and reset grid mode
    clearVLines $path
    set state($path,gridsize) ""
    set state($path,cfg,linefrom) 0
    set state($path,cfg,lineto) 0
    set state($path,cfg,vlinefrom) 0
    set state($path,cfg,vlineto) 0
    set state($path,cfg,linepattern) {}
    set state($path,synctabs) 0
    $path.txt configure -tabs {} -tabstyle tabular

    # Line color
    if {[dict exists $p linecolor]} {
        setLineColor $path [dict get $p linecolor]
    }

    # Paper background
    if {[dict exists $p paperbg]} {
        set state($path,cfg,paperbg) [dict get $p paperbg]
        $txt configure -background [dict get $p paperbg]
    }

    # Margin
    if {[dict exists $p margincolor]} {
        set state($path,cfg,margincolor) [dict get $p margincolor]
        $path.txt._margin configure \
            -background [dict get $p margincolor]
    }
    if {[dict exists $p showmargin]} {
        toggleMargin $path [dict get $p showmargin]
    }

    # Right margin (default: off)
    if {[dict exists $p rmargincolor]} {
        set state($path,cfg,rmargincolor) [dict get $p rmargincolor]
        $path.txt._rmargin configure \
            -background [dict get $p rmargincolor]
    }
    if {[dict exists $p rmarginx]} {
        set state($path,cfg,rmarginx) [dict get $p rmarginx]
    }
    if {[dict exists $p showrmargin]} {
        toggleRMargin $path [dict get $p showrmargin]
    } else {
        toggleRMargin $path 0
    }

    # Font
    if {[dict exists $p font]} {
        setFont $path [dict get $p font]
    }

    # Text color (default: black)
    if {[dict exists $p fg]} {
        $txt configure -foreground [dict get $p fg] \
            -insertbackground [dict get $p fg]
    } else {
        $txt configure -foreground black \
            -insertbackground black
    }

    # Grid size mode: "char" = square grid based on char width
    if {[dict exists $p gridsize]} {
        set state($path,gridsize) [dict get $p gridsize]
    }

    # Horizontal line range (optional, default 0 0 = full width)
    if {[dict exists $p linefrom]} {
        set state($path,cfg,linefrom) [dict get $p linefrom]
    }
    if {[dict exists $p lineto]} {
        set state($path,cfg,lineto) [dict get $p lineto]
    }

    # Vertical line range (optional, default 0 0 = full height)
    if {[dict exists $p vlinefrom]} {
        set state($path,cfg,vlinefrom) [dict get $p vlinefrom]
    }
    if {[dict exists $p vlineto]} {
        set state($path,cfg,vlineto) [dict get $p vlineto]
    }

    # Horizontal line pattern (optional, default {} = uniform)
    if {[dict exists $p linepattern]} {
        set state($path,cfg,linepattern) [dict get $p linepattern]
    }

    # Grid mode: vertical lines at linespace intervals (= squares)
    if {[dict exists $p vgrid] && [dict get $p vgrid]} {
        set font [$txt cget -font]
        set step [font metrics $font -linespace]
        set W [winfo width $txt]
        if {$W > 40} {
            for {set x $step} {$x < $W} {incr x $step} {
                addVLine $path $x [dict get $p linecolor]
            }
        }
    }

    # Column lines at fixed positions
    if {[dict exists $p vcols]} {
        set vc [expr {[dict exists $p vcolor] \
            ? [dict get $p vcolor] : "#c0c0c0"}]
        foreach x [dict get $p vcols] {
            addVLine $path $x $vc
        }
    }

    # Tab sync: align tab stops with vertical line positions
    if {[dict exists $p tabs] && [dict get $p tabs]} {
        $path.txt configure -tabstyle wordprocessor
        setTabSync $path 1
    }

    after idle [list ruledtext::_draw $path]
}
