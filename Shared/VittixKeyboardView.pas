unit VittixKeyboardView;

{-------------------------------------------------------------------------
  TVittixKeyboardView

  A reusable VCL control that draws a physical keyboard and lets the user
  click (or arrow-key to) a key to select it, see its current mapping, and
  assign a new one.

  This revision:
    * FHits is pre-sized instead of concatenated (O(n^2) -> O(n) per Paint).
    * CurrentMapping now reports the *effective* glyph (same lookup Paint
      uses), so OnKeySelect can no longer disagree with what's on screen
      for keys mapped through Prebase/Postbase/Modifiers.
    * Keyboard navigation: arrows move the selection, Home/End jump to the
      row ends, Enter/Space fire OnKeySelect, Esc clears the selection.
    * Modifier lookup is generic (iterates FLayout.Modifiers) instead of
      hardcoding 'halant' / 'reph'.
    * Metrics scale via ChangeScale, so the control survives a DPI change.
    * DrawKey receives the glyph from Paint instead of redoing the lookup.
    * SetLayout routes through SetSelectedKey so the setter invariant holds.

  Special keys (Backspace / Enter / Shift / Space) are still drawn but not
  wired to DirectMap selection/assignment -- clicking or pressing Enter on
  one is a no-op. They *do* receive the visual selection highlight so arrow
  navigation doesn't skip over them.

  Note on ChangeScale: this overrides the two-argument TControl.ChangeScale
  (M, D: Integer), which is what fires on VCL form-level scaling. On newer
  Delphi versions targeting per-monitor V2 DPI awareness, that overload may
  be marked deprecated in favor of ChangeScale(M, D: Integer; isDpiChange:
  Boolean) -- it still fires and works, but if you want to silence the
  deprecation hint, override the three-argument version instead and call
  through to this logic.
-------------------------------------------------------------------------}

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.Themes,
  System.Generics.Collections,
  LayoutModel,
  LayoutResolver;

type
  TKeyboardKeyHit = record
    KeyName: string;
    KeyRect: TRect;
    Glyph: string;
    IsSpecial: Boolean;
    function IsValid: Boolean;
  end;

  TKeyDef = record
    KeyName: string;
    WidthUnits: Single;
    IsSpecial: Boolean;
  end;

  TKeyRowDef = record
    Keys: TArray<TKeyDef>;
    IndentUnits: Single;
  end;

  TVittixKeySelectEvent = procedure(Sender: TObject;
    const KeyName, CurrentGlyph: string) of object;
  TVittixKeyAssignEvent = procedure(Sender: TObject;
    const KeyName, NewGlyph: string) of object;

  TVittixKeyboardView = class(TCustomControl)
  private
    FLayout: TKeyboardLayout;
    FSelectedKey: string;
    FShiftState: Boolean;
    FHighContrastMode: Boolean;
    FScaleToFit: Boolean;
    
    FRefKeySize: TSize;
    FRefKeySpacing: Integer;
    FRefOriginX, FRefOriginY, FRefRowGapExtra: Integer;
    
    FKeySize: TSize;
    FKeySpacing: Integer;
    FOriginX, FOriginY, FRowGapExtra: Integer;
    FMappedColor: TColor;
    FUnmappedColor: TColor;
    FSelectedColor: TColor;
    FHits: TArray<TKeyboardKeyHit>;
    FRows: TArray<TKeyRowDef>;
    FOnKeySelect: TVittixKeySelectEvent;
    FOnKeyAssign: TVittixKeyAssignEvent;

    procedure SetLayout(const Value: TKeyboardLayout);
    procedure SetSelectedKey(const Value: string);
    procedure SetShiftState(const Value: Boolean);
    procedure SetHighContrastMode(const Value: Boolean);
    procedure SetScaleToFit(const Value: Boolean);
    procedure SetKeySpacing(const Value: Integer);
    procedure SetMappedColor(const Value: TColor);
    procedure SetUnmappedColor(const Value: TColor);
    procedure SetSelectedColor(const Value: TColor);

    function  GetGlyphForKey(const Key: string): string;
    function  KeyPixelWidth(const KeyDef: TKeyDef): Integer;
    procedure DrawKey(const KeyDef: TKeyDef; const R: TRect;
                      const Glyph: string; IsSelected: Boolean);
    function  HitTestInternal(const P: TPoint;
                              out Hit: TKeyboardKeyHit): Boolean;
    procedure ApplyPreferredExtent;
    procedure RecalcFitScale;
    procedure UseReferenceMetrics;
    function  IsSpecialKey(const KeyName: string): Boolean;
    procedure MoveSelection(const DCol, DRow: Integer);
    procedure FireSelectForSelected;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
                        X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure ChangeScale(M, D: Integer); override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;

    // Returns the key (if any) under P, in client coordinates.
    function  KeyAtPoint(const P: TPoint): TKeyboardKeyHit; overload;
    function  KeyAtPoint(const P: TPoint;
                         out Hit: TKeyboardKeyHit): Boolean; overload;

    // Effective glyph for KeyName (DirectMap > Prebase > Postbase > Modifiers).
    // Returns False and an empty Glyph if the key has no mapping at all.
    function  CurrentMapping(const KeyName: string;
                             out Glyph: string): Boolean;

    // Writes (or overwrites) the Direct-map entry for KeyName and repaints.
    // Fires OnKeyAssign. Passing a whitespace-only Glyph clears the mapping.
    procedure AssignKey(const KeyName, Glyph: string);

    // Removes the Direct-map entry for KeyName, if any, and repaints.
    procedure ClearKey(const KeyName: string);

    // Re-applies the built-in row table and re-sizes to fit. Call this if
    // you ever want to reset after mutating FRows from a descendant.
    procedure RebuildLayout;

    property Layout: TKeyboardLayout read FLayout write SetLayout;
    property SelectedKey: string read FSelectedKey write SetSelectedKey;
    property ShiftState: Boolean read FShiftState write SetShiftState;
  published
    property ScaleToFit: Boolean read FScaleToFit write SetScaleToFit default False;
    property HighContrastMode: Boolean read FHighContrastMode
      write SetHighContrastMode default False;
    property KeySpacing: Integer read FKeySpacing
      write SetKeySpacing default 4;
    property MappedColor: TColor read FMappedColor
      write SetMappedColor default $E4F6E0;
    property UnmappedColor: TColor read FUnmappedColor
      write SetUnmappedColor default $F8F8F8;
    property SelectedColor: TColor read FSelectedColor
      write SetSelectedColor default clHighlight;

    property OnKeySelect: TVittixKeySelectEvent
      read FOnKeySelect write FOnKeySelect;
    property OnKeyAssign: TVittixKeyAssignEvent
      read FOnKeyAssign write FOnKeyAssign;

    property Align;
    property Anchors;
    property Color default clWhite;
    property Constraints;
    property Font;
    property ParentColor default False;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop default True;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
  end;

implementation

const
  ROW_NUMBERS = '1234567890';
  ROW_NUMBERS_SHIFT = '!@#$%^&*()';
  ROW_1 = 'QWERTYUIOP';
  ROW_1_SHIFT = 'QWERTYUIOP';
  ROW_2 = 'ASDFGHJKL';
  ROW_2_SHIFT = 'ASDFGHJKL';
  ROW_3 = 'ZXCVBNM';
  ROW_3_SHIFT = 'ZXCVBNM';

  // All metrics are expressed at 96 DPI and scaled by ChangeScale.
  BASE_ORIGIN        = 20;
  BASE_ROW_GAP_EXTRA = 2;
  BASE_KEY_SIZE      = 42;
  BASE_KEY_SPACING   = 4;

{ -------------------------------------------------
  Row-table construction (static layout description)
------------------------------------------------- }

function MakeKeys(const Chars: string): TArray<TKeyDef>;
var
  I: Integer;
begin
  SetLength(Result, Length(Chars));
  for I := 1 to Length(Chars) do
  begin
    Result[I - 1].KeyName    := Chars[I];
    Result[I - 1].WidthUnits := 1.0;
    Result[I - 1].IsSpecial  := False;
  end;
end;

function SpecialKey(const AName: string; AWidthUnits: Single): TKeyDef;
begin
  Result.KeyName    := AName;
  Result.WidthUnits := AWidthUnits;
  Result.IsSpecial  := True;
end;

function NormalKey(const AName: string; AWidthUnits: Single): TKeyDef;
begin
  Result.KeyName    := AName;
  Result.WidthUnits := AWidthUnits;
  Result.IsSpecial  := False;
end;

function BuildKeyboardRows(AShiftState: Boolean): TArray<TKeyRowDef>;
begin
  SetLength(Result, 5);

  if AShiftState then
  begin
    // Number row + Backspace. No indent -- reference row.
    Result[0].IndentUnits := 0;
    Result[0].Keys := MakeKeys(ROW_NUMBERS_SHIFT) + [SpecialKey('Backspace', 2.0)];

    // Tab + QWERTY row.
    Result[1].IndentUnits := 0;
    Result[1].Keys := [SpecialKey('Tab', 1.5)] + MakeKeys(ROW_1_SHIFT) + [NormalKey('|', 1.5)];

    // Caps + ASDF row + Enter.
    Result[2].IndentUnits := 0;
    Result[2].Keys := [SpecialKey('Caps Lock', 1.75)] + MakeKeys(ROW_2_SHIFT) + [SpecialKey('Return', 2.25)];

    // Shift + ZXCV row + Shift.
    Result[3].IndentUnits := 0;
    Result[3].Keys := [SpecialKey('Shift', 2.25)] + MakeKeys(ROW_3_SHIFT) + [SpecialKey('Shift', 2.75)];
  end
  else
  begin
    // Number row + Backspace. No indent -- reference row.
    Result[0].IndentUnits := 0;
    Result[0].Keys := MakeKeys(ROW_NUMBERS) + [SpecialKey('Backspace', 2.0)];

    // Tab + QWERTY row.
    Result[1].IndentUnits := 0;
    Result[1].Keys := [SpecialKey('Tab', 1.5)] + MakeKeys(ROW_1) + [NormalKey('\', 1.5)];

    // Caps + ASDF row + Enter.
    Result[2].IndentUnits := 0;
    Result[2].Keys := [SpecialKey('Caps Lock', 1.75)] + MakeKeys(ROW_2) + [SpecialKey('Return', 2.25)];

    // Shift + ZXCV row + Shift.
    Result[3].IndentUnits := 0;
    Result[3].Keys := [SpecialKey('Shift', 2.25)] + MakeKeys(ROW_3) + [SpecialKey('Shift', 2.75)];
  end;

  // Space bar row.
  Result[4].IndentUnits := 0;
  Result[4].Keys := [
    SpecialKey('Control', 1.25),
    SpecialKey('Win', 1.25),
    SpecialKey('Alt', 1.25),
    SpecialKey('Space', 6.25),
    SpecialKey('Alt', 1.25),
    SpecialKey('Win', 1.25),
    SpecialKey('Menu', 1.25),
    SpecialKey('Control', 1.25)
  ];
end;

{ TKeyboardKeyHit }

function TKeyboardKeyHit.IsValid: Boolean;
begin
  Result := KeyName <> '';
end;

{ -------------------------------------------------
  Construction / DPI
------------------------------------------------- }

constructor TVittixKeyboardView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  ControlStyle   := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  TabStop        := True;
  Color          := clWhite;
  ParentColor    := False;

  FRefOriginX     := BASE_ORIGIN;
  FRefOriginY     := BASE_ORIGIN;
  FRefRowGapExtra := BASE_ROW_GAP_EXTRA;
  FRefKeySize.cx  := BASE_KEY_SIZE;
  FRefKeySize.cy  := BASE_KEY_SIZE;
  FRefKeySpacing  := BASE_KEY_SPACING;
  
  FOriginX       := BASE_ORIGIN;
  FOriginY       := BASE_ORIGIN;
  FRowGapExtra   := BASE_ROW_GAP_EXTRA;
  FKeySize.cx    := BASE_KEY_SIZE;
  FKeySize.cy    := BASE_KEY_SIZE;
  FKeySpacing    := BASE_KEY_SPACING;
  FMappedColor   := $E4F6E0;
  FUnmappedColor := $F8F8F8;
  FSelectedColor := clHighlight;
  FHighContrastMode := False;

  Font.Name := 'Segoe UI';
  Font.Size := 9;

  FRows := BuildKeyboardRows(FShiftState);
  ApplyPreferredExtent;
end;

procedure TVittixKeyboardView.ChangeScale(M, D: Integer);
begin
  if (M > 0) and (D > 0) and (M <> D) then
  begin
    FRefOriginX     := MulDiv(FRefOriginX,     M, D);
    FRefOriginY     := MulDiv(FRefOriginY,     M, D);
    FRefRowGapExtra := MulDiv(FRefRowGapExtra, M, D);
    FRefKeySize.cx  := MulDiv(FRefKeySize.cx,  M, D);
    FRefKeySize.cy  := MulDiv(FRefKeySize.cy,  M, D);
    FRefKeySpacing  := MulDiv(FRefKeySpacing,  M, D);
  end;
  UseReferenceMetrics;
  if FScaleToFit then
    RecalcFitScale;
  inherited ChangeScale(M, D);
  ApplyPreferredExtent;
end;

{ -------------------------------------------------
  Sizing
------------------------------------------------- }

procedure TVittixKeyboardView.ApplyPreferredExtent;
var
  Row: TKeyRowDef;
  KeyDef: TKeyDef;
  RowWidth, MaxRowWidth: Integer;
begin
  MaxRowWidth := 0;
  for Row in FRows do
  begin
    RowWidth := Round(Row.IndentUnits * (FKeySize.cx + FKeySpacing));
    for KeyDef in Row.Keys do
      Inc(RowWidth, KeyPixelWidth(KeyDef) + FKeySpacing);
    if RowWidth > MaxRowWidth then
      MaxRowWidth := RowWidth;
  end;

  Width  := FOriginX * 2 + MaxRowWidth;
  Height := FOriginY * 2 +
            Length(FRows) * (FKeySize.cy + FKeySpacing + FRowGapExtra);
end;

procedure TVittixKeyboardView.RebuildLayout;
begin
  FRows := BuildKeyboardRows(FShiftState);
  ApplyPreferredExtent;
  Invalidate;
end;

function TVittixKeyboardView.KeyPixelWidth(const KeyDef: TKeyDef): Integer;
begin
  Result := Round(KeyDef.WidthUnits * FKeySize.cx +
                  (KeyDef.WidthUnits - 1) * FKeySpacing);
end;

{ -------------------------------------------------
  Property setters
------------------------------------------------- }


procedure TVittixKeyboardView.UseReferenceMetrics;
begin
  FOriginX     := FRefOriginX;
  FOriginY     := FRefOriginY;
  FRowGapExtra := FRefRowGapExtra;
  FKeySize     := FRefKeySize;
  FKeySpacing  := FRefKeySpacing;
end;

procedure TVittixKeyboardView.RecalcFitScale;
var
  Row: TKeyRowDef;
  KeyDef: TKeyDef;
  MaxRefW, RefH: Integer;
  RowW: Integer;
  ScaleX, ScaleY, Scale: Double;
begin
  if FRows = nil then Exit;
  if (ClientWidth <= 0) or (ClientHeight <= 0) then Exit;

  MaxRefW := 0;
  for Row in FRows do
  begin
    RowW := Round(Row.IndentUnits * (FRefKeySize.cx + FRefKeySpacing));
    for KeyDef in Row.Keys do
      Inc(RowW, Round(KeyDef.WidthUnits * FRefKeySize.cx + (KeyDef.WidthUnits - 1) * FRefKeySpacing) + FRefKeySpacing);
    if RowW > MaxRefW then MaxRefW := RowW;
  end;
  RefH := Length(FRows) * (FRefKeySize.cy + FRefKeySpacing + FRefRowGapExtra);

  if (MaxRefW = 0) or (RefH = 0) then Exit;

  ScaleX := (ClientWidth  - (FRefOriginX * 2)) / MaxRefW;
  ScaleY := (ClientHeight - (FRefOriginY * 2)) / RefH;
  if ScaleX < ScaleY then Scale := ScaleX else Scale := ScaleY;

  FKeySize.cx  := Round(FRefKeySize.cx  * Scale);
  FKeySize.cy  := Round(FRefKeySize.cy  * Scale);
  FKeySpacing  := Round(FRefKeySpacing  * Scale);
  FRowGapExtra := Round(FRefRowGapExtra * Scale);

  FOriginX := (ClientWidth  - Round(MaxRefW * Scale)) div 2;
  FOriginY := (ClientHeight - Round(RefH * Scale)) div 2;
  if FOriginX < 0 then FOriginX := 0;
  if FOriginY < 0 then FOriginY := 0;
end;

procedure TVittixKeyboardView.Resize;
begin
  inherited;
  if FScaleToFit then
  begin
    RecalcFitScale;
    Invalidate;
  end;
end;

procedure TVittixKeyboardView.SetScaleToFit(const Value: Boolean);
begin
  if FScaleToFit <> Value then
  begin
    FScaleToFit := Value;
    if FScaleToFit then
      RecalcFitScale
    else
    begin
      UseReferenceMetrics;
      ApplyPreferredExtent;
    end;
    Invalidate;
  end;
end;

procedure TVittixKeyboardView.SetLayout(const Value: TKeyboardLayout);
begin
  if FLayout <> Value then
  begin
    FLayout := Value;
    // Route through the setter so the change is always observed and the
    // control invalidates exactly once.
    SetSelectedKey('');
  end;
end;

procedure TVittixKeyboardView.SetSelectedKey(const Value: string);
begin
  if not SameText(FSelectedKey, Value) then
  begin
    FSelectedKey := Value;
    Invalidate;
  end;
end;

procedure TVittixKeyboardView.SetShiftState(const Value: Boolean);
begin
  if FShiftState <> Value then
  begin
    FShiftState := Value;
    RebuildLayout;
  end;
end;

procedure TVittixKeyboardView.SetHighContrastMode(const Value: Boolean);
begin
  if FHighContrastMode <> Value then
  begin
    FHighContrastMode := Value;
    Invalidate;
  end;
end;

procedure TVittixKeyboardView.SetKeySpacing(const Value: Integer);
begin
  if FKeySpacing <> Value then
  begin
    FKeySpacing := Value;
    ApplyPreferredExtent;
    Invalidate;
  end;
end;

procedure TVittixKeyboardView.SetMappedColor(const Value: TColor);
begin
  if FMappedColor <> Value then
  begin
    FMappedColor := Value;
    Invalidate;
  end;
end;

procedure TVittixKeyboardView.SetUnmappedColor(const Value: TColor);
begin
  if FUnmappedColor <> Value then
  begin
    FUnmappedColor := Value;
    Invalidate;
  end;
end;

procedure TVittixKeyboardView.SetSelectedColor(const Value: TColor);
begin
  if FSelectedColor <> Value then
  begin
    FSelectedColor := Value;
    Invalidate;
  end;
end;

{ -------------------------------------------------
  Painting
------------------------------------------------- }

procedure TVittixKeyboardView.Paint;
var
  Row: TKeyRowDef;
  KeyDef: TKeyDef;
  R: TRect;
  Hit: TKeyboardKeyHit;
  Glyph: string;
  KeyW: Integer;
  TopPos, LeftPos: Integer;
  HitCount, HitIndex: Integer;
begin
  if FHighContrastMode then
    Canvas.Brush.Color := clBlack
  else if TStyleManager.IsCustomStyleActive then
    Canvas.Brush.Color := StyleServices.GetSystemColor(clWindow)
  else
    Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);

  if FLayout = nil then
  begin
    Canvas.Font.Assign(Font);
    if FHighContrastMode then
      Canvas.Font.Color := clWhite
    else if TStyleManager.IsCustomStyleActive then
      Canvas.Font.Color := StyleServices.GetSystemColor(clGrayText)
    else
      Canvas.Font.Color := clGrayText;
    Canvas.TextOut(FOriginX, FOriginY,
      'Open or create a layout to see the keyboard view.');
    SetLength(FHits, 0);
    Exit;
  end;

  Canvas.Font.Assign(Font);
  Canvas.Brush.Style := bsSolid;

  // First pass: count keys so we can size FHits once. The old
  // `FHits := FHits + [Hit]` reallocated on every key, making Paint O(n^2).
  HitCount := 0;
  for Row in FRows do
    Inc(HitCount, Length(Row.Keys));
  SetLength(FHits, HitCount);
  HitIndex := 0;

  TopPos := FOriginY;
  for Row in FRows do
  begin
    LeftPos := FOriginX +
               Round(Row.IndentUnits * (FKeySize.cx + FKeySpacing));

    for KeyDef in Row.Keys do
    begin
      KeyW := KeyPixelWidth(KeyDef);
      R := Rect(LeftPos, TopPos, LeftPos + KeyW, TopPos + FKeySize.cy);

      if KeyDef.IsSpecial then
        Glyph := ''
      else
        Glyph := GetGlyphForKey(KeyDef.KeyName);

      DrawKey(KeyDef, R, Glyph, SameText(KeyDef.KeyName, FSelectedKey));

      Hit.KeyName   := KeyDef.KeyName;
      Hit.KeyRect   := R;
      Hit.Glyph     := Glyph;
      Hit.IsSpecial := KeyDef.IsSpecial;
      FHits[HitIndex] := Hit;
      Inc(HitIndex);

      Inc(LeftPos, KeyW + FKeySpacing);
    end;

    Inc(TopPos, FKeySize.cy + FKeySpacing + FRowGapExtra);
  end;
end;

procedure TVittixKeyboardView.DrawKey(const KeyDef: TKeyDef; const R: TRect;
  const Glyph: string; IsSelected: Boolean);
var
  FillColor, BorderColor, TextColor: TColor;
  BorderWidth: Integer;
  IsMapped: Boolean;
  IsStyled: Boolean;
begin
  IsMapped := (Glyph <> '') and not KeyDef.IsSpecial;
  IsStyled := TStyleManager.IsCustomStyleActive;

  if FHighContrastMode then
  begin
    FillColor   := clBlack;
    BorderColor := clWhite;
    if IsSelected then
    begin
      BorderColor := clYellow;
      TextColor   := clYellow;
    end
    else if IsMapped then
      TextColor := clWhite
    else
      TextColor := clSilver;
  end
  else if IsStyled then
  begin
    // Style-aware: use the active VCL style's palette
    if IsMapped then
      FillColor := StyleServices.GetSystemColor(clBtnFace)
    else
      FillColor := StyleServices.GetSystemColor(clWindow);
    TextColor   := StyleServices.GetSystemColor(clWindowText);
    BorderColor := StyleServices.GetSystemColor(clGrayText);
    if IsSelected then
      BorderColor := StyleServices.GetSystemColor(clHighlight);
  end
  else
  begin
    if IsMapped then
      FillColor := FMappedColor
    else
      FillColor := FUnmappedColor;
    TextColor   := clWindowText;
    BorderColor := clGray;
    if IsSelected then
      BorderColor := FSelectedColor;
  end;

  if KeyDef.IsSpecial and (KeyDef.KeyName = 'Shift') and FShiftState then
  begin
    if FHighContrastMode then
    begin
      FillColor := clWhite;
      TextColor := clBlack;
    end
    else if IsStyled then
    begin
      FillColor := StyleServices.GetSystemColor(clHighlight);
      TextColor := StyleServices.GetSystemColor(clHighlightText);
    end
    else
    begin
      FillColor := $00E0E0E0; // lighter/pressed look for Shift
      TextColor := clWindowText;
    end;
  end;

  BorderWidth := Ord(IsSelected) + 1;

  Canvas.Brush.Color := FillColor;
  Canvas.Pen.Color   := BorderColor;
  Canvas.Pen.Width   := BorderWidth;
  Canvas.Rectangle(R);
  Canvas.Pen.Width   := 1;

  if KeyDef.IsSpecial then
  begin
    Canvas.Font.Color := TextColor;
    Canvas.Font.Style := [];
    Canvas.TextOut(
      R.Left + (R.Width  div 2) - (Canvas.TextWidth (KeyDef.KeyName) div 2),
      R.Top  + (R.Height div 2) - (Canvas.TextHeight(KeyDef.KeyName) div 2),
      KeyDef.KeyName);
    Exit;
  end;

  // Physical key label, top-left.
  Canvas.Font.Color := TextColor;
  Canvas.Font.Style := [];
  Canvas.TextOut(R.Left + 4, R.Top + 4, KeyDef.KeyName);

  // Mapped glyph, centered and bold.
  if Glyph <> '' then
  begin
    Canvas.Font.Style := [fsBold];
    Canvas.TextOut(
      R.Left + (R.Width  div 2) - (Canvas.TextWidth (Glyph) div 2),
      R.Top  + (R.Height div 2) - (Canvas.TextHeight(Glyph) div 2),
      Glyph);
  end;
end;

{ -------------------------------------------------
  Hit testing
------------------------------------------------- }

function TVittixKeyboardView.HitTestInternal(const P: TPoint;
  out Hit: TKeyboardKeyHit): Boolean;
var
  H: TKeyboardKeyHit;
begin
  for H in FHits do
    if PtInRect(H.KeyRect, P) then
    begin
      Hit := H;
      Exit(True);
    end;

  Hit.KeyName   := '';
  Hit.KeyRect   := Rect(0, 0, 0, 0);
  Hit.Glyph     := '';
  Hit.IsSpecial := False;
  Result := False;
end;

function TVittixKeyboardView.KeyAtPoint(const P: TPoint): TKeyboardKeyHit;
begin
  HitTestInternal(P, Result);
end;

function TVittixKeyboardView.KeyAtPoint(const P: TPoint;
  out Hit: TKeyboardKeyHit): Boolean;
begin
  Result := HitTestInternal(P, Hit);
end;

{ -------------------------------------------------
  Mouse / keyboard
------------------------------------------------- }

procedure TVittixKeyboardView.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Hit: TKeyboardKeyHit;
  Glyph: string;
begin
  inherited;
  SetFocus;
  if FLayout = nil then Exit;

  if not HitTestInternal(Point(X, Y), Hit) then Exit;
  if Hit.IsSpecial then
  begin
    if Hit.KeyName = 'Shift' then
      ShiftState := not ShiftState;
    Exit;
  end;

  SetSelectedKey(Hit.KeyName);

  // Use the live lookup, not Hit.Glyph -- FHits can be one paint behind if
  // the mouse message was queued before WM_PAINT got processed.
  Glyph := GetGlyphForKey(Hit.KeyName);
  if Assigned(FOnKeySelect) then
    FOnKeySelect(Self, Hit.KeyName, Glyph);
end;

procedure TVittixKeyboardView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  if FLayout = nil then Exit;

  case Key of
    VK_LEFT:   begin MoveSelection(-1,  0); Key := 0; end;
    VK_RIGHT:  begin MoveSelection( 1,  0); Key := 0; end;
    VK_UP:     begin MoveSelection( 0, -1); Key := 0; end;
    VK_DOWN:   begin MoveSelection( 0,  1); Key := 0; end;
    VK_HOME:   begin MoveSelection(Low(Integer),  0); Key := 0; end;
    VK_END:    begin MoveSelection(High(Integer), 0); Key := 0; end;
    VK_RETURN,
    VK_SPACE:
      begin
        FireSelectForSelected;
        Key := 0;
      end;
    VK_ESCAPE:
      begin
        SetSelectedKey('');
        Key := 0;
      end;
  end;
end;

function TVittixKeyboardView.IsSpecialKey(const KeyName: string): Boolean;
var
  Row: TKeyRowDef;
  K: TKeyDef;
begin
  for Row in FRows do
    for K in Row.Keys do
      if SameText(K.KeyName, KeyName) then
        Exit(K.IsSpecial);
  Result := False;
end;

procedure TVittixKeyboardView.MoveSelection(const DCol, DRow: Integer);
var
  I, J, CurRow, CurCol, NewRow, NewCol: Integer;
begin
  CurRow := -1;
  CurCol := -1;

  if FSelectedKey <> '' then
    for I := 0 to High(FRows) do
    begin
      for J := 0 to High(FRows[I].Keys) do
        if SameText(FRows[I].Keys[J].KeyName, FSelectedKey) then
        begin
          CurRow := I;
          CurCol := J;
          Break;
        end;
      if CurRow >= 0 then Break;
    end;

  if CurRow < 0 then
  begin
    // Nothing selected yet: start at the top-left.
    CurRow := 0;
    CurCol := 0;
  end
  else
  begin
    // Vertical: wrap around.
    NewRow := CurRow + DRow;
    if NewRow < 0 then NewRow := High(FRows)
    else if NewRow > High(FRows) then NewRow := 0;

    // Horizontal: sentinel values mean "row start" / "row end".
    if DCol = Low(Integer) then
      NewCol := 0
    else if DCol = High(Integer) then
      NewCol := High(FRows[NewRow].Keys)
    else
    begin
      NewCol := CurCol + DCol;
      if NewCol < 0 then
        NewCol := 0
      else if NewCol > High(FRows[NewRow].Keys) then
        NewCol := High(FRows[NewRow].Keys);
    end;

    CurRow := NewRow;
    CurCol := NewCol;
  end;

  SetSelectedKey(FRows[CurRow].Keys[CurCol].KeyName);
end;

procedure TVittixKeyboardView.FireSelectForSelected;
var
  Glyph: string;
begin
  if FSelectedKey = '' then Exit;
  if IsSpecialKey(FSelectedKey) then Exit;   // no-op, same as mouse

  Glyph := GetGlyphForKey(FSelectedKey);
  if Assigned(FOnKeySelect) then
    FOnKeySelect(Self, FSelectedKey, Glyph);
end;

{ -------------------------------------------------
  Mapping lookups / mutation
------------------------------------------------- }

function TVittixKeyboardView.GetGlyphForKey(const Key: string): string;
begin
  // Resolution order lives in LayoutResolver so the editor, the on-screen
  // keyboard and this view can never disagree about what a key produces.
  Result := TLayoutResolver.GlyphFor(FLayout, Key);
end;

function TVittixKeyboardView.CurrentMapping(const KeyName: string;
  out Glyph: string): Boolean;
begin
  // Now returns the same glyph Paint draws. If you specifically want the
  // DirectMap entry only, query FLayout.DirectMap directly.
  Glyph  := GetGlyphForKey(KeyName);
  Result := Glyph <> '';
end;

procedure TVittixKeyboardView.AssignKey(const KeyName, Glyph: string);
var
  Trimmed: string;
begin
  if (FLayout = nil) or (Trim(KeyName) = '') then Exit;

  Trimmed := Trim(Glyph);
  if Trimmed = '' then
  begin
    ClearKey(KeyName);
    Exit;
  end;

  FLayout.DirectMap.AddOrSetValue(KeyName, Trimmed);
  Invalidate;

  if Assigned(FOnKeyAssign) then
    FOnKeyAssign(Self, KeyName, Trimmed);
end;

procedure TVittixKeyboardView.ClearKey(const KeyName: string);
begin
  if (FLayout = nil) or (Trim(KeyName) = '') then Exit;

  if FLayout.DirectMap.ContainsKey(KeyName) then
    FLayout.DirectMap.Remove(KeyName);
  Invalidate;

  if Assigned(FOnKeyAssign) then
    FOnKeyAssign(Self, KeyName, '');
end;

end.
