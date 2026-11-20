unit LayoutsPathResolver;

{ Review follow-up (issue 6): the layouts-folder resolution shared by the
  tray application and the standalone Layout Editor, extracted from
  Keyboard/Config/AppSettings.pas so the editor does not couple to the
  keyboard app's settings unit (whose initialization owns a process-global
  TAppSettings). The resolution order:

    1. The configured path, when it exists AND is writable.
    2. <app-data>\Vittix\layouts - created on demand; when it is first
       created, the installed defaults are copied recursively from
       AFallbackLayoutsDir (the exe-relative 'layouts' folder), so a copy
       installed under Program Files gets a writable per-user layouts home.
    3. AFallbackLayoutsDir itself, as a read-only last resort. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.IniFiles,
  System.IOUtils,
  System.StrUtils,
  System.Hash,
  System.Generics.Collections,
  System.JSON,
  Winapi.Windows,
  Winapi.ShlObj,
  BackupManager;

// The three-step resolution. Pure with respect to its arguments, so tests
// can exercise the full order against temporary directories.
function ResolveLayoutsPath(const AConfiguredPath, AAppDataRoot,
  AFallbackLayoutsDir: string): string;

// The per-user application-data root (%APPDATA%\Vittix, with a home-dir
// fallback when the shell folder is unavailable).
function DefaultAppDataRoot: string;

// Reads [Layouts] Path from the given settings.ini ('' when the file is
// missing or the key is unset). A stored relative path is resolved against
// AExeDir, exactly like TAppSettings.Load does.
function ReadConfiguredLayoutsPath(const ASettingsIniPath,
  AExeDir: string): string;

{ Item (shipped layout updates never reach existing users): reconcile the
  per-user seeded layouts copy with the shipped layouts tree at startup.

  ASeedManifest (<per-user layouts>\.seed.json) records, per file, the SHA-256
  of the shipped version WHEN IT WAS COPIED, plus the app version. For every
  shipped file:
    - per-user copy missing            -> copy it (record the hash);
    - per-user copy hash == recorded   -> the user never edited it, so a
      shipped file that now differs is OVERWRITTEN (after EnsureBackup);
    - per-user copy hash != recorded (or no record) -> the user modified it:
      leave it alone, log a warning through ALog (nil-tolerant).
  Files the user created (absent from the shipped tree) are never touched;
  the loop iterates shipped files only.

  Bootstrap: a copy seeded by an older build has no manifest - a per-user
  file whose content EXACTLY matches the shipped file is adopted (hash
  recorded); anything else is treated as user-modified. This upgrades
  existing users without rewriting files that may hold their edits.

  Only acts when AResolvedLayoutsDir IS the per-user app-data copy: a custom
  configured folder or the exe-relative fallback belongs to the user and is
  never reconciled. ALog receives 'info: ...' / 'warning: ...' lines for the
  caller to log. }
procedure UpdateSeededLayouts(const AResolvedLayoutsDir, AAppDataRoot,
  AFallbackLayoutsDir, AAppVersion: string; ALog: TStrings);

implementation

// A directory is considered writable when a probe file can be created in it.
// Called on startup / settings apply only - never per keystroke.
function IsWritableDirectory(const ADir: string): Boolean;
var
  Probe: string;
begin
  Result := False;
  if (Trim(ADir) = '') or (not TDirectory.Exists(ADir)) then
    Exit;

  Probe := TPath.Combine(ADir, 'vittix-write-probe.tmp');
  try
    TFile.WriteAllText(Probe, 'probe');
    Result := True;
  except
    Result := False;
  end;
  if TFile.Exists(Probe) then
    try
      TFile.Delete(Probe);
    except
      // A probe that cannot be deleted is still proof the directory accepts
      // writes; leave it - it will be overwritten next run.
    end;
end;

{ Item (backup files are loaded as layouts): the seeding copy must not carry
  editor backup folders into the per-user layouts home. TDirectory.Copy has no
  filter, so the shipped tree is copied file by file, skipping every
  \_backup\ folder (BackupManager.PathInBackupFolder). }
procedure SeedLayoutsCopy(const ASourceDir, ATargetDir: string);
var
  Files: TArray<string>;
  FileName, RelPath, DestPath: string;
begin
  Files := TDirectory.GetFiles(ASourceDir, '*.*', TSearchOption.soAllDirectories);
  for FileName in Files do
  begin
    if PathInBackupFolder(FileName) then
      Continue;

    RelPath := ExtractRelativePath(IncludeTrailingPathDelimiter(ASourceDir), FileName);
    DestPath := TPath.Combine(ATargetDir, RelPath);
    ForceDirectories(ExtractFileDir(DestPath));
    TFile.Copy(FileName, DestPath, False);
  end;
end;

function ResolveLayoutsPath(const AConfiguredPath, AAppDataRoot,
  AFallbackLayoutsDir: string): string;
var
  Configured: string;
  AppDataLayouts: string;
begin
  // (1) Configured + exists + writable.
  Configured := ExcludeTrailingPathDelimiter(Trim(AConfiguredPath));
  if IsWritableDirectory(Configured) then
    Exit(Configured);

  // (2) App-data layouts, created on demand and seeded once.
  AppDataLayouts := '';
  if Trim(AAppDataRoot) <> '' then
    AppDataLayouts := TPath.Combine(IncludeTrailingPathDelimiter(Trim(AAppDataRoot)), 'layouts');

  if (AppDataLayouts <> '') and (not TDirectory.Exists(AppDataLayouts)) then
  begin
    try
      if TDirectory.Exists(AFallbackLayoutsDir) then
      begin
        // First run of an installed copy: seed the per-user copy with the
        // shipped defaults (recursive - layouts live in script subfolders).
        // Backup folders are skipped, so an editor _backup dir next to the
        // shipped layouts can never leak into the fresh per-user copy.
        ForceDirectories(AppDataLayouts);
        SeedLayoutsCopy(AFallbackLayoutsDir, AppDataLayouts);
      end
      else
        ForceDirectories(AppDataLayouts);
    except
      // Creation or seeding failed (read-only profile, blocked path, ...):
      // do not leave a broken empty folder posing as the layouts home -
      // fall through to (3).
      if TDirectory.Exists(AppDataLayouts) then
        try
          TDirectory.Delete(AppDataLayouts, True);
        except
        end;
    end;
  end;

  if (AppDataLayouts <> '') and TDirectory.Exists(AppDataLayouts) then
    Exit(AppDataLayouts);

  // (3) Exe-relative fallback, read-only under an installed copy.
  Result := ExcludeTrailingPathDelimiter(Trim(AFallbackLayoutsDir));
end;

function DefaultAppDataRoot: string;
var
  AppDataPath: array[0..MAX_PATH] of Char;
begin
  if SHGetFolderPath(0, CSIDL_APPDATA, 0, 0, AppDataPath) = S_OK then
    Result := TPath.Combine(string(AppDataPath), 'Vittix')
  else
    Result := TPath.Combine(TPath.GetHomePath, 'Vittix');
end;

function ReadConfiguredLayoutsPath(const ASettingsIniPath,
  AExeDir: string): string;
var
  Ini: TIniFile;
begin
  Result := '';
  if Trim(ASettingsIniPath) = '' then
    Exit;

  // Reading a missing INI simply yields the defaults; TIniFile creates
  // nothing until something is written.
  Ini := TIniFile.Create(ASettingsIniPath);
  try
    Result := Trim(Ini.ReadString('Layouts', 'Path', ''));
  finally
    Ini.Free;
  end;

  // Save persists exe-relative paths for folders inside the application
  // directory; resolve them the same way TAppSettings.Load does.
  if (Result <> '') and (not TPath.IsPathRooted(Result)) then
    Result := IncludeTrailingPathDelimiter(AExeDir) + Result;
end;

{ --------------------------------------------------
  Item: shipped layout updates for existing users
-------------------------------------------------- }

const
  SEED_MANIFEST_NAME = '.seed.json';

// ALog receives 'info: ...' / 'warning: ...' lines; nil-tolerant so callers
// without logging (tests) can pass nil.
procedure SeedLog(ALog: TStrings; const AKind, AMsg: string);
begin
  if ALog <> nil then
    ALog.Add(AKind + ': ' + AMsg);
end;

// Loads <ALayoutsDir>\.seed.json into AFiles ('' version when absent).
function LoadSeedManifest(const ALayoutsDir: string;
  AFiles: TDictionary<string, string>): string;
var
  Json: TJSONValue;
  Root, FilesObj: TJSONObject;
  Pair: TJSONPair;
  ManifestPath: string;
begin
  Result := '';
  AFiles.Clear;

  ManifestPath := TPath.Combine(ALayoutsDir, SEED_MANIFEST_NAME);
  if not TFile.Exists(ManifestPath) then
    Exit;

  try
    Json := TJSONObject.ParseJSONValue(TFile.ReadAllText(ManifestPath));
  except
    // A corrupt manifest must never block startup: behave as if absent
    // (existing files get adopted by equality or left as user-modified).
    Json := nil;
  end;
  if Json = nil then
    Exit;

  try
    if not (Json is TJSONObject) then
      Exit;
    Root := TJSONObject(Json);

    FilesObj := nil;
    if Root.FindValue('files') is TJSONObject then
      FilesObj := TJSONObject(Root.FindValue('files'));
    if FilesObj <> nil then
      for Pair in FilesObj do
      begin
        if (Pair.JsonValue <> nil) and (Pair.JsonValue is TJSONString) then
          AFiles.AddOrSetValue(Pair.JsonString.Value, Pair.JsonValue.Value);
      end;

    if Root.FindValue('app_version') is TJSONString then
      Result := (Root.FindValue('app_version') as TJSONString).Value;
  finally
    Json.Free;
  end;
end;

procedure SaveSeedManifest(const ALayoutsDir, AAppVersion: string;
  AFiles: TDictionary<string, string>);
var
  Root, FilesObj: TJSONObject;
  FileName: string;
begin
  FilesObj := TJSONObject.Create;
  try
    for FileName in AFiles.Keys do
      FilesObj.AddPair(FileName, AFiles[FileName]);

    Root := TJSONObject.Create;
    try
      Root.AddPair('app_version', AAppVersion);
      Root.AddPair('files', FilesObj);
      TFile.WriteAllText(TPath.Combine(ALayoutsDir, SEED_MANIFEST_NAME),
        Root.ToJSON, TEncoding.UTF8);
    finally
      Root.Free;
    end;
  except
    // The manifest write is best-effort; the next run re-adopts by equality.
  end;
end;

procedure UpdateSeededLayouts(const AResolvedLayoutsDir, AAppDataRoot,
  AFallbackLayoutsDir, AAppVersion: string; ALog: TStrings);
var
  ExpectedPerUser, ShippedDir, PerUserPath: string;
  ShippedFiles: TArray<string>;
  FileName, RelPath, SeedKey: string;
  Manifest: TDictionary<string, string>;
  RecordedHash, UserHash, ShippedHash: string;
begin
  if (Trim(AResolvedLayoutsDir) = '') or (Trim(AAppDataRoot) = '') then
    Exit;

  // Reconcile ONLY the per-user seeded copy (the folder step (2) owns);
  // a custom configured folder or the exe-relative fallback is never touched.
  ExpectedPerUser := TPath.Combine(IncludeTrailingPathDelimiter(Trim(AAppDataRoot)),
    'layouts');
  if not SameText(ExcludeTrailingPathDelimiter(AResolvedLayoutsDir),
    ExcludeTrailingPathDelimiter(ExpectedPerUser)) then
    Exit;

  ShippedDir := ExcludeTrailingPathDelimiter(AFallbackLayoutsDir);
  if (ShippedDir = '') or (not TDirectory.Exists(ShippedDir)) then
    Exit;

  Manifest := TDictionary<string, string>.Create;
  try
    LoadSeedManifest(AResolvedLayoutsDir, Manifest);

    try
      ShippedFiles := TDirectory.GetFiles(ShippedDir, '*.*',
        TSearchOption.soAllDirectories);
    except
      on E: Exception do
      begin
        SeedLog(ALog, 'warning', 'could not enumerate shipped layouts: ' + E.Message);
        Exit;
      end;
    end;
    for FileName in ShippedFiles do
    begin
      if PathInBackupFolder(FileName) then
        Continue;

      try
        SeedKey := ReplaceText(ExtractRelativePath(
          IncludeTrailingPathDelimiter(ShippedDir), FileName), '\', '/');
        PerUserPath := TPath.Combine(AResolvedLayoutsDir,
          ReplaceText(SeedKey, '/', '\'));
        ShippedHash := THashSHA2.GetHashStringFromFile(FileName);

        if not TFile.Exists(PerUserPath) then
        begin
          // Missing per-user copy (brand-new shipped layout): copy it.
          try
            ForceDirectories(ExtractFileDir(PerUserPath));
            TFile.Copy(FileName, PerUserPath, False);
            Manifest.AddOrSetValue(SeedKey, ShippedHash);
            SeedLog(ALog, 'info', 'seeded new shipped layout ' + SeedKey);
          except
            on E: Exception do
              SeedLog(ALog, 'warning', 'could not seed ' + SeedKey + ': ' + E.Message);
          end;
          Continue;
        end;

        UserHash := THashSHA2.GetHashStringFromFile(PerUserPath);

        if Manifest.TryGetValue(SeedKey, RecordedHash) then
        begin
          if SameText(UserHash, RecordedHash) then
          begin
            // The user never edited this file since we shipped it, so a
            // changed shipped version arrives as an update (backed up first).
            if not SameText(UserHash, ShippedHash) then
            begin
              try
                EnsureBackup(PerUserPath, DefaultBackupOptions);
                TFile.Copy(FileName, PerUserPath, True);
                Manifest.AddOrSetValue(SeedKey, ShippedHash);
                SeedLog(ALog, 'info', 'updated seeded layout ' + SeedKey +
                  ' to the shipped version');
              except
                on E: Exception do
                  SeedLog(ALog, 'warning', 'could not update ' + SeedKey + ': ' +
                    E.Message);
              end;
            end;
          end
          else
            SeedLog(ALog, 'warning', 'layout ' + SeedKey +
              ' was modified by the user; leaving it alone (a newer shipped version exists)');
        end
        else if SameText(UserHash, ShippedHash) then
        begin
          // No manifest (older-build seed): identical content proves the file
          // was never edited - adopt it into the manifest.
          Manifest.AddOrSetValue(SeedKey, ShippedHash);
        end
        else
          SeedLog(ALog, 'warning', 'layout ' + SeedKey +
            ' has no seed record and differs from the shipped file; treating it as user-modified and leaving it alone');
      except
        on E: Exception do
          SeedLog(ALog, 'warning', 'could not reconcile ' + FileName + ': ' + E.Message);
      end;
    end;

    SaveSeedManifest(AResolvedLayoutsDir, AAppVersion, Manifest);
  finally
    Manifest.Free;
  end;
end;

end.
