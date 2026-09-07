unit Tests.Keyboard.AppSettingsMigration;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IniFiles,
  System.IOUtils,
  AppSettings;

type
  [TestFixture]
  TAppSettingsMigrationTests = class
  strict private
    FDir: string;
    FIniPath: string;
    FLegacyPath: string;
    FSettings: TAppSettings;
    function NewSettings: TAppSettings;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure NoFiles_CreatesNew();
    
    [Test]
    procedure LegacyFileOnly_MigratesSettings();
    
    [Test]
    procedure BothFilesExist_DoesNotOverwriteCurrent();
  end;

implementation

procedure TAppSettingsMigrationTests.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath, 'VittixMigrationTests_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDir);
  FIniPath := TPath.Combine(FDir, 'settings.ini');
  FLegacyPath := TPath.Combine(FDir, 'legacy_settings.ini');
  FSettings := nil;
end;

procedure TAppSettingsMigrationTests.TearDown;
begin
  FreeAndNil(FSettings);
  try
    if TDirectory.Exists(FDir) then
      TDirectory.Delete(FDir, True);
  except
  end;
end;

function TAppSettingsMigrationTests.NewSettings: TAppSettings;
begin
  Result := TAppSettings.Create(FIniPath, FLegacyPath);
end;

procedure TAppSettingsMigrationTests.NoFiles_CreatesNew;
begin
  FSettings := NewSettings;
  Assert.IsFalse(TFile.Exists(FIniPath), 'Should not create file until saved');
  Assert.IsFalse(TFile.Exists(FLegacyPath), 'Should not create legacy file');
end;

procedure TAppSettingsMigrationTests.LegacyFileOnly_MigratesSettings;
var
  LegacyIni: TIniFile;
begin
  LegacyIni := TIniFile.Create(FLegacyPath);
  try
    LegacyIni.WriteBool('General', 'EnableKeyboard', False);
    LegacyIni.WriteString('Hotkey', 'Toggle', 'Ctrl+Shift+L');
  finally
    LegacyIni.Free;
  end;
  
  Assert.IsTrue(TFile.Exists(FLegacyPath), 'Legacy file must exist');
  Assert.IsFalse(TFile.Exists(FIniPath), 'Target file must not exist yet');
  
  FSettings := NewSettings; // Triggers migration
  
  Assert.IsTrue(TFile.Exists(FIniPath), 'Migration should copy the file');
  
  FSettings.Load;
  Assert.IsFalse(FSettings.EnableKeyboard, 'Should load migrated setting');
  Assert.AreEqual('Ctrl+Shift+L', FSettings.ToggleHotkeyText, 'Should load migrated hotkey');
end;

procedure TAppSettingsMigrationTests.BothFilesExist_DoesNotOverwriteCurrent;
var
  LegacyIni, TargetIni: TIniFile;
begin
  LegacyIni := TIniFile.Create(FLegacyPath);
  try
    LegacyIni.WriteBool('General', 'EnableKeyboard', False);
  finally
    LegacyIni.Free;
  end;
  
  TargetIni := TIniFile.Create(FIniPath);
  try
    TargetIni.WriteBool('General', 'EnableKeyboard', True);
  finally
    TargetIni.Free;
  end;
  
  FSettings := NewSettings; // Should not overwrite because FIniPath exists
  
  FSettings.Load;
  Assert.IsTrue(FSettings.EnableKeyboard, 'Should retain current setting, not legacy');
end;

initialization
  TDUnitX.RegisterTestFixture(TAppSettingsMigrationTests);

end.
