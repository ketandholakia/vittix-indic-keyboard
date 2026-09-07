unit frmTray;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.ShellAPI,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.ImgList,
  Winapi.ShlObj,
   
  Vcl.Menus,
  Vcl.ExtCtrls,

  EngineState,
  KeyboardHook,
  ShreeLipi.Engine,

  LayoutManager,
  AppSettings,
  LayoutModel,
  frmSettings,
  WinStartup,
  Logger,

  frmOnScreenKeyboard,
  SendInputHelper,
  System.ImageList;

type
  TfrmTray = class(TForm)
    TrayIcon: TTrayIcon;

    PopupMenu: TPopupMenu;

    miEnable: TMenuItem;
    miSep1: TMenuItem;
    miLayouts: TMenuItem;
    miOnScreen: TMenuItem;
    miLayoutEditor: TMenuItem;
    miAppWhitelist: TMenuItem;
    miSettings: TMenuItem;
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
    procedure miLayoutEditorClick(Sender: TObject);
    procedure miAppWhitelistClick(Sender: TObject);
    procedure miSettingsClick(Sender: TObject);
    procedure PopupMenuPopup(Sender: TObject);

  private
    FOSK: TfrmOnScreenKeyboard;

    procedure HandleRawKey(const AChar: string);

    procedure BuildLayoutMenu;
    procedure BuildAppWhitelistMenu;
    procedure UpdateLayoutHeader;
    procedure LayoutItemClick(Sender: TObject);
    procedure UpdateTrayIcon;
    procedure OpenSettings(Sender: TObject);
    procedure RegisterConfiguredHotkeys;
    procedure UnregisterConfiguredHotkeys;
    procedure ApplyRuntimeSettings(const Settings: TKeyboardAppSettingsData);
    function CaptureCurrentSettings: TKeyboardAppSettingsData;
    procedure PopulateLayoutChoices(LayoutNames, LayoutIDs: TStrings);
    procedure LaunchLayoutEditor;
    procedure ToggleAppWhitelistItem(Sender: TObject);
  protected
    procedure WMHotKey(var Msg: TWMHotKey); message WM_HOTKEY;
  end;

var
  gFrmTray: TfrmTray;

implementation

{$R *.dfm}

const
  HOTKEY_ID_TOGGLE = 1; // ID for the global hotkey to toggle the engine
  HOTKEY_ID_ACTION = 2;
  APP_RUN_NAME = 'Vittix Indic Keyboard';
  APP_WHITELIST_ITEM_BASE = 200;
  APP_CANDIDATES: array[0..3] of string = (
    'CorelDRW.exe',
    'Adobe Illustrator.exe',
    'WinWord.exe',
    'notepad.exe'
  );

{ --------------------------------------------------
  Keyboard handlers (FIX for E2009)
-------------------------------------------------- }

procedure TfrmTray.HandleRawKey(const AChar: string);
begin
  ProcessKeyChar(AChar);
end;

{ --------------------------------------------------
  Form lifecycle
-------------------------------------------------- }

procedure TfrmTray.FormCreate(Sender: TObject);
begin
  Application.Title := 'Vittix Indic Keyboard';

  Visible := False;
  BorderStyle := bsNone;

  // Ensure the Settings menu option is visible, labeled, and hooked up correctly
  miSettings.Caption := '&Settings...';
  miSettings.Visible := True;
  miSettings.Enabled := True;
  miSettings.OnClick := miSettingsClick;

  SetWindowLong(
    Handle,
    GWL_EXSTYLE,
    GetWindowLong(Handle, GWL_EXSTYLE) or WS_EX_TOOLWINDOW
  );

  var LocalAppDataPath: array[0..MAX_PATH] of Char;
  var LogDir: string;
  if SHGetFolderPath(0, CSIDL_LOCAL_APPDATA, 0, 0, LocalAppDataPath) = S_OK then
    LogDir := TPath.Combine(string(LocalAppDataPath), 'Vittix\Logs')
  else
    LogDir := TPath.Combine(ExtractFilePath(Application.ExeName), 'logs');

  InitLogger(TPath.Combine(LogDir, 'vittix-keyboard.log'));
  EnableLogger(True);
  LogInfo('Tray form starting');

  // 🔴 REQUIRED: initialize engine
  InitEngineState;
  SetEngineEnabled(GAppSettings.EnableKeyboard);
  miEnable.Checked := EngineEnabled;

  UpdateTrayIcon;

  // 🔴 REQUIRED: keyboard pipeline
  SetKeyHandler(HandleRawKey);
  SetTargetProcessName(GAppSettings.TargetProcessName);
  SetAllowedProcessNames(GAppSettings.AllowedProcessesText);
  if Trim(GAppSettings.AllowedProcessesText) = '' then
    MessageBox(
      Handle,
      'No allowed apps are configured. Interception will stay disabled except for the primary target process.',
      'Vittix Indic Keyboard',
      MB_ICONWARNING or MB_OK
    );
  // Load layouts
  gLayoutManager.Initialize(GAppSettings.LayoutsPath);

  // Notify user if some layouts failed to load. Show only a bounded preview so
  // a directory with many invalid files cannot produce an unusable dialog; the
  // full set is available in the application log.
  if gLayoutManager.LoadErrors.Count > 0 then
  begin
    var LoadSuccessCount := gLayoutManager.LayoutCount;
    var ErrorMsg: string;
    var ShownErrors: Integer;
    ErrorMsg := Format('Warning: %d layout(s) failed to load:%s',
      [gLayoutManager.LoadErrors.Count, sLineBreak]);
    ShownErrors := gLayoutManager.LoadErrors.Count;
    if ShownErrors > 5 then
      ShownErrors := 5;
    for var I := 0 to ShownErrors - 1 do
      ErrorMsg := ErrorMsg + '  - ' + gLayoutManager.LoadErrors[I] + sLineBreak;
    if gLayoutManager.LoadErrors.Count > ShownErrors then
      ErrorMsg := ErrorMsg + Format('  ... and %d more (see the application log).%s',
        [gLayoutManager.LoadErrors.Count - ShownErrors, sLineBreak]);
    ErrorMsg := ErrorMsg + Format('%s layouts loaded successfully.',
      [LoadSuccessCount]);
    MessageBox(Handle, PChar(ErrorMsg), 'Layout Load Warnings',
      MB_ICONWARNING or MB_OK);
  end;

  if GAppSettings.DefaultLayoutID <> '' then
    gLayoutManager.SetActiveLayoutByID(GAppSettings.DefaultLayoutID);

  if gLayoutManager.ActiveLayout <> nil then
  begin
    SetActiveLayout(gLayoutManager.ActiveLayout);
    UpdateLayoutHeader;
  end;

  BuildLayoutMenu;

  InstallKeyboardHook;

  RegisterConfiguredHotkeys;

  TrayIcon.Visible := True;
end;


procedure TfrmTray.FormDestroy(Sender: TObject);
begin
  UnregisterConfiguredHotkeys;
  FreeAndNil(FOSK);
  RemoveKeyboardHook;
  LogInfo('Tray form shutting down');
end;

{ --------------------------------------------------
  Windows Messages
-------------------------------------------------- }

procedure TfrmTray.WMHotKey(var Msg: TWMHotKey);
begin
  if Msg.HotKey = HOTKEY_ID_TOGGLE then
  begin
    miEnableClick(nil); // Reuse the menu click logic to toggle the engine
  end
  else if Msg.HotKey = HOTKEY_ID_ACTION then
  begin
    // Special action hotkey pressed
    MessageBox(Handle, 'Special action hotkey triggered!', 'Vittix Indic Keyboard', MB_OK or MB_ICONINFORMATION);
    // TODO: Implement custom action here
  end;
end;

{ --------------------------------------------------
  Tray menu handlers
-------------------------------------------------- }

procedure TfrmTray.miEnableClick(Sender: TObject);
begin
  SetEngineEnabled(not EngineEnabled);
  // If injection was failing (e.g. targeting an elevated app), re-enabling the
  // engine gives it a fresh chance instead of staying stuck in fail-open.
  ResetInjectionStatus;
  miEnable.Checked := EngineEnabled;
  GAppSettings.EnableKeyboard := EngineEnabled;
  GAppSettings.Save;
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

procedure TfrmTray.miLayoutEditorClick(Sender: TObject);
begin
  LaunchLayoutEditor;
end;

procedure TfrmTray.miAppWhitelistClick(Sender: TObject);
begin
  ToggleAppWhitelistItem(Sender);
end;

procedure TfrmTray.miSettingsClick(Sender: TObject);
begin
  OpenSettings(Sender);
end;

procedure TfrmTray.PopupMenuPopup(Sender: TObject);
begin
  // Rebuild the menu each time to reflect the currently active layout.
  BuildLayoutMenu;
  BuildAppWhitelistMenu;
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

procedure TfrmTray.BuildAppWhitelistMenu;
var
  I: Integer;
  Item: TMenuItem;
  Allowed: string;
  CustomList: TStringList;
  CustomApp: string;
  TagCounter: Integer;
begin
  while miAppWhitelist.Count > 0 do
    miAppWhitelist.Delete(0);
  Allowed := ',' + LowerCase(GAppSettings.AllowedProcessesText) + ',';

  TagCounter := APP_WHITELIST_ITEM_BASE;
  for I := Low(APP_CANDIDATES) to High(APP_CANDIDATES) do
  begin
    Item := TMenuItem.Create(miAppWhitelist);
    Item.Caption := APP_CANDIDATES[I];
    Item.AutoCheck := False;
    Item.Checked := Pos(',' + LowerCase(APP_CANDIDATES[I]) + ',', Allowed) > 0;
    Item.Tag := TagCounter;
    Inc(TagCounter);
    Item.OnClick := miAppWhitelistClick;
    miAppWhitelist.Add(Item);
  end;

  CustomList := TStringList.Create;
  try
    CustomList.StrictDelimiter := True;
    CustomList.Delimiter := ',';
    CustomList.DelimitedText := StringReplace(
      StringReplace(GAppSettings.AllowedProcessesText, sLineBreak, ',', [rfReplaceAll]),
      ';', ',', [rfReplaceAll]
    );

    for I := 0 to CustomList.Count - 1 do
    begin
      CustomApp := Trim(CustomList[I]);
      if CustomApp = '' then Continue;

      // If it's not already in APP_CANDIDATES, add it
      var Found := False;
      for var J := Low(APP_CANDIDATES) to High(APP_CANDIDATES) do
      begin
        if SameText(CustomApp, APP_CANDIDATES[J]) then
        begin
          Found := True;
          Break;
        end;
      end;

      if not Found then
      begin
        Item := TMenuItem.Create(miAppWhitelist);
        Item.Caption := CustomApp;
        Item.AutoCheck := False;
        Item.Checked := True; // Custom items in this list are always checked because they are in the allowed text
        Item.Tag := TagCounter;
        Inc(TagCounter);
        Item.OnClick := miAppWhitelistClick;
        miAppWhitelist.Add(Item);
      end;
    end;
  finally
    CustomList.Free;
  end;
end;

procedure TfrmTray.LaunchLayoutEditor;
var
  EditorPath: string;
  LayoutFileName: string;
  LaunchResult: HINST;
begin
  EditorPath := TPath.Combine(
    ExtractFilePath(Application.ExeName),
    'VittixIndicEditor.exe'
  );

  if not FileExists(EditorPath) then
  begin
    MessageBox(
      Handle,
      PChar('Layout editor was not found:'#13#10 + EditorPath),
      'Vittix Indic Keyboard',
      MB_ICONERROR or MB_OK
    );
    Exit;
  end;

  if not Assigned(gLayoutManager.ActiveLayout) then
  begin
    MessageBox(
      Handle,
      'No active layout is selected.',
      'Vittix Indic Keyboard',
      MB_ICONERROR or MB_OK
    );
    Exit;
  end;

  LayoutFileName := Trim(gLayoutManager.ActiveLayout.SourceFileName);
  if (LayoutFileName = '') or (not FileExists(LayoutFileName)) then
  begin
    MessageBox(
      Handle,
      PChar('Source file for the selected layout was not found.'),
      'Vittix Indic Keyboard',
      MB_ICONERROR or MB_OK
    );
    Exit;
  end;

  LaunchResult := ShellExecute(
    Handle,
    'open',
    PChar(EditorPath),
    PChar('"' + LayoutFileName + '"'),
    PChar(ExtractFilePath(EditorPath)),
    SW_SHOWNORMAL
  );

  if LaunchResult <= 32 then
    MessageBox(
      Handle,
      PChar('Layout editor could not be started:'#13#10 + EditorPath),
      'Vittix Indic Keyboard',
      MB_ICONERROR or MB_OK
    );
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

  // 3. Reset any intermediate state in the engine and injection failures.
  ResetEngineState;
  ResetInjectionStatus;

  // 4. Persist the user's choice for the next application start.
  if Assigned(gLayoutManager.ActiveLayout) then
    GAppSettings.SaveDefaultLayoutID(gLayoutManager.ActiveLayout.LayoutID);

  // 5. Update the UI to reflect the change.
  UpdateLayoutHeader;
  BuildLayoutMenu;
end;

procedure TfrmTray.OpenSettings(Sender: TObject);
var
  CurrentSettings: TKeyboardAppSettingsData;
  PreviousSettings: TKeyboardAppSettingsData;
  LayoutNames: TStringList;
  LayoutIDs: TStringList;
begin
  CurrentSettings := CaptureCurrentSettings;
  PreviousSettings := CurrentSettings;

  LayoutNames := TStringList.Create;
  LayoutIDs := TStringList.Create;
  try
    PopulateLayoutChoices(LayoutNames, LayoutIDs);
    if not TfrmSettings.Execute(CurrentSettings, LayoutNames, LayoutIDs) then
      Exit;

    try
      ApplyRuntimeSettings(CurrentSettings);
    except
      on E: Exception do
      begin
        ApplyRuntimeSettings(PreviousSettings);
        MessageBox(
          Handle,
          PChar('Settings could not be applied:'#13#10 + E.Message),
          'Vittix Indic Keyboard',
          MB_ICONERROR or MB_OK
        );
      end;
    end;
  finally
    LayoutIDs.Free;
    LayoutNames.Free;
  end;
end;

function TfrmTray.CaptureCurrentSettings: TKeyboardAppSettingsData;
begin
  Result.EnableKeyboard := GAppSettings.EnableKeyboard;
  Result.StartWithWindows := GAppSettings.StartWithWindows;
  Result.LayoutsPath := GAppSettings.LayoutsPath;
  Result.DefaultLayoutID := GAppSettings.DefaultLayoutID;
  Result.TargetProcessName := GAppSettings.TargetProcessName;
  Result.AllowedProcessesText := GAppSettings.AllowedProcessesText;
  Result.ToggleHotkeyText := GAppSettings.ToggleHotkeyText;
  Result.ActionHotkeyText := GAppSettings.ActionHotkeyText;
  Result.FallbackFont := GAppSettings.FallbackFont;
  Result.PreviewFontSize := GAppSettings.PreviewFontSize;
end;

procedure TfrmTray.PopulateLayoutChoices(LayoutNames, LayoutIDs: TStrings);
var
  I: Integer;
  Layout: TKeyboardLayout;
begin
  LayoutNames.Clear;
  LayoutIDs.Clear;
  for I := 0 to gLayoutManager.LayoutCount - 1 do
  begin
    Layout := gLayoutManager.GetLayout(I);
    LayoutNames.Add(Format('%s [%s]', [Layout.Name, Layout.Group]));
    LayoutIDs.Add(Layout.LayoutID);
  end;
end;

procedure TfrmTray.UnregisterConfiguredHotkeys;
begin
  UnregisterHotKey(Handle, HOTKEY_ID_TOGGLE);
  UnregisterHotKey(Handle, HOTKEY_ID_ACTION);
end;

procedure TfrmTray.RegisterConfiguredHotkeys;
var
  Mods: UINT;
  VK: UINT;
  ActionHotkey: string;
  ToggleHotkey: string;
begin
  UnregisterConfiguredHotkeys;

  ToggleHotkey := Trim(GAppSettings.GetToggleHotkeyText);
  if ToggleHotkey <> '' then
  begin
    if not GAppSettings.ParseHotkey(ToggleHotkey, Mods, VK) then
      MessageBox(
        Handle,
        PChar('Invalid hotkey configuration: ' + ToggleHotkey),
        'Vittix Indic Keyboard',
        MB_ICONWARNING or MB_OK
      )
    else if not RegisterHotKey(Handle, HOTKEY_ID_TOGGLE, Mods or MOD_NOREPEAT, VK) then
      MessageBox(
        Handle,
        PChar('Hotkey already in use: ' + ToggleHotkey),
        'Vittix Indic Keyboard',
        MB_ICONWARNING or MB_OK
      );
  end;

  ActionHotkey := Trim(GAppSettings.ActionHotkeyText);
  if (ActionHotkey = '') and Assigned(gLayoutManager.ActiveLayout) then
    gLayoutManager.ActiveLayout.Properties.TryGetValue('HotkeyAction', ActionHotkey);

  if ActionHotkey <> '' then
  begin
    if not GAppSettings.ParseHotkey(ActionHotkey, Mods, VK) then
      MessageBox(
        Handle,
        PChar('Invalid hotkey configuration: ' + ActionHotkey),
        'Vittix Indic Keyboard',
        MB_ICONWARNING or MB_OK
      )
    else if not RegisterHotKey(Handle, HOTKEY_ID_ACTION, Mods or MOD_NOREPEAT, VK) then
      MessageBox(
        Handle,
        PChar('Action hotkey already in use: ' + ActionHotkey),
        'Vittix Indic Keyboard',
        MB_ICONWARNING or MB_OK
      );
  end;

  miEnable.Caption := 'Enable Keyboard (' + GAppSettings.GetToggleHotkeyText + ')';
end;

procedure TfrmTray.ApplyRuntimeSettings(const Settings: TKeyboardAppSettingsData);
begin
  if Trim(Settings.LayoutsPath) = '' then
    raise Exception.Create('Layouts path cannot be empty.');

  if not DirectoryExists(Settings.LayoutsPath) then
    raise Exception.Create('Layouts folder not found: ' + Settings.LayoutsPath);

  GAppSettings.EnableKeyboard := Settings.EnableKeyboard;
  GAppSettings.StartWithWindows := Settings.StartWithWindows;
  GAppSettings.LayoutsPath := IncludeTrailingPathDelimiter(Settings.LayoutsPath);
  GAppSettings.DefaultLayoutID := Settings.DefaultLayoutID;
  GAppSettings.TargetProcessName := Trim(Settings.TargetProcessName);
  GAppSettings.AllowedProcessesText := Trim(Settings.AllowedProcessesText);
  GAppSettings.ToggleHotkeyText := Settings.ToggleHotkeyText;
  GAppSettings.ActionHotkeyText := Settings.ActionHotkeyText;
  GAppSettings.FallbackFont := Settings.FallbackFont;
  GAppSettings.PreviewFontSize := Settings.PreviewFontSize;

  gLayoutManager.Initialize(GAppSettings.LayoutsPath);
  if GAppSettings.DefaultLayoutID <> '' then
    gLayoutManager.SetActiveLayoutByID(GAppSettings.DefaultLayoutID);

  if gLayoutManager.ActiveLayout = nil then
    raise Exception.Create('No layout could be activated with the current settings.');

  SetActiveLayout(gLayoutManager.ActiveLayout);
  ResetEngineState;
  ResetInjectionStatus;

  SetEngineEnabled(GAppSettings.EnableKeyboard);
  miEnable.Checked := EngineEnabled;
  SetTargetProcessName(GAppSettings.TargetProcessName);
  SetAllowedProcessNames(GAppSettings.AllowedProcessesText);
  UpdateTrayIcon;

  if GAppSettings.StartWithWindows then
    EnableStartup(APP_RUN_NAME, Application.ExeName)
  else
    DisableStartup(APP_RUN_NAME);

  GAppSettings.Save;
  RegisterConfiguredHotkeys;
  UpdateLayoutHeader;
  BuildLayoutMenu;
end;

procedure TfrmTray.ToggleAppWhitelistItem(Sender: TObject);
var
  Item: TMenuItem;
  ProcessList: TStringList;
  Value: string;
  Existing: Integer;
begin
  if not (Sender is TMenuItem) then
    Exit;

  Item := TMenuItem(Sender);
  Value := Item.Caption;

  ProcessList := TStringList.Create;
  try
    ProcessList.StrictDelimiter := True;
    ProcessList.Delimiter := ',';
    ProcessList.DelimitedText := StringReplace(
      StringReplace(GAppSettings.AllowedProcessesText, sLineBreak, ',', [rfReplaceAll]),
      ';', ',', [rfReplaceAll]
    );

    Existing := ProcessList.IndexOf(Value);
    if Existing >= 0 then
      ProcessList.Delete(Existing)
    else
      ProcessList.Add(Value);

    GAppSettings.AllowedProcessesText := Trim(StringReplace(ProcessList.DelimitedText, ',', sLineBreak, [rfReplaceAll]));
    if Trim(GAppSettings.AllowedProcessesText) = '' then
      MessageBox(
        Handle,
        'You are saving an empty allowed-app list. Interception will be disabled for all apps except the primary target process.',
        'Vittix Indic Keyboard',
        MB_ICONWARNING or MB_OK
      );
    SetAllowedProcessNames(GAppSettings.AllowedProcessesText);
    GAppSettings.Save;
    BuildAppWhitelistMenu;
  finally
    ProcessList.Free;
  end;
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
