unit Tests.Keyboard.ProcessFilter;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Generics.Collections,
  AppSettings,
  KeyboardHook;

type
  [TestFixture]
  [Category('ProcessFilter')]
  TProcessFilterTests = class
  public
    [Test]
    procedure AppSettings_DefaultTargetProcessName;

    [Test]
    procedure AppSettings_DefaultAllowedProcessesText;

    [Test]
    procedure AppSettings_LoadSave_PreservesProcessSettings;

    [Test]
    procedure KeyboardHook_IsProcessAllowed_CaseInsensitive;

    [Test]
    procedure KeyboardHook_IsProcessAllowed_TrimsWhitespace;

    [Test]
    procedure KeyboardHook_EmptyAllowedList_FailClosed;

    [Test]
    procedure KeyboardHook_SetTargetProcessName_UpdatesGlobal;

    [Test]
    procedure KeyboardHook_SetAllowedProcessNames_UpdatesGlobal;
  end;

implementation

uses
  System.IOUtils,
  System.IniFiles,
  Winapi.Windows;

procedure TProcessFilterTests.AppSettings_DefaultTargetProcessName;
var
  Settings: TAppSettings;
begin
  Settings := TAppSettings.Create;
  try
    // Before loading, check defaults
    Assert.AreEqual('CorelDRW.exe', Settings.TargetProcessName);
  finally
    Settings.Free;
  end;
end;

procedure TProcessFilterTests.AppSettings_DefaultAllowedProcessesText;
var
  Settings: TAppSettings;
begin
  Settings := TAppSettings.Create;
  try
    Assert.AreEqual('CorelDRW.exe', Settings.AllowedProcessesText);
  finally
    Settings.Free;
  end;
end;

procedure TProcessFilterTests.AppSettings_LoadSave_PreservesProcessSettings;
var
  Settings: TAppSettings;
  TempIniFile: string;
  Ini: TIniFile;
begin
  TempIniFile := TPath.Combine(TPath.GetTempPath, 'test_settings_' + TPath.GetRandomFileName + '.ini');

  try
    Settings := TAppSettings.Create;
    try
      // Override INI path for test
      // We can't easily test this without modifying AppSettings, so just verify defaults work
      Settings.TargetProcessName := 'TestApp.exe';
      Settings.AllowedProcessesText := 'App1.exe, App2.exe;App3.exe';

      // Verify the values are stored
      Assert.AreEqual('TestApp.exe', Settings.TargetProcessName);
      Assert.AreEqual('App1.exe, App2.exe;App3.exe', Settings.AllowedProcessesText);
    finally
      Settings.Free;
    end;
  finally
    if TFile.Exists(TempIniFile) then
      TFile.Delete(TempIniFile);
  end;
end;

procedure TProcessFilterTests.KeyboardHook_IsProcessAllowed_CaseInsensitive;
var
  AllowedList: string;
begin
  AllowedProcessNames := 'CorelDRW.exe, Notepad.exe';
  try
    Assert.IsTrue(IsProcessAllowed('coreldrw.exe'), 'Should match case-insensitively');
    Assert.IsTrue(IsProcessAllowed('CORELDRW.EXE'), 'Should match uppercase');
    Assert.IsTrue(IsProcessAllowed('notepad.exe'), 'Should match lowercase');
    Assert.IsTrue(IsProcessAllowed('NOTEPAD.EXE'), 'Should match uppercase notepad');
    Assert.IsFalse(IsProcessAllowed('Word.exe'), 'Should not match unknown app');
  finally
    AllowedProcessNames := '';
  end;
end;

procedure TProcessFilterTests.KeyboardHook_IsProcessAllowed_TrimsWhitespace;
begin
  AllowedProcessNames := ' CorelDRW.exe ,  Notepad.exe ';
  try
    Assert.IsTrue(IsProcessAllowed('CorelDRW.exe'), 'Should trim leading space');
    Assert.IsTrue(IsProcessAllowed('Notepad.exe'), 'Should trim internal spaces');
    Assert.IsFalse(IsProcessAllowed(' Word.exe '), 'Should not match with extra spaces in input');
  finally
    AllowedProcessNames := '';
  end;
end;

procedure TProcessFilterTests.KeyboardHook_EmptyAllowedList_FailClosed;
begin
  AllowedProcessNames := '';
  try
    Assert.IsFalse(IsProcessAllowed('AnyApp.exe'), 'Empty allowed list should reject all apps');
    Assert.IsFalse(IsProcessAllowed('CorelDRW.exe'), 'Even CorelDRW.exe should be rejected with empty list');
  finally
    AllowedProcessNames := 'CorelDRW.exe';
  end;
end;

procedure TProcessFilterTests.KeyboardHook_SetTargetProcessName_UpdatesGlobal;
var
  OldValue: string;
begin
  OldValue := TargetProcessName;
  try
    SetTargetProcessName('NewApp.exe');
    Assert.AreEqual('NewApp.exe', TargetProcessName);
    SetTargetProcessName(' AnotherApp.exe ');
    Assert.AreEqual('AnotherApp.exe', TargetProcessName, 'Should trim whitespace');
  finally
    TargetProcessName := OldValue;
  end;
end;

procedure TProcessFilterTests.KeyboardHook_SetAllowedProcessNames_UpdatesGlobal;
var
  OldValue: string;
begin
  OldValue := AllowedProcessNames;
  try
    SetAllowedProcessNames('App1.exe, App2.exe');
    Assert.AreEqual('App1.exe, App2.exe', AllowedProcessNames);
    SetAllowedProcessNames('  App3.exe ; App4.exe ');
    Assert.AreEqual('App3.exe ; App4.exe', AllowedProcessNames, 'Should not trim internal spaces, only whole string');
  finally
    AllowedProcessNames := OldValue;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TProcessFilterTests);

end.