program VittixIndicKeyboard;

{$APPTYPE GUI}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  frmTray in 'Forms\frmTray.pas' {frmTray},
  KeyboardHook in 'Core\KeyboardHook.pas',
  ShreeLipi.Engine in 'Core\ShreeLipi.Engine.pas',
  EngineState in 'Core\EngineState.pas',
  OSKInput in 'Core\OSKInput.pas',
  LayoutLoader in 'Layout\LayoutLoader.pas',
  LayoutManager in 'Layout\LayoutManager.pas',
  BackupManager in '..\LayoutEditor\Utils\BackupManager.pas',
  LayoutReload in 'Layout\LayoutReload.pas',
  LayoutModel in '..\Shared\LayoutModel.pas',
  LayoutJson in '..\Shared\LayoutJson.pas',
  LayoutValidation in '..\Shared\LayoutValidation.pas',
  LayoutsPathResolver in '..\Shared\LayoutsPathResolver.pas',
  FontReminder in 'UI\FontReminder.pas',
  SendInputHelper in 'Utils\SendInputHelper.pas',
  WinStartup in 'Utils\WinStartup.pas',
  Logger in 'Utils\Logger.pas',
  frmOnScreenKeyboard in 'Forms\frmOnScreenKeyboard.pas' {frmOnScreenKeyboard},
  frmSettings in 'Forms\frmSettings.pas' {frmSettings},
  AppSettings in 'Config\AppSettings.pas',
  SettingsPathProvider in 'Config\SettingsPathProvider.pas';

{$R *.res}

{ --------------------------------------------------
  Windows 7+ API (not declared in all Delphi versions)
-------------------------------------------------- }
function SetCurrentProcessExplicitAppUserModelID(
  AppID: PWideChar
): HRESULT; stdcall; external 'shell32.dll';

var
  hMutex: THandle;
begin
  // Item: Local\ (per-session) instead of Global\ (per-machine): a Global\
  // mutex makes the second Windows session (Fast User Switching, RDP, another
  // console user) unable to run its own instance even though per-session LL
  // hooks and per-user settings are fully independent. Local\ scopes the
  // single-instance rule to THIS session, which is the behavior users expect.
  hMutex := CreateMutex(nil, True, 'Local\VittixIndicKeyboardInstance');
  if (hMutex = 0) or (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
    if hMutex <> 0 then CloseHandle(hMutex);
    Exit;
  end;

  try
  try
    // CRITICAL for Windows 10/11 tray settings visibility
    // MUST be called before Application.Initialize
    SetCurrentProcessExplicitAppUserModelID(
      'com.vittix.indic.keyboard'
    );

    // Enable Per-Monitor V2 DPI awareness for High-DPI displays
    // This must be called before Application.Initialize
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

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
  finally
    if hMutex <> 0 then
      CloseHandle(hMutex);
  end;
end.
