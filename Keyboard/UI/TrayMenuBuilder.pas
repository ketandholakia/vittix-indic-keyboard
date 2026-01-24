unit TrayMenuBuilder;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Menus,
  LayoutManager,
  LayoutModel,
  ShreeLipi.Engine,
  EngineState;

type
  TTrayMenuBuilder = class
  private
    FLayoutsMenu: TMenuItem;
    procedure LayoutItemClick(Sender: TObject);
  public
    constructor Create(ALayoutsMenu: TMenuItem);
    procedure Build;
  end;

implementation

{ --------------------------------------------------
  Constructor
-------------------------------------------------- }

constructor TTrayMenuBuilder.Create(ALayoutsMenu: TMenuItem);
begin
  inherited Create;
  FLayoutsMenu := ALayoutsMenu;
end;

{ --------------------------------------------------
  Build layout list dynamically
-------------------------------------------------- }

procedure TTrayMenuBuilder.Build;
var
  I: Integer;
  Item: TMenuItem;
  Layout: TKeyboardLayout;
begin
  if not Assigned(FLayoutsMenu) then
    Exit;

  FLayoutsMenu.Clear;

  for I := 0 to gLayoutManager.LayoutCount - 1 do
  begin
    Layout := gLayoutManager.GetLayout(I);

    Item := TMenuItem.Create(FLayoutsMenu);
    Item.Caption := Layout.Name;
    Item.Tag := I;
    Item.RadioItem := True;
    Item.OnClick := LayoutItemClick;

    if Layout = gLayoutManager.ActiveLayout then
      Item.Checked := True;

    FLayoutsMenu.Add(Item);
  end;
end;

{ --------------------------------------------------
  Layout selection handler
-------------------------------------------------- }

procedure TTrayMenuBuilder.LayoutItemClick(Sender: TObject);
var
  Index: Integer;
begin
  if not (Sender is TMenuItem) then
    Exit;

  Index := TMenuItem(Sender).Tag;

  gLayoutManager.SetActiveLayout(Index);
  SetActiveLayout(gLayoutManager.ActiveLayout);

  ResetEngineState;

  Build; // refresh checkmarks
end;

end.

