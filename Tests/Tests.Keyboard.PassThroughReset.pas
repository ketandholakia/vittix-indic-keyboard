unit Tests.Keyboard.PassThroughReset;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  EngineState,
  SendInputHelper,
  ShreeLipi.Engine,
  KeyboardHook,
  LayoutModel;

type
  // Items 3 & 4 regression coverage. Item 3: keys that pass through the hook
  // must clear the engine's pending prebase/reph/cluster state, so a stale
  // matra can never be emitted into the next field. Item 4: unmapped keys
  // (space, digits, Tab/Enter with nothing pending) pass through natively with
  // no SendInput call at all, while a pending prebase is flushed and then
  // re-injected. End-to-end through HandleKeyEvent with the real engine wired
  // as the key handler: no real hook, no foreground app, no real keystrokes
  // (working rule #4).
  [TestFixture]
  TPassThroughResetTests = class
  strict private
    FLayout: TKeyboardLayout;
    FEvents: TStringList;
    // TOnKeyChar is a method pointer, so the engine handler lives on the class.
    function EngineKey(const AChar: string): TInjectionOutcome;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure LeftArrow_AfterPendingPrebase_NoMatraLeak;
    [Test]
    procedure Escape_CancelsPending;
    [Test]
    procedure CtrlCombo_CancelsPending;
    [Test]
    procedure KeyUp_DoesNotClearPending;
    [Test]
    procedure ShiftKeyDown_DoesNotClearPending;
    [Test]
    procedure ForegroundChange_CancelsPending;
    [Test]
    procedure DeleteKey_CancelsPending;
    [Test]
    procedure Space_NoPending_PassesThrough_WithoutSendInput;
    [Test]
    procedure Digit_NoPending_PassesThrough_WithoutSendInput;
    [Test]
    procedure Tab_NoPending_PassesThrough_WithoutSendInput;
    [Test]
    procedure Enter_NoPending_PassesThrough_WithoutSendInput;
    [Test]
    procedure Space_WithPendingPrebase_FlushesThenReinjects;
    [Test]
    procedure Tab_WithPendingPrebase_FlushesThenReinjectsVKTab;
  end;

implementation

var
  GFakeProcess: string;
  GFakeModifiers: TKeyModifierState;
  GFakeVKChar: string;
  GSendInputCalls: Integer;
  GEvents: TStringList = nil;

function FakeForegroundProcess: string;
begin
  Result := GFakeProcess;
end;

function FakeModifierState: TKeyModifierState;
begin
  Result := GFakeModifiers;
end;

// Deterministic conversion: exactly the characters the test feeds in, empty
// for the keys a real US ToUnicode cannot convert (navigation keys).
function FakeVKToUnicode(VKCode: DWORD; ScanCode: DWORD;
  const Modifiers: TKeyModifierState): string;
begin
  Result := GFakeVKChar;
end;

function FakeSendInput(cInputs: UINT; pInputs: PInput;
  cbSize: Integer): UINT; stdcall;
begin
  Inc(GSendInputCalls);
  Result := cInputs;   // always fully accepted
end;

function TPassThroughResetTests.EngineKey(const AChar: string): TInjectionOutcome;
begin
  Result := ProcessKeyChar(AChar);
end;

procedure CaptureAction(const AAction: TEngineOutputAction; const AText: string);
begin
  if not Assigned(GEvents) then
    Exit;
  case AAction of
    eoEmitText:      GEvents.Add('T:' + AText);
    eoEmitBackspace: GEvents.Add('B');
    eoResetState:    GEvents.Add('R');
  end;
end;

function MakeKey(VK: DWORD; AKeyDown: Boolean): TKeyContext;
begin
  Result := Default(TKeyContext);
  Result.VKCode := VK;
  Result.ScanCode := 0;
  Result.IsKeyDown := AKeyDown;
  Result.IsInjected := False;
end;

procedure TPassThroughResetTests.Setup;
var
  Deps: THookPolicyDependencies;
  Prebase: TKeyMapping;
begin
  InitEngineState;
  SetEngineEnabled(True);

  // ASCII layout: 'i' is the prebase matra (pending 'I'), 'k' the direct
  // consonant 'K', 'a' the postbase matra 'A'.
  FLayout := TKeyboardLayout.Create;
  FLayout.DirectMap.Add('k', 'K');
  Prebase := Default(TKeyMapping);
  Prebase.Key := 'i';
  Prebase.Glyph := 'I';
  Prebase.MapType := 'prebase';
  FLayout.PrebaseMap.Add('i', Prebase);
  FLayout.PostbaseMap.Add('a', 'A');
  SetActiveLayout(FLayout);

  FEvents := TStringList.Create;
  GEvents := FEvents;
  SetEngineOutputHandler(CaptureAction);
  SetKeyHandler(EngineKey);

  GFakeProcess := 'notepad.exe';
  GFakeModifiers := Default(TKeyModifierState);
  GFakeVKChar := '';

  SetAllowedProcessNames('notepad.exe');
  SetTargetProcessName('');

  Deps := Default(THookPolicyDependencies);
  Deps.GetForegroundProcessName := FakeForegroundProcess;
  Deps.GetModifierState := FakeModifierState;
  Deps.VKToUnicode := FakeVKToUnicode;
  Deps.IsInjectionHealthy := nil;   // production wiring reads M1.2 status
  SetHookPolicyDependencies(Deps);

  GFakeVKChar := '';
  GSendInputCalls := 0;
  SetSendInputHook(FakeSendInput);
  ResetInjectionStatus;
  FEvents.Clear;
end;

procedure TPassThroughResetTests.TearDown;
begin
  ResetEngineState;
  SetActiveLayout(nil);
  SetEngineOutputHandler(nil);
  SetKeyHandler(nil);
  SetSendInputHook(nil);
  SetHookPolicyDependencies(Default(THookPolicyDependencies));
  GEvents := nil;
  FEvents.Free;
  FLayout.Free;
end;

// The spec scenario: pending prebase, then Left arrow, then a consonant.
// Expect no matra emitted.
procedure TPassThroughResetTests.LeftArrow_AfterPendingPrebase_NoMatraLeak;
begin
  GFakeVKChar := 'i';
  Assert.IsTrue(HandleKeyEvent(MakeKey($49, True)),
    'the prebase key must be consumed');
  Assert.AreEqual('', FEvents.Text, 'no output while the prebase is pending');

  GFakeVKChar := '';    // a real ToUnicode returns nothing for VK_LEFT
  Assert.IsFalse(HandleKeyEvent(MakeKey(VK_LEFT, True)),
    'the arrow key must pass through');
  Assert.AreEqual('', gEngineState.PendingPrebase,
    'navigation must cancel the pending prebase');

  GFakeVKChar := 'k';
  Assert.IsTrue(HandleKeyEvent(MakeKey($4B, True)),
    'the consonant must be consumed');
  Assert.AreEqual(1, FEvents.Count, 'only the consonant may be emitted');
  Assert.AreEqual('T:K', FEvents[0],
    'the pending matra must not be emitted after navigation');
end;

procedure TPassThroughResetTests.Escape_CancelsPending;
begin
  GFakeVKChar := 'i';
  HandleKeyEvent(MakeKey($49, True));

  Assert.IsFalse(HandleKeyEvent(MakeKey(VK_ESCAPE, True)),
    'Esc passes through');
  Assert.AreEqual('', gEngineState.PendingPrebase,
    'Esc must cancel the pending prebase');

  GFakeVKChar := 'k';
  HandleKeyEvent(MakeKey($4B, True));
  Assert.AreEqual(1, FEvents.Count, 'only the consonant may be emitted');
  Assert.AreEqual('T:K', FEvents[0], 'no stale matra after Esc');
end;

procedure TPassThroughResetTests.CtrlCombo_CancelsPending;
begin
  GFakeVKChar := 'i';
  HandleKeyEvent(MakeKey($49, True));

  GFakeModifiers.CtrlDown := True;
  Assert.IsFalse(HandleKeyEvent(MakeKey($41, True)),
    'Ctrl+A is an application shortcut and passes through');
  Assert.AreEqual('', gEngineState.PendingPrebase,
    'a Ctrl/Alt/Win combo must cancel the pending prebase');
end;

// A key-up must NOT clear pending state: its own key-down was consumed a
// moment ago and the pending matra belongs to the typing flow that continues
// with the NEXT key.
procedure TPassThroughResetTests.KeyUp_DoesNotClearPending;
begin
  GFakeVKChar := 'i';
  HandleKeyEvent(MakeKey($49, True));

  GFakeVKChar := '';
  Assert.IsFalse(HandleKeyEvent(MakeKey($49, False)),
    'the key-up passes through');

  // Tab commits whatever is pending: if the key-up had wrongly cleared the
  // pending prebase, nothing would be flushed here.
  GFakeVKChar := 'i';
  HandleKeyEvent(MakeKey(VK_TAB, True));
  Assert.IsTrue(FEvents.Text.Contains('T:I'),
    'the pending prebase must survive its own key-up and flush on Tab');
end;

// Plain modifier presses happen between every capital keystroke; they must
// never disturb the pending state.
procedure TPassThroughResetTests.ShiftKeyDown_DoesNotClearPending;
begin
  GFakeVKChar := 'i';
  HandleKeyEvent(MakeKey($49, True));

  GFakeVKChar := '';
  Assert.IsFalse(HandleKeyEvent(MakeKey(VK_SHIFT, True)),
    'Shift alone passes through');

  GFakeVKChar := 'i';
  HandleKeyEvent(MakeKey(VK_TAB, True));
  Assert.IsTrue(FEvents.Text.Contains('T:I'),
    'the pending prebase must survive a plain Shift press');
end;

procedure TPassThroughResetTests.ForegroundChange_CancelsPending;
begin
  GFakeVKChar := 'i';
  HandleKeyEvent(MakeKey($49, True));

  HandleForegroundChanged;
  Assert.AreEqual('', gEngineState.PendingPrebase,
    'a foreground change must cancel the pending prebase');

  GFakeVKChar := 'k';
  HandleKeyEvent(MakeKey($4B, True));
  Assert.AreEqual(1, FEvents.Count, 'only the consonant may be emitted');
  Assert.AreEqual('T:K', FEvents[0], 'no stale matra after a foreground change');
end;

procedure TPassThroughResetTests.DeleteKey_CancelsPending;
begin
  GFakeVKChar := 'i';
  HandleKeyEvent(MakeKey($49, True));

  GFakeVKChar := '';    // ToUnicode returns empty for VK_DELETE
  Assert.IsFalse(HandleKeyEvent(MakeKey(VK_DELETE, True)),
    'Delete passes through');
  Assert.AreEqual('', gEngineState.PendingPrebase,
    'Delete must cancel the pending prebase');
end;

// Item 4: with no pending state, an unmapped key (space, digits) and
// Tab/Enter must pass through NATIVELY — no emission, no reinjection, zero
// SendInput calls.
procedure TPassThroughResetTests.Space_NoPending_PassesThrough_WithoutSendInput;
begin
  GFakeVKChar := ' ';
  Assert.IsFalse(HandleKeyEvent(MakeKey(VK_SPACE, True)),
    'space with nothing pending must pass through');
  Assert.AreEqual(0, GSendInputCalls, 'pass-through must not call SendInput');
  Assert.AreEqual(0, FEvents.Count, 'pass-through must not emit anything');
end;

procedure TPassThroughResetTests.Digit_NoPending_PassesThrough_WithoutSendInput;
begin
  GFakeVKChar := '5';
  Assert.IsFalse(HandleKeyEvent(MakeKey($35, True)),
    'an unmapped digit with nothing pending must pass through');
  Assert.AreEqual(0, GSendInputCalls, 'pass-through must not call SendInput');
  Assert.AreEqual(0, FEvents.Count, 'pass-through must not emit anything');
end;

procedure TPassThroughResetTests.Tab_NoPending_PassesThrough_WithoutSendInput;
begin
  Assert.IsFalse(HandleKeyEvent(MakeKey(VK_TAB, True)),
    'Tab with nothing pending must pass through natively');
  Assert.AreEqual(0, GSendInputCalls,
    'the original Tab must go through, not be re-injected');
  Assert.AreEqual(0, FEvents.Count, 'nothing to flush means nothing to emit');
end;

procedure TPassThroughResetTests.Enter_NoPending_PassesThrough_WithoutSendInput;
begin
  Assert.IsFalse(HandleKeyEvent(MakeKey(VK_RETURN, True)),
    'Enter with nothing pending must pass through natively');
  Assert.AreEqual(0, GSendInputCalls,
    'the original Enter must go through, not be re-injected');
end;

// With a pending prebase the flush emits text, and the physical key —
// consumed by the translation — is re-injected afterwards (space re-emitted
// as literal text through the engine, Tab re-injected as a virtual key).
// The capture handler is detached so every emission reaches the (faked)
// SendInput and can be counted.
procedure TPassThroughResetTests.Space_WithPendingPrebase_FlushesThenReinjects;
begin
  SetEngineOutputHandler(nil);

  GFakeVKChar := 'i';
  Assert.IsTrue(HandleKeyEvent(MakeKey($49, True)), 'the prebase key is consumed');
  Assert.AreEqual(0, GSendInputCalls, 'storing the prebase injects nothing');

  GFakeVKChar := ' ';
  Assert.IsTrue(HandleKeyEvent(MakeKey(VK_SPACE, True)),
    'the space is consumed because the flush already emitted text');
  Assert.AreEqual(2, GSendInputCalls,
    'the flushed prebase and the literal space must have been injected');
end;

// Item (Tab/Enter ordering): with a pending prebase the flush emits text, so
// the physical Tab is CONSUMED and re-injected in order after the matra (the
// injected matra would otherwise land after the still-in-flight physical
// Tab, in the field the Tab just moved to). Nothing-pending Tabs stay native
// (see Tab_NoPending above).
procedure TPassThroughResetTests.Tab_WithPendingPrebase_FlushesThenReinjectsVKTab;
begin
  SetEngineOutputHandler(nil);

  GFakeVKChar := 'i';
  Assert.IsTrue(HandleKeyEvent(MakeKey($49, True)), 'the prebase key is consumed');
  Assert.AreEqual(0, GSendInputCalls, 'storing the prebase injects nothing');

  Assert.IsTrue(HandleKeyEvent(MakeKey(VK_TAB, True)),
    'Tab with a committed flush must be consumed (re-injected in order)');
  Assert.AreEqual(2, GSendInputCalls,
    'the flushed prebase AND the re-injected VK_TAB must have been injected');
end;

initialization
  TDUnitX.RegisterTestFixture(TPassThroughResetTests);

end.
