unit FontReminder;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.ExtCtrls,
  LayoutModel;

type
  { --------------------------------------------------
    Font reminder helper
    Shows tray notification when layout changes
  -------------------------------------------------- }
  TFontReminder = class
  private
    FTrayIcon: TTrayIcon;
    FLastLayoutID: string;
    FEnabled: Boolean;

    function GetLayoutFont(const ALayout: TKeyboardLayout): string;
  public
    constructor Create(ATrayIcon: TTrayIcon);
    procedure NotifyLayoutChange(ALayout: TKeyboardLayout);

    procedure SetEnabled(AValue: Boolean);
    property Enabled: Boolean read FEnabled write SetEnabled;
  end;

implementation

{ --------------------------------------------------
  Constructor
-------------------------------------------------- }

constructor TFontReminder.Create(ATrayIcon: TTrayIcon);
begin
  inherited Create;
  FTrayIcon := ATrayIcon;
  FLastLayoutID := '';
  FEnabled := True;
end;

{ --------------------------------------------------
  Enable / Disable
-------------------------------------------------- }

procedure TFontReminder.SetEnabled(AValue: Boolean);
begin
  FEnabled := AValue;
end;

{ --------------------------------------------------
  Get recommended font for layout
-------------------------------------------------- }

function TFontReminder.GetLayoutFont(
  const ALayout: TKeyboardLayout
): string;
begin
  Result := '';

  if not Assigned(ALayout) then
    Exit;

  { Preferred order:
    1. Layout.RecommendedFont (if you added it)
    2. Layout.Name heuristic
  }

  // If your LayoutModel has RecommendedFont
  {$IFDEF HAS_LAYOUT_FONT}
  Result := ALayout.RecommendedFont;
  {$ENDIF}

  if Result <> '' then
    Exit;

  // Heuristic fallback
  if Pos('Shree', ALayout.Name) > 0 then
    Result := 'Shree-Lipi-0714'
  else if Pos('Kruti', ALayout.Name) > 0 then
    Result := 'Kruti Dev 010'
  else if Pos('Chanakya', ALayout.Name) > 0 then
    Result := 'Chanakya'
  else
    Result := '';
end;

{ --------------------------------------------------
  Notify on layout change
-------------------------------------------------- }

procedure TFontReminder.NotifyLayoutChange(
  ALayout: TKeyboardLayout
);
var
  FontName: string;
begin
  if not FEnabled then
    Exit;

  if not Assigned(FTrayIcon) then
    Exit;

  if not Assigned(ALayout) then
    Exit;

  // Prevent repeated reminders
  if SameText(FLastLayoutID, ALayout.LayoutID) then
    Exit;

  FLastLayoutID := ALayout.LayoutID;

  FontName := GetLayoutFont(ALayout);
  if FontName = '' then
    Exit;

  FTrayIcon.BalloonTitle := 'Font Reminder';
  FTrayIcon.BalloonHint :=
    Format(
      'Layout "%s" works best with font:%s%s',
      [ALayout.Name, sLineBreak, FontName]
    );
  FTrayIcon.BalloonTimeout := 5000;
  FTrayIcon.BalloonFlags := bfInfo;

  FTrayIcon.ShowBalloonHint;
end;

end.

