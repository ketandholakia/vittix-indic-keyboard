# Vittix Indic Keyboard — Codebase Analysis

**Analysis date:** 2026-08-31  
**Repository:** `vittix-indic-keyboard`  
**Branch inspected:** `main`  
**HEAD inspected:** `e02d12f`  
**Primary platform:** Windows, Win32  
**Toolchain:** Delphi 12 Athens (Studio 23.0), VCL, DUnitX

## 1. Executive summary

Vittix Indic Keyboard is a Windows tray application that captures physical keyboard events through a low-level keyboard hook, translates them with a selected Indic layout, and emits Unicode or legacy-font text through `SendInput`. The repository also contains a VCL layout editor, shared layout model/JSON/validation units, layout data, and a DUnitX test project.

The core architecture is small and understandable, and recent commits addressed most high-severity findings from `AUDIT_REPORT_2026-08-31.md`. Important pre-production work remains:

- The most safety-critical runtime paths do not have automated tests.
- Some consumed pending engine state can still be discarded on Tab or Enter.
- `SendInput` result handling does not correctly detect partial injection and can reset a failed status after a later successful event.
- Current uncommitted layout-error reporting needs correctness fixes before it is committed.
- Runtime, editor, validation, layouts, and documentation disagree about multi-key sequences.
- Settings and logging paths require installation-context verification.
- Packaging is incomplete: the installer, README, license, two translations, and two tracked layouts are empty.

The recommended immediate goal is a stability milestone: finish the fail-open behavior, make the engine testable without a live global hook, reconcile the layout contract, and establish a reproducible build/test/release pipeline before adding features.

## 2. Repository state

At the time of analysis, local `main` was four commits ahead of `origin/main` and contained uncommitted changes in:

- `Keyboard/Forms/frmTray.pas`
- `Keyboard/Layout/LayoutManager.pas`
- `Shared/LayoutValidation.pas`

Those changes add user-visible layout load warnings and a sequence deprecation warning. They are not treated as completed work in this analysis because they have not yet been committed or fully validated.

Generated compiler files are generally ignored. One unrelated binary archive, `LayoutEditor/Forms/frmEditorMain.rar`, remains tracked and should be reviewed for removal.

## 3. Project structure

| Area | Purpose | Main files |
|---|---|---|
| Keyboard application | Tray UI, lifecycle, global hook, translation, output | `Keyboard/VittixIndicKeyboard.dpr`, `Keyboard/Forms/frmTray.pas` |
| Keyboard core | Hook callback and engine state/translation | `Keyboard/Core/KeyboardHook.pas`, `Keyboard/Core/ShreeLipi.Engine.pas`, `Keyboard/Core/EngineState.pas` |
| Layout runtime | Recursive discovery, loading, selection | `Keyboard/Layout/LayoutManager.pas`, `Keyboard/Layout/LayoutLoader.pas` |
| Configuration | INI persistence and hotkey parsing | `Keyboard/Config/AppSettings.pas` |
| Runtime utilities | Input injection, logging, Windows startup | `Keyboard/Utils/*.pas` |
| Runtime UI | Tray, settings, on-screen keyboard | `Keyboard/Forms/*.pas`, `Keyboard/UI/*.pas` |
| Shared domain | Layout object model, JSON, validation | `Shared/LayoutModel.pas`, `Shared/LayoutJson.pas`, `Shared/LayoutValidation.pas` |
| Layout editor | VCL editor, painter, backup support | `LayoutEditor/*` |
| Tests | DUnitX console runner and fixtures | `Tests/*` |
| Layout data | Production JSON layout definitions | `layouts/*` |
| Documentation | Layout author guide and translations | `docs/*` |
| Packaging | Planned Inno Setup installer | `installer/InnoSetup.iss` |

## 4. Runtime architecture and data flow

### 4.1 Startup flow

1. `VittixIndicKeyboard.dpr` sets the AppUserModelID and Per-Monitor V2 DPI awareness.
2. VCL initializes and creates the hidden tray form.
3. `TfrmTray.FormCreate` initializes logging and engine state.
4. Process filters are copied from application settings into the hook unit.
5. `TLayoutManager.Initialize` recursively finds and parses layout JSON files.
6. The configured or first layout is activated in the engine.
7. Tray menus are built.
8. The low-level hook is installed after layout initialization.
9. Configured global hotkeys are registered.

Installing the hook after layout parsing is an important recent correction: lengthy startup I/O no longer risks causing Windows to remove the hook under `LowLevelHooksTimeout` before normal operation begins.

### 4.2 Keystroke flow

1. Windows invokes `LowLevelKeyboardProc` for keyboard events.
2. Injected events are ignored to prevent recursion.
3. Disabled-engine, missing-layout, disallowed-process, modifier-combination, and failed-injection states pass through to the next hook.
4. Tab, Enter, and Backspace receive explicit handling.
5. Other virtual keys are converted through `ToUnicode` using physical modifier state.
6. `ProcessKeyChar` applies layout rules in this order:
   - Backspace/control behavior
   - Reph trigger
   - Prebase trigger
   - Direct mapping
   - Postbase mapping
   - Halant trigger
   - Literal fallback
7. Output helpers reinject Unicode or virtual-key events with `SendInput`.
8. Injected events return through the hook and are passed through without reprocessing.

### 4.3 Layout flow

1. `TLayoutManager` discovers every `*.json` file under the configured path.
2. `LayoutLoader` delegates parsing to the shared JSON layer.
3. JSON is converted into `TKeyboardLayout` and its maps.
4. Shared validation rejects invalid required data and malformed mappings.
5. Layout IDs are used for default selection and persistence.
6. The same shared model and JSON code are used by the layout editor.

This shared domain layer is a strength: fixes to parsing and validation can apply to both applications. Its contract must, however, match actual runtime capabilities.

## 5. Strengths

- Clear separation between layout data, engine state, hook handling, and VCL forms.
- Shared model, parser, and validator reduce runtime/editor drift.
- Layout ownership is generally correct through owning collections and protected construction.
- Hook behavior usually fails open when the engine is disabled, no layout is active, the process is not allowed, or injection is known to be unavailable.
- Injected-event filtering prevents recursive translation.
- Recent fixes addressed silent pending-state loss on ordinary fallback paths, modifier races, hook exception escape, malformed JSON diagnostics, duplicate JSON keys, and unsafe hotkey parsing.
- Layout JSON encoding tests include UTF-8/UTF-16 and BOM variants.
- DUnitX runner returns CI-compatible exit codes and enables `FailsOnNoAsserts`.

## 6. Correctness and reliability findings

### 6.1 Pending state on Tab and Enter

`ProcessKeyChar` resets engine state for Tab and Enter without first flushing a consumed pending prebase matra or reph. The original audit finding about pending-state loss is therefore substantially fixed but not completely closed.

The intended behavior must be defined and covered for pending state followed by:

- Direct output
- Postbase output
- Halant
- Literal/Space
- Tab
- Enter
- Backspace
- Engine disable
- Layout change

### 6.2 Input-injection result handling

`SendInputHelper.pas` checks whether some calls return zero, but the Win32 API returns the number of inserted events. Correct success requires the return value to equal the requested count.

Current risks include:

- A partial batched insertion is treated as success.
- A failed key-down can be followed by a successful key-up that restores `gInjectionOK` to `True`.
- A failure can therefore be concealed before the hook makes its next fail-open decision.

The result must be accumulated for an entire logical output operation and reset only through an explicit recovery action.

### 6.3 Layout-manager error reporting in the working tree

The uncommitted `LoadErrors` implementation has several issues:

- The collection is not cleared at the start of a reload.
- `FirstLoadError` is declared and tested but is no longer assigned.
- A directory containing JSON files where every file is invalid can be reported as if it contained no layout files.
- Duplicate layout IDs are logged but not represented consistently in the warning collection.
- A message box containing all failures may be unusable for a large directory.

Error reporting should distinguish missing directory, empty directory, all-invalid files, mixed valid/invalid files, and duplicate IDs.

### 6.4 Process filtering

Allowed applications are matched by executable filename, case-insensitively. This is adequate as a user convenience filter but not as a security boundary because an unrelated executable can use an allowed filename. The limitation should be documented. Optional full-path matching can be considered later.

### 6.5 Hook performance

The hook performs foreground-process discovery and key translation synchronously. This is normal for the current design, but the callback must remain very small because Windows may silently remove slow low-level hooks. Logging and other disk I/O must never be added to the normal per-key path without careful profiling.

## 7. Configuration and lifecycle findings

### 7.1 Settings location

The implementation states that settings are stored under `%APPDATA%\Vittix`, but constructs the directory with `TPath.GetHomePath`. The resulting location must be verified on supported Windows versions. Prefer an explicit roaming or local application-data known folder and test it through an injectable path resolver.

### 7.2 Logging location and rotation

The tray form currently places logs beside the executable under `logs`. A normal installation under `Program Files` may not permit this. Logging also opens/creates the file for every line and has no rotation, creating performance and unbounded-growth risks.

Logs should move to a per-user application-data directory with bounded rotation and a lifecycle-managed stream or writer.

### 7.3 On-screen keyboard safety

`frmOnScreenKeyboard.LoadLayout` should tolerate `nil`. Startup currently tends to prevent this state, but UI code should not depend on an indirect lifecycle guarantee.

### 7.4 Whitelist editing

The tray menu is based on a fixed candidate list. A custom process removed from the list cannot necessarily be restored through that menu. Settings should remain the authoritative place for arbitrary process entries, and tray behavior should preserve/manage current custom entries.

## 8. Layout-contract mismatch

The runtime sequence path was removed because direct mappings emitted and cleared their prefix before a sequence could complete, and reph rules introduced further conflicts. Halant-based conjunct entry is now the effective runtime behavior.

Other repository areas still expose or recommend sequences:

- `Shared/LayoutModel.pas` retains the sequence map.
- `Shared/LayoutValidation.pas` validates sequence length and content.
- The layout editor exposes sequence editing.
- `docs/UserGuide_EN.md` recommends sequences for conjuncts.
- Shipped layout files contain sequence sections.

Short-term recommendation: formally deprecate sequence execution, retain tolerant parsing for compatibility, warn in editor/validation, and remove claims that the runtime executes sequences. A future sequence engine should be a separately designed feature with explicit prefix, timeout, fallback, reph-conflict, and backspace rules.

## 9. Test assessment

### 9.1 Existing automated coverage

The registered DUnitX suite covers:

- Shared layout model behavior
- JSON loading and malformed/duplicate input
- Shared validation
- Loading real layouts
- Logger basics

### 9.2 Missing critical coverage

There are no registered automated tests for:

- Engine translation and pending-state transitions
- Hook decision/filter logic
- `SendInput` failure and partial-success behavior
- Hotkey parsing
- Settings migration and actual persistence
- Layout-manager reload and error classification
- Startup/shutdown sequencing
- Layout editor workflows

`Tests/Tests.Keyboard.ProcessFilter.pas` exists but is not registered by the test project. It also references implementation-private state and contains a persistence test that only assigns fields in memory. It should be redesigned rather than simply enabled.

### 9.3 Testability constraint

Core units directly call Win32 APIs and use module-level globals. Tests should not install a system-wide hook or inject real keystrokes. Small interfaces or callbacks are needed around output injection, modifier lookup, foreground-process lookup, and settings paths so core decisions can be exercised deterministically.

## 10. Build and automation assessment

The repository contains separate batch files for keyboard, editor, and test builds. They hardcode Delphi Studio `23.0` and the .NET Framework MSBuild location. There is no single verification command and no confirmed CI workflow.

Recommended improvements:

- Consolidate the repeated environment setup.
- Permit toolchain paths to be supplied through environment variables.
- Add one script that builds tests, runs them, builds both applications, and optionally builds the installer.
- Fail immediately on a nonzero build or test exit code.
- Add checks for empty production files and invalid/duplicate layouts.

## 11. Documentation and packaging assessment

The following tracked production-facing files are empty:

- `README.md`
- `LICENSE.txt`
- `installer/InnoSetup.iss`
- `docs/UserGuide_Gujarati.md`
- `docs/UserGuide_Hindi.md`
- `layouts/gujarati/gopika.json`
- `layouts/gujarati/shreelipi_0708.json`

The ignored `build/Win32/layouts` directory also contains layouts not present in the tracked source layout directory. Release contents must be generated from a single authoritative, source-controlled layout set.

Until the installer, license, source layout inventory, version metadata, and clean-install validation are complete, the project should be treated as pre-production.

## 12. Risk register

| Risk | Impact | Likelihood | Priority | Required mitigation |
|---|---|---:|---:|---|
| Consumed pending state lost on control-key path | User input loss | Medium | P0 | Define behavior and add engine regression tests |
| Partial/overwritten injection failure | Silent missing or malformed output | Medium | P0 | Exact-count injection wrapper and fail-open tests |
| Core runtime has little automated coverage | Regression in primary product behavior | High | P0 | Extract testable boundaries and add DUnitX fixtures |
| Invalid-layout reporting is incorrect across reloads | Misleading startup/reconfiguration failures | High | P0 | Correct local implementation and test scenarios |
| Sequence contract differs across components | Wrong user expectations and invalid layouts | High | P1 | Formal deprecation or separately designed implementation |
| Settings/log paths fail after installation | Lost configuration/diagnostics | Medium | P1 | Known-folder paths and installation tests |
| Empty/mismatched release files | Broken or legally incomplete distribution | High | P1 | Complete packaging inventory and release gate |
| Filename-only whitelist mistaken for security | Unexpected process interception | Low | P2 | Document limitation; optionally support full paths |

## 13. Recommended architectural direction

Avoid a large rewrite. Introduce narrow seams around existing code:

1. A pure engine decision layer that consumes keys and returns output actions/state changes.
2. An output adapter that converts those actions to `SendInput` calls.
3. A hook policy layer for pass-through versus consume decisions.
4. Injected services for foreground process, modifier state, settings directory, and logging destination.
5. Shared layout validation as the authoritative contract used by runtime, editor, tests, and release checks.

This retains the current VCL and Delphi architecture while enabling deterministic unit tests and reducing Win32 side effects in business logic.

## 14. Conclusion

The repository has a viable foundation and recent safety improvements, but the primary keyboard behavior is still protected mostly by manual testing. The next development milestone should focus on correctness, testability, contract alignment, and packaging—not new editor or keyboard features. Detailed execution phases and acceptance gates are defined in `docs/DEVELOPMENT_PLAN.md`.