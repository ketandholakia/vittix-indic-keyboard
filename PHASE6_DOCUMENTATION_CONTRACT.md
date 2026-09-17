# Phase 6 - Documentation & User-Facing Contract Alignment

## 1. Executive Summary

The README and layout guide now describe the shipped layouts, runtime
capabilities, schema policy, LayoutEditor workflow, build entry point, and
installer contents as implemented. No runtime or validation behavior changed.

## 2. Documentation Inventory

Inspected: `README.md`, `docs/UserGuide_EN.md`, `docs/CODEBASE_ANALYSIS.md`,
`docs/DEVELOPMENT_PLAN.md`, phase reports, `LICENSE.txt`, `verify.bat`,
`verify.ps1`, and `installer/InnoSetup.iss`. The analysis and development-plan
documents retain their historical/planning material; the README and user guide
are the maintained user-facing contract.

## 3. Claim Audit

| Claim | Previous status | Evidence | Final status |
|---|---|---|---|
| Broad Indic-language support | Overstated | `layouts/**/*.json` ships Devanagari and Gujarati layouts only | Replaced with a nine-layout inventory |
| Legacy build scripts | Stale | `verify.bat`, `verify.ps1`, and `Tests/build_tests_local.bat` exist; root historical scripts do not | Replaced with current commands |
| General sequences | Ambiguous | `ShreeLipi.Engine.ProcessKeyChar` does not read `Sequences`; validation warns | Explicitly documented as compatibility-only |
| Arbitrary modifiers | Ambiguous | Runtime executes `reph` and `halant`; validation warns for other rules | Explicitly documented |
| Schema version | Missing | `LayoutModel`, `LayoutJson`, `LayoutValidation` | Documents the v1.0 policy |
| `LayoutJsonIO` path | Stale | Shared serializer is `Shared/LayoutJson.pas` | Replaced with current paths |

## 4. Supported Layouts

The README lists all nine shipped layout files: KrutiDev Devanagari 010,
ShreeLipi Devanagari 0708 and 1076, Press Custom 1, Hindi Phonetic Example,
Hindi InScript, Gujarati Remington, Gujarati Phonetic Example, and Gujarati
InScript. Their source files use Devanagari or Gujarati `script` values.

## 5. Runtime Capability Contract

Direct, prebase, postbase, `reph`, and `halant` behavior is documented as
runtime-supported. General multi-key sequences and other modifier records are
documented as legacy-compatible data, not executable typing behavior.

## 6. Schema Contract

The layout guide now states: schema `1.0` is supported; an omitted version is
treated as legacy-compatible `1.0`; an empty or unsupported declared version
is a validation error.

## 7. LayoutEditor Documentation

The guide identifies `LayoutEditor/Forms/frmEditorMain.pas` and
`Shared/LayoutJson.pas` as current paths. It documents opening/saving selected
files, shared validation, and preservation of non-grid `map_type`/metadata.

## 8. Build & Verification Documentation

The README directs developers to `verify.bat`. It accurately describes the
pipeline stages and documents `Tests/build_tests_local.bat` as the local
test-only build helper.

## 9. Installer Documentation

The README now reflects `installer/InnoSetup.iss`: keyboard and editor
applications, layouts, documentation, README, and license are installed;
Start Menu shortcuts are created and the keyboard desktop shortcut is optional.

## 10. Documentation Consistency Checks

Repository searches confirmed the edited user-facing documents contain no
`LayoutJsonIO` reference or removed root build commands. Claims were checked
against layout JSON, project files, `verify.ps1`, `InnoSetup.iss`, the engine,
and shared validation code.

## 11. Tests

```text
142 passed
0 failed
0 errors
0 leaked
```

## 12. Full Verification

```text
Verification run 1: PASS
Verification run 2: PASS
```

Both runs built tests, keyboard, and LayoutEditor; validated nine layouts;
compiled the installer; and completed the whitespace check.

## 13. Files Changed

* `README.md` - corrected user-facing layout, runtime, build, and installer claims.
* `docs/UserGuide_EN.md` - corrected schema, authoring, modifier, sequence, and current-path guidance.
* `PHASE6_DOCUMENTATION_CONTRACT.md` - this audit report.

## 14. Remaining Documentation Gaps

The historical analysis and development-plan documents intentionally retain
planning/history, including references to past build-script names. They are
not current user/developer instructions; the maintained README now directs
users to the current verification workflow.

## 15. Final Recommendation

READY FOR REVIEW
