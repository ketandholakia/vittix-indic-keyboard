unit EditorTheme;

{ The editor's design tokens, in one place.

  Before this unit the form carried seven different greys, three font sizes and
  six ad-hoc text colours, all as literals in the DFM. Those literals are still
  present, but they are superseded at startup by ApplyEditorTheme, which assigns
  every surface, text colour and size from this table. Changing the look of the
  editor now means changing this file.

  Colours are written as BGR hex because that is how VCL stores a TColor, and
  the source palette is noted next to each value so it can be checked against
  the design reference.

  High Contrast composes with this: it captures the themed colours on the way in
  and restores them on the way out, so leaving High Contrast returns the editor
  to the palette applied here rather than to the old DFM literals. }

interface

uses
  System.SysUtils,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Themes;

type
  // TLabel does not republish Color, so reaching it needs the standard
  // protected-member accessor rather than a cast to TLabel.
  TControlSurfaceAccess = class(TControl);

  TEditorTheme = record
    Canvas: TColor;         // window and grid background
    Surface: TColor;        // bars, headers, sidebar
    SurfaceAlt: TColor;     // hover, alternating rows
    Inset: TColor;          // wells, read-only fields
    Border: TColor;
    BorderMuted: TColor;
    BorderSubtle: TColor;   // row rules
    Text: TColor;
    TextMuted: TColor;
    TextSubtle: TColor;     // section headers, shortcut column
    Accent: TColor;
    AccentHover: TColor;
    AccentSubtle: TColor;
    Success: TColor;
    SuccessSubtle: TColor;
    Warning: TColor;
    WarningSubtle: TColor;
    Danger: TColor;
    DangerSubtle: TColor;
    BodyHeight: Integer;    // text height in pixels, negative as VCL expects
    SmallHeight: Integer;
  end;

// The palette used when no VCL style is active, and the source of the semantic
// colours (success, warning, danger) that styles do not provide.
function EditorThemeFromTokens: TEditorTheme;

// The palette used when the editor is running under a VCL style.
function EditorThemeFromStyle: TEditorTheme;

// The palette the editor uses when High Contrast is off.
function EditorThemeDefault: TEditorTheme;

// The palette currently applied, for painters that cannot receive it as an
// argument (GridDrawCell).
function EditorThemeCurrent: TEditorTheme;

// Walks ARoot and assigns the palette. Call once from the form's OnCreate.
procedure ApplyEditorTheme(ARoot: TWinControl; const Theme: TEditorTheme);

// True for the horizontal bars that should read as surface rather than canvas.
function IsSurfaceBar(const ControlName: string): Boolean;

// True for the sidebar panels, which sit on the surface rather than the canvas.
function IsSidebarPanel(const ControlName: string): Boolean;

// True for the small uppercase section headers.
function IsSectionLabel(const ControlName: string): Boolean;

implementation

uses
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.Grids,
  Vcl.ExtCtrls,
  Vcl.Forms;

const
  CLR_CANVAS         = $00FFFFFF; // #FFFFFF
  CLR_SURFACE        = $00FAF8F6; // #F6F8FA
  CLR_SURFACE_ALT    = $00F6F2EE; // #EEF2F6
  CLR_INSET          = $00F2EEEA; // #EAEEF2
  CLR_BORDER         = $00DED7D0; // #D0D7DE
  CLR_BORDER_MUTED   = $00E4DED8; // #D8DEE4
  CLR_TEXT           = $0028231F; // #1F2328
  CLR_TEXT_MUTED     = $00766D65; // #656D76
  CLR_TEXT_SUBTLE    = $009F958C; // #8C959F
  CLR_ACCENT         = $00DA6909; // #0969DA
  CLR_ACCENT_HOVER   = $00AE5005; // #0550AE
  CLR_ACCENT_SUBTLE  = $00FFF4DD; // #DDF4FF
  CLR_SUCCESS        = $00377F1A; // #1A7F37
  CLR_SUCCESS_SUBTLE = $00E1FBDA; // #DAFBE1
  CLR_WARNING        = $0000679A; // #9A6700
  CLR_WARNING_SUBTLE = $00C5F8FF; // #FFF8C5
  CLR_DANGER         = $002E22CF; // #CF222E
  CLR_DANGER_SUBTLE  = $00E9EBFF; // #FFEBE9

  BODY_HEIGHT  = -12; // 9pt, the body size
  SMALL_HEIGHT = -11; // 8pt, metadata and section headers

var
  GCurrentTheme: TEditorTheme;
  GThemeLoaded: Boolean;

// The palette the editor uses when no VCL style is active. This is the fallback
// path; when a custom style is loaded it owns the colours of every style-aware
// control, so the theme defers to it instead of fighting it.
function EditorThemeDefault: TEditorTheme;
begin
  Result := EditorThemeFromStyle;
end;

// Colours taken from the active VCL style, so the few surfaces this unit does
// paint itself (the grid) match the chrome the style draws everywhere else.
function EditorThemeFromStyle: TEditorTheme;
var
  S: TCustomStyleServices;
begin
  if not TStyleManager.IsCustomStyleActive then
    Exit(EditorThemeFromTokens);

  S := StyleServices;

  Result.Canvas := S.GetSystemColor(clWindow);
  Result.Surface := S.GetSystemColor(clBtnFace);
  Result.SurfaceAlt := S.GetSystemColor(clBtnFace);
  Result.Inset := S.GetSystemColor(clBtnFace);
  Result.Border := S.GetSystemColor(clBtnShadow);
  Result.BorderMuted := S.GetSystemColor(clBtnShadow);
  Result.BorderSubtle := S.GetSystemColor(cl3DLight);
  Result.Text := S.GetSystemColor(clWindowText);
  // Not clGrayText: a style can map that to something too pale to read as a
  // section heading on the style's own panel colour. These greys are readable
  // on any light surface.
  Result.TextMuted := CLR_TEXT_MUTED;
  Result.TextSubtle := CLR_TEXT_SUBTLE;
  Result.Accent := S.GetSystemColor(clHighlight);
  Result.AccentHover := S.GetSystemColor(clHighlight);
  Result.AccentSubtle := S.GetSystemColor(clHighlight);
  Result.Success := CLR_SUCCESS;
  Result.SuccessSubtle := CLR_SUCCESS_SUBTLE;
  Result.Warning := CLR_WARNING;
  Result.WarningSubtle := CLR_WARNING_SUBTLE;
  Result.Danger := CLR_DANGER;
  Result.DangerSubtle := CLR_DANGER_SUBTLE;
  Result.BodyHeight := BODY_HEIGHT;
  Result.SmallHeight := SMALL_HEIGHT;
end;

function EditorThemeFromTokens: TEditorTheme;
begin
  Result.Canvas := CLR_CANVAS;
  Result.Surface := CLR_SURFACE;
  Result.SurfaceAlt := CLR_SURFACE_ALT;
  Result.Inset := CLR_INSET;
  Result.Border := CLR_BORDER;
  Result.BorderMuted := CLR_BORDER_MUTED;
  Result.BorderSubtle := CLR_INSET;
  Result.Text := CLR_TEXT;
  Result.TextMuted := CLR_TEXT_MUTED;
  Result.TextSubtle := CLR_TEXT_SUBTLE;
  Result.Accent := CLR_ACCENT;
  Result.AccentHover := CLR_ACCENT_HOVER;
  Result.AccentSubtle := CLR_ACCENT_SUBTLE;
  Result.Success := CLR_SUCCESS;
  Result.SuccessSubtle := CLR_SUCCESS_SUBTLE;
  Result.Warning := CLR_WARNING;
  Result.WarningSubtle := CLR_WARNING_SUBTLE;
  Result.Danger := CLR_DANGER;
  Result.DangerSubtle := CLR_DANGER_SUBTLE;
  Result.BodyHeight := BODY_HEIGHT;
  Result.SmallHeight := SMALL_HEIGHT;
end;

function EditorThemeCurrent: TEditorTheme;
begin
  if not GThemeLoaded then
  begin
    GCurrentTheme := EditorThemeDefault;
    GThemeLoaded := True;
  end;
  Result := GCurrentTheme;
end;

function IsSurfaceBar(const ControlName: string): Boolean;
begin
  Result := SameText(ControlName, 'pnlCommandBar') or
    SameText(ControlName, 'pnlProblems') or
    SameText(ControlName, 'pnlKeyboardHeader') or
    SameText(ControlName, 'pnlHeader') or
    (Pos('pnlSearch', ControlName) = 1);
end;

function IsSidebarPanel(const ControlName: string): Boolean;
begin
  Result := SameText(ControlName, 'pnlSideScroll') or
    SameText(ControlName, 'pnlLayoutInfo') or
    SameText(ControlName, 'pnlProperties') or
    SameText(ControlName, 'pnlHotkeys') or
    SameText(ControlName, 'pnlAppSettings') or
    SameText(ControlName, 'pnlMappingInspector') or
    SameText(ControlName, 'pnlDiagnostics');
end;

function IsSectionLabel(const ControlName: string): Boolean;
begin
  Result := (Pos('lblSection', ControlName) = 1) or
    SameText(ControlName, 'lblInspectorTitle');
end;

procedure ApplyEditorTheme(ARoot: TWinControl; const Theme: TEditorTheme);
var
  I: Integer;
  Ctl: TControl;
begin
  for I := 0 to ARoot.ControlCount - 1 do
  begin
    Ctl := ARoot.Controls[I];

    if Ctl is TPanel then
    begin
      TPanel(Ctl).ParentBackground := False;
      if IsSidebarPanel(Ctl.Name) then
        TPanel(Ctl).Color := Theme.Surface
      else if IsSurfaceBar(Ctl.Name) then
        TPanel(Ctl).Color := Theme.Surface
      else
        TPanel(Ctl).Color := Theme.Canvas;
    end
    else if Ctl is TTabSheet then
      TControlSurfaceAccess(Ctl).Color := Theme.Canvas
    else if Ctl is TPageControl then
      TPageControl(Ctl).Font.Color := Theme.Text
    else if Ctl is TStringGrid then
    begin
      TStringGrid(Ctl).Color := Theme.Canvas;
      TStringGrid(Ctl).FixedColor := Theme.Surface;
      TStringGrid(Ctl).Font.Color := Theme.Text;
    end
    else if Ctl is TStatusBar then
    begin
      TStatusBar(Ctl).Color := Theme.Surface;
      TStatusBar(Ctl).Font.Color := Theme.TextMuted;
    end
    else if Ctl is TListBox then
    begin
      TListBox(Ctl).Color := Theme.Canvas;
      TListBox(Ctl).Font.Color := Theme.Text;
    end
    else if Ctl is TEdit then
    begin
      TEdit(Ctl).Color := Theme.Canvas;
      TEdit(Ctl).Font.Color := Theme.Text;
    end
    else if Ctl is TComboBox then
    begin
      TComboBox(Ctl).Color := Theme.Canvas;
      TComboBox(Ctl).Font.Color := Theme.Text;
    end
    else if Ctl is TCheckBox then
      TCheckBox(Ctl).Font.Color := Theme.Text
    else if Ctl is TButton then
      TButton(Ctl).Font.Color := Theme.Text
    else if Ctl is TLabel then
    begin
      if IsSectionLabel(Ctl.Name) then
      begin
        // Section headers: small, bold, uppercase, muted.
        TLabel(Ctl).Caption := UpperCase(TLabel(Ctl).Caption);
        TLabel(Ctl).Font.Style := [fsBold];
        TLabel(Ctl).Font.Height := Theme.SmallHeight;
        TLabel(Ctl).Font.Color := Theme.TextSubtle;
      end
      else if Pos('lblDivider', Ctl.Name) = 1 then
      begin
        // Hairline rules drawn as thin labels.
        TControlSurfaceAccess(Ctl).Color := Theme.BorderMuted;
      end
      else
      begin
        TLabel(Ctl).Font.Color := Theme.TextMuted;
        // Collapse the stray 10pt labels onto the body size.
        if TLabel(Ctl).Font.Height < Theme.BodyHeight then
          TLabel(Ctl).Font.Height := Theme.BodyHeight;
      end;
    end;

    if Ctl is TWinControl then
      ApplyEditorTheme(TWinControl(Ctl), Theme);
  end;

  // The root itself is not in its own Controls list.
  if ARoot is TCustomForm then
  begin
    TCustomForm(ARoot).Color := Theme.Canvas;
    TCustomForm(ARoot).Font.Color := Theme.Text;
    TCustomForm(ARoot).Font.Height := Theme.BodyHeight;
  end;
end;

initialization
  GCurrentTheme := EditorThemeDefault;
  GThemeLoaded := True;

end.
