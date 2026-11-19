unit frmEditorMain;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Dialogs,
  Vcl.Clipbrd,
  Vcl.Grids,
  Vcl.Graphics,
  Vcl.Menus,

  System.Generics.Collections, // ✅ REQUIRED for TPair

  LayoutModel,
  LayoutResolver,
  LayoutsPathResolver,
  LayoutLoader,
  LayoutJson,
  LayoutValidation,
  LayoutMappingSync,
  BackupManager,
  LayoutEditorSettings,
  EditorTheme,
  VittixKeyboardView,
  Vcl.ToolWin,
  Vcl.Themes;

type

  // Captured so leaving high-contrast mode restores the design palette instead
  // of flattening every surface to a system colour.
  TEditorThemeEntry = record
    Control: TControl;
    SurfaceColor: TColor;
    TextColor: TColor;
    ParentBackground: Boolean;
  end;

  TfrmEditorMain = class(TForm)
    MainMenu1: TMainMenu;
    miFile: TMenuItem;
    miNew: TMenuItem;
    miOpen: TMenuItem;
    miSave: TMenuItem;
    miSaveAs: TMenuItem;
    miSep1: TMenuItem;
    miSep2: TMenuItem;
    miExit: TMenuItem;
    miEdit: TMenuItem;
    miUndo: TMenuItem;
    miRedo: TMenuItem;
    miHelpMenu: TMenuItem;
    miAbout: TMenuItem;
    miTools: TMenuItem;
    miValidateLayout: TMenuItem;

    pnlMain: TPanel;

    OpenDialog: TOpenDialog;
    SaveDialog: TSaveDialog;
    Panel2: TPanel;
    lblLayoutName: TLabel;
    edtLayoutName: TEdit;
    ComboBoxFonts: TComboBox;
    ComboBoxScript: TComboBox;
    grdProperties: TStringGrid;
    Label1: TLabel;
    PageControl: TPageControl;
    tabDirect: TTabSheet;
    edtSearchDirect: TEdit;
    grdDirect: TStringGrid;
    tabPrebase: TTabSheet;
    edtSearchPrebase: TEdit;
    grdPrebase: TStringGrid;
    tabPostbase: TTabSheet;
    edtSearchPostbase: TEdit;
    grdPostbase: TStringGrid;
    tabSequences: TTabSheet;
    edtSearchSequences: TEdit;
    grdSequences: TStringGrid;
    tabModifiers: TTabSheet;
    edtSearchModifiers: TEdit;
    grdModifiers: TStringGrid;
    pmGridContext: TPopupMenu;
    miAddKey: TMenuItem;
    miRemoveKey: TMenuItem;
    miCopy: TMenuItem;
    miPaste: TMenuItem;
    miValidate: TMenuItem;
    tabKeyboard: TTabSheet;
    pnlKeyboardHeader: TPanel;
    lblKeyboardHint: TLabel;
    vkvKeyboard: TVittixKeyboardView;
    tabPreview: TTabSheet;
    pnlPreview: TPanel;
    lblPreviewHint: TLabel;
    edtPreviewInput: TEdit;
    lblPreviewOutput: TLabel;
    lblPreviewSourcesCaption: TLabel;
    lstPreviewSources: TListBox;
    pnlDiagnostics: TPanel;
    lblDiagInfo: TLabel;
    lblEmptyState: TLabel;
    pnlProblems: TPanel;
    lblProblemsSummary: TLabel;
    btnProblemsClose: TButton;
    lstProblems: TListBox;
    StatusBar1: TStatusBar;
    btnBarNew: TButton;
    btnBarOpen: TButton;
    btnBarSave: TButton;
    btnBarSaveAs: TButton;
    btnBarUndo: TButton;
    btnBarRedo: TButton;
    btnBarValidate: TButton;
    btnAddKeyMap: TButton;
    btnAddDirect: TButton;
    btnAddPrebase: TButton;
    btnAddPostbase: TButton;
    btnAddModifiers: TButton;
    pnlMappingInspector: TPanel;
    lblInspectorTitle: TLabel;
    lblInspectorGrid: TLabel;
    lblInspectorKey: TLabel;
    lblInspectorValue: TLabel;
    edtInspectorKey: TEdit;
    edtInspectorValue: TEdit;
    btnInspectorApply: TButton;
    btnInspectorClear: TButton;
    btnInspectorAdd: TButton;
    btnHelp: TButton;
    chkHighContrast: TCheckBox;
    edtHotkeySwitch: TEdit;
    edtHotkeyAction: TEdit;
    pnlLayoutInfo: TPanel;
    pnlProperties: TPanel;
    pnlHotkeys: TPanel;
    pnlSideScroll: TScrollBox;
    splitterVert: TSplitter;
    lblSectionLayout: TLabel;
    lblSectionProps: TLabel;
    lblSectionHotkeys: TLabel;
    lblSectionDiag: TLabel;
    lblSectionAppSettings: TLabel;
    lblDivider1: TLabel;
    lblDivider2: TLabel;
    lblDivider3: TLabel;
    lblDivider4: TLabel;
    lblDivider5: TLabel;
    pnlSearchDirect: TPanel;
    pnlSearchPrebase: TPanel;
    pnlSearchPostbase: TPanel;
    pnlSearchSequences: TPanel;
    pnlSearchModifiers: TPanel;
    pnlAppSettings: TPanel;
    lblKeyFontSize: TLabel;
    ComboBoxKeyFontSize: TComboBox;
  procedure UpdateLayoutPreview;
    procedure edtSearchDirectChange(Sender: TObject);
    procedure edtSearchPrebaseChange(Sender: TObject);
    procedure edtSearchPostbaseChange(Sender: TObject);
    procedure edtSearchSequencesChange(Sender: TObject);
    procedure edtSearchModifiersChange(Sender: TObject);
    procedure ComboBoxKeyFontSizeChange(Sender: TObject);

    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btnOpenClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnSaveAsClick(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure GridSelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure GridMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ComboBox1Change(Sender: TObject);
    procedure ComboBoxScriptChange(Sender: TObject);
    procedure grdPropertiesSetEditText(Sender: TObject; ACol, ARow: Integer; const Value: string);
    procedure btnNewLayoutClick(Sender: TObject);
    procedure btnExportLayoutClick(Sender: TObject);
    procedure btnImportLayoutClick(Sender: TObject);
    procedure btnUndoClick(Sender: TObject);
    procedure btnRedoClick(Sender: TObject);
    procedure btnHelpClick(Sender: TObject);
    procedure chkHighContrastClick(Sender: TObject);
    procedure btnAddKeyMapClick(Sender: TObject);
    procedure btnAddRowClick(Sender: TObject);
    procedure btnProblemsCloseClick(Sender: TObject);
    procedure lstProblemsDblClick(Sender: TObject);
    procedure btnInspectorApplyClick(Sender: TObject);
    procedure btnInspectorClearClick(Sender: TObject);
    procedure btnInspectorAddClick(Sender: TObject);
    procedure vkvKeyboardKeySelect(Sender: TObject; const KeyName, CurrentGlyph: string);
    procedure vkvKeyboardKeyAssign(Sender: TObject; const KeyName, NewGlyph: string);

    destructor Destroy; override;
  private
    FSelectedKeyboardKey: string;

    // The model name each visible grid row is responsible for. Empty means the
    // row is new.  These arrays are what stops a filtered grid from deleting
    // the mappings it is hiding.
    FDirectOwned: TArray<string>;
    FPrebaseOwned: TArray<string>;
    FPostbaseOwned: TArray<string>;
    FSequencesOwned: TArray<string>;
    FModifiersOwned: TArray<string>;

    FPreviewTimer: TTimer;
    FPreviewDirty: Boolean;
    FLastUndoTick: Cardinal;

    // Cached LayoutResolver.Redefinitions for the current model. Rebuilt lazily
    // when the model changes, so the cell-paint path never recomputes it.
    FRedefinitions: TDictionary<string, TMappingSourceSet>;
    FRedefinitionsDirty: Boolean;

    // The problems currently shown in the dock, so a double-click can map a list
    // row back to the section and key that produced it.
    FProblems: TValidationErrors;
    FHighContrast: Boolean;
    FThemeBackup: TList<TEditorThemeEntry>;
    FLayout: TKeyboardLayout;
    FCurrentFileName: string;
    // Review follow-up (issue 6): the resolved writable layouts folder -
    // where a standalone Start Menu launch defaults its Open/Save dialogs.
    FDefaultLayoutsDir: string;
    FUndoStack: TStack<string>;
    FRedoStack: TStack<string>;
    FIsModified: Boolean;
    procedure LoadLayoutFromCommandLine;
    procedure OpenLayoutFile(const FileName: string);
    procedure UpdateWindowCaption;
    procedure SetModified(Value: Boolean);
    procedure PushUndo;

    // Returns True when it is safe to discard the current document: either it
    // is unmodified, or the user resolved the save prompt. Every code path
    // that replaces FLayout must go through this first.
    function ConfirmDiscardChanges: Boolean;

    // Resolves the grid a context-menu command applies to without casting
    // Screen.ActiveControl (which raises EInvalidCast for any non-grid focus).
    function GetActiveGrid: TStringGrid;
    procedure RemoveGridRow(Grid: TStringGrid; Row: Integer);
    procedure GridContextPopup(Sender: TObject);
    function GridForCurrentTab: TStringGrid;
    procedure UpdateEmptyState;
    procedure UpdateOutputPreview;
    procedure edtPreviewInputChange(Sender: TObject);

    // One renderer per section, shared by "load the file" and "apply a search
    // filter", so a filter can never produce a grid with columns missing.
    procedure RenderDirect(const Filter: string);
    procedure RenderPrebase(const Filter: string);
    procedure RenderPostbase(const Filter: string);
    procedure RenderSequences(const Filter: string);
    procedure RenderModifiers(const Filter: string);
    procedure ReportFilterCount(Grid: TStringGrid; Total: Integer);

    function CollectStringRows(Grid: TStringGrid): TArray<TStringMappingRow>;
    function CollectDirectClassRows(Grid: TStringGrid): TArray<TStringMappingRow>;
    function CollectPrebaseRows: TArray<TEditorMapping>;
    function CollectModifierRows: TArray<TEditorMapping>;
    function CollectOwnedKeys(Grid: TStringGrid): TArray<string>;

    procedure PreviewTimerTick(Sender: TObject);
    procedure UpdateLayoutPreviewNow;

    procedure ApplyHighContrast(const Enabled: Boolean);
    procedure ApplyHighContrastTo(AParent: TWinControl);
    procedure CaptureTheme;
    procedure CaptureThemeIn(AParent: TWinControl);
    procedure RestoreTheme;

    procedure GridDrawCell(
      Sender: TObject;
      ACol, ARow: Integer;
      Rect: TRect;
      State: TGridDrawState
    );
    procedure GridSetEditText(Sender: TObject; ACol, ARow: Integer; const Value: string);
    procedure ComboBoxFontsChange(Sender: TObject);
    procedure LoadInstalledFonts;
    procedure ClearGrids;
    procedure LoadLayoutToUI;
    procedure UpdateDiagnosticsPanel;
    procedure UpdateStatusBar;
    procedure LoadDirect;
    procedure LoadPrebase;
    procedure LoadPostbase;
    procedure LoadSequences;
    procedure LoadModifiers;
    procedure LoadExtraMaps;
    procedure miAddKeyClick(Sender: TObject);
    procedure miRemoveKeyClick(Sender: TObject);
    procedure miCopyClick(Sender: TObject);
    procedure miPasteClick(Sender: TObject);
    procedure miValidateClick(Sender: TObject);
    procedure ShowValidationErrors(const Errors: TValidationErrors);
    procedure SyncUIToModel;
    procedure SaveUIToLayout;
    procedure RefreshKeyboardView;
    procedure ClearLayout;
    procedure UpdateMappingInspector(const Grid: TStringGrid; ARow: Integer);
    function GetGridCellText(Grid: TStringGrid; ARow, ACol: Integer): string;
    procedure SetInspectorFromSelection(const Grid: TStringGrid; ARow: Integer);
    function GetSelectedGrid: TStringGrid;
    procedure AddRowToGrid(Grid: TStringGrid);
    function FindRowByKey(Grid: TStringGrid; const Key: string): Integer;
    procedure SelectGridRow(Grid: TStringGrid; Row: Integer);
    function GetMappingForKey(const Key: string; out Value: string): Boolean;
    function IsRealDuplicateKey(Grid: TStringGrid; const Key: string): Boolean;
    function RedefinitionIndex: TDictionary<string, TMappingSourceSet>;
    function GridForSection(const Section: string): TStringGrid;
    procedure TrimUndoStack;
  public
  end;

var
  gFrmEditorMain: TfrmEditorMain; // ✅ FIXED (no collision)

implementation

{$R *.dfm}

const
  DEFAULT_EDITOR_CAPTION = 'Vittix Indic Keyboard Layout Editor';

  // Tall enough for a 16pt preview glyph in the layout font.  The DFM ships 26,
  // which clipped Devanagari matras.
  GRID_ROW_HEIGHT = 32;

  // In-place grid editing fires per keystroke; collapse a burst into one undo
  // entry and one preview rebuild instead of one of each per character.
  UNDO_COALESCE_MS = 700;
  PREVIEW_REFRESH_MS = 250;

  // Snapshots are full layout JSON, so the stack needs a ceiling.
  MAX_UNDO_DEPTH = 50;

procedure EnableGridEditing(Grid: TStringGrid);
begin
  Grid.Options := Grid.Options + [goEditing, goAlwaysShowEditor, goTabs];
end;

function AskSaveChanges(AOwner: TComponent): Integer;
var
  Dlg: TTaskDialog;
begin
  Dlg := TTaskDialog.Create(AOwner);
  try
    Dlg.Caption := 'Unsaved Changes';
    Dlg.Title := 'Do you want to save your changes?';
    Dlg.Text := 'Your layout has been modified. If you close without ' +
      'saving, your changes will be lost.';
    Dlg.MainIcon := tdiWarning;
    Dlg.CommonButtons := [];
    with Dlg.Buttons.Add do begin Caption := '&Save';        ModalResult := mrYes;    Default := True; end;
    with Dlg.Buttons.Add do begin Caption := 'Do&n''t Save';  ModalResult := mrNo;     end;
    with Dlg.Buttons.Add do begin Caption := 'Cancel';        ModalResult := mrCancel; end;
    Dlg.Execute;
    Result := Dlg.ModalResult;
  finally
    Dlg.Free;
  end;
end;

procedure TfrmEditorMain.LoadInstalledFonts;
begin
  ComboBoxFonts.Items.BeginUpdate;
  try
    ComboBoxFonts.Items.Assign(Screen.Fonts);
    ComboBoxFonts.Sorted := True;
  finally
    ComboBoxFonts.Items.EndUpdate;
  end;
end;

procedure TfrmEditorMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := ConfirmDiscardChanges;
end;

function TfrmEditorMain.ConfirmDiscardChanges: Boolean;
begin
  Result := True;
  if not FIsModified then
    Exit;

  case AskSaveChanges(Self) of
    mrYes:
      begin
        btnSaveClick(nil);
        // Only safe to continue if saving actually cleared the modified flag,
        // which it does not when the user cancels the file dialog.
        Result := not FIsModified;
      end;
    mrNo: Result := True;
  else
    Result := False;
  end;
end;

function TfrmEditorMain.GetActiveGrid: TStringGrid;
begin
  Result := nil;
  if Screen.ActiveControl is TStringGrid then
    Result := Screen.ActiveControl as TStringGrid;
end;

procedure TfrmEditorMain.RemoveGridRow(Grid: TStringGrid; Row: Integer);
var
  I: Integer;
begin
  if (Grid = nil) or (Row < Grid.FixedRows) or (Row >= Grid.RowCount) then
    Exit;

  // Shift the rows below up by one, then shrink. Clearing the row instead
  // leaves a permanent blank line that SaveUIToModel silently ignores.
  for I := Row to Grid.RowCount - 2 do
    Grid.Rows[I].Assign(Grid.Rows[I + 1]);
  Grid.RowCount := Grid.RowCount - 1;

  if Grid.Row >= Grid.RowCount then
    Grid.Row := Grid.RowCount - 1;
  if Grid.Row < Grid.FixedRows then
    Grid.Row := Grid.FixedRows;
  Grid.Invalidate;
end;

procedure TfrmEditorMain.GridContextPopup(Sender: TObject);
var
  Grid: TStringGrid;
  Editable: Boolean;
begin
  Grid := GetActiveGrid;
  Editable := Assigned(Grid) and (goEditing in Grid.Options);

  // A read-only grid (Sequences) must not advertise commands that write to it.
  miAddKey.Enabled := Editable;
  miRemoveKey.Enabled := Editable;
  miPaste.Enabled := Editable;
  miCopy.Enabled := Assigned(Grid);
  miValidate.Enabled := Assigned(FLayout);
end;

destructor TfrmEditorMain.Destroy;
begin
  FreeAndNil(FRedefinitions);
  FreeAndNil(FProblems);
  inherited;
end;

procedure TfrmEditorMain.FormCreate(Sender: TObject);
begin
  // One token set for the whole window. Everything the form shows is assigned
  // from EditorTheme, so the palette can be changed in one file.
  ApplyEditorTheme(Self, EditorThemeDefault);

  FCurrentFileName := '';
  UpdateWindowCaption;

  // Review follow-up (issue 6): a standalone launch (no tray-passed file
  // argument) should default its Open/Save dialogs to the same writable
  // per-user layouts folder the tray app uses - the configured path from
  // %APPDATA%\Vittix\settings.ini when present and usable, else the
  // per-user copy (created and seeded on first run), else the exe-relative
  // folder. The dialog objects are themed/unthemed freely elsewhere, so the
  // InitialDir assignments here are the single source for the start folder.
  FDefaultLayoutsDir := LayoutsPathResolver.ResolveLayoutsPath(
    LayoutsPathResolver.ReadConfiguredLayoutsPath(
      TPath.Combine(LayoutsPathResolver.DefaultAppDataRoot, 'settings.ini'),
      ExtractFilePath(Application.ExeName)),
    LayoutsPathResolver.DefaultAppDataRoot,
    IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'layouts');
  OpenDialog.InitialDir := FDefaultLayoutsDir;
  SaveDialog.InitialDir := FDefaultLayoutsDir;

  ClearGrids;

  LoadInstalledFonts;

  ComboBoxFonts.Enabled := False;
  ComboBoxFonts.ItemIndex := -1;

  EnableGridEditing(grdDirect);
  EnableGridEditing(grdPrebase);
  EnableGridEditing(grdPostbase);
  // Sequences are read-only and deprecated
  EnableGridEditing(grdModifiers);

  grdDirect.OnSetEditText := GridSetEditText;
  grdPrebase.OnSetEditText := GridSetEditText;
  grdPostbase.OnSetEditText := GridSetEditText;
  // grdSequences.OnSetEditText := GridSetEditText;
  grdModifiers.OnSetEditText := GridSetEditText;

  ComboBoxFonts.OnChange := ComboBoxFontsChange;
  pmGridContext.Items[0].OnClick := miAddKeyClick;
  pmGridContext.Items[1].OnClick := miRemoveKeyClick;
  pmGridContext.Items[2].OnClick := miCopyClick;
  pmGridContext.Items[3].OnClick := miPasteClick;
  pmGridContext.Items[4].OnClick := miValidateClick;
  pmGridContext.OnPopup := GridContextPopup;

  // Validation used to be reachable only by right-clicking a grid. It now has a
  // menu item and F7 as well.
  miValidateLayout.OnClick := miValidateClick;
  btnHelp.OnClick := btnHelpClick;
  chkHighContrast.OnClick := chkHighContrastClick;
  btnAddKeyMap.OnClick := btnAddKeyMapClick;
  btnInspectorApply.OnClick := btnInspectorApplyClick;
  btnInspectorClear.OnClick := btnInspectorClearClick;
  btnInspectorAdd.OnClick := btnInspectorAddClick;
  vkvKeyboard.OnKeySelect := vkvKeyboardKeySelect;
  vkvKeyboard.OnKeyAssign := vkvKeyboardKeyAssign;
  // The inspector is the only editing surface, so keyboard selection needs no
  // separate wiring: vkvKeyboardKeySelect loads the inspector directly.
  // The Add buttons live in the DFM and are anchored to the right edge of their
  // search panel. Creating them at runtime with absolute Left offsets placed
  // them on top of the search field at every DPI.
  btnAddDirect.OnClick := btnAddRowClick;
  btnAddPrebase.OnClick := btnAddRowClick;
  btnAddPostbase.OnClick := btnAddRowClick;
  // Sequences do not get an Add button: the section is deprecated and read-only.
  btnAddModifiers.OnClick := btnAddRowClick;

  // Initialize Application Settings
  ComboBoxKeyFontSize.Items.Clear;
  ComboBoxKeyFontSize.Items.Add('8');
  ComboBoxKeyFontSize.Items.Add('9');
  ComboBoxKeyFontSize.Items.Add('10');
  ComboBoxKeyFontSize.Items.Add('11');
  ComboBoxKeyFontSize.Items.Add('12');
  ComboBoxKeyFontSize.Items.Add('14');
  ComboBoxKeyFontSize.Items.Add('16');
  ComboBoxKeyFontSize.Items.Add('18');
  ComboBoxKeyFontSize.Items.Add('20');
  ComboBoxKeyFontSize.Items.Add('24');
  ComboBoxKeyFontSize.Items.Add('28');
  ComboBoxKeyFontSize.Items.Add('32');
  ComboBoxKeyFontSize.Text := IntToStr(GEditorSettings.KeyFontSize);
  ComboBoxKeyFontSize.OnChange := ComboBoxKeyFontSizeChange;
  vkvKeyboard.Font.Size := GEditorSettings.KeyFontSize;

  // Populate script/language options
  ComboBoxScript.Items.Clear;
  if Assigned(FLayout) then
    ComboBoxScript.Items.AddStrings(FLayout.SupportedScripts)
  else
    ComboBoxScript.Items.AddStrings([ 'Devanagari', 'Gujarati', 'Tamil', 'Bengali', 'Kannada', 'Malayalam', 'Oriya', 'Punjabi', 'Telugu', 'Sinhala' ]);
  ComboBoxScript.OnChange := ComboBoxScriptChange;

  // Setup property grid
  grdProperties.ColCount := 2;
  grdProperties.RowCount := 2;
  grdProperties.Cells[0,0] := 'Property';
  grdProperties.Cells[1,0] := 'Value';
  grdProperties.OnSetEditText := grdPropertiesSetEditText;

  grdDirect.FixedRows := 1;
  grdPrebase.FixedRows := 1;
  grdPostbase.FixedRows := 1;
  grdSequences.FixedRows := 1;
  grdModifiers.FixedRows := 1;

  grdDirect.DefaultDrawing := False;
  grdPrebase.DefaultDrawing := False;
  grdPostbase.DefaultDrawing := False;
  grdSequences.DefaultDrawing := False;
  grdModifiers.DefaultDrawing := False;

  grdDirect.OnDrawCell := GridDrawCell;
  grdPrebase.OnDrawCell := GridDrawCell;
  grdPostbase.OnDrawCell := GridDrawCell;
  grdSequences.OnDrawCell := GridDrawCell;
  grdModifiers.OnDrawCell := GridDrawCell;

  grdDirect.OnSelectCell := GridSelectCell;
  grdPrebase.OnSelectCell := GridSelectCell;
  grdPostbase.OnSelectCell := GridSelectCell;
  grdSequences.OnSelectCell := GridSelectCell;
  grdModifiers.OnSelectCell := GridSelectCell;

  grdDirect.OnMouseDown := GridMouseDown;
  grdPrebase.OnMouseDown := GridMouseDown;
  grdPostbase.OnMouseDown := GridMouseDown;
  grdSequences.OnMouseDown := GridMouseDown;
  grdModifiers.OnMouseDown := GridMouseDown;

  edtSearchDirect.OnChange := edtSearchDirectChange;
  edtSearchPrebase.OnChange := edtSearchPrebaseChange;
  edtSearchPostbase.OnChange := edtSearchPostbaseChange;
  edtSearchSequences.OnChange := edtSearchSequencesChange;
  edtSearchModifiers.OnChange := edtSearchModifiersChange;

  // (the command-bar buttons are declared in the DFM and wired there)

  btnBarUndo.OnClick := btnUndoClick;
  btnBarRedo.OnClick := btnRedoClick;
  // Wired here rather than in the DFM because miValidateClick is not published.
  // Wired here so the handler can stay private.
  edtPreviewInput.OnChange := edtPreviewInputChange;

  btnBarValidate.OnClick := miValidateClick;

  FUndoStack := TStack<string>.Create;
  FRedoStack := TStack<string>.Create;

  FPreviewTimer := TTimer.Create(Self);
  FPreviewTimer.Interval := PREVIEW_REFRESH_MS;
  FPreviewTimer.Enabled := False;
  FPreviewTimer.OnTimer := PreviewTimerTick;

  LoadLayoutFromCommandLine;
  UpdateEmptyState;
end;
procedure TfrmEditorMain.ComboBoxScriptChange(Sender: TObject);
begin
  if Assigned(FLayout) then
  begin
    FLayout.Script := ComboBoxScript.Text;
    UpdateLayoutPreview;
  end;
end;

procedure TfrmEditorMain.ComboBoxKeyFontSizeChange(Sender: TObject);
var
  NewSize: Integer;
begin
  if TryStrToInt(ComboBoxKeyFontSize.Text, NewSize) then
  begin
    GEditorSettings.KeyFontSize := NewSize;
    GEditorSettings.Save;
    vkvKeyboard.Font.Size := NewSize;
    vkvKeyboard.Invalidate;
  end;
end;

procedure TfrmEditorMain.grdPropertiesSetEditText(Sender: TObject; ACol, ARow: Integer; const Value: string);
var
  PropName: string;
begin
  if Assigned(FLayout) and (ARow > 0) then
  begin
    PropName := grdProperties.Cells[0,ARow];
    FLayout.Properties.AddOrSetValue(PropName, Value);
  end;
end;

procedure TfrmEditorMain.GridSetEditText(Sender: TObject; ACol, ARow: Integer; const Value: string);
begin
  if (Sender = grdDirect) and (ACol = 1) and (grdDirect.ColCount > 3) then
    grdDirect.Cells[3, ARow] := Value;
  PushUndo;
  SaveUIToLayout;
  UpdateLayoutPreview;
  if Sender is TStringGrid then
    SetInspectorFromSelection(Sender as TStringGrid, ARow);
end;

procedure TfrmEditorMain.ComboBoxFontsChange(Sender: TObject);
begin
  PushUndo;
  SaveUIToLayout;
  UpdateLayoutPreview;
end;

procedure TfrmEditorMain.btnHelpClick(Sender: TObject);
var
  Dlg: TTaskDialog;
begin
  Dlg := TTaskDialog.Create(Self);
  try
    Dlg.Caption := 'About Vittix';
    Dlg.Title := 'Vittix Indic Keyboard Editor';
    Dlg.Text :=
      #$2022' See User Guide (Help menu) for details.' + sLineBreak +
      #$2022' Tooltips are available for most controls.' + sLineBreak +
      #$2022' For accessibility, use High Contrast Mode.';
    Dlg.FooterText := 'Documentation: docs/UserGuide_EN.md';
    Dlg.MainIcon := tdiInformation;
    Dlg.CommonButtons := [tcbOk];
    Dlg.Execute;
  finally
    Dlg.Free;
  end;
end;

procedure TfrmEditorMain.chkHighContrastClick(Sender: TObject);
begin
  ApplyHighContrast(chkHighContrast.Checked);
end;

// TControl.Color, TControl.Font and TWinControl.ParentBackground are all
// protected. Several VCL controls republish them and several do not (TScrollBox
// and TTabSheet among them), and the theme walk must not care which. These are
// the standard Delphi accessors for reaching them generically.
type
  TControlSurfaceAccess = class(TControl);
  TWinControlAccess = class(TWinControl);

function ControlHasSurface(AControl: TControl): Boolean;
begin
  Result := (AControl is TPanel) or (AControl is TScrollBox) or
    (AControl is TTabSheet) or (AControl is TStringGrid) or
    (AControl is TEdit) or (AControl is TComboBox);
end;

procedure TfrmEditorMain.CaptureThemeIn(AParent: TWinControl);
var
  I: Integer;
  Ctl: TControl;
  Entry: TEditorThemeEntry;
begin
  for I := 0 to AParent.ControlCount - 1 do
  begin
    Ctl := AParent.Controls[I];
    Entry.Control := Ctl;
    Entry.SurfaceColor := TControlSurfaceAccess(Ctl).Color;
    Entry.TextColor := TControlSurfaceAccess(Ctl).Font.Color;
    Entry.ParentBackground := (Ctl is TWinControl) and
      TWinControlAccess(Ctl).ParentBackground;
    FThemeBackup.Add(Entry);

    if Ctl is TWinControl then
      CaptureThemeIn(TWinControl(Ctl));
  end;
end;

procedure TfrmEditorMain.CaptureTheme;
begin
  if Assigned(FThemeBackup) then
    Exit;

  FThemeBackup := TList<TEditorThemeEntry>.Create;
  CaptureThemeIn(Self);
end;

procedure TfrmEditorMain.RestoreTheme;
var
  Entry: TEditorThemeEntry;
begin
  if not Assigned(FThemeBackup) then
    Exit;

  for Entry in FThemeBackup do
  begin
    if not Assigned(Entry.Control) then
      Continue;

    if ControlHasSurface(Entry.Control) then
      TControlSurfaceAccess(Entry.Control).Color := Entry.SurfaceColor;

    TControlSurfaceAccess(Entry.Control).Font.Color := Entry.TextColor;

    if Entry.Control is TWinControl then
      TWinControlAccess(Entry.Control).ParentBackground := Entry.ParentBackground;
  end;

  // Re-apply the editor palette rather than hardcoded defaults, so leaving High
  // Contrast returns to the themed look instead of the old DFM literals.
  ApplyEditorTheme(Self, EditorThemeDefault);
end;

procedure TfrmEditorMain.ApplyHighContrastTo(AParent: TWinControl);
var
  I: Integer;
  Ctl: TControl;
  Bg, Fg: TColor;
begin
  if not FHighContrast then
    Exit;

  Bg := clBlack;
  Fg := clWhite;

  for I := 0 to AParent.ControlCount - 1 do
  begin
    Ctl := AParent.Controls[I];

    // The surface and the text on it are set together. Setting only the font
    // is what produced white text on the white sidebar panels.
    if ControlHasSurface(Ctl) then
      TControlSurfaceAccess(Ctl).Color := Bg;

    if Ctl is TWinControl then
      TWinControlAccess(Ctl).ParentBackground := False;

    TControlSurfaceAccess(Ctl).Font.Color := Fg;

    if Ctl is TWinControl then
      ApplyHighContrastTo(TWinControl(Ctl));
  end;
end;

procedure TfrmEditorMain.ApplyHighContrast(const Enabled: Boolean);
begin
  if FHighContrast = Enabled then
    Exit;

  FHighContrast := Enabled;

  if Enabled then
  begin
    CaptureTheme;
    ApplyHighContrastTo(Self);
    Color := clBlack;
    Font.Color := clWhite;

    // The diagnostics strip is the one panel that needs its own accent.
    pnlDiagnostics.Color := clBlack;
    lblDiagInfo.Font.Color := clYellow;
  end
  else
  begin
    RestoreTheme;
    pnlDiagnostics.Color := $00F4F4F4;
    lblDiagInfo.Font.Color := $00666666;
  end;

  vkvKeyboard.HighContrastMode := Enabled;

  grdDirect.Invalidate;
  grdPrebase.Invalidate;
  grdPostbase.Invalidate;
  grdSequences.Invalidate;
  grdModifiers.Invalidate;
  grdProperties.Invalidate;
end;

procedure TfrmEditorMain.PushUndo;
begin
  SetModified(True);
  if FLayout = nil then
    Exit;

  // Coalesce: typing a multi-character glyph must not create one full layout
  // snapshot per keystroke.
  if (FUndoStack.Count > 0) and (GetTickCount - FLastUndoTick < UNDO_COALESCE_MS) then
    Exit;

  FLastUndoTick := GetTickCount;
  FUndoStack.Push(LayoutToJson(FLayout));
  FRedoStack.Clear;
  TrimUndoStack;
end;

procedure TfrmEditorMain.TrimUndoStack;
var
  Temp: TArray<string>;
  I: Integer;
begin
  if FUndoStack.Count <= MAX_UNDO_DEPTH then
    Exit;

  // TStack offers no way to drop the oldest entry, so rebuild the stack when it
  // overflows. Temp[0] ends up newest, Temp[High] oldest.
  SetLength(Temp, FUndoStack.Count);
  for I := 0 to High(Temp) do
    Temp[I] := FUndoStack.Pop;

  FUndoStack.Clear;
  for I := MAX_UNDO_DEPTH - 1 downto 0 do
    FUndoStack.Push(Temp[I]);
end;

procedure TfrmEditorMain.btnUndoClick(Sender: TObject);
var
  PrevState: string;
begin
  if FUndoStack.Count = 0 then Exit;
  if FLayout <> nil then
    FRedoStack.Push(LayoutToJson(FLayout));
  PrevState := FUndoStack.Pop;
  FreeAndNil(FLayout);
  FLayout := LayoutFromJson(PrevState);
  LoadLayoutToUI;
  UpdateLayoutPreview;
end;

procedure TfrmEditorMain.btnRedoClick(Sender: TObject);
var
  NextState: string;
begin
  if FRedoStack.Count = 0 then Exit;
  if FLayout <> nil then
    FUndoStack.Push(LayoutToJson(FLayout));
  NextState := FRedoStack.Pop;
  FreeAndNil(FLayout);
  FLayout := LayoutFromJson(NextState);
  LoadLayoutToUI;
  UpdateLayoutPreview;
end;
procedure TfrmEditorMain.btnNewLayoutClick(Sender: TObject);
begin
  if not ConfirmDiscardChanges then
    Exit;

  PushUndo;
  FreeAndNil(FLayout);
  FLayout := TKeyboardLayout.Create;
  FCurrentFileName := '';
  edtLayoutName.Text := '';
  ComboBoxFonts.ItemIndex := -1;
  ComboBoxFonts.Enabled := True;
  ClearGrids;
  LoadLayoutToUI;
  UpdateWindowCaption;
  UpdateLayoutPreview;
  UpdateEmptyState;
end;

procedure TfrmEditorMain.btnExportLayoutClick(Sender: TObject);
begin
  if FLayout = nil then Exit;
  if SaveDialog.Execute then
  begin
    // Phase A.4: overwriting an existing layout file keeps a backup first.
    // EnsureBackup no-ops when the target does not exist yet.
    EnsureBackup(SaveDialog.FileName, DefaultBackupOptions);
    SaveLayoutToFile(FLayout, SaveDialog.FileName);
  end;
end;

procedure TfrmEditorMain.btnImportLayoutClick(Sender: TObject);
begin
  if OpenDialog.Execute then
  begin
    if not ConfirmDiscardChanges then
      Exit;

    PushUndo;
    FreeAndNil(FLayout);
    FLayout := LoadLayoutFromFile(OpenDialog.FileName);
    FCurrentFileName := OpenDialog.FileName;
    LoadLayoutToUI;
    UpdateLayoutPreview;
  end;
end;
procedure TfrmEditorMain.edtSearchPrebaseChange(Sender: TObject);
begin
  RenderPrebase(edtSearchPrebase.Text);
end;

procedure TfrmEditorMain.edtSearchPostbaseChange(Sender: TObject);
begin
  RenderPostbase(edtSearchPostbase.Text);
end;

procedure TfrmEditorMain.edtSearchSequencesChange(Sender: TObject);
begin
  RenderSequences(edtSearchSequences.Text);
end;

procedure TfrmEditorMain.edtSearchModifiersChange(Sender: TObject);
begin
  RenderModifiers(edtSearchModifiers.Text);
end;

procedure TfrmEditorMain.edtSearchDirectChange(Sender: TObject);
begin
  RenderDirect(edtSearchDirect.Text);
end;

procedure TfrmEditorMain.ClearGrids;
begin
  grdDirect.RowCount := 2;
  grdPrebase.RowCount := 2;
  grdPostbase.RowCount := 2;
  grdSequences.RowCount := 2;
  grdModifiers.RowCount := 2;
end;

  // Initialize preview panel
  // Preview will be updated after layout is loaded or changed
procedure TfrmEditorMain.ClearLayout;
begin
  FreeAndNil(FLayout);
  FCurrentFileName := '';
  edtLayoutName.Clear;
  ComboBoxFonts.ItemIndex := -1;
  ComboBoxFonts.Enabled := False;
  ClearGrids;
  SetModified(False);
  UpdateWindowCaption;
  FSelectedKeyboardKey := '';
  vkvKeyboard.Layout := nil;
  vkvKeyboard.GlyphFontName := '';
  edtInspectorKey.Clear;
  edtInspectorValue.Clear;
  UpdateLayoutPreview;
end;

procedure TfrmEditorMain.UpdateLayoutPreview;
begin
  FPreviewDirty := True;
  if Assigned(FPreviewTimer) then
  begin
    // Restart the interval so the rebuild runs once, after the user stops.
    FPreviewTimer.Enabled := False;
    FPreviewTimer.Enabled := True;
  end
  else
    UpdateLayoutPreviewNow;
end;

procedure TfrmEditorMain.PreviewTimerTick(Sender: TObject);
begin
  FPreviewTimer.Enabled := False;
  if not FPreviewDirty then
    Exit;
  FPreviewDirty := False;
  if csDestroying in ComponentState then
    Exit;
  UpdateLayoutPreviewNow;
end;

procedure TfrmEditorMain.UpdateLayoutPreviewNow;
begin
  // The Preview tab used to draw a second copy of the mapping list as a grid of
  // labels, which duplicated the Keyboard tab and rebuilt every label on each
  // keystroke. It is now a typing scratchpad: type on the physical keyboard and
  // the resolved output appears in the layout font, with the source per key.
  UpdateOutputPreview;
end;

procedure TfrmEditorMain.edtPreviewInputChange(Sender: TObject);
begin
  UpdateOutputPreview;
end;

procedure TfrmEditorMain.UpdateOutputPreview;
var
  I: Integer;
  Ch: Char;
  Rendered: string;
  Resolved: TResolvedGlyph;
  Sources: TStringList;
begin
  if not Assigned(lblPreviewOutput) then
    Exit;

  if Assigned(lblPreviewHint) then
  begin
    if Assigned(FLayout) then
      lblPreviewHint.Caption := Format(
        'Typing preview for %s. Type above; the resolved output appears here and the source of each key is listed below.',
        [FLayout.Name])
    else
      lblPreviewHint.Caption := 'Open a layout to preview its output.';
  end;

  Rendered := '';
  Sources := TStringList.Create;
  try
    if Assigned(edtPreviewInput) and Assigned(FLayout) then
    begin
      for I := 1 to Length(edtPreviewInput.Text) do
      begin
        Ch := edtPreviewInput.Text[I];
        Resolved := TLayoutResolver.Resolve(FLayout, Ch);
        if Resolved.Found then
        begin
          Rendered := Rendered + Resolved.Glyph;
          Sources.Add(Format('%s   %s   (%s)',
            [Ch, Resolved.Glyph, Resolved.SourceLabel]));
        end
        else
        begin
          Rendered := Rendered + Ch;
          Sources.Add(Format('%s   %s   (no mapping, passed through)', [Ch, Ch]));
        end;
      end;
    end;

    lblPreviewOutput.Font.Color := EditorThemeCurrent.Text;
    lblPreviewOutput.Font.Style := [];
    if Assigned(FLayout) and (Trim(FLayout.FontFamily) <> '') then
    begin
      // The preview must render in the layout's own font or it shows nothing
      // useful for a legacy encoding such as KrutiDev.
      lblPreviewOutput.Font.Name := FLayout.FontFamily;
      lblPreviewOutput.Font.Size := GEditorSettings.KeyFontSize;
    end;
    lblPreviewOutput.Caption := Rendered;

    lstPreviewSources.Items.BeginUpdate;
    try
      lstPreviewSources.Items.Clear;
      for I := 0 to Sources.Count - 1 do
        lstPreviewSources.Items.Add(Sources[I]);
    finally
      lstPreviewSources.Items.EndUpdate;
    end;
  finally
    Sources.Free;
  end;
end;

function TfrmEditorMain.GetGridCellText(Grid: TStringGrid; ARow, ACol: Integer): string;
begin
  Result := '';
  if (Grid <> nil) and (ARow >= 0) and (ARow < Grid.RowCount) and
     (ACol >= 0) and (ACol < Grid.ColCount) then
    Result := Trim(Grid.Cells[ACol, ARow]);
end;

function TfrmEditorMain.GetSelectedGrid: TStringGrid;
begin
  Result := nil;
  if Screen.ActiveControl is TStringGrid then
    Result := Screen.ActiveControl as TStringGrid;
end;

function TfrmEditorMain.GetMappingForKey(const Key: string; out Value: string): Boolean;
begin
  Result := False;
  Value := '';
  if (FLayout = nil) then Exit;
  if FLayout.DirectMap.TryGetValue(Key, Value) then Exit(True);
end;

function TfrmEditorMain.RedefinitionIndex: TDictionary<string, TMappingSourceSet>;
begin
  if FRedefinitionsDirty or (FRedefinitions = nil) then
  begin
    FreeAndNil(FRedefinitions);
    FRedefinitions := TLayoutResolver.Redefinitions(FLayout);
    FRedefinitionsDirty := False;
  end;
  Result := FRedefinitions;
end;

function TfrmEditorMain.IsRealDuplicateKey(Grid: TStringGrid; const Key: string): Boolean;
begin
  // A key is flagged when more than one section defines it, which is exactly the
  // case where one mapping shadows another. The previous version only counted
  // DirectMap and PostbaseMap and re-scanned both for every painted cell.
  Result := (FLayout <> nil) and (Trim(Key) <> '') and
    RedefinitionIndex.ContainsKey(Trim(Key));
end;

procedure TfrmEditorMain.SelectGridRow(Grid: TStringGrid; Row: Integer);
begin
  if (Grid = nil) or (Row < Grid.FixedRows) or (Row >= Grid.RowCount) then
    Exit;
  Grid.Row := Row;
  Grid.Col := 0;
  Grid.EditorMode := False;
  SetInspectorFromSelection(Grid, Row);
end;

function TfrmEditorMain.FindRowByKey(Grid: TStringGrid; const Key: string): Integer;
var
  R: Integer;
begin
  Result := -1;
  if Grid = nil then Exit;
  for R := Grid.FixedRows to Grid.RowCount - 1 do
    if SameText(Trim(Grid.Cells[0, R]), Trim(Key)) then
      Exit(R);
end;

procedure TfrmEditorMain.AddRowToGrid(Grid: TStringGrid);
var
  Row, C: Integer;
begin
  if Grid = nil then Exit;
  Row := Grid.RowCount;
  Grid.RowCount := Row + 1;
  Grid.Cells[0, Row] := 'NewKey';
  for C := 1 to Grid.ColCount - 1 do
    Grid.Cells[C, Row] := '';
  SelectGridRow(Grid, Row);
  Grid.EditorMode := True;
end;

procedure TfrmEditorMain.SetInspectorFromSelection(const Grid: TStringGrid; ARow: Integer);
begin
  UpdateMappingInspector(Grid, ARow);
  if (Grid = nil) or (ARow < Grid.FixedRows) then Exit;
  lblInspectorGrid.Caption := 'Grid: ' + Grid.Name;
  edtInspectorKey.Text := GetGridCellText(Grid, ARow, 0);
  if Grid.ColCount > 1 then
    edtInspectorValue.Text := GetGridCellText(Grid, ARow, 1)
  else
    edtInspectorValue.Clear;
end;

procedure TfrmEditorMain.UpdateMappingInspector(const Grid: TStringGrid; ARow: Integer);
var
  KeyText, ValueText, GridName: string;
begin
  if (Grid = nil) or (ARow < Grid.FixedRows) then
    Exit;

  KeyText := GetGridCellText(Grid, ARow, 0);
  ValueText := '';
  if Grid.ColCount > 1 then
    ValueText := GetGridCellText(Grid, ARow, 1);

  if Grid = grdDirect then GridName := 'Direct'
  else if Grid = grdPrebase then GridName := 'Prebase'
  else if Grid = grdPostbase then GridName := 'Postbase'
  else if Grid = grdSequences then GridName := 'Sequences'
  else if Grid = grdModifiers then GridName := 'Modifiers'
  else GridName := 'Extra map';

  if (KeyText = '') and (ValueText = '') then
    lblDiagInfo.Caption := GridName + ': empty row'
  else
  begin
    // Say where the glyph actually comes from, and call out shadowing, so the
    // author is not left guessing why an edit in one grid did nothing.
    var Resolved := TLayoutResolver.Resolve(FLayout, KeyText);
    var Line := Format('%s: %s -> %s', [GridName, KeyText, ValueText]);
    if (Grid = grdDirect) and (grdDirect.ColCount > 2) and (grdDirect.Cells[2, ARow] <> '') then
      Line := Line + ' [' + grdDirect.Cells[2, ARow] + ']';
    if Resolved.Found then
      Line := Line + '   resolves from ' + Resolved.SourceLabel
    else if ValueText <> '' then
      Line := Line + '   not resolvable (empty glyph)';

    if RedefinitionIndex.ContainsKey(Trim(KeyText)) then
      Line := Line + '   [shadowed: another section defines this key]';

    lblDiagInfo.Caption := Line;
  end;
end;

procedure TfrmEditorMain.miExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmEditorMain.btnOpenClick(Sender: TObject);
begin
  if not OpenDialog.Execute then
    Exit;

  OpenLayoutFile(OpenDialog.FileName);
end;

procedure TfrmEditorMain.btnSaveClick(Sender: TObject);
begin
  if not Assigned(FLayout) then
    Exit;

  SaveUIToLayout;

  // If file already exists → overwrite silently
  if FCurrentFileName <> '' then
  begin
    // Phase A.4: keep a backup before clobbering the existing file.
    EnsureBackup(FCurrentFileName, DefaultBackupOptions);
    SaveLayoutToFile(FLayout, FCurrentFileName);
    SetModified(False);
  end
  else
  begin
    // First save → ask filename
    if not SaveDialog.Execute then
      Exit;

    FCurrentFileName := SaveDialog.FileName;
    // Phase A.4: no-op for a brand-new file; backs up if the chosen name
    // already exists (Save Dialog's replace confirmation).
    EnsureBackup(FCurrentFileName, DefaultBackupOptions);
    SaveLayoutToFile(FLayout, FCurrentFileName);
    SetModified(False);
  end;
end;

procedure TfrmEditorMain.btnSaveAsClick(Sender: TObject);
begin
  if not Assigned(FLayout) then Exit;
  if not SaveDialog.Execute then Exit;
  SaveUIToLayout;
  FCurrentFileName := SaveDialog.FileName;
  // Phase A.4: brand-new Save As targets are not backed up (EnsureBackup
  // no-ops); overwriting an existing file keeps a backup first.
  EnsureBackup(FCurrentFileName, DefaultBackupOptions);
  SaveLayoutToFile(FLayout, FCurrentFileName);
  SetModified(False);
end;

procedure TfrmEditorMain.LoadLayoutToUI;
begin
  // The virtual keyboard on the Keyboard tab renders this layout. This used to
  // be assigned from the preview builder, which meant the Keyboard tab only
  // worked as a side effect of the Preview tab.
  vkvKeyboard.Layout := FLayout;
  RefreshKeyboardView;

  edtLayoutName.Text := FLayout.Name;

  // Select font in ComboBox
  if ComboBoxFonts.Items.IndexOf(FLayout.FontFamily) >= 0 then
    ComboBoxFonts.ItemIndex :=
      ComboBoxFonts.Items.IndexOf(FLayout.FontFamily)
  else
    ComboBoxFonts.ItemIndex := -1;

  // Select script in ComboBoxScript
  if ComboBoxScript.Items.IndexOf(FLayout.Script) >= 0 then
    ComboBoxScript.ItemIndex := ComboBoxScript.Items.IndexOf(FLayout.Script)
  else
    ComboBoxScript.ItemIndex := -1;


  // Populate property grid
  var PropList := FLayout.Properties.Keys.ToArray;
  grdProperties.RowCount := Length(PropList) + 1;
  grdProperties.Cells[0,0] := 'Property';
  grdProperties.Cells[1,0] := 'Value';
  for var i := 0 to High(PropList) do
  begin
    grdProperties.Cells[0,i+1] := PropList[i];
    grdProperties.Cells[1,i+1] := FLayout.Properties[PropList[i]];
  end;

  // Load hotkey settings from layout properties
  if FLayout.Properties.ContainsKey('HotkeySwitch') then
    edtHotkeySwitch.Text := FLayout.Properties['HotkeySwitch']
  else
    edtHotkeySwitch.Text := '';
  if FLayout.Properties.ContainsKey('HotkeyAction') then
    edtHotkeyAction.Text := FLayout.Properties['HotkeyAction']
  else
    edtHotkeyAction.Text := '';

  LoadDirect;
  LoadPrebase;
  LoadPostbase;
  LoadSequences;
  LoadModifiers;
  LoadExtraMaps;
  UpdateDiagnosticsPanel;
  UpdateEmptyState;
  FRedefinitionsDirty := True;

  // A freshly loaded layout has not been validated, so the dock is stale.
  pnlProblems.Visible := False;
  lstProblems.Items.Clear;
  FreeAndNil(FProblems);
end;

procedure TfrmEditorMain.UpdateEmptyState;
var
  HasLayout: Boolean;
begin
  HasLayout := Assigned(FLayout);

  // The page control is alClient and used to cover the empty-state label
  // completely, so a first-run editor showed blank grids and no guidance.
  if Assigned(PageControl) then
    PageControl.Visible := HasLayout;

  if Assigned(lblEmptyState) then
    lblEmptyState.Visible := not HasLayout;
end;

procedure TfrmEditorMain.LoadLayoutFromCommandLine;
var
  FileName: string;
begin
  if ParamCount < 1 then
    Exit;

  FileName := ParamStr(1);
  if FileName = '' then
    Exit;

  if not FileExists(FileName) then
  begin
    MessageBox(
      Handle,
      PChar('Layout file not found:'#13#10 + FileName),
      'Vittix Indic Editor',
      MB_OK or MB_ICONERROR
    );
    Exit;
  end;

  OpenLayoutFile(FileName);
end;

procedure TfrmEditorMain.OpenLayoutFile(const FileName: string);
begin
  if not ConfirmDiscardChanges then
    Exit;

  FreeAndNil(FLayout);
  FLayout := LoadLayoutFromFile(FileName);
  FCurrentFileName := FileName;
  LoadLayoutToUI;
  UpdateWindowCaption;
  UpdateStatusBar;
  ComboBoxFonts.Enabled := True;
  UpdateLayoutPreview;
  SetModified(False);
end;

procedure TfrmEditorMain.SetModified(Value: Boolean);
begin
  if FIsModified <> Value then
  begin
    FIsModified := Value;
    UpdateWindowCaption;
    UpdateStatusBar;
  end;
end;

procedure TfrmEditorMain.UpdateWindowCaption;
var
  Parts: TStringList;
begin
  if not Assigned(FLayout) then
  begin
    Caption := DEFAULT_EDITOR_CAPTION;
    Exit;
  end;

  Parts := TStringList.Create;
  try
    if Trim(FLayout.Name) <> '' then
      Parts.Add(FLayout.Name);
    if Trim(FLayout.LayoutID) <> '' then
      Parts.Add('ID: ' + FLayout.LayoutID);
    if Trim(FLayout.Script) <> '' then
      Parts.Add('Script: ' + FLayout.Script);
    if Trim(FCurrentFileName) <> '' then
      Parts.Add(ExtractFileName(FCurrentFileName));

    if Parts.Count > 0 then
      Caption := DEFAULT_EDITOR_CAPTION + ' - ' + StringReplace(Trim(Parts.Text), sLineBreak, ' | ', [rfReplaceAll])
    else
      Caption := DEFAULT_EDITOR_CAPTION;

    if FIsModified then
      Caption := Caption + '*';
  finally
    Parts.Free;
  end;
end;

procedure TfrmEditorMain.UpdateDiagnosticsPanel;
var
  Info: string;
begin
  if not Assigned(FLayout) then Exit;
  Info := 'Script: ' + FLayout.Script + ' | Keys: ' + FLayout.DirectMap.Count.ToString;
  Info := Info + ' | Layout Type: ' + FLayout.LayoutType;
  lblDiagInfo.Caption := Info;
  UpdateStatusBar;
end;

procedure TfrmEditorMain.UpdateStatusBar;
begin
  if not Assigned(StatusBar1) then Exit;

  if FCurrentFileName <> '' then
    StatusBar1.Panels[1].Text := ExtractFileName(FCurrentFileName)
  else
    StatusBar1.Panels[1].Text := '(untitled)';

  if Assigned(FLayout) then
    StatusBar1.Panels[2].Text := Format('Keys: %d', [FLayout.DirectMap.Count])
  else
    StatusBar1.Panels[2].Text := 'Keys: 0';

  if FIsModified then
    StatusBar1.Panels[0].Text := 'Modified'
  else
    StatusBar1.Panels[0].Text := 'Ready';
end;

procedure TfrmEditorMain.LoadExtraMaps;
var
  MapName: string;
  Tab: TTabSheet;
  Grid: TStringGrid;
  Map: TDictionary<string, string>;
  i: Integer;
  Keys: TArray<string>;
begin
  // Remove old tabs/grids for ExtraMaps
  for i := PageControl.PageCount - 1 downto 0 do
    if (PageControl.Pages[i].Tag = 999) then
      PageControl.Pages[i].Free;

  // Add a tab and grid for each ExtraMap
  for MapName in FLayout.ExtraMaps.Keys do
  begin
    Tab := TTabSheet.Create(PageControl);
    Tab.PageControl := PageControl;
    Tab.Caption := MapName;
    Tab.Tag := 999; // Mark as dynamic

    Grid := TStringGrid.Create(Tab);
    Grid.Parent := Tab;
    Grid.Align := alClient;
    Grid.Options := [goEditing, goAlwaysShowEditor, goTabs];
    Grid.ColCount := 2;
    Grid.RowCount := 2;
    Grid.FixedRows := 1;
    Grid.Cells[0,0] := 'Key';
    Grid.Cells[1,0] := 'Value';
    Grid.OnSetEditText := GridSetEditText;
    Grid.Hint := 'Edit key-value pairs for ' + MapName + ' mapping.';
    Grid.ColWidths[0] := 120;
    Grid.ColWidths[1] := 220;
    Grid.PopupMenu := pmGridContext;

    Map := FLayout.ExtraMaps[MapName];
    Keys := Map.Keys.ToArray;
    Grid.RowCount := Length(Keys) + 1;
    for i := 0 to High(Keys) do
    begin
      Grid.Cells[0,i+1] := Keys[i];
      Grid.Cells[1,i+1] := Map[Keys[i]];
    end;
  end;
end;

procedure TfrmEditorMain.miAddKeyClick(Sender: TObject);
var
  Grid: TStringGrid;
  Row: Integer;
begin
  Grid := GetActiveGrid;
  if (Grid = nil) or not (goEditing in Grid.Options) then
    Exit;

  Row := Grid.RowCount;
  Grid.RowCount := Row + 1;
  Grid.Cells[0,Row] := 'NewKey';
  Grid.Cells[1,Row] := '';
  // Review D.1: a fresh row must not inherit the preview of whatever row
  // previously occupied it.
  if (Grid = grdDirect) and (Grid.ColCount > 3) then
    Grid.Cells[3,Row] := '';
  SaveUIToLayout;
end;

procedure TfrmEditorMain.miRemoveKeyClick(Sender: TObject);
var
  Grid: TStringGrid;
begin
  Grid := GetActiveGrid;
  if (Grid = nil) or not (goEditing in Grid.Options) then
    Exit;

  RemoveGridRow(Grid, Grid.Row);
  SetInspectorFromSelection(Grid, Grid.Row);
  SaveUIToLayout;
end;

procedure TfrmEditorMain.miCopyClick(Sender: TObject);
var
  Grid: TStringGrid;
  Row: Integer;
begin
  Grid := GetActiveGrid;
  if Grid = nil then
    Exit;

  Row := Grid.Row;
  if Row >= Grid.FixedRows then
  begin
    if (Grid = grdDirect) and (Grid.ColCount > 2) and (Grid.Cells[2, Row] <> '') then
      Clipboard.AsText := Grid.Cells[0, Row] + #9 + Grid.Cells[1, Row] + #9 + Grid.Cells[2, Row]
    else
      Clipboard.AsText := Grid.Cells[0, Row] + #9 + Grid.Cells[1, Row];
  end;
end;

procedure TfrmEditorMain.miPasteClick(Sender: TObject);
var
  Grid: TStringGrid;
  Row: Integer;
  Parts: TArray<string>;
begin
  Grid := GetActiveGrid;
  if (Grid = nil) or not (goEditing in Grid.Options) then
    Exit;

  Row := Grid.Row;
  if Row >= Grid.FixedRows then
  begin
    Parts := Clipboard.AsText.Split([#9]);
    if Length(Parts) >= 2 then
    begin
      Grid.Cells[0, Row] := Parts[0];
      Grid.Cells[1, Row] := Parts[1];
      // Review D.1: the clipboard is the row's WHOLE content — pasting a
      // 2-value (old-format) row over one that carries a direct_classes
      // value must clear the class, or the old class silently transfers to
      // the pasted key on the next sync.
      if Grid = grdDirect then
      begin
        if (Length(Parts) >= 3) and (Grid.ColCount > 2) then
          Grid.Cells[2, Row] := Parts[2]
        else if Grid.ColCount > 2 then
          Grid.Cells[2, Row] := '';
        // Mirror the glyph into the Preview column like GridSetEditText does,
        // so the pasted row does not show a stale preview until the next
        // full render.
        if (Grid.ColCount > 3) then
          Grid.Cells[3, Row] := Grid.Cells[1, Row];
      end;
      SetInspectorFromSelection(Grid, Row);
      SaveUIToLayout;
    end;
  end;
end;

procedure TfrmEditorMain.miValidateClick(Sender: TObject);
var
  Errors: TValidationErrors;
begin
  if not Assigned(FLayout) then
  begin
    MessageBox(Handle, 'Open or create a layout before validating.',
      'Vittix Indic Editor', MB_OK or MB_ICONINFORMATION);
    Exit;
  end;

  Errors := TValidationErrors.Create;
  try
    TLayoutValidation.ValidateLayout(FLayout, Errors);
    ShowValidationErrors(Errors);
  finally
    Errors.Free;
  end;
end;

procedure TfrmEditorMain.ShowValidationErrors(const Errors: TValidationErrors);
var
  E: TValidationError;
begin
  // Results go to the dock instead of a modal wall of text. The diagnostics
  // strip keeps one short summary line, so the two no longer share a label.
  FreeAndNil(FProblems);
  FProblems := TValidationErrors.Create;
  for E in Errors do
    FProblems.Add(E);

  lstProblems.Items.BeginUpdate;
  try
    lstProblems.Items.Clear;
    for E in FProblems do
      lstProblems.Items.Add(E.ToString);
  finally
    lstProblems.Items.EndUpdate;
  end;

  if Errors.Count = 0 then
  begin
    lblProblemsSummary.Caption := 'Problems';
    pnlProblems.Visible := False;
    lblDiagInfo.Caption := 'Validation: layout is valid.';
    Exit;
  end;

  lblProblemsSummary.Caption := Format('Problems - %d issue(s). Double-click to jump to the row.',
    [Errors.Count]);
  pnlProblems.Visible := True;
  lblDiagInfo.Caption := Format('Validation: %d issue(s), listed below.', [Errors.Count]);
end;

function TfrmEditorMain.GridForSection(const Section: string): TStringGrid;
begin
  Result := nil;
  if SameText(Section, 'Direct') then
    Result := grdDirect
  else if SameText(Section, 'Prebase') then
    Result := grdPrebase
  else if SameText(Section, 'Postbase') then
    Result := grdPostbase
  else if SameText(Section, 'Sequences') then
    Result := grdSequences
  else if SameText(Section, 'Modifiers') then
    Result := grdModifiers;
end;

procedure TfrmEditorMain.btnProblemsCloseClick(Sender: TObject);
begin
  pnlProblems.Visible := False;
end;

procedure TfrmEditorMain.lstProblemsDblClick(Sender: TObject);
var
  Index, Row: Integer;
  Problem: TValidationError;
  Grid: TStringGrid;
begin
  Index := lstProblems.ItemIndex;
  if (Index < 0) or (FProblems = nil) or (Index >= FProblems.Count) then
    Exit;

  Problem := FProblems[Index];
  Grid := GridForSection(Problem.Section);
  if Grid = nil then
    Exit;

  Row := FindRowByKey(Grid, Problem.Key);
  if Row < 0 then
    Exit;

  if Grid.Parent is TTabSheet then
    PageControl.ActivePage := TTabSheet(Grid.Parent);
  SelectGridRow(Grid, Row);
end;

procedure TfrmEditorMain.LoadDirect;
begin
  if edtSearchDirect.Text <> '' then
    edtSearchDirect.Text := '';
  RenderDirect('');
end;

procedure TfrmEditorMain.LoadPrebase;
begin
  if edtSearchPrebase.Text <> '' then
    edtSearchPrebase.Text := '';
  RenderPrebase('');
end;

procedure TfrmEditorMain.LoadPostbase;
begin
  if edtSearchPostbase.Text <> '' then
    edtSearchPostbase.Text := '';
  RenderPostbase('');
end;

procedure TfrmEditorMain.LoadSequences;
begin
  if edtSearchSequences.Text <> '' then
    edtSearchSequences.Text := '';
  RenderSequences('');
end;

procedure TfrmEditorMain.LoadModifiers;
begin
  if edtSearchModifiers.Text <> '' then
    edtSearchModifiers.Text := '';
  RenderModifiers('');
end;

{ --------------------------------------------------
  Section renderers

  Load and filter both go through these, so every column (including the
  preview column and its header) is always written, and the ownership array
  always matches exactly what is on screen.
-------------------------------------------------- }

procedure TfrmEditorMain.RenderDirect(const Filter: string);
var
  Keys: TArray<string>;
  I, Row: Integer;
  Needle, Glyph, KeyClass: string;
begin
  grdDirect.ColCount := 4;
  grdDirect.DefaultRowHeight := GRID_ROW_HEIGHT;
  grdDirect.ColWidths[0] := 60;
  grdDirect.ColWidths[1] := 100;
  grdDirect.ColWidths[2] := 100;
  grdDirect.ColWidths[3] := 120;
  grdDirect.Cells[0, 0] := 'Key';
  grdDirect.Cells[1, 0] := 'Glyph';
  grdDirect.Cells[2, 0] := 'Class';
  grdDirect.Cells[3, 0] := 'Preview';
  grdDirect.RowCount := 1;
  FDirectOwned := nil;

  if FLayout = nil then
  begin
    grdDirect.RowCount := 2;
    Exit;
  end;

  Needle := LowerCase(Trim(Filter));
  Keys := FLayout.DirectMap.Keys.ToArray;
  TArray.Sort<string>(Keys);

  Row := grdDirect.FixedRows;
  for I := 0 to High(Keys) do
  begin
    Glyph := FLayout.DirectMap[Keys[I]];
    KeyClass := '';
    if not FLayout.DirectClasses.TryGetValue(Keys[I], KeyClass) then
      KeyClass := '';

    if (Needle <> '') and (Pos(Needle, LowerCase(Keys[I])) = 0) and
       (Pos(Needle, LowerCase(Glyph)) = 0) and
       (Pos(Needle, LowerCase(KeyClass)) = 0) then
      Continue;

    grdDirect.RowCount := Row + 1;
    grdDirect.Cells[0, Row] := Keys[I];
    grdDirect.Cells[1, Row] := Glyph;
    grdDirect.Cells[2, Row] := KeyClass;
    grdDirect.Cells[3, Row] := Glyph;
    Inc(Row);
  end;

  if grdDirect.RowCount < 2 then
    grdDirect.RowCount := 2;

  FDirectOwned := CollectOwnedKeys(grdDirect);
  ReportFilterCount(grdDirect, FLayout.DirectMap.Count);
end;

procedure TfrmEditorMain.RenderPostbase(const Filter: string);
var
  Keys: TArray<string>;
  I, Row: Integer;
  Needle, Glyph: string;
begin
  grdPostbase.ColCount := 3;
  grdPostbase.DefaultRowHeight := GRID_ROW_HEIGHT;
  grdPostbase.ColWidths[2] := 120;
  grdPostbase.Cells[0, 0] := 'Key';
  grdPostbase.Cells[1, 0] := 'Glyph';
  grdPostbase.Cells[2, 0] := 'Preview';
  grdPostbase.RowCount := 1;
  FPostbaseOwned := nil;

  if FLayout = nil then
  begin
    grdPostbase.RowCount := 2;
    Exit;
  end;

  Needle := LowerCase(Trim(Filter));
  Keys := FLayout.PostbaseMap.Keys.ToArray;
  TArray.Sort<string>(Keys);

  Row := grdPostbase.FixedRows;
  for I := 0 to High(Keys) do
  begin
    Glyph := FLayout.PostbaseMap[Keys[I]];
    if (Needle <> '') and (Pos(Needle, LowerCase(Keys[I])) = 0) and
       (Pos(Needle, LowerCase(Glyph)) = 0) then
      Continue;

    grdPostbase.RowCount := Row + 1;
    grdPostbase.Cells[0, Row] := Keys[I];
    grdPostbase.Cells[1, Row] := Glyph;
    grdPostbase.Cells[2, Row] := Glyph;
    Inc(Row);
  end;

  if grdPostbase.RowCount < 2 then
    grdPostbase.RowCount := 2;

  FPostbaseOwned := CollectOwnedKeys(grdPostbase);
  ReportFilterCount(grdPostbase, FLayout.PostbaseMap.Count);
end;

procedure TfrmEditorMain.RenderSequences(const Filter: string);
var
  Keys: TArray<string>;
  I, Row: Integer;
  Needle, Glyph: string;
begin
  grdSequences.ColCount := 3;
  grdSequences.DefaultRowHeight := GRID_ROW_HEIGHT;
  grdSequences.ColWidths[2] := 120;
  grdSequences.Cells[0, 0] := 'Keys';
  grdSequences.Cells[1, 0] := 'Output';
  grdSequences.Cells[2, 0] := 'Preview';
  grdSequences.RowCount := 1;
  FSequencesOwned := nil;

  if FLayout = nil then
  begin
    grdSequences.RowCount := 2;
    Exit;
  end;

  Needle := LowerCase(Trim(Filter));
  Keys := FLayout.Sequences.Keys.ToArray;
  TArray.Sort<string>(Keys);

  Row := grdSequences.FixedRows;
  for I := 0 to High(Keys) do
  begin
    Glyph := FLayout.Sequences[Keys[I]];
    if (Needle <> '') and (Pos(Needle, LowerCase(Keys[I])) = 0) and
       (Pos(Needle, LowerCase(Glyph)) = 0) then
      Continue;

    grdSequences.RowCount := Row + 1;
    grdSequences.Cells[0, Row] := Keys[I];
    grdSequences.Cells[1, Row] := Glyph;
    grdSequences.Cells[2, Row] := Glyph;
    Inc(Row);
  end;

  if grdSequences.RowCount < 2 then
    grdSequences.RowCount := 2;

  FSequencesOwned := CollectOwnedKeys(grdSequences);
  ReportFilterCount(grdSequences, FLayout.Sequences.Count);
end;

procedure TfrmEditorMain.RenderPrebase(const Filter: string);
var
  Keys: TArray<string>;
  I, Row: Integer;
  Needle, Glyph: string;
begin
  grdPrebase.ColCount := 3;
  grdPrebase.DefaultRowHeight := GRID_ROW_HEIGHT;
  grdPrebase.ColWidths[2] := 120;
  grdPrebase.Cells[0, 0] := 'Key';
  grdPrebase.Cells[1, 0] := 'Glyph';
  grdPrebase.Cells[2, 0] := 'Preview';
  grdPrebase.RowCount := 1;
  FPrebaseOwned := nil;

  if FLayout = nil then
  begin
    grdPrebase.RowCount := 2;
    Exit;
  end;

  Needle := LowerCase(Trim(Filter));
  Keys := FLayout.PrebaseMap.Keys.ToArray;
  TArray.Sort<string>(Keys);

  Row := grdPrebase.FixedRows;
  for I := 0 to High(Keys) do
  begin
    Glyph := FLayout.PrebaseMap[Keys[I]].Glyph;
    if (Needle <> '') and (Pos(Needle, LowerCase(Keys[I])) = 0) and
       (Pos(Needle, LowerCase(Glyph)) = 0) then
      Continue;

    grdPrebase.RowCount := Row + 1;
    grdPrebase.Cells[0, Row] := Keys[I];
    grdPrebase.Cells[1, Row] := Glyph;
    grdPrebase.Cells[2, Row] := Glyph;
    Inc(Row);
  end;

  if grdPrebase.RowCount < 2 then
    grdPrebase.RowCount := 2;

  FPrebaseOwned := CollectOwnedKeys(grdPrebase);
  ReportFilterCount(grdPrebase, FLayout.PrebaseMap.Count);
end;

procedure TfrmEditorMain.RenderModifiers(const Filter: string);
var
  Keys: TArray<string>;
  I, Row: Integer;
  Needle, Key, Glyph: string;
begin
  grdModifiers.ColCount := 4;
  grdModifiers.DefaultRowHeight := GRID_ROW_HEIGHT;
  grdModifiers.ColWidths[3] := 120;
  grdModifiers.Cells[0, 0] := 'Name';
  grdModifiers.Cells[1, 0] := 'Key';
  grdModifiers.Cells[2, 0] := 'Glyph';
  grdModifiers.Cells[3, 0] := 'Preview';
  grdModifiers.RowCount := 1;
  FModifiersOwned := nil;

  if FLayout = nil then
  begin
    grdModifiers.RowCount := 2;
    Exit;
  end;

  Needle := LowerCase(Trim(Filter));
  Keys := FLayout.Modifiers.Keys.ToArray;
  TArray.Sort<string>(Keys);

  Row := grdModifiers.FixedRows;
  for I := 0 to High(Keys) do
  begin
    Key := FLayout.Modifiers[Keys[I]].Key;
    Glyph := FLayout.Modifiers[Keys[I]].Glyph;
    if (Needle <> '') and (Pos(Needle, LowerCase(Keys[I])) = 0) and
       (Pos(Needle, LowerCase(Glyph)) = 0) then
      Continue;

    grdModifiers.RowCount := Row + 1;
    grdModifiers.Cells[0, Row] := Keys[I];
    grdModifiers.Cells[1, Row] := Key;
    grdModifiers.Cells[2, Row] := Glyph;
    grdModifiers.Cells[3, Row] := Glyph;
    Inc(Row);
  end;

  if grdModifiers.RowCount < 2 then
    grdModifiers.RowCount := 2;

  FModifiersOwned := CollectOwnedKeys(grdModifiers);
  ReportFilterCount(grdModifiers, FLayout.Modifiers.Count);
end;

function TfrmEditorMain.CollectOwnedKeys(Grid: TStringGrid): TArray<string>;
var
  I, R: Integer;
begin
  SetLength(Result, Grid.RowCount - Grid.FixedRows);
  for R := Grid.FixedRows to Grid.RowCount - 1 do
  begin
    I := R - Grid.FixedRows;
    Result[I] := Trim(Grid.Cells[0, R]);
  end;
end;

function TfrmEditorMain.CollectStringRows(Grid: TStringGrid): TArray<TStringMappingRow>;
var
  I, R: Integer;
begin
  SetLength(Result, Grid.RowCount - Grid.FixedRows);
  for R := Grid.FixedRows to Grid.RowCount - 1 do
  begin
    I := R - Grid.FixedRows;
    Result[I].Key := Trim(Grid.Cells[0, R]);
    Result[I].Value := Trim(Grid.Cells[1, R]);
  end;
end;

function TfrmEditorMain.CollectDirectClassRows(Grid: TStringGrid): TArray<TStringMappingRow>;
var
  I, R: Integer;
begin
  SetLength(Result, Grid.RowCount - Grid.FixedRows);
  for R := Grid.FixedRows to Grid.RowCount - 1 do
  begin
    I := R - Grid.FixedRows;
    Result[I].Key := Trim(Grid.Cells[0, R]);
    if Grid.ColCount > 2 then
      Result[I].Value := LowerCase(Trim(Grid.Cells[2, R]))
    else
      Result[I].Value := '';
  end;
end;

function TfrmEditorMain.CollectPrebaseRows: TArray<TEditorMapping>;
var
  I, R: Integer;
begin
  SetLength(Result, grdPrebase.RowCount - grdPrebase.FixedRows);
  for R := grdPrebase.FixedRows to grdPrebase.RowCount - 1 do
  begin
    I := R - grdPrebase.FixedRows;
    Result[I].Name := Trim(grdPrebase.Cells[0, R]);
    Result[I].Key := Trim(grdPrebase.Cells[0, R]);
    Result[I].Glyph := Trim(grdPrebase.Cells[1, R]);
  end;
end;

function TfrmEditorMain.CollectModifierRows: TArray<TEditorMapping>;
var
  I, R: Integer;
begin
  SetLength(Result, grdModifiers.RowCount - grdModifiers.FixedRows);
  for R := grdModifiers.FixedRows to grdModifiers.RowCount - 1 do
  begin
    I := R - grdModifiers.FixedRows;
    Result[I].Name := Trim(grdModifiers.Cells[0, R]);
    Result[I].Key := Trim(grdModifiers.Cells[1, R]);
    Result[I].Glyph := Trim(grdModifiers.Cells[2, R]);
  end;
end;

procedure TfrmEditorMain.ReportFilterCount(Grid: TStringGrid; Total: Integer);
var
  Shown, I: Integer;
begin
  if not Assigned(StatusBar1) or (StatusBar1.Panels.Count < 4) then
    Exit;

  Shown := 0;
  for I := Grid.FixedRows to Grid.RowCount - 1 do
    if Trim(Grid.Cells[0, I]) <> '' then
      Inc(Shown);

  if Shown < Total then
    StatusBar1.Panels[3].Text := Format('Showing %d of %d', [Shown, Total])
  else
    StatusBar1.Panels[3].Text := '';
end;

procedure TfrmEditorMain.btnAddKeyMapClick(Sender: TObject);
var
  MapName: string;
begin
  MapName := InputBox('Add Key Map Type', 'Enter new key map type name:', '');
  if (MapName <> '') and Assigned(FLayout) then
  begin
    if not FLayout.ExtraMaps.ContainsKey(MapName) then
      FLayout.ExtraMaps.Add(MapName, TDictionary<string, string>.Create);
    ShowMessage('Key map type "' + MapName + '" added.');
    LoadLayoutToUI;
  end;
end;

procedure TfrmEditorMain.btnInspectorApplyClick(Sender: TObject);
var
  Grid: TStringGrid;
  Row: Integer;
  Key: string;
begin
  Key := Trim(edtInspectorKey.Text);
  if Key = '' then
    Exit;

  // The inspector owns the edit. With no grid row selected it writes to Direct,
  // which is where a keyboard selection lands.
  Grid := GetSelectedGrid;
  if (Grid = nil) or (Grid.Row < Grid.FixedRows) then
    Grid := grdDirect;

  Row := FindRowByKey(Grid, Key);
  if Row < 0 then
  begin
    if not (goEditing in Grid.Options) then
      Exit;
    AddRowToGrid(Grid);
    Row := Grid.RowCount - 1;
  end;

  PushUndo;
  Grid.Cells[0, Row] := Key;
  if Grid.ColCount > 1 then
    Grid.Cells[1, Row] := edtInspectorValue.Text;
  if (Grid = grdDirect) and (Grid.ColCount > 3) then
    Grid.Cells[3, Row] := edtInspectorValue.Text;
  Grid.Invalidate;
  SaveUIToLayout;
  UpdateLayoutPreview;
  SelectGridRow(Grid, Row);
end;

procedure TfrmEditorMain.btnInspectorClearClick(Sender: TObject);
var
  Grid: TStringGrid;
  Row: Integer;
  Key: string;
begin
  // Mirrors Apply: the inspector owns the edit, and with no grid row selected
  // the edit belongs to Direct, which is where a keyboard selection lands.
  // The old version bailed out whenever focus was not on a grid, so Clear did
  // nothing at all from the Keyboard tab.
  Key := Trim(edtInspectorKey.Text);
  if Key = '' then Exit;

  Grid := GetSelectedGrid;
  if (Grid = nil) or (Grid.Row < Grid.FixedRows) then
    Grid := grdDirect;

  Row := FindRowByKey(Grid, Key);
  if Row < 0 then Exit;

  PushUndo;
  Grid.Rows[Row].Clear;
  Grid.Invalidate;
  SaveUIToLayout;
  UpdateLayoutPreview;
end;

procedure TfrmEditorMain.btnAddRowClick(Sender: TObject);
var
  Grid: TStringGrid;
begin
  if not (Sender is TComponent) then
    Exit;

  case TComponent(Sender).Tag of
    0: Grid := grdDirect;
    1: Grid := grdPrebase;
    2: Grid := grdPostbase;
    3: Grid := grdModifiers;
  else
    Exit;
  end;

  if not (goEditing in Grid.Options) then
    Exit;

  AddRowToGrid(Grid);
  SaveUIToLayout;
end;

function TfrmEditorMain.GridForCurrentTab: TStringGrid;
begin
  Result := nil;
  if not Assigned(PageControl) or not Assigned(PageControl.ActivePage) then
    Exit;

  if PageControl.ActivePage = tabDirect then
    Result := grdDirect
  else if PageControl.ActivePage = tabPrebase then
    Result := grdPrebase
  else if PageControl.ActivePage = tabPostbase then
    Result := grdPostbase
  else if PageControl.ActivePage = tabSequences then
    Result := grdSequences
  else if PageControl.ActivePage = tabModifiers then
    Result := grdModifiers;
end;

procedure TfrmEditorMain.btnInspectorAddClick(Sender: TObject);
var
  Grid: TStringGrid;
begin
  // The old fallback derived the target grid from the sender's parent name,
  // which matched nothing for the inspector's own button, so it did nothing.
  Grid := GetSelectedGrid;
  if Grid = nil then
    Grid := GridForCurrentTab;

  if (Grid = nil) or not (goEditing in Grid.Options) then
    Exit;

  AddRowToGrid(Grid);
  SaveUIToLayout;
end;

procedure TfrmEditorMain.GridDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
  Grid: TStringGrid;
  Text, KeyText, ValueText, Badge: string;
  LStyle: TCustomStyleServices;
  ClrHeaderBg, ClrCellBg, ClrCellAlt, ClrText, ClrSelBg, ClrSelText, ClrBadge: TColor;
begin
  Grid := Sender as TStringGrid;
  LStyle := StyleServices;

  // One palette for the whole grid, so high-contrast mode cannot end up with
  // dark text on a dark surface (or the reverse) in part of the table.
  if FHighContrast then
  begin
    ClrHeaderBg := clBlack;
    ClrCellBg := clBlack;
    ClrCellAlt := $00202020;
    ClrText := clWhite;
    ClrSelBg := clYellow;
    ClrSelText := clBlack;
    ClrBadge := clYellow;
  end
  else
  begin
    // Normal palette comes from the editor's token set rather than the system
    // theme, so surfaces, text and the selection treatment stay consistent.
    var Theme := EditorThemeCurrent;
    ClrHeaderBg := Theme.Surface;
    ClrCellBg := Theme.Canvas;
    ClrCellAlt := Theme.SurfaceAlt;
    ClrText := Theme.Text;
    ClrSelBg := Theme.AccentSubtle;
    ClrSelText := Theme.Text;
    ClrBadge := Theme.Warning;
  end;

  // -------------------------------
  // HEADER ROW (titles)
  // -------------------------------
  if ARow < Grid.FixedRows then
  begin
    Grid.Canvas.Brush.Color := ClrHeaderBg;
    Grid.Canvas.FillRect(Rect);

    Grid.Canvas.Font.Name := 'Segoe UI';
    Grid.Canvas.Font.Size := 9;
    Grid.Canvas.Font.Style := [fsBold];
    Grid.Canvas.Font.Color := ClrText;

    Text := Grid.Cells[ACol, ARow];

    DrawText(
      Grid.Canvas.Handle,
      PChar(Text),
      Length(Text),
      Rect,
      DT_SINGLELINE or DT_VCENTER or DT_CENTER
    );
    Exit;
  end;

  // -------------------------------
  // NORMAL CELLS
  // -------------------------------
  if Odd(ARow) then
    Grid.Canvas.Brush.Color := ClrCellAlt
  else
    Grid.Canvas.Brush.Color := ClrCellBg;
  Grid.Canvas.FillRect(Rect);

  Text := Grid.Cells[ACol, ARow];
  KeyText := '';
  ValueText := '';
  if ARow >= Grid.FixedRows then
  begin
    KeyText := Trim(Grid.Cells[0, ARow]);
    if Grid.ColCount > 1 then
      ValueText := Trim(Grid.Cells[1, ARow]);
  end;

  // PREVIEW COLUMN (rightmost) — use layout font
  if (ACol = Grid.ColCount - 1) and Assigned(FLayout) then
  begin
    Grid.Canvas.Font.Name := FLayout.FontFamily;
    Grid.Canvas.Font.Size := 16;
  end
  else
  begin
    Grid.Canvas.Font.Name := 'Segoe UI';
    Grid.Canvas.Font.Size := 10;
  end;

  Grid.Canvas.Font.Style := [];
  Grid.Canvas.Font.Color := ClrText;

  // Selection highlight
  if gdSelected in State then
  begin
    Grid.Canvas.Brush.Color := ClrSelBg;
    Grid.Canvas.Font.Color := ClrSelText;
    Grid.Canvas.FillRect(Rect);
  end;

  // Status badge. Drawn once per row in the glyph column, not once per cell:
  // it used to repeat in every column and collide with the preview glyph.
  Badge := '';
  if (ARow >= Grid.FixedRows) and
     (((Grid = grdDirect) and (ACol = 1)) or
      ((Grid <> grdDirect) and (ACol = Grid.ColCount - 2))) then
  begin
    if KeyText = '' then
      Badge := 'EMPTY'
    else if ValueText = '' then
      Badge := 'UNMAPPED'
    else if IsRealDuplicateKey(Grid, KeyText) then
      Badge := 'DUP';
  end;

  if Badge <> '' then
  begin
    Grid.Canvas.Font.Style := [fsBold];
    Grid.Canvas.Font.Color := ClrBadge;
    DrawText(
      Grid.Canvas.Handle,
      PChar(Badge),
      Length(Badge),
      Rect,
      DT_SINGLELINE or DT_VCENTER or DT_RIGHT
    );
    Grid.Canvas.Font.Color := ClrText;
  end;

  DrawText(
    Grid.Canvas.Handle,
    PChar(Text),
    Length(Text),
    Rect,
    DT_SINGLELINE or DT_VCENTER or DT_LEFT or DT_END_ELLIPSIS
  );
end;

procedure TfrmEditorMain.SyncUIToModel;
var
  R: Integer;
  Key, Glyph: string;
  Tab: TTabSheet;
  MapName: string;
  ExtraMap: TDictionary<string, string>;
  ExtraGrid: TStringGrid;
  I: Integer;
begin
  if FLayout = nil then Exit;

  // The redefinition index describes the model, so it is stale from here on.
  FRedefinitionsDirty := True;

  PushUndo;

  FLayout.Name := edtLayoutName.Text;
  FLayout.FontFamily := ComboBoxFonts.Text;
  FLayout.Script := ComboBoxScript.Text;

  FLayout.Properties.AddOrSetValue('HotkeySwitch', edtHotkeySwitch.Text);
  FLayout.Properties.AddOrSetValue('HotkeyAction', edtHotkeyAction.Text);

  // Only the rows currently on screen are applied. Any mapping a search filter
  // is hiding stays in the model untouched. This is the fix for the save path
  // that used to delete every mapping the filter excluded.
  SyncVisibleStringMap(FLayout.DirectMap, CollectStringRows(grdDirect), FDirectOwned);
  SyncVisibleStringMap(FLayout.DirectClasses, CollectDirectClassRows(grdDirect), FDirectOwned);
  // Review D.3: a class whose key just lost its glyph (row's glyph cleared)
  // would survive as an invisible orphan the UI can neither show nor edit
  // (the validator warns, but the model should simply agree with the grid).
  // Prune entries whose key is no longer a direct mapping. Filtered-out rows
  // are safe: their keys are still in DirectMap, so nothing hidden is lost.
  for var ClassKey in FLayout.DirectClasses.Keys.ToArray do
    if not FLayout.DirectMap.ContainsKey(ClassKey) then
      FLayout.DirectClasses.Remove(ClassKey);
  SyncVisibleMappings(FLayout.PrebaseMap, CollectPrebaseRows, FPrebaseOwned, 'prebase');
  SyncVisibleStringMap(FLayout.PostbaseMap, CollectStringRows(grdPostbase), FPostbaseOwned);
  SyncVisibleStringMap(FLayout.Sequences, CollectStringRows(grdSequences), FSequencesOwned);
  SyncVisibleMappings(FLayout.Modifiers, CollectModifierRows, FModifiersOwned, 'modifier');

  // Ownership follows what is on screen now, so the next edit is attributed to
  // the right model entries.
  FDirectOwned := CollectOwnedKeys(grdDirect);
  FPrebaseOwned := CollectOwnedKeys(grdPrebase);
  FPostbaseOwned := CollectOwnedKeys(grdPostbase);
  FSequencesOwned := CollectOwnedKeys(grdSequences);
  FModifiersOwned := CollectOwnedKeys(grdModifiers);

  for I := PageControl.PageCount - 1 downto 0 do
  begin
    Tab := PageControl.Pages[I];
    if Tab.Tag = 999 then
    begin
      MapName := Tab.Caption;
      if FLayout.ExtraMaps.ContainsKey(MapName) then
        FLayout.ExtraMaps[MapName].Clear
      else
      begin
        ExtraMap := TDictionary<string, string>.Create;
        FLayout.ExtraMaps.Add(MapName, ExtraMap);
      end;

      ExtraGrid := nil;
      if Tab.ControlCount > 0 then
        if Tab.Controls[0] is TStringGrid then
          ExtraGrid := Tab.Controls[0] as TStringGrid;

      if Assigned(ExtraGrid) then
      begin
        ExtraMap := FLayout.ExtraMaps[MapName];
        for R := ExtraGrid.FixedRows to ExtraGrid.RowCount - 1 do
        begin
          Key := Trim(ExtraGrid.Cells[0, R]);
          Glyph := Trim(ExtraGrid.Cells[1, R]);
          if (Key <> '') and (Glyph <> '') then
            ExtraMap.Add(Key, Glyph);
        end;
      end;
    end;
  end;

  // Every model write funnels through here, and the Keyboard tab paints from
  // the model on demand only. Without this the key that was just applied keeps
  // showing its previous glyph until some unrelated repaint happens to run
  // (clicking another key, switching tabs, resizing the window).
  RefreshKeyboardView;
end;

procedure TfrmEditorMain.SaveUIToLayout;
begin
  SyncUIToModel;
end;

procedure TfrmEditorMain.RefreshKeyboardView;
begin
  if not Assigned(vkvKeyboard) then
    Exit;

  // Keep the key glyphs in the layout's own font, the same one the Preview
  // column and the typing preview use, so all three surfaces agree.
  if Assigned(FLayout) then
    vkvKeyboard.GlyphFontName := FLayout.FontFamily
  else
    vkvKeyboard.GlyphFontName := '';

  vkvKeyboard.Invalidate;
end;

procedure TfrmEditorMain.ComboBox1Change(Sender: TObject);
begin
  if not Assigned(FLayout) then
    Exit;

  FLayout.FontFamily := ComboBoxFonts.Text;

  // Refresh all grids
  grdDirect.Invalidate;
  grdPrebase.Invalidate;
  grdPostbase.Invalidate;
  grdSequences.Invalidate;
  grdModifiers.Invalidate;
end;

procedure TfrmEditorMain.GridSelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
  // Prevent editing header row
  CanSelect := ARow >= (Sender as TStringGrid).FixedRows;
  if CanSelect and (Sender is TStringGrid) then
    SetInspectorFromSelection(Sender as TStringGrid, ARow);
end;

procedure TfrmEditorMain.GridMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Col, Row: Integer;
  Grid: TStringGrid;
begin
  Grid := Sender as TStringGrid;
  Grid.MouseToCell(X, Y, Col, Row);

  if Row >= Grid.FixedRows then
  begin
    Grid.Col := Col;
    Grid.Row := Row;
    Grid.EditorMode := True; // 🔴 THIS enables typing
    SetInspectorFromSelection(Grid, Row);
  end;
end;

// Fired by TVittixKeyboardView when the user clicks a key. The control has
// already computed the current mapping and repainted itself with the
// selection highlight — this handler just wires that into the rest of the
// editor's UI (quick-assign box + the matching grid row, for anyone still
// working from the grid tabs).
procedure TfrmEditorMain.vkvKeyboardKeySelect(Sender: TObject; const KeyName, CurrentGlyph: string);
var
  Row: Integer;
begin
  FSelectedKeyboardKey := KeyName;

  // The inspector is the single editing surface now, so the keyboard selection
  // loads into it instead of into a second set of controls.
  edtInspectorKey.Text := KeyName;
  edtInspectorValue.Text := CurrentGlyph;

  Row := FindRowByKey(grdDirect, KeyName);
  if Row >= 0 then
    SelectGridRow(grdDirect, Row)
  else
  begin
    var Resolved := TLayoutResolver.Resolve(FLayout, KeyName);
    if Resolved.Found then
      lblDiagInfo.Caption := Format(
        'Keyboard: %s resolves from %s. Enter a value here and Apply to override it.',
        [KeyName, Resolved.SourceLabel])
    else
      lblDiagInfo.Caption := Format(
        'Keyboard: %s is unmapped. Enter a value and press Apply.', [KeyName]);
  end;

  edtInspectorValue.SetFocus;
  edtInspectorValue.SelectAll;
end;

// Fired by TVittixKeyboardView.AssignKey/ClearKey after it has already
// written (or removed) the Direct-map entry. Everything else that mirrors
// that mapping — the grid, the preview tab, the diagnostics line — refreshes
// from here.
procedure TfrmEditorMain.vkvKeyboardKeyAssign(Sender: TObject; const KeyName, NewGlyph: string);
begin
  LoadDirect;
  UpdateLayoutPreview;

  if NewGlyph <> '' then
    lblDiagInfo.Caption := Format('Direct: %s -> %s', [KeyName, NewGlyph])
  else
    lblDiagInfo.Caption := KeyName + ' cleared';
end;


end.
