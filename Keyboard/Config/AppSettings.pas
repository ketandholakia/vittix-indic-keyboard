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
  TAppSettings = class
  private
    FIni: TIniFile;
    FIniPath: string;
  public
    // [General]
    EnableKeyboard: Boolean;
    // [Layouts]
    LayoutsPath: string;
    DefaultLayoutID: string;
    // [Font]
    FallbackFont: string;
    PreviewFontSize: Integer;

    constructor Create;
    destructor Destroy; override;

    procedure Load;
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

  // [Layouts]
  LayoutsPath := FIni.ReadString('Layouts', 'Path', 'layouts');
  DefaultLayoutID := FIni.ReadString('Layouts', 'DefaultLayout', '');

  // [Font]
  FallbackFont := FIni.ReadString('Font', 'FallbackFont', 'Segoe UI');
  PreviewFontSize := FIni.ReadInteger('Font', 'PreviewSize', 16);

  // Convert relative layouts path to absolute
  if not TPath.IsPathRooted(LayoutsPath) then
    LayoutsPath := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName) + LayoutsPath);
end;

procedure TAppSettings.SaveDefaultLayoutID(const ALayoutID: string);
begin
  FIni.WriteString('Layouts', 'DefaultLayout', ALayoutID);
end;

function TAppSettings.GetToggleHotkeyText: string;
begin
  Result := FIni.ReadString('Hotkey', 'Toggle', 'Ctrl+Alt+K');
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