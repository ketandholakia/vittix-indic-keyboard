unit AppSettings;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IniFiles,
  System.IOUtils, // For TPath
  Vcl.Forms,
  Winapi.Windows;

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

    constructor Create;
    destructor Destroy; override;

    procedure Load;
    procedure Save;
    procedure SaveDefaultLayoutID(const ALayoutID: string);
    function GetToggleHotkeyText: string;
    procedure ParseHotkey(const HotkeyText: string; out Modifiers: UINT;
      out VirtualKey: UINT);
  end;

var
  GAppSettings: TAppSettings;

implementation

constructor TAppSettings.Create;
begin
  FIniPath := ExtractFilePath(Application.ExeName) + 'settings.ini';
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

procedure TAppSettings.ParseHotkey(const HotkeyText: string; out Modifiers: UINT;
  out VirtualKey: UINT);
var
  Parts: TArray<string>;
  P, Part: string;
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
      else if Part.StartsWith('F') then
        VirtualKey := VK_F1 + StrToIntDef(Copy(Part, 2), 1) - 1
      else if Length(Part) = 1 then
        VirtualKey := Ord(Part[1]);
    end;
  end;

  // SAFETY FALLBACK
  if VirtualKey = 0 then
    VirtualKey := Ord('K');
end;

initialization
  GAppSettings := TAppSettings.Create;
  GAppSettings.Load;

finalization
  GAppSettings.Free;

end.
