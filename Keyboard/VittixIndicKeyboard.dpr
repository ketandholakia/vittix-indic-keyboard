program VittixIndicKeyboard;

{$APPTYPE GUI}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  frmTray in 'Forms\frmTray.pas' {frmTray},
  KeyboardHook in 'Core\KeyboardHook.pas',
  KeyTranslator in 'Core\KeyTranslator.pas',
  ShreeLipi.Engine in 'Core\ShreeLipi.Engine.pas',
  EngineState in 'Core\EngineState.pas',
  LayoutLoader in 'Layout\LayoutLoader.pas',
  LayoutManager in 'Layout\LayoutManager.pas',
  LayoutModel in 'Layout\LayoutModel.pas',
  TrayMenuBuilder in 'UI\TrayMenuBuilder.pas',
  FontReminder in 'UI\FontReminder.pas',
  SendInputHelper in 'Utils\SendInputHelper.pas',
  WinStartup in 'Utils\WinStartup.pas',
  Logger in 'Utils\Logger.pas',
  frmOnScreenKeyboard in 'Forms\frmOnScreenKeyboard.pas' {frmOnScreenKeyboard},
  AppSettings in 'Config\AppSettings.pas';

{$R *.res}

{ --------------------------------------------------
  Windows 7+ API (not declared in all Delphi versions)
-------------------------------------------------- }
function SetCurrentProcessExplicitAppUserModelID(
  AppID: PWideChar
): HRESULT; stdcall; external 'shell32.dll';

begin
  try
    // CRITICAL for Windows 10/11 tray settings visibility
    // MUST be called before Application.Initialize
    SetCurrentProcessExplicitAppUserModelID(
      'com.vittix.indic.keyboard'
    );

    Application.Initialize;
    Application.MainFormOnTaskbar := False;
    Application.ShowMainForm := False;

    Application.CreateForm(TfrmTray, gFrmTray);
  Application.Run;

  except
    on E: Exception do
    begin
      MessageBox(
        0,
        PChar('Vittix Indic Keyboard failed to start:'#13#10 + E.Message),
        'Vittix Indic Keyboard',
        MB_ICONERROR or MB_OK
      );
    end;
  end;
end.
