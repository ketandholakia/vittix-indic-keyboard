unit frmOnScreenKeyboard;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Buttons,
  LayoutModel,
  LayoutResolver,
  ShreeLipi.Engine,
  OSKInput,
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
    // QW2: the OSK must never take focus, or the glyph the engine sends via
    // SendInput would land in the OSK window instead of the user's document.
    procedure WMMouseActivate(var Msg: TWMMouseActivate); message WM_MOUSEACTIVATE;
  public
    procedure LoadLayout(ALayout: TKeyboardLayout);
  end;

implementation

{$R *.dfm}

procedure TfrmOnScreenKeyboard.WMMouseActivate(var Msg: TWMMouseActivate);
begin
  Msg.Result := MA_NOACTIVATE;
end;

procedure TfrmOnScreenKeyboard.FormCreate(Sender: TObject);
begin
  // QW2: clicks type through the engine, so the keyboard must not take
  // focus: the view skips SetFocus and never activates, at form and control
  // level. The engine's own guards make clicks no-ops when typing is off.
  vkvKeyboard.FocusOnClick := False;
  lblLayoutName.Caption := 'No layout loaded';
  lblKeyInfo.Caption := '';
end;

procedure TfrmOnScreenKeyboard.LoadLayout(ALayout: TKeyboardLayout);
begin
  FLayout := ALayout;

  // The shared keyboard view renders the layout itself, including glyphs in the
  // layout font and DPI-correct key metrics. A nil layout means nothing active.
  vkvKeyboard.GlyphFontName := '';
  if ALayout <> nil then
    vkvKeyboard.GlyphFontName := ALayout.FontFamily;
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
  EngineKey: string;
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

  // QW2: type through the engine so the click produces exactly what the
  // physical key would (cluster context, prebase/postbase, reph all apply).
  // The engine passes through when disabled or layout-less; '' means the
  // name is not a typeable single character.
  EngineKey := OSKKeyNameToEngineKey(KeyName, vkvKeyboard.ShiftState);
  if EngineKey <> '' then
    ProcessKeyChar(EngineKey);
end;

end.