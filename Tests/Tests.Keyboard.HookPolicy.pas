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
    procedure EmptyKeyConversion_PassesThrough;
    [Test]
    procedure Tab_KeyDown_Consumed_NotifiesEngine;
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
  AInjected: Boolean = False; AIsOurs: Boolean = False): TKeyContext;
begin
  Result.VKCode := VK;
  Result.ScanCode := 0;
  Result.IsKeyDown := AKeyDown;
  Result.IsInjected := AInjected;
  Result.IsOurs := AIsOurs;
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

procedure THookPolicyTests.EmptyKeyConversion_PassesThrough;
begin
  GFakeVKChar := '';
  Assert.IsFalse(HandleKeyEvent(MakeKey($41, True)),
    'an empty conversion result must pass the key through');
  Assert.AreEqual(0, FKeys.Count);
end;

procedure THookPolicyTests.Tab_KeyDown_Consumed_NotifiesEngine;
begin
  Assert.IsTrue(HandleKeyEvent(MakeKey(VK_TAB, True)),
    'Tab must be consumed');
  Assert.AreEqual(1, FKeys.Count);
  Assert.AreEqual(#9, FKeys[0], 'the engine must receive the Tab control char');
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

initialization
  TDUnitX.RegisterTestFixture(THookPolicyTests);
  TDUnitX.RegisterTestFixture(TForegroundCacheTests);

end.
