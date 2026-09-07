unit Tests.Keyboard.AppSettings;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IniFiles,
  System.IOUtils,
  Winapi.Windows,
  AppSettings;

type
  // M2.3 regression coverage: settings path injection. Every test constructs
  // TAppSettings against its own isolated temporary directory, so no settings
  // operation can reach the real user profile. Construction is proven
  // side-effect-free and distinct from explicit persistence (Save /
  // SaveDefaultLayoutID), and the normal settings lifecycle is verified
  // end-to-end through the injected path.
  [TestFixture]
  TAppSettingsTests = class
  strict private
    FDir: string;
    FIniPath: string;
    FSettings: TAppSettings;
    function NewSettings: TAppSettings;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Create_WithTempPath_PerformsNoWrite;
    [Test]
    procedure Save_WritesInjectedPath;
    [Test]
    procedure SaveDefaultLayoutID_PersistsToInjectedPath;
    [Test]
    procedure RoundTrip_SecondInstanceReadsSavedValues;
    [Test]
    procedure FreshTempLocation_YieldsDocumentedDefaults;
    [Test]
    procedure ParseHotkey_UnmodifiedKey_RemainsRejected;
  end;

implementation

procedure TAppSettingsTests.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath,
    'VittixSettingsTests_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDir);
  FIniPath := TPath.Combine(FDir, 'settings.ini');
  FSettings := nil;
end;

procedure TAppSettingsTests.TearDown;
begin
  FreeAndNil(FSettings);
  try
    if TDirectory.Exists(FDir) then
      TDirectory.Delete(FDir, True);
  except
    // Best-effort cleanup: never fail the suite over a locked temp file.
  end;
  FDir := '';
  FIniPath := '';
end;

function TAppSettingsTests.NewSettings: TAppSettings;
begin
  Result := TAppSettings.Create(FIniPath);
end;

procedure TAppSettingsTests.Create_WithTempPath_PerformsNoWrite;
begin
  FSettings := NewSettings;

  Assert.AreEqual(FIniPath, FSettings.IniPath,
    'the injected path must be used verbatim');
  Assert.IsFalse(TFile.Exists(FIniPath),
    'construction must not create the settings file');
  Assert.AreEqual(0, Length(TDirectory.GetFiles(FDir)),
    'construction must not write anything into the injected location');
end;

procedure TAppSettingsTests.Save_WritesInjectedPath;
var
  Ini: TIniFile;
begin
  FSettings := NewSettings;
  FSettings.EnableKeyboard := False;
  FSettings.TargetProcessName := 'TestApp.exe';
  FSettings.AllowedProcessesText := 'App1.exe, App2.exe';
  FSettings.PreviewFontSize := 20;

  FSettings.Save;   // explicit persistence

  Assert.IsTrue(TFile.Exists(FIniPath), 'explicit Save must create the INI');
  Ini := TIniFile.Create(FIniPath);
  try
    Assert.IsFalse(Ini.ReadBool('General', 'EnableKeyboard', True));
    Assert.AreEqual('TestApp.exe', Ini.ReadString('General', 'TargetProcessName', ''));
    Assert.AreEqual('App1.exe, App2.exe',
      Ini.ReadString('General', 'AllowedProcesses', ''));
    Assert.AreEqual(20, Ini.ReadInteger('Font', 'PreviewSize', 0));
  finally
    Ini.Free;
  end;
end;

procedure TAppSettingsTests.SaveDefaultLayoutID_PersistsToInjectedPath;
var
  Ini: TIniFile;
begin
  FSettings := NewSettings;

  FSettings.SaveDefaultLayoutID('custom_layout_1');   // explicit persistence

  Assert.IsTrue(TFile.Exists(FIniPath));
  Ini := TIniFile.Create(FIniPath);
  try
    Assert.AreEqual('custom_layout_1', Ini.ReadString('Layouts', 'DefaultLayout', ''));
  finally
    Ini.Free;
  end;
end;

procedure TAppSettingsTests.RoundTrip_SecondInstanceReadsSavedValues;
var
  Second: TAppSettings;
begin
  FSettings := NewSettings;
  FSettings.EnableKeyboard := False;
  FSettings.TargetProcessName := 'TestApp.exe';
  FSettings.AllowedProcessesText := 'App1.exe, App2.exe';
  FSettings.ToggleHotkeyText := 'Ctrl+Shift+F12';
  FSettings.FallbackFont := 'Arial';
  FSettings.PreviewFontSize := 22;
  FSettings.Save;
  FreeAndNil(FSettings);

  Second := TAppSettings.Create(FIniPath);
  try
    Second.Load;
    Assert.IsFalse(Second.EnableKeyboard);
    Assert.AreEqual('TestApp.exe', Second.TargetProcessName);
    Assert.AreEqual('App1.exe, App2.exe', Second.AllowedProcessesText);
    Assert.AreEqual('Ctrl+Shift+F12', Second.ToggleHotkeyText);
    Assert.AreEqual('Arial', Second.FallbackFont);
    Assert.AreEqual(22, Second.PreviewFontSize);
  finally
    Second.Free;
  end;
end;

procedure TAppSettingsTests.FreshTempLocation_YieldsDocumentedDefaults;
begin
  FSettings := NewSettings;
  Assert.IsFalse(TFile.Exists(FIniPath));

  FSettings.Load;

  Assert.IsTrue(FSettings.EnableKeyboard);
  Assert.IsFalse(FSettings.StartWithWindows);
  Assert.AreEqual('CorelDRW.exe', FSettings.TargetProcessName);
  Assert.AreEqual('CorelDRW.exe', FSettings.AllowedProcessesText);
  Assert.AreEqual('Ctrl+Alt+K', FSettings.ToggleHotkeyText);
  Assert.AreEqual('', FSettings.ActionHotkeyText);
  Assert.AreEqual('', FSettings.DefaultLayoutID);
  Assert.AreEqual('Segoe UI', FSettings.FallbackFont);
  Assert.AreEqual(16, FSettings.PreviewFontSize);
  Assert.IsFalse(TFile.Exists(FIniPath), 'Load must remain read-only');
end;

procedure TAppSettingsTests.ParseHotkey_UnmodifiedKey_RemainsRejected;
var
  Modifiers: UINT;
  VirtualKey: UINT;
begin
  FSettings := NewSettings;

  // M1.1: an unmodified hotkey must be rejected (would steal the key).
  Assert.IsFalse(FSettings.ParseHotkey('K', Modifiers, VirtualKey),
    'an unmodified hotkey must remain rejected');
  // M1.1: a malformed token must not silently bind to anything.
  Assert.IsFalse(FSettings.ParseHotkey('Ctrl+Foo', Modifiers, VirtualKey),
    'a malformed main-key token must be rejected');
  // A valid modified hotkey must still be accepted.
  Assert.IsTrue(FSettings.ParseHotkey('Ctrl+Alt+K', Modifiers, VirtualKey),
    'a valid modified hotkey must still be accepted');
end;

initialization
  TDUnitX.RegisterTestFixture(TAppSettingsTests);

end.