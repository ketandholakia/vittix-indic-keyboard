unit Tests.Engine.State;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  EngineState;

type
  [TestFixture]
  [Category('EngineState')]
  TEngineStateTests = class
  public
    [Test]
    procedure InitEngineState_SetsEnabledTrue_AndClearsState;

    [Test]
    procedure ResetEngineState_ClearsPendingFields;

    [Test]
    procedure SetEngineEnabled_False_CallsResetEngineState;

    [Test]
    procedure SetEngineHasActiveLayout_UpdatesState;
  end;

implementation

procedure TEngineStateTests.InitEngineState_SetsEnabledTrue_AndClearsState;
begin
  gEngineState.Enabled := False;
  gEngineState.PendingPrebase := 'X';
  
  InitEngineState;
  
  Assert.IsTrue(gEngineState.Enabled, 'InitEngineState must set Enabled to True');
  Assert.AreEqual('', gEngineState.PendingPrebase, 'InitEngineState must zero out the record');
  Assert.IsFalse(gEngineState.HasActiveLayout, 'InitEngineState must clear active layout flag');
end;

procedure TEngineStateTests.ResetEngineState_ClearsPendingFields;
begin
  gEngineState.KeyBuffer := 'buffer';
  gEngineState.PendingPrebase := 'pre';
  gEngineState.PendingPostbase := 'post';
  gEngineState.PendingReph := True;
  gEngineState.CurrentCluster := 'cluster';
  gEngineState.LastOutput := 'out';
  
  ResetEngineState;
  
  Assert.AreEqual('', gEngineState.KeyBuffer);
  Assert.AreEqual('', gEngineState.PendingPrebase);
  Assert.AreEqual('', gEngineState.PendingPostbase);
  Assert.IsFalse(gEngineState.PendingReph);
  Assert.AreEqual('', gEngineState.CurrentCluster);
  Assert.AreEqual('', gEngineState.LastOutput);
end;

procedure TEngineStateTests.SetEngineEnabled_False_CallsResetEngineState;
begin
  InitEngineState;
  gEngineState.PendingPrebase := 'pre';
  
  SetEngineEnabled(False);
  
  Assert.IsFalse(EngineEnabled);
  Assert.AreEqual('', gEngineState.PendingPrebase, 'Disabling the engine must reset the state');
end;

procedure TEngineStateTests.SetEngineHasActiveLayout_UpdatesState;
begin
  InitEngineState;
  Assert.IsFalse(EngineHasActiveLayout);
  
  SetEngineHasActiveLayout(True);
  Assert.IsTrue(EngineHasActiveLayout);
end;

initialization
  TDUnitX.RegisterTestFixture(TEngineStateTests);

end.
