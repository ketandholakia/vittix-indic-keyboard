unit Tests.Keyboard.ControlKeyOrdering;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  EngineState,
  LayoutModel,
  ShreeLipi.Engine,
  SendInputHelper,
  KeyboardHook;

type
  // Item (Tab/Enter ordering): when a pending matra/reph is committed ON a
  // Tab/Enter, the injected text is queued after the physical control key
  // that is still in flight, so the matra would land in the field the
  // Tab/Enter moved TO. The hook must consume the key and re-inject it in
  // order (Shift preserved). Verified against a RECORDING fake SendInput:
  // every INPUT record is captured in order — no real keystrokes are sent
  // (working rule #4).
  [TestFixture]
  TControlKeyOrderingTests = class
  private
    FLayout: TKeyboardLayout;
    function DoEngineKey(const AChar: string): TInjectionOutcome;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure PendingPrebase_Enter_ReinjectsKeyAfterTheMatra;
    [Test]
    procedure PendingPrebase_ShiftTab_ReinjectionKeepsShiftAroundTab;
    [Test]
    procedure NoPending_Tab_PassesThroughNatively_NothingReinjected;
  end;

implementation

uses
  System.Generics.Collections;

const
  VK_TAG_NONE = 0;

var
  // One human-readable line per submitted INPUT record, in submission order:
  // 'U:0049' (Unicode char $0049 down), 'U:0049/up', 'VK:0d' (VK_RETURN down),
  // 'VK:0d/up', 'VK:10' (VK_SHIFT down)...
  GRecords: TStringList = nil;
  // The physical modifier snapshot the hook reads (settable per test).
  GFakeMods: TKeyModifierState;

function RecordingSendInput(cInputs: UINT; pInputs: PInput;
  cbSize: Integer): UINT; stdcall;
var
  I: Integer;
  Flags: DWORD;
  S: string;
begin
  for I := 0 to Integer(cInputs) - 1 do
  begin
    Flags := PInput(PByte(pInputs) + I * SizeOf(TInput))^.ki.dwFlags;
    if (Flags and KEYEVENTF_UNICODE) <> 0 then
      S := Format('U:%.4x', [PInput(PByte(pInputs) + I * SizeOf(TInput))^.ki.wScan])
    else
      S := Format('VK:%.2x', [PInput(PByte(pInputs) + I * SizeOf(TInput))^.ki.wVk]);
    if (Flags and KEYEVENTF_KEYUP) <> 0 then
      S := S + '/up';
    GRecords.Add(S);
  end;
  // Accept the exact requested count (healthy injection).
  Result := cInputs;
end;

function TControlKeyOrderingTests.DoEngineKey(const AChar: string): TInjectionOutcome;
begin
  // The production wiring: the hook's key handler IS the engine. A fixture
  // method because TOnKeyChar is a method pointer type.
  Result := ProcessKeyChar(AChar);
end;

function FakeForegroundProcess: string;
begin
  Result := 'notepad.exe';
end;

function FakeModifierState: TKeyModifierState;
begin
  Result := GFakeMods;
end;

function FakeVKToUnicode(VKCode: DWORD; ScanCode: DWORD;
  const Modifiers: TKeyModifierState): string;
begin
  // Good enough for the engine path: the tests drive the engine through
  // 'k' (direct consonant) and 'i' (prebase matra key).
  case VKCode of
    $49: Result := 'i';
    $4B: Result := 'k';
  else
    Result := '';
  end;
end;

function MakeKey(VK: DWORD; AKeyDown: Boolean): TKeyContext;
begin
  Result := Default(TKeyContext);
  Result.VKCode := VK;
  Result.ScanCode := 0;
  Result.IsKeyDown := AKeyDown;
end;

procedure TControlKeyOrderingTests.Setup;
var
  Deps: THookPolicyDependencies;
  Matra: TKeyMapping;
begin
  InitEngineState;
  SetEngineEnabled(True);

  GFakeMods := Default(TKeyModifierState);
  GRecords := TStringList.Create;
  SetSendInputHook(RecordingSendInput);
  SetEngineOutputHandler(nil);

  // A minimal layout: 'k' -> direct consonant 'K', 'i' -> prebase matra 'I'.
  Matra := Default(TKeyMapping);
  Matra.Key := 'i';
  Matra.Glyph := 'I';
  FLayout := TKeyboardLayout.Create;
  FLayout.DirectMap.Add('k', 'K');
  FLayout.PrebaseMap.Add('i', Matra);

  SetActiveLayout(FLayout);
  ResetEngineState;
  ResetInjectionStatus;

  SetKeyHandler(DoEngineKey);
  SetAllowedProcessNames('notepad.exe');
  SetTargetProcessName('');
  SetIgnoreInjectedInput(True);

  Deps := Default(THookPolicyDependencies);
  Deps.GetForegroundProcessName := FakeForegroundProcess;
  Deps.GetModifierState := FakeModifierState;
  Deps.VKToUnicode := FakeVKToUnicode;
  SetHookPolicyDependencies(Deps);
end;

procedure TControlKeyOrderingTests.TearDown;
begin
  SetHookPolicyDependencies(Default(THookPolicyDependencies));
  SetKeyHandler(nil);
  SetEngineOutputHandler(nil);
  SetSendInputHook(nil);
  SetActiveLayout(nil);
  ResetEngineState;
  ResetInjectionStatus;
  FreeAndNil(GRecords);
  FreeAndNil(FLayout);
end;

// The heart of the item: pending prebase + Enter must produce
// [matra, VK_RETURN] in the injected stream, and the physical Enter must be
// consumed (it is re-injected, not passed through).
procedure TControlKeyOrderingTests.PendingPrebase_Enter_ReinjectsKeyAfterTheMatra;
begin
  // 'k': consonant emitted (cluster opens).
  Assert.IsTrue(HandleKeyEvent(MakeKey($4B, True)), 'k must be consumed');
  // 'i': prebase matra becomes pending (consumed, nothing emitted yet).
  Assert.IsTrue(HandleKeyEvent(MakeKey($49, True)), 'i must be consumed');

  GRecords.Clear;
  // Enter: the engine commits the matra, the hook re-injects VK_RETURN.
  Assert.IsTrue(HandleKeyEvent(MakeKey(VK_RETURN, True)),
    'Enter with a committed flush must be consumed (re-injected in order)');

  Assert.AreEqual(4, GRecords.Count,
    'matra down/up + re-injected Enter down/up');
  Assert.AreEqual('U:0049', GRecords[0], 'the matra goes out FIRST');
  Assert.AreEqual('U:0049/up', GRecords[1]);
  Assert.AreEqual('VK:0d', GRecords[2], 'the re-injected Enter follows the matra');
  Assert.AreEqual('VK:0d/up', GRecords[3]);
end;

procedure TControlKeyOrderingTests.PendingPrebase_ShiftTab_ReinjectionKeepsShiftAroundTab;
begin
  GFakeMods.ShiftDown := True;   // the physical Shift is held
  Assert.IsTrue(HandleKeyEvent(MakeKey($4B, True)));
  Assert.IsTrue(HandleKeyEvent(MakeKey($49, True)), 'pending prebase set');

  GRecords.Clear;
  Assert.IsTrue(HandleKeyEvent(MakeKey(VK_TAB, True)),
    'Shift+Tab with a committed flush must be consumed and re-injected');

  Assert.AreEqual(6, GRecords.Count,
    'matra down/up + Shift down + Tab down/up + Shift up');
  Assert.AreEqual('U:0049', GRecords[0], 'the matra goes out FIRST');
  Assert.AreEqual('U:0049/up', GRecords[1]);
  Assert.AreEqual('VK:10', GRecords[2], 'Shift down wraps the re-injected Tab');
  Assert.AreEqual('VK:09', GRecords[3], 'the re-injected Tab follows the matra');
  Assert.AreEqual('VK:09/up', GRecords[4]);
  Assert.AreEqual('VK:10/up', GRecords[5], 'Shift up restores the modifier');
end;

procedure TControlKeyOrderingTests.NoPending_Tab_PassesThroughNatively_NothingReinjected;
begin
  // Fresh engine, nothing pending: the physical Tab passes through untouched
  // and no VK batch is injected at all.
  Assert.IsFalse(HandleKeyEvent(MakeKey(VK_TAB, True)),
    'Tab with nothing pending must pass through natively');
  Assert.AreEqual(0, GRecords.Count,
    'no re-injection may happen when the engine emitted nothing');
end;

initialization
  TDUnitX.RegisterTestFixture(TControlKeyOrderingTests);

end.
