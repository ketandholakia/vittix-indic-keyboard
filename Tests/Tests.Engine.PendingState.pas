unit Tests.Engine.PendingState;

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
  // M1.1 regression coverage: the engine must commit (flush) consumed pending
  // prebase/reph state at every normal transliteration boundary (direct,
  // postbase, halant, literal fallback, Tab, Enter, layout switch) and cancel it
  // without emitting only on an explicit user request (Backspace, engine
  // disable). These tests run the engine against capture hooks instead of the
  // real SendInput helper so no real keystrokes are sent (working rule #4).
  [TestFixture]
  TPendingStateTests = class
  strict private
    FOutput: TStringList;
    FLayout1: TKeyboardLayout;
    FLayout2: TKeyboardLayout;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Prebase_CommitOnTab;
    [Test]
    procedure Prebase_CommitOnEnter;
    [Test]
    procedure Reph_CommitOnTab;
    [Test]
    procedure Backspace_CancelsPendingPrebase_WithoutEmit;
    [Test]
    procedure Backspace_CancelsPendingReph_WithoutEmit;
    [Test]
    procedure Prebase_CommitOnDirectConsonant;
    [Test]
    procedure Prebase_CommitOnPostbase;
    [Test]
    procedure Prebase_CommitOnHalant;
    [Test]
    procedure Prebase_CommitOnLiteralFallback;
    [Test]
    procedure LayoutSwitch_CommitsPendingPrebase;
    [Test]
    procedure EngineDisable_DiscardsPendingOnExplicitExit;
  end;

implementation

var
  // Shared state between the plain hook procedure and the fixture instance.
  GOutput: TStringList = nil;

function MakeMapping(const AKey, AGlyph: string): TKeyMapping;
begin
  Result := Default(TKeyMapping);
  Result.Key := AKey;
  Result.Glyph := AGlyph;
  // Metadata intentionally left nil: TKeyboardLayout.Destroy calls
  // FreeMetadata, which guards on Assigned(Metadata).
end;

function CreateLayout(const AName: string): TKeyboardLayout;
begin
  Result := TKeyboardLayout.Create;
  Result.Name := AName;
  Result.DirectMap.Add('k', 'क');
  Result.DirectMap.Add('t', 'त');
  Result.PrebaseMap.Add('i', MakeMapping('i', 'ि'));
  Result.PostbaseMap.Add('a', 'ा');
  Result.Modifiers.Add('halant', MakeMapping('-', '्'));
  Result.Modifiers.Add('reph', MakeMapping('R', 'र्'));
end;

procedure CaptureAction(const AAction: TEngineOutputAction; const AText: string);
begin
  // Only eoEmitText carries the translated text the M1.1 assertions check。
  // Backspace/reset actions carry no text and are ignored here。
  if AAction = eoEmitText then
    if Assigned(GOutput) then
      GOutput.Add(AText);
end;

procedure TPendingStateTests.Setup;
begin
  InitEngineState;
  SetEngineEnabled(True);

  FOutput := TStringList.Create;
  GOutput := FOutput;
  SetEngineOutputHandler(CaptureAction);

  FLayout1 := CreateLayout('TestLayout1');
  FLayout2 := CreateLayout('TestLayout2');
  SetActiveLayout(FLayout1);
  ResetEngineState;
end;

procedure TPendingStateTests.TearDown;
begin
  ResetEngineState;   // clear pending so no flush can emit during teardown
  SetActiveLayout(nil);
  SetEngineOutputHandler(nil);
  GOutput := nil;
  FOutput.Free;
  FLayout1.Free;
  FLayout2.Free;
end;

procedure TPendingStateTests.Prebase_CommitOnTab;
begin
  ProcessKeyChar('k');   // direct → क
  ProcessKeyChar('i');   // pending prebase ि
  ProcessKeyChar(#9);    // Tab → must flush ि before reset

  Assert.AreEqual(2, FOutput.Count, 'pending ि must not be lost on Tab');
  Assert.AreEqual('क', FOutput[0]);
  Assert.AreEqual('ि', FOutput[1]);
  Assert.AreEqual('', gEngineState.PendingPrebase);
end;

procedure TPendingStateTests.Prebase_CommitOnEnter;
begin
  ProcessKeyChar('k');   // direct → क
  ProcessKeyChar('i');   // pending prebase ि
  ProcessKeyChar(#13);   // Enter → must flush ि before reset

  Assert.AreEqual(2, FOutput.Count, 'pending ि must not be lost on Enter');
  Assert.AreEqual('क', FOutput[0]);
  Assert.AreEqual('ि', FOutput[1]);
  Assert.AreEqual('', gEngineState.PendingPrebase);
end;

procedure TPendingStateTests.Reph_CommitOnTab;
begin
  ProcessKeyChar('k');   // direct → क
  ProcessKeyChar('R');   // pending reph
  ProcessKeyChar(#9);    // Tab → must flush the reph glyph before reset

  Assert.AreEqual(2, FOutput.Count, 'pending reph must not be lost on Tab');
  Assert.AreEqual('क', FOutput[0]);
  Assert.AreEqual('र्', FOutput[1]);
  Assert.IsFalse(gEngineState.PendingReph, 'reph must be cleared after Tab');
end;

procedure TPendingStateTests.Backspace_CancelsPendingPrebase_WithoutEmit;
begin
  ProcessKeyChar('k');   // direct → क
  ProcessKeyChar('i');   // pending prebase ि
  ProcessKeyChar(#8);    // Backspace cancels one pending state without emitting

  Assert.AreEqual('', gEngineState.PendingPrebase, 'pending prebase must be cancelled');
  Assert.AreEqual(1, FOutput.Count, 'Backspace must not flush or emit the pending ि');
  Assert.AreEqual('क', FOutput[0]);
end;

procedure TPendingStateTests.Backspace_CancelsPendingReph_WithoutEmit;
begin
  ProcessKeyChar('k');   // direct → क
  ProcessKeyChar('R');   // pending reph
  ProcessKeyChar(#8);    // Backspace cancels one pending state without emitting

  Assert.IsFalse(gEngineState.PendingReph, 'pending reph must be cancelled');
  Assert.AreEqual(1, FOutput.Count, 'Backspace must not flush or emit the reph glyph');
  Assert.AreEqual('क', FOutput[0]);
end;

procedure TPendingStateTests.Prebase_CommitOnDirectConsonant;
begin
  ProcessKeyChar('k');   // → क
  ProcessKeyChar('i');   // pending ि
  ProcessKeyChar('t');   // direct → flush ि then emit त

  Assert.AreEqual('', gEngineState.PendingPrebase);
  Assert.AreEqual(3, FOutput.Count);
  Assert.AreEqual('क', FOutput[0]);
  Assert.AreEqual('ि', FOutput[1]);
  Assert.AreEqual('त', FOutput[2]);
end;

procedure TPendingStateTests.Prebase_CommitOnPostbase;
begin
  ProcessKeyChar('k');   // → क
  ProcessKeyChar('i');   // pending ि
  ProcessKeyChar('a');   // postbase → flush ि then emit ा

  Assert.AreEqual('', gEngineState.PendingPrebase);
  Assert.AreEqual(3, FOutput.Count);
  Assert.AreEqual('क', FOutput[0]);
  Assert.AreEqual('ि', FOutput[1]);
  Assert.AreEqual('ा', FOutput[2]);
end;

procedure TPendingStateTests.Prebase_CommitOnHalant;
begin
  ProcessKeyChar('k');   // → क
  ProcessKeyChar('i');   // pending ि
  ProcessKeyChar('-');   // halant → flush ि then emit ्

  Assert.AreEqual('', gEngineState.PendingPrebase);
  Assert.AreEqual(3, FOutput.Count);
  Assert.AreEqual('क', FOutput[0]);
  Assert.AreEqual('ि', FOutput[1]);
  Assert.AreEqual('्', FOutput[2]);
end;

procedure TPendingStateTests.Prebase_CommitOnLiteralFallback;
begin
  ProcessKeyChar('k');   // → क
  ProcessKeyChar('i');   // pending ि
  ProcessKeyChar(' ');   // literal fallback → flush ि then emit space

  Assert.AreEqual('', gEngineState.PendingPrebase);
  Assert.AreEqual(3, FOutput.Count);
  Assert.AreEqual('क', FOutput[0]);
  Assert.AreEqual('ि', FOutput[1]);
  Assert.AreEqual(' ', FOutput[2]);
end;

procedure TPendingStateTests.LayoutSwitch_CommitsPendingPrebase;
begin
  ProcessKeyChar('k');   // → क (layout1)
  ProcessKeyChar('i');   // pending ि (layout1)
  SetActiveLayout(FLayout2);

  // The pending prebase is committed with the OLD layout's glyph before the
  // switch, so input typed in the previous layout is not silently dropped.
  Assert.AreEqual(2, FOutput.Count, 'pending ि must be flushed on layout switch');
  Assert.AreEqual('क', FOutput[0]);
  Assert.AreEqual('ि', FOutput[1]);
  Assert.AreEqual('', gEngineState.PendingPrebase);
  Assert.IsTrue(EngineHasActiveLayout);
end;

procedure TPendingStateTests.EngineDisable_DiscardsPendingOnExplicitExit;
begin
  ProcessKeyChar('k');   // → क
  ProcessKeyChar('i');   // pending ि
  SetEngineEnabled(False);  // explicit mode exit → pending is cancelled, not flushed

  Assert.AreEqual('', gEngineState.PendingPrebase,
    'pending prebase must be cleared when the engine is disabled');
  Assert.AreEqual(1, FOutput.Count,
    'engine disable is an explicit exit: pending ि is discarded, not emitted');
  Assert.AreEqual('क', FOutput[0]);
end;

initialization
  TDUnitX.RegisterTestFixture(TPendingStateTests);

end.