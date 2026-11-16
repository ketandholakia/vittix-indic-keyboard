unit AppSettings;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IniFiles,
  System.IOUtils, // For TPath
  Vcl.Forms,
  Winapi.Windows,
  Winapi.ShlObj,
  SettingsPathProvider;

type
  TKeyboardAppSettingsData = record
    EnableKeyboard: Boolean;
    StartWithWindows: Boolean;
    LayoutsPath: string;
    DefaultLayoutID: string;
    TargetProcessName: string;
    AllowedProcessesText: string;
    ToggleHotkeyText: string;
    ActionHotkeyText: string;
    FallbackFont: string;
    PreviewFontSize: Integer;
  end;

  TAppSettings = class
  private
    FIni: TIniFile;
    FIniPath: string;
  public
    // [General]
    EnableKeyboard: Boolean;
    StartWithWindows: Boolean;
    // [Layouts]
    LayoutsPath: string;
    DefaultLayoutID: string;
    TargetProcessName: string;
    AllowedProcessesText: string;
    ToggleHotkeyText: string;
    ActionHotkeyText: string;
    // [Font]
    FallbackFont: string;
    PreviewFontSize: Integer;

    constructor Create; overload;
    constructor Create(const AIniPath: string; const ALegacyPath: string = ''); overload;
    destructor Destroy; override;

    procedure Load;
    procedure Save;
    procedure SaveDefaultLayoutID(const ALayoutID: string);
    function GetToggleHotkeyText: string;
     function ParseHotkey(const HotkeyText: string; out Modifiers: UINT;
       out VirtualKey: UINT): Boolean;

    // M2.3: exposes the concrete INI location (injected or production) so
    // tests can assert where settings actually go.
    property IniPath: string read FIniPath;
  end;

var
  GAppSettings: TAppSettings;

// Review fix (issue 6): resolve the layouts folder the engine should load
// from and the Layout Editor should save to.
//   1. The configured path, when it exists AND is writable.
//   2. <app-data>\Vittix\layouts — created on demand; when it is first
//      created, the installed defaults are copied recursively from
//      AFallbackLayoutsDir (the exe-relative 'layouts' folder), so a copy
//      installed under Program Files gets a writable per-user layouts home.
//   3. AFallbackLayoutsDir itself, as a read-only last resort.
// The two-argument form supplies the app-data root from the settings location
// (the SettingsPathProvider seam in test hosts, else the per-user profile)
// and the exe-relative fallback folder.
function ResolveLayoutsPath(const AConfiguredPath, AAppDataRoot,
  AFallbackLayoutsDir: string): string; overload;
function ResolveLayoutsPath(const AConfiguredPath: string): string; overload;

implementation

// A directory is considered writable when a probe file can be created in it.
// Called on startup / settings apply only — never per keystroke.
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
      // writes; leave it — it will be overwritten next run.
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
        // shipped defaults (recursive — layouts live in script subfolders).
        ForceDirectories(AppDataLayouts);
        TDirectory.Copy(AFallbackLayoutsDir, AppDataLayouts);
      end
      else
        ForceDirectories(AppDataLayouts);
    except
      // Creation or seeding failed (read-only profile, blocked path, ...):
      // do not leave a broken empty folder posing as the layouts home —
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

function ResolveLayoutsPath(const AConfiguredPath: string): string;
var
  Provider: TSettingsPathProvider;
  LegacyPath: string;
  AppDataPath: array[0..MAX_PATH] of Char;
  AppDataRoot: string;
begin
  // The app-data root follows the same location rules as settings.ini: a
  // test provider owns the location completely, else the per-user profile.
  Provider := GetSettingsPathProvider();
  if Assigned(Provider) then
    AppDataRoot := ExtractFileDir(Provider(LegacyPath))
  else if SHGetFolderPath(0, CSIDL_APPDATA, 0, 0, AppDataPath) = S_OK then
    AppDataRoot := TPath.Combine(string(AppDataPath), 'Vittix')
  else
    AppDataRoot := TPath.Combine(TPath.GetHomePath, 'Vittix');

  Result := ResolveLayoutsPath(AConfiguredPath, AppDataRoot,
    IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'layouts');
end;

constructor TAppSettings.Create;
var
  AppDataDir: string;
  LegacyPath: string;
  Provider: TSettingsPathProvider;
  AppDataPath: array[0..MAX_PATH] of Char;
begin
  Provider := GetSettingsPathProvider();
  if Assigned(Provider) then
  begin
    // M2.3: a provider (test host) owns the location completely. No directory
    // creation, no legacy migration, no access to the real user profile.
    FIniPath := Provider(LegacyPath);
    if (LegacyPath <> '') and (not TFile.Exists(FIniPath)) and TFile.Exists(LegacyPath) then
    begin
      try
        TFile.Copy(LegacyPath, FIniPath, False);
      except
        // Ignore migration failures; just start fresh.
      end;
    end;
  end
  else
  begin
    // Store settings under the per-user application-data folder so they are
    // always writable.
    if SHGetFolderPath(0, CSIDL_APPDATA, 0, 0, AppDataPath) = S_OK then
      AppDataDir := TPath.Combine(string(AppDataPath), 'Vittix')
    else
      AppDataDir := TPath.Combine(TPath.GetHomePath, 'Vittix'); // Fallback

    ForceDirectories(AppDataDir);
    FIniPath := TPath.Combine(AppDataDir, 'settings.ini');

    // Migrate an existing exe-relative settings.ini created by older builds.
    LegacyPath := ExtractFilePath(Application.ExeName) + 'settings.ini';
    if (not TFile.Exists(FIniPath)) and TFile.Exists(LegacyPath) then
    begin
      try
        TFile.Copy(LegacyPath, FIniPath, False);
      except
        // Ignore migration failures; just start fresh.
      end;
    end;
  end;

  FIni := TIniFile.Create(FIniPath);
end;

constructor TAppSettings.Create(const AIniPath: string; const ALegacyPath: string = '');
begin
  // M2.3: explicit path injection. Pure: the caller owns the location and any
  // directory creation. No profile access, no migration, no filesystem writes
  // (unless migration is explicitly tested via ALegacyPath).
  FIniPath := AIniPath;

  if (ALegacyPath <> '') and (not TFile.Exists(FIniPath)) and TFile.Exists(ALegacyPath) then
  begin
    try
      TFile.Copy(ALegacyPath, FIniPath, False);
    except
    end;
  end;

  FIni := TIniFile.Create(FIniPath);
end;

destructor TAppSettings.Destroy;
begin
  FIni.Free;
  inherited;
end;

procedure TAppSettings.Load;
begin
  // [General]
  EnableKeyboard := FIni.ReadBool('General', 'EnableKeyboard', True);
  StartWithWindows := FIni.ReadBool('General', 'StartWithWindows', False);

  // [Layouts]
  LayoutsPath := FIni.ReadString('Layouts', 'Path', 'layouts');
  DefaultLayoutID := FIni.ReadString('Layouts', 'DefaultLayout', '');
  TargetProcessName := FIni.ReadString('General', 'TargetProcessName', 'CorelDRW.exe');
  AllowedProcessesText := FIni.ReadString('General', 'AllowedProcesses',
    'CorelDRW.exe');
  ToggleHotkeyText := FIni.ReadString('Hotkey', 'Toggle', 'Ctrl+Alt+K');
  ActionHotkeyText := FIni.ReadString('Hotkey', 'Action', '');

  // [Font]
  FallbackFont := FIni.ReadString('Font', 'FallbackFont', 'Segoe UI');
  PreviewFontSize := FIni.ReadInteger('Font', 'PreviewSize', 16);

  // Convert relative layouts path to absolute
  if not TPath.IsPathRooted(LayoutsPath) then
    LayoutsPath := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName) + LayoutsPath);
end;

procedure TAppSettings.Save;
var
  StoredLayoutsPath: string;
  AppDir: string;
begin
  // Store a relative path when it points inside the application folder.
  StoredLayoutsPath := ExcludeTrailingPathDelimiter(LayoutsPath);
  AppDir := ExcludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
  if SameText(Copy(StoredLayoutsPath, 1, Length(AppDir)), AppDir) then
    StoredLayoutsPath := ExtractRelativePath(IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)), StoredLayoutsPath);

  FIni.WriteBool('General', 'EnableKeyboard', EnableKeyboard);
  FIni.WriteBool('General', 'StartWithWindows', StartWithWindows);
  FIni.WriteString('General', 'TargetProcessName', Trim(TargetProcessName));
  FIni.WriteString('General', 'AllowedProcesses', Trim(AllowedProcessesText));
  FIni.WriteString('Layouts', 'Path', StoredLayoutsPath);
  FIni.WriteString('Layouts', 'DefaultLayout', DefaultLayoutID);
  FIni.WriteString('Hotkey', 'Toggle', ToggleHotkeyText);
  FIni.WriteString('Hotkey', 'Action', ActionHotkeyText);
  FIni.WriteString('Font', 'FallbackFont', FallbackFont);
  FIni.WriteInteger('Font', 'PreviewSize', PreviewFontSize);
  FIni.UpdateFile;
end;

procedure TAppSettings.SaveDefaultLayoutID(const ALayoutID: string);
begin
  DefaultLayoutID := ALayoutID;
  FIni.WriteString('Layouts', 'DefaultLayout', ALayoutID);
end;

function TAppSettings.GetToggleHotkeyText: string;
begin
  Result := ToggleHotkeyText;
  if Result = '' then
    Result := 'Ctrl+Alt+K';
end;

function TAppSettings.ParseHotkey(const HotkeyText: string; out Modifiers: UINT;
  out VirtualKey: UINT): Boolean;
var
  Parts: TArray<string>;
  P, Part: string;
  FNum: Integer;
begin
  Modifiers := 0;
  VirtualKey := 0;

  Parts := HotkeyText.Split(['+']);

  for P in Parts do
  begin
    Part := UpperCase(Trim(P));

    if Part = 'CTRL' then
      Modifiers := Modifiers or MOD_CONTROL
    else if Part = 'ALT' then
      Modifiers := Modifiers or MOD_ALT
    else if Part = 'SHIFT' then
      Modifiers := Modifiers or MOD_SHIFT
    else if (Part = 'WIN') or (Part = 'WINDOWS') then
      Modifiers := Modifiers or MOD_WIN
    else
    begin
      // ---- MAIN KEY ----
      if Part = 'SPACE' then
        VirtualKey := VK_SPACE
      else if (Length(Part) >= 2) and (Part[1] = 'F') then
      begin
        // Strict F-key parsing: 'F' must be followed by 1..24. Legacies such as
        // 'Ctrl+F' or 'Ctrl+Foo' must NOT silently bind to F1.
        if (not TryStrToInt(Copy(Part, 2), FNum)) or (FNum < 1) or (FNum > 24) then
          Exit(False);
        VirtualKey := VK_F1 + FNum - 1;
      end
      else if Length(Part) = 1 then
        VirtualKey := Ord(Part[1])
      else
        Exit(False); // unrecognized token
    end;
  end;

  // Refuse unmodified hotkeys: a global register of a bare letter (e.g. 'K')
  // would steal that key system-wide and break typing everywhere.
  Result := (VirtualKey <> 0) and (Modifiers <> 0);
end;

initialization
  GAppSettings := TAppSettings.Create;
  GAppSettings.Load;

finalization
  GAppSettings.Free;

end.
