# ruledtext Tests

Test-Suite für `ruledtext 1.2` und `ruledtext::pdf 1.2`.

## Tests ausführen

### Alle Tests

```bash
cd test
wish test_ruledtext.tcl
wish test_pdf.tcl
```

### Einzelne Tests

```bash
wish test_ruledtext.tcl -match "rt-1.*"
wish test_pdf.tcl -match "pdf-1.*"
```

## Test-Abdeckung

### test_ruledtext.tcl (Hauptmodul)

**Basis-API:**
- ✅ Widget-Erstellung (`create`)
- ✅ Text-Widget-Zugriff (`textwidget`)
- ✅ Widget-Struktur (frame + text + scrollbar)
- ✅ Named Fonts (Erstellung, Löschung)

**Font-Operationen:**
- ✅ Font ändern (`setFont`)
- ✅ Font-Update auf Text-Widget

**Linien:**
- ✅ Linienfarbe ändern (`setLineColor`)
- ✅ Margin ein/aus (`toggleMargin`)
- ✅ Margin-Position (`padx`-Anpassung)

**Text-Operationen:**
- ✅ Text löschen (`clear`)
- ✅ Readonly-Modus (`setReadonly`)
- ✅ Readonly select Modus (Keyboard blockiert, Selektion erlaubt)
- ✅ Text einfügen bei Readonly (`insertText`)

**Vertikale Linien:**
- ✅ Vertikale Linie hinzufügen (`addVLine`)
- ✅ Alle vertikalen Linien entfernen (`clearVLines`)
- ✅ Farbe aller vertikalen Linien ändern (`setVLineColor`)

**Tab-Synchronisation:**
- ✅ Tab-Stops aus vertikalen Linien (`syncTabs`)
- ✅ Auto-Sync ein/aus (`setTabSync`)
- ✅ Tab-Clear bei `clearVLines`

**Presets:**
- ✅ Preset-Namen auflisten (`presetNames`)
- ✅ Preset anwenden (`preset`)
- ✅ Fehler bei unbekanntem Preset
- ✅ Preset löscht vorhandene vlines
- ✅ Preset mit vlines (ledger)
- ✅ Preset mit Tab-Sync (ledger)
- ✅ vgrid-Preset entfernt Linien beim Verkleinern

**Grid-Größe:**
- ✅ Grid-Modus setzen (`setGridSize`)

**Per-Instanz-Konfiguration:**
- ✅ Keine Leaks zwischen Widgets
- ✅ cfg-Template ändert keine existierenden Widgets

**Pool-Wachstum:**
- ✅ Dynamisches Pool-Wachstum bei großen Fenstern

**Cleanup:**
- ✅ State-Einträge werden entfernt
- ✅ Named Font wird gelöscht

**Mehrere Instanzen:**
- ✅ Unabhängige Widgets

### test_pdf.tcl (PDF-Export)

**PDF-Export:**
- ✅ Basis-Export
- ✅ Export mit Titel
- ✅ Export mit custom Paper-Size
- ✅ Export mit vertikalen Linien
- ✅ Export mit Preset
- ✅ Paginierung bei vielen Zeilen
- ✅ Fehler bei unbekannter Option

**Helper-Funktionen:**
- ✅ Hex-zu-RGB-Konvertierung (in `ruledtext::pdf::` Namespace)
- ✅ Font-Mapping
- ✅ Text-Sanitization
- ✅ Pixel→Point Fontsize-Konvertierung (DPI-aware)

## Voraussetzungen

- **Tcl/Tk 8.6+** (für `wish`)
- **tcltest 2.5** (Standard-Package)
- **pdf4tcl 0.9+** (nur für `test_pdf.tcl`)

## Test-Struktur

Tests verwenden `tcltest` mit `wish` (GUI-Tests).

**Helper-Procedures:**
- `withWidget`: Erstellt Widget, führt Test aus, zerstört Widget

**Test-Namen:**
- `rt-*`: ruledtext Hauptmodul
- `pdf-*`: PDF-Export-Modul

## Bekannte Einschränkungen

- Tests benötigen GUI (`wish`)
- Einige Tests prüfen visuelle Eigenschaften (Farben, Positionen)
- PDF-Tests benötigen `pdf4tcl` (optional)

## Neue Features (getestet)

- ✅ **readonly select Modus**: Keyboard-Editing blockiert, Maus-Selektion erlaubt
- ✅ **vgrid Shrink**: Automatisches Entfernen von Linien außerhalb des sichtbaren Bereichs
- ✅ **DPI-aware Fontsize-Konvertierung**: Pixel→Point über `tk scaling`
- ✅ **Namespace-Design**: PDF-Helper in `ruledtext::pdf::` Namespace

## Erweiterte Tests (könnten hinzugefügt werden)

- Performance-Tests (viele Widgets, große Dokumente)
- Scroll-Verhalten
- Event-Handling
- Memory-Leak-Tests (viele Create/Destroy-Zyklen)
