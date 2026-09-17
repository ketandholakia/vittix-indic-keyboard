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
  LayoutModel,
  LayoutResolver,
  VittixKeyboardView;

type
  TfrmOnScreenKeyboard = class(TForm)
    pnlHeader: TPanel;
    lblLayoutName: TLabel;
    pnlKeyboard: TScrollBox;
    pnlFooter: TPanel;
    lblKeyInfo: TLabel;
    vkvKeyboard: TVittixKeyboardView;
    procedure FormCreate(Sender: TObject);
    procedure vkvKeyboardKeySelect(Sender: TObject; const KeyName, CurrentGlyph: string);
  private
    FLayout: TKeyboardLayout;
  public
    procedure LoadLayout(ALayout: TKeyboardLayout);
  end;

implementation

{$R *.dfm}

procedure TfrmOnScreenKeyboard.FormCreate(Sender: TObject);
begin
  lblLayoutName.Caption := 'No layout loaded';
  lblKeyInfo.Caption := '';
end;

procedure TfrmOnScreenKeyboard.LoadLayout(ALayout: TKeyboardLayout);
begin
  FLayout := ALayout;

  // The shared keyboard view renders the layout itself, including glyphs in the
  // layout font and DPI-correct key metrics. A nil layout means nothing active.
  vkvKeyboard.Layout := ALayout;
  vkvKeyboard.SelectedKey := '';
  lblKeyInfo.Caption := '';

  if ALayout = nil then
  begin
    lblLayoutName.Caption := 'No layout loaded';
    Exit;
  end;

  lblLayoutName.Caption := ALayout.Name;
end;

procedure TfrmOnScreenKeyboard.vkvKeyboardKeySelect(Sender: TObject;
  const KeyName, CurrentGlyph: string);
var
  Resolved: TResolvedGlyph;
begin
  if FLayout = nil then
  begin
    lblKeyInfo.Caption := '';
    Exit;
  end;

  Resolved := TLayoutResolver.Resolve(FLayout, KeyName);
  if not Resolved.Found then
    lblKeyInfo.Caption := Format('Key: %s    no mapping', [KeyName])
  else
    lblKeyInfo.Caption := Format('Key: %s    glyph: %s    from %s',
      [KeyName, CurrentGlyph, Resolved.SourceLabel]);
end;

end.