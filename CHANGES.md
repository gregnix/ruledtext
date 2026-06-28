# Changes

## 1.2

- Tcl/Tk 9 support made explicit: `package require Tcl 8.6-` and
  `Tk 8.6.9-` (and `pdf4tcl 0.9-` / `ruledtext 1.2-`). Runs on Tcl/Tk
  8.6.9+ and 9.x.
- `ruledtext::pdf` now declares its Tk dependency explicitly (it uses
  `winfo`/`font` metrics) instead of relying on transitive loading.
- `preset` now fails with errorCode `{RULEDTEXT PRESET UNKNOWN}` on an
  unknown name.
- Added man page `man/mann/ruledtext.n`.
- Test suite runs on both 8.6 and 9.0; the vgrid-on-shrink test now
  pumps the event loop and passes (no longer skipped).

## 1.1

- Initial tagged release.
