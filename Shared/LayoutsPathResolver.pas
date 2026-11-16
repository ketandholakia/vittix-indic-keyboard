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
  Winapi.Windows,
  Winapi.ShlObj;

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
        ForceDirectories(AppDataLayouts);
        TDirectory.Copy(AFallbackLayoutsDir, AppDataLayouts);
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

end.
