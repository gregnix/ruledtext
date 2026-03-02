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
#                              de->"Seite", en->"Page", etc.
#
# All positions/colors are taken from the live widget state.
# The PDF replicates the on-screen look as closely as possible
# using pdf4tcl's 14 standard fonts.
#
# Coordinate conversion:
#   Tk values (margins, positions, linespace) are in screen pixels.
#   pdf4tcl works in points (1 pt = 1/72 inch).
#   _px2pt converts: points = pixels * 72 / (96 * [tk scaling])
#
# Font calibration:
#   font actual -size gives logical points, but Tk and PDF standard
#   fonts have different glyph metrics (Tk Courier != PDF Courier).
#   fontSize is calibrated by measuring a reference string in both
#   Tk pixels (_px2pt) and pdf4tcl getStringWidth, then scaling.
#   This ensures text spans the correct number of grid squares.

package require pdf4tcl 0.9
package require ruledtext 1.1
package provide ruledtext::pdf 1.1

namespace eval ruledtext::pdf {}

# ============================================================
#  Helpers
# ============================================================

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

proc ruledtext::pdf::_colorToRGB {color} {
    if {[string index $color 0] eq "#"} {
        return [ruledtext::pdf::_hexToRGB $color]
    }
    if {[catch {winfo rgb . $color} rgb]} {
        return {0.0 0.0 0.0}
    }
    lassign $rgb r g b
    return [list [expr {$r / 65535.0}] [expr {$g / 65535.0}] [expr {$b / 65535.0}]]
}

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

proc ruledtext::pdf::_defaultPageLabel {} {
    if {[catch {package require msgcat}]} {
        return "Page"
    }
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

# Convert Tk screen pixels to PDF points.
# points = pixels * 72 / (96 * [tk scaling])
proc ruledtext::pdf::_px2pt {pixels} {
    if {[catch {tk scaling} scaling] || $scaling <= 0} {
        set scaling 1.0
    }
    return [expr {$pixels * 72.0 / (96.0 * $scaling)}]
}

# Calibrate PDF font size by matching character width.
#
# Tk Courier and PDF Courier have different glyph widths
# relative to the nominal font size. On HiDPI, the mismatch
# is amplified because Tk uses more pixels per character.
#
# Method: measure a 10-char reference string in both systems
# and compute the fontSize that makes PDF widths match Tk widths.
#
# Returns calibrated fontSize in points.
proc ruledtext::pdf::_calibrateFontSize {tkFont pdfFontName} {
    set refStr "MMMMMMMMMM"
    set refSize 10.0

    # Tk width in points
    set tkW_px [font measure $tkFont $refStr]
    set tkW_pt [ruledtext::pdf::_px2pt $tkW_px]

    # PDF width at reference size
    set tmp [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    $tmp startPage
    $tmp setFont $refSize $pdfFontName
    set pdfW [$tmp getStringWidth $refStr]
    $tmp endPage
    $tmp destroy

    if {$pdfW < 0.01} {
        # Fallback: use Tk size
        set sz [dict get [font actual $tkFont] -size]
        if {$sz < 0} { set sz [ruledtext::pdf::_px2pt [expr {abs($sz)}]] }
        return $sz
    }

    # Scale: at what fontSize does PDF width equal Tk width?
    # pdfW scales linearly with fontSize
    return [expr {$tkW_pt * $refSize / $pdfW}]
}

# Extend evenly-spaced V-lines to fill the PDF area width.
# Widget V-lines only cover widget pixel width; PDF page may be wider.
proc ruledtext::pdf::_extendEvenVLines {vlinesVar maxWidth} {
    upvar $vlinesVar vlines
    set n [llength $vlines]
    if {$n < 2} return

    # Detect even spacing
    set step [expr {[lindex $vlines 1 0] - [lindex $vlines 0 0]}]
    if {$step < 1.0} return
    for {set j 1} {$j < $n - 1} {incr j} {
        set sj [expr {[lindex $vlines [expr {$j+1}] 0] - [lindex $vlines $j 0]}]
        if {abs($sj - $step) > 0.5} return
    }

    # Even spacing confirmed -- extend
    set lastX [lindex $vlines end 0]
    set color [lindex $vlines end 1]
    set nextX [expr {$lastX + $step}]
    while {$nextX < $maxWidth} {
        lappend vlines [list $nextX $color]
        set nextX [expr {$nextX + $step}]
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

    if {$pagelabel eq ""} {
        set pagelabel [ruledtext::pdf::_defaultPageLabel]
    }

    lassign $margin ml mt mr mb
    set txt $path.txt

    # --- Font ---
    set font       [$txt cget -font]
    set fontActual [font actual $font]
    set family     [dict get $fontActual -family]
    set fontWeight [dict get $fontActual -weight]

    # Font mapping (must happen before calibration)
    lassign [ruledtext::pdf::_mapFont $family] pdfFont pdfFontBold
    if {$fontWeight eq "bold"} {
        set pdfFont $pdfFontBold
    }

    # Calibrate: find fontSize where PDF char width matches Tk char width.
    # This compensates for different glyph metrics between Tk and PDF fonts,
    # as well as DPI scaling effects.
    set fontSize [ruledtext::pdf::_calibrateFontSize $font $pdfFont]

    # --- Line spacing ---
    # Widget: H-lines and V-lines both step by linespace pixels.
    # Convert to points so squares stay square in PDF.
    set lineH_px [font metrics $font -linespace]
    set pdfLineH [ruledtext::pdf::_px2pt $lineH_px]

    # --- Widget state ---
    set paperbg      $state($path,cfg,paperbg)
    set linecolor    $state($path,cfg,linecolor)
    set margincolor  $state($path,cfg,margincolor)
    set showmargin   $state($path,cfg,showmargin)
    set rmargincolor $state($path,cfg,rmargincolor)
    set showrmargin  $state($path,cfg,showrmargin)

    # Convert ALL pixel values consistently via _px2pt
    set marginx_pt   [ruledtext::pdf::_px2pt $state($path,cfg,marginx)]
    set rmarginx_pt  [ruledtext::pdf::_px2pt $state($path,cfg,rmarginx)]
    set linefrom_pt  [ruledtext::pdf::_px2pt $state($path,cfg,linefrom)]
    set lineto_pt    [ruledtext::pdf::_px2pt $state($path,cfg,lineto)]
    set vlinefrom_pt [ruledtext::pdf::_px2pt $state($path,cfg,vlinefrom)]
    set vlineto_pt   [ruledtext::pdf::_px2pt $state($path,cfg,vlineto)]

    # --- Text content ---
    set content [$txt get 1.0 "end - 1 char"]
    set lines [split $content "\n"]

    # --- Vertical lines (pixels -> points) ---
    set vlines {}
    foreach vl $state($path,vlines) {
        lassign $vl f x
        lappend vlines [list [ruledtext::pdf::_px2pt $x] [$f cget -background]]
    }

    # --- Tab positions (pixels -> points) ---
    set tabsPt {}
    foreach {tval talign} [$txt cget -tabs] {
        lappend tabsPt [ruledtext::pdf::_px2pt $tval] $talign
    }

    # --- Line pattern ---
    set linepattern $state($path,cfg,linepattern)
    set plen [llength $linepattern]

    # --- Create PDF ---
    set pdf [::pdf4tcl::new %AUTO% -paper $paper -orient true -compress 1]
    lassign [$pdf getDrawableArea] pageW pageH

    set areaX $ml
    set areaY $mt
    set areaW [expr {$pageW - $ml - $mr}]
    set areaH [expr {$pageH - $mt - $mb}]
    set areaRight [expr {$areaX + $areaW}]

    # Extend evenly-spaced V-lines (squared/graph) to fill PDF width
    ruledtext::pdf::_extendEvenVLines vlines $areaW

    # Text indent: widget uses marginx + 12px gap
    set padPt [ruledtext::pdf::_px2pt 12]

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
                -x $areaRight \
                -y [expr {$areaY + $fontSize + 2}] \
                -align right
        }

        # -- Horizontal lines --
        lassign [ruledtext::pdf::_colorToRGB $linecolor] lr lg lb
        $pdf setLineWidth 0.5

        set hx1 [expr {$areaX + $linefrom_pt}]
        set hx2 [expr {$lineto_pt > 0 ? $areaX + $lineto_pt : $areaRight}]

        # Ruled paper: lines at contentTop + i*pdfLineH (i=1,2,3...)
        for {set i 1} {$i <= $linesPerPage} {incr i} {
            set ly [expr {$contentTop + $i * $pdfLineH}]
            if {$ly > ($areaY + $areaH)} break
            if {$plen > 0} {
                set pc [lindex $linepattern [expr {($i - 1) % $plen}]]
                if {$pc eq ""} continue
                lassign [ruledtext::pdf::_colorToRGB $pc] lr lg lb
            }
            $pdf setStrokeColor $lr $lg $lb
            $pdf line $hx1 $ly $hx2 $ly
        }

        # -- Vertical line Y range --
        set vy1 [expr {$areaY + $vlinefrom_pt}]
        set vy2 [expr {$vlineto_pt > 0 ? $areaY + $vlineto_pt : $areaY + $areaH}]

        # -- Left margin --
        if {$showmargin} {
            set mx [expr {$areaX + $marginx_pt}]
            if {$mx > $areaX && $mx < $areaRight} {
                lassign [ruledtext::pdf::_colorToRGB $margincolor] mr2 mg2 mb2
                $pdf setStrokeColor $mr2 $mg2 $mb2
                $pdf setLineWidth 0.75
                $pdf line $mx $vy1 $mx $vy2
            }
        }

        # -- Right margin --
        if {$showrmargin} {
            set rmx [expr {$areaRight - $rmarginx_pt}]
            if {$rmx > $areaX && $rmx < $areaRight} {
                lassign [ruledtext::pdf::_colorToRGB $rmargincolor] rr2 rg2 rb2
                $pdf setStrokeColor $rr2 $rg2 $rb2
                $pdf setLineWidth 0.75
                $pdf line $rmx $vy1 $rmx $vy2
            }
        }

        # -- Vertical lines --
        foreach vl $vlines {
            lassign $vl vx vcolor
            set px [expr {$areaX + $vx}]
            if {$px <= $areaX || $px >= $areaRight} continue
            lassign [ruledtext::pdf::_colorToRGB $vcolor] vr vg vb
            $pdf setStrokeColor $vr $vg $vb
            $pdf setLineWidth 0.5
            $pdf line $px $vy1 $px $vy2
        }

        # -- Text --
        # Baseline ON the H-line (ruled paper model).
        # Descenders go below, ascenders above.
        set fgcolor [$txt cget -foreground]
        lassign [ruledtext::pdf::_colorToRGB $fgcolor] fr fg fb
        $pdf setFillColor $fr $fg $fb
        $pdf setFont $fontSize $pdfFont

        set textX [expr {$showmargin ? $areaX + $marginx_pt + $padPt : $areaX + $padPt}]

        for {set i 0} {$i < $linesPerPage && $lineIdx < $totalLines} {incr i; incr lineIdx} {
            # Baseline on H-line at contentTop + (i+1)*pdfLineH
            set textY [expr {$contentTop + ($i + 1) * $pdfLineH}]

            set line [lindex $lines $lineIdx]
            set line [ruledtext::pdf::_sanitize $line]

            if {$line ne ""} {
                if {[string first "\t" $line] >= 0} {
                    ruledtext::pdf::_renderTabLine $pdf $line $textX $textY \
                        $tabsPt $areaX $fontSize $pdfFont $vlines
                } else {
                    $pdf text $line -x $textX -y $textY
                }
            }
        }

        $pdf endPage
    }

    $pdf write -file $filename
    $pdf destroy
    return $pageNum
}

# Render a line containing tabs at correct column positions
proc ruledtext::pdf::_renderTabLine {pdf line textX textY tabsPt areaX fontSize pdfFont vlines} {
    set parts [split $line "\t"]
    set colIdx 0

    foreach part $parts {
        if {$part ne ""} {
            $pdf setFont $fontSize $pdfFont
            $pdf text $part -x $textX -y $textY
        }
        incr colIdx
        if {$colIdx < [llength $parts]} {
            set tabIdx [expr {($colIdx - 1) * 2}]
            if {$tabIdx < [llength $tabsPt]} {
                set textX [expr {$areaX + [lindex $tabsPt $tabIdx]}]
            } else {
                set textX [expr {$textX + $fontSize * 8}]
            }
        }
    }
}

# ============================================================
#  Register in ensemble
# ============================================================
namespace eval ruledtext {
    namespace export exportPDF
}
