unit KeyboardHook;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.StrUtils,
  System.SysUtils,
  EngineState,
  ShreeLipi.Engine,
  SendInputHelper,
  Logger;

type
  TOnKeyChar = function(const AChar: string): TInjectionOutcome of object;

  // M2.2: hook-policy dependencies. Every field is a narrow replaceable seam;
  // a nil field selects the production (Win32-backed) implementation. Tests
  // install deterministic fakes so the consume/pass-through policy can be
  // verified without a live foreground application, real keyboard state, or
  // actual input injection (working rule #4).

  // Snapshot of the physical modifier state needed by the policy and by the
  // Unicode key conversion.
  TKeyModifierState = record
    ShiftDown: Boolean;    // VK_SHIFT / VK_LSHIFT / VK_RSHIFT
    CtrlDown: Boolean;     // VK_CONTROL / VK_LCONTROL / VK_RCONTROL
    AltDown: Boolean;      // VK_MENU / VK_LMENU / VK_RMENU
    WinDown: Boolean;      // VK_LWIN / VK_RWIN
    CapsLockOn: Boolean;   // VK_CAPITAL toggle state
  end;

  TGetForegroundProcessName = function: string;
  TGetModifierState = function: TKeyModifierState;

  // Unicode key conversion (where practical): production feeds ToUnicode from
  // the modifier snapshot; tests substitute a deterministic mapping.
  TVKToUnicode = function(VKCode: DWORD; ScanCode: DWORD;
    const Modifiers: TKeyModifierState): string;

  // Item 9.2: scan-code to virtual-key resolution through the fixed US
  // layout (the positional mapping). Production uses MapVirtualKeyEx with
  // MAPVK_VSC_TO_VK_EX and falls back to FallbackVK when the scan cannot be
  // mapped. Tests substitute a deterministic mapping.
  TScanToVK = function(ScanCode: DWORD; FallbackVK: DWORD): DWORD;

  // Injection status: production reuses the M1.2 SendInputHelper status.
  TIsInjectionHealthy = function: Boolean;

  THookPolicyDependencies = record
    GetForegroundProcessName: TGetForegroundProcessName;
    GetModifierState: TGetModifierState;
    VKToUnicode: TVKToUnicode;
    IsInjectionHealthy: TIsInjectionHealthy;
    ScanToVK: TScanToVK;   // item 9.2: nil selects the production mapping
  end;

  // One key event decoded from KBDLLHOOKSTRUCT + wParam, so the policy never
  // needs the raw hook parameters.
  TKeyContext = record
    VKCode: DWORD;
    ScanCode: DWORD;
    IsKeyDown: Boolean;    // WM_KEYDOWN or WM_SYSKEYDOWN
    IsInjected: Boolean;   // LLKHF_INJECTED
    IsOurs: Boolean;       // carries VITTIX_SENDINPUT_TAG (our own output)
    IsExtended: Boolean;   // LLKHF_EXTENDED (KBDLLHOOKSTRUCT flags bit 0)
  end;

procedure InstallKeyboardHook;
procedure RemoveKeyboardHook;
procedure SetKeyHandler(AHandler: TOnKeyChar);
procedure SetTargetProcessName(const AProcessName: string);
procedure SetAllowedProcessNames(const AProcessNames: string);
procedure SetHookPolicyDependencies(
  const ADependencies: THookPolicyDependencies);
// Item 7: whether events injected by OTHER tools (on-screen keyboards, remote
// desktop) are translated. Default True = the historical behavior (all
// injected input passes through). Our own tagged events are always ignored,
// regardless of this setting.
procedure SetIgnoreInjectedInput(AValue: Boolean);
// The EVENT_SYSTEM_FOREGROUND sink: a foreground-window change cancels the
// engine's pending state so a stale matra never lands in the new field.
// Exposed as a plain procedure so tests can exercise it without a live
// window station; the WinEvent callback delegates to it.
procedure HandleForegroundChanged;

// The production VK-to-character conversion, mapping through a fixed US
// layout (item 5). Exported so tests can pin the deterministic mapping; the
// hook policy still overrides it via THookPolicyDependencies.VKToUnicode.
function ProductionVKToUnicode(VKCode: DWORD; ScanCode: DWORD;
  const Modifiers: TKeyModifierState): string;

// Item 9.2 production scan-to-VK resolution, exported for tests: derives the
// POSITIONAL VK from the scan code through the fixed US layout; falls back to
// the incoming VK when the scan cannot be mapped. The hook policy overrides
// it via THookPolicyDependencies.ScanToVK.
function ProductionScanToVK(ScanCode: DWORD; FallbackVK: DWORD): DWORD;

// Item 9.3: one-time init that resolves the fixed US layout BEFORE the hook
// goes live, so the first keystroke never pays LoadKeyboardLayout inside the
// LL hook callback. Exported so tests can assert the cached handle; the lazy
// fallback inside GetUSLayoutHKL stays as a safety net.
procedure PreloadUSLayout;

// Read access to the cached fixed US layout handle (0 = not resolved).
// Exported for tests; production callers go through ProductionScanToVK and
// ProductionVKToUnicode.
function GetUSLayoutHKL: HKL;

// Item 7 production dependencies, exported for tests only; production callers
// go through THookPolicyDependencies.GetForegroundProcessName.
function ProductionForegroundProcessName: string;
procedure InvalidateForegroundCache;

// The consume/pass-through decision for one key event, kept separate from
// CallNextHookEx so it can be unit tested (M2.2). Returns True when the event
// has been consumed (the hook reports it handled); False when it must be
// passed through.
function HandleKeyEvent(const AKey: TKeyContext): Boolean;

implementation

type
  PKBDLLHookStruct = ^TKBDLLHookStruct;
  TKBDLLHookStruct = record
    vkCode: DWORD;
    scanCode: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: ULONG_PTR;
  end;

var
  KBHook: HHOOK = 0;
  ForegroundEventHook: THandle = 0;
  KeyHandler: TOnKeyChar = nil;
  TargetProcessName: string = '';
  AllowedProcessNames: string = '';
  // Review fix (issue 2): the allowed list is parsed ONCE when it is set,
  // never on the per-keystroke path. Entries are already Trim'd and
  // non-empty; matching below is a plain iteration over this cache.
  AllowedProcessList: TArray<string> = [];
  Policy: THookPolicyDependencies;
  // Item 7: default True preserves the historical fail-open behavior (ignore
  // ALL injected input). Flipping it lets other tools' injected keys reach the
  // translation pipeline; our own tagged events are always excluded.
  IgnoreInjectedInput: Boolean = True;

const
  PROCESS_QUERY_LIMITED_INFORMATION = $1000;

  // KBDLLHOOKSTRUCT.flags bit indicating the event was generated by
  // SendInput/keybd_event (ours or anyone else's) rather than real hardware.
  LLKHF_INJECTED = $10;

  // KBDLLHOOKSTRUCT.flags bit indicating an extended key (arrow/nav keys,
  // right-hand modifiers): the scan code carries the $E0 prefix.
  LLKHF_EXTENDED = $01;

  // The extended-key prefix byte, embedded in the high byte of the scan code
  // passed to MapVirtualKeyEx(MAPVK_VSC_TO_VK_EX) (item 9.2).
  SCANCODE_EXTENDED_PREFIX = $E0;

{ Item 7: kernel32's QueryFullProcessImageName is not declared in the RTL. It
  works with PROCESS_QUERY_LIMITED_INFORMATION and resolves image paths across
  32/64-bit process boundaries, unlike GetModuleFileNameEx. }
function QueryFullProcessImageNameW(
  ProcessHandle: THandle;
  dwFlags: DWORD;
  lpExeName: PChar;
  var lpdwSize: DWORD
): BOOL; stdcall; external kernel32 name 'QueryFullProcessImageNameW';

{ --------------------------------------------------
  Production dependency implementations (Win32-backed)
-------------------------------------------------- }

var
  // Item 7: per-keystroke cache of the foreground process name. The LL hook
  // runs for every key event; OpenProcess + a full image query per keystroke
  // is measurable. Same foreground HWND/PID -> same name, so the pair is the
  // cache key and the EVENT_SYSTEM_FOREGROUND hook (which fires exactly when
  // the foreground window changes) invalidates it.
  CachedForegroundWnd: HWND = 0;
  CachedForegroundPid: DWORD = 0;
  CachedForegroundName: string = '';

procedure InvalidateForegroundCache;
begin
  CachedForegroundWnd := 0;
  CachedForegroundPid := 0;
  CachedForegroundName := '';
end;

function ProductionForegroundProcessName: string;
var
  ForegroundWnd: HWND;
  ProcessId: DWORD;
  ProcessHandle: THandle;
  Buffer: array[0..1023] of Char;
  Len: DWORD;
begin
  ForegroundWnd := GetForegroundWindow;
  if ForegroundWnd = 0 then
    Exit('');

  GetWindowThreadProcessId(ForegroundWnd, ProcessId);
  if ProcessId = 0 then
    Exit('');

  if (ForegroundWnd = CachedForegroundWnd) and
     (ProcessId = CachedForegroundPid) and
     (CachedForegroundName <> '') then
    Exit(CachedForegroundName);

  ProcessHandle := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, ProcessId);
  if ProcessHandle = 0 then
    Exit('');

  try
    Len := Length(Buffer);
    if QueryFullProcessImageNameW(ProcessHandle, 0, Buffer, Len) and (Len > 0) then
    begin
      CachedForegroundWnd := ForegroundWnd;
      CachedForegroundPid := ProcessId;
      CachedForegroundName := ExtractFileName(Buffer);
      Result := CachedForegroundName;
    end
    else
      Result := '';   // fail open: unresolvable name -> pass keys through
  finally
    CloseHandle(ProcessHandle);
  end;
end;

function GetForegroundWindowTitle: string;
var
  ForegroundWnd: HWND;
  Buffer: array[0..MAX_PATH - 1] of Char;
begin
  Result := '';
  ForegroundWnd := GetForegroundWindow;
  if ForegroundWnd = 0 then
    Exit;
  if GetWindowText(ForegroundWnd, Buffer, Length(Buffer)) > 0 then
    Result := Buffer;
end;

function ProductionModifierState: TKeyModifierState;
  function Down(VK: Integer): Boolean;
  begin
    Result := GetAsyncKeyState(VK) < 0;
  end;
begin
  // Use GetAsyncKeyState (physical state), matching the key conversion.
  // GetKeyState reads this thread message queue, which an LL hook does not
  // receive in step with the current keystroke, so modifier state can lag and
  // a Ctrl/Alt/Win shortcut can be eaten by the hook (wrong-glyph injection
  // instead of the shortcut). Caps Lock uses the toggle bit via GetKeyState.
  Result.ShiftDown := Down(VK_SHIFT) or Down(VK_LSHIFT) or Down(VK_RSHIFT);
  Result.CtrlDown := Down(VK_CONTROL) or Down(VK_LCONTROL) or Down(VK_RCONTROL);
  Result.AltDown := Down(VK_MENU) or Down(VK_LMENU) or Down(VK_RMENU);
  Result.WinDown := Down(VK_LWIN) or Down(VK_RWIN);
  // The toggle bit (bit 0) is the Caps Lock state; the high bit only says the
  // key is currently held down and made the old "> 0" check wrong while the
  // key was pressed.
  Result.CapsLockOn := (GetKeyState(VK_CAPITAL) and 1) <> 0;
end;

var
  // Cached fixed US layout (item 5): mapping must not depend on the user's
  // default input language. Loaded once, without activating it for this
  // thread or notifying the shell; 0 on failure (fail-open fallback below).
  gUSLayoutHKL: HKL = 0;

procedure PreloadUSLayout;
begin
  // Item 9.3: called once from InstallKeyboardHook (before SetWindowsHookEx)
  // and idempotent afterwards — the cache guard in GetUSLayoutHKL makes every
  // later call a pure read, never a second LoadKeyboardLayout round.
  if GetUSLayoutHKL = 0 then
    LogError('US layout preload failed: fixed-layout key conversion falls back '
      + 'to per-keystroke lazy loading');
end;

function GetUSLayoutHKL: HKL;
begin
  // Lazy fallback (item 9.3): in normal use the cache is filled by
  // PreloadUSLayout before the hook is installed, so this load path is never
  // the first call in the LL callback.
  if gUSLayoutHKL = 0 then
    gUSLayoutHKL := LoadKeyboardLayout('00000409', KLF_NOTELLSHELL);
  Result := gUSLayoutHKL;
end;

{ Item 9.2: positional scan-to-VK resolution. MAPVK_VSC_TO_VK_EX maps the
  PHYSICAL key (scan code) to the US-layout VK; it understands the $E0
  extended-key prefix embedded by HandleKeyEvent in the high byte. Extended
  and untabled scans fall back to the incoming VK (fail-open). }
function ProductionScanToVK(ScanCode: DWORD; FallbackVK: DWORD): DWORD;
begin
  Result := MapVirtualKeyEx(ScanCode, MAPVK_VSC_TO_VK_EX, GetUSLayoutHKL);
  if Result = 0 then
    Result := FallbackVK;
end;

function ScanToVKDispatch(ScanCode: DWORD; FallbackVK: DWORD): DWORD;
begin
  if Assigned(Policy.ScanToVK) then
    Result := Policy.ScanToVK(ScanCode, FallbackVK)
  else
    Result := ProductionScanToVK(ScanCode, FallbackVK);
  // Fail-open: an unmappable scan (from a fake or a broken table) must never
  // resolve to VK 0 — fall back to the incoming VK so conversion continues.
  if Result = 0 then
    Result := FallbackVK;
end;

function ProductionVKToUnicode(VKCode: DWORD; ScanCode: DWORD;
  const Modifiers: TKeyModifierState): string;
var
  KeyboardState: TKeyboardState;
  WideBuf: array[0..3] of WideChar;
  Len: Integer;
  LayoutHKL: HKL;
  EffectiveVK: DWORD;
begin
  Result := '';

  FillChar(KeyboardState, SizeOf(KeyboardState), 0);

  // ToUnicode consults the base modifier bytes; the snapshot is already the
  // normalized left/right-independent state.
  if Modifiers.ShiftDown then
    KeyboardState[VK_SHIFT] := $80;
  if Modifiers.CtrlDown then
    KeyboardState[VK_CONTROL] := $80;
  if Modifiers.AltDown then
    KeyboardState[VK_MENU] := $80;
  if Modifiers.CapsLockOn then
    KeyboardState[VK_CAPITAL] := 1;

  // Item 9.2: the incoming VK was computed by the focused application with
  // ITS layout, so on a non-US physical keyboard (German QWERTZ, InScript,
  // Remington) the VK is already shifted relative to the physical key.
  // Re-derive it from the scan code through the fixed US layout so positional
  // layouts stay positional. Falls back to the incoming VK when the scan
  // cannot be mapped.
  EffectiveVK := ScanToVKDispatch(ScanCode, VKCode);

  // Map through the fixed US layout so results are deterministic regardless
  // of the user's default input language. Flag $4 leaves the dead-key state
  // untouched, so no throwaway second call is needed.
  LayoutHKL := GetUSLayoutHKL;
  if LayoutHKL <> 0 then
    Len := ToUnicodeEx(EffectiveVK, ScanCode and $FF, KeyboardState, WideBuf,
      Length(WideBuf), $4, LayoutHKL)
  else
    Len := ToUnicode(EffectiveVK, ScanCode and $FF, KeyboardState, WideBuf,
      Length(WideBuf), $4);

  // Handle surrogate pairs (Len can be 2 for SMP characters)
  if Len = 1 then
    Result := WideBuf[0]
  else if Len > 1 then
    SetString(Result, PWideChar(@WideBuf[0]), Len);
  // Len < 0: this key is a dead key. The dead key itself is passed through
  // (Result = '') and its residue was not modified (flag $4).
end;

function ProductionInjectionHealthy: Boolean;
begin
  // M1.2 injection status is the single source of truth; never re-implement it.
  Result := InjectionOK;
end;

{ --------------------------------------------------
  Dependency dispatch (nil = production implementation)
-------------------------------------------------- }

function ForegroundProcessName: string;
begin
  if Assigned(Policy.GetForegroundProcessName) then
    Result := Policy.GetForegroundProcessName()
  else
    Result := ProductionForegroundProcessName;
end;

function CurrentModifierState: TKeyModifierState;
begin
  if Assigned(Policy.GetModifierState) then
    Result := Policy.GetModifierState()
  else
    Result := ProductionModifierState;
end;

function VKToChar(VKCode: DWORD; ScanCode: DWORD;
  const Modifiers: TKeyModifierState): string;
begin
  if Assigned(Policy.VKToUnicode) then
    Result := Policy.VKToUnicode(VKCode, ScanCode, Modifiers)
  else
    Result := ProductionVKToUnicode(VKCode, ScanCode, Modifiers);
end;

function InjectionHealthy: Boolean;
begin
  if Assigned(Policy.IsInjectionHealthy) then
    Result := Policy.IsInjectionHealthy()
  else
    Result := ProductionInjectionHealthy;
end;

function IsProcessAllowed(const ProcessName: string): Boolean;
var
  Entry: string;
begin
  // Review fix (issue 2): no per-keystroke Split/allocation — the parsed
  // entries were precomputed in SetAllowedProcessNames.
  Result := False;
  if Length(AllowedProcessList) = 0 then
    Exit(False);
  for Entry in AllowedProcessList do
    if SameText(Entry, ProcessName) then
      Exit(True);
end;

function IsTargetAppActive: Boolean;
var
  ActiveProcessName: string;
begin
  ActiveProcessName := ForegroundProcessName;
  Result := IsProcessAllowed(ActiveProcessName) or
    ((TargetProcessName <> '') and SameText(ActiveProcessName, TargetProcessName));
end;

function IsModifierComboActive(const Modifiers: TKeyModifierState): Boolean;
begin
  // Ctrl/Alt/Win combos are application shortcuts and pass through untouched.
  // Shift alone must still reach the engine because layouts use it for
  // shifted keys.
  Result := Modifiers.CtrlDown or Modifiers.AltDown or Modifiers.WinDown;
end;

{ --------------------------------------------------
  Consume/pass-through policy (M2.2)
  Pure decision + engine dispatch, independent of CallNextHookEx.
  Returns True when the event is consumed, False to pass through.
  The pipeline order below is the original hook order, preserved.
-------------------------------------------------- }
function HandleKeyEvent(const AKey: TKeyContext): Boolean;
var
  Modifiers: TKeyModifierState;
  Ch: string;
  Outcome: TInjectionOutcome;
  Scan: DWORD;
begin
  Result := False;   // default: pass through
  Outcome := ioNoOutput;

  // Item 7: never reprocess events injected by THIS process. Every key we
  // inject below comes back through this same global hook; without this check,
  // injecting a real VK_TAB/VK_RETURN/VK_BACK to pass a key through feeds it
  // straight back into the handler that injected it, forever. The dwExtraInfo
  // tag makes the distinction exact: events from OTHER tools (on-screen
  // keyboards, remote desktop) are filtered only by IgnoreInjectedInput.
  if AKey.IsOurs then
    Exit;

  if AKey.IsInjected and IgnoreInjectedInput then
    Exit;

  if not EngineEnabled then
    Exit;

  // Fail open: if no layout is active (e.g. loading failed at startup),
  // do not intercept and discard keystrokes; let them through untouched.
  if not EngineHasActiveLayout then
    Exit;

  if not IsTargetAppActive then
    Exit;

  // Fail open: if our own injection is failing (e.g. UIPI blocks targeting a
  // window at a higher integrity level), stop consuming keys so the user's
  // typing is not silently eaten.
  if not InjectionHealthy then
    Exit;

  if not AKey.IsKeyDown then
    Exit;   // key-up: no reset. Its own key-down was consumed a moment ago and
            // the pending matra belongs to the typing flow that continues with
            // the NEXT key; resetting here would lose it.

  // Ignore modifier & control keys. Plain modifier presses (Shift/Ctrl/Alt/
  // Win/Caps alone) must NOT reset pending state: Shift happens between every
  // capital keystroke and would kill the cluster context mid-word.
  case AKey.VKCode of
    VK_SHIFT, VK_LSHIFT, VK_RSHIFT,
    VK_CONTROL, VK_LCONTROL, VK_RCONTROL,
    VK_MENU, VK_LMENU, VK_RMENU,
    VK_CAPITAL:
      Exit;
    VK_ESCAPE:
      begin
        // Esc cancels the current input flow (menus, dialogs); the pending
        // matra/reph belongs to it and must not leak anywhere else.
        ResetPendingOnPassThrough;
        Exit;
      end;
  end;

  Modifiers := CurrentModifierState;

  // Let Ctrl/Alt/Win combos (app shortcuts) pass through untouched. The
  // shortcut ends the typing flow: cancel pending state so it cannot leak.
  if IsModifierComboActive(Modifiers) then
  begin
    ResetPendingOnPassThrough;
    Exit;
  end;

  if (AKey.VKCode = VK_TAB) or (AKey.VKCode = VK_RETURN) then
  begin
    if Assigned(KeyHandler) then
    begin
      if AKey.VKCode = VK_TAB then
        Outcome := KeyHandler(#9)
      else
        Outcome := KeyHandler(#13);
    end;

    // Review fix (issue 1): the engine has committed any pending prebase/reph
    // (or had nothing to commit). The physical control key passes through
    // NATIVELY — the hook never consumed it, so there is nothing to
    // re-inject and its real modifiers survive: Shift+Tab with a pending
    // matra flushes the matra AND moves focus backwards. Re-injecting a bare
    // VK_TAB/VK_RETURN would have dropped the Shift modifier.
    Result := False;
    Exit;
  end;

  // Handle BACKSPACE explicitly
  if AKey.VKCode = VK_BACK then
  begin
    if Assigned(KeyHandler) then
    begin
      Outcome := KeyHandler(#8);  // ASCII Backspace
      Result := (Outcome <> ioZeroAccepted) and (Outcome <> ioPassThrough);
      Exit;
    end;
  end;

  // Convert VK to Unicode character. Item 9.2: extended keys (flags bit 0)
  // carry the $E0 prefix in the high byte of the scan code so the positional
  // scan-to-VK translation can resolve them; KBDLLHOOKSTRUCT.scanCode may
  // already include it, so only add it when absent. An empty conversion is a
  // navigation or non-text key (arrows, Home/End, Delete, F-keys, dead keys):
  // it moves the caret or leaves the flow, so pending state is cancelled
  // rather than emitted into wherever the caret lands next.
  Scan := AKey.ScanCode;
  if AKey.IsExtended and ((Scan shr 8) <> SCANCODE_EXTENDED_PREFIX) then
    Scan := Scan or (SCANCODE_EXTENDED_PREFIX shl 8);
  Ch := VKToChar(AKey.VKCode, Scan, Modifiers);
  if Ch = '' then
  begin
    ResetPendingOnPassThrough;
    Exit;
  end;

  // Pass to engine
  if Assigned(KeyHandler) then
  begin
    Outcome := KeyHandler(Ch);
    // Zero accepted records and explicit pass-through outcomes are safe to
    // pass through (ioPassThrough means the engine emitted and consumed
    // nothing, so the original key goes through natively). Partial acceptance
    // is deliberately consumed because some synthetic input may already exist.
    Result := (Outcome <> ioZeroAccepted) and (Outcome <> ioPassThrough);
    Exit;
  end;

  Result := False;   // no handler: pass through
end;

{ --------------------------------------------------
  Low-level keyboard hook procedure (thin Win32 adapter)
-------------------------------------------------- }
function LowLevelKeyboardProc(
  nCode: Integer;
  wParam: WPARAM;
  lParam: LPARAM
): LRESULT; stdcall;
var
  KBD: PKBDLLHookStruct;
  Key: TKeyContext;
begin
  // If Windows says ignore, pass it on
  if nCode <> HC_ACTION then
    Exit(CallNextHookEx(KBHook, nCode, wParam, lParam));

  KBD := PKBDLLHookStruct(lParam);

  try
    Key := Default(TKeyContext);
    Key.VKCode := KBD^.vkCode;
    Key.ScanCode := KBD^.scanCode;
    Key.IsKeyDown := (wParam = WM_KEYDOWN) or (wParam = WM_SYSKEYDOWN);
    Key.IsInjected := (KBD^.flags and LLKHF_INJECTED) <> 0;
    Key.IsExtended := (KBD^.flags and LLKHF_EXTENDED) <> 0;
    // One comparison per event, no allocation: our SendInput helper tags every
    // record with VITTIX_SENDINPUT_TAG, so our own output is recognized exactly.
    Key.IsOurs := KBD^.dwExtraInfo = VITTIX_SENDINPUT_TAG;

    if HandleKeyEvent(Key) then
      Result := 1   // consumed: do NOT call CallNextHookEx
    else
      Result := CallNextHookEx(KBHook, nCode, wParam, lParam);
  except
    on E: Exception do
    begin
      LogError('LowLevelKeyboardProc failed: ' + E.Message);
      Result := CallNextHookEx(KBHook, nCode, wParam, lParam);
    end;
  end;
end;

{ --------------------------------------------------
  Public API
-------------------------------------------------- }

procedure SetKeyHandler(AHandler: TOnKeyChar);
begin
  KeyHandler := AHandler;
end;

procedure SetIgnoreInjectedInput(AValue: Boolean);
begin
  IgnoreInjectedInput := AValue;
end;

procedure SetTargetProcessName(const AProcessName: string);
begin
  TargetProcessName := Trim(AProcessName);
end;

procedure SetAllowedProcessNames(const AProcessNames: string);
var
  Names: TArray<string>;
  RawName, Entry: string;
  Count: Integer;
begin
  // Review fix (issue 2): parse the list ONCE into trimmed, non-empty
  // entries. Called on settings changes only, never per keystroke; setting
  // an empty string clears the cache entirely.
  AllowedProcessNames := Trim(AProcessNames);
  SetLength(AllowedProcessList, 0);
  if AllowedProcessNames = '' then
    Exit;

  Names := AllowedProcessNames.Split([',', ';', #13, #10]);
  Count := 0;
  SetLength(AllowedProcessList, Length(Names));
  for RawName in Names do
  begin
    Entry := Trim(RawName);
    if Entry = '' then
      Continue;
    AllowedProcessList[Count] := Entry;
    Inc(Count);
  end;
  SetLength(AllowedProcessList, Count);
end;

procedure SetHookPolicyDependencies(
  const ADependencies: THookPolicyDependencies);
begin
  // nil fields restore the production implementations.
  Policy := ADependencies;
end;

procedure HandleForegroundChanged;
begin
  // The typing flow does not survive a foreground switch: whatever was
  // consumed but not yet emitted belongs to the old field, so cancel it
  // without emitting. Also drops the cached foreground process name (item 7),
  // which belongs to the old foreground window. Both operations clear state
  // with no I/O or allocation, keeping the callback fast.
  InvalidateForegroundCache;
  try
    ResetPendingOnPassThrough;
  except
    on E: Exception do
      LogError('Foreground-change reset failed: ' + E.Message);
  end;
end;

// WinEvent callback. Both hooks are installed on the main thread, so this
// serializes with the keyboard hook callback; the work below is a state
// clear with no I/O or allocation, keeping the callback fast.
procedure ForegroundWinEventProc(
  hWinEventHook: THandle;
  Event: DWORD;
  hwnd: HWND;
  idObject: LONG;
  idChild: LONG;
  idEventThread: DWORD;
  dwmsEventTime: DWORD
); stdcall;
begin
  if Event = EVENT_SYSTEM_FOREGROUND then
    HandleForegroundChanged;
end;

procedure InstallKeyboardHook;
begin
  if KBHook <> 0 then
    Exit;

  // Item 9.3: resolve the fixed US layout before the hook goes live, so no
  // keystroke ever pays LoadKeyboardLayout inside the LL callback.
  PreloadUSLayout;

  LogInfo('Installing keyboard hook');
  KBHook := SetWindowsHookEx(
    WH_KEYBOARD_LL,
    @LowLevelKeyboardProc,
    HInstance,
    0
  );

  if KBHook = 0 then
  begin
    LogError('Keyboard hook installation failed');
    RaiseLastOSError;
  end;

  // Foreground-window changes cancel pending engine state (item 3). Installed
  // and removed together with the keyboard hook; failures are logged, not
  // fatal — the stale-state reset is an extra guard, not a safety requirement.
  ForegroundEventHook := SetWinEventHook(
    EVENT_SYSTEM_FOREGROUND,
    EVENT_SYSTEM_FOREGROUND,
    0,
    @ForegroundWinEventProc,
    0,
    0,
    WINEVENT_OUTOFCONTEXT
  );
  if ForegroundEventHook = 0 then
    LogError('Foreground event hook installation failed');
end;

procedure RemoveKeyboardHook;
begin
  if ForegroundEventHook <> 0 then
  begin
    UnhookWinEvent(ForegroundEventHook);
    ForegroundEventHook := 0;
  end;

  if KBHook <> 0 then
  begin
    LogInfo('Removing keyboard hook');
    UnhookWindowsHookEx(KBHook);
    KBHook := 0;
  end;
end;

end.
