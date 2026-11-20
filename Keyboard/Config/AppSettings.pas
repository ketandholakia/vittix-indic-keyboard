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
    IgnoreInjectedInput: Boolean;
    LayoutsPath: string;
    DefaultLayoutID: string;
    TargetProcessName: string;
    AllowedProcessesText: string;
    ToggleHotkeyText: string;
    ActionHotkeyText: string;
    CycleHotkeyText: string;
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
    // QW3: the hook filters keystrokes that carry the LLKHF_INJECTED flag
    // when this is on; uncheck only for remote desktop / macro tools that
    // must drive the mapping. Default True preserves hook history.
    IgnoreInjectedInput: Boolean;
    // [Layouts]
    LayoutsPath: string;
    DefaultLayoutID: string;
    TargetProcessName: string;
    AllowedProcessesText: string;
    ToggleHotkeyText: string;
    ActionHotkeyText: string;
    // C.2: cycles to the next loaded layout; '' disables it (no surprise
    // global binding by default).
    CycleHotkeyText: string;
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
// from and the Layout Editor should save to. The three-step resolution core
// (configured-writable -> app-data copy seeded on first run -> exe-relative
// fallback) lives in the shared LayoutsPathResolver unit, which the
// standalone Layout Editor uses too; this wrapper only supplies the
// keyboard-specific environment: the app-data root follows the settings
// location (the SettingsPathProvider seam in test hosts, else the per-user
// profile) and the fallback is the exe-relative 'layouts' folder.
function ResolveLayoutsPath(const AConfiguredPath: string): string;

// Item (shipped layout updates): reconcile the per-user seeded layouts copy
// with the shipped tree using the same keyboard-specific environment as
// ResolveLayoutsPath. Only the per-user copy is reconciled; ALog collects
// 'info:'/'warning:' lines for the caller to report.
procedure ReconcileSeededLayouts(const AResolvedLayoutsDir, AAppVersion: string;
  ALog: TStrings);

implementation

uses
  LayoutsPathResolver;

function ResolveLayoutsPath(const AConfiguredPath: string): string;
var
  Provider: TSettingsPathProvider;
  LegacyPath: string;
  AppDataRoot: string;
begin
  Provider := GetSettingsPathProvider();
  if Assigned(Provider) then
    AppDataRoot := ExtractFileDir(Provider(LegacyPath))
  else
    AppDataRoot := LayoutsPathResolver.DefaultAppDataRoot;

  Result := LayoutsPathResolver.ResolveLayoutsPath(AConfiguredPath, AppDataRoot,
    IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'layouts');
end;

procedure ReconcileSeededLayouts(const AResolvedLayoutsDir, AAppVersion: string;
  ALog: TStrings);
var
  Provider: TSettingsPathProvider;
  LegacyPath: string;
  AppDataRoot: string;
begin
  Provider := GetSettingsPathProvider();
  if Assigned(Provider) then
    AppDataRoot := ExtractFileDir(Provider(LegacyPath))
  else
    AppDataRoot := LayoutsPathResolver.DefaultAppDataRoot;

  LayoutsPathResolver.UpdateSeededLayouts(AResolvedLayoutsDir, AppDataRoot,
    IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'layouts',
    AAppVersion, ALog);
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
  IgnoreInjectedInput := FIni.ReadBool('General', 'IgnoreInjectedInput', True);

  // [Layouts]
  LayoutsPath := FIni.ReadString('Layouts', 'Path', 'layouts');
  DefaultLayoutID := FIni.ReadString('Layouts', 'DefaultLayout', '');
  TargetProcessName := FIni.ReadString('General', 'TargetProcessName', 'CorelDRW.exe');
  AllowedProcessesText := FIni.ReadString('General', 'AllowedProcesses',
    'CorelDRW.exe');
  ToggleHotkeyText := FIni.ReadString('Hotkey', 'Toggle', 'Ctrl+Alt+K');
  ActionHotkeyText := FIni.ReadString('Hotkey', 'Action', '');
  CycleHotkeyText := FIni.ReadString('Hotkey', 'Cycle', '');

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
  FIni.WriteBool('General', 'IgnoreInjectedInput', IgnoreInjectedInput);
  FIni.WriteString('General', 'TargetProcessName', Trim(TargetProcessName));
  FIni.WriteString('General', 'AllowedProcesses', Trim(AllowedProcessesText));
  FIni.WriteString('Layouts', 'Path', StoredLayoutsPath);
  FIni.WriteString('Layouts', 'DefaultLayout', DefaultLayoutID);
  FIni.WriteString('Hotkey', 'Toggle', ToggleHotkeyText);
  FIni.WriteString('Hotkey', 'Action', ActionHotkeyText);
  FIni.WriteString('Hotkey', 'Cycle', CycleHotkeyText);
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
