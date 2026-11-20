# Manual verification checklist (real hardware)

Automated tests cannot reproduce real-hardware keyboard timing or how target
applications consume injected input. Run this checklist on physical hardware
before releases; each section maps to the change it guards.

## Tab/Enter with a pending matra — output ORDER

Guards: the hook consumes the physical Tab/Enter and re-injects it AFTER the
committed matra/reph (previously the matra could land in the field the
Tab/Enter moved to).

Setup: engine enabled, a layout with a prebase matra active (e.g. Kruti Dev
010 or a phonetic layout), the app on the allowed list.

1. **Notepad:** type a consonant, then a prebase key (pending matra), then
   **Enter**. Expected: the matra appears at the END of the current line,
   then the caret moves to the next line. The matra must NOT appear at the
   start of the next line. Repeat with **Tab**: the matra stays in the field,
   then focus/indent moves.
2. **Corel text box:** same sequence in a text-on-path box. Expected: matra
   lands on the current text line, then the caret/focus moves. Watch for the
   matra appearing in a different frame or duplicated.
3. **Browser textarea (Chrome/Edge):** same sequence; also try Tab to move
   between two textareas. Expected: matra in textarea A, caret in textarea B.
4. **Shift+Tab with a pending matra:** hold Shift, consonant + prebase key,
   then Shift+Tab. Expected: the matra is committed in the current field AND
   focus moves BACKWARDS (Tab must not act as a forward Tab).
   Keep Shift held and type another character or use Shift+Arrow. Expected:
   capitalization/selection still works until the physical Shift release.
5. **Nothing pending:** plain Tab / Enter with no uncommitted state must
   behave exactly like native typing (no duplicated Tab/Enter, no lag).

## Injection latch + notification

Guards: the per-foreground-window re-arm and the one-time balloon.

1. Run an elevated app (e.g. Task Manager) and the tray app unelevated; type
   into the elevated app. Expected: keys pass through unchanged, one balloon
   "Typing is blocked in this app…", tray icon greyed with the hint suffix.
2. Switch to Notepad and type. Expected: translation works again; the icon
   returns to the enabled frame (no toggle/layout change needed).
3. Switch back and forth repeatedly. Expected: no balloon spam — one balloon
   per latch trip, not per keystroke.

## Watchdog (hook re-install)

Guards: silent LL-hook removal recovery.

1. Type normally and check the log has no watchdog lines.
2. Leave the machine idle >2 minutes with occasional mouse movement (no
   typing), then type. Expected: typing works; at most one "watchdog"
   re-install line in the log (a mouse-only idle window may legitimately
   trigger one).
3. Lock the workstation (Win+L), unlock, type immediately. Expected:
   translation works; log shows a "Keyboard hook restart requested" line.
4. Sleep/resume the machine, type immediately. Expected: translation works;
   log shows the restart line.

## Layout loading

1. In the Layout Editor, save a layout twice (creates `_backup\`), then
   restart the keyboard app and check the tray menu: no duplicate layout
   entry named after a backup, layout count matches the folder's real files.
