# Phase 2: SendInput Failure Implementation

## 1. Summary

Phase 2 introduces a semantic injection outcome from the SendInput helper,
through `ProcessKeyChar` and the tray key handler, to `HandleKeyEvent`.  The
hook can now distinguish no output attempt, full acceptance, zero acceptance,
and partial acceptance.  No retry or target-side rollback was added.

## 2. Outcome Contract

`SendInputHelper.TInjectionOutcome` is:

```text
ioNoOutput         no synthetic input was attempted
ioSuccess          every requested INPUT record was accepted
ioZeroAccepted     an attempted batch accepted zero records
ioPartialAccepted  an attempted batch accepted some but not all records,
                   or a multi-action operation has both an accepted side
                   effect and a later failed action
```

`CombineInjectionOutcomes` is the semantic aggregation point.  It keeps the
record count private to the helper and maps a success-plus-zero sequence to
partial-equivalent because the target was already changed by the first action.

## 3. Zero-Acceptance Policy

An output procedure returns `ioZeroAccepted` after a zero `SendInput` return,
logs/latches unhealthy exactly as before, and performs no retry.  The engine
resets state before returning the outcome.  The hook returns false for this
outcome, so Windows delivers the current original physical event.  The next
eligible event observes unhealthy injection and also fails open before reaching
the engine.

## 4. Partial-Acceptance Policy

A short nonzero count returns `ioPartialAccepted`, latches unhealthy, and
resets engine state.  The hook consumes the current original event.  It never
replays that event because some synthetic input may already have reached the
target.  Future eligible events fail open.

## 5. Engine State Policy

`ProcessKeyChar` starts with `ioNoOutput`, aggregates emitted output actions,
and calls `ResetEngineState` when its final injection outcome is not
`ioSuccess`.  Thus pending prelude, current cluster, and other transient state
are deterministically cleared after zero or partial acceptance.  This is a
safe recovery state, not a claim that target-side content was rolled back.

## 6. Hook Policy

`TOnKeyChar` now returns `TInjectionOutcome`.  `HandleKeyEvent` consumes all
outcomes except `ioZeroAccepted`.  Tab and Enter aggregate engine prelude
output with their virtual-key injection; Backspace uses its engine result.
The existing injected-event, process, modifier, active-layout, enabled, and
health eligibility checks remain unchanged.

## 7. Multi-Action Aggregation

* no output + one outcome yields that outcome;
* all successful actions yield success;
* all zero-accepted actions yield zero acceptance;
* any partial action yields partial acceptance;
* success plus zero yields partial-equivalent, therefore consumed.

This specifically protects a flushed prelude that succeeds followed by a
current glyph whose batch accepts zero records.

## 8. Tests Added

* `ZeroAcceptance_PassesThroughCurrentAndNextEvent` verifies current and next
  events pass through after a zero result.
* `PartialAcceptance_ConsumesCurrentThenFailsOpen` verifies no physical-key
  fallback after one accepted Unicode down/up record and future fail-open.
* `DirectZeroAcceptance_ResetsEngineState` verifies zero outcome and reset.
* `BackspacePartialAcceptance_ResetsEngineState` verifies partial backspace
  outcome, health latch, and deterministic reset.
* `PendingPrelude_SuccessThenZero_IsPartialEquivalent` verifies multi-action
  success-plus-zero aggregation and reset.

Existing SendInput helper latch/reset/count tests remain in place.

## 9. Verification

Baseline before Phase 2: 125 found, 118 passed, 4 failed, 3 errored, 0 leaked.

After Phase 2, `verify.bat` built the test project successfully and ran:

```text
Tests found:   130
Tests passed:  123
Tests failed:  4
Tests errored: 3
Tests leaked:  0
```

The seven failures are unchanged baseline failures: six logger-file tests in
`Tests.Utils.Logger` and `Tests.Shared.LayoutJson.SaveAndLoadLayoutFile_Works`
(`Path is empty`).  No new Phase-2 test failed.  Because `verify.ps1` is
fail-fast, keyboard build, LayoutEditor build, layout validation, installer,
and whitespace stages were not reached; complete verification remains failed.

## 10. Files Changed

* `Keyboard/Utils/SendInputHelper.pas` — semantic outcomes and aggregation.
* `Keyboard/Core/ShreeLipi.Engine.pas` — output-result propagation and
  deterministic failure reset.
* `Keyboard/Core/KeyboardHook.pas` — consume/pass-through by outcome.
* `Keyboard/Forms/frmTray.pas` — returns engine outcome to hook.
* `Tests/Tests.Keyboard.HookPolicy.pas` — zero/partial current-event tests.
* `Tests/Tests.Keyboard.ProcessFilter.pas` — adapts test handler to the new
  callback contract.
* `Tests/Tests.Engine.InjectionOutcome.pas` — focused engine-state and
  multi-action tests.
* `Tests/VittixIndicTests.dpr` — registers the new test unit.

## 11. Remaining Risks

Partial target-side injection remains irreversible; the application only
prevents unsafe physical-key replay.  Engine reset makes subsequent behavior
deterministic but cannot reconstruct target text.  The repository-wide
verification failure remains unrelated and unresolved in this phase.

## 12. Final Recommendation

READY FOR REVIEW
