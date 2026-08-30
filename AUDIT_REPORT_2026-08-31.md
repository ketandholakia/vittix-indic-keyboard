# Pre-Production Audit — Vittix Indic Keyboard

- **Date:** 2026-08-31
- **Repo state audited:** `main` @ `ed19ecf7cb236d1230da10bb590148ef7c9ce9e7`
- **Scope:** Full runtime (`Keyboard/Core/KeyboardHook.pas`, `Keyboard/Core/ShreeLipi.Engine.pas`, `Keyboard/Core/EngineState.pas`, `Keyboard/Utils/SendInputHelper.pas`, `Keyboard/Layout/LayoutManager.pas`, `Keyboard/Layout/LayoutLoader.pas`, `Keyboard/Config/AppSettings.pas`, `Keyboard/Forms/frmTray.pas`, `Keyboard/Utils/Logger.pas`, `Keyboard/Utils/WinStartup.pas`), shared code (`Shared/LayoutJson.pas`, `Shared/LayoutModel.pas`, `Shared/LayoutValidation.pas`), forms (`frmSettings.pas`, `frmOnScreenKeyboard.pas`).
- **Cross-checked against:** `CHANGELOG.md`, `docs/UserGuide_EN.md`, shipped layouts in `build/Win32/layouts/`, `Tests/`.

Context: Windows low-level keyboard hook (`WH_KEYBOARD_LL`) for an Indic input method. Delphi/VCL tray app. Per-keystroke translate-and-reinject via `SendInput`.

Severity scale: **Critical** = silent user data loss / wrong output on ordinary use. **High** = intermittent or environment-dependent breakage of core workflow. **Medium** = diagnosability, configuration, or persistence defects. **Low** = robustness hardening.

---

## 1. Correctness bugs that appear only at runtime

### 1.1 CRITICAL — Pending prebase/reph state silently swallows keystrokes on the fallback path

**File:** `Keyboard/Core/ShreeLipi.Engine.pas`, `ProcessKeyChar` — fallback block (lines 153–155), and every non-direct-consonant exit path.

The hook *blocks* the physical key (`KeyboardHook.pas:273`, `Result := 1`) and hands the char to the engine. The engine's final fallback is:

```pascal
ResetEngineState;
SendUnicodeText(AKey);
```

`ResetEngineState` wipes `PendingPrebase` and `PendingReph` **without ever emitting their glyphs**. Any keystroke that entered pending state and is not followed by a direct consonant is lost entirely.

**Concrete failure scenario** (verified against shipped `build/Win32/layouts/devnagari/devanagari_unicode_gj.json` where `i` → prebase `ि`):

- User types `k` → `क` emitted. Types `i` → swallowed into `PendingPrebase` (nothing on screen). Types `Space` → fallback: `ResetEngineState` discards `ि`, sends only the space. Output: `"क "` instead of `"कि "`. The user's keystroke vanished with no error, no log line (the except path only logs exceptions).
- Same with reph: `क` + `R` (reph key) + `Enter` → the `र्` is silently discarded.

This is exactly the class of "stale buffer" bug the CHANGELOG claims was fixed (CHANGELOG line 11) — that fix cleared `KeyBuffer` on direct mapping but left the prebase/reph pending state with the identical loss path.

**Minimal fix:** in the fallback branch, before `ResetEngineState`, flush what was consumed:

```pascal
if gEngineState.PendingReph and ActiveLayout.Modifiers.TryGetValue('reph', ModRule) then
  SendUnicodeText(ModRule.Glyph);
if gEngineState.PendingPrebase <> '' then
  SendUnicodeText(gEngineState.PendingPrebase);
ResetEngineState;
SendUnicodeText(AKey);
```

---

### 1.2 CRITICAL — Every `sequences` entry in the shipped layouts is unreachable (dead feature producing wrong output)

**File:** `Keyboard/Core/ShreeLipi.Engine.pas` lines 77–130 (ordering of reph / sequence / direct checks) + shipped layout data.

For a sequence `"kS" → क्ष` to match, `KeyBuffer` must accumulate `k`,`S`. But:

1. `k` is in `DirectMap` → line 96 tries `Sequences['k']` (miss; sequences are ≥2 chars), then line 107 emits `क` and **clears the buffer** (line 126 — deliberate behavior from the earlier buffer-residue fix).
2. `S` then arrives with an empty buffer → `Sequences['S']` misses → `DirectMap['S']` emits `श`.

Net: user types `kS` expecting `क्ष`, gets `कश`. Verified all 11 sequences in `devanagari_unicode_gj.json`: every prefix char (`k,t,p,m,n,d,b,g,S,j`) is in `DirectMap`, and every sequence-final `R` is additionally shadowed by the reph rule (lines 77–84 intercept `R` before the sequence check). **No shipped sequence can ever fire.** `LayoutValidation` allows 2-char sequences and can check cross-map duplicates — but with `ACheckCrossMapDuplicates=False` by default at runtime (`LayoutLoader.pas:32`), nothing catches this.

**Concrete failure scenario:** a user types a conjunct the layout author documented as `kS`; silently gets two glyphs. This contradicts `docs/UserGuide_EN.md`'s sequence documentation and `Shared/LayoutModel.pas:48` (`k\s → क्ष`).

**Minimal fix (design decision required):** either

- (a) check `Sequences` as a *prefix* before emitting a DirectMap hit (defer emission while `KeyBuffer` is a proper prefix of any sequence, with lookahead/timeout), or
- (b) if the intended conjunct input path is halant-only (`k\ S`), delete `sequences` from the shipped layouts and remove the dead engine branch.

The current state is worse than either option because it silently produces wrong script.

---

### 1.3 HIGH — `IsModifierComboActive` uses `GetKeyState` — the exact stale-state race the changelog says was eliminated

**File:** `Keyboard/Core/KeyboardHook.pas` lines 146–153, called at line 229.

CHANGELOG line 12 documents that thread-queue key state lags inside `WH_KEYBOARD_LL` callbacks and fixed it in `VKToChar` by switching to `GetAsyncKeyState`. But the Ctrl/Alt/Win shortcut gate still uses `GetKeyState`, which reads the *calling thread's* queue state — the same lagging source.

**Concrete failure scenario:** user types `Ctrl+S` in a whitelisted app. The `VK_CONTROL` keydown went to the foreground thread's queue, not ours; `GetKeyState(VK_CONTROL)` inside the hook can report "up", so `IsModifierComboActive` returns False → the hook consumes `S` (`Result := 1`) and injects the Indic glyph instead → the app shortcut is eaten and garbage text appears. Fast typists hitting shortcuts immediately after a modifier will hit this intermittently.

**Minimal fix:** one-line consistency change — use `GetAsyncKeyState` for `VK_CONTROL/VK_MENU/VK_LWIN/VK_RWIN` in `IsModifierComboActive`, mirroring `VKToChar`.

---

### 1.4 HIGH — Buffer-overflow reset also discards up to `MAX_SEQUENCE_KEY_LEN` consumed keystrokes

**File:** `ShreeLipi.Engine.pas` lines 103–104.

```pascal
else if Length(gEngineState.KeyBuffer) > MAX_SEQUENCE_KEY_LEN - 1 then
---

### 1.5 HIGH — Unhandled exception inside the LL hook callback returns an uninitialized `Result`

**File:** `Keyboard/Core/KeyboardHook.pas` `LowLevelKeyboardProc` (lines 181–278); `ShreeLipi.Engine.pas` re-raises at line 160.

`ProcessKeyChar` wraps everything in `try/except ... raise`. If `SendUnicodeText`/`TDictionary`/memory raises during `KeyHandler(Ch)` (line 270), the exception unwinds through a `stdcall` Windows callback *before* `Result := 1` is assigned. The LRESULT returned to Windows is garbage: depending on the value, the original key may pass through *and* the reinjected glyph was already sent (doubled input), or the key is eaten; repeated faults risk Windows silently dropping the hook.

**Minimal fix:** wrap the hook body after the `nCode` check in:

```pascal
try
  // existing body
except
  on E: Exception do
  begin
    LogError('LowLevelKeyboardProc failed: ' + E.Message);
    Result := CallNextHookEx(KBHook, nCode, wParam, lParam);
  end;
end;
```

---

### 1.6 HIGH — `SendInput` failure is never checked: fail-unsafe under UIPI (elevated apps)

**File:** `Keyboard/Utils/SendInputHelper.pas` — all four procedures ignore `SendInput`'s return value; `KeyboardHook.pas` blocks the original key unconditionally (line 273).

`OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, ...)` (KeyboardHook.pas:120) succeeds against elevated processes, so `IsTargetAppActive` passes — but UIPI blocks injecting into a higher-integrity window, and `SendInput` returns 0.

**Concrete failure scenario:** user runs Notepad as Administrator (or targets any elevated app) while whitelisted → every keystroke is consumed by the hook and the reinjection is silently dropped → typing produces nothing, no error, no log. A user's workflow is destroyed silently.

**Minimal fix:** check the return of `SendInput` in `SendUnicodeText`/`SendVirtualKey`/`SendBackspace`; on 0, log once and disable interception (set engine inactive) so keys pass through natively — fail-open beats silently eating the keyboard.

---

### 1.7 MEDIUM — `ToUnicode` dead-key state corruption and unhandled `-1` return

**File:** `KeyboardHook.pas` `VKToChar` lines 87–101.

`ToUnicode` mutates the calling thread's keyboard-layout dead-key residue and returns `-1` when the key *is* a dead key. `Len < 0` is not handled (falls through to `Result := ''` → pass-through, which is fine), but the residue it leaves in *our* thread corrupts the next translation: after a user presses a dead-key chord, subsequent `VKToChar` calls can return the composed accented char instead of the layout's real mapping.

**Concrete scenario:** any user whose base keyboard layout has dead keys (e.g., `US-International` or German) types in a whitelisted app; a dead-key press is followed by wrong glyphs for the *next* unrelated key.

**Minimal fix:** call `ToUnicode` twice (first call with a scratch buffer to clear residue), or check for `Len < 0` and call `ToUnicode` a second time to reset the state.

---

### 1.8 MEDIUM — LL hook can be silently removed by Windows (LowLevelHooksTimeout)

**Files:** `KeyboardHook.pas` (per-keystroke `OpenProcess` + `GetModuleFileNameEx` + `ToUnicode` inside the callback), `frmTray.pas:158–174` (hook installed **before** `gLayoutManager.Initialize`, which does recursive `TDirectory.GetFiles` + full JSON parse/validation of every layout), `Logger.pas:80–85` (`ForceDirectories` + file open per log line).

If the hook thread doesn't service the callback within `LowLevelHooksTimeout`, Windows silently stops invoking the hook — no error anywhere.

**Scenario:** layouts folder on a network share or delayed by AV scan at startup → `Initialize` blocks for seconds → hook silently dropped → IME is dead until app restart, with zero indication. Being fail-open here is correct in principle, but the *silent* aspect means users think the app is broken.

---

## 2. Fail-safe vs fail-closed

Verified as **good** (documented intent matches behavior):

- Empty whitelist fails closed (`KeyboardHook.pas:161`), with warnings surfaced at startup (`frmTray.pas:151–157`) and on toggle (line 639). ✔ matches CHANGELOG line 4.
- No active layout → pass-through (`KeyboardHook.pas:207–210`); injected keys are never reprocessed (`KeyboardHook.pas:201`). ✔

Gaps:

### 2.1 MEDIUM — Settings silently not persisted when installed to `Program Files`

**File:** `AppSettings.pas:64` keeps `settings.ini` next to the exe. Under a normal install (an `installer/InnoSetup.iss` exists, currently empty), `WritePrivateProfileString` fails or gets virtualized; every toggle/whitelist change is lost on restart, silently.

**Fix:** store under `%APPDATA%\Vittix` (`TPath.GetHomePath`), with a migration read from the legacy exe-relative path.

### 2.2 MEDIUM — Invalid JSON produces a cryptic, wrong error

**File:** `LayoutJson.pas:142`: `TJSONObject.ParseJSONValue(...) as TJSONObject` raises `EInvalidCast` when parse returns `nil`, so the friendly `'Invalid layout JSON: ...'` at line 145 is **dead code**. Loader still rejects the file (fail-closed ✔) but the log says "Invalid class typecast", which misdirects diagnosis.

**Fix:** parse into a `TJSONValue`, nil-check, then cast.

### 2.3 LOW — Duplicate keys only guarded for `prebase`/`modifiers`

---

## 3. Resource / lifecycle

### 3.1 LOW — `Logger.WriteLine` opens/creates the file and `ForceDirectories` on every line

**File:** `Logger.pas:78–93`. `fmShareDenyNone`, no rotation. Unbounded growth over months of tray-app uptime; two instances interleave.

**Fix:** keep a persistent `TFileStream` handle, add size-based rotation.

### 3.2 LOW — `frmOnScreenKeyboard.LoadLayout` nil dereference

**File:** `frmOnScreenKeyboard.pas:52–53` dereferences `ALayout` without the nil guard used in `GetGlyphForKey`. Currently unreachable only because layout-load failure aborts startup.

### 3.3 LOW — Whitelist menu can remove but not re-add custom entries

**File:** `frmTray.pas:97–102` — `APP_CANDIDATES` is a hardcoded 4-item array; a user process toggled off via the menu cannot be toggled back on from the UI (only by editing the ini).

Ownership overall is sound: `TObjectList` ownership in `LayoutManager`, `LoadLayoutFromFile`'s `except Result.Free; raise` (`LayoutLoader.pas:40–43`), the metadata guards in `LayoutFromJson`, and `TKeyboardLayout.Destroy`'s metadata walk are all correct. No leaks found.

---

## 4. Security

### 4.1 LOW — Whitelist matches by process *filename* only, case-insensitive

**File:** `IsProcessAllowed`, `KeyboardHook.pas:155–167`: any binary named `notepad.exe` passes. Acceptable for a per-user session IME threat model, but worth documenting; consider also checking the window's trust level.

### 4.2 LOW — `ParseHotkey` accepts unmodified keys

**File:** `AppSettings.pas:165–166`: `Toggle=K` in the ini registers a *global* plain-`K` hotkey — `RegisterHotKey` succeeds and the letter K is captured system-wide, breaking typing everywhere. The settings UI's `NormalizeHotkeyInput` doesn't enforce a modifier either (`frmSettings.pas:263–291`).

**Fix:** require ≥1 modifier in `ParseHotkey` (mirroring the UI's token grammar) and add `MOD_NOREPEAT` to both `RegisterHotKey` calls (`frmTray.pas:530,552`).

### 4.3 MEDIUM — `ParseHotkey`'s F-key parsing silently fabricates keys

**File:** `AppSettings.pas:163–164`: `Part.StartsWith('F')` + `StrToIntDef(Copy(Part,2), 1)` means `"Ctrl+F"` → `Ctrl+F1` and `"Ctrl+Foo"` → `Ctrl+F1`. The UI normalizes, but hand-edited/legacy ini values bind the wrong key with no warning (the "Invalid hotkey" path won't fire).

---

## 5. Contradictions with documented intent (CHANGELOG / comments / docs)

| Document claim | Reality |
|---|---|
| CHANGELOG:11 — "direct mapping clears the buffer and the expected glyph path is preserved" | True as stated, but the same fix made **every shipped sequence unreachable** (finding 1.2). The changelog documents a symptom fix that hardened the underlying design conflict. |
| CHANGELOG:12 — modifier lag "eliminating the race" | Only in `VKToChar`; `IsModifierComboActive` still races (finding 1.3). |
| `LayoutModel.pas:48` — `Sequences: k\s → क्ष` | Sequences can't match in any shipped layout (finding 1.2). |
| `docs/UserGuide_EN.md:343` — duplicate keys "may load unpredictably" | Actually a hard reject with a cryptic message (finding 2.3) — behavior is stricter than documented. |
| `KeyboardHook.pas:207` comment — "Fail open: if no layout is active... let them through" | Correct and verified ✔ |
| `frmTray.pas:642` empty-whitelist warning text | Matches actual fail-closed-with-target behavior ✔ |

---

## Recommended fix order

1. **1.1** fallback flush (prebase/reph loss) — user-visible silent data loss on ordinary typing.
2. **1.2** decide the conjunct design (prefix-matching vs halant-only) — currently every shipped layout produces wrong script output for documented sequences.
3. **1.3** `GetAsyncKeyState` in `IsModifierComboActive` — one line, removes shortcut-eating race.
4. **1.6 + 1.5** `SendInput` result check + try/except in the hook — converts silent keyboard-eating into pass-through.
5. **1.8, 2.1, 4.3** — hook-after-init, `%APPDATA%` settings, strict hotkey parse.

## Verification notes

- BOM handling in `Shared/LayoutJson.pas` (`LoadLayoutFromFile`) was verified working: `TEncoding.Unicode.GetString` + Delphi's JSON parser tolerates the leading U+FEFF, and `Tests/Tests.Shared.LayoutJson.pas` contains UTF-16LE/UTF-8 ± BOM regression tests. Shipped file `krutidev_010.json` is UTF-16LE with BOM (`FF FE`).
- The reph design (`R` pending → glyph emitted before next direct consonant) is internally consistent for words like धर्म (`D R m` → ध र् म), which is why finding 1.2 is confined to the `sequences` map, not the reph mechanism itself.

---
