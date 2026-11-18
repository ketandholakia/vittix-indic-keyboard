program VittixIndicEditor;

{$APPTYPE GUI}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,

  // ---- Forms ----
  frmEditorMain in 'Forms\frmEditorMain.pas' {frmEditorMain},

  // ---- Model / IO ----
  LayoutModel in '..\Shared\LayoutModel.pas',
  LayoutJson in '..\Shared\LayoutJson.pas',
  LayoutValidation in '..\Shared\LayoutValidation.pas',
  LayoutsPathResolver in '..\Shared\LayoutsPathResolver.pas',
  LayoutLoader in '..\Keyboard\Layout\LayoutLoader.pas',

  // ---- UI helpers ----
  VittixKeyboardView in '..\Shared\VittixKeyboardView.pas',

  // ---- Utils ----
  BackupManager in 'Utils\BackupManager.pas',
  LayoutMappingSync in 'Utils\LayoutMappingSync.pas',
  LayoutEditorSettings in 'Utils\LayoutEditorSettings.pas';

{$R *.res}

begin
  try
    // PerMonitorV2 is declared in the application manifest (dproj).
    // No runtime call needed — the manifest takes effect before WinMain.

    Application.Initialize;
    Application.MainFormOnTaskbar := True;
    Application.Title := 'Vittix Indic Keyboard – Layout Editor';

    // Apply modern VCL Style for Windows 10/11 look
    TStyleManager.TrySetStyle('Windows11 Modern Light');

    Application.CreateForm(TfrmEditorMain, gFrmEditorMain);

    Application.Run;
  except
    on E: Exception do
    begin
      MessageBox(
        0,
        PChar('Vittix Indic Editor failed to start:'#13#10 + E.Message),
        'Vittix Indic Editor',
        MB_ICONERROR or MB_OK
      );
    end;
  end;
end.
