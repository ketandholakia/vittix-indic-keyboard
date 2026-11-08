unit Tests.Engine.OutputBoundary;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  EngineState,
  SendInputHelper,
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
    procedure Backspace_NoPending_EmitsBackspaceThroughBoundary;
    [Test]
    procedure Backspace_WithPending_Cancels_EmitsNothing;
    [Test]
    procedure Backspace_MultiUnitGlyph_SendsUnitCount;
    [Test]
    procedure Backspace_Chain_PopsEachGlyphInOrder;
    [Test]
    procedure Backspace_AfterNavigationClearsStack_SendsSingleBackspace;
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
    procedure ResetPendingOnPassThrough_ClearsPendingWithoutEmitting;
    [Test]
    procedure Reph_WhileRephPending_FlushesFirst;
    [Test]
    procedure Prebase_WhilePrebasePending_FlushesFirst;
    [Test]
    procedure Prebase_WhileRephPending_FlushesReph;
    [Test]
    procedure EngineDisabled_ReturnsPassThrough;
    [Test]
    procedure NoActiveLayout_ReturnsPassThrough;
    [Test]
    procedure LiteralFallback_NoPending_PassesThrough_WithoutEmitting;
    [Test]
    procedure Tab_NoPending_ReturnsPassThrough;
    [Test]
    procedure Enter_NoPending_ReturnsPassThrough;
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
  // 's' emits a three-unit glyph, mirroring the legacy layouts where one key
  // produces a multi-character legacy-font sequence (item 6).
  Result.DirectMap.Add('s', 'SSS');
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
    eoEmitBackspace:
      // '' = single backspace; a numeric payload carries the multi-unit count.
      if AText = '' then
        GEvents.Add('B')
      else
        GEvents.Add('B' + AText);
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

// A single-unit glyph deletes with one backspace, and the backspace decision
// crosses the boundary. No reset event: the emitted-length stack must survive
// a backspace chain (item 6), so the per-backspace reset was replaced by
// targeted state clears.
procedure TOutputBoundaryTests.Backspace_NoPending_EmitsBackspaceThroughBoundary;
begin
  ProcessKeyChar('k');   // establish a cluster
  FEvents.Clear;
  ProcessKeyChar(#8);    // no pending → real backspace through the boundary

  Assert.AreEqual(1, FEvents.Count);
  Assert.AreEqual('B', FEvents[0],
    'a one-unit glyph must delete with a single backspace');
end;

// Item 6: a glyph spanning several UTF-16 units must delete with one
// backspace per unit — the boundary carries the count in the payload.
procedure TOutputBoundaryTests.Backspace_MultiUnitGlyph_SendsUnitCount;
begin
  ProcessKeyChar('s');   // emits the three-unit glyph SSS
  FEvents.Clear;
  ProcessKeyChar(#8);

  Assert.AreEqual(1, FEvents.Count);
  Assert.AreEqual('B3', FEvents[0],
    'a three-unit glyph must delete with three backspaces');
end;

// The stack pops in emission order and survives individual backspaces, so a
// multi-unit glyph followed by a single-unit glyph deletes correctly in both
// directions.
procedure TOutputBoundaryTests.Backspace_Chain_PopsEachGlyphInOrder;
begin
  ProcessKeyChar('s');   // SSS (3 units)
  ProcessKeyChar('k');   // K   (1 unit)
  FEvents.Clear;
  ProcessKeyChar(#8);    // deletes K: one backspace
  ProcessKeyChar(#8);    // deletes SSS: three backspaces

  Assert.AreEqual(2, FEvents.Count);
  Assert.AreEqual('B', FEvents[0], 'the single-unit glyph deletes with 1');
  Assert.AreEqual('B3', FEvents[1], 'the three-unit glyph deletes with 3');
end;

// Navigation/foreground resets clear the emitted-length stack; the next
// backspace then falls back to the safe single backspace.
procedure TOutputBoundaryTests.Backspace_AfterNavigationClearsStack_SendsSingleBackspace;
begin
  ProcessKeyChar('s');   // SSS (3 units)
  ResetPendingOnPassThrough;
  FEvents.Clear;
  ProcessKeyChar(#8);

  Assert.AreEqual(1, FEvents.Count);
  Assert.AreEqual('B', FEvents[0],
    'after a stack reset the backspace count is unknown: fail-safe 1');
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
  // Item 4: Tab with nothing pending passes through natively — and a
  // pass-through emits NOTHING through the boundary. State (including the
  // cluster context) is cleared directly.
  Assert.AreEqual(ioPassThrough, ProcessKeyChar(#9));
  Assert.AreEqual(0, FEvents.Count);
  Assert.AreEqual('', gEngineState.CurrentCluster,
    'Tab must still clear the cluster context');
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
  ProcessKeyChar(' ');   // literal fallback: nothing pending -> pass-through, no events
  ProcessKeyChar('a');   // no longer contextual

  Assert.AreEqual(2, FEvents.Count);
  Assert.AreEqual('T:AVowel', FEvents[1],
    'a literal fallback must clear the cluster context');
end;

procedure TOutputBoundaryTests.Postbase_TabClearsTheClusterContext;
begin
  ProcessKeyChar('k');   // K
  ProcessKeyChar(#9);    // Tab: nothing pending -> pass-through, no events
  ProcessKeyChar('a');   // no longer contextual

  Assert.AreEqual(2, FEvents.Count);
  Assert.AreEqual('T:AVowel', FEvents[1],
    'Tab must clear the cluster context');
end;

procedure TOutputBoundaryTests.Postbase_BackspaceClearsTheClusterContext;
begin
  ProcessKeyChar('k');   // K
  ProcessKeyChar(#8);    // real backspace deletes the consonant
  ProcessKeyChar('a');   // no longer contextual

  Assert.AreEqual(3, FEvents.Count);
  Assert.AreEqual('B', FEvents[1]);
  Assert.AreEqual('T:AVowel', FEvents[2],
    'a real backspace must clear the cluster context');
end;

// Item 3: keys that pass through the hook (navigation, shortcuts, foreground
// changes) must clear pending state WITHOUT emitting anything, so a stale
// matra/reph can never leak into unrelated input.
procedure TOutputBoundaryTests.ResetPendingOnPassThrough_ClearsPendingWithoutEmitting;
begin
  ProcessKeyChar('k');   // K
  ProcessKeyChar('R');   // pending reph
  ProcessKeyChar('i');   // pending prebase (reph stays pending behind it)
  FEvents.Clear;
  ResetPendingOnPassThrough;

  Assert.AreEqual(0, FEvents.Count, 'the reset must not emit anything');
  Assert.AreEqual('', gEngineState.PendingPrebase, 'pending prebase must be cleared');
  Assert.IsFalse(gEngineState.PendingReph, 'pending reph must be cleared');
  Assert.AreEqual('', gEngineState.CurrentCluster, 'the cluster context must be cleared');
end;

// Item 4a: a disabled engine or a missing layout must NOT report success —
// that made the hook consume the key with no output. Fail open instead.
// Item 7: pressing a prebase/reph key while one is already pending must flush
// the FIRST one instead of silently overwriting it.
procedure TOutputBoundaryTests.Reph_WhileRephPending_FlushesFirst;
begin
  ProcessKeyChar('R');   // pending reph
  ProcessKeyChar('R');   // second press: flush the first, then pend again

  Assert.AreEqual(1, FEvents.Count);
  Assert.AreEqual('T:R', FEvents[0], 'the first pending reph must be flushed');
  Assert.IsTrue(gEngineState.PendingReph, 'the second press stays pending');
end;

procedure TOutputBoundaryTests.Prebase_WhilePrebasePending_FlushesFirst;
begin
  ProcessKeyChar('i');   // pending prebase I
  ProcessKeyChar('i');   // second press: flush the first, then pend again

  Assert.AreEqual(1, FEvents.Count);
  Assert.AreEqual('T:I', FEvents[0], 'the first pending prebase must be flushed');
  Assert.AreEqual('I', gEngineState.PendingPrebase, 'the second press stays pending');
end;

procedure TOutputBoundaryTests.Prebase_WhileRephPending_FlushesReph;
begin
  ProcessKeyChar('R');   // pending reph
  ProcessKeyChar('i');   // prebase key: flush the reph, then pend the prebase

  Assert.AreEqual(1, FEvents.Count);
  Assert.AreEqual('T:R', FEvents[0], 'the pending reph must be flushed first');
  Assert.AreEqual('I', gEngineState.PendingPrebase, 'the prebase stays pending');
end;

procedure TOutputBoundaryTests.EngineDisabled_ReturnsPassThrough;
begin
  SetEngineEnabled(False);
  Assert.AreEqual(ioPassThrough, ProcessKeyChar('k'),
    'a disabled engine must return pass-through, not success');
end;

procedure TOutputBoundaryTests.NoActiveLayout_ReturnsPassThrough;
begin
  SetActiveLayout(nil);
  Assert.AreEqual(ioPassThrough, ProcessKeyChar('k'),
    'a missing layout must return pass-through, not success');
end;

// Item 4b: with nothing pending and nothing emitted, the literal fallback must
// not re-inject the character — the original key passes through natively.
procedure TOutputBoundaryTests.LiteralFallback_NoPending_PassesThrough_WithoutEmitting;
begin
  Assert.AreEqual(ioPassThrough, ProcessKeyChar('x'),
    'an unmapped key with no pending state must pass through');
  Assert.AreEqual(0, FEvents.Count,
    'pass-through must not emit anything through the boundary');
end;

procedure TOutputBoundaryTests.Tab_NoPending_ReturnsPassThrough;
begin
  Assert.AreEqual(ioPassThrough, ProcessKeyChar(#9),
    'Tab with nothing pending must pass through natively');
  Assert.AreEqual(0, FEvents.Count,
    'a pass-through emits nothing through the boundary');
end;

procedure TOutputBoundaryTests.Enter_NoPending_ReturnsPassThrough;
begin
  Assert.AreEqual(ioPassThrough, ProcessKeyChar(#13),
    'Enter with nothing pending must pass through natively');
  Assert.AreEqual(0, FEvents.Count,
    'a pass-through emits nothing through the boundary');
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