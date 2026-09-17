# Vittix Indic Keyboard — Tray Menu & Layout Editor UI/UX Review

**Scope:** `Keyboard/Forms/frmTray.*`, `LayoutEditor/Forms/frmEditorMain.*`, `Shared/VittixKeyboardView.pas`, `LayoutEditor/UI/KeyboardPainter.pas`, plus the dialogs they launch (`frmSettings`, `frmOnScreenKeyboard`).
**Baseline reviewed:** working tree at `c27473c` + uncommitted changes.
**Stack:** Embarcadero Delphi 23.0, VCL, Win32.
**Date:** 2026-09-16

---

## 0. How to read this document

Every finding has an ID (`T-xx` tray, `E-xx` editor, `X-xx` cross-cutting), a severity, a code reference, and a fix. Severity means:

| Severity | Meaning |
|---|---|
| **P0** | Data loss, crash, or a feature that does not work as labelled. Fix before next release. |
| **P1** | Blocks or slows a core user task. Fix in the next milestone. |
| **P2** | Polish, inconsistency, or scale problem. Schedule. |
| **P3** | Nice to have. |

The three visual deliverables that accompany this document are the design intent, not decoration:

- `ui-ux-proposal/V1 Vittix Tray and Editor Redesign-Infinite Canvas.html` — the full design delivery (brief, design system, before/after screens).
- `ui-ux-proposal/V1 Vittix Tray and Editor Redesign-Interactive Prototype.html` — the clickable target design.

---

## 1. Scope, baseline and method

### What was inspected

| File | Lines | Role |
|---|---|---|
| `Keyboard/Forms/frmTray.pas` / `.dfm` | 656 / 611 | Tray icon, popup menu, layout switching, whitelist, hotkeys |
| `LayoutEditor/Forms/frmEditorMain.pas` / `.dfm` | 1659 / 1119 | Main editor window: 7 tabs, 7 sidebar panels, status bar |
| `Shared/VittixKeyboardView.pas` | 845 | Virtual keyboard control used by the editor |
| `Keyboard/Forms/frmSettings.pas` / `.dfm` | 281 / 109 | Settings dialog launched from the tray |
| `Keyboard/Forms/frmOnScreenKeyboard.pas` / `.dfm` | 114 / 72 | On-screen keyboard launched from the tray |
| `Keyboard/UI/FontReminder.pas`, `Shared/LayoutModel.pas`, `Shared/LayoutValidation.pas` | — | Supporting context |

### Method

Static reading of the VCL form definitions and their event handlers, tracing every user-visible string, control geometry, state transition and model write. Findings are tied to the code that produces them; no runtime profiling was performed (no Delphi toolchain on this machine), so performance findings are derived from call-graph analysis and are marked as such.

---

## 2. Findings at a glance

| ID | Sev | Area | Finding |
|---|---|---|---|
| **E-01** | P0 | Editor | An active search filter silently deletes every non-matching mapping on the next save |
| **E-02** | P0 | Editor | Every keystroke in a grid cell re-serialises the whole layout, rebuilds every map, and recreates the entire preview |
| **E-03** | P0 | Editor | `+ Add` buttons are drawn on top of the search fields, and drift off-panel at >100% DPI |
| **E-04** | P0 | Editor | `New Layout` and `Import Layout` discard unsaved work with no prompt |
| **E-05** | P0 | Editor | High Contrast Mode produces white-on-white text in several sidebar controls |
| **E-06** | P1 | Editor | Search blanks the Preview column and leaves its header empty |
| **E-07** | P1 | Editor | Undo pushes a snapshot per keystroke; history floods and memory is unbounded |
| **E-08** | P1 | Editor | Three competing edit surfaces (grid / inspector / quick-assign) with no single selection model |
| **E-09** | P1 | Editor | Validation is only reachable by right-clicking a grid; no menu, toolbar, or shortcut |
| **E-10** | P1 | Editor | Context-menu handlers hard-cast `Screen.ActiveControl`; `Remove Key` clears a row instead of removing it |
| **E-11** | P1 | Editor | Row status badges are painted once per column, colliding with the preview glyph |
| **E-12** | P1 | Editor | Preview glyphs are drawn at 16pt into 26px rows and are clipped |
| **E-13** | P2 | Editor | The empty-state label is covered by the page control and never visible |
| **E-14** | P2 | Editor | `Open` and `Import` do the same thing; `Sequences` is exposed but deprecated and inconsistent |
| **E-15** | P2 | Editor | Tab order, panel order and duplicated `TabOrder` values disagree |
| **E-16** | P2 | Editor | Assigning from the virtual keyboard silently shadows Prebase/Postbase mappings |
| **E-17** | P2 | Editor | Duplicate detection ignores Prebase and Modifiers and runs inside the paint loop |
| **E-18** | P2 | Editor | No visible primary action: all command buttons are 0×0 invisible holders |
| **E-19** | P2 | Editor | The `Preview` tab duplicates the `Keyboard` tab instead of previewing output |
| **T-01** | P0 | Tray | The Settings dialog is 214px tall while its content needs ~361px — the lower two thirds are unreachable |
| **T-02** | P1 | Tray | The tray icon ships only at 32×32 and encodes state by hue alone (green vs blue) |
| **T-03** | P1 | Tray | Engine state, active layout and hotkey are buried in prose rows and captions |
| **T-04** | P1 | Tray | Startup runs up to three blocking modal dialogs before the icon appears |
| **T-05** | P1 | Tray | No way to add an allowed app from the menu; the whitelist dialog is a raw multiline text box |
| **T-06** | P2 | Tray | No mnemonics on any menu item; hotkey text is baked into a caption instead of `ShortCut` |
| **T-07** | P2 | Tray | No support affordances (open layouts folder, reload layouts, open log, about) |
| **T-08** | P2 | Tray | Icon refresh is done by hiding and re-showing the icon, which flickers |
| **T-09** | P2 | Tray | Both menus are rebuilt from scratch on every popup |
| **T-10** | P3 | Tray | The on-screen keyboard shows physical keys only, never the mapped glyph |
| **X-01** | P1 | Cross | Layout precedence (Direct > Prebase > Postbase > Modifiers) is invisible in the UI |
| **X-02** | P2 | Cross | Designer is the only DPI-aware surface; the two dialogs are not |
| **X-03** | P2 | Cross | Diagnostics text is used as the status channel for four different concerns |
| **X-04** | P0 | Build | `$(ProjectDir)` is not an MSBuild reserved property, so every search path and the keyboard pre-build copy resolved to the drive root. `verify.bat` cannot complete. |

### 2.1 Fixed and verified in the current working tree

All three projects clean-rebuild and the test suite passes (149 tests, 6 new).

| ID | Change | Files |
|---|---|---|
| **X-04** | Replaced `$(ProjectDir)` with `$(MSBuildProjectDirectory)` so paths resolve under any MSBuild; the pre-build layout copy now succeeds and the keyboard project is buildable again | `Keyboard/VittixIndicKeyboard.dproj`, `LayoutEditor/VittixIndicEditor.dproj`, `Tests/VittixIndicTests.dproj` |
| **T-01** | Settings dialog rebuilt on a correct vertical rhythm; `ClientHeight` 214 to 405, controls constrained so geometry cannot drift again | `Keyboard/Forms/frmSettings.dfm` |
| **T-03** | One state line (`Engine: ON - layout name`) replaces two prose rows; tray tooltip now carries engine, layout and hotkey; double-click toggles the engine | `Keyboard/Forms/frmTray.pas` |
| **T-04** | Startup no longer blocks on modal dialogs; notices are collected and delivered as one balloon after the icon appears | `Keyboard/Forms/frmTray.pas` |
| **T-06** | Mnemonics on every menu item; the hotkey moved out of the caption into the shortcut column | `Keyboard/Forms/frmTray.dfm`, `frmTray.pas` |
| **T-08** | Icon and hint are assigned directly instead of hiding and re-showing the icon | `Keyboard/Forms/frmTray.pas` |
| **E-01** | Filtered-grid save no longer deletes hidden mappings: sync is now ownership-scoped (`SyncVisibleStringMap` / `SyncVisibleMappings`) | `LayoutEditor/Utils/LayoutMappingSync.pas`, `frmEditorMain.pas` |
| **E-04** | `ConfirmDiscardChanges` guards New, Open and Import, not just window close | `LayoutEditor/Forms/frmEditorMain.pas` |
| **E-05** | High Contrast now themes surfaces and text together, and restores the original palette on exit | `LayoutEditor/Forms/frmEditorMain.pas` |
| **E-06** | One renderer per section, shared by load and filter, so filtering can no longer blank the preview column | `LayoutEditor/Forms/frmEditorMain.pas` |
| **E-07** | Undo snapshots coalesce over 700ms instead of one per keystroke | `LayoutEditor/Forms/frmEditorMain.pas` |
| **E-10** | Context-menu commands resolve their grid safely, `Remove Key` really removes the row, Validate is nil-guarded and disabled on read-only grids | `LayoutEditor/Forms/frmEditorMain.pas` |
| **E-11** | Row status badge drawn once per row in the glyph column instead of once per cell | `LayoutEditor/Forms/frmEditorMain.pas` |
| **E-12** | Grid row height raised to 32px so 16pt preview glyphs are not clipped | `LayoutEditor/Forms/frmEditorMain.pas` |
| **E-02** | Preview rebuild debounced to a 250ms trailing timer | `LayoutEditor/Forms/frmEditorMain.pas` |
| **E-06** | Filter result count shown in the status bar (`Showing 12 of 412`) | `frmEditorMain.pas`, `frmEditorMain.dfm` |
| **E-03** | The runtime `+ Add` buttons were drawn inside the search field at every DPI (panel 612 wide, field 12 to 602, button 500 to 584). They are now DFM controls anchored to the panel's right edge, with the field anchored left and right. `AddToolbarButton` is gone. Verified: 8px gap, all controls inside their panel, at any width. | `frmEditorMain.pas`, `frmEditorMain.dfm` |
| **E-19** | The `Preview` tab drew a second copy of the mapping list as a grid of labels, which duplicated the `Keyboard` tab and freed and recreated every label on each keystroke. It is now a typing scratchpad: type on the physical keyboard and the resolved output renders in the layout font, with the source of each key listed underneath. The old builder was also the only place the virtual keyboard got its layout, which is now assigned where it belongs | `frmEditorMain.pas`, `frmEditorMain.dfm` |
| **E-09** | Validation is no longer reachable only by right-clicking a grid: new `Tools > Validate Layout` item bound to `F7` | `frmEditorMain.pas`, `frmEditorMain.dfm` |
| **E-13** | The empty state was covered by the `alClient` page control and never rendered. The page control now hides when no layout is open, so first run shows guidance instead of blank grids | `frmEditorMain.pas` |
| **E-15** | Sidebar `TabOrder` was `0,1,2,6,3,3,4` with a duplicate and a mismatch against visual order. Renumbered `0..6` to match the visual stack | `frmEditorMain.dfm` |
| **E-20** | The inspector's `+ Add` button did nothing: it derived its target grid from the sender's parent name, and `pnlMappingInspector` matched none of the branches. It now targets the selected grid, falling back to the active tab | `frmEditorMain.pas` |
| **T-02** | Tray icon: the shipped artwork is kept as-is and rebuilt at 16/20/24/32 with alpha, so the shell is never asked to resample. Resource embedded in the executable, no installer change needed | `Keyboard/Resources/vittix_on.ico`, `vittix_off.ico`, `vikicons.rc`, `vikicons.res`, `make_icons.py`, `frmTray.pas` |
| **T-11** | The tray icon never changed state. The code wrote to `TrayIcon.Icon.Handle`, but the shell is fed from the component's private `FCurrentIcon`, which only the `Icon` property setter updates. Now one loaded `TIcon` per state is assigned to the property | `Keyboard/Forms/frmTray.pas` |
| **T-12** | Allowed-app entries were persisted with the menu's auto-inserted accelerator, so `notepad.exe` was written back as `&notepad.exe`, and every toggle appended another copy. Those entries never match a real process, so interception silently stopped for them. `AutoHotkeys := maManual`, strip `&` on read, and de-duplicate | `Keyboard/Forms/frmTray.pas` |
| **X-05** | `verify.bat` cannot complete while the application is running: it rebuilds `build\Win32\VittixIndicKeyboard.exe`, and the running instance holds that file open, so MSBuild fails with MSB3061. Do not mistake this for a code failure | `verify.ps1` behaviour, no code change |
| **X-06** | The unit search path was a no-op. The projects set `DCC_SearchPath`, but the Delphi targets only read `DCC_UnitSearchPath`, so `..\Shared` was never actually on the compiler's path and Shared units resolved only through explicit references or leftover `.dcu` files. Adding a new Shared unit failed to compile until this was fixed | all three `.dproj` files |
| **X-01** | One glyph resolver. The order Direct, Prebase, Postbase, Modifiers was implemented three times, and two copies looked the modifier up by the literal name `halant` then `reph`, so any layout naming its modifier differently stopped drawing. Now `Shared/LayoutResolver.pas` is the only implementation and all three call sites use it | `Shared/LayoutResolver.pas`, `Shared/VittixKeyboardView.pas`, `LayoutEditor/UI/KeyboardPainter.pas`, `Keyboard/Forms/frmOnScreenKeyboard.pas` |
| **E-17** | Duplicate detection counted only DirectMap and PostbaseMap and re-scanned both dictionaries for every painted cell. It is now a cached index over all four sections, built once per model change | `frmEditorMain.pas` |
| **E-16** | The inspector now reports where the selected key resolves from and flags it when another section shadows it, so an edit that appears to do nothing is explained | `frmEditorMain.pas` |
| **E-14** | The deprecated `Sequences` tab is labelled `Sequences (legacy)`, and the duplicate `Open`/`Import` file intents are collapsed: `Import` and `Export` are gone from both the File menu and the command bar, leaving New, Open, Save, Save As | `frmEditorMain.dfm`, `frmEditorMain.pas` |
| **E-18** | Eight command buttons existed as 0x0 invisible holders, so the form had no visible primary action. Replaced with a real command bar: New, Open, Save, Save As, Import, Export, Undo, Redo, Validate | `frmEditorMain.dfm`, `frmEditorMain.pas` |
| **E-09** | Validation results were a modal `TTaskDialog` containing a wall of text. They now populate a Problems dock; double-clicking an entry switches to the section and selects the offending row. Zero issues means no dialog at all | `frmEditorMain.pas`, `frmEditorMain.dfm` |
| **X-03** | The diagnostics label carried selection info, assign confirmations and full validation output. It now carries one short line; the detail lives in the dock | `frmEditorMain.pas` |
| **E-08** | The keyboard tab had its own quick-assign bar editing the same Direct mapping as the grid and the inspector. Removed; the inspector is the only editing surface, the keyboard selection loads into it, and Apply creates a Direct row when the key has none | `frmEditorMain.pas`, `frmEditorMain.dfm` |
| **E-07** | Undo snapshots are capped at 50 entries; the stack previously grew without bound while storing full layout JSON | `frmEditorMain.pas` |
| **T-10** | The on-screen keyboard built 42x42 `TSpeedButton`s at hardcoded pixel positions, so it showed physical keys only, lost its layout at high DPI, and did not follow a layout change. Rebuilt on `TVittixKeyboardView`, which renders glyphs in the layout font with DPI-correct metrics, and it now refreshes when the active layout changes | `frmOnScreenKeyboard.pas`, `frmOnScreenKeyboard.dfm`, `frmTray.pas` |
| **X-02** | `frmOnScreenKeyboard` had no size constraints; it now has a 520x260 minimum. The DPI problem for that form is solved outright by T-10, since the embedded view scales itself | `frmOnScreenKeyboard.dfm` |
| **X-07** | The editor carried seven distinct greys, three font sizes and six ad-hoc text colours as DFM literals. They are now superseded at startup by one token set, `LayoutEditor/UI/EditorTheme.pas`, which assigns every surface, text colour and size. Grid rows use the canvas surface and the accent-subtle selection; section headers are small, bold, uppercase and muted; the stray 10pt labels collapse onto the body size. Leaving High Contrast re-applies this palette instead of hardcoded defaults | `LayoutEditor/UI/EditorTheme.pas`, `frmEditorMain.pas`, `frmEditorMain.dfm`, `VittixIndicEditor.dproj` |
| **T-05** | The allowed-app list could only be extended by typing into a multiline box in Settings. The menu now carries `Add application...`, which opens a file picker, takes the executable name, appends it, saves and confirms with a balloon; `Edit allowed list...` opens Settings. Both sit below a separator so they can never be mistaken for an app name, and the empty-list warning is a balloon rather than a modal | `Keyboard/Forms/frmTray.pas` |
| **T-09** | Both menus were destroyed and rebuilt item by item on every popup, which is a visible hitch with a large layout set. They are now rebuilt only when something they show has changed, with `InvalidateTrayMenus` called from every mutation site: layout switch, settings apply, layout reload, whitelist toggle and add-application. The cheap per-open state, the engine checkmark, header and tray icon, is still refreshed on every popup | `Keyboard/Forms/frmTray.pas` |
| **T-07** | The menu had no support affordances at all. Added `Open layouts folder`, `Reload layouts` (F5, re-reads the layout folder, re-arms the engine and refreshes the on-screen keyboard), `Open log folder`, and `About`, which reports the version read from the executable's own version resource, the engine state, active layout, layout count and hotkey. Startup now logs the resolved version, layouts path and log path so the support actions are verifiable without a click | `Keyboard/Forms/frmTray.pas`, `frmTray.dfm` |

Every editor item in this document is now closed. The only work left is structural: replacing the seven stacked sidebar panels with a rail plus a single inspector, which §5 describes and which is a restructure rather than a defect fix.

Every P0 finding in this document is now closed.

#### Tray icon design

The shipped artwork is kept. The glyph and both state colours come straight from
the files that already ship, and the 32px output frame is byte-identical to them
(checked on every regeneration):

| | Enabled | Disabled |
|---|---|---|
| Source | `Keyboard/icons/keyboard_on..ico` | `Keyboard/icons/keyboard_off..ico` |
| Colour | `rgb(0, 128, 0)` | `rgb(212, 0, 0)` |
| Framing | glyph inset with a margin | glyph full bleed, flush to the canvas |

The two shipped icons are framed differently, so scale is a second channel
alongside colour. That is pre-existing and was left alone.

Only the rendering and the loading changed:

1. **`TIcon.LoadFromResourceName` ignores the requested size.** A standalone probe confirmed it returns a 32x32 HICON no matter what `Width`/`Height` are set to, and the shipped files held a single 32x32 frame anyway. The notification area asks for 16px at 100% display scaling, 20px at 125% and 24px at 150%, so it was being handed a 32x32 icon to downscale every time. `LoadImage(HInstance, name, IMAGE_ICON, SM_CXSMICON, SM_CYSMICON, 0)` returns a frame at the exact requested size, and `TIcon.Handle` accepts it and takes ownership.
2. **16/20/24/32 frames are built up front**, so nothing is resampled at draw time. There is no 48px frame: the notification area never requests one and upscaling the 32px source would only add blur.
3. **A levels step keeps stroke weight consistent across sizes.** A plain downscale left the 20px and 24px frames visibly lighter than the 16px one.

Two approaches were tried and rejected, recorded so they are not retried: adding
a red diagonal to mark the disabled state, and dilating the alpha before the 16px
downscale. The dilation fused the glyph's internal gaps into a solid blob,
because the 32px source has features only a few pixels apart.

The disabled state is red rather than grey, which is the shipped choice. Red can
read as "error" rather than "off"; the tray tooltip and the menu state line both
spell the state out in words, which is the text alternative.

To replace the artwork, drop two files into `Keyboard/Resources/` and regenerate:

| File | Meaning |
|---|---|
| `tray_enabled.png` | engine on |
| `tray_disabled.png` | engine off |

`.ico` is also accepted. PNG-32 with a transparent background is preferred:
square, 256x256 or larger, glyph centred, and both files on the same canvas so
the glyph does not shift between states. The generator crops nothing, so whatever
margin the artwork carries is preserved at every size. A source of 48px or more
also produces a 48px frame. When neither file is present the generator falls back
to the shipped 32px icons, so it works before any new artwork arrives.

**Current state: supplied artwork is in use.** Both files are transparent
single-colour marks on a 256x256 canvas, which is what the tray needs:

| | Enabled | Disabled |
|---|---|---|
| Source | `tray_enabled.png`, 256x256 | `tray_disabled.png`, 256x256 |
| Colour | `rgb(0, 128, 0)` | `rgb(212, 0, 0)` |
| Opaque coverage | 18.5% | 18.5% |
| Frames produced | 16/20/24/32/48 | 16/20/24/32/48 |

Supplied artwork keeps its own colours; only the alpha channel is crispened, so
thin strokes do not wash out at 16px. Measured at 16px: 206 transparent pixels
and 50 of accent, out of 256. Ink by size is 43 / 77 / 105 / 197 / 429,
monotonic in both states.

Both states share identical geometry and differ only in colour. Green against red
is the classic confusion pair for the most common colour vision deficiency, so at
a glance the tray icon alone does not distinguish the two states for those users.
The tray tooltip and the menu state line both spell the state out in words, and
that is the current text alternative. If a shape difference is wanted later, the
cheapest option is to offset or strike the disabled mark.

For the record, the previous revision of this artwork was a dark opaque tile at
96 percent coverage. At 16px only four of its pixels were transparent, so the
rounded corners vanished and the icon rendered as a square, and the dark tile
merged into a dark taskbar. The current transparent pair does not have either
problem.

Regenerate after any mark change:

```bat
python Keyboard\Resources\make_icons.py
cd Keyboard\Resources && brcc32 -fo vikicons.res vikicons.rc
```

Preview PNGs at 8x magnification, on the light editor surface and on a dark taskbar, are in `ui-ux-proposal/`. The 16px frames could not be judged by eye in this environment, so those previews are the review artifact for the small sizes.

Minor issues noticed while wiring this up and deliberately left alone: `Keyboard/icons/keyboard_on..ico` and `keyboard_off..ico` both contain a double dot in the filename, and the DFM's `ilTrayIcons` image list still holds the older green/blue bitmap pair. That image list is now only a fallback for the case where the icon resource cannot be loaded, so it no longer decides what the user sees, but its blue "disabled" entry contradicts the red one in the shipped icons and is worth deleting when the DFM is next opened.

#### Files touched in this session

| File | What changed |
|---|---|
| `Keyboard/Forms/frmSettings.dfm` | Whole-file rebuild of the dialog geometry. Untouched at HEAD, so this diff is entirely ours. |
| `Keyboard/Forms/frmTray.pas` | Non-blocking startup, balloon `Notify`, `TrayHint`, direct icon assignment, shortcut column, status line, `OnDblClick`. |
| `Keyboard/Forms/frmTray.dfm` | Mnemonics on all items, state-line captions. |
| `LayoutEditor/Forms/frmEditorMain.pas` | Ownership-scoped sync, discard guards, high-contrast theme walk, undo and preview coalescing, per-section renderers, context-menu safety, badge and row-height fixes. |
| `LayoutEditor/Forms/frmEditorMain.dfm` | Status bar panel widened to 170 for the filter count. One line. |
| `LayoutEditor/Utils/LayoutMappingSync.pas` | `TStringMappingRow`, `SyncVisibleStringMap`, `SyncVisibleMappings`. |
| `Tests/Tests.LayoutEditor.MappingSync.pas` | Six regression tests. |
| `Keyboard/VittixIndicKeyboard.dproj`, `LayoutEditor/VittixIndicEditor.dproj`, `Tests/VittixIndicTests.dproj` | `$(ProjectDir)` to `$(MSBuildProjectDirectory)`. |
| `UI_UX_REVIEW_2026-09-16.md` | This document. |
| `ui-ux-proposal/` | Design deliverables (canvas, prototype, notes, tray icon previews). |

#### Separating this from existing uncommitted work

`git diff` against HEAD mixes two bodies of work, because the working tree already
carried roughly 50 modified and several untracked files before this session began.
Three things make the mix harder to read than it looks:

1. **`git diff` does not show untracked files.** `LayoutMappingSync.pas` and
   `Tests.LayoutEditor.MappingSync.pas` are both untracked, so the additions here
   are invisible to any diff-based review and to `git diff --check`.
2. **`frmEditorMain.pas` is the genuinely entangled file.** It carries both the
   pre-existing editor rework and this session's fixes in overlapping regions.
3. **`frmEditorMain.dfm` is almost entirely pre-existing.** 23 of its 24 diff hunks
   predate this session; the only change here is the status bar panel width.

Markers that identify this session's code by grep: `ConfirmDiscardChanges`,
`SyncVisibleStringMap`, `SyncVisibleMappings`, `RenderDirect`, `GRID_ROW_HEIGHT`,
`ApplyHighContrast`, `FDirectOwned`, `PreviewTimerTick`, `ReportFilterCount`,
`TControlSurfaceAccess`, `FStartupNotices`, `AddStartupNotice`, `TrayHint`,
`MSBuildProjectDirectory`.

A baseline for a true "ours versus yours" diff is not recoverable from the
repository: the index matches HEAD (nothing was ever staged), there is no stash,
and the IDE `__history` backups all date from March 2026, which predates the
uncommitted work. To get a clean separation next time, commit or stash first, or
let the work happen on a branch.

---

## 3. Tray menu

### 3.1 Current state

`frmTray` is a borderless, never-shown form that owns a `TTrayIcon`, a `TPopupMenu` and a 2-image `TImageList`. The menu is defined statically in the DFM and partly rebuilt at runtime:

```
DEVANAGARI                       ← miLayoutGroupHeader (disabled)
KrutiDev Devanagari 010          ← miLayoutNameHeader (disabled, Default=True for bold)
─────────
✓ Enable Keyboard                ← miEnable, caption rewritten with the hotkey in prose
─────────
Layouts ▸                        ← miLayouts, rebuilt on every popup
On-Screen Keyboard
Layout Editor...
Allowed Apps ▸                   ← rebuilt on every popup
Settings...
─────────
Exit
```

State is carried by the checkmark on `miEnable` and by the colour of the tray icon (green image 0 = enabled, blue image 1 = disabled).

### 3.2 Issues

**T-01 · P0 · The Settings dialog is clipped and unusable.**
`Keyboard/Forms/frmSettings.dfm` declares `ClientHeight = 214`, but `memAllowedApps` starts at `Top = 213` (height 68), `lblHotkeyHelp` at `Top = 291`, and `btnOK`/`btnCancel` at `Top = 336` (height 25). The dialog is roughly 147px shorter than its content: the allowed-apps box, the hotkey help text and both buttons render outside the client area. A user with a custom `settings.ini` can open Settings and has no reachable way to confirm or cancel it.
*Fix:* set `ClientHeight` to the real content extent (≈ 373) and add `Constraints.MinHeight`; then re-verify by opening the dialog at 100% and 150% scaling. Better: rebuild the dialog on a `TGridPanel`/`TStackPanel` + `Align` layout so geometry cannot drift again.

**T-02 · P1 · The tray icon is low-resolution and uses colour as the only state signal.**
`ilTrayIcons` is a single 32×32 image list with two bitmaps (`00AA00` green, `0000D4` blue). Windows asks for 16×16 or 20×20 in the notification area and downscales, so the icon is soft. Enabled and disabled differ only in hue; green-vs-blue does not read as on/off, and it fails for colour-blind users (`color.md`: never let colour alone carry state).
*Fix:* ship 16/20/24/32px frames in one image list (`Width=16, Height=16` with 32-bit alpha, or a `.ico` with multiple frames), and encode state on two channels: **shape** (filled badge vs hollow outline) plus a small accent dot; keep hue as the third, redundant channel. Add `TrayIcon.BalloonHint` for transient events.

**T-03 · P1 · The state the user opens the menu to see is rendered as prose.**
The active layout occupies two disabled rows (group in caps + name), the engine state is a checkmark, and the toggle hotkey is concatenated into a caption at runtime: `miEnable.Caption := 'Enable Keyboard (' + GAppSettings.GetToggleHotkeyText + ')'` (`frmTray.pas`, `RegisterConfiguredHotkeys`). If the hotkey is empty the caption renders `Enable Keyboard ()`. The caption is also never refreshed when the user changes the hotkey until restart.
*Fix:* one status block at the top — `Engine: ON · KrutiDev Devanagari 010` — and move the hotkey to `TMenuItem.ShortCut`, which renders right-aligned in its own column and does not pollute the label. Rebuild the status block in `PopupMenuPopup`, which already runs on every open.

**T-04 · P1 · Startup blocks on modal dialogs.**
`FormCreate` can raise three `MessageBox` calls before the icon is shown: "No allowed apps are configured", the layout-load warning (with a bounded 5-item preview), and then `RegisterConfiguredHotkeys` can raise two more for invalid or already-registered hotkeys. A tray utility that greets the user with stacked modal error boxes on login is a bad first impression, and any of them can be dismissed by an accidental keypress.
*Fix:* never block startup. Route these to `TrayIcon.BalloonHint`, and surface a persistent `⚠ N layouts failed to load` menu item that opens the log folder. Keep a modal only for a genuinely unrecoverable condition.

**T-05 · P1 · The whitelist cannot be extended from the menu.**
`APP_CANDIDATES` is a hard-coded array of four executables (`CorelDRW.exe`, `Adobe Illustrator.exe`, `WinWord.exe`, `notepad.exe`). Anything else must be typed into a multiline comma/semicolon/newline-separated box in Settings, which is then normalised back to newline-separated text (`ToggleAppWhitelistItem`).
*Fix:* add `Add application…` (a file picker that extracts the exe name and appends it) and `Edit allowed list…` (the Settings dialog). Present the list with per-row checkmarks and a one-line explanation of what the whitelist does.

**T-06 · P2 · No mnemonics, and hotkey text in captions.**
Only `miSettings` has an accelerator (`&Settings...`). `Enable Keyboard`, `Layouts`, `On-Screen Keyboard`, `Layout Editor...`, `Allowed Apps`, `Exit` have none, so the menu is not keyboard-navigable by letter. Assign `&` mnemonics to every item and keep the hotkey out of the caption (see T-03).

**T-07 · P2 · No support affordances.**
There is no way to open the layouts folder, reload layouts after editing JSON by hand, open the log folder, or see the version. `LaunchLayoutEditor` already computes `ExtractFilePath(Application.ExeName)`; the same pattern opens the folder with `ShellExecute(..., 'explore', ...)`. The log path is already resolved in `FormCreate`.
*Fix:* add a `Tools` group: `Open layouts folder`, `Reload layouts`, `Open log folder`, `About Vittix Indic Keyboard` (version, layout count, hook status, hotkey).

**T-08 · P2 · Forcing an icon refresh by hiding it.**
`UpdateTrayIcon` sets `TrayIcon.Visible := False` then `True` to force a repaint. This makes the icon blink out of the notification area on every engine toggle.
*Fix:* assign the new `Icon` and `Hint` directly; `TTrayIcon` repaints on assignment. Reserve the hide/show cycle for the initial show.

**T-09 · P2 · Both submenus are rebuilt on every popup.**
`PopupMenuPopup` calls `BuildLayoutMenu`, `BuildAppWhitelistMenu` and `UpdateLayoutHeader` every time the menu opens, destroying and recreating every `TMenuItem`. At 10 layouts this is invisible; at 60 (a realistic multi-script authoring set) it is a visible hitch on right-click.
*Fix:* invalidate a cached menu instead. Set a dirty flag from `LayoutItemClick`, `ApplyRuntimeSettings` and `ToggleAppWhitelistItem`; rebuild only when dirty.

**T-10 · P3 · The "On-Screen Keyboard" never shows the mapped glyph.**
`frmOnScreenKeyboard.BuildRow` creates 42×42 `TSpeedButton`s whose caption is the physical key only, and the glyph appears in a one-line footer after a click. It is a key-inspector, not an on-screen keyboard, and it does not refresh when the active layout changes while it is open.
*Fix:* draw the glyph in the layout font inside each key (reuse `TVittixKeyboardView` — it already does exactly this, with hit-testing, selection and DPI handling), keep the footer for the last inspected key, refresh on layout change, and make it topmost while the user is working in an app.

### 3.3 Proposed information architecture

Replace menu-as-text with menu-as-status:

```
Vittix Indic Keyboard                    ← brand row, disabled, bold
Engine: ON                              ← single state row
KrutiDev Devanagari 010 · Devanagari     ← single state row
────────────────────────────
✓  Typing enabled            Ctrl+Alt+K ← ShortCut column, not caption text
   Layouts ▸                             ← groups as separators when ≤ 12 layouts
      Devanagari
      ● KrutiDev Devanagari 010
        ShreeLipi 0708
      Gujarati
        Remington
      ─────────
      Open layouts folder…
      Reload layouts                     (F5)
   On-Screen Keyboard…
   Layout Editor…                        (opens the active layout file)
────────────────────────────
   Allowed apps ▸
      ✓ CorelDRW.exe
        Adobe Illustrator.exe
        WinWord.exe
        notepad.exe
      ─────────
      Add application…
      Edit allowed list…
────────────────────────────
   Settings…                 Ctrl+,
   Open log folder
   About Vittix Indic Keyboard
────────────────────────────
   Exit
```

Rules applied:

1. **Primary state first.** Rows 1-2 answer "is it on, and which layout" without opening anything.
2. **One decision per row.** The engine toggle is a checkbox; the layout chooser is a submenu. They are no longer mixed with utilities.
3. **Grouping by object, not by widget.** *Typing* (engine, layouts, on-screen, editor), *Scope* (allowed apps), *Application* (settings, support, exit).
4. **Destructive action isolated** at the bottom behind a separator (already correct today — keep it).
5. **Shortcuts in the shortcut column.** Never in the caption.
6. **Radios stay radios.** Every layout item keeps `RadioItem := True`; the invariant "exactly one checked" is asserted in `BuildLayoutMenu`, across all groups, not per-parent.

### 3.4 Visual and interaction spec

| Element | Spec |
|---|---|
| Menu width | 260-320px; the status block may wrap to two lines but never truncates the layout name |
| Status rows | 12px, `--fg-muted`; the value (`ON`, layout name) in `--fg`, weight 600 |
| Separators | 1px `--border-muted`, 4px vertical margin |
| Check column | 16px, reserves space so labels align whether checked or not |
| Shortcut column | right-aligned, `--fg-subtle`, 12px, tabular figures |
| Hover | `--accent-subtle` fill, `--fg` text |
| Disabled | `--fg-subtle`, no hover |
| Icon | 16px, single size in the menu; 16/20/24/32 in the notification area |
| Tooltip | `Vittix Indic Keyboard — Enabled · KrutiDev Devanagari 010 · Ctrl+Alt+K` |
| Double-click | Toggle the engine (assign `TrayIcon.OnDblClick`) |

### 3.5 Implementation notes

- Convert the commands to a `TActionList`: `actToggleEngine`, `actOpenEditor`, `actOnScreen`, `actSettings`, `actReloadLayouts`, `actOpenLayoutsFolder`, `actOpenLogFolder`, `actExit`. One place defines caption, shortcut, enablement and handler; the menu becomes thin wiring. This kills T-03, T-06 and most of T-07 at once.
- Set `miEnable.Checked := EngineEnabled` in `PopupMenuPopup` as well as after the toggle, so an external change (the global hotkey) is reflected.
- Keep the two-row status block as two `TMenuItem`s with `Enabled := False` — that is the standard VCL idiom — but drive them from one function `UpdateStatusBlock` that composes `Engine: ON|OFF`, the layout name and the group.
- Replace the `MessageBox` calls in `FormCreate` with `TrayIcon.BalloonHint` + a count badge. Keep the log as the source of truth and add `Open log folder`.
- For `Add application…`: `TOpenDialog` filtered on `*.exe`, take `ExtractFileName`, append to the normalised list, rebuild the submenu, and confirm with a balloon rather than a modal.

---

## 4. Layout editor

### 4.1 Current state

`TfrmEditorMain` is a 980×714 form with a menu bar, a `TPageControl` holding 7 tabs (Direct, Prebase, Postbase, Sequences, Modifiers, Keyboard, Preview), a 6px splitter, a 354px right sidebar in a `TScrollBox` holding 7 stacked panels, and a 4-panel status bar. Eight command buttons (`btnOpen`, `btnSave`, `btnSaveAs`, `btnNewLayout`, `btnExportLayout`, `btnImportLayout`, `btnUndo`, `btnRedo`) exist as 0×0 invisible controls used only as event holders. Four `+ Add` buttons are created at runtime inside the search panels, and the grids share one `TStringGrid`-based editing idiom.

### 4.2 Issues

**E-01 · P0 · A search filter plus a save silently deletes data.**
`edtSearchDirectChange` (and its four siblings) rewrites the grid so it contains **only the matching rows**:

```pascal
grdDirect.RowCount := Length(Filtered) + 1;
for I := 0 to High(Filtered) do begin
  grdDirect.Cells[0,I+1] := Filtered[I];
  grdDirect.Cells[1,I+1] := FLayout.DirectMap[Filtered[I]];
end;
```

`SaveUIToLayout → SyncUIToModel` then rebuilds the model **from the grid**:

```pascal
FLayout.DirectMap.Clear;
for R := grdDirect.FixedRows to grdDirect.RowCount - 1 do ... Add(Key, Glyph);
```

So: type `k` in the Direct search box, press `Ctrl+S` (or edit any cell, or change the font combo — anything that calls `SaveUIToLayout`), and every mapping whose key does not contain `k` is deleted from the layout and written to disk.
*Fix:* stop using the grid as the model. Keep the model as the single source of truth and make filtering a **view** operation (two arrays: `FVisibleRows: TArray<Integer>` mapping grid row → model index). Persist from the model, never from the visible grid. As an immediate stopgap, disable filter-driven grid rewrites and grey out editing while a filter is active — but the real fix is the view indirection.

**E-02 · P0/P1 · Every keystroke triggers a full-layout rebuild.**
`GridSetEditText` runs on `OnSetEditText`, which TStringGrid fires every time the in-place editor commits text to the cell — i.e. per keystroke:

```pascal
procedure TfrmEditorMain.GridSetEditText(...);
begin
  PushUndo;              // LayoutToJson(FLayout) — full JSON serialisation
  SaveUIToLayout;        // clear + rebuild every map, rebuild dynamic tabs
  UpdateLayoutPreview;   // free and recreate every preview TLabel
  ...
end;
```

`SyncUIToModel` alone pushes an undo snapshot, iterates six grids, calls `SyncPrebaseMappings`/`SyncModifierMappings`, and walks every dynamically-created extra-map tab. `UpdateLayoutPreview` then destroys and recreates one `TLabel` per direct mapping. On a KrutiDev-sized layout (hundreds of mappings) each typed character does this work once.
*Fix:* debounce and separate concerns. Push undo on **cell edit begin** (`OnEditingDone` / `OnSelectCell` transition) or on a 500ms idle timer, not per keystroke. Update the preview only for the edited row (`Grid.InvalidateRow`), or throttle the full rebuild. Rebuild extra-map tabs only when extra maps changed.

**E-03 · P0 · The `+ Add` buttons overlap the search fields and break at high DPI.**
`AddToolbarButton(pnlSearchDirect, '+ Add', 500, ...)` positions the button at `MulDiv(500, Screen.PixelsPerInch, 96)` with width `MulDiv(84, ...)`. In the DFM the search edit spans `Left = 12 … Right = 602` inside a 612px panel. At 96 DPI the button occupies 500-584, i.e. **inside the edit's rectangle** — the button is drawn over the field and the typed text runs underneath it. At 144 DPI the button lands at ~750px in a panel that the VCL scaled by the font ratio, not by `PixelsPerInch`, so it can end up outside the panel entirely and become invisible.
*Fix:* put search + actions in one container with `Align`-based layout (`TStackPanel`, `TGridPanel`, or `Align := alRight` on the button and `Align := alClient` on the edit with margins). Delete `AddToolbarButton` and every `MulDiv(500, …)`.

**E-04 · P0 · `New Layout` and `Import Layout` discard unsaved work.**
`FormCloseQuery` correctly prompts via `AskSaveChanges`. `btnNewLayoutClick` and `btnImportLayoutClick` both call `PushUndo` and `FreeAndNil(FLayout)` with no prompt. `btnOpenClick → OpenLayoutFile` also frees the current layout without asking. Three of four "replace the document" paths are unguarded.
*Fix:* extract `function ConfirmDiscardChanges: Boolean` and call it from all four paths (new, open, import, close). Also guard the last-undo case: announce it with a status-bar message rather than a modal.

**E-05 · P0 · High Contrast Mode makes the sidebar unreadable.**
`chkHighContrastClick` sets `Color := clBlack; Font.Color := clWhite;` on the form and recolours only `pnlDiagnostics`. Panels like `pnlLayoutInfo`, `pnlProperties`, `pnlHotkeys`, `pnlAppSettings`, `pnlMappingInspector` keep `Color = clWhite`, and any child without an explicit `Font` block (e.g. `lblInspectorGrid`, `lblInspectorKey`, `lblInspectorValue`, the inspector edits and buttons) inherits `ParentFont` from the form — white text on white panels. The accessibility feature breaks accessibility.
*Fix:* do not theme by poking the form. Define a `TTheme` record/class exposing `Surface`, `SurfaceAlt`, `Text`, `TextMuted`, `Border`, `Accent`, and have every panel and custom painter read from it. High Contrast then swaps the record and calls `ApplyTheme(Self)` recursively; `TVittixKeyboardView` already has a `HighContrastMode` property following this idea.

**E-06 · P1 · Search blanks the Preview column.**
`LoadDirect` sets `ColCount := 3` and fills `Cells[2, R]` with the glyph for a large-font preview. `edtSearchDirectChange` writes only columns 0 and 1 and sets only two headers, so as soon as the user types in the search box the Preview column empties and its header cell reverts to blank. Same for Prebase, Postbase and Sequences.
*Fix:* have one `RenderGrid(Grid, Filter)` function per section that always writes every column, including the header row. This also removes the four near-duplicate search handlers (≈ 120 lines) in favour of one parameterised implementation.

**E-07 · P1 · Undo granularity is per keystroke and memory is unbounded.**
`PushUndo` stores a full `LayoutToJson(FLayout)` string on every call, and `GridSetEditText` calls it per keystroke (see E-02). Typing a 6-character glyph creates 6 snapshots; the stack is never trimmed (`FUndoStack := TStack<string>.Create` and never bounded), so a long session holds hundreds of full layout copies.
*Fix:* snapshot on edit-begin/commit boundaries, cap the stack (e.g. 100 entries with drop-oldest), and label entries (`Undo: change "k" glyph`) so `miUndo.Caption` can become `Undo change "k" glyph`. `TAction`-based commands make the enable/disable state of Undo/Redo automatic.

**E-08 · P1 · Three surfaces edit the same mapping and none is authoritative.**
The same `DirectMap` entry can be edited from (a) the grid cell, (b) the "Selected key" inspector (`edtInspectorKey` / `edtInspectorValue` / Apply / Clear), and (c) the Keyboard tab's quick-assign bar (`edtQuickAssignValue` / Apply / Clear). The only feedback channel for all three is `lblDiagInfo` in the Diagnostics panel, whose text and background colour change ad hoc (`ShowValidationErrors` sets `pnlDiagnostics.Color := $00FFF4E0` and never restores it). The user cannot tell which surface "owns" the selection, and the three can disagree after a filter (E-06).
*Fix:* pick one. Make the **inspector** the single editing surface, fed by a single `FSelection` (grid row, keyboard key, or nothing). Remove the quick-assign bar, or reduce it to a read-only echo of the inspector. Give the inspector a state: *nothing selected* → "Select a key or row to edit"; *selected* → fields; *conflict* → warning with the winning source.

**E-09 · P1 · Validation is hidden.**
`miValidateClick` is only wired to `pmGridContext.Items[4]` — the grid right-click menu. There is no menu item, no toolbar button and no shortcut. `MainMenu1` has File, Edit and Help; Edit contains only Undo/Redo. The results arrive in a modal `TTaskDialog` with the errors as one wall of text.
*Fix:* add `Validate layout` to a `Tools`/`Layout` menu and to the command bar, bind `F7`, and report into a **Problems dock** at the bottom of the window: one row per issue, double-click to select the offending row in the correct section, a summary chip in the status bar (`0 issues` / `3 issues`). Keep the modal only for the "no layout open" case.

**E-10 · P1 · Context-menu handlers are unsafe and mislabelled.**
`miAddKeyClick`, `miRemoveKeyClick`, `miCopyClick` and `miPasteClick` all begin with `Grid := Screen.ActiveControl as TStringGrid;`. If the active control is not a grid the cast raises `EInvalidCast`. `miRemoveKeyClick` calls `Grid.Rows[Row].Clear`, which empties the row but leaves it in place — the row count never shrinks, so the grid accumulates blank rows while the label says "Remove Key".
*Fix:* pass the grid through the command (actions with a `Grid` parameter, or `pmGridContext.PopupComponent`) and never read `Screen.ActiveControl`. Implement remove as an actual row deletion (`Grid.RowCount := Grid.RowCount - 1` after shifting rows up). Also nil-check `FLayout` in `miValidateClick` before calling the validator.

**E-11 · P1 · Status badges are drawn once per column.**
`GridDrawCell` computes `Badge` (`EMPTY` / `UNMAPPED` / `DUP`) whenever `ARow >= FixedRows`, and then draws it right-aligned inside whichever cell `Rect` it is currently painting. The badge is therefore painted once per column — three times for a Direct row, four for a Modifiers row.
*Fix:* draw status into a dedicated, narrow **Status column** (or a fixed non-scrolling gutter), once per row. Remove the in-cell overlay.

**E-12 · P1 · Preview glyphs are clipped.**
`GridDrawCell` sets `Font.Size := 16` for the last column while the DFM sets `DefaultRowHeight = 26`. A 16pt Devanagari glyph needs roughly 26-30px for the em box alone, before matras; combined with E-11 the badge and the glyph also fight for the same rectangle.
*Fix:* make row height follow the preview font size (`DefaultRowHeight := Max(26, Round(FontSize * 2.2))`), recalculated when the font-size setting changes, and right-align status into its own column so it cannot collide with the glyph.

**E-13 · P2 · The empty state is invisible.**
`lblEmptyState` ("Open or create a layout to start editing") is a child of the same panel as `PageControl`, which is `Align := alClient` and declared after the label. The page control covers the label's area, so the message never renders.
*Fix:* make the empty state a first-class surface: when `FLayout = nil`, hide the page control and show a centred empty state with the layout name field disabled, a primary action (`New layout`) and a secondary (`Open layout…`). Comment the grid out of the layout or place it on a separate panel that is swapped with `Visible`.

**E-14 · P2 · Duplicate intents and a deprecated section exposed as a peer.**
`File → Open…` (`btnOpenClick` → `OpenLayoutFile`) and `File → Import Layout…` (`btnImportLayoutClick` → `LoadLayoutFromFile`) do the same thing with slightly different bookkeeping (`OpenLayoutFile` also updates the caption and status bar and resets the modified flag; Import does not). Meanwhile `Sequences` is presented as a normal tab even though `LoadSequences` documents it as read-only and deprecated, and `LayoutValidation` warns about it — yet `grdSequences` still carries `pmGridContext`, whose `Add Key` and `Paste` items will happily write into it.
*Fix:* keep one `Open layout…` command and delete Import/Export as separate file intents (or redefine Export as "save a normalised copy"). Move `Sequences` behind a `Legacy` disclosure with a one-line explanation and remove its context menu.

**E-15 · P2 · Ordering metadata disagrees.**
In `frmEditorMain.dfm` the sidebar panels stack Layout Info (0) → Metadata (185) → Hotkeys (343) → App Settings (451) → Mapping Inspector (533) → Diagnostics (703) → Accessibility (785), but their `TabOrder` values are `0, 1, 2, 6, 3, 3, 4` — `pnlMappingInspector` and `pnlDiagnostics` both claim 3, and the visual order does not match tab order. Keyboard users tab through a different sequence than they see.
*Fix:* either make the sidebar a `TStackPanel`/`TVertScrollBox` with `Align := alTop` so order is declared once, or renumber `TabOrder` to match the visual order.

**E-16 · P2 · Assignment silently shadows other maps.**
`TVittixKeyboardView.GetGlyphForKey` resolves Direct > Prebase > Postbase > Modifiers, and `AssignKey` always writes to `DirectMap`. Clicking a key that currently resolves from `PrebaseMap` and pressing Apply creates a Direct entry that permanently shadows the prebase mapping — with no warning, and no way to see the shadowed value in the grid (the Direct grid simply gains a row).
*Fix:* in the inspector, show the **resolved source** (`Direct` / `Prebase` / `Postbase` / `Modifiers / reph`) and, when assigning over a non-Direct source, show an inline note: `This key resolves from Prebase ("f" → િ). A direct entry will override it.`

**E-17 · P2 · Duplicate detection is wrong and expensive.**
`IsRealDuplicateKey` counts occurrences across `DirectMap` and `PostbaseMap` only — it ignores `PrebaseMap` and `Modifiers`, so a key present in both Direct and Prebase is not flagged, while a key in Direct and Postbase is. It also runs inside `GridDrawCell`, i.e. once per painted cell, iterating two dictionaries each time — O(cells × entries) per repaint.
*Fix:* compute a duplicate set once per model change (`FLayout.DirectMap`/`Prebase`/`Postbase`/`Modifiers` key multiset), cache it in the model layer, and look it up during paint. Align the definition with `LayoutValidation` so the editor and the validator agree.

**E-18 · P2 · No visible primary action.**
`btnOpen`, `btnSave`, `btnSaveAs`, `btnNewLayout`, `btnExportLayout`, `btnImportLayout`, `btnUndo`, `btnRedo` are all `Visible = False` with `Width = 0; Height = 0`. The only visible affordances are the menu bar and keyboard shortcuts. A first-time user sees a form with no buttons.
*Fix:* a command bar with `New`, `Open`, `Save`, `Undo`, `Redo`, `Validate`, then the layout name field, then the font-size control. Replace the hidden-button pattern with `TActionList`.

**E-19 · P2 · `Preview` duplicates `Keyboard`.**
`UpdateLayoutPreview` lays out one `TLabel` per direct mapping in a 10-column flow, showing `Key → Glyph`. The Keyboard tab already shows exactly this, at a real keyboard geometry, with selection and the layout font. The Preview tab is redundant, and it is the most expensive thing to rebuild (E-02).
*Fix:* repurpose the tab as an **Output preview**: a one-line scratchpad where the user types on a physical keyboard and sees the mapped Devanagari output stream rendered in the layout font, with the resolved source per character. That is the single most useful thing a layout author can have and it does not exist yet.

### 4.3 Proposed workspace

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ File  Edit  Layout  View  Tools  Help                                        │
├──────────────────────────────────────────────────────────────────────────────┤
│ [New] [Open] [Save]  │ [Undo] [Redo]  │ krutidev_010.json            [Validate]│
├────────────┬──────────────────────────────────────────────┬──────────────────┤
│ SECTIONS   │  Table  ○  Keyboard                          │  INSPECTOR       │
│            ├──────────────────────────────────────────────┤                  │
│ Direct 412 │ 🔍 Search mappings…            12 of 412 ⟳   │  Key     k       │
│ Prebase 38 │ ──────────────────────────────────────────── │  Output  क       │
│ Postbase 41│ Status │ Key │ Glyph │ Preview │ Kind        │  Kind    Direct  │
│ Modifiers 2│  ●     │ k   │ क     │   क     │ direct      │  Font    [preview]│
│ Sequences 8│  ●     │ kh  │ ख     │   ख     │ direct      │                  │
│ ─────────  │  ⚠     │ k   │ क     │   क     │ prebase     │  Resolves from   │
│ Keyboard   │  ○     │ z   │ (none)│         │ -           │  Direct          │
│ Output     │        │     │       │         │             │  [Apply] [Revert]│
├────────────┴──────────────────────────────────────────────┴──────────────────┤
│ PROBLEMS  ⚠ 3   "prebase f is shadowed by direct f" · "sequence key too long" │
├──────────────────────────────────────────────────────────────────────────────┤
│ Ready            krutidev_010.json    Direct 412 · Prebase 38    ✓ 0 errors   │
└──────────────────────────────────────────────────────────────────────────────┘
```

Six structural moves:

1. **Command bar replaces invisible buttons** (E-18). `TActionList` drives menu, bar and shortcuts from one declaration.
2. **Sections rail replaces the tab strip** (E-14, E-15). Each section shows a live count and an error badge; `Legacy` sections are visually demoted.
3. **One data surface with a real toolbar** (E-01, E-03, E-06, E-11, E-12): search with a result count, a Status gutter, sortable columns, column show/hide, and `Add row` in the toolbar rather than floating over the search field.
4. **Inspector is the only editor** (E-08, E-16): it follows the single selection, shows the resolved source, and warns before shadowing.
5. **Problems dock replaces the validation modal** (E-09): click an issue to jump to it; the status bar carries a persistent count.
6. **Output preview replaces the redundant tile grid** (E-19).

### 4.4 Component specs

| Component | Default | Hover | Focus | Active/selected | Disabled | Empty | Error |
|---|---|---|---|---|---|---|---|
| Command button | `--surface` fill, `--border` 1px, 6px radius | `--surface-hover` | 3px `--accent` ring | 1px translateY | `--fg-subtle` text, no border | — | — |
| Grid row | alternating `--surface` / `--surface-subtle` | `--surface-hover` | — | `--accent-subtle` fill, `--accent` left marker | `--fg-subtle` | `(none)` in italic muted | `--danger-subtle` fill |
| Status gutter | 4px dot, `--success` mapped | — | — | — | grey dot | hollow circle | `--danger` triangle |
| Search field | `--surface`, `--border` | — | `--border-accent` + 3px ring | — | `--surface-subtle` | `Search mappings…` placeholder | — |
| Result count | `12 of 412` mono, `--fg-muted` | — | — | — | — | `No matches` + clear button | — |
| Inspector field | `--surface`, label above | — | ring | — | `--surface-subtle` | `-` | red border + inline message |
| Problems row | 14px, `--danger` icon | `--surface-hover` | ring | `--accent-subtle` | — | `No problems` + green check | — |

### 4.5 Implementation notes

- **Model/view split first (E-01).** Introduce `TMappingView = record GridRow: Integer; ModelKey: string; end` arrays per section and a `RebuildView(filter)`. Every write goes `Grid → Model` through the view, never by re-deriving the model from visible cells. This one change removes the data-loss class of bugs and makes E-06, E-17 cheap to fix.
- **Debounce (E-02, E-07).** `TTimer` of 400-500ms for preview resync; `PushUndo` on edit commit; `InvalidateRow` for single-row changes.
- **Theme object (E-05).** `TTheme` + `ApplyTheme(ARoot: TWinControl)` recursive assignment; `TVittixKeyboardView.HighContrastMode` becomes a projection of the theme.
- **Layout by `Align` (E-03, E-13, E-15).** Remove absolute `Left`/`Top` for anything created at runtime. Panels use `alTop`/`alClient`, toolbars use `TStackPanel`, the empty state swaps with the page control via `Visible`.
- **`TActionList` (E-09, E-18).** Every command becomes an action with `Caption`, `ShortCut`, `OnExecute`, `OnUpdate`. `OnUpdate` sets `Enabled` from `FLayout <> nil`, selection state and dirty state — removing all the hidden 0×0 buttons.
- **Remove the 16pt/26px mismatch (E-12).** Recompute `DefaultRowHeight` from the preview font size when `ComboBoxKeyFontSize` or `ComboBoxFonts` changes.
- **Reuse `TVittixKeyboardView` for the on-screen keyboard (T-10).** It already has hit-testing, selection, keyboard navigation, DPI-safe metrics and a theme hook.

---

## 5. Shared design system

**Implemented for the editor.** The token table below now lives in
`LayoutEditor/UI/EditorTheme.pas` and is applied to the whole window at startup
by `ApplyEditorTheme`. Changing the editor's look means changing that file; the
DFM's colour literals are superseded and remain only as design-time values.
Verified by probe against the running form: form canvas `$FFFFFF` with body text
at -12, grid fill `$FFFFFF` and fixed row `$F6F8FA`, and section headers reading
`LAYOUT INFO`, `LAYOUT METADATA`, `HOTKEY CUSTOMIZATION`, `APPLICATION SETTINGS`
in `$8C959F` at -11 bold.

### 5.1 Runtime reality: a VCL style overrides most of this

Found during the visual pass, and it corrects the claim above.

The editor links `Vcl.Styles` and calls
`TStyleManager.TrySetStyle('Windows11 Modern Light')` at startup. The style is
embedded in `VittixIndicEditor.exe` (the executable carries the `VCLSTYLE`
resource type and the style name as UTF-16 resource names). The tray
executable does not embed it, so **the editor runs styled and the tray does
not**: the two surfaces do not share a look, and that is a product decision that
was never made explicitly.

Consequences for this unit:

- Under a style, `TControl.Color` and the style-dominated font properties are
  ignored for style-aware controls. Panels, labels, edits, buttons, menus and
  scroll bars are painted by the style, not by `EditorTheme`.
- What `EditorTheme` still governs is the grid, which `GridDrawCell` paints
  itself, plus caption text such as the uppercase section headers.
- `ParentBackground := False`, which the theme sets on every panel, does not opt
  a control out of styling. That requires removing `seClient` from
  `StyleElements`.

So the original finding behind X-07, nine greys hard-coded in the DFM, was
largely moot in the editor: the style was already overriding those literals. The
token set still earns its place, because it is the palette the grid uses and the
fallback when no style is loaded, but it is not the editor's whole appearance.

`EditorThemeDefault` now returns colours read from the active style when one is
loaded, and the token palette otherwise. Verified as a visual no-op, which is
the expected result and confirms that the style, not the theme, was painting
those surfaces either way.

**Not yet decided:** whether the editor should keep the style (and the theme
reduce to the grid and the fallback), be opted out of it so the token palette
applies, or have the tray adopt the same style for a consistent product. The
third option is the only one that makes both surfaces look like one product.


### 5.2 Sidebar restructure

Done, with a deliberate deviation from the sketch above.

**What changed.** The seven stacked panels became six, ordered by how often you
touch them:

| Order | Panel | Was |
|---|---|---|
| 1 | Mapping inspector | 5th |
| 2 | Layout info | 1st |
| 3 | Layout metadata | 2nd |
| 4 | Hotkey customization | 3rd |
| 5 | Application settings | 4th |
| 6 | Diagnostics | 6th |

The accessibility panel is gone; its checkbox and the Help button moved onto the
Application settings row, which was previously a mostly empty panel holding one
combo box. Tab order now matches the visual order. Verified geometry:
0-170, 170-355, 355-513, 513-621, 621-725, 725-807, contiguous with no gaps or
overlaps.

**Why the inspector moved.** It is the single editing surface, and it was fifth
of seven, so clicking a row in the grid updated a panel that was below the fold.
That was the real defect in the sidebar. It is now first and always visible.

The sidebar total is 807px against roughly 681px of viewport, so the last two
panels still scroll. That is deliberate: what sits below the fold is now the
rarely touched settings and diagnostics rather than the selection feedback.

**What was not done.** The tab strip was not replaced by a rail. Doing that means
re-parenting every grid, the virtual keyboard and the output scratchpad, and
rework of all page switching, on a form that cannot be seen while working. The
consolidation above captures the intent, one surface ordered by use, without that
risk. A rail remains a reasonable later step if the tab strip becomes the
bottleneck.

The two surfaces currently share nothing: the tray uses system defaults with `Tahoma`-era font metrics, the editor uses Segoe UI with a hand-rolled set of hex literals (`15790320`, `16316664`, `16448250`, `16053492`, `8092539`, `5592405`, `10395294`, `6710886`, `5658198`), and `TVittixKeyboardView` uses a fourth set (`$E4F6E0`, `$F8F8F8`, `clHighlight`). Nine ad-hoc greys, three accents by accident.

Adopt one token set, anchored on a dense, neutral, system-font tool aesthetic (the values below are the spec; they also appear in `ui-ux-proposal/`):

| Token | Value | Use |
|---|---|---|
| `--bg` | `#FFFFFF` | Window canvas, grids |
| `--surface` | `#F6F8FA` | Panels, toolbars, headers, inputs |
| `--surface-hover` | `#EEF2F6` | Row and button hover |
| `--surface-inset` | `#EAEEF2` | Inset wells, read-only fields |
| `--border` | `#D0D7DE` | Panel and control outline |
| `--border-muted` | `#D8DEE4` | Inner dividers |
| `--border-subtle` | `#EAEEF2` | Table row rules |
| `--fg` | `#1F2328` | Primary text |
| `--fg-muted` | `#656D76` | Secondary text, labels |
| `--fg-subtle` | `#8C959F` | Shortcut column, disabled |
| `--accent` | `#0969DA` | Focus ring, primary action, active marker |
| `--accent-hover` | `#0550AE` | Accent hover/pressed |
| `--accent-subtle` | `#DDF4FF` | Selected row, info surface |
| `--success` / `--success-subtle` | `#1A7F37` / `#DAFBE1` | Valid layout, mapped key |
| `--warning` / `--warning-subtle` | `#9A6700` / `#FFF8C5` | Deprecated section, shadowing |
| `--danger` / `--danger-subtle` | `#CF222E` / `#FFEBE9` | Validation error, empty key |
| `--font-ui` | `"Segoe UI Variable Text", "Segoe UI", system-ui, sans-serif` | Everything |
| `--font-mono` | `"Cascadia Mono", Consolas, ui-monospace, monospace` | Key names, counts, hotkeys |
| `--font-layout` | the layout's `font_family` | Glyph previews only |
| `--text-body` | 14px / 1.5 | Body, grid cells |
| `--text-small` | 12px / 1.4 | Metadata, shortcut column |
| `--text-section` | 12px, weight 600, uppercase, `0.06em` tracking | Sidebar section headers |
| `--space-1..6` | 4 / 8 / 12 / 16 / 24 / 32 | Spacing scale |
| `--radius` | 6px (controls), 8px (panels) | One radius family |
| `--focus-ring` | `0 0 0 1px #0969DA, 0 0 0 4px rgba(9,105,218,0.28)` | Every focusable control |

Notes:

- Uppercase section headers must carry `0.06em`-`0.1em` tracking — currently `LAYOUT INFO` and friends have none.
- `--accent` is used at most twice per screen (one primary action + one active marker).
- Colour never carries state alone: every status also has a shape or a text label.
- The layout font family is used **only** for glyph previews, never for UI chrome.

---

## 6. Cross-cutting engineering

**X-01 · P1 · Precedence is invisible.**
The glyph resolution order (Direct > Prebase > Postbase > Modifiers) is implemented three times (`TVittixKeyboardView.GetGlyphForKey`, `frmOnScreenKeyboard.GetGlyphForKey`, `KeyboardPainter.GetGlyphForKey`) with subtly different modifier handling — `KeyboardPainter` still hard-codes `halant`/`reph`, the other two iterate `FLayout.Modifiers`. Expose one shared resolver (e.g. `TLayoutResolver.Resolve(layout, key): TResolvedGlyph` returning value + source) in `Shared/`, use it everywhere, and surface `Source` in the inspector.

**X-02 · P2 · DPI coverage is uneven.**
`TVittixKeyboardView` scales properly via `ChangeScale` and `RecalcFitScale`. `frmEditorMain` mixes DPI-aware runtime positioning (`MulDiv`) with DFM-scaled geometry (E-03). `frmSettings` and `frmOnScreenKeyboard` have no `Constraints` and no scaling verification — and `frmSettings` does not even fit at 100% (T-01). Audit both dialogs at 100% / 150% / 200%, add `Scaled := True` checks and `Constraints.MinWidth/MinHeight`.

**X-03 · P2 · One label is four channels.**
`lblDiagInfo` carries mapping selection info (`UpdateMappingInspector`), key selection info (`vkvKeyboardKeySelect`), assign confirmations (`vkvKeyboardKeyAssign`), and full validation output (`ShowValidationErrors`, which also changes the panel colour and never restores it). Split into: a status-bar segment (transient), the inspector (selection), and the Problems dock (validation).

---

## 7. Roadmap

Ordered by risk removed per hour of work. Effort is a rough engineering estimate for one developer already familiar with the code.

### Sprint 0 — Stop the bleeding (~1-2 days)

| # | Item | Effort |
|---|---|---|
| 1 | **T-01** fix the Settings dialog height (or rebuild on `Align`) | 0.5h |
| 2 | **E-04** add `ConfirmDiscardChanges` to New / Open / Import | 1h |
| 3 | **E-01** stop persisting from the filtered grid (interim: disable editing + save while filtering) | 3h |
| 4 | **E-03** move `+ Add` into an aligned container; delete `AddToolbarButton` | 1h |
| 5 | **E-10** replace `Screen.ActiveControl as TStringGrid`; make Remove delete the row | 1.5h |
| 6 | **E-05** fix High Contrast to recolour surfaces, not just the form font | 2h |
| 7 | **T-02/T-08** multi-size tray icon, shape+colour state, no hide/show refresh | 2h |

### Sprint 1 — Make the editor trustworthy (~3-5 days)

| # | Item | Effort |
|---|---|---|
| 8 | **E-01** full model/view split with `TMappingView[]` + `RebuildView(filter)` | 1d |
| 9 | **E-02/E-07** debounce preview, undo on commit, bounded stack with labels | 1d |
| 10 | **E-18/E-09** `TActionList` + command bar + `Validate` action (`F7`) | 1d |
| 11 | **E-06/E-17** one `RenderGrid(Grid, Filter)` per section; cached duplicate set | 0.5d |
| 12 | **E-11/E-12** status gutter column; row height follows preview font size | 0.5d |
| 13 | **E-13** real empty state; **E-15** sidebar order = tab order | 0.5d |

### Sprint 2 — Make both surfaces good (~4-6 days)

| # | Item | Effort |
|---|---|---|
| 14 | **T-03/T-06/T-07** tray status block, mnemonics, `ShortCut` column, support actions | 1d |
| 15 | **T-04** balloon notifications instead of startup modals | 0.5d |
| 16 | **T-05** `Add application…` + whitelist row UI | 0.5d |
| 17 | **T-09** cached menus with invalidation | 0.5d |
| 18 | **E-08/E-16** single-selection inspector with resolved source and shadow warning | 1d |
| 19 | **E-19** Output preview scratchpad | 1d |
| 20 | **§5** apply the token set across tray, editor, dialogs | 1.5d |

### Sprint 3 — Scale and depth (~3-4 days)

| # | Item | Effort |
|---|---|---|
| 21 | **E-14** collapse Open/Import; move Sequences behind a `Legacy` disclosure | 0.5d |
| 22 | **E-09** Problems dock with jump-to-row | 1d |
| 23 | **T-10** on-screen keyboard rebuilt on `TVittixKeyboardView`, topmost, layout font | 1d |
| 24 | **X-01** shared resolver used by all three call sites | 0.5d |
| 25 | **X-02** DPI audit of both dialogs at 100/150/200% | 0.5d |
| 26 | **X-03** split the four-channel diagnostics label | 0.5d |

---

## 8. Acceptance checklist

Tray:

- [ ] Settings opens with every control visible and both buttons reachable at 100% and 150%.
- [ ] The menu answers "is it on?" and "which layout?" without opening a submenu.
- [ ] Every item has a mnemonic; the toggle hotkey renders in the shortcut column, never in the caption.
- [ ] Engine state is distinguishable without colour (shape change present).
- [ ] The tray icon is crisp at the notification-area size.
- [ ] Startup produces zero modal dialogs.
- [ ] A custom app can be whitelisted from the menu in three clicks.
- [ ] Balloon, not modal, on layout-load failure, with a menu row that opens the log.

Editor:

- [ ] With a filter active, saving never removes a non-matching mapping (regression test: filter to 1 row, save, count model entries).
- [ ] Typing a 6-character glyph performs one undo push and one preview resync.
- [ ] No runtime-created control has an absolute `Left`/`Top`.
- [ ] `New` and `Open` prompt when the document is dirty.
- [ ] High Contrast Mode is legible in every panel, verified by inspection.
- [ ] Validation is reachable from the menu, the toolbar and `F7`.
- [ ] The status gutter shows exactly one marker per row.
- [ ] Preview glyphs are not clipped at 12pt, 20pt and 32pt.
- [ ] `Remove Key` reduces the row count.
- [ ] Keyboard-only path exists for: search → select row → edit → apply → validate → save.

Shared:

- [ ] No hard-coded hex outside the theme unit.
- [ ] One `--focus-ring` on every focusable control.
- [ ] Layout font is used only for glyphs.

---

## 9. Assumptions and open questions

1. **Runtime verification not performed.** No Delphi toolchain is available in this environment, so all findings are from source analysis. E-02's latency and T-09's hitch should be confirmed with a stopwatch on a KrutiDev-sized layout.
2. **Layout scale assumption.** The performance recommendations assume layouts in the 200-800 mapping range (the shipped KrutiDev/ShreeLipi files are the largest). If real user layouts are an order of magnitude bigger, the grid itself needs virtualisation and that is a separate project.
3. **`Sequences` removal.** The plan keeps the data and hides the UI. If the format is still needed for round-tripping, it should be read-only and explicitly labelled; if not, removing the tab entirely is cleaner. Decide before Sprint 3.
4. **`Export`**, if kept, should mean "save a normalised, validated copy" rather than "save" — currently it is `SaveDialog` + `SaveLayoutToFile`, i.e. Save As with a different label.
5. **Windows 11 theming.** If Vittix is expected to follow the OS light/dark setting, the token set needs a dark variant. The current app has no dark mode; the proposed High Contrast implementation (a swappable theme record) is the right seam for adding one.

---

## Appendix A — File map

| Concern | File |
|---|---|
| Tray icon, menu, hotkeys, whitelist | `Keyboard/Forms/frmTray.pas`, `.dfm` |
| Settings dialog (T-01) | `Keyboard/Forms/frmSettings.pas`, `.dfm` |
| On-screen keyboard (T-10) | `Keyboard/Forms/frmOnScreenKeyboard.pas`, `.dfm` |
| Editor shell, grids, sidebar | `LayoutEditor/Forms/frmEditorMain.pas`, `.dfm` |
| Virtual keyboard control (reuse candidate) | `Shared/VittixKeyboardView.pas` |
| Legacy painter (superseded) | `LayoutEditor/UI/KeyboardPainter.pas` |
| Model + validation contract | `Shared/LayoutModel.pas`, `Shared/LayoutValidation.pas`, `Shared/LayoutJson.pas` |
| Settings persistence | `Keyboard/Config/AppSettings.pas` |

## Appendix B — Where the nine greys live

`frmEditorMain.dfm` and `.pas` currently hard-code `15790320`, `16316664`, `16448250`, `16053492`, `8092539`, `5592405`, `10395294`, `6710886`, `5658198`, plus `clWhite`, `clBtnFace`, `$00FFF4E0` and `$00F4F4F4`. `TVittixKeyboardView` adds `$E4F6E0` and `$F8F8F8`. `chkHighContrastClick` sets `clBlack`/`clWhite`/`clYellow`. All of these become tokens in §5.
