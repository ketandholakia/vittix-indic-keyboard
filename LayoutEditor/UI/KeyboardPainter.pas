unit KeyboardPainter;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.ExtCtrls,
  LayoutModel;

type
  { -------------------------------------------------
    Keyboard painter
    ------------------------------------------------- }
  TKeyboardPainter = class
  private
    FLayout: TKeyboardLayout;
    FCanvas: TCanvas;
    FKeySize: TSize;
    FFont: TFont;

    procedure DrawKey(const Key: string; const R: TRect);
    function GetGlyphForKey(const Key: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure PaintKeyboard(
      ACanvas: TCanvas;
      const Origin: TPoint;
      ALayout: TKeyboardLayout
    );
  end;

implementation

const
  // Physical keyboard rows (Remington / QWERTY based)
  ROW_NUMBERS = '1234567890';
  ROW_1 = 'QWERTYUIOP';
  ROW_2 = 'ASDFGHJKL';
  ROW_3 = 'ZXCVBNM';

{ -------------------------------------------------
  Constructor / Destructor
------------------------------------------------- }

constructor TKeyboardPainter.Create;
begin
  inherited Create;

  FKeySize.cx := 42;
  FKeySize.cy := 42;

  FFont := TFont.Create;
  FFont.Name := 'Segoe UI';
  FFont.Size := 9;
end;

destructor TKeyboardPainter.Destroy;
begin
  FFont.Free;
  inherited;
end;

{ -------------------------------------------------
  Public paint entry
------------------------------------------------- }

procedure TKeyboardPainter.PaintKeyboard(
  ACanvas: TCanvas;
  const Origin: TPoint;
  ALayout: TKeyboardLayout
);
var
  TopPos: Integer;

  procedure DrawRow(const Keys: string; OffsetX: Integer);
  var
    I, LeftPos: Integer;
    R: TRect;
  begin
    LeftPos := Origin.X + OffsetX;

    for I := 1 to Length(Keys) do
    begin
      R := Rect(
        LeftPos,
        TopPos,
        LeftPos + FKeySize.cx,
        TopPos + FKeySize.cy
      );

      DrawKey(Keys[I], R);
      Inc(LeftPos, FKeySize.cx + 4);
    end;
  end;

begin
  if ALayout = nil then Exit;

  FCanvas := ACanvas;
  FLayout := ALayout;

  FCanvas.Font.Assign(FFont);
  FCanvas.Brush.Style := bsSolid;

  TopPos := Origin.Y;

  DrawRow(ROW_NUMBERS, 0);
  Inc(TopPos, FKeySize.cy + 6);

  DrawRow(ROW_1, 20);
  Inc(TopPos, FKeySize.cy + 6);

  DrawRow(ROW_2, 30);
  Inc(TopPos, FKeySize.cy + 6);

  DrawRow(ROW_3, 50);
end;

{ -------------------------------------------------
  Draw individual key
------------------------------------------------- }

procedure TKeyboardPainter.DrawKey(const Key: string; const R: TRect);
var
  Glyph: string;
begin
  Glyph := GetGlyphForKey(Key);

  // Key background
  FCanvas.Brush.Color := $F0F0F0;
  FCanvas.Pen.Color := clGray;
  FCanvas.Rectangle(R);

  // Physical key (top-left)
  FCanvas.Font.Style := [];
  FCanvas.TextOut(R.Left + 4, R.Top + 4, Key);

  // Glyph output (center)
  if Glyph <> '' then
  begin
    FCanvas.Font.Style := [fsBold];
    FCanvas.TextOut(
      R.Left + (R.Width div 2) - (FCanvas.TextWidth(Glyph) div 2),
      R.Top + (R.Height div 2) - 8,
      Glyph
    );
  end;
end;

{ -------------------------------------------------
  Lookup glyph from layout
------------------------------------------------- }

function TKeyboardPainter.GetGlyphForKey(const Key: string): string;
var
  Matra: TPrebaseMatra;
begin
  Result := '';

  if FLayout.DirectMap.ContainsKey(Key) then
    Exit(FLayout.DirectMap[Key]);

  if FLayout.PrebaseMap.TryGetValue(Key, Matra) then
    Exit(Matra.Glyph);

  if FLayout.PostbaseMap.ContainsKey(Key) then
    Exit(FLayout.PostbaseMap[Key]);

  if FLayout.Modifiers.ContainsKey('halant') then
    if Key = FLayout.Modifiers['halant'].Key then
      Exit(FLayout.Modifiers['halant'].Glyph);

  if FLayout.Modifiers.ContainsKey('reph') then
    if Key = FLayout.Modifiers['reph'].Key then
      Exit(FLayout.Modifiers['reph'].Glyph);
end;

end.
