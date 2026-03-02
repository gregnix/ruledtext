# ruledtext::pdf-1.1.tm -- PDF export for ruledtext widgets
#
# Exports the current ruledtext widget content as PDF,
# reproducing horizontal lines, margin, vertical lines,
# background color, and text with pagination.
#
# Requires: pdf4tcl 0.9+, ruledtext 1.1+
#
# Usage:
#   tcl::tm::path add /path/to/modules
#   package require ruledtext::pdf 1.1
#   ruledtext exportPDF .ed "output.pdf"
#
# Options:
#   -paper      a4|letter     (default: a4)
#   -margin     {l t r b}     (default: {50 50 50 50}, in points)
#   -title      string        (default: "", header on each page)
#   -pagelabel  string        (default: auto-detected via msgcat)
#                              de→"Seite", en→"Page", etc.
#
# All positions/colors are taken from the live widget state.
# The PDF replicates the on-screen look as closely as possible
# using pdf4tcl's 14 standard fonts.

package require pdf4tcl 0.9
package require ruledtext 1.1
package provide ruledtext::pdf 1.1

# ============================================================
#  PDF namespace for helper functions
# ============================================================

namespace eval ruledtext::pdf {
    # Helper functions moved here to keep ruledtext namespace clean
}

# ============================================================
#  Helpers
# ============================================================

# Convert Tk hex color "#rrggbb" to pdf4tcl {r g b} (0.0-1.0)
proc ruledtext::pdf::_hexToRGB {hex} {
    set hex [string trimleft $hex "#"]
    if {[string length $hex] == 6} {
        scan $hex "%2x%2x%2x" r g b
    } elseif {[string length $hex] == 3} {
        scan $hex "%1x%1x%1x" r g b
        set r [expr {$r * 17}]
        set g [expr {$g * 17}]
        set b [expr {$b * 17}]
    } else {
        return {0.0 0.0 0.0}
    }
    return [list [expr {$r / 255.0}] [expr {$g / 255.0}] [expr {$b / 255.0}]]
}

# Convert any Tk color (hex, named, rgb) to {r g b}
proc ruledtext::pdf::_colorToRGB {color} {
    if {[string index $color 0] eq "#"} {
        return [ruledtext::pdf::_hexToRGB $color]
    }
    # Use winfo rgb on . for named colors → 0-65535
    if {[catch {winfo rgb . $color} rgb]} {
        return {0.0 0.0 0.0}
    }
    lassign $rgb r g b
    return [list [expr {$r / 65535.0}] [expr {$g / 65535.0}] [expr {$b / 65535.0}]]
}

# Map Tk font family to PDF standard font name
# Returns {normal bold} pair
proc ruledtext::pdf::_mapFont {family} {
    set fam [string tolower $family]
    switch -glob -- $fam {
        courier*  -
        consolas* -
        *mono*    { return {Courier Courier-Bold} }
        times*    -
        *serif    { return {Times-Roman Times-Bold} }
        default   { return {Helvetica Helvetica-Bold} }
    }
}

# Sanitize text for PDF standard fonts (WinAnsi subset)
proc ruledtext::pdf::_sanitize {text} {
    set map {
        "\u2502" "|"   "\u2500" "-"   "\u253C" "+"
        "\u2611" "[x]" "\u2610" "[ ]"
        "\u2022" "*"   "\u2026" "..."
        "\u201C" "\"" "\u201D" "\"" "\u201E" "\""
        "\u2018" "'"  "\u2019" "'"
        "\u2013" "-"  "\u2014" "--"
    }
    return [string map $map $text]
}

# Auto-detect page label from system locale via msgcat
proc ruledtext::pdf::_defaultPageLabel {} {
    if {[catch {package require msgcat}]} {
        return "Page"
    }
    # msgcat::mclocale returns e.g. "de_de", "en_us", "fr_fr"
    set locale [string tolower [::msgcat::mclocale]]
    set lang [string range $locale 0 1]
    switch -- $lang {
        de { return "Seite" }
        fr { return "Page" }
        es { return "P\xe1gina" }
        it { return "Pagina" }
        nl { return "Pagina" }
        pt { return "P\xe1gina" }
        da - sv - nb - nn { return "Side" }
        default { return "Page" }
    }
}

# ============================================================
#  Main export proc
# ============================================================
proc ruledtext::exportPDF {path filename args} {
    variable state

    # --- Parse options ---
    set paper     "a4"
    set margin    {50 50 50 50}
    set margin    {50 50 50 0}
    set title     ""
    set pagelabel ""

    foreach {opt val} $args {
        switch -- $opt {
            -paper      { set paper $val }
            -margin     { set margin $val }
            -title      { set title $val }
            -pagelabel  { set pagelabel $val }
            default     { error "unknown option \"$opt\"" }
        }
    }

    # Auto-detect page label if not given
    if {$pagelabel eq ""} {
        set pagelabel [ruledtext::pdf::_defaultPageLabel]
    }

    lassign $margin ml mt mr mb
    set txt $path.txt

    # --- Gather widget state ---
    set font      [$txt cget -font]
    set fontActual [font actual $font]
    set family    [dict get $fontActual -family]
    set fontSize  [dict get $fontActual -size]
    # debug korr 0.58 
    set fontSize [expr {$fontSize * 0.58}]
    set fontWeight [dict get $fontActual -weight]
    if {$fontSize < 0} {
        # Negative = pixels, convert to points via DPI/Tk scaling
        # Tk 8.6+: use [tk scaling] (default 1.0 = 96dpi, 1.5 = 144dpi, etc.)
        # Points = pixels * (72 / (96 * scaling))
        set pixels [expr {abs($fontSize)}]
        if {[catch {tk scaling} scaling]} {
            set scaling 1.0
        }
        set fontSize [expr {$pixels * 72.0 / (96.0 * $scaling)}]
    }

    set lineH     [font metrics $font -linespace]
    # debug korr 0.58
    set lineH     [expr {$lineH * 0.58}]
    set paperbg   $state($path,cfg,paperbg)
    set linecolor $state($path,cfg,linecolor)
    set margincolor $state($path,cfg,margincolor)
    set marginx   $state($path,cfg,marginx)
    set showmargin $state($path,cfg,showmargin)
    set rmargincolor $state($path,cfg,rmargincolor)
    set rmarginx   $state($path,cfg,rmarginx)
    set showrmargin $state($path,cfg,showrmargin)

    # Font mapping
    lassign [ruledtext::pdf::_mapFont $family] pdfFont pdfFontBold
    if {$fontWeight eq "bold"} {
        set pdfFont $pdfFontBold
    }

    # PDF line height: match the visual feel
    # In the widget, factor 1.5 places lines between rows.
    # For PDF: lineH in points = font linespace
    # pdf4tcl works in points, Tk font metrics are in pixels.
    # Approximation: 1px ≈ 0.75pt at 96dpi, but we use fontSize
    # directly since pdf4tcl standard fonts at size N ≈ Tk font N.
    set pdfLineH [expr {$fontSize * 1.5}]

    # --- Collect text content ---
    set content [$txt get 1.0 "end - 1 char"]
    set lines [split $content "\n"]

    # --- Collect vertical lines (x positions + colors) ---
    set vlines {}
    foreach vl $state($path,vlines) {
        lassign $vl f x
        # debug korr 0.58
        set x [expr {$x * 0.58}]
        set vcolor [$f cget -background]
        lappend vlines [list $x $vcolor]
    }

    # --- Tab positions (from text widget) ---
    set tabsList [$txt cget -tabs]

    # --- Horizontal line range ---
    set linefrom $state($path,cfg,linefrom)
    set lineto   $state($path,cfg,lineto)

    # --- Horizontal line pattern ---
    set linepattern $state($path,cfg,linepattern)
    set plen [llength $linepattern]

    # --- Vertical line range ---
    set vlinefrom $state($path,cfg,vlinefrom)
    set vlineto   $state($path,cfg,vlineto)

    # --- Create PDF ---
    set pdf [::pdf4tcl::new %AUTO% -paper $paper -orient true -compress 1]

    # Page dimensions
    lassign [$pdf getDrawableArea] pageW pageH

    # Usable area
    set areaX $ml
    set areaY $mt
    set areaW [expr {$pageW - $ml - $mr}]
    set areaH [expr {$pageH - $mt - $mb}]

    # Scale factor: widget padx to PDF margin offset
    set padx [$txt cget -padx]
    # In the widget, marginx is in pixels from left edge.
    # In PDF, we place it relative to areaX.
    # Simple approach: use the same pixel value as points.
    # This works well for typical values (40-80px ≈ 40-80pt).

    # Lines per page
    set titleH [expr {$title ne "" ? ($fontSize * 2 + 10) : 0}]
    set contentTop [expr {$areaY + $titleH}]
    set linesPerPage [expr {int(($areaH - $titleH) / $pdfLineH)}]
    if {$linesPerPage < 1} { set linesPerPage 1 }

    # --- Render pages ---
    set totalLines [llength $lines]
    set lineIdx 0
    set pageNum 0

    while {$lineIdx < $totalLines} {
        incr pageNum
        $pdf startPage

        # -- Background --
        lassign [ruledtext::pdf::_colorToRGB $paperbg] br bg bb
        $pdf setFillColor $br $bg $bb
        $pdf rectangle $areaX $areaY $areaW $areaH -filled 1

        # -- Title --
        if {$title ne ""} {
            set fgcolor [$txt cget -foreground]
            lassign [ruledtext::pdf::_colorToRGB $fgcolor] fr fg fb
            $pdf setFillColor $fr $fg $fb
            $pdf setFont [expr {$fontSize + 2}] $pdfFontBold
            $pdf text $title -x $areaX -y [expr {$areaY + $fontSize + 2}]
            $pdf setFont 8 Helvetica
            $pdf text "$pagelabel $pageNum" \
                -x [expr {$areaX + $areaW}] \
                -y [expr {$areaY + $fontSize + 2}] \
                -align right
        }

        # -- Horizontal lines --
        lassign [ruledtext::pdf::_colorToRGB $linecolor] lr lg lb
        $pdf setLineWidth 0.5

        set areaRight [expr {$areaX + $areaW}]
        set hx1 [expr {$areaX + $linefrom}]
        set hx2 [expr {$lineto > 0 ? $areaX + $lineto : $areaRight}]

        set y $contentTop
        # First line offset: start between first and second text row
        set firstLineY [expr {$contentTop + $pdfLineH}]
        for {set i 0} {$i < $linesPerPage} {incr i} {
            set ly [expr {$firstLineY + $i * $pdfLineH}]
            if {$ly > ($areaY + $areaH)} break
            if {$plen > 0} {
                set pc [lindex $linepattern [expr {$i % $plen}]]
                if {$pc eq ""} continue
                lassign [ruledtext::pdf::_colorToRGB $pc] lr lg lb
            }
            $pdf setStrokeColor $lr $lg $lb
            $pdf line $hx1 $ly $hx2 $ly
        }

        # -- Vertical line Y range --
        set vy1 [expr {$areaY + $vlinefrom}]
        set vy2 [expr {$vlineto > 0 ? $areaY + $vlineto : $areaY + $areaH}]

        # -- Margin line (clamp to paper area) --
        if {$showmargin} {
            set mx [expr {$areaX + $marginx}]
            if {$mx > $areaX && $mx < $areaRight} {
                lassign [ruledtext::pdf::_colorToRGB $margincolor] mr2 mg2 mb2
                $pdf setStrokeColor $mr2 $mg2 $mb2
                $pdf setLineWidth 0.75
                $pdf line $mx $vy1 $mx $vy2
            }
        }

        # -- Right margin line (clamp to paper area) --
        if {$showrmargin} {
            set rmx [expr {$areaRight - $rmarginx}]
            if {$rmx > $areaX && $rmx < $areaRight} {
                lassign [ruledtext::pdf::_colorToRGB $rmargincolor] rr2 rg2 rb2
                $pdf setStrokeColor $rr2 $rg2 $rb2
                $pdf setLineWidth 0.75
                $pdf line $rmx $vy1 $rmx $vy2
            }
        }

        # -- Vertical lines (clamp to paper area) --
        foreach vl $vlines {
            lassign $vl vx vcolor
            set px [expr {$areaX + $vx}]
            # Skip lines outside the printable area
            if {$px <= $areaX || $px >= $areaRight} continue
            lassign [ruledtext::pdf::_colorToRGB $vcolor] vr vg vb
            $pdf setStrokeColor $vr $vg $vb
            $pdf setLineWidth 0.5
            $pdf line $px $vy1 $px $vy2
        }

        # -- Text content --
        set fgcolor [$txt cget -foreground]
        lassign [ruledtext::pdf::_colorToRGB $fgcolor] fr fg fb
        $pdf setFillColor $fr $fg $fb
        $pdf setFont $fontSize $pdfFont

        set textX [expr {$showmargin ? $areaX + $marginx + 12 : $areaX + 12}]
        #set textX [expr {$showmargin ? 0 + $marginx + 0.12 : 0 + 0.12}]
        set textY [expr {$contentTop + $fontSize}]

        for {set i 0} {$i < $linesPerPage && $lineIdx < $totalLines} {incr i; incr lineIdx} {
            set line [lindex $lines $lineIdx]
            set line [ruledtext::pdf::_sanitize $line]

            if {$line ne ""} {
                # Handle tab characters
                if {[string first "\t" $line] >= 0} {
                    ruledtext::pdf::_renderTabLine $pdf $line $textX $textY \
                        $tabsList $areaX $fontSize $pdfFont $vlines
                } else {
                    $pdf text $line -x $textX -y $textY
                }
            }

            set textY [expr {$textY + $pdfLineH}]
        }

        $pdf endPage
    }

    # --- Save ---
    $pdf write -file $filename
    $pdf destroy

    return $pageNum
}

# Render a line containing tabs at correct column positions
proc ruledtext::pdf::_renderTabLine {pdf line textX textY tabsList areaX fontSize pdfFont vlines} {
    set parts [split $line "\t"]
    set colIdx 0

    foreach part $parts {
        if {$part ne ""} {
            $pdf setFont $fontSize $pdfFont
            $pdf text $part -x $textX -y $textY
        }

        incr colIdx
        # Advance to next tab position
        if {$colIdx < [llength $parts]} {
            # Try to use tab positions from widget
            set tabIdx [expr {($colIdx - 1) * 2}]
            if {$tabIdx < [llength $tabsList]} {
                set tabPos [lindex $tabsList $tabIdx]
                set textX [expr {$areaX + $tabPos}]
            } else {
                # Fallback: advance by 8em
                set textX [expr {$textX + $fontSize * 8}]
            }
        }
    }
}

# ============================================================
#  Register in ensemble
# ============================================================
# The original ensemble uses namespace exports.
# Adding a new export makes it available as subcommand.
namespace eval ruledtext {
    namespace export exportPDF
}
