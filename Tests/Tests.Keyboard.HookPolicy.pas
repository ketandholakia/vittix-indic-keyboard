unit Tests.Keyboard.HookPolicy;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  EngineState,
  SendInputHelper,
  KeyboardHook;

type
  // M2.2 regression coverage: the consume/pass-through hook policy, exercised
  // through the extracted dependencies with deterministic fakes. No real global
  // hook is installed, no foreground application is queried, no real modifier
  // state is read, and no real keystrokes are sent (working rule #4). The
  // Tab/Enter reinjection path is neutralised through the existing M1.2
  // SetSendInputHook seam.
  [TestFixture]
  THookPolicyTests = class
  strict private
    FDeps: THookPolicyDependencies;
    FKeys: TStringList;
    function CaptureKey(const AChar: string): TInjectionOutcome;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure EngineDisabled_PassesThrough;
    [Test]
    procedure AllowedProcess_TranslatedKey_Consumed;
    [Test]
    procedure DisallowedProcess_PassesThrough;
    [Test]
    procedure TargetProcessName_Matches_CaseInsensitive;
    [Test]
    procedure EmptyWhitelist_FailClosed;
    [Test]
    procedure InjectedEvent_PassesThrough_EvenWhenEligible;
    [Test]
    procedure DecodeKeyContext_TreatsLowerILInjectionAsInjected;
    [Test]
    procedure OwnTaggedEvent_AlwaysIgnored;
    [Test]
    procedure OtherInjectedInput_TranslatedWhenConfigured;
    [Test]
    procedure NonKeyDown_PassesThrough;
    [Test]
    procedure ModifierVirtualKeys_PassThrough;
    [Test]
    procedure CtrlCombo_PassesThrough;
    [Test]
    procedure ShiftAlone_ReachesEngine_WithSnapshot;
    [Test]
    procedure CapsLock_Snapshot_ReachesConversion;
    [Test]
    procedure InjectionUnhealthy_PassesThrough;
    [Test]
    procedure InjectionStatus_ProductionDefault_UsesSendInputHelper;
    [Test]
    procedure ForegroundChange_ReArmsTrippedInjectionLatch_NotifyFiresOncePerTrip;
    [Test]
    procedure EmptyKeyConversion_PassesThrough;
    [Test]
    procedure ExtendedKey_PassesEmbeddedScanPrefix;
    [Test]
    procedure Tab_KeyDown_NotifiesEngine_PassesThroughNatively;
    [Test]
    procedure ShiftTab_WithPendingFlush_FocusesBackwards;
    [Test]
    procedure Backspace_KeyDown_Consumed_NotifiesEngine;
    [Test]
    procedure ZeroAcceptance_PassesThroughCurrentAndNextEvent;
    [Test]
    procedure PartialAcceptance_ConsumesCurrentThenFailsOpen;
  end;

implementation

var
  GFakeProcess: string;
  GFakeModifiers: TKeyModifierState;
  GLastModifiers: TKeyModifierState;
  GLastScanCode: DWORD;
  GFakeVKChar: string;
  GFakeInjectionHealthy: Boolean;
  GFakeSendReturn: UINT;
  GCaptured: TStringList = nil;

function FakeForegroundProcess: string;
begin
  Result := GFakeProcess;
end;

function FakeModifierState: TKeyModifierState;
begin
  Result := GFakeModifiers;
end;

function FakeVKToUnicode(VKCode: DWORD; ScanCode: DWORD;
  const Modifiers: TKeyModifierState): string;
begin
  GLastModifiers := Modifiers;
  GLastScanCode := ScanCode;
  Result := GFakeVKChar;
end;

function FakeInjectionHealthy: Boolean;
begin
  Result := GFakeInjectionHealthy;
end;

function FakeSendInput(cInputs: UINT; pInputs: PInput;
  cbSize: Integer): UINT; stdcall;
begin
  Result := GFakeSendReturn;
end;

function MakeKey(VK: DWORD; AKeyDown: Boolean;
  AInjected: Boolean = False; AIsOurs: Boolean = False;
  AIsExtended: Boolean = False): TKeyContext;
begin
  // Default() first: any field the helper does not set must be False, not
  // stale stack memory (bit us when the IsOurs field was added).
  Result := Default(TKeyContext);
  Result.VKCode := VK;
  Result.ScanCode := 0;
  Result.IsKeyDown := AKeyDown;
  Result.IsInjected := AInjected;
  Result.IsOurs := AIsOurs;
  Result.IsExtended := AIsExtended;
end;

function THookPolicyTests.CaptureKey(const AChar: string): TInjectionOutcome;
begin
  if Assigned(GCaptured) then
    GCaptured.Add(AChar);
  Result := SendUnicodeText(AChar);
end;

procedure THookPolicyTests.Setup;
begin
  InitEngineState;
  SetEngineEnabled(True);
  SetEngineHasActiveLayout(True);

  FKeys := TStringList.Create;
  GCaptured := FKeys;
  SetKeyHandler(CaptureKey);

  GFakeProcess := 'notepad.exe';
  GFakeModifiers := Default(TKeyModifierState);
  GLastModifiers := Default(TKeyModifierState);
  GLastScanCode := 0;
  GFakeVKChar := 'x';
  GFakeInjectionHealthy := True;

  SetAllowedProcessNames('notepad.exe');
  SetTargetProcessName('');

  FDeps := Default(THookPolicyDependencies);
  FDeps.GetForegroundProcessName := FakeForegroundProcess;
  FDeps.GetModifierState := FakeModifierState;
  FDeps.VKToUnicode := FakeVKToUnicode;
  FDeps.IsInjectionHealthy := FakeInjectionHealthy;
  SetHookPolicyDependencies(FDeps);

  // Tab/Enter reinjection must never send real input: reuse the M1.2 seam.
  GFakeSendReturn := 2;
  SetSendInputHook(FakeSendInput);
end;

procedure THookPolicyTests.TearDown;
begin
  FDeps := Default(THookPolicyDependencies);
  SetHookPolicyDependencies(FDeps);   // restore production implementations
  SetSendInputHook(nil);
  SetKeyHandler(nil);
  ResetEngineState;
  ResetInjectionStatus;
  GCaptured := nil;
  FKeys.Free;
end;

procedure THookPolicyTests.EngineDisabled_PassesThrough;
begin
  SetEngineEnabled(False);
  Assert.IsFalse(HandleKeyEvent(MakeKey($41, True)),
    'engine disabled must pass the key through');
  Assert.AreEqual(0, FKeys.Count);
end;

procedure THookPolicyTests.AllowedProcess_TranslatedKey_Consumed;
begin
  Assert.IsTrue(HandleKeyEvent(MakeKey($41, True)),
    'allowed process + healthy injection must consume the key');
  Assert.AreEqual(1, FKeys.Count);
  Assert.AreEqual('x', FKeys[0], 'engine must receive the converted character');
end;

procedure THookPolicyTests.DisallowedProcess_PassesThrough;
begin
  GFakeProcess := 'cmd.exe';
  Assert.IsFalse(HandleKeyEvent(MakeKey($41, True)),
    'a disallowed foreground process must pass the key through');
  Assert.AreEqual(0, FKeys.Count);
end;

procedure THookPolicyTests.TargetProcessName_Matches_CaseInsensitive;
begin
  SetAllowedProcessNames('');
  SetTargetProcessName('WinWord.exe');
  GFakeProcess := 'WINWORD.EXE';
  Assert.IsTrue(HandleKeyEvent(MakeKey($41, True)),
    'the configured target process must be accepted case-insensitively');
end;

procedure THookPolicyTests.EmptyWhitelist_FailClosed;
begin
  SetAllowedProcessNames('');
  GFakeProcess := 'notepad.exe';
  Assert.IsFalse(HandleKeyEvent(MakeKey($41, True)),
    'an empty whitelist with no target must reject every process');
  Assert.AreEqual(0, FKeys.Count);
end;

procedure THookPolicyTests.InjectedEvent_PassesThrough_EvenWhenEligible;
begin
  Assert.IsFalse(HandleKeyEvent(MakeKey($41, True, True)),
    'injected events must never be reprocessed');
  Assert.AreEqual(0, FKeys.Count);
end;

// Item 7: events carrying our own dwExtraInfo tag are ignored regardless of
// configuration — reprocessing them would create an infinite loop.
// Review fix (issue 3): the raw flag decoding must treat LLKHF_INJECTED
// ($10, same-integrity injection) AND LLKHF_LOWER_IL_INJECTED ($02,
// injection from a lower-integrity process) as synthetic input, so the
// injected filter covers everything. Extended and ours-tag decoding are
// pinned alongside.
procedure THookPolicyTests.DecodeKeyContext_TreatsLowerILInjectionAsInjected;
var
  KBD: TKBDLLHookStruct;
begin
  KBD := Default(TKBDLLHookStruct);
  KBD.vkCode := $41;
  KBD.scanCode := $1E;
  KBD.dwExtraInfo := 12345;

  KBD.flags := $10;
  Assert.IsTrue(DecodeKeyContext(KBD, True).IsInjected, 'LLKHF_INJECTED ($10)');
  KBD.flags := $02;
  Assert.IsTrue(DecodeKeyContext(KBD, True).IsInjected,
    'LLKHF_LOWER_IL_INJECTED ($02) is synthetic too');
  KBD.flags := $12;
  Assert.IsTrue(DecodeKeyContext(KBD, True).IsInjected, 'both bits set');
  KBD.flags := $00;
  Assert.IsFalse(DecodeKeyContext(KBD, True).IsInjected, 'plain hardware event');
  KBD.flags := $01;
  Assert.IsTrue(DecodeKeyContext(KBD, True).IsExtended, 'extended bit decodes');
  Assert.IsFalse(DecodeKeyContext(KBD, True).IsInjected,
    'the extended bit alone is NOT injected');
  KBD.flags := $10;
  KBD.dwExtraInfo := VITTIX_SENDINPUT_TAG;
  Assert.IsTrue(DecodeKeyContext(KBD, True).IsOurs, 'our dwExtraInfo tag');
  Assert.IsTrue(DecodeKeyContext(KBD, True).IsInjected);
  Assert.AreEqual(DWORD($41), DecodeKeyContext(KBD, True).VKCode);
  Assert.AreEqual(DWORD($1E), DecodeKeyContext(KBD, True).ScanCode);
end;

procedure THookPolicyTests.OwnTaggedEvent_AlwaysIgnored;
begin
  SetIgnoreInjectedInput(False);
  try
    Assert.IsFalse(HandleKeyEvent(MakeKey($41, True, True, True)),
      'our own tagged events must never be reprocessed');
    Assert.AreEqual(0, FKeys.Count);
  finally
    SetIgnoreInjectedInput(True);
  end;
end;

// Item 7: with the configurable ignore switched off, injected input from other
// tools (on-screen keyboards, remote desktop) is translated like real input.
procedure THookPolicyTests.OtherInjectedInput_TranslatedWhenConfigured;
begin
  SetIgnoreInjectedInput(False);
  try
    Assert.IsTrue(HandleKeyEvent(MakeKey($41, True, True)),
      'foreign injected input must be translated when configured');
    Assert.AreEqual(1, FKeys.Count);
    Assert.AreEqual('x', FKeys[0]);
  finally
    SetIgnoreInjectedInput(True);
  end;
end;

procedure THookPolicyTests.NonKeyDown_PassesThrough;
begin
  Assert.IsFalse(HandleKeyEvent(MakeKey($41, False)),
    'key-up events must pass through');
end;

procedure THookPolicyTests.ModifierVirtualKeys_PassThrough;
begin
  Assert.IsFalse(HandleKeyEvent(MakeKey(VK_SHIFT, True)), 'VK_SHIFT passes through');
  Assert.IsFalse(HandleKeyEvent(MakeKey(VK_ESCAPE, True)), 'VK_ESCAPE passes through');
  Assert.IsFalse(HandleKeyEvent(MakeKey(VK_CONTROL, True)), 'VK_CONTROL passes through');
  Assert.IsFalse(HandleKeyEvent(MakeKey(VK_CAPITAL, True)), 'VK_CAPITAL passes through');
  Assert.AreEqual(0, FKeys.Count);
end;

procedure THookPolicyTests.CtrlCombo_PassesThrough;
begin
  GFakeModifiers.CtrlDown := True;
  Assert.IsFalse(HandleKeyEvent(MakeKey($41, True)),
    'Ctrl+key is an application shortcut and must pass through');
  Assert.AreEqual(0, FKeys.Count);
end;

procedure THookPolicyTests.ShiftAlone_ReachesEngine_WithSnapshot;
begin
  GFakeModifiers.ShiftDown := True;
  GFakeVKChar := 'X';
  Assert.IsTrue(HandleKeyEvent(MakeKey($41, True)),
    'Shift alone must still reach the engine');
  Assert.AreEqual(1, FKeys.Count);
  Assert.AreEqual('X', FKeys[0]);
  Assert.IsTrue(GLastModifiers.ShiftDown,
    'the modifier snapshot must cross the conversion boundary');
end;

procedure THookPolicyTests.CapsLock_Snapshot_ReachesConversion;
begin
  GFakeModifiers.CapsLockOn := True;
  Assert.IsTrue(HandleKeyEvent(MakeKey($41, True)));
  Assert.IsTrue(GLastModifiers.CapsLockOn,
    'Caps Lock state must cross the conversion boundary');
end;

procedure THookPolicyTests.InjectionUnhealthy_PassesThrough;
begin
  GFakeInjectionHealthy := False;
  Assert.IsFalse(HandleKeyEvent(MakeKey($41, True)),
    'failing injection must fail open and pass the key through');
  Assert.AreEqual(0, FKeys.Count);
end;

procedure THookPolicyTests.InjectionStatus_ProductionDefault_UsesSendInputHelper;
begin
  // Leave IsInjectionHealthy unset (nil) so the production wiring is used.
  FDeps.IsInjectionHealthy := nil;
  SetHookPolicyDependencies(FDeps);

  GFakeSendReturn := 0;              // SendInput accepts nothing
  SendUnicodeText('A');              // marks the M1.2 injection failure
  Assert.IsFalse(InjectionOK, 'M1.2 status must report the failure');
  Assert.IsFalse(HandleKeyEvent(MakeKey($41, True)),
    'the hook must fail open on the real injection status');

  GFakeSendReturn := 2;              // exact down/up count accepted
  ResetInjectionStatus;
  Assert.IsTrue(HandleKeyEvent(MakeKey($41, True)),
    'after the explicit reset the key is consumed again');
end;

// Item (injection latch): the SendInput-failure latch is per foreground
// window. A UIPI block against one elevated app must not stop translation
// everywhere until the user manually toggles: a foreground change re-arms
// the latch, and the tray's notify callback fires exactly once for the trip.
procedure THookPolicyTests.ForegroundChange_ReArmsTrippedInjectionLatch_NotifyFiresOncePerTrip;
var
  StatusEvents: TStringList;
begin
  StatusEvents := TStringList.Create;
  try
    // Production injection status + a failing fake SendInput.
    FDeps.IsInjectionHealthy := nil;
    SetHookPolicyDependencies(FDeps);
    GFakeSendReturn := 0;
    SetInjectionStatusCallback(
      procedure(AHealthy: Boolean)
      begin
        if AHealthy then
          StatusEvents.Add('1')
        else
          StatusEvents.Add('0');
      end);
    try
      // Trip the latch through the fake SendInput (one failing output batch).
      SendUnicodeText('A');
      Assert.IsFalse(InjectionOK, 'the failed SendInput must trip the latch');
      Assert.AreEqual(1, StatusEvents.Count,
        'the trip must notify exactly once');
      Assert.AreEqual('0', StatusEvents[0]);

      // An eligible key fails open (pass-through) while the latch is down.
      Assert.IsFalse(HandleKeyEvent(MakeKey($42, True)),
        'a tripped latch must fail open');

      // The foreground changes (e.g. the user left the elevated app):
      // the latch re-arms for the new window.
      HandleForegroundChanged;
      Assert.IsTrue(InjectionOK,
        'a foreground change must re-arm the injection latch');

      // The next key in the new window is translated again.
      GFakeSendReturn := 2;
      Assert.IsTrue(HandleKeyEvent(MakeKey($43, True)),
        'the next key in the new window is translated again');

      // Exactly ONE trip notify for the episode; the re-arm added a healthy
      // event. (If SendInput keeps failing in the new window, the latch trips
      // again and notifies again - one notify per latch, never per keystroke.)
      Assert.AreEqual(2, StatusEvents.Count,
        'one trip notify + one re-arm notify, rate-limited to once per latch');
      Assert.AreEqual('1', StatusEvents[1], 'the re-arm notify reports healthy');
    finally
      SetInjectionStatusCallback(nil);
    end;
  finally
    StatusEvents.Free;
  end;
end;

procedure THookPolicyTests.EmptyKeyConversion_PassesThrough;
begin
  GFakeVKChar := '';
  Assert.IsFalse(HandleKeyEvent(MakeKey($41, True)),
    'an empty conversion result must pass the key through');
  Assert.AreEqual(0, FKeys.Count);
end;

// Item 9.2: extended keys (KBDLLHOOKSTRUCT flags bit 0) must reach the VK
// conversion with the $E0 prefix embedded in the scan code, so the
// scan-to-VK translation through MapVirtualKeyEx can resolve the correct
// extended key. Non-extended scans pass through unmodified.
procedure THookPolicyTests.ExtendedKey_PassesEmbeddedScanPrefix;
var
  Key: TKeyContext;
begin
  Key := MakeKey($26, True, False, False, True);
  Key.ScanCode := $26;   // a real scan, so the prefix lands in the high byte
  Assert.IsTrue(HandleKeyEvent(Key), 'extended key reaches the conversion');
  Assert.AreEqual(DWORD($E026), GLastScanCode,
    'the scan code must carry the $E0 extended-key prefix');

  Key := MakeKey($41, True);
  Key.ScanCode := $1E;
  Assert.IsTrue(HandleKeyEvent(Key), 'regular key reaches the conversion');
  Assert.AreEqual(DWORD($1E), GLastScanCode,
    'a regular key must not carry the prefix');
end;

// Review fix (issue 1): the physical control key passes through NATIVELY
// after the engine's flush — the hook never consumed it, so its real
// modifiers survive. Shift+Tab therefore still moves focus backwards.
procedure THookPolicyTests.Tab_KeyDown_NotifiesEngine_PassesThroughNatively;
begin
  Assert.IsFalse(HandleKeyEvent(MakeKey(VK_TAB, True)),
    'Tab must pass through natively (no synthetic re-injection)');
  Assert.AreEqual(1, FKeys.Count);
  Assert.AreEqual(#9, FKeys[0], 'the engine must receive the Tab control char');
end;

procedure THookPolicyTests.ShiftTab_WithPendingFlush_FocusesBackwards;
begin
  // The modifier snapshot has Shift held: the pending flush runs, and the
  // physical Shift+Tab flows on untouched, so focus moves backwards.
  GFakeModifiers.ShiftDown := True;
  Assert.IsFalse(HandleKeyEvent(MakeKey(VK_TAB, True)),
    'Shift+Tab must pass through with its Shift modifier intact');
  Assert.AreEqual(1, FKeys.Count, 'the pending flush must have been committed');
  Assert.AreEqual(#9, FKeys[0]);
end;

procedure THookPolicyTests.Backspace_KeyDown_Consumed_NotifiesEngine;
begin
  Assert.IsTrue(HandleKeyEvent(MakeKey(VK_BACK, True)),
    'Backspace must be consumed');
  Assert.AreEqual(1, FKeys.Count);
  Assert.AreEqual(#8, FKeys[0], 'the engine must receive ASCII Backspace');
end;

procedure THookPolicyTests.ZeroAcceptance_PassesThroughCurrentAndNextEvent;
begin
  FDeps.IsInjectionHealthy := nil;
  SetHookPolicyDependencies(FDeps);
  GFakeSendReturn := 0;
  Assert.IsFalse(HandleKeyEvent(MakeKey($41, True)),
    'zero accepted records must pass through the current physical key');
  Assert.IsFalse(InjectionOK);
  Assert.AreEqual(1, FKeys.Count);

  GFakeSendReturn := 2;
  Assert.IsFalse(HandleKeyEvent(MakeKey($42, True)),
    'the next eligible key must fail open before invoking the handler');
  Assert.AreEqual(1, FKeys.Count);
end;

procedure THookPolicyTests.PartialAcceptance_ConsumesCurrentThenFailsOpen;
begin
  FDeps.IsInjectionHealthy := nil;
  SetHookPolicyDependencies(FDeps);
  GFakeSendReturn := 1;
  Assert.IsTrue(HandleKeyEvent(MakeKey($41, True)),
    'partial acceptance must consume the current key to prevent duplicate fallback');
  Assert.IsFalse(InjectionOK);
  Assert.AreEqual(1, FKeys.Count);

  GFakeSendReturn := 2;
  Assert.IsFalse(HandleKeyEvent(MakeKey($42, True)),
    'the next eligible key must fail open after partial acceptance');
  Assert.AreEqual(1, FKeys.Count);
end;

type
  // Item 7: the production foreground-process lookup uses
  // QueryFullProcessImageName with a per-foreground-HWND/PID cache that the
  // WinEvent hook invalidates. Only the observable contract is asserted here:
  // the name stays stable across cached calls and remains correct right after
  // an explicit invalidation. No real hook is installed.
  [TestFixture]
  TForegroundCacheTests = class
  public
    [Test]
    procedure ForegroundName_StableAcrossCalls_AndValidAfterInvalidation;
  end;

procedure TForegroundCacheTests.ForegroundName_StableAcrossCalls_AndValidAfterInvalidation;
var
  FirstName, SecondName, AfterInvalidate: string;
begin
  if GetForegroundWindow = 0 then
  begin
    Assert.Pass('no foreground window on this session');
    Exit;
  end;

  FirstName := ProductionForegroundProcessName;
  SecondName := ProductionForegroundProcessName;   // served from the cache
  Assert.AreEqual(FirstName, SecondName,
    'repeated lookups for the same foreground window must agree');

  InvalidateForegroundCache;
  AfterInvalidate := ProductionForegroundProcessName;
  Assert.AreEqual(FirstName, AfterInvalidate,
    'after invalidation the same window must resolve to the same name');
end;

// Item 3a (watchdog): Windows silently removes WH_KEYBOARD_LL hooks whose
// callback exceeds the timeout. The liveness decision is a pure function
// (heartbeat vs GetLastInputInfo) and is pinned here; the Win32 re-install
// itself stays untested (no real global hook may be installed in tests), and
// both restart entries are guarded no-ops while no hook is installed, which
// the no-op tests below also pin.
type
  [TestFixture]
  THookWatchdogTests = class
public
  [Test]
  procedure HeartbeatStale_InputNewerThanHeartbeat_BeyondWindow;
  [Test]
  procedure HeartbeatFresh_IsNotStale;
  [Test]
  procedure HeartbeatOlderButNoNewerInput_IsNotStale;
  [Test]
  procedure HeartbeatStale_TickWrapAround;
  [Test]
  procedure HeartbeatTouch_RoundTrip;
  [Test]
  procedure NoHookInstalled_RestartEntriesAreSafeNoOps;
end;

procedure THookWatchdogTests.HeartbeatStale_InputNewerThanHeartbeat_BeyondWindow;
begin
  // System input at t=130000, heartbeat last refreshed at t=1000 (never ran
  // again): the hook missed input and is beyond the stale window -> dead.
  Assert.IsTrue(HookHeartbeatIsStale(200000, 1000, 130000));
end;

procedure THookWatchdogTests.HeartbeatFresh_IsNotStale;
begin
  // The hook saw input 5 s ago (a normal typing pause): alive.
  Assert.IsFalse(HookHeartbeatIsStale(200000, 195000, 199000));
end;

procedure THookWatchdogTests.HeartbeatOlderButNoNewerInput_IsNotStale;
begin
  // No system input at all since the heartbeat (idle machine, no mouse,
  // no keyboard): absence of keystrokes proves nothing -> alive.
  Assert.IsFalse(HookHeartbeatIsStale(200000, 1000, 500));
end;

procedure THookWatchdogTests.HeartbeatStale_TickWrapAround;
begin
  // GetTickCount wraps after ~49.7 days; Integer subtraction keeps the
  // comparison correct across the wrap. Heartbeat $FFFF0000 (just before the
  // wrap), "now" $20000 (196.6 s after it, past the 120 s window):
  // input 32.8 s after the heartbeat (newer than it) means dead;
  // input 8.2 s BEFORE the heartbeat (no missed input) means alive.
  Assert.IsFalse(HookHeartbeatIsStale(DWORD($20000), DWORD($FFFF0000),
    DWORD($FFFEE000)), 'no input newer than the heartbeat: alive across the wrap');
  Assert.IsTrue(HookHeartbeatIsStale(DWORD($20000), DWORD($FFFF0000),
    DWORD($FFFF8000)), 'input newer than a heartbeat 196 s behind now: dead');
end;

procedure THookWatchdogTests.HeartbeatTouch_RoundTrip;
begin
  TouchHookHeartbeat;
  Assert.AreEqual(GetTickCount, HookHeartbeatTick,
    'TouchHookHeartbeat must stamp the current tick');
end;

// No real global hook may be installed in tests (working rule #4), so both
// restart entries must be no-ops while KBHook = 0: they must not install a
// hook, not raise, and leave the "installed" answer False.
procedure THookWatchdogTests.NoHookInstalled_RestartEntriesAreSafeNoOps;
begin
  Assert.IsFalse(KeyboardHookInstalled,
    'tests never install a real global hook');
  EnsureKeyboardHookInstalled('watchdog: hook handle missing');
  Assert.IsFalse(KeyboardHookInstalled,
    'EnsureKeyboardHookInstalled must no-op in a test host (no real hook)');
  RestartKeyboardHook;
  Assert.IsFalse(KeyboardHookInstalled,
    'RestartKeyboardHook must no-op when nothing is installed');
end;

initialization
  TDUnitX.RegisterTestFixture(THookPolicyTests);
  TDUnitX.RegisterTestFixture(TForegroundCacheTests);
  TDUnitX.RegisterTestFixture(THookWatchdogTests);

end.
