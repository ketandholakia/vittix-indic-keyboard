unit Tests.Layouts.Examples;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  EngineState,
  ShreeLipi.Engine,
  LayoutModel,
  LayoutJson;

type
  [TestFixture]
  [Category('ExampleLayouts')]
  TExampleLayoutTests = class
  private
    FEvents: TStringList;
    FLayouts: array[0..3] of TKeyboardLayout;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure GujaratiPhonetic_MappingsAndComposition;

    [Test]
    procedure GujaratiInScript_MappingsAndComposition;

    [Test]
    procedure HindiPhonetic_MappingsAndComposition;

    [Test]
    procedure HindiInScript_MappingsAndComposition;
  end;

var
  GEvents: TStringList;

implementation

procedure CaptureAction(const AAction: TEngineOutputAction; const AText: string);
begin
  if not Assigned(GEvents) then
    Exit;

  case AAction of
    eoEmitText:      GEvents.Add(AText);
    eoEmitBackspace: GEvents.Add('<BS>');
    eoResetState:    GEvents.Add('<RESET>');
  end;
end;

procedure TExampleLayoutTests.Setup;
begin
  InitEngineState;
  SetEngineEnabled(True);

  FEvents := TStringList.Create;
  GEvents := FEvents;
  SetEngineOutputHandler(CaptureAction);

  FLayouts[0] := LoadLayoutFromFile('D:\ketan\github\vittix-indic-keyboard\layouts\gujarati\gujarati_phonetic.json');
  FLayouts[1] := LoadLayoutFromFile('D:\ketan\github\vittix-indic-keyboard\layouts\gujarati\gujarati_inscript.json');
  FLayouts[2] := LoadLayoutFromFile('D:\ketan\github\vittix-indic-keyboard\layouts\hindi\hindi_phonetic.json');
  FLayouts[3] := LoadLayoutFromFile('D:\ketan\github\vittix-indic-keyboard\layouts\hindi\hindi_inscript.json');
  ResetEngineState;
  FEvents.Clear;
end;

procedure TExampleLayoutTests.TearDown;
var
  i: Integer;
begin
  ResetEngineState;
  SetActiveLayout(nil);
  SetEngineOutputHandler(nil);
  GEvents := nil;
  FEvents.Free;
  for i := Low(FLayouts) to High(FLayouts) do
    if Assigned(FLayouts[i]) then
      FLayouts[i].Free;
end;

procedure TExampleLayoutTests.GujaratiPhonetic_MappingsAndComposition;
begin
  SetActiveLayout(FLayouts[0]);
  FEvents.Clear;

  ProcessKeyChar('n');
  ProcessKeyChar('m');
  ProcessKeyChar('s');
  ProcessKeyChar('\');
  ProcessKeyChar('t');
  ProcessKeyChar('Y');
  
  Assert.AreEqual(6, FEvents.Count);
  Assert.AreEqual('ન', FEvents[0]);
  Assert.AreEqual('મ', FEvents[1]);
  Assert.AreEqual('સ', FEvents[2]);
  Assert.AreEqual('્', FEvents[3]);
  Assert.AreEqual('ત', FEvents[4]);
  Assert.AreEqual('ે', FEvents[5]);
end;

procedure TExampleLayoutTests.GujaratiInScript_MappingsAndComposition;
begin
  SetActiveLayout(FLayouts[1]);
  FEvents.Clear;

  ProcessKeyChar('i');
  ProcessKeyChar('g');

  Assert.AreEqual(2, FEvents.Count);
  Assert.AreEqual('ગ', FEvents[0]);
  Assert.AreEqual('ુ', FEvents[1]);
end;

procedure TExampleLayoutTests.HindiPhonetic_MappingsAndComposition;
begin
  SetActiveLayout(FLayouts[2]);
  FEvents.Clear;

  ProcessKeyChar('n');
  ProcessKeyChar('m');
  ProcessKeyChar('s');
  ProcessKeyChar('\');
  ProcessKeyChar('t');
  ProcessKeyChar('Y');

  Assert.AreEqual(6, FEvents.Count);
  Assert.AreEqual('न', FEvents[0]);
  Assert.AreEqual('म', FEvents[1]);
  Assert.AreEqual('स', FEvents[2]);
  Assert.AreEqual('्', FEvents[3]);
  Assert.AreEqual('त', FEvents[4]);
  Assert.AreEqual('े', FEvents[5]);
end;

procedure TExampleLayoutTests.HindiInScript_MappingsAndComposition;
begin
  SetActiveLayout(FLayouts[3]);
  FEvents.Clear;

  ProcessKeyChar('u');
  ProcessKeyChar('f');
  ProcessKeyChar('v');
  ProcessKeyChar('d');
  ProcessKeyChar('o');
  ProcessKeyChar('r');

  Assert.AreEqual(6, FEvents.Count);
  Assert.AreEqual('ह', FEvents[0]);
  Assert.AreEqual('ि', FEvents[1]);
  Assert.AreEqual('न', FEvents[2]);
  Assert.AreEqual('्', FEvents[3]);
  Assert.AreEqual('द', FEvents[4]);
  Assert.AreEqual('ी', FEvents[5]);
end;

initialization
  TDUnitX.RegisterTestFixture(TExampleLayoutTests);

end.
