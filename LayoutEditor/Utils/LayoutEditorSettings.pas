unit LayoutEditorSettings;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IniFiles,
  System.IOUtils,
  Vcl.Forms;

type
  TLayoutEditorSettings = class
  private
    FIni: TIniFile;
    FIniPath: string;
  public
    KeyFontSize: Integer;

    constructor Create;
    destructor Destroy; override;

    procedure Load;
    procedure Save;
  end;

var
  GEditorSettings: TLayoutEditorSettings;

implementation

constructor TLayoutEditorSettings.Create;
var
  AppDataDir: string;
begin
  AppDataDir := TPath.Combine(TPath.GetHomePath, 'Vittix');
  ForceDirectories(AppDataDir);
  FIniPath := TPath.Combine(AppDataDir, 'editor_settings.ini');
  FIni := TIniFile.Create(FIniPath);
  Load;
end;

destructor TLayoutEditorSettings.Destroy;
begin
  FIni.Free;
  inherited;
end;

procedure TLayoutEditorSettings.Load;
begin
  KeyFontSize := FIni.ReadInteger('Appearance', 'KeyFontSize', 9);
end;

procedure TLayoutEditorSettings.Save;
begin
  FIni.WriteInteger('Appearance', 'KeyFontSize', KeyFontSize);
  FIni.UpdateFile;
end;

initialization
  GEditorSettings := TLayoutEditorSettings.Create;

finalization
  GEditorSettings.Free;

end.
