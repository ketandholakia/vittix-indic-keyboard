unit Tests.Keyboard.ProcessFilter;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  Winapi.Windows,
  KeyboardHook,
  EngineState,
  AppSettings;

type
  [TestFixture]
  [Category('ProcessFilter')]
  TProcessFilterTests = class
  strict private
    FDir: string;
    FIniPath: string;
    FDeps: THookPolicyDependencies;
    procedure ResetGlobalHookState;
  public
    procedure FakeKeyHandler(const AChar: string);
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Persistence_SavesAndLoadsProcessSettings;

    [Test]
    procedure HandleKeyEvent_AllowsMultipleProcesses_SeparatedByCommaOrSemicolon;

    [Test]
    procedure HandleKeyEvent_TrimsWhitespaceFromProcessNames;
  end;

implementation

var
  GFakeProcess: string;

function FakeForegroundProcess: string;
begin
  Result := GFakeProcess;
end;

function FakeModifierState: TKeyModifierState;
begin
  Result := Default(TKeyModifierState);
end;

function FakeVKToUnicode(VKCode: DWORD; ScanCode: DWORD;
  const Modifiers: TKeyModifierState): string;
begin
  Result := 'x'; // always translate
end;

function FakeInjectionHealthy: Boolean;
begin
  Result := True; // always healthy
end;

procedure TProcessFilterTests.FakeKeyHandler(const AChar: string);
begin
  // Do nothing
end;

function MakeKey: TKeyContext;
begin
  Result.VKCode := $41; // A
  Result.ScanCode := 0;
  Result.IsKeyDown := True;
  Result.IsInjected := False;
end;

procedure TProcessFilterTests.ResetGlobalHookState;
begin
  SetTargetProcessName('');
  SetAllowedProcessNames('');
end;

procedure TProcessFilterTests.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath, 'VittixProcessFilterTests_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDir);
  FIniPath := TPath.Combine(FDir, 'settings.ini');
  ResetGlobalHookState;
  
  InitEngineState;
  SetEngineEnabled(True);
  SetEngineHasActiveLayout(True);
  
  FDeps := Default(THookPolicyDependencies);
  FDeps.GetForegroundProcessName := FakeForegroundProcess;
  FDeps.GetModifierState := FakeModifierState;
  FDeps.VKToUnicode := FakeVKToUnicode;
  FDeps.IsInjectionHealthy := FakeInjectionHealthy;
  SetHookPolicyDependencies(FDeps);
  
  SetKeyHandler(FakeKeyHandler);
end;

procedure TProcessFilterTests.TearDown;
begin
  try
    if TDirectory.Exists(FDir) then
      TDirectory.Delete(FDir, True);
  except
  end;
  ResetGlobalHookState;
  ResetEngineState;
  SetHookPolicyDependencies(Default(THookPolicyDependencies));
end;

procedure TProcessFilterTests.Persistence_SavesAndLoadsProcessSettings;
var
  Settings: TAppSettings;
begin
  Settings := TAppSettings.Create(FIniPath);
  Settings.TargetProcessName := 'TestApp.exe';
  Settings.AllowedProcessesText := 'App1.exe, App2.exe;App3.exe';
  Settings.Save;
  Settings.Free;

  Settings := TAppSettings.Create(FIniPath);
  try
    Settings.Load;
    Assert.AreEqual('TestApp.exe', Settings.TargetProcessName);
    Assert.AreEqual('App1.exe, App2.exe;App3.exe', Settings.AllowedProcessesText);
  finally
    Settings.Free;
  end;
end;

procedure TProcessFilterTests.HandleKeyEvent_AllowsMultipleProcesses_SeparatedByCommaOrSemicolon;
begin
  SetAllowedProcessNames('CorelDRW.exe, Notepad.exe; Word.exe');
  
  GFakeProcess := 'notepad.exe';
  Assert.IsTrue(HandleKeyEvent(MakeKey()), 'Notepad should be allowed (comma separator)');
  
  GFakeProcess := 'word.exe';
  Assert.IsTrue(HandleKeyEvent(MakeKey()), 'Word should be allowed (semicolon separator)');
  
  GFakeProcess := 'cmd.exe';
  Assert.IsFalse(HandleKeyEvent(MakeKey()), 'Cmd should NOT be allowed');
end;

procedure TProcessFilterTests.HandleKeyEvent_TrimsWhitespaceFromProcessNames;
begin
  SetAllowedProcessNames('  CorelDRW.exe  ,   Notepad.exe  ');
  
  GFakeProcess := 'notepad.exe';
  Assert.IsTrue(HandleKeyEvent(MakeKey()), 'Should trim spaces around Notepad.exe');
  
  GFakeProcess := 'coreldrw.exe';
  Assert.IsTrue(HandleKeyEvent(MakeKey()), 'Should trim spaces around CorelDRW.exe');
end;

initialization
  TDUnitX.RegisterTestFixture(TProcessFilterTests);

end.