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
  Vcl.Grids,
  Vcl.Graphics,

  System.Generics.Collections, // ✅ REQUIRED for TPair

  LayoutModel,
  LayoutLoader,
  LayoutJsonIO;

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
    Label1: TLabel;
    btnOpen: TButton;
    btnSave: TButton;
    PageControl: TPageControl;
    tabDirect: TTabSheet;
    Panel1: TPanel;
    grdDirect: TStringGrid;
    tabPrebase: TTabSheet;
    grdPrebase: TStringGrid;
    tabPostbase: TTabSheet;
    grdPostbase: TStringGrid;
    tabSequences: TTabSheet;
    grdSequences: TStringGrid;
    tabModifiers: TTabSheet;
    grdModifiers: TStringGrid;
    btnSaveAs: TButton;
    lblEmptyState: TLabel;

    procedure FormCreate(Sender: TObject);
    procedure btnOpenClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnSaveAsClick(Sender: TObject);
    procedure GridSelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure GridMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ComboBox1Change(Sender: TObject);
  private
    FLayout: TKeyboardLayout;
    FCurrentFileName: string;

    procedure GridDrawCell(
      Sender: TObject;
      ACol, ARow: Integer;
      Rect: TRect;
      State: TGridDrawState
    );
    procedure LoadInstalledFonts;
    procedure ClearGrids;
    procedure LoadLayoutToUI;
    procedure LoadDirect;
    procedure LoadPrebase;
    procedure LoadPostbase;
    procedure LoadSequences;
    procedure LoadModifiers;
    procedure SaveUIToLayout;
    procedure ClearLayout;
  public
  end;

var
  gFrmEditorMain: TfrmEditorMain; // ✅ FIXED (no collision)

implementation

{$R *.dfm}

procedure EnableGridEditing(Grid: TStringGrid);
begin
  Grid.Options := Grid.Options + [goEditing, goAlwaysShowEditor, goTabs];
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

  ClearGrids;

  LoadInstalledFonts;

  ComboBoxFonts.Enabled := False;
  ComboBoxFonts.ItemIndex := -1;

  EnableGridEditing(grdDirect);
  EnableGridEditing(grdPrebase);
  EnableGridEditing(grdPostbase);
  EnableGridEditing(grdSequences);
  EnableGridEditing(grdModifiers);

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
end;

procedure TfrmEditorMain.ClearGrids;
begin
  grdDirect.RowCount := 2;
  grdPrebase.RowCount := 2;
  grdPostbase.RowCount := 2;
  grdSequences.RowCount := 2;
  grdModifiers.RowCount := 2;
end;

procedure TfrmEditorMain.ClearLayout;
begin
  FCurrentFileName := '';

  FreeAndNil(FLayout);

  edtLayoutName.Clear;
  ClearGrids;

  ComboBoxFonts.ItemIndex := -1;
  ComboBoxFonts.Enabled := False;
end;

procedure TfrmEditorMain.btnOpenClick(Sender: TObject);
begin
  if not OpenDialog.Execute then
    Exit;

  FreeAndNil(FLayout);
  FLayout := LoadLayoutFromFile(OpenDialog.FileName);

  FCurrentFileName := OpenDialog.FileName;

  LoadLayoutToUI;

  ComboBoxFonts.Enabled := True;
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

  LoadDirect;
  LoadPrebase;
  LoadPostbase;
  LoadSequences;
  LoadModifiers;
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
end;

procedure TfrmEditorMain.LoadPrebase;
var
  Pair: TPair<string, TPrebaseMatra>;
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
end;

procedure TfrmEditorMain.LoadModifiers;
var
  Pair: TPair<string, TModifierRule>;
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

  grdModifiers.ColWidths[3] := 120;
end;

procedure TfrmEditorMain.GridDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
  Grid: TStringGrid;
  Text: string;
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
  Grid.Canvas.Brush.Color := clWindow;
  Grid.Canvas.FillRect(Rect);

  Text := Grid.Cells[ACol, ARow];

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
  FLayout.Name := edtLayoutName.Text;
  FLayout.FontFamily := ComboBoxFonts.Text;
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
  end;
end;

end.
