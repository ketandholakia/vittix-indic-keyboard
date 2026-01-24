unit frmTray;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.ImgList,
   
  Vcl.Menus,
  Vcl.ExtCtrls,

  EngineState,
  KeyboardHook,
  KeyTranslator,
  ShreeLipi.Engine,

  LayoutManager,
  AppSettings,
  LayoutModel,

  frmOnScreenKeyboard;

type
  TfrmTray = class(TForm)
    TrayIcon: TTrayIcon;

    PopupMenu: TPopupMenu;

    miEnable: TMenuItem;
    miSep1: TMenuItem;
    miLayouts: TMenuItem;
    miOnScreen: TMenuItem;
    miSep2: TMenuItem;
    miExit: TMenuItem;
    miLayoutGroupHeader: TMenuItem;
    miLayoutNameHeader: TMenuItem;
    miSepHeader: TMenuItem;
    ilTrayIcons: TImageList;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure miEnableClick(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure miOnScreenClick(Sender: TObject);
    procedure PopupMenuPopup(Sender: TObject);

  private
    FOSK: TfrmOnScreenKeyboard;

    procedure HandleTranslatedKey(const AKey: string);
    procedure HandleRawKey(const AChar: string);

    procedure BuildLayoutMenu;
    procedure UpdateLayoutHeader;
    procedure LayoutItemClick(Sender: TObject);
    procedure UpdateTrayIcon;
  protected
    procedure WMHotKey(var Msg: TWMHotKey); message WM_HOTKEY;
  end;

var
  gFrmTray: TfrmTray;

implementation

{$R *.dfm}

const
  HOTKEY_ID_TOGGLE = 1; // ID for the global hotkey to toggle the engine

{ --------------------------------------------------
  Keyboard handlers (FIX for E2009)
-------------------------------------------------- }

procedure TfrmTray.HandleTranslatedKey(const AKey: string);
begin
  ProcessKeyChar(AKey);
end;

procedure TfrmTray.HandleRawKey(const AChar: string);
begin
  TranslateKey(AChar);
end;

{ --------------------------------------------------
  Form lifecycle
-------------------------------------------------- }

procedure TfrmTray.FormCreate(Sender: TObject);
var
  Mods: UINT;
  VK: UINT;
begin
  Application.Title := 'Vittix Indic Keyboard';

  Visible := False;
  BorderStyle := bsNone;

  SetWindowLong(
    Handle,
    GWL_EXSTYLE,
    GetWindowLong(Handle, GWL_EXSTYLE) or WS_EX_TOOLWINDOW
  );

  // 🔴 REQUIRED: initialize engine
  InitEngineState;
  SetEngineEnabled(True);
  miEnable.Checked := True;

  UpdateTrayIcon;

  // 🔴 REQUIRED: keyboard pipeline
  SetKeyHandler(HandleRawKey);
  SetTranslatorHandler(HandleTranslatedKey);
  InstallKeyboardHook;

  // Load layouts
  gLayoutManager.Initialize(GAppSettings.LayoutsPath);

  if GAppSettings.DefaultLayoutID <> '' then
    gLayoutManager.SetActiveLayoutByID(GAppSettings.DefaultLayoutID);

  if gLayoutManager.ActiveLayout <> nil then
  begin
    SetActiveLayout(gLayoutManager.ActiveLayout);
    UpdateLayoutHeader;
  end;

  BuildLayoutMenu;

  // Update menu caption with hotkey text
  miEnable.Caption := 'Enable Keyboard (' + GAppSettings.GetToggleHotkeyText + ')';

  // Register the global hotkey from settings
  GAppSettings.ParseHotkey(GAppSettings.GetToggleHotkeyText, Mods, VK);
  if not RegisterHotKey(Handle, HOTKEY_ID_TOGGLE, Mods, VK) then
  begin
    MessageBox(
      Handle,
      PChar('Hotkey already in use: ' + GAppSettings.GetToggleHotkeyText),
      'Vittix Indic Keyboard',
      MB_ICONWARNING or MB_OK
    );
  end;

  TrayIcon.Visible := True;
end;


procedure TfrmTray.FormDestroy(Sender: TObject);
begin
  UnregisterHotKey(Handle, HOTKEY_ID_TOGGLE);
  FreeAndNil(FOSK);
  RemoveKeyboardHook;
end;

{ --------------------------------------------------
  Windows Messages
-------------------------------------------------- }

procedure TfrmTray.WMHotKey(var Msg: TWMHotKey);
begin
  if Msg.HotKey = HOTKEY_ID_TOGGLE then
  begin
    miEnableClick(nil); // Reuse the menu click logic to toggle the engine
  end;
end;

{ --------------------------------------------------
  Tray menu handlers
-------------------------------------------------- }

procedure TfrmTray.miEnableClick(Sender: TObject);
begin
  SetEngineEnabled(not EngineEnabled);
  miEnable.Checked := EngineEnabled;
  UpdateTrayIcon;
end;

procedure TfrmTray.miExitClick(Sender: TObject);
begin
  // In a tray-icon application where the main form is hidden, calling Close
  // might not terminate the process. Application.Terminate is the most
  // reliable and explicit way to shut down the entire application.
  Application.Terminate;
end;

procedure TfrmTray.miOnScreenClick(Sender: TObject);
begin
  if not Assigned(FOSK) then
    FOSK := TfrmOnScreenKeyboard.Create(nil);

  FOSK.LoadLayout(gLayoutManager.ActiveLayout);
  FOSK.Show;
end;

procedure TfrmTray.PopupMenuPopup(Sender: TObject);
begin
  // Rebuild the menu each time to reflect the currently active layout.
  BuildLayoutMenu;
  UpdateLayoutHeader;
end;

{ --------------------------------------------------
  UI Helpers
-------------------------------------------------- }

procedure TfrmTray.UpdateTrayIcon;
begin
  // Force Windows to refresh tray icon by toggling visibility.
  TrayIcon.Visible := False;

  if EngineEnabled then
  begin
    ilTrayIcons.GetIcon(0, TrayIcon.Icon);
    TrayIcon.Hint := 'Vittix Indic Keyboard (Enabled)';
  end
  else
  begin
    ilTrayIcons.GetIcon(1, TrayIcon.Icon);
    TrayIcon.Hint := 'Vittix Indic Keyboard (Disabled)';
  end;

  TrayIcon.Visible := True;
end;

{ --------------------------------------------------
  Layout menu
-------------------------------------------------- }

procedure TfrmTray.BuildLayoutMenu;
var
  GroupMenus: TDictionary<string, TMenuItem>;
  Layout: TKeyboardLayout;
  GroupItem, Item: TMenuItem;
  I: Integer;
  GroupName: string;
begin
  miLayouts.Clear;
  GroupMenus := TDictionary<string, TMenuItem>.Create;
  try
    for I := 0 to gLayoutManager.LayoutCount - 1 do
    begin
      Layout := gLayoutManager.GetLayout(I);

      // IMPORTANT: Ensure group name is never empty to prevent silent failures.
      GroupName := Trim(Layout.Group);
      if GroupName = '' then
        GroupName := 'OTHER';

      // Create group menu if needed
      if not GroupMenus.TryGetValue(GroupName, GroupItem) then
      begin
        GroupItem := TMenuItem.Create(miLayouts);
        GroupItem.Caption := GroupName;
        miLayouts.Add(GroupItem);
        GroupMenus.Add(GroupName, GroupItem);
      end;

      // Create layout item
      Item := TMenuItem.Create(GroupItem);
      Item.Caption := Layout.Name;
      Item.RadioItem := True;
      Item.Checked := Layout = gLayoutManager.ActiveLayout;
      Item.Tag := I;
      Item.OnClick := LayoutItemClick;

      GroupItem.Add(Item);
    end;
  finally
    GroupMenus.Free;
  end;
end;

procedure TfrmTray.LayoutItemClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := TMenuItem(Sender).Tag;

  // 1. Update the layout manager with the user's selection.
  gLayoutManager.SetActiveLayout(Index);

  // 2. Update the core typing engine to use the new layout.
  SetActiveLayout(gLayoutManager.ActiveLayout);

  // 3. Reset any intermediate state in the engine.
  ResetEngineState;

  // 4. Persist the user's choice for the next application start.
  if Assigned(gLayoutManager.ActiveLayout) then
    GAppSettings.SaveDefaultLayoutID(gLayoutManager.ActiveLayout.LayoutID);

  // 5. Update the UI to reflect the change.
  UpdateLayoutHeader;
  BuildLayoutMenu;
end;

procedure TfrmTray.UpdateLayoutHeader;
var
  L: TKeyboardLayout;
begin
  L := gLayoutManager.ActiveLayout;

  if Assigned(L) then
  begin
    miLayoutGroupHeader.Caption := UpperCase(L.Group);
    miLayoutNameHeader.Caption  := L.Name;

    // Make layout name visually strong
    miLayoutNameHeader.Default := True; // bold effect in menus
  end
  else
  begin
    miLayoutGroupHeader.Caption := 'NO LAYOUT';
    miLayoutNameHeader.Caption  := '';
    miLayoutNameHeader.Default := False;
  end;
end;

end.
