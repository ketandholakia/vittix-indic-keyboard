# HookOrderTest — manual hooks integration test

An interactive Win32 VCL app that runs the WHOLE production keyboard
pipeline — real `WH_KEYBOARD_LL` hook → `HandleKeyEvent` → real engine →
real `SendInput` output — against scripted input. It exists because the
DUnitX suite replaces the Win32 boundaries with fakes (no real hooks are
installed in tests, working rule #4); this app is the real-hardware
complement. **Not part of verify.bat; never run by CI.**

## Build

```bat
:: from the repo root (loads the Delphi 23.0 environment first)
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
msbuild Tests\manual\HookOrderTest\HookOrderTest.dproj /p:Config=Debug /p:Platform=Win32
```

The exe lands in `build\Win32\HookOrderTest.exe`.

## Run

1. Launch `build\Win32\HookOrderTest.exe`. It installs the real keyboard
   hook on startup (the tray app must NOT be running at the same time — two
   translating hooks would double-process the scripted keys).
2. Click **k + i (prebase) + Enter**. The app focuses the memo, sends the
   scripted keys through `SendInput` (untagged, so the hook treats them as
   input to translate), and shows the resulting memo content in the status
   line.

## Scenarios and expected results

| Button | Scripted input | Expected |
|---|---|---|
| k + i (prebase) + Enter | `K`, `I`, `Enter` | Memo shows `KI` then a line break — the committed matra appears BEFORE the re-injected Enter, never after. |
| k + i (prebase) + Shift+Tab | `K`, `I`, `Shift+Tab` | `KI` stays in the memo AND focus moves BACKWARDS to the first button — the re-injected Tab kept its Shift. |
| plain Enter | `Enter` | Exactly one new line — native pass-through, no duplicate Enter. |
| Clear output | — | Empties the memo for the next run. |

## Why the scripted keys are translated

`SendInput` events carry no `dwExtraInfo` tag, so the hook classifies them
as foreign injected input. The app calls `SetIgnoreInjectedInput(False)` so
foreign injected input IS translated — the same switch a remote-desktop
user flips. The engine's own output stays tagged and is never reprocessed.

## Logging

The app writes to `%TEMP%\vittix-hook-order-test.log` (install/restart
events, engine errors). Combine this with `docs/MANUAL_VERIFICATION.md` for
the full pre-release hardware pass.
