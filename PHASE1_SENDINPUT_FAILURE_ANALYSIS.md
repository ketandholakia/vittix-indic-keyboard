# Phase 1: SendInput Failure Semantics Analysis

## 1. Executive Summary

The current design reliably records a `SendInput` failure and fails open for
subsequent physical key events.  It does **not** protect the physical event
which caused the failure.  `HandleKeyEvent` calls the tray/engine handler,
which invokes `SendInput`, then unconditionally returns `True` and the hook
consumes the original event.  A zero-result injection therefore loses the
current physical key.  A partial result is more serious: some synthetic input
may already have reached the target, so passing through the original key would
create mixed or duplicate output.

The smallest safe direction is to introduce an explicit per-event output
result that distinguishes: (1) successful handling, (2) zero records injected,
and (3) partial records injected.  This result should cross the engine output
boundary to the hook policy.  The hook may pass through only case (2); it must
consume case (3), mark the injector unhealthy, and fail open on future events.
This is a design recommendation only; no implementation was made in Phase 1.

## 2. Verification Baseline

| Item | Result |
|---|---|
| Branch / HEAD | `main` / `c27473cd8dd696872bd8cb8d459996a4688ae4b5` |
| Worktree | Already extensively dirty before Phase 1; no existing changes were altered |
| Command | `verify.bat` |
| Test build | Passed; Delphi Win32 compiler 36.0 |
| Tests | 125 found, 118 passed, 4 failed, 3 errored, 0 leaked, 0 ignored |
| Keyboard build | Not run: pipeline stops after test failure |
| LayoutEditor build | Not run: pipeline stops after test failure |
| Layout validation | Not run |
| Installer | Not run |
| Overall exit | Failed at `verify.ps1` test-exit check |

Failures were the six logger assertions/errors in `Tests.Utils.Logger` caused
by expected files not being created, and `SaveAndLoadLayoutFile_Works` in
`Tests.Shared.LayoutJson`, which raises `Path is empty`.  These are real
baseline test failures in this run, not a missing Delphi environment: the
test project itself built under `verify.bat`, which invokes `rsvars.bat` when
needed.  The pipeline cannot presently demonstrate a reproducible complete
release verification.

`verify.ps1` builds tests, runs the executable, builds keyboard and editor,
parses all layout JSON / checks unique IDs, optionally invokes Inno Setup, and
runs `git diff --check`.  Its fail-fast test-exit check prevents all later
stages after the red test suite.

## 3. Current Event Flow

```text
Physical key down
  -> LowLevelKeyboardProc creates TKeyContext
  -> HandleKeyEvent eligibility checks
       injected? enabled? active layout? allowed foreground process?
       InjectionOK? key-down? shortcut/modifier?
  -> KeyHandler(Ch) [TfrmTray.HandleRawKey]
  -> ProcessKeyChar(Ch)
  -> EmitOutput(eoEmitText / eoEmitBackspace / eoResetState)
  -> SendUnicodeText / SendBackspace / SendVirtualKey
  -> SubmitInputs -> DoSendInput -> Win32 SendInput
  -> HandleKeyEvent sets Result := True
  -> LowLevelKeyboardProc returns 1; original physical event is consumed
```

For Tab/Enter, the handler is called first to flush/reset engine state, then
`SendVirtualKey` is called directly by `HandleKeyEvent`, and the event is also
unconditionally consumed.  Backspace invokes the engine handler and is then
unconditionally consumed.  Literal/direct keys follow the same handler path.

### Normal supported key

For a direct map, `ProcessKeyChar` resolves the glyph, flushes any pending
prelude, emits text, sets `CurrentCluster`, and returns.  `SendUnicodeText`
batches two `INPUT` records for each UTF-16 code unit.  If all records are
accepted, `InjectionOK` remains true; then the hook consumes the original key.

### Exact current failure trace

1. `HandleKeyEvent` checks `InjectionHealthy` **before** calling `KeyHandler`.
2. `KeyHandler` reaches `SubmitInputs` during the call.
3. `SubmitInputs` detects a short return and calls `MarkInjectionFailure`,
   setting `gInjectionOK := False`; it does not raise an exception and its
   Boolean result is ignored by public output procedures.
4. Control returns normally to `HandleKeyEvent`.
5. Its `Assigned(KeyHandler)` branch sets `Result := True` without inspecting
   injection status after handling.
6. `LowLevelKeyboardProc` returns `1`, so Windows does not deliver the
   original physical key to the foreground application.

Therefore the current event can be lost.  The next physical key observes
`InjectionHealthy = False` and passes through before reaching the engine.
The original failing key is not duplicated under the current policy, but a
partial `SendInput` can have emitted a prefix of synthetic output.

## 4. SendInputHelper Behavior

`SetSendInputHook` permits deterministic replacement of the Win32 call.
`SendUnicodeText`, `SendBackspace`, and `SendVirtualKey` build a full batch and
call private `SubmitInputs`.  Their public APIs return no result.  No helper
raises for a short count.  `MarkInjectionFailure` logs only on the first
healthy-to-failed transition, then latches `gInjectionOK := False`.
`ResetInjectionStatus` is the only re-arm operation; later successful calls do
not re-arm it.

| `SendInput` result | Helper result / state | Caller and keyboard event |
|---|---|---|
| `N` requested, `N` returned | `SubmitInputs=True`; health unchanged | Engine returns normally; hook consumes original event |
| `N` requested, `0` returned | `SubmitInputs=False`; one error log if previously healthy; health false | Output procedure discards Boolean; hook still consumes original event. No injected records are reported accepted, so the current physical key is lost. |
| `N` requested, `0<K<N` returned | `SubmitInputs=False`; one error log if previously healthy; health false | Hook still consumes original event. Win32 reports that a prefix of records was accepted, so the current output may be partial. |

The return count alone does not state which target-side effects occurred beyond
the accepted prefix semantics reported by `SendInput`; the application has no
rollback facility.  A batch is better than individual calls for detecting a
short submission, but does not make the submission atomic.

## 5. Failure Timing Scenarios

### A. Zero output acceptance

Direct/literal mapped key: engine has already resolved output and may already
have updated state (for example `CurrentCluster`) when `SendInput` returns
zero.  The glyph is absent, original key is consumed, health becomes false,
and the next event passes through.  Pending prelude state was already cleared
by `FlushPendingPreludes` when it was emitted, so it cannot be retried.

### B. Partial Unicode batch

For text of `L` UTF-16 code units, the batch has `2L` records.  A short count
can include complete characters, an unmatched key-down record, or a prefix of
a multi-code-unit/surrogate sequence.  The original key remains consumed.
Passing it through after this point would be unsafe: target output could become
`partial synthetic text + physical key`, with duplicate or invalid Unicode.

### C. Backspace failure

With no pending state, engine emits `eoEmitBackspace` and `eoResetState`.
`SendBackspace` can return zero/partial, while engine reset is still executed
via the output boundary.  The original Backspace is consumed.  A partial
virtual-key pair can leave target-side behavior uncertain; it must not be
blindly replayed as a physical pass-through.

### D. Pending prelude plus failure

`FlushPendingPreludes` emits and clears `PendingReph`/`PendingPrebase` before
the following glyph is emitted.  Failure may therefore lose the prelude,
following glyph, or both, while the engine no longer retains the pending
material.  Its state is internally consistent (not stale) but it cannot
recover user-visible input.

### E. Another key after failure

The next `HandleKeyEvent` exits at `InjectionHealthy`; it does not call the
engine and returns false.  The next original event reaches the foreground app
natively.  This prevents continued swallowing but does not repair the failed
event or reconcile engine state with possibly partial target text.

## 6. Policy Evaluation

### A. Current policy: consume then fail open later

Simple and avoids duplicate physical input after partial injection.  It loses
the entire current key when zero records were accepted, and can leave partial
synthetic output.  Engine state is coherent internally but not necessarily
coherent with target text.

### B. Always pass through when injection fails

Safe only when the helper can prove zero records were accepted.  It is unsafe
after a partial result because part of the synthetic result may already exist.
It cannot be the single policy for both zero and partial failures.

### C. Decide success before consuming

The hook can delay its return until synchronous `SendInput` completes, but the
engine currently performs output and state side effects while deciding output.
There is no reversible transaction around engine state or target input.
Precomputing all output would require a larger engine redesign and still cannot
undo partial `SendInput`.  This is not the smallest safe Phase-2 change.

### D. Explicit current-event injection result (recommended)

Add an outcome flowing from the SendInput boundary through the engine output
boundary and key handler, conceptually:

```text
HandledSuccessfully
HandledWithZeroAcceptance
HandledWithPartialAcceptance
PassThrough
```

At the hook boundary:

* successful: consume;
* zero acceptance: pass through the current original event, then preserve
  fail-open behavior for later events;
* partial acceptance: consume to prevent duplication/corruption, mark failed,
  and fail open on later events;
* no engine output (for example pending-prebase trigger): consume without
  calling SendInput; it is not an injection failure.

This belongs primarily at the SendInput/output boundary because only it knows
the accepted record count.  The engine should expose or accumulate the result
without learning hook policy; the hook remains owner of consume/pass-through
policy.  The tray should remain a thin adapter.  This preserves existing seams
and avoids a hook refactor.

An implementation must define multi-action aggregation.  Any partial action
means `HandledWithPartialAcceptance`.  If all attempted actions have zero
acceptance, it may be `HandledWithZeroAcceptance`; mixed zero/success actions
are target-modifying and must be treated as consumed/partial-equivalent.

## 7. Existing Coverage and Proposed Test Matrix

Existing `Tests.Utils.SendInputHelper` covers full success, zero, partial,
down/up pair counts, latching, and reset at the helper status level.
`Tests.Keyboard.HookPolicy` covers eligibility and future-event fail-open.
`Tests.Engine.OutputBoundary` and `Tests.Engine.PendingState` cover output
decisions and pending commits.  No test joins a real helper failure outcome to
the current hook consume decision.

| Test | Setup / injected result | Method under test | Expected result |
|---|---|---|---|
| Full direct output | eligible context; helper returns exact count | end-to-end policy seam | consumed; health true; text captured/accepted; engine direct state normal |
| Zero direct output | eligible context; helper returns 0 | end-to-end policy seam | explicit zero-accept outcome; health false; original key passes through; no synthetic text; engine rollback/defined reset asserted |
| Partial text batch | mapped multi-unit text; helper returns 1 or other `K<N` | end-to-end policy seam | partial outcome; health false; original key consumed; exact accepted-prefix capture asserted; no fallback key |
| Next event after failure | previous zero/partial failure | `HandleKeyEvent` | pass-through before engine; no output capture; health remains false |
| Backspace zero / partial | no pending state; helper returns 0 / 1 of 2 | engine + policy seam | outcome follows zero/partial rule; reset state asserted; no unsafe replay after partial |
| Pending prelude then zero | prebase/reph pending, next mapped glyph; helper returns 0 | engine + policy seam | defined rollback/reset behavior asserted; pending state must not silently diverge |
| Pending prelude then partial | same; helper short count | engine + policy seam | consumed partial outcome; health false; exact state reset policy asserted |
| Multi-action aggregate | prelude flush plus glyph, scripted outcomes | output-result aggregator | success only if all actions exact; any accepted side effect consumes |
| Health latch / reset | fail then successful fake, then explicit reset | helper and policy | failure remains latched until reset; reset permits a new attempt |

For tests that exercise accepted prefixes, extend the fake to retain the
submitted `TInput` records and return a controlled count.  This verifies the
modelled accepted prefix without sending real keyboard input.

## 8. Adjacent Findings Confirmed (Not Changed)

* `SyncUIToModel` clears/rebuilds prebase and modifier records with only visible
  fields, so layout editor metadata/map-type round trips remain lossy.
* `TKeyMapping` is a record owning a dictionary by convention; clear/rebuild
  paths remain ownership-sensitive.
* README still overstates supported language scope and references absent build
  scripts; the user guide retains a removed `LayoutJsonIO` reference.
* Validation accepts cross-map duplicates by default and stores but does not
  enforce schema versions; sequences remain tolerated but unsupported by engine.
* Unified verification remains non-green and therefore not reproducible as a
  complete release gate on this baseline.

## 9. Phase-1 Conclusion

No production or test changes were made.  The verified problem is not merely
historical failure tracking: current-event loss follows directly from the
unconditional `Result := True` after a synchronous handler call.  The next
phase should first specify state rollback/reset semantics for zero acceptance,
then add explicit results and the integration tests above.  It must never
blindly pass through a physical event after partial acceptance.
