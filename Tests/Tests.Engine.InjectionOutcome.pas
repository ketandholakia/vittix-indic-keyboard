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
  end;

implementation

var
  GReturns: TArray<UINT>;
  GCallIndex: Integer;

function FakeSendInput(cInputs: UINT; pInputs: PInput; cbSize: Integer): UINT; stdcall;
begin
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

initialization
  TDUnitX.RegisterTestFixture(TEngineInjectionOutcomeTests);

end.
