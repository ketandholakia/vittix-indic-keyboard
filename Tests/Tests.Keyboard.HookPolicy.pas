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
    procedure CaptureKey(const AChar: string);
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
  AInjected: Boolean = False): TKeyContext;
begin
  Result.VKCode := VK;
  Result.ScanCode := 0;
  Result.IsKeyDown := AKeyDown;
  Result.IsInjected := AInjected;
end;

procedure THookPolicyTests.CaptureKey(const AChar: string);
begin
  if Assigned(GCaptured) then
    GCaptured.Add(AChar);
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

initialization
  TDUnitX.RegisterTestFixture(THookPolicyTests);

end.