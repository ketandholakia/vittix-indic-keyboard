# Vittix Indic Keyboard — Development Plan

**Plan date:** 2026-08-31  
**Planning baseline:** `main` at `e02d12f`, including separately identified uncommitted work  
**Target:** Stable, testable, installable Win32 release

## 1. Objective

Deliver a production-ready version of Vittix Indic Keyboard that:

- Does not silently lose consumed user input.
- Fails open when translation or input injection cannot complete safely.
- Has automated coverage for the keyboard engine and configuration boundaries.
- Uses a layout contract consistently across runtime, editor, validation, data, and documentation.
- Persists settings and diagnostics for a standard non-administrator installation.
- Can be built, tested, packaged, installed, upgraded, and uninstalled reproducibly.

This plan prioritizes stability and release engineering over new features.

## 2. Priority definitions

| Priority | Meaning |
|---|---|
| P0 | Required to prevent input loss or establish a trustworthy baseline |
| P1 | Required for the first production release |
| P2 | Important hardening or maintainability work after the release candidate |
| P3 | Optional product enhancement |

## 3. Working rules

1. Preserve and review the current uncommitted source changes before editing the same files.
2. Make one behavior change per focused commit where practical.
3. Add a regression test with every testable defect fix.
4. Do not test core logic by installing a real global hook or sending real keystrokes.
5. Build the keyboard, editor, and tests after shared-unit changes.
6. Keep `FailsOnNoAsserts` enabled in DUnitX.
7. Treat source-controlled `layouts` as the authoritative release layout set.
8. Do not declare a phase complete until its acceptance criteria pass.

## 4. Milestone overview

| Milestone | Priority | Depends on | Outcome |
|---|---:|---|---|
| M0 — Baseline and local-work reconciliation | P0 | None | Reproducible starting point |
| M1 — Runtime correctness and fail-open hardening | P0 | M0 | No known silent input-loss path |
| M2 — Core testability and regression suite | P0/P1 | M1 design | Deterministic automated core tests |
| M3 — Layout contract alignment | P1 | M1, M2 | Runtime/editor/docs/layout agreement |
| M4 — Persistence, logging, and lifecycle | P1 | M2 | Safe installed-user operation |
| M5 — Packaging and release readiness | P1 | M1–M4 | Installable release candidate |
| M6 — Automation and quality gates | P1/P2 | M2, M5 | One-command verification/release checks |
| M7 — Post-release enhancements | P2/P3 | Production release | Product/editor improvements |

## 5. M0 — Baseline and local-work reconciliation

**Priority:** P0  
**Estimated effort:** 0.5–1 day

### M0.1 Capture the build and test baseline

Build Debug/Win32 for:

- `Tests/VittixIndicTests.dproj`
- `Keyboard/VittixIndicKeyboard.dproj`
- `LayoutEditor/VittixIndicEditor.dproj`

Run `build/Win32/VittixIndicTests.exe` and record test count, failures, and exit code.

### M0.2 Review current uncommitted work

Review the changes in:

- `Keyboard/Forms/frmTray.pas`
- `Keyboard/Layout/LayoutManager.pas`
- `Shared/LayoutValidation.pas`

Do not commit them unchanged. The layout manager implementation must first clear errors on reload and correctly report an all-invalid directory.

### M0.3 Reconcile layout inventory

Compare `layouts` with `build/Win32/layouts` and classify every generated-only layout as one of:

- Required production layout: add it to source control.
- Fixture/sample only: move it to an explicit sample/test location.
- Obsolete: exclude it from releases.

### M0 acceptance criteria

- All three baseline build results are documented.
- The current test executable has been run and its exit code captured.
- Existing local changes are preserved and understood.
- Every release layout has an identified authoritative source.

## 6. M1 — Runtime correctness and fail-open hardening

**Priority:** P0  
**Estimated effort:** 2–4 days  
**Dependency:** M0

### M1.1 Fix pending-state control-key behavior

Define a single engine policy for committing or cancelling consumed pending state. At minimum, handle pending prebase/reph followed by:

- Direct mapping
- Postbase mapping
- Halant
- Literal/Space
- Tab
- Enter
- Backspace
- Engine disable
- Layout switch

Recommended behavior: flush already-consumed visible input before committing Tab or Enter; Backspace may cancel one pending state without emitting it because the user explicitly requested deletion.

### M1.2 Harden `SendInput` result handling

Wrap the Win32 call behind an injectable function or interface.

Requirements:

- Compare the result with the exact requested input count.
- Treat partial insertion as failure.
- Aggregate down/up results for a logical operation.
- Never allow a later successful sub-call to conceal an earlier failure.
- Log only the transition into failed state to prevent flooding.
- Recover only through an explicit reset, such as engine toggle or layout activation.

### M1.3 Correct layout-manager error collection

Update the local `LoadErrors` work so initialization:

1. Clears layouts, active layout, and prior load errors.
2. Distinguishes a missing directory from an empty directory.
3. Captures malformed file errors.
4. Captures duplicate layout-ID conflicts consistently.
5. Loads valid files when invalid files are also present.
6. Raises an all-invalid error containing a representative cause.
7. Never labels an all-invalid directory as an empty directory.

Replace an unbounded startup message box with a short summary plus a bounded detail mechanism or log reference.

### M1.4 Add nil safety to on-screen keyboard loading

Make `frmOnScreenKeyboard.LoadLayout(nil)` clear or disable the view safely rather than dereferencing the layout.

### M1 acceptance criteria

- Regression tests cover every pending-state transition listed above.
- Partial or failed injection always enters fail-open state.
- A successful key-up cannot hide a failed key-down.
- Layout-manager tests pass for missing, empty, valid, mixed, duplicate-ID, all-invalid, and repeated initialization cases.
- All three Delphi projects compile.
- All tests pass.

## 7. M2 — Core testability and regression suite

**Priority:** P0/P1  
**Estimated effort:** 4–7 days  
**Dependency:** M1 behavior decisions

### M2.1 Extract a testable engine output boundary

Keep the existing engine entry point if useful, but route emitted operations through an abstraction. Tests must capture actions such as:

- Emit Unicode text
- Emit virtual key
- Emit backspace
- Reset/commit state

No test should type into the developer’s foreground application.

### M2.2 Extract hook-policy dependencies

Introduce narrow replaceable boundaries for:

- Foreground process name lookup
- Physical modifier state
- Unicode key conversion where practical
- Input injection status

Separate the decision “consume or pass through” from actual `CallNextHookEx` invocation so the policy can be unit tested.

### M2.3 Make settings paths injectable

Allow tests to construct `TAppSettings` with a temporary INI path or path provider. Avoid initialization-time writes to the real user profile during tests.

### M2.4 Add and register DUnitX fixtures

Add fixtures for:

- Engine state initialization/reset
- Engine translation and pending state
- Input injection result aggregation
- Hotkey parsing
- Process filtering
- Settings defaults, save/load, and migration
- Layout-manager behavior

Repair or replace `Tests/Tests.Keyboard.ProcessFilter.pas`. Do not merely register it: it currently relies on private implementation state and its persistence case does not perform persistence.

Update both:

- `Tests/VittixIndicTests.dpr`
- `Tests/VittixIndicTests.dproj`

### M2.5 Establish test naming and isolation rules

- Use `Given_When_Then` or the repository’s existing descriptive method style consistently.
- Use a fresh layout/state object per test.
- Use temporary directories with cleanup in `finally` or fixture teardown.
- Restore any replaceable global callback after each test.
- Do not depend on key enumeration order in dictionaries.

### M2 acceptance criteria

- Engine tests run without installing a hook or invoking real `SendInput`.
- Settings tests do not modify real application settings.
- All fixture units are registered in the DPR and DPROJ.
- Test failures produce a nonzero process exit code.
- Tests pass repeatedly and independently.
- Keyboard and editor still compile against the refactored shared/core units.

## 8. M3 — Layout contract alignment

**Priority:** P1  
**Estimated effort:** 2–4 days  
**Dependencies:** M1, M2

### M3.1 Adopt a short-term sequence policy

Recommended decision for the first production release:

- Halant-based conjunct entry is supported.
- Multi-key `sequences` are not executed by the runtime.
- Existing sequence JSON is tolerated temporarily for backward compatibility.
- Validator/editor display a clear deprecation warning.
- Documentation does not instruct users to rely on sequences.

This avoids adding delayed prefix matching to the critical input path before release.

### M3.2 Align all components

Update consistently:

- `Shared/LayoutModel.pas` comments and compatibility contract
- `Shared/LayoutValidation.pas`
- Layout editor sequence UI
- `docs/UserGuide_EN.md`
- Production layout JSON
- Real-layout tests

Decide whether the editor hides sequence editing or shows it read-only/deprecated. It must not imply runtime support.

### M3.3 Introduce layout format versioning

Add a documented schema/version field with backward-compatible loading. Define required and optional fields and supported behavior for direct, prebase, postbase, modifiers, extra maps, properties, and deprecated sequences.

### M3.4 Validate production layouts

- Remove or complete `layouts/gujarati/gopika.json`.
- Remove or complete `layouts/gujarati/shreelipi_0708.json`.
- Confirm unique layout IDs.
- Test-load every shipped layout.
- Confirm halant/reph keys and representative mappings manually in intended applications.

### M3 acceptance criteria

- Runtime, editor, validator, layouts, and English documentation state the same sequence policy.
- No shipped layout silently depends on an unsupported behavior.
- Every shipped layout is non-empty, parses, and validates.
- Every layout ID is unique.
- Compatibility behavior is covered by tests.

## 9. M4 — Persistence, logging, and lifecycle

**Priority:** P1  
**Estimated effort:** 3–5 days  
**Dependency:** M2

### M4.1 Use explicit application-data paths

Resolve settings and logs through a Windows application-data known folder rather than inferring `%APPDATA%` from a home path.

Recommended structure:

```text
%APPDATA%\Vittix\settings.ini
%LOCALAPPDATA%\Vittix\Logs\vittix-keyboard.log
```

The exact roaming/local policy must be documented.

### M4.2 Test legacy settings migration

Cover:

- No current or legacy file
- Legacy file only
- Current file already exists
- Migration copy failure
- Save and reload of every setting
- Relative and absolute layout paths

Never overwrite a current settings file with a legacy file.

### M4.3 Add bounded logging

- Create the log directory once.
- Avoid open/close and `ForceDirectories` on every log message.
- Rotate by size.
- Retain a small documented number of generations.
- Keep logger failure nonfatal.
- Avoid routine per-keystroke logging.

### M4.4 Complete whitelist management

- Keep Settings as the authoritative arbitrary process editor.
- Preserve current custom entries in tray menu behavior.
- Permit removal and re-addition without manual INI editing.
- Clearly warn when no effective target is enabled.
- Document filename-only matching as non-security filtering.

### M4.5 Review application lifecycle

- Ensure hook removal and hotkey unregistration are idempotent.
- Ensure active-layout and injection state reset together.
- Add single-instance handling or document why multiple instances are supported.
- Verify startup registration for paths containing spaces.

### M4 acceptance criteria

- Settings persist for a standard user when installed under `Program Files`.
- Legacy settings migrate exactly once without data loss.
- Logs are written to a user-writable directory and remain bounded.
- Logger failures do not stop typing or application startup.
- Custom whitelist entries can be added, removed, and restored through UI.
- Shutdown leaves no registered hotkeys or hook owned by the process.

## 10. M5 — Packaging and release readiness

**Priority:** P1  
**Estimated effort:** 3–6 days  
**Dependencies:** M1–M4

### M5.1 Complete repository-facing documents

Populate `README.md` with:

- Product purpose and screenshots if available
- Supported Windows/Delphi versions
- Build and test commands
- Installation and configuration
- Layout overview
- Known limitations
- Contribution and release guidance

Select and populate `LICENSE.txt`. Do not publish a release until the license is explicit.

### M5.2 Decide translation scope

Either complete `docs/UserGuide_Gujarati.md` and `docs/UserGuide_Hindi.md`, or remove them from the first release and track translation as a later deliverable. Do not ship empty guides.

### M5.3 Implement the Inno Setup installer

Define:

- Application identity and version
- Win32 executable and layout payload
- Optional layout editor component
- Start-menu shortcut
- Optional startup behavior coordinated with application settings
- Upgrade behavior
- Uninstall behavior
- License and documentation inclusion

### M5.4 Standardize version metadata

Set matching product/file versions in keyboard, editor, installer, and release notes. Replace generic Delphi project metadata where appropriate.

### M5.5 Validate installation scenarios

Test on a clean standard-user account:

1. Fresh install
2. First startup
3. Layout discovery
4. Settings save/reload
5. Start-with-Windows
6. Upgrade with legacy settings
7. Uninstall
8. Reinstall

Test representative targets, including an elevated target, and confirm injection failure causes native pass-through rather than missing input.

### M5 acceptance criteria

- Installer builds from source-controlled inputs without manual copying.
- All payload layouts are non-empty and validated.
- Standard-user install/configuration works under `Program Files`.
- Version and license information are present and consistent.
- Clean install, upgrade, and uninstall checklists pass.
- Release notes identify supported behavior and known limitations.

## 11. M6 — Automation and quality gates

**Priority:** P1/P2  
**Estimated effort:** 2–4 days  
**Dependencies:** M2, M5

### M6.1 Consolidate build scripts

Create one root verification script that:

1. Loads the Delphi environment.
2. Builds the DUnitX runner.
3. Runs tests and checks the exit code.
4. Builds the keyboard.
5. Builds the layout editor.
6. Runs layout/release-file validation.
7. Optionally builds the installer.

Permit Delphi and MSBuild locations to be provided by environment variables, with Studio 23.0 defaults only when appropriate.

### M6.2 Add release static checks

Fail verification when:

- A production layout or required document is empty.
- A layout cannot parse or validate.
- Layout IDs conflict.
- An installer input is missing.
- A required project does not build.
- Tests fail or no tests execute.

### M6.3 Add CI where licensing permits

Use a Windows runner with an available Delphi toolchain. If hosted automation is not possible, document the exact local release procedure and archive its output for each release.

### M6 acceptance criteria

- A single command performs the complete verification pipeline.
- Every failure returns a nonzero exit code.
- Toolchain paths are configurable.
- Release artifacts are derived only from source-controlled inputs.
- The release checklist records the verification output.

## 12. M7 — Post-release enhancements

**Priority:** P2/P3  
**Dependency:** First stable production release

Candidate backlog, in recommended order:

1. Layout editor search and filtering
2. Backup restoration UI
3. Undo/redo
4. Live output preview using the pure engine layer
5. Diagnostics panel with bounded recent events
6. Import/export workflows
7. Accessibility and high-contrast review
8. Additional scripts backed by tested layouts
9. User profiles
10. Optional full-path process matching
11. Hook performance profiling and foreground-process caching
12. A separately specified sequence-prefix engine

Sequence support must not be reintroduced without rules and tests for overlapping prefixes, fallback, timeout/commit, reph conflicts, Backspace, Enter/Tab, and layout switching.

## 13. Validation commands

Current repository scripts use Delphi Studio 23.0 and Win32. From the repository root:

```bat
build_tests.bat
build\Win32\VittixIndicTests.exe
build_test.bat
build_editor.bat
```

Because the script names are ambiguous (`build_test.bat` builds the keyboard, while `build_tests.bat` builds tests), M6 should replace them with clearer names or a single verification entry point.

For every implementation phase, also inspect:

```bat
git status --short
git diff --check
```

Manual keyboard testing must be performed only after automated tests pass and should include Notepad, the primary target application, fast Shift typing, Ctrl/Alt/Win shortcuts, dead-key keyboard layouts, layout switching, and an elevated target.

## 14. Release gate

The first production release is ready only when all of the following are true:

- [ ] Debug and Release Win32 builds succeed for tests, keyboard, and editor.
- [ ] All DUnitX tests pass with a zero exit code.
- [ ] Engine tests cover consumed pending-state transitions.
- [ ] Injection tests cover zero and partial `SendInput` results.
- [ ] No known path silently discards consumed input.
- [ ] Layout reload/error classification tests pass.
- [ ] Settings and logs work for a standard installed user.
- [ ] Runtime, editor, validator, layouts, and docs agree on sequences.
- [ ] Every shipped layout is non-empty, unique, parsed, and validated.
- [ ] README, license, English guide, and installer are complete.
- [ ] Product versions match across executable and installer metadata.
- [ ] Fresh install, upgrade, startup, and uninstall tests pass.
- [ ] Elevated-target injection failure demonstrably fails open.
- [ ] Release artifacts are generated from a clean, identified commit.

## 15. Immediate next sprint

Recommended first sprint scope:

1. **M0.1:** Run and record the current builds/tests.
2. **M1.3:** Correct the uncommitted layout-error implementation.
3. **M2.3:** Add an injectable settings path before writing settings tests.
4. **M2.4:** Add real hotkey and layout-manager tests.
5. **M2.1:** Introduce the engine output boundary.
6. **M1.1:** Fix Tab/Enter pending-state behavior with regression tests.
7. **M1.2:** Harden injection result aggregation with a fake API in tests.

The sprint is complete when all three projects compile and the expanded DUnitX suite passes. Sequence/UI/packaging work should begin only after this correctness baseline is green.