unit Tests.LayoutEditor.BackupManager;

interface

uses
  DUnitX.TestFramework,
  Winapi.Windows,
  System.SysUtils,
  System.IOUtils;

type
  [TestFixture]
  [Category('BackupManager')]
  TBackupManagerTests = class
  private
    FTempDir: string;
    FSrcFile: string;
    function BackupDir: string;
    procedure WriteFile(const APath, AContent: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Phase A.4: EnsureBackup is wired into the editor's overwrite-save
    // sites. These tests pin the utility's contract; the wiring itself is
    // accepted by "the editor still builds" (VCL form, no test seam).
    [Test]
    procedure EnsureBackup_FirstCall_CreatesBackupCopyOfExistingFile;
    [Test]
    procedure EnsureBackup_BackupContent_MatchesOriginal;
    [Test]
    procedure EnsureBackup_SourceMissing_NoBackupDirCreated;
    [Test]
    procedure EnsureBackup_Disabled_NothingCopied;
    [Test]
    procedure EnsureBackup_Rotation_KeepsOnlyMaxBackups;
  end;

implementation

uses
  BackupManager;

function TBackupManagerTests.BackupDir: string;
begin
  Result := TPath.Combine(FTempDir, DefaultBackupOptions.BackupSubDir);
end;

procedure TBackupManagerTests.WriteFile(const APath, AContent: string);
begin
  TFile.WriteAllText(APath, AContent);
end;

procedure TBackupManagerTests.Setup;
begin
  // Unique per run so parallel/stray state cannot leak between tests.
  FTempDir := TPath.Combine(TPath.GetTempPath,
    'vittix_backup_tests_' + FormatDateTime('yyyymmdd_hhnnss_zzz', Now) +
    '_' + IntToStr(GetCurrentThreadId));
  TDirectory.CreateDirectory(FTempDir);
  FSrcFile := TPath.Combine(FTempDir, 'MyLayout.json');
  WriteFile(FSrcFile, '{"layout_id":"backup-test"}');
end;

procedure TBackupManagerTests.TearDown;
begin
  try
    if TDirectory.Exists(FTempDir) then
      TDirectory.Delete(FTempDir, True);
  except
    on E: Exception do
      ; // never fail the suite on a locked temp file
  end;
end;

procedure TBackupManagerTests.EnsureBackup_FirstCall_CreatesBackupCopyOfExistingFile;
var
  Options: TBackupOptions;
  Backups: TArray<string>;
begin
  Options := DefaultBackupOptions;
  EnsureBackup(FSrcFile, Options);

  Assert.IsTrue(TDirectory.Exists(BackupDir), 'the "_backup" subdirectory must be created');
  Backups := TDirectory.GetFiles(BackupDir, '*.json');
  Assert.AreEqual(1, Length(Backups), 'the first call must create exactly one backup');
  Assert.IsTrue(TPath.GetFileName(Backups[0]).StartsWith('MyLayout_'),
    'the backup name must be prefixed with the source name');
end;

procedure TBackupManagerTests.EnsureBackup_BackupContent_MatchesOriginal;
var
  Options: TBackupOptions;
  Backups: TArray<string>;
begin
  Options := DefaultBackupOptions;
  EnsureBackup(FSrcFile, Options);

  Backups := TDirectory.GetFiles(BackupDir, '*.json');
  Assert.AreEqual(1, Length(Backups));
  Assert.AreEqual(TFile.ReadAllText(FSrcFile), TFile.ReadAllText(Backups[0]),
    'the backup must be a faithful copy of the source file');
end;

procedure TBackupManagerTests.EnsureBackup_SourceMissing_NoBackupDirCreated;
var
  Options: TBackupOptions;
begin
  // A brand-new target (e.g. Save As to a file that does not exist yet)
  // must not produce a backup - this is what keeps first saves backup-free.
  Options := DefaultBackupOptions;
  EnsureBackup(TPath.Combine(FTempDir, 'does_not_exist.json'), Options);

  Assert.IsFalse(TDirectory.Exists(BackupDir),
    'no "_backup" directory may be created for a non-existent source');
end;

procedure TBackupManagerTests.EnsureBackup_Disabled_NothingCopied;
var
  Options: TBackupOptions;
begin
  Options := DefaultBackupOptions;
  Options.Enabled := False;
  EnsureBackup(FSrcFile, Options);

  Assert.IsFalse(TDirectory.Exists(BackupDir),
    'Enabled=False must copy nothing');
end;

procedure TBackupManagerTests.EnsureBackup_Rotation_KeepsOnlyMaxBackups;
var
  Options: TBackupOptions;
  I: Integer;
  Backups: TArray<string>;
begin
  // Pre-seed five deterministic backups (names sort before the timestamped
  // one EnsureBackup creates, because digits sort before digits of today's
  // date), then let EnsureBackup add a sixth and rotate.
  TDirectory.CreateDirectory(BackupDir);
  for I := 1 to 5 do
    WriteFile(TPath.Combine(BackupDir, Format('MyLayout_%.4d.json', [I])),
      'backup ' + IntToStr(I));

  Options := DefaultBackupOptions;
  Options.MaxBackups := 3;
  EnsureBackup(FSrcFile, Options);

  Backups := TDirectory.GetFiles(BackupDir, '*.json');
  Assert.AreEqual(3, Length(Backups), 'rotation must keep exactly MaxBackups files');
  Assert.IsFalse(TFile.Exists(TPath.Combine(BackupDir, 'MyLayout_0001.json')),
    'the oldest backup must be deleted first');
  Assert.IsFalse(TFile.Exists(TPath.Combine(BackupDir, 'MyLayout_0002.json')));
  Assert.IsFalse(TFile.Exists(TPath.Combine(BackupDir, 'MyLayout_0003.json')));
  Assert.IsTrue(TFile.Exists(TPath.Combine(BackupDir, 'MyLayout_0004.json')),
    'the newest pre-seeded backups must survive');
  Assert.IsTrue(TFile.Exists(TPath.Combine(BackupDir, 'MyLayout_0005.json')));
end;

initialization
  TDUnitX.RegisterTestFixture(TBackupManagerTests);

end.
