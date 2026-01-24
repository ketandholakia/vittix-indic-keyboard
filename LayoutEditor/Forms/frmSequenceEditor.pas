unit frmSequenceEditor;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Grids,
  Vcl.Dialogs,
  LayoutModel;

type
  TfrmSequenceEditor = class(TForm)
    pnlTop: TPanel;
    lblInfo: TLabel;
    btnOK: TButton;
    btnCancel: TButton;

    grdSequences: TStringGrid;

    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FLayout: TKeyboardLayout;
    procedure LoadSequences;
    procedure SaveSequences;
  public
    class function Execute(ALayout: TKeyboardLayout): Boolean;
  end;

implementation

{$R *.dfm}

{ --------------------------------------------------
  Static execute helper
-------------------------------------------------- }
class function TfrmSequenceEditor.Execute(ALayout: TKeyboardLayout): Boolean;
var
  Frm: TfrmSequenceEditor;
begin
  Result := False;
  if ALayout = nil then Exit;

  Frm := TfrmSequenceEditor.Create(nil);
  try
    Frm.FLayout := ALayout;
    Frm.LoadSequences;
    Result := (Frm.ShowModal = mrOk);
  finally
    Frm.Free;
  end;
end;

{ --------------------------------------------------
  Form lifecycle
-------------------------------------------------- }
procedure TfrmSequenceEditor.FormCreate(Sender: TObject);
begin
  Caption := 'Sequence / Conjunct Editor';
  lblInfo.Caption := 'Define multi-key sequences (example: k\s → ક્ષ)';
end;

{ --------------------------------------------------
  Load sequences into grid
-------------------------------------------------- }
procedure TfrmSequenceEditor.LoadSequences;
var
  Pair: TPair<string, string>;
  R: Integer;
begin
  grdSequences.ColCount := 2;
  grdSequences.FixedRows := 1;
  grdSequences.Cells[0,0] := 'Keys';
  grdSequences.Cells[1,0] := 'Output';

  grdSequences.RowCount := FLayout.Sequences.Count + 2;

  R := 1;
  for Pair in FLayout.Sequences do
  begin
    grdSequences.Cells[0,R] := Pair.Key;
    grdSequences.Cells[1,R] := Pair.Value;
    Inc(R);
  end;
end;

{ --------------------------------------------------
  Save grid back to layout
-------------------------------------------------- }
procedure TfrmSequenceEditor.SaveSequences;
var
  R: Integer;
  KeySeq, OutGlyph: string;
begin
  FLayout.Sequences.Clear;

  for R := 1 to grdSequences.RowCount - 1 do
  begin
    KeySeq := Trim(grdSequences.Cells[0,R]);
    OutGlyph := Trim(grdSequences.Cells[1,R]);

    if (KeySeq <> '') and (OutGlyph <> '') then
      FLayout.Sequences.Add(KeySeq, OutGlyph);
  end;
end;

{ --------------------------------------------------
  Buttons
-------------------------------------------------- }
procedure TfrmSequenceEditor.btnOKClick(Sender: TObject);
begin
  SaveSequences;
  ModalResult := mrOk;
end;

procedure TfrmSequenceEditor.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
