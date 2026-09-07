unit Tests.Engine.OutputBoundary;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  EngineState,
  ShreeLipi.Engine,
  LayoutModel;

type
  // M2.1 regression coverage: the engine must route every emitted operation
  // (text, backspace, state reset) through the output boundary as discrete
  // actions, so tests can capture engine decisions without any real keyboard
  // injection (working rule #4). Layout glyphs are ASCII so assertions do not
  // depend on source encoding.
  [TestFixture]
  TOutputBoundaryTests = class
  strict private
    FEvents: TStringList;
    FLayout1: TKeyboardLayout;
    FLayout2: TKeyboardLayout;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure DirectConsonant_EmitsSingleTextAction;
    [Test]
    procedure Backspace_NoPending_EmitsBackspaceThenReset;
    [Test]
    procedure Backspace_WithPending_Cancels_EmitsNothing;
    [Test]
    procedure Tab_NoPending_EmitsResetOnly;
    [Test]
    procedure Tab_WithPending_FlushesTextThenReset;
    [Test]
    procedure LiteralFallback_ResetsStateThenEmitsText;
    [Test]
    procedure LayoutSwitch_FlushesTextThenReset;
    [Test]
    procedure EngineDisable_DoesNotEmitThroughBoundary;
  end;

implementation

var
  GEvents: TStringList = nil;

function MakeMapping(const AKey, AGlyph: string): TKeyMapping;
begin
  Result := Default(TKeyMapping);
  Result.Key := AKey;
  Result.Glyph := AGlyph;
end;

function CreateAsciiLayout(const AName: string): TKeyboardLayout;
begin
  Result := TKeyboardLayout.Create;
  Result.Name := AName;
  Result.DirectMap.Add('k', 'K');
  Result.DirectMap.Add('t', 'T');
  Result.PrebaseMap.Add('i', MakeMapping('i', 'I'));
  Result.PostbaseMap.Add('a', 'A');
  Result.Modifiers.Add('halant', MakeMapping('-', 'H'));
  Result.Modifiers.Add('reph', MakeMapping('R', 'R'));
end;

procedure CaptureAction(const AAction: TEngineOutputAction; const AText: string);
begin
  if not Assigned(GEvents) then
    Exit;

  case AAction Of
    eoEmitText:      GEvents.Add('T:' + AText);
      eoEmitBackspace:   GEvents.Add('B');
      eoResetState:       GEvents.Add('R');
    end;
end;

procedure TOutputBoundaryTests.Setup;
begin
  InitEngineState;
  SetEngineEnabled(True);

  FEvents := TStringList.Create;
  GEvents := FEvents;
  SetEngineOutputHandler(CaptureAction);

  FLayout1 := CreateAsciiLayout('BoundaryLayout1');
  FLayout2 := CreateAsciiLayout('BoundaryLayout2');
  SetActiveLayout(FLayout1);
  ResetEngineState;
  FEvents.Clear;   // setup must not contaminate the assertions
end;

procedure TOutputBoundaryTests.TearDown;
begin
  ResetEngineState;   // clear pending so no flush can emit during teardown
  SetActiveLayout(nil);
  SetEngineOutputHandler(nil);
  GEvents := nil;
  FEvents.Free;
  FLayout1.Free;
  FLayout2.Free;
end;

procedure TOutputBoundaryTests.DirectConsonant_EmitsSingleTextAction;
begin
  ProcessKeyChar('k');

  Assert.AreEqual(1, FEvents.Count, 'direct consonant must emit exactly one action');
  Assert.AreEqual('T:K', FEvents[0], 'the action must be Emit Unicode text');
end;

procedure TOutputBoundaryTests.Backspace_NoPending_EmitsBackspaceThenReset;
begin
  ProcessKeyChar('k');   // establish a cluster
  FEvents.Clear;
  ProcessKeyChar(#8);    // no pending → real backspace through the boundary

  Assert.AreEqual(2, FEvents.Count);
  Assert.AreEqual('B', FEvents[0], 'backspace decision must cross the boundary');
  Assert.AreEqual('R', FEvents[1], 'state reset must follow the backspace');
end;

procedure TOutputBoundaryTests.Backspace_WithPending_Cancels_EmitsNothing;
begin
  ProcessKeyChar('k');   // K
  ProcessKeyChar('i');   // pending I
  FEvents.Clear;
  ProcessKeyChar(#8);    // cancels the pending prebase

  Assert.AreEqual(0, FEvents.Count,
    'cancelling pending state must not emit through the boundary');
  Assert.AreEqual('', gEngineState.PendingPrebase);
end;

procedure TOutputBoundaryTests.Tab_NoPending_EmitsResetOnly;
begin
  ProcessKeyChar('k');
  FEvents.Clear;
  ProcessKeyChar(#9);

  Assert.AreEqual(1, FEvents.Count);
  Assert.AreEqual('R', FEvents[0], 'Tab must reset state through the boundary');
end;

procedure TOutputBoundaryTests.Tab_WithPending_FlushesTextThenReset;
begin
  ProcessKeyChar('k');   // K
  ProcessKeyChar('i');   // pending I
  FEvents.Clear;
  ProcessKeyChar(#9);    // Tab commits the pending text, then resets

  Assert.AreEqual(2, FEvents.Count);
  Assert.AreEqual('T:I', FEvents[0], 'pending prebase must be flushed on Tab');
  Assert.AreEqual('R', FEvents[1]);
end;

procedure TOutputBoundaryTests.LiteralFallback_ResetsStateThenEmitsText;
begin
  ProcessKeyChar('k');   // K
  ProcessKeyChar('i');   // pending I
  FEvents.Clear;
  ProcessKeyChar(' ');   // literal fallback

  Assert.AreEqual(3, FEvents.Count);
  Assert.AreEqual('T:I', FEvents[0], 'pending prebase must be flushed before fallback');
  Assert.AreEqual('R', FEvents[1], 'state must be reset before the literal is emitted');
  Assert.AreEqual('T: ', FEvents[2], 'the literal key must be emitted as text');
end;

procedure TOutputBoundaryTests.LayoutSwitch_FlushesTextThenReset;
begin
  ProcessKeyChar('k');   // K (layout1)
  ProcessKeyChar('i');   // pending I (layout1)
  FEvents.Clear;
  SetActiveLayout(FLayout2);

  Assert.AreEqual(2, FEvents.Count);
  Assert.AreEqual('T:I', FEvents[0], 'pending prebase must be flushed on layout switch');
  Assert.AreEqual('R', FEvents[1], 'layout switch must reset state through the boundary');
  Assert.AreEqual('', gEngineState.PendingPrebase);
end;

procedure TOutputBoundaryTests.EngineDisable_DoesNotEmitThroughBoundary;
begin
  ProcessKeyChar('k');   // K
  ProcessKeyChar('i');   // pending I
  FEvents.Clear;
  SetEngineEnabled(False);

  Assert.AreEqual(0, FEvents.Count,
    'engine disable resets state inside EngineState, not through the boundary');
  Assert.AreEqual('', gEngineState.PendingPrebase);
end;

initialization
  TDUnitX.RegisterTestFixture(TOutputBoundaryTests);

end.