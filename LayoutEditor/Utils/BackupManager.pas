unit BackupManager;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections; // ✅ REQUIRED for TArray.Sort

type
  TBackupOptions = record
    Enabled: Boolean;
    MaxBackups: Integer;     // keep last N backups (0 = unlimited)
    BackupSubDir: string;    // default: "_backup"
  end;

procedure EnsureBackup(
  const SourceFile: string;
  const Options: TBackupOptions
);

function DefaultBackupOptions: TBackupOptions;

implementation

function DefaultBackupOptions: TBackupOptions;
begin
  Result.Enabled := True;
  Result.MaxBackups := 20;
  Result.BackupSubDir := '_backup';
end;

function TimeStampStr: string;
begin
  // YYYYMMDD_HHMMSS
  Result := FormatDateTime('yyyymmdd_hhnnss', Now);
end;

procedure CleanupOldBackups(const BackupDir: string; MaxBackups: Integer);
var
  Files: TArray<string>;  // ✅ FIXED
begin
  if (MaxBackups <= 0) or (not DirectoryExists(BackupDir)) then
    Exit;

  Files := TDirectory.GetFiles(
    BackupDir,
    '*.json',
    TSearchOption.soTopDirectoryOnly
  );

  // Files are not guaranteed sorted
  TArray.Sort<string>(Files);

  // Remove oldest
  while Length(Files) > MaxBackups do
  begin
    TFile.Delete(Files[0]);
    Files := Copy(Files, 1, High(Files));
  end;
end;

procedure EnsureBackup(
  const SourceFile: string;
  const Options: TBackupOptions
);
var
  SrcDir, SrcName, BackupDir, BackupFile: string;
begin
  if not Options.Enabled then
    Exit;

  if (SourceFile = '') or (not FileExists(SourceFile)) then
    Exit;

  SrcDir := ExtractFileDir(SourceFile);
  SrcName := TPath.GetFileNameWithoutExtension(SourceFile);

  BackupDir := TPath.Combine(SrcDir, Options.BackupSubDir);
  ForceDirectories(BackupDir);

  BackupFile :=
    TPath.Combine(
      BackupDir,
      Format('%s_%s.json', [SrcName, TimeStampStr])
    );

  // Copy original to backup
  TFile.Copy(SourceFile, BackupFile, True);

  // Cleanup old backups if needed
  CleanupOldBackups(BackupDir, Options.MaxBackups);
end;

end.
