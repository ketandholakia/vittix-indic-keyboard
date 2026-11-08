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
    procedure LayoutSwitchToNil_FlushesPendingReph;
    [Test]
    procedure Postbase_AfterConsonant_PostbaseGlyphWins;
    [Test]
    procedure Postbase_NoConsonant_DirectGlyphWins;
    [Test]
    procedure Postbase_MatraEndsTheClusterContext;
    [Test]
    procedure Postbase_LiteralFallbackClearsTheClusterContext;
    [Test]
    procedure Postbase_TabClearsTheClusterContext;
    [Test]
    procedure Postbase_BackspaceClearsTheClusterContext;
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
  // The key 'a' exists in BOTH maps with different glyphs, mirroring the legacy
  // layouts (direct = standalone vowel glyph, postbase = matra glyph). Only the
  // direct side is reachable today; the contextual postbase tests pin the fix.
  Result.DirectMap.Add('a', 'AVowel');
  Result.PrebaseMap.Add('i', MakeMapping('i', 'I'));
  Result.PostbaseMap.Add('a', 'AMatra');
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

// Regression (reload use-after-free): the tray detaches the engine with
// SetActiveLayout(nil) BEFORE the layout manager frees the old layout objects.
// The flush must run while the old layout is still alive, and afterwards no
// pending state may survive on a nil layout.
procedure TOutputBoundaryTests.LayoutSwitchToNil_FlushesPendingReph;
begin
  ProcessKeyChar('k');   // K
  ProcessKeyChar('R');   // pending reph (layout1)
  Assert.IsTrue(gEngineState.PendingReph, 'setup: reph must be pending');
  FEvents.Clear;
  SetActiveLayout(nil);

  Assert.AreEqual(2, FEvents.Count);
  Assert.AreEqual('T:R', FEvents[0],
    'pending reph must be flushed through the still-valid old layout before detach');
  Assert.AreEqual('R', FEvents[1], 'detaching must reset state through the boundary');
  Assert.IsFalse(gEngineState.PendingReph, 'no pending state may survive the detach');
end;

// Contextual postbase (item 2): after a consonant, a key present in both the
// direct and the postbase map must produce the matra glyph, not the standalone
// glyph. Unicode layouts keep the two maps disjoint, so they are unaffected.
procedure TOutputBoundaryTests.Postbase_AfterConsonant_PostbaseGlyphWins;
begin
  ProcessKeyChar('k');   // K (consonant: cluster context active)
  ProcessKeyChar('a');   // contextually: the aa-matra, not the standalone vowel

  Assert.AreEqual(2, FEvents.Count);
  Assert.AreEqual('T:K', FEvents[0]);
  Assert.AreEqual('T:AMatra', FEvents[1],
    'after a consonant the postbase (matra) glyph must win over the direct glyph');
end;

procedure TOutputBoundaryTests.Postbase_NoConsonant_DirectGlyphWins;
begin
  ProcessKeyChar('a');   // no consonant before it: plain standalone glyph

  Assert.AreEqual(1, FEvents.Count);
  Assert.AreEqual('T:AVowel', FEvents[0],
    'without a preceding consonant the direct glyph must win');
end;

procedure TOutputBoundaryTests.Postbase_MatraEndsTheClusterContext;
begin
  ProcessKeyChar('k');   // K
  ProcessKeyChar('a');   // AMatra (contextual)
  ProcessKeyChar('a');   // the matra is not a consonant: back to the direct glyph

  Assert.AreEqual(3, FEvents.Count);
  Assert.AreEqual('T:AMatra', FEvents[1]);
  Assert.AreEqual('T:AVowel', FEvents[2],
    'emitting a matra must clear the cluster context');
end;

procedure TOutputBoundaryTests.Postbase_LiteralFallbackClearsTheClusterContext;
begin
  ProcessKeyChar('k');   // K
  ProcessKeyChar(' ');   // literal fallback (space)
  ProcessKeyChar('a');   // no longer contextual

  Assert.AreEqual(4, FEvents.Count);
  Assert.AreEqual('T:AVowel', FEvents[3],
    'a literal fallback must clear the cluster context');
end;

procedure TOutputBoundaryTests.Postbase_TabClearsTheClusterContext;
begin
  ProcessKeyChar('k');   // K
  ProcessKeyChar(#9);    // Tab
  ProcessKeyChar('a');   // no longer contextual

  Assert.AreEqual(3, FEvents.Count);
  Assert.AreEqual('T:AVowel', FEvents[2],
    'Tab must clear the cluster context');
end;

procedure TOutputBoundaryTests.Postbase_BackspaceClearsTheClusterContext;
begin
  ProcessKeyChar('k');   // K
  ProcessKeyChar(#8);    // real backspace deletes the consonant
  ProcessKeyChar('a');   // no longer contextual

  Assert.AreEqual(4, FEvents.Count);
  Assert.AreEqual('B', FEvents[1]);
  Assert.AreEqual('T:AVowel', FEvents[3],
    'a real backspace must clear the cluster context');
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