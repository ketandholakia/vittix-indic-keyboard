unit Tests.Engine.InjectionOutcome;

interface

uses
  DUnitX.TestFramework,
  Winapi.Windows,
  EngineState,
  LayoutModel,
  ShreeLipi.Engine,
  SendInputHelper;

type
  [TestFixture]
  TEngineInjectionOutcomeTests = class
  private
    FLayout: TKeyboardLayout;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure DirectZeroAcceptance_ResetsEngineState;
    [Test]
    procedure BackspacePartialAcceptance_ResetsEngineState;
    [Test]
    procedure PendingPrelude_SuccessThenZero_IsPartialEquivalent;
    [Test]
    procedure Combine_PassThroughAlone_StaysPassThrough;
    [Test]
    procedure Combine_PassThroughWithEmitted_EmittedWins;
    [Test]
    procedure Combine_PassThroughWithFailure_FailureWins;
    [Test]
    procedure Backspace_MultiUnitGlyph_SubmitsSixBackspaceRecords;
  end;

implementation

var
  GReturns: TArray<UINT>;
  GCallIndex: Integer;
  GCapturedCount: UINT = 0;
  GCapturedFirstVK: Word = 0;

function FakeSendInput(cInputs: UINT; pInputs: PInput; cbSize: Integer): UINT; stdcall;
begin
  GCapturedCount := cInputs;
  if (cInputs > 0) and (pInputs <> nil) then
    GCapturedFirstVK := PInput(pInputs)^.ki.wVk;
  if GCallIndex <= High(GReturns) then
    Result := GReturns[GCallIndex]
  else
    Result := cInputs;
  Inc(GCallIndex);
end;

function Mapping(const AKey, AGlyph: string): TKeyMapping;
begin
  Result := Default(TKeyMapping);
  Result.Key := AKey;
  Result.Glyph := AGlyph;
end;

procedure TEngineInjectionOutcomeTests.Setup;
begin
  InitEngineState;
  SetEngineEnabled(True);
  SetLength(GReturns, 0);
  GCallIndex := 0;
  GCapturedCount := 0;
  GCapturedFirstVK := 0;
  SetSendInputHook(FakeSendInput);
  SetEngineOutputHandler(nil);
  FLayout := TKeyboardLayout.Create;
  FLayout.DirectMap.Add('k', 'K');
  FLayout.PrebaseMap.Add('i', Mapping('i', 'I'));
  SetActiveLayout(FLayout);
  ResetEngineState;
  ResetInjectionStatus;
end;

procedure TEngineInjectionOutcomeTests.TearDown;
begin
  ResetEngineState;
  SetActiveLayout(nil);
  SetSendInputHook(nil);
  ResetInjectionStatus;
  FLayout.Free;
end;

procedure TEngineInjectionOutcomeTests.DirectZeroAcceptance_ResetsEngineState;
begin
  GReturns := TArray<UINT>.Create(0);
  Assert.AreEqual(ioZeroAccepted, ProcessKeyChar('k'));
  Assert.IsFalse(InjectionOK);
  Assert.AreEqual('', gEngineState.CurrentCluster);
  Assert.AreEqual('', gEngineState.PendingPrebase);
end;

procedure TEngineInjectionOutcomeTests.BackspacePartialAcceptance_ResetsEngineState;
begin
  GReturns := TArray<UINT>.Create(1); // one of a virtual-key down/up pair
  Assert.AreEqual(ioPartialAccepted, ProcessKeyChar(#8));
  Assert.IsFalse(InjectionOK);
  Assert.AreEqual('', gEngineState.CurrentCluster);
  Assert.AreEqual('', gEngineState.PendingPrebase);
end;

procedure TEngineInjectionOutcomeTests.PendingPrelude_SuccessThenZero_IsPartialEquivalent;
begin
  ProcessKeyChar('i');
  GReturns := TArray<UINT>.Create(2, 0); // prelude succeeds, glyph accepts zero
  GCallIndex := 0;
  Assert.AreEqual(ioPartialAccepted, ProcessKeyChar('k'));
  Assert.IsFalse(InjectionOK);
  Assert.AreEqual('', gEngineState.PendingPrebase);
  Assert.AreEqual('', gEngineState.CurrentCluster);
end;

// Item 4: ioPassThrough means "let the original physical key through". It only
// survives a combination when nothing was emitted and nothing failed.
procedure TEngineInjectionOutcomeTests.Combine_PassThroughAlone_StaysPassThrough;
begin
  Assert.AreEqual(ioPassThrough, CombineInjectionOutcomes(ioNoOutput, ioPassThrough));
  Assert.AreEqual(ioPassThrough, CombineInjectionOutcomes(ioPassThrough, ioNoOutput));
  Assert.AreEqual(ioPassThrough, CombineInjectionOutcomes(ioPassThrough, ioPassThrough));
end;

procedure TEngineInjectionOutcomeTests.Combine_PassThroughWithEmitted_EmittedWins;
begin
  // Once output exists the original key can no longer pass through natively.
  Assert.AreEqual(ioSuccess, CombineInjectionOutcomes(ioPassThrough, ioSuccess));
  Assert.AreEqual(ioSuccess, CombineInjectionOutcomes(ioSuccess, ioPassThrough));
  Assert.AreEqual(ioZeroAccepted, CombineInjectionOutcomes(ioPassThrough, ioZeroAccepted));
  Assert.AreEqual(ioZeroAccepted, CombineInjectionOutcomes(ioZeroAccepted, ioPassThrough));
end;

procedure TEngineInjectionOutcomeTests.Combine_PassThroughWithFailure_FailureWins;
begin
  Assert.AreEqual(ioPartialAccepted, CombineInjectionOutcomes(ioPassThrough, ioPartialAccepted));
  Assert.AreEqual(ioPartialAccepted, CombineInjectionOutcomes(ioPartialAccepted, ioPassThrough));
end;

// Item 6, physical level: a three-unit glyph followed by one Backspace must
// submit SendBackspace(3) — six VK_BACK records through the boundary.
procedure TEngineInjectionOutcomeTests.Backspace_MultiUnitGlyph_SubmitsSixBackspaceRecords;
begin
  FLayout.DirectMap.Add('s', 'SSS');
  Assert.AreEqual(ioSuccess, ProcessKeyChar('s'));

  GCapturedCount := 0;
  GCapturedFirstVK := 0;
  Assert.AreEqual(ioSuccess, ProcessKeyChar(#8));
  Assert.AreEqual(6, Integer(GCapturedCount),
    'SendBackspace(3) submits three down/up pairs');
  Assert.AreEqual(Word(VK_BACK), GCapturedFirstVK,
    'the submitted records are backspaces');
end;

initialization
  TDUnitX.RegisterTestFixture(TEngineInjectionOutcomeTests);

end.
