#!/usr/bin/env wish
# demo-pdf-compare.tcl -- Widget/PDF-Vergleich fuer ruledtext
#
# Zeigt das Widget links und die berechneten PDF-Metriken rechts.
# Export erzeugt PDF im gleichen Verzeichnis.
# Zum visuellen Vergleich: Widget und PDF nebeneinander oeffnen.

tcl::tm::path add [file join [file dirname [info script]] .. lib]
package require ruledtext 1.1
package require ruledtext::pdf 1.1

wm title . "ruledtext PDF-Vergleich"
wm geometry . 1050x700

# ============================================================
#  Metrics-Berechnung
# ============================================================
proc computeMetrics {path} {
    set txt $path.txt
    set font [$txt cget -font]
    set actual [font actual $font]

    set family    [dict get $actual -family]
    set sizePt    [dict get $actual -size]
    set weight    [dict get $actual -weight]
    set ascent    [font metrics $font -ascent]
    set descent   [font metrics $font -descent]
    set linespace [font metrics $font -linespace]
    set charW     [font measure $font "M"]

    if {[catch {tk scaling} scaling]} { set scaling 1.0 }
    set factor [expr {72.0 / (96.0 * $scaling)}]

    # pdfLineH wie im Export
    set pdfLineH [expr {$linespace * $factor}]

    # Font-Kalibrierung wie im Export
    lassign [ruledtext::pdf::_mapFont $family] pdfFont pdfFontBold
    if {$weight eq "bold"} { set pdfFont $pdfFontBold }
    set calibFontSize [ruledtext::pdf::_calibrateFontSize $font $pdfFont]

    # Zeichenbreite mit kalibriertem Font
    set tmp [::pdf4tcl::new %AUTO% -paper a4 -orient true]
    $tmp startPage
    $tmp setFont $calibFontSize $pdfFont
    set pdfCharW [$tmp getStringWidth "M"]
    $tmp endPage
    $tmp destroy

    set tkCharW_pt [expr {$charW * $factor}]

    # VLine-Abstande
    set vlineStep $linespace
    set vlineStepPt [expr {$vlineStep * $factor}]

    # Quadrat-Check
    set isSquare [expr {abs($pdfLineH - $vlineStepPt) < 0.01}]

    set marginx $::ruledtext::state($path,cfg,marginx)
    set marginxPt [expr {$marginx * $factor}]

    # V-Linien-Abdeckung
    set lastVX 0
    foreach vl $::ruledtext::state($path,vlines) {
        set vx [lindex $vl 1]
        if {$vx > $lastVX} { set lastVX $vx }
    }
    set lastVXPt [expr {$lastVX * $factor}]

    return [dict create \
        family       $family \
        sizePt       $sizePt \
        pdfFont      $pdfFont \
        ascent_px    $ascent \
        descent_px   $descent \
        linespace_px $linespace \
        charW_px     $charW \
        tk_scaling   $scaling \
        px2pt        $factor \
        calibFontSize $calibFontSize \
        pdfLineH     $pdfLineH \
        vlineStep_pt $vlineStepPt \
        isSquare     $isSquare \
        tkCharW_pt   $tkCharW_pt \
        pdfCharW     $pdfCharW \
        marginx_px   $marginx \
        marginx_pt   $marginxPt \
        numVLines    [llength $::ruledtext::state($path,vlines)] \
        lastVX_pt    $lastVXPt \
    ]
}

proc updateMetricsDisplay {} {
    set m [computeMetrics .ed]

    set t ""
    append t "=== Tk Font Metriken ===\n"
    append t "Font:         [dict get $m family] [dict get $m sizePt]pt\n"
    append t "PDF Font:     [dict get $m pdfFont]\n"
    append t "Ascent:       [dict get $m ascent_px] px\n"
    append t "Descent:      [dict get $m descent_px] px\n"
    append t "Linespace:    [dict get $m linespace_px] px\n"
    append t "Char 'M':     [dict get $m charW_px] px\n"
    append t "\n"
    append t "=== Umrechnung ===\n"
    append t "tk scaling:   [format %.3f [dict get $m tk_scaling]]\n"
    append t "px->pt:       [format %.4f [dict get $m px2pt]]\n"
    append t "\n"
    append t "=== Font-Kalibrierung ===\n"
    append t "font actual:  [dict get $m sizePt] pt (nominal)\n"
    append t "kalibriert:   [format %.2f [dict get $m calibFontSize]] pt\n"
    set ratio [expr {[dict get $m calibFontSize] / double([dict get $m sizePt])}]
    append t "Faktor:       [format %.3f $ratio]\n"
    append t "\n"
    append t "=== Zeichenbreite 'M' ===\n"
    append t "Tk:           [dict get $m charW_px] px = [format %.2f [dict get $m tkCharW_pt]] pt\n"
    append t "PDF:          [format %.2f [dict get $m pdfCharW]] pt\n"
    set diff [expr {abs([dict get $m tkCharW_pt] - [dict get $m pdfCharW])}]
    if {$diff < 0.1} {
        append t "Differenz:    [format %.3f $diff] pt -> PASST\n"
    } else {
        append t "Differenz:    [format %.3f $diff] pt -> MISMATCH!\n"
    }
    append t "\n"
    append t "=== PDF Grid ===\n"
    append t "pdfLineH:     [format %.2f [dict get $m pdfLineH]] pt\n"
    append t "vlineStep:    [format %.2f [dict get $m vlineStep_pt]] pt\n"
    append t "marginx:      [dict get $m marginx_px] px -> [format %.1f [dict get $m marginx_pt]] pt\n"
    append t "V-Linien:     [dict get $m numVLines]\n"
    append t "\n"
    append t "=== Quadrat-Check ===\n"
    if {[dict get $m isSquare]} {
        append t "H=[format %.2f [dict get $m pdfLineH]]  "
        append t "V=[format %.2f [dict get $m vlineStep_pt]]\n"
        append t "-> QUADRAT\n"
    } else {
        append t "H=[format %.2f [dict get $m pdfLineH]]  "
        append t "V=[format %.2f [dict get $m vlineStep_pt]]\n"
        append t "-> RECHTECK!\n"
    }
    append t "\n"
    append t "=== Kaestchen pro 10 Zeichen ===\n"
    set charsPer10 [expr {10.0 * [dict get $m pdfCharW] / [dict get $m pdfLineH]}]
    append t "PDF:  [format %.1f $charsPer10] Kaestchen\n"
    set tkChars [expr {10.0 * [dict get $m charW_px] / double([dict get $m linespace_px])}]
    append t "Tk:   [format %.1f $tkChars] Kaestchen\n"
    append t "\n"
    append t "=== Seiten (A4) ===\n"
    set usableH [expr {842.0 - 100}]
    set lpp [expr {int($usableH / [dict get $m pdfLineH])}]
    append t "Zeilen/Seite: ca. $lpp\n"
    append t "\n"
    append t "=== V-Linien Abdeckung ===\n"
    set lastVXpt [dict get $m lastVX_pt]
    set pdfW 495
    if {$lastVXpt > 0} {
        append t "Letzte: [format %.1f $lastVXpt] pt\n"
        append t "PDF-W:  $pdfW pt\n"
        if {$lastVXpt < ($pdfW - 5)} {
            append t "-> wird erweitert\n"
        } else {
            append t "-> abgedeckt\n"
        }
    } else {
        append t "Keine V-Linien.\n"
    }

    .info.txt configure -state normal
    .info.txt delete 1.0 end
    .info.txt insert end $t
    .info.txt configure -state disabled
}

# ============================================================
#  Export
# ============================================================
proc exportPDF {} {
    set preset [.tb.sel get]
    set dir [file dirname [info script]]
    set filename [file join $dir "compare-${preset}.pdf"]

    updateMetricsDisplay

    .st configure -text "Exportiere $filename ..."
    update

    if {[catch {
        set pages [ruledtext exportPDF .ed $filename \
            -title "Vergleich: $preset"]
        .st configure -text \
            "OK: compare-${preset}.pdf ($pages Seite[expr {$pages > 1 ? {n} : {}}])"
    } err]} {
        .st configure -text "FEHLER: $err"
        tk_messageBox -icon error -title "PDF Export" \
            -message "Export fehlgeschlagen:\n$err"
    }
}

# ============================================================
#  GUI
# ============================================================

# -- Toolbar --
ttk::frame .tb
pack .tb -fill x -padx 6 -pady {6 2}

ttk::label .tb.l -text "Preset:" -font {TkDefaultFont 9 bold}
ttk::combobox .tb.sel -state readonly -width 12 \
    -values [ruledtext presetNames]
.tb.sel set "college"

ttk::button .tb.apply -text "Anwenden" -command {
    ruledtext preset .ed [.tb.sel get]
    fillContent
    after 100 updateMetricsDisplay
    .st configure -text "Preset: [.tb.sel get]"
}
bind .tb.sel <<ComboboxSelected>> { .tb.apply invoke }

ttk::separator .tb.sep1 -orient vertical

ttk::button .tb.pdf -text "PDF erzeugen" -command exportPDF
ttk::button .tb.refresh -text "Metriken" -command updateMetricsDisplay

ttk::separator .tb.sep2 -orient vertical

ttk::button .tb.quit -text "Beenden" -command exit

pack .tb.l .tb.sel .tb.apply -side left -padx {0 4}
pack .tb.sep1 -side left -padx 8 -fill y -pady 2
pack .tb.pdf .tb.refresh -side left -padx 4
pack .tb.sep2 -side left -padx 8 -fill y -pady 2
pack .tb.quit -side right

# -- Main: Widget links, Info rechts --
ttk::panedwindow .pw -orient horizontal
pack .pw -fill both -expand 1 -padx 6 -pady 2

ttk::frame .wf
ruledtext create .ed
pack .ed -in .wf -fill both -expand 1
.pw add .wf -weight 3

ttk::frame .info
text .info.txt -width 42 -height 30 -wrap word \
    -font {Courier 10} -background "#f8f8f0" \
    -state disabled -borderwidth 1 -highlightthickness 0
ttk::scrollbar .info.sb -orient vertical \
    -command {.info.txt yview}
.info.txt configure -yscrollcommand {.info.sb set}
pack .info.sb -side right -fill y
pack .info.txt -side left -fill both -expand 1
.pw add .info -weight 1

ttk::label .st -text "Bereit" -foreground #666666 -anchor w
pack .st -fill x -padx 8 -pady {0 6}

# ============================================================
#  Testinhalt
# ============================================================
proc fillContent {} {
    set txt [ruledtext textwidget .ed]
    $txt configure -state normal
    $txt delete 1.0 end

    $txt insert end "PDF-Vergleichs-Demo\n"
    $txt insert end "===================\n\n"
    $txt insert end "Vergleichspunkte:\n"
    $txt insert end "  - Zeichenbreite passt zum Gitter?\n"
    $txt insert end "  - Quadrate bei 'squared'?\n"
    $txt insert end "  - Linien nicht durch Text?\n"
    $txt insert end "  - Margin am richtigen Ort?\n\n"
    $txt insert end "ABCDEFGHIJ <- 10 Zeichen zaehlen!\n"
    $txt insert end "abcdefghij <- Unterlaengen: gjpqy\n"
    $txt insert end "0123456789 <- Ziffernbreite\n\n"

    for {set i 1} {$i <= 50} {incr i} {
        $txt insert end [format "Zeile %2d: " $i]
        if {$i <= 26} {
            $txt insert end [string repeat [format %c [expr {64 + $i}]] 40]
        } else {
            $txt insert end "Test-Inhalt fuer Paginierung"
        }
        $txt insert end "\n"
    }
    $txt insert end "\nEnde.\n"
}

# -- Init --
ruledtext preset .ed college
fillContent
after 200 updateMetricsDisplay
focus [ruledtext textwidget .ed]
