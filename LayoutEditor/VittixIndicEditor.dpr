program VittixIndicEditor;

{$APPTYPE GUI}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Forms,

  // ---- Forms ----
  frmEditorMain in 'Forms\frmEditorMain.pas' {frmEditorMain},
  frmSequenceEditor in 'Forms\frmSequenceEditor.pas' {frmSequenceEditor},

  // ---- Model / IO ----
  LayoutModel in 'Model\LayoutModel.pas',
  LayoutLoader in '..\Keyboard\Layout\LayoutLoader.pas',

  // Editor-specific JSON save/load
  LayoutJsonIO in 'IO\LayoutJsonIO.pas',

  // ---- UI helpers ----
  KeyboardPainter in 'UI\KeyboardPainter.pas',
  Validation in 'UI\Validation.pas',

  // ---- Utils ----
  BackupManager in 'Utils\BackupManager.pas';

{$R *.res}

begin
  try
    // Enable Per-Monitor V2 DPI awareness for High-DPI displays
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

    Application.Initialize;
    Application.MainFormOnTaskbar := True;
    Application.Title := 'Vittix Indic Keyboard – Layout Editor';

    // 🔴 FIXED: use renamed global variable
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
