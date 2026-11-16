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

  // Review fix (issue 6): the layouts folder resolution order. All tests run
  // against private temporary directories; the last test exercises the
  // SettingsPathProvider seam exactly as the test host uses it.
  [TestFixture]
  TLayoutsPathResolutionTests = class
  strict private
    FDir: string;
    function NewTempDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ConfiguredWritable_Wins;
    [Test]
    procedure ConfiguredMissing_SeedsAppDataLayouts;
    [Test]
    procedure AppDataAlreadyPresent_IsNotReseeded;
    [Test]
    procedure AppDataCreationFails_FallsBackToFallbackDir;
    [Test]
    procedure ProviderOwnedAppDataRoot_IsUsed;
  end;

implementation

uses
  SettingsPathProvider;

var
  // Sandbox for the provider-seam test; TSettingsPathProvider is a plain
  // function type, so the fake needs a unit-level variable to capture it.
  GProviderSandbox: string = '';

function FakeProviderSettingsIni(out ALegacyPath: string): string;
begin
  ALegacyPath := '';
  Result := TPath.Combine(GProviderSandbox, 'settings.ini');
end;

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

function TLayoutsPathResolutionTests.NewTempDir: string;
begin
  Result := TPath.Combine(FDir, 'root_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(Result);
end;

procedure TLayoutsPathResolutionTests.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath,
    'VittixLayoutsResolveTests_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDir);
end;

procedure TLayoutsPathResolutionTests.TearDown;
begin
  try
    if TDirectory.Exists(FDir) then
      TDirectory.Delete(FDir, True);
  except
    // Best-effort cleanup.
  end;
  FDir := '';
end;

// (1) An existing, writable configured path is used as-is.
procedure TLayoutsPathResolutionTests.ConfiguredWritable_Wins;
var
  Configured, Resolved: string;
begin
  Configured := NewTempDir;
  TFile.WriteAllText(TPath.Combine(Configured, 'layout.json'), '{}');
  Resolved := ResolveLayoutsPath(Configured, NewTempDir, NewTempDir + '\fallback');

  Assert.AreEqual(Configured, Resolved,
    'a writable configured path must win over every fallback');
end;

// (2) A missing configured path falls back to <appdata>\layouts, which is
// created on demand and seeded ONCE from the fallback (installed) folder.
procedure TLayoutsPathResolutionTests.ConfiguredMissing_SeedsAppDataLayouts;
var
  AppDataRoot, Fallback, Resolved: string;
begin
  AppDataRoot := NewTempDir;
  Fallback := NewTempDir;
  // Seed source: a layout at the root AND one in a script subfolder, so the
  // recursive copy is proven.
  TFile.WriteAllText(TPath.Combine(Fallback, 'base.json'), '{}');
  TDirectory.CreateDirectory(TPath.Combine(Fallback, 'devnagari'));
  TFile.WriteAllText(TPath.Combine(Fallback, 'devnagari', 'sub.json'), '{}');

  Resolved := ResolveLayoutsPath(TPath.Combine(FDir, 'NotThere'), AppDataRoot, Fallback);

  Assert.AreEqual(TPath.Combine(AppDataRoot, 'layouts'), Resolved,
    'the per-user layouts folder must be used');
  Assert.IsTrue(TFile.Exists(TPath.Combine(Resolved, 'base.json')),
    'the shipped defaults must be copied');
  Assert.IsTrue(TFile.Exists(TPath.Combine(Resolved, 'devnagari', 'sub.json')),
    'script subfolders must be copied recursively');
end;

// The per-user copy is created once: an existing appdata layouts folder is
// reused as-is and never re-seeded (it may hold user edits).
procedure TLayoutsPathResolutionTests.AppDataAlreadyPresent_IsNotReseeded;
var
  AppDataRoot, Fallback, AppDataLayouts, Resolved: string;
begin
  AppDataRoot := NewTempDir;
  Fallback := NewTempDir;
  TFile.WriteAllText(TPath.Combine(Fallback, 'shipped.json'), '{}');

  AppDataLayouts := TPath.Combine(AppDataRoot, 'layouts');
  TDirectory.CreateDirectory(AppDataLayouts);
  TFile.WriteAllText(TPath.Combine(AppDataLayouts, 'user-edit.json'), '{}');

  Resolved := ResolveLayoutsPath(TPath.Combine(FDir, 'NotThere'), AppDataRoot, Fallback);

  Assert.AreEqual(AppDataLayouts, Resolved);
  Assert.IsTrue(TFile.Exists(TPath.Combine(Resolved, 'user-edit.json')),
    'existing per-user content must be untouched');
  Assert.IsFalse(TFile.Exists(TPath.Combine(Resolved, 'shipped.json')),
    'an existing folder must not be re-seeded');
end;

// (3) When the app-data root cannot host the layouts folder (here: the root
// path goes THROUGH an existing file), the exe-relative fallback is used.
procedure TLayoutsPathResolutionTests.AppDataCreationFails_FallsBackToFallbackDir;
var
  Blocker, Fallback, Resolved: string;
begin
  Blocker := TPath.Combine(FDir, 'blocker.txt');
  TFile.WriteAllText(Blocker, 'this file blocks directory creation below it');
  Fallback := NewTempDir;

  // Root = <blocker.txt>\Vittix — ForceDirectories must fail on it.
  Resolved := ResolveLayoutsPath(TPath.Combine(FDir, 'NotThere'),
    TPath.Combine(Blocker, 'Vittix'), Fallback);

  Assert.AreEqual(Fallback, Resolved,
    'a failing app-data creation must fall back to the fallback folder');
end;

// The one-argument wrapper derives the app-data root from the settings
// location seam, so a test host gets everything inside its sandbox. Its
// fallback folder is the exe-relative one by design (not injectable), so
// this test pins the ROOT derivation only; seeding itself is covered by the
// three-argument tests above.
procedure TLayoutsPathResolutionTests.ProviderOwnedAppDataRoot_IsUsed;
var
  Sandbox, Resolved: string;
begin
  Sandbox := NewTempDir;

  GProviderSandbox := Sandbox;
  SetSettingsPathProvider(FakeProviderSettingsIni);
  try
    Resolved := ResolveLayoutsPath(TPath.Combine(FDir, 'NotThere'));

    Assert.AreEqual(TPath.Combine(Sandbox, 'layouts'), Resolved,
      'the provider-owned location must host the layouts folder');
    Assert.IsTrue(TDirectory.Exists(Resolved),
      'the per-user layouts folder is created on demand');
  finally
    SetSettingsPathProvider(nil);
    GProviderSandbox := '';
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAppSettingsTests);
  TDUnitX.RegisterTestFixture(TLayoutsPathResolutionTests);

end.