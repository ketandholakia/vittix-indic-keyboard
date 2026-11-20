# Dedicated hook thread — design write-up (item 3, stage b)

Status: **designed, not implemented.** Stage a (the watchdog) is implemented
and committed; this document is the structural stage b design. It was not
attempted because keeping every existing test green while the hook, its
message loop and the whole engine move to another thread requires
synchronization around every global the current tests touch synchronously —
a risk/reward trade-off the watchdog already de-risked (the worst outcome of
a stalled UI hook today is a logged, automatic re-install, not permanent
typing loss).

## Why the hook is currently on the UI thread

`WH_KEYBOARD_LL` is dispatched to the thread that installed it **via that
thread's message loop**. Today `InstallKeyboardHook` runs in
`TfrmTray.FormCreate`, so:

- every keystroke is decoded on the main/UI thread;
- any UI stall (layout reload, modal dialog, `ShellExecute`, file I/O in a
  click handler) also stalls the LL callback. Windows silently removes the
  hook when the callback exceeds its timeout (`LowLevelHooksTimeout`,
  default ~300 ms per event, cumulative removal after repeats);
- engine state (`gEngineState`, `ShreeLipi.Engine` globals,
  `KeyboardHook` policy globals) is touched from exactly one thread, so
  there is no synchronization anywhere — and none is needed today.

Stage a reduced the *consequence* of that architecture (auto re-install,
session/power restarts). Stage b removes the *cause* (UI stalls reaching the
hook at all).

## Target architecture

```
UI thread (VCL)                          Hook thread (TKeyboardHookThread)
────────────────                         ─────────────────────────────────
frmTray / frmSettings / OSK              message loop ( GetMessage )
  |  mutations only via                    |
  |  THookCommandQueue                     ├─ WM_KEY event dispatch:
  +------------------------------------->  |   DecodeKeyContext
        (PostThreadMessage)                |   HandleKeyEvent (engine)
                                           |   KeyHandler -> output
  engine/layout/settings MUTATION          |   SendInputHelper (inject)
  happens ON the hook thread, or           |
  under a single engine critical           └─ heartbeat tick (watchdog)
  section — never concurrently
```

### 1. Thread and message loop

- `TKeyboardHookThread = class(TThread)` created suspended, free-on-terminate
  **off** (explicit shutdown order), owning:
  - `InstallKeyboardHook` (runs inside Execute, before the loop);
  - a `GetMessage` loop terminated by `WM_QUIT` (or `PostThreadMessage(id, WM_QUIT)`).
- The hook handle becomes thread-local: only the hook thread installs/unhooks.
  The watchdog's `EnsureKeyboardHookInstalled`/`RestartKeyboardHook` must be
  rewritten as commands *posted to the hook thread*, never called
  cross-thread (SetWindowsHookEx from the UI thread would put the hook back
  on the UI thread — the exact bug being removed).

### 2. Marshaling mutations (the part that decides the schedule)

Every public mutator currently called from the UI thread must become a
command to the hook thread:

| Today (UI thread, synchronous)   | Stage b                                      |
|----------------------------------|----------------------------------------------|
| `SetEngineEnabled`               | posted command `cmdSetEngineEnabled`         |
| `SetActiveLayout`                | posted command `cmdSetActiveLayout`          |
| `SetAllowedProcessNames`         | posted command `cmdSetAllowedProcessNames`   |
| `SetTargetProcessName`           | posted command                               |
| `SetIgnoreInjectedInput`         | posted command                               |
| `ResetInjectionStatus`           | posted command (or engine-lock body)         |
| `ResetEngineState`               | posted command                               |
| `gLayoutManager.Initialize`      | load into a NEW list on the UI thread; hand over via command; hook thread swaps the pointer under lock |
| `EngineEnabled` / `EngineHasActiveLayout` / settings reads | read under the engine lock (cheap; no I/O) |

Command shape: `PostThreadMessage(HookThreadId, WM_APP+x, wParam, lParam)`
with small payloads carried in a pooled record, **or** — simpler and
preferred — a `TThreadedQueue<THookCommand>` (lock-free enough, built-in)
plus a `PostMessage` wake-up, because `GetMessage` blocks even when the
queue has data.

The OSK's click-to-type path (`OSKInput` → `ProcessKeyChar`) and the tray's
`HandleRawKey` are *engine calls from the UI thread*: they become posted
commands too (the OSK path is latency-tolerant; it already goes through the
same engine).

### 3. Locking discipline

One process-wide `TCriticalSection` (`gEngineLock`) guarding:
`gEngineState`, `ShreeLipi.Engine`'s `ActiveLayout`/`OnOutput`,
`KeyboardHook`'s `KeyHandler`/`Policy`/`AllowedProcessList`,
`SendInputHelper`'s `gInjectionOK`/hooks.

Rules:

- The LL callback holds the lock for the whole `HandleKeyEvent` call. That
  is acceptable *on the hook thread*: the callback must stay fast, and the
  only things that could contend are posted commands (queued, not executed
  inline) and a UI thread reader that momentarily waits.
- The UI thread takes the lock ONLY for short reads (`EngineEnabled`,
  capture-current-settings) and for command enqueue. **Never** inside a VCL
  event handler that itself calls into engine state twice (check-then-act
  must become one posted command).
- The output handler (`SetEngineOutputHandler`) runs on the hook thread in
  stage b. The production handler is pure SendInput — thread-safe. Any
  future handler that touches VCL must marshal back (PostMessage to the
  main form), enforced by convention and a comment contract on the type.

### 4. Test impact (the acceptance gate)

- All 337 tests call `HandleKeyEvent`/`ProcessKeyChar`/`SetEngineEnabled`
  synchronously. With the locking discipline above, synchronous calls from
  the test thread still work (the lock is uncontended in a single-threaded
  host) — this is precisely why every existing test can stay green.
- `InstallKeyboardHook` is never called in tests (no real hooks); the
  thread is likewise never started in tests — the seam is that
  `HandleKeyEvent` remains a plain function callable from any thread.
- New tests to add when implementing:
  - two threads hammering `HandleKeyEvent` + posted commands produce no
    state corruption (cluster/pending invariants);
  - a queued `cmdSetActiveLayout` is observed by the next `HandleKeyEvent`;
  - shutdown with pending commands does not deadlock or leak the hook.

### 5. Rollout order

1. Introduce `gEngineLock` and lock the mutators + reads. Commit (tests
   must stay green; behavior identical, single-threaded).
2. Add `TKeyboardHookThread` + command queue; move install/callback onto it;
   rewrite watchdog entries as commands. Commit.
3. Move OSK/tray raw-key paths through the queue. Commit.
4. Remove the stage-a heartbeat's UI-thread assumption: the watchdog timer
   stays on the UI thread but its restart requests become posted commands.

### 6. Known sharp edges

- `ResetInjectionStatus`/latch callback now fires on the hook thread; the
  tray balloon must marshal to the UI thread (`TThread.Synchronize` or
  PostMessage) — the current callback contract ("fired on the installing
  thread") changes.
- `LowLevelHooksTimeout` protects the hook thread too, but engine work on
  the hook thread must still avoid I/O (layout reload stays on the UI
  thread; only the pointer swap is marshaled).
- SendInput from a non-UI thread is legal (the injection tag already
  disambiguates our events).
- The DUnitX host never starts the thread, so a regression that only
  manifests with a live message loop will not be caught by the suite; the
  manual hooks-integration test (Tests/manual, item 9) is the guard.
