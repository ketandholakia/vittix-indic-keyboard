unit BackupManager;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections; // ✅ REQUIRED for TArray.Sort

const
  // Item: the backup folder name, defined ONCE here. BackupManager writes
  // <layoutdir>\_backup\<name>_<timestamp>.json; every layout scanner
  // (LayoutManager.Initialize, the LayoutsPathResolver seeding copy) skips
  // this folder so a stale backup with a duplicate layout_id can never win
  // over the real file.
  BACKUP_SUBDIR_NAME = '_backup';

type
  TBackupOptions = record
    Enabled: Boolean;
    MaxBackups: Integer;     // keep last N backups (0 = unlimited)
    BackupSubDir: string;    // default: BACKUP_SUBDIR_NAME ('_backup')
  end;

procedure EnsureBackup(
  const SourceFile: string;
  const Options: TBackupOptions
);

function DefaultBackupOptions: TBackupOptions;

// True when APath points inside a backup folder ('\_<BACKUP_SUBDIR_NAME>\'
// segment, case-insensitive). Shared by every recursive layout scan so a
// stale backup can never be picked up as a layout: LayoutManager.Initialize
// skips such files, and the LayoutsPathResolver seeding copy skips such
// folders.
function PathInBackupFolder(const APath: string): Boolean;

implementation

function DefaultBackupOptions: TBackupOptions;
begin
  Result.Enabled := True;
  Result.MaxBackups := 20;
  Result.BackupSubDir := BACKUP_SUBDIR_NAME;
end;

function PathInBackupFolder(const APath: string): Boolean;
var
  P: string;
begin
  P := APath.ToLower;
  // The trailing delimiter makes the match segment-exact: a file named
  // '_backup_notes.json' is NOT a backup, only a real \_backup\ folder is.
  // The StartsWith branch covers relative scans ('_backup\x.json' has no
  // leading delimiter to anchor the segment).
  Result := (Pos('\_backup\', P) > 0) or P.StartsWith('_backup\');
end;

function TimeStampStr: string;
begin
  // YYYYMMDD_HHMMSS_mmm
  Result := FormatDateTime('yyyymmdd_hhnnss_zzz', Now);
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
