# Phase 3 — Verification Baseline Repair

## 1. Executive Summary

The seven baseline failures came from test-path handling, not from the Logger
or LayoutJson production implementations.  In the Delphi console test host,
`TPath.GetTempPath` returned an empty string despite the parent process having
valid `TEMP` and `TMP` values.  Logger test filenames therefore had no parent
directory, and the layout save test passed a filename whose `ExtractFileDir`
was empty.  The tests now fall back to the known existing current directory
only when `TPath.GetTempPath` is empty.

## 2. Initial Baseline

```text
130 tests found
123 passed
4 failed
3 errored
0 leaked
```

## 3. Logger Failures

| Test(s) | Observed | Root cause | Correction | Result |
|---|---|---|---|---|
| `ExplicitInitLogger_UsesCustomFile` | Log file absent | Relative filename with empty parent; Logger safely swallowed `ForceDirectories('')` failure | Test helper falls back to current directory | Pass |
| `EnableLoggerFalse_PreventsWriting` | File absent after re-enable | Same empty-parent filename | Same | Pass |
| `RepeatedInitLogger_UsesLastFile` | First log file absent | Same empty-parent filename | Same | Pass |
| `MultipleLogCalls_SameFile` | Log file absent | Same empty-parent filename | Same | Pass |
| `DisableThenEnable_ResumesWriting` | File-not-found read error | Same empty-parent filename | Same | Pass |
| `LogLevels_AllWork` | File-not-found read error | Same empty-parent filename | Same | Pass |

The logger's nonfatal exception policy hid the failed `ForceDirectories('')`
operation as designed.  No production logger change was justified.

## 4. LayoutJson Failure

`Tests.Shared.LayoutJson.SaveAndLoadLayoutFile_Works` raised `Path is empty`.
The test constructed a filename from empty `TPath.GetTempPath`; its result was
only a filename.  `SaveLayoutToFile` correctly calls
`TDirectory.CreateDirectory(ExtractFileDir(FileName))`, which then received
the empty string.  The new test helper uses the current directory when the
Delphi temp path is empty, giving `SaveLayoutToFile` an absolute parent path.
The test now passes.

## 5. Root-Cause Classification

All seven failures were **test infrastructure defects**: tests assumed
`TPath.GetTempPath` is nonempty in the Delphi console host.  The shell's
`TEMP`, `TMP`, and .NET temp path were populated; only the Delphi API observed
by the tests was empty.  This was not a production Logger or LayoutJson defect.

## 6. Files Changed

* `Tests/Tests.Utils.Logger.pas` — fall back to the current directory for test
  log files if Delphi returns no temp path.
* `Tests/Tests.Shared.LayoutJson.pas` — centralize temporary layout filename
  creation with the same guarded fallback.

No Phase 2 source or test behavior changed.

## 7. Phase 2 Regression Verification

All remain passing in both complete verification runs:

* `ZeroAcceptance_PassesThroughCurrentAndNextEvent`
* `PartialAcceptance_ConsumesCurrentThenFailsOpen`
* `DirectZeroAcceptance_ResetsEngineState`
* `BackspacePartialAcceptance_ResetsEngineState`
* `PendingPrelude_SuccessThenZero_IsPartialEquivalent`
* existing `Tests.Utils.SendInputHelper` tests

## 8. Final Test Results

```text
Tests found:   130
Tests passed:  130
Tests failed:  0
Tests errored: 0
Tests leaked:  0
```

## 9. Complete Verification

| Stage | Result |
|---|---|
| Tests | Pass — 130/130 |
| Keyboard build | Pass |
| LayoutEditor build | Pass |
| Layout validation | Pass — 9 unique layouts |
| Installer | Pass — Inno Setup 6.7.1 |
| Whitespace | Pass (`git diff --check`) |
| Overall | Pass |

The first attempted post-fix pipeline run reached the Keyboard build and found
a stale `VittixIndicKeyboard.exe` process locking the output file.  The stale
process was stopped, after which the two required consecutive full runs passed.

## 10. Reproducibility

```text
Complete verification run 1: PASS
Complete verification run 2: PASS
```

Both runs built the tests and applications, validated layouts, compiled the
installer, and completed the whitespace check.

## 11. Remaining Issues

The installer emits its existing deprecation/advisory warnings, but compiles
successfully.  They are outside this phase's verification-baseline scope.

## 12. Final Recommendation

READY FOR REVIEW
