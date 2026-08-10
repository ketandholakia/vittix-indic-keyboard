unit frmEditorMain;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
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
  LayoutLoader,
  LayoutJsonIO,
  Validation,
  KeyboardPainter,
  Vcl.ToolWin;

type

  TfrmEditorMain = class(TForm)
    pnlTop: TPanel;

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
    btnOpen: TButton;
    btnSave: TButton;
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
    tabKeyboard: TTabSheet;
    pnlKeyboardHeader: TPanel;
    lblKeyboardHint: TLabel;
    pbRealKeyboard: TPaintBox;
    tabPreview: TTabSheet;
    pnlPreview: TPanel;
    pnlDiagnostics: TPanel;
    lblDiagInfo: TLabel;
    btnSaveAs: TButton;
    lblEmptyState: TLabel;
    btnNewLayout: TButton;
    btnExportLayout: TButton;
    btnImportLayout: TButton;
    btnUndo: TButton;
    btnRedo: TButton;
    btnAddKeyMap: TButton;
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
    ToolBar1: TToolBar;
    tbtnUndo: TToolButton;
    tbtnRedo: TToolButton;
    tbtnHelp: TToolButton;
    tbtnNew: TToolButton;
    tbtnExportLayout: TToolButton;
    tbtnImportLayout: TToolButton;
    tbtnSave: TToolButton;
    tbtnSaveAs: TToolButton;
    tbtnOpen: TToolButton;
    pnlLayoutInfo: TPanel;
    pnlProperties: TPanel;
    pnlHotkeys: TPanel;
    pnlAccessibility: TPanel;
    pnlSideScroll: TScrollBox;
    splitterVert: TSplitter;
    lblSectionLayout: TLabel;
    lblSectionProps: TLabel;
    lblSectionHotkeys: TLabel;
    lblSectionDiag: TLabel;
    lblDivider1: TLabel;
    lblDivider2: TLabel;
    lblDivider3: TLabel;
    lblDivider4: TLabel;
    pnlSearchDirect: TPanel;
    pnlSearchPrebase: TPanel;
    pnlSearchPostbase: TPanel;
    pnlSearchSequences: TPanel;
    pnlSearchModifiers: TPanel;
  procedure UpdateLayoutPreview;
    procedure pbRealKeyboardPaint(Sender: TObject);
    procedure edtSearchDirectChange(Sender: TObject);
    procedure edtSearchPrebaseChange(Sender: TObject);
    procedure edtSearchPostbaseChange(Sender: TObject);
    procedure edtSearchSequencesChange(Sender: TObject);
    procedure edtSearchModifiersChange(Sender: TObject);

    procedure FormCreate(Sender: TObject);
    procedure btnOpenClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnSaveAsClick(Sender: TObject);
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
    procedure btnInspectorApplyClick(Sender: TObject);
    procedure btnInspectorClearClick(Sender: TObject);
    procedure btnInspectorAddClick(Sender: TObject);
    procedure pbRealKeyboardMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pbRealKeyboardMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
  private
    FLayout: TKeyboardLayout;
    FCurrentFileName: string;
    FUndoStack: TStack<string>;
    FRedoStack: TStack<string>;
    procedure LoadLayoutFromCommandLine;
    procedure OpenLayoutFile(const FileName: string);
    procedure UpdateWindowCaption;
    procedure PushUndo;

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
    procedure ShowValidationErrors(const Errors: TList<TValidationError>);
    procedure SaveUIToLayout;
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
  public
  end;

var
  gFrmEditorMain: TfrmEditorMain; // ✅ FIXED (no collision)

implementation

{$R *.dfm}

const
  DEFAULT_EDITOR_CAPTION = 'Vittix Indic Keyboard Layout Editor';

procedure EnableGridEditing(Grid: TStringGrid);
begin
  Grid.Options := Grid.Options + [goEditing, goAlwaysShowEditor, goTabs];
end;

procedure AddToolbarButton(Parent: TWinControl; const Caption: string;
  LeftPos: Integer; OnClick: TNotifyEvent);
var
  Btn: TButton;
begin
  Btn := TButton.Create(Parent);
  Btn.Parent := Parent;
  Btn.Left := LeftPos;
  Btn.Top := 6;
  Btn.Width := 84;
  Btn.Height := 24;
  Btn.Caption := Caption;
  Btn.OnClick := OnClick;
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

procedure TfrmEditorMain.FormCreate(Sender: TObject);
begin
  FCurrentFileName := '';
  UpdateWindowCaption;

  ClearGrids;

  LoadInstalledFonts;

  ComboBoxFonts.Enabled := False;
  ComboBoxFonts.ItemIndex := -1;

  EnableGridEditing(grdDirect);
  EnableGridEditing(grdPrebase);
  EnableGridEditing(grdPostbase);
  EnableGridEditing(grdSequences);
  EnableGridEditing(grdModifiers);

  grdDirect.OnSetEditText := GridSetEditText;
  grdPrebase.OnSetEditText := GridSetEditText;
  grdPostbase.OnSetEditText := GridSetEditText;
  grdSequences.OnSetEditText := GridSetEditText;
  grdModifiers.OnSetEditText := GridSetEditText;

  ComboBoxFonts.OnChange := ComboBoxFontsChange;
  pmGridContext.Items[0].OnClick := miAddKeyClick;
  pmGridContext.Items[1].OnClick := miRemoveKeyClick;
  pmGridContext.Items[2].OnClick := miCopyClick;
  pmGridContext.Items[3].OnClick := miPasteClick;
  pmGridContext.Items[4].OnClick := miValidateClick;
  btnHelp.OnClick := btnHelpClick;
  chkHighContrast.OnClick := chkHighContrastClick;
  btnAddKeyMap.OnClick := btnAddKeyMapClick;
  btnInspectorApply.OnClick := btnInspectorApplyClick;
  btnInspectorClear.OnClick := btnInspectorClearClick;
  btnInspectorAdd.OnClick := btnInspectorAddClick;
  pbRealKeyboard.OnMouseDown := pbRealKeyboardMouseDown;
  pbRealKeyboard.OnMouseMove := pbRealKeyboardMouseMove;
  AddToolbarButton(pnlSearchDirect, '+ Add', 500, btnInspectorAddClick);
  AddToolbarButton(pnlSearchPrebase, '+ Add', 500, btnInspectorAddClick);
  AddToolbarButton(pnlSearchPostbase, '+ Add', 500, btnInspectorAddClick);
  AddToolbarButton(pnlSearchSequences, '+ Add', 500, btnInspectorAddClick);
  AddToolbarButton(pnlSearchModifiers, '+ Add', 500, btnInspectorAddClick);
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

  btnNewLayout.OnClick := btnNewLayoutClick;
  btnExportLayout.OnClick := btnExportLayoutClick;
  btnImportLayout.OnClick := btnImportLayoutClick;

  btnUndo.OnClick := btnUndoClick;
  btnRedo.OnClick := btnRedoClick;

  FUndoStack := TStack<string>.Create;
  FRedoStack := TStack<string>.Create;

  LoadLayoutFromCommandLine;
end;
procedure TfrmEditorMain.ComboBoxScriptChange(Sender: TObject);
begin
  if Assigned(FLayout) then
  begin
    FLayout.Script := ComboBoxScript.Text;
    UpdateLayoutPreview;
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
begin
  MessageDlg('Vittix Indic Keyboard Editor'#13#10#13#10 +
    '- See User Guide (Help menu) for details.'#13#10 +
    '- Tooltips are available for most controls.'#13#10 +
    '- For accessibility, use High Contrast Mode.'#13#10#13#10 +
    'Visit: docs/UserGuide_EN.md', mtInformation, [mbOK], 0);
end;

procedure TfrmEditorMain.chkHighContrastClick(Sender: TObject);
begin
  if chkHighContrast.Checked then
  begin
    Color := clBlack;
    Font.Color := clWhite;
    pnlDiagnostics.Color := clBlack;
    lblDiagInfo.Font.Color := clYellow;
  end
  else
  begin
    Color := clBtnFace;
    Font.Color := clWindowText;
    pnlDiagnostics.Color := $00F4F4F4;
    lblDiagInfo.Font.Color := $00666666;
  end;
end;

procedure TfrmEditorMain.PushUndo;
begin
  if FLayout <> nil then
  begin
    FUndoStack.Push(FLayout.ToJSON);
    FRedoStack.Clear;
  end;
end;

procedure TfrmEditorMain.btnUndoClick(Sender: TObject);
var
  PrevState: string;
begin
  if FUndoStack.Count = 0 then Exit;
  if FLayout <> nil then
    FRedoStack.Push(FLayout.ToJSON);
  PrevState := FUndoStack.Pop;
  FreeAndNil(FLayout);
  FLayout := TKeyboardLayout.FromJSON(PrevState); // You may need to implement FromJSON
  LoadLayoutToUI;
  UpdateLayoutPreview;
end;

procedure TfrmEditorMain.btnRedoClick(Sender: TObject);
var
  NextState: string;
begin
  if FRedoStack.Count = 0 then Exit;
  if FLayout <> nil then
    FUndoStack.Push(FLayout.ToJSON);
  NextState := FRedoStack.Pop;
  FreeAndNil(FLayout);
  FLayout := TKeyboardLayout.FromJSON(NextState); // You may need to implement FromJSON
  LoadLayoutToUI;
  UpdateLayoutPreview;
end;
procedure TfrmEditorMain.btnNewLayoutClick(Sender: TObject);
begin
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
end;

procedure TfrmEditorMain.btnExportLayoutClick(Sender: TObject);
begin
  if FLayout = nil then Exit;
  if SaveDialog.Execute then
    SaveLayoutToFile(FLayout, SaveDialog.FileName);
end;

procedure TfrmEditorMain.btnImportLayoutClick(Sender: TObject);
begin
  if OpenDialog.Execute then
  begin
    PushUndo;
    FreeAndNil(FLayout);
    FLayout := LoadLayoutFromFile(OpenDialog.FileName);
    FCurrentFileName := OpenDialog.FileName;
    LoadLayoutToUI;
    UpdateLayoutPreview;
  end;
end;
procedure TfrmEditorMain.edtSearchPrebaseChange(Sender: TObject);
var
  SearchText: string;
  Filtered: TArray<string>;
  Key: string;
  I: Integer;
begin
  if FLayout = nil then Exit;
  SearchText := Trim(edtSearchPrebase.Text).ToLower;
  Filtered := [];
  for Key in FLayout.PrebaseMap.Keys do
    if (SearchText = '') or (Pos(SearchText, Key.ToLower) > 0) or (Pos(SearchText, FLayout.PrebaseMap[Key].Glyph.ToLower) > 0) then
      Filtered := Filtered + [Key];

  grdPrebase.RowCount := Length(Filtered) + 1;
  grdPrebase.Cells[0,0] := 'Key';
  grdPrebase.Cells[1,0] := 'Glyph';
  for I := 0 to High(Filtered) do
  begin
    grdPrebase.Cells[0,I+1] := Filtered[I];
    grdPrebase.Cells[1,I+1] := FLayout.PrebaseMap[Filtered[I]].Glyph;
  end;
end;

procedure TfrmEditorMain.edtSearchPostbaseChange(Sender: TObject);
var
  SearchText: string;
  Filtered: TArray<string>;
  Key: string;
  I: Integer;
begin
  if FLayout = nil then Exit;
  SearchText := Trim(edtSearchPostbase.Text).ToLower;
  Filtered := [];
  for Key in FLayout.PostbaseMap.Keys do
    if (SearchText = '') or (Pos(SearchText, Key.ToLower) > 0) or (Pos(SearchText, FLayout.PostbaseMap[Key].ToLower) > 0) then
      Filtered := Filtered + [Key];

  grdPostbase.RowCount := Length(Filtered) + 1;
  grdPostbase.Cells[0,0] := 'Key';
  grdPostbase.Cells[1,0] := 'Glyph';
  for I := 0 to High(Filtered) do
  begin
    grdPostbase.Cells[0,I+1] := Filtered[I];
    grdPostbase.Cells[1,I+1] := FLayout.PostbaseMap[Filtered[I]];
  end;
end;

procedure TfrmEditorMain.edtSearchSequencesChange(Sender: TObject);
var
  SearchText: string;
  Filtered: TArray<string>;
  Key: string;
  I: Integer;
begin
  if FLayout = nil then Exit;
  SearchText := Trim(edtSearchSequences.Text).ToLower;
  Filtered := [];
  for Key in FLayout.Sequences.Keys do
    if (SearchText = '') or (Pos(SearchText, Key.ToLower) > 0) or (Pos(SearchText, FLayout.Sequences[Key].ToLower) > 0) then
      Filtered := Filtered + [Key];

  grdSequences.RowCount := Length(Filtered) + 1;
  grdSequences.Cells[0,0] := 'Keys';
  grdSequences.Cells[1,0] := 'Output';
  for I := 0 to High(Filtered) do
  begin
    grdSequences.Cells[0,I+1] := Filtered[I];
    grdSequences.Cells[1,I+1] := FLayout.Sequences[Filtered[I]];
  end;
end;

procedure TfrmEditorMain.edtSearchModifiersChange(Sender: TObject);
var
  SearchText: string;
  Filtered: TArray<string>;
  Key: string;
  I: Integer;
begin
  if FLayout = nil then Exit;
  SearchText := Trim(edtSearchModifiers.Text).ToLower;
  Filtered := [];
  for Key in FLayout.Modifiers.Keys do
    if (SearchText = '') or (Pos(SearchText, Key.ToLower) > 0) or (Pos(SearchText, FLayout.Modifiers[Key].Glyph.ToLower) > 0) then
      Filtered := Filtered + [Key];

  grdModifiers.RowCount := Length(Filtered) + 1;
  grdModifiers.Cells[0,0] := 'Name';
  grdModifiers.Cells[1,0] := 'Key';
  grdModifiers.Cells[2,0] := 'Glyph';
  grdModifiers.Cells[3,0] := 'Preview';
  for I := 0 to High(Filtered) do
  begin
    grdModifiers.Cells[0,I+1] := Filtered[I];
    grdModifiers.Cells[1,I+1] := FLayout.Modifiers[Filtered[I]].Key;
    grdModifiers.Cells[2,I+1] := FLayout.Modifiers[Filtered[I]].Glyph;
    grdModifiers.Cells[3,I+1] := FLayout.Modifiers[Filtered[I]].Glyph;
  end;
end;
procedure TfrmEditorMain.edtSearchDirectChange(Sender: TObject);
var
  SearchText: string;
  Filtered: TArray<string>;
  Key: string;
  I: Integer;
begin
  if FLayout = nil then Exit;
  SearchText := Trim(edtSearchDirect.Text).ToLower;
  Filtered := [];
  for Key in FLayout.DirectMap.Keys do
    if (SearchText = '') or (Pos(SearchText, Key.ToLower) > 0) or (Pos(SearchText, FLayout.DirectMap[Key].ToLower) > 0) then
      Filtered := Filtered + [Key];

  grdDirect.RowCount := Length(Filtered) + 1;
  grdDirect.Cells[0,0] := 'Key';
  grdDirect.Cells[1,0] := 'Glyph';
  for I := 0 to High(Filtered) do
  begin
    grdDirect.Cells[0,I+1] := Filtered[I];
    grdDirect.Cells[1,I+1] := FLayout.DirectMap[Filtered[I]];
  end;
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
  UpdateWindowCaption;
  pbRealKeyboard.Invalidate;
  UpdateLayoutPreview;
end;

procedure TfrmEditorMain.UpdateLayoutPreview;
var
  i: Integer;
  lbl: TLabel;
  Keys: TArray<string>;
  Row, Col: Integer;
  Key, Glyph: string;
const
  Cols = 10;
begin
  pbRealKeyboard.Invalidate;

  // Remove all controls from pnlPreview
  for i := pnlPreview.ControlCount - 1 downto 0 do
    pnlPreview.Controls[i].Free;

  if FLayout = nil then Exit;

  Keys := FLayout.DirectMap.Keys.ToArray;
  for i := 0 to High(Keys) do
  begin
    Key := Keys[i];
    Glyph := FLayout.DirectMap[Key];
    Row := i div Cols;
    Col := i mod Cols;

    lbl := TLabel.Create(nil);
    lbl.Parent := pnlPreview;
    lbl.Left := 10 + Col * 36;
    lbl.Top := 10 + Row * 36;
    lbl.Width := 34;
    lbl.Height := 34;
    lbl.Caption := Key + ' → ' + Glyph;
    lbl.Layout := tlCenter;
    lbl.Alignment := taCenter;
    lbl.Transparent := False;
    lbl.Color := clInfoBk;
    lbl.Font.Size := 10;
    lbl.Font.Name := 'Segoe UI';
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

function TfrmEditorMain.IsRealDuplicateKey(Grid: TStringGrid; const Key: string): Boolean;
var
  PairStr: TPair<string, string>;
  KeyCount: Integer;
begin
  Result := False;
  if (FLayout = nil) or (Trim(Key) = '') then
    Exit;

  if Grid = grdDirect then
    Exit(False);

  KeyCount := 0;
  for PairStr in FLayout.DirectMap do
    if SameText(Trim(PairStr.Key), Trim(Key)) then
      Inc(KeyCount);

  for PairStr in FLayout.PostbaseMap do
    if SameText(Trim(PairStr.Key), Trim(Key)) then
      Inc(KeyCount);

  if KeyCount > 1 then
    Exit(True);
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
  Row: Integer;
begin
  if Grid = nil then Exit;
  Row := Grid.RowCount;
  Grid.RowCount := Row + 1;
  Grid.Cells[0, Row] := 'NewKey';
  if Grid.ColCount > 1 then
    Grid.Cells[1, Row] := '';
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
    lblDiagInfo.Caption := Format('%s: %s -> %s', [GridName, KeyText, ValueText]);
end;

procedure TfrmEditorMain.pbRealKeyboardPaint(Sender: TObject);
var
  Painter: TKeyboardPainter;
begin
  pbRealKeyboard.Canvas.Brush.Color := clWhite;
  pbRealKeyboard.Canvas.FillRect(pbRealKeyboard.ClientRect);

  if not Assigned(FLayout) then
  begin
    pbRealKeyboard.Canvas.Font.Name := 'Segoe UI';
    pbRealKeyboard.Canvas.Font.Size := 10;
    pbRealKeyboard.Canvas.Font.Color := clGrayText;
    pbRealKeyboard.Canvas.TextOut(20, 20, 'Open or create a layout to see the keyboard view.');
    Exit;
  end;

  Painter := TKeyboardPainter.Create;
  try
    Painter.PaintKeyboard(pbRealKeyboard.Canvas, Point(20, 24), FLayout);
  finally
    Painter.Free;
  end;
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
    SaveLayoutToFile(FLayout, FCurrentFileName);
  end
  else
  begin
    // First save → ask filename
    if not SaveDialog.Execute then
      Exit;

    FCurrentFileName := SaveDialog.FileName;
    SaveLayoutToFile(FLayout, FCurrentFileName);
    UpdateWindowCaption;
  end;

  MessageBox(
    Handle,
    'Layout saved successfully.',
    'Vittix Indic Editor',
    MB_OK or MB_ICONINFORMATION
  );
end;

procedure TfrmEditorMain.btnSaveAsClick(Sender: TObject);
begin
  if not Assigned(FLayout) then Exit;
  if not SaveDialog.Execute then Exit;
  SaveUIToLayout;
  FCurrentFileName := SaveDialog.FileName;
  SaveLayoutToFile(FLayout, FCurrentFileName);
  UpdateWindowCaption;
end;

procedure TfrmEditorMain.LoadLayoutToUI;
begin
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
  FreeAndNil(FLayout);
  FLayout := LoadLayoutFromFile(FileName);
  FCurrentFileName := FileName;
  LoadLayoutToUI;
  UpdateWindowCaption;
  ComboBoxFonts.Enabled := True;
  UpdateLayoutPreview;
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
  Grid := Screen.ActiveControl as TStringGrid;
  Row := Grid.RowCount;
  Grid.RowCount := Row + 1;
  Grid.Cells[0,Row] := 'NewKey';
  Grid.Cells[1,Row] := '';
end;

procedure TfrmEditorMain.miRemoveKeyClick(Sender: TObject);
var
  Grid: TStringGrid;
  Row: Integer;
begin
  Grid := Screen.ActiveControl as TStringGrid;
  Row := Grid.Row;
  if Row > 0 then
    Grid.Rows[Row].Clear;
end;

procedure TfrmEditorMain.miCopyClick(Sender: TObject);
var
  Grid: TStringGrid;
  Row: Integer;
begin
  Grid := Screen.ActiveControl as TStringGrid;
  Row := Grid.Row;
  if Row > 0 then
    Clipboard.AsText := Grid.Cells[0,Row] + #9 + Grid.Cells[1,Row];
end;

procedure TfrmEditorMain.miPasteClick(Sender: TObject);
var
  Grid: TStringGrid;
  Row: Integer;
  Parts: TArray<string>;
begin
  Grid := Screen.ActiveControl as TStringGrid;
  Row := Grid.Row;
  if Row > 0 then
  begin
    Parts := Clipboard.AsText.Split([#9]);
    if Length(Parts) = 2 then
    begin
      Grid.Cells[0,Row] := Parts[0];
      Grid.Cells[1,Row] := Parts[1];
    end;
  end;
end;

procedure TfrmEditorMain.miValidateClick(Sender: TObject);
var
  Errors: TList<TValidationError>;
begin
  Errors := TList<TValidationError>.Create;
  try
    Validation.ValidateLayout(FLayout, Errors);
    ShowValidationErrors(Errors);
  finally
    Errors.Free;
  end;
end;

procedure TfrmEditorMain.ShowValidationErrors(const Errors: TList<TValidationError>);
var
  Msg: string;
  E: TValidationError;
begin
  if Errors.Count = 0 then
    Msg := 'No validation errors.'
  else
  begin
    Msg := 'Validation errors:' + sLineBreak;
    for E in Errors do
      Msg := Msg + '[' + E.Section + '] ' + E.Message + sLineBreak;
  end;
  pnlDiagnostics.Color := $00FFF4E0; // warm tint on error
  lblDiagInfo.Caption := Msg;
  MessageDlg(Msg, mtWarning, [mbOK], 0);
end;

procedure TfrmEditorMain.LoadDirect;
var
  Pair: TPair<string, string>;
  R: Integer;
begin
  grdDirect.ColCount := 3;
  grdDirect.RowCount := FLayout.DirectMap.Count + 1;
  grdDirect.Cells[0,0] := 'Key';
  grdDirect.Cells[1,0] := 'Glyph';
  grdDirect.Cells[2,0] := 'Preview';

  R := 1;
  for Pair in FLayout.DirectMap do
  begin
    grdDirect.Cells[0,R] := Pair.Key;
    grdDirect.Cells[1,R] := Pair.Value;
    grdDirect.Cells[2,R] := Pair.Value;
    Inc(R);
  end;

  grdDirect.ColWidths[2] := 120;

  edtSearchDirect.Text := '';
end;

procedure TfrmEditorMain.LoadPrebase;
var
  Pair: TPair<string, TKeyMapping>;
  R: Integer;
begin
  grdPrebase.ColCount := 3;
  grdPrebase.RowCount := FLayout.PrebaseMap.Count + 1;
  grdPrebase.Cells[0,0] := 'Key';
  grdPrebase.Cells[1,0] := 'Glyph';
  grdPrebase.Cells[2,0] := 'Preview';

  R := 1;
  for Pair in FLayout.PrebaseMap do
  begin
    grdPrebase.Cells[0,R] := Pair.Key;
    grdPrebase.Cells[1,R] := Pair.Value.Glyph;
    grdPrebase.Cells[2,R] := Pair.Value.Glyph;
    Inc(R);
  end;

  grdPrebase.ColWidths[2] := 120;

  edtSearchPrebase.Text := '';
end;

procedure TfrmEditorMain.LoadPostbase;
var
  Pair: TPair<string, string>;
  R: Integer;
begin
  grdPostbase.ColCount := 3;
  grdPostbase.RowCount := FLayout.PostbaseMap.Count + 1;
  grdPostbase.Cells[0,0] := 'Key';
  grdPostbase.Cells[1,0] := 'Glyph';
  grdPostbase.Cells[2,0] := 'Preview';

  R := 1;
  for Pair in FLayout.PostbaseMap do
  begin
    grdPostbase.Cells[0,R] := Pair.Key;
    grdPostbase.Cells[1,R] := Pair.Value;
    grdPostbase.Cells[2,R] := Pair.Value;
    Inc(R);
  end;

  grdPostbase.ColWidths[2] := 120;

  edtSearchPostbase.Text := '';
end;

procedure TfrmEditorMain.LoadSequences;
var
  Pair: TPair<string, string>;
  R: Integer;
begin
  grdSequences.ColCount := 3;
  grdSequences.RowCount := FLayout.Sequences.Count + 1;
  grdSequences.Cells[0,0] := 'Keys';
  grdSequences.Cells[1,0] := 'Output';
  grdSequences.Cells[2,0] := 'Preview';

  R := 1;
  for Pair in FLayout.Sequences do
  begin
    grdSequences.Cells[0,R] := Pair.Key;
    grdSequences.Cells[1,R] := Pair.Value;
    grdSequences.Cells[2,R] := Pair.Value;
    Inc(R);
  end;

  grdSequences.ColWidths[2] := 120;

  edtSearchSequences.Text := '';
end;

procedure TfrmEditorMain.LoadModifiers;
var
  Pair: TPair<string, TKeyMapping>;
  R: Integer;
begin
  grdModifiers.ColCount := 4;
  grdModifiers.RowCount := FLayout.Modifiers.Count + 1;
  grdModifiers.Cells[0,0] := 'Name';
  grdModifiers.Cells[1,0] := 'Key';
  grdModifiers.Cells[2,0] := 'Glyph';
  grdModifiers.Cells[3,0] := 'Preview';

  R := 1;
  for Pair in FLayout.Modifiers do
  begin
    grdModifiers.Cells[0,R] := Pair.Key;
    grdModifiers.Cells[1,R] := Pair.Value.Key;
    grdModifiers.Cells[2,R] := Pair.Value.Glyph;
    grdModifiers.Cells[3,R] := Pair.Value.Glyph;
    Inc(R);
  end;

  edtSearchModifiers.Text := '';

  grdModifiers.ColWidths[3] := 120;
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
begin
  Grid := GetSelectedGrid;
  if Grid = nil then Exit;
  Row := Grid.Row;
  if Row < Grid.FixedRows then Exit;
  PushUndo;
  Grid.Cells[0, Row] := edtInspectorKey.Text;
  if Grid.ColCount > 1 then
    Grid.Cells[1, Row] := edtInspectorValue.Text;
  Grid.Invalidate;
  SaveUIToLayout;
  UpdateLayoutPreview;
end;

procedure TfrmEditorMain.btnInspectorClearClick(Sender: TObject);
var
  Grid: TStringGrid;
  Row: Integer;
begin
  Grid := GetSelectedGrid;
  if Grid = nil then Exit;
  Row := Grid.Row;
  if Row < Grid.FixedRows then Exit;
  PushUndo;
  Grid.Rows[Row].Clear;
  Grid.Invalidate;
  SaveUIToLayout;
  UpdateLayoutPreview;
end;

procedure TfrmEditorMain.btnInspectorAddClick(Sender: TObject);
var
  Grid: TStringGrid;
  ParentName: string;
begin
  Grid := GetSelectedGrid;
  if (Grid = nil) and (Sender is TControl) then
  begin
    ParentName := LowerCase((Sender as TControl).Parent.Name);
    if Pos('direct', ParentName) > 0 then Grid := grdDirect
    else if Pos('prebase', ParentName) > 0 then Grid := grdPrebase
    else if Pos('postbase', ParentName) > 0 then Grid := grdPostbase
    else if Pos('sequences', ParentName) > 0 then Grid := grdSequences
    else if Pos('modifiers', ParentName) > 0 then Grid := grdModifiers;
  end;
  if Grid <> nil then
    AddRowToGrid(Grid);
end;

procedure TfrmEditorMain.GridDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
  Grid: TStringGrid;
  Text, KeyText, ValueText, Badge: string;
begin
  Grid := Sender as TStringGrid;

  // -------------------------------
  // HEADER ROW (titles)
  // -------------------------------
  if ARow < Grid.FixedRows then
  begin
    Grid.Canvas.Brush.Color := clBtnFace;
    Grid.Canvas.FillRect(Rect);

    Grid.Canvas.Font.Name := 'Segoe UI';
    Grid.Canvas.Font.Size := 9;
    Grid.Canvas.Font.Style := [fsBold];
    Grid.Canvas.Font.Color := clWindowText;

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
    Grid.Canvas.Brush.Color := $00FAFAFA
  else
  Grid.Canvas.Brush.Color := clWindow;
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

  // 🔵 PREVIEW COLUMN (rightmost)
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
  Grid.Canvas.Font.Color := clWindowText;

  // Selection highlight
  if gdSelected in State then
  begin
    Grid.Canvas.Brush.Color := clHighlight;
    Grid.Canvas.Font.Color := clHighlightText;
    Grid.Canvas.FillRect(Rect);
  end;

  Badge := '';
  if ARow >= Grid.FixedRows then
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
    Grid.Canvas.Font.Color := clMaroon;
    DrawText(
      Grid.Canvas.Handle,
      PChar(Badge),
      Length(Badge),
      Rect,
      DT_SINGLELINE or DT_VCENTER or DT_RIGHT
    );
    Grid.Canvas.Font.Color := clWindowText;
  end;

  DrawText(
    Grid.Canvas.Handle,
    PChar(Text),
    Length(Text),
    Rect,
    DT_SINGLELINE or DT_VCENTER or DT_LEFT or DT_END_ELLIPSIS
  );
end;

procedure TfrmEditorMain.SaveUIToLayout;
begin
  PushUndo;
  FLayout.Name := edtLayoutName.Text;
  FLayout.FontFamily := ComboBoxFonts.Text;

  // Save hotkey settings to layout properties
  FLayout.Properties.AddOrSetValue('HotkeySwitch', edtHotkeySwitch.Text);
  FLayout.Properties.AddOrSetValue('HotkeyAction', edtHotkeyAction.Text);
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

procedure TfrmEditorMain.pbRealKeyboardMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Painter: TKeyboardPainter;
  Hit: TKeyboardKeyHit;
  Grid: TStringGrid;
  Value: string;
  Row: Integer;
begin
  if FLayout = nil then Exit;
  Painter := TKeyboardPainter.Create;
  try
    Painter.PaintKeyboard(pbRealKeyboard.Canvas, Point(20, 24), FLayout);
    Hit := Painter.HitTest(Point(X, Y));
  finally
    Painter.Free;
  end;
  if Hit.KeyName = '' then Exit;
  if Button = mbRight then
  begin
    if not GetMappingForKey(Hit.KeyName, Value) then
      Value := '';
    edtInspectorKey.Text := Hit.KeyName;
    edtInspectorValue.Text := Value;
    if Value = '' then
      btnInspectorAddClick(Sender)
    else
      ShowMessage(Hit.KeyName + ' = ' + Value);
    Exit;
  end;
  Grid := grdDirect;
  Row := FindRowByKey(Grid, Hit.KeyName);
  if Row > 0 then
  begin
    SelectGridRow(Grid, Row);
    edtInspectorKey.Text := Hit.KeyName;
    if GetMappingForKey(Hit.KeyName, Value) then
      edtInspectorValue.Text := Value;
    Grid.EditorMode := True;
  end;
end;

procedure TfrmEditorMain.pbRealKeyboardMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  Painter: TKeyboardPainter;
  Hit: TKeyboardKeyHit;
  Value: string;
begin
  if FLayout = nil then Exit;
  Painter := TKeyboardPainter.Create;
  try
    Painter.PaintKeyboard(pbRealKeyboard.Canvas, Point(20, 24), FLayout);
    Hit := Painter.HitTest(Point(X, Y));
  finally
    Painter.Free;
  end;
  if Hit.KeyName <> '' then
  begin
    if GetMappingForKey(Hit.KeyName, Value) then
      lblDiagInfo.Caption := Hit.KeyName + ' -> ' + Value
    else
      lblDiagInfo.Caption := Hit.KeyName + ' (unmapped)';
  end;
end;

end.
