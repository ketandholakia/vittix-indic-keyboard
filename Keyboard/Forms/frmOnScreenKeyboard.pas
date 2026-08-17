unit frmOnScreenKeyboard;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Buttons,
  LayoutModel;

type
  TfrmOnScreenKeyboard = class(TForm)
    pnlHeader: TPanel;
    lblLayoutName: TLabel;
    pnlKeyboard: TScrollBox;
    pnlFooter: TPanel;
    lblKeyInfo: TLabel;
    procedure FormCreate(Sender: TObject);
  private
    FLayout: TKeyboardLayout;
    procedure BuildKeyboard;
    procedure BuildRow(const Keys: string; TopPos: Integer);
    procedure KeyButtonClick(Sender: TObject);
    function GetGlyphForKey(const AKey: string): string;
  public
    procedure LoadLayout(ALayout: TKeyboardLayout);
  end;

implementation

{$R *.dfm}

const
  ROW_NUMBERS = '1234567890';
  ROW_1 = 'QWERTYUIOP';
  ROW_2 = 'ASDFGHJKL';
  ROW_3 = 'ZXCVBNM';

procedure TfrmOnScreenKeyboard.FormCreate(Sender: TObject);
begin
  lblLayoutName.Caption := 'No layout loaded';
  lblKeyInfo.Caption := '';
end;

procedure TfrmOnScreenKeyboard.LoadLayout(ALayout: TKeyboardLayout);
begin
  FLayout := ALayout;
  lblLayoutName.Caption := ALayout.Name;
  BuildKeyboard;
end;

procedure TfrmOnScreenKeyboard.BuildKeyboard;
begin
  pnlKeyboard.DestroyComponents;

  BuildRow(ROW_NUMBERS, 10);
  BuildRow(ROW_1, 60);
  BuildRow(ROW_2, 110);
  BuildRow(ROW_3, 160);
end;

procedure TfrmOnScreenKeyboard.BuildRow(const Keys: string; TopPos: Integer);
var
  I, LeftPos: Integer;
  Btn: TSpeedButton;
begin
  LeftPos := 10;

  for I := 1 to Length(Keys) do
  begin
    Btn := TSpeedButton.Create(Self);
    Btn.Parent := pnlKeyboard;
    Btn.SetBounds(LeftPos, TopPos, 42, 42);
    Btn.Caption := Keys[I];
    Btn.Tag := Ord(Keys[I]);
    Btn.OnClick := KeyButtonClick;
    Btn.Flat := True;

    LeftPos := LeftPos + 44;
  end;
end;

procedure TfrmOnScreenKeyboard.KeyButtonClick(Sender: TObject);
var
  Key, Glyph: string;
begin
  Key := Char(TSpeedButton(Sender).Tag);
  Glyph := GetGlyphForKey(Key);

  if Glyph = '' then
    lblKeyInfo.Caption := Format('Key: %s → (no mapping)', [Key])
  else
    lblKeyInfo.Caption := Format('Key: %s  →  Glyph: %s', [Key, Glyph]);
end;

function TfrmOnScreenKeyboard.GetGlyphForKey(const AKey: string): string;
var
  Matra: TKeyMapping;

begin
  Result := '';

  if FLayout = nil then
    Exit;

  if FLayout.DirectMap.ContainsKey(AKey) then
    Exit(FLayout.DirectMap[AKey]);

  if FLayout.PrebaseMap.TryGetValue(AKey, Matra) then
    Exit(Matra.Glyph);

  if FLayout.PostbaseMap.ContainsKey(AKey) then
    Exit(FLayout.PostbaseMap[AKey]);

  if FLayout.Modifiers.ContainsKey('halant') then
    if AKey = FLayout.Modifiers['halant'].Key then
      Exit(FLayout.Modifiers['halant'].Glyph);

  if FLayout.Modifiers.ContainsKey('reph') then
    if AKey = FLayout.Modifiers['reph'].Key then
      Exit(FLayout.Modifiers['reph'].Glyph);
end;

end.
