unit frmTray;

interface

uses
  Winapi.Windows,
  Winapi.WTSApi32,
  Winapi.Messages,
  Winapi.ShellAPI,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.Dialogs,
  Vcl.ImgList,
  Winapi.ShlObj,
   
  Vcl.Menus,
  Vcl.ExtCtrls,

  EngineState,
  KeyboardHook,
  ShreeLipi.Engine,

  LayoutManager,
  LayoutReload,
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
    miOpenLayoutsFolder: TMenuItem;
    miReloadLayouts: TMenuItem;
    miOpenLogFolder: TMenuItem;
    miAbout: TMenuItem;
    miSep2: TMenuItem;
    miSep3: TMenuItem;
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

    // Collected during startup and delivered as one balloon once the icon is
    // visible, instead of a stack of modal boxes before the app appears.
    FStartupNotices: TStringList;

    // One icon per engine state, loaded once at the size the notification area
    // asks for. Assigning one of these to TrayIcon.Icon is what tells the shell
    // to repaint; mutating TrayIcon.Icon.Handle does not.
    FIconEnabled: TIcon;
    FIconDisabled: TIcon;

    // Where the log lives, captured when the logger is initialised.
    FLogDir: string;

    // Item (injection latch): True while the SendInput-failure latch is
    // tripped (e.g. the user typed into an elevated app). Drives the alternate
    // tray icon state (blocked shows the "off" frame while the engine stays
    // enabled) and a hint suffix. The balloon itself comes from the
    // injection-status callback, which fires once per latch trip.
    FInjectionBlocked: Boolean;

    // Item 3a (watchdog): periodic liveness check of the LL keyboard hook.
    // Windows silently removes hooks whose callback exceeds its timeout, so a
    // UI stall can kill system-wide typing; this timer re-installs.
    FHookWatchdog: TTimer;

    // The layout and allowed-app submenus are destroyed and rebuilt item by item.
    // Doing that on every popup is a visible hitch with a large layout set, so
    // they are rebuilt only when something they show has actually changed.
    FMenusDirty: Boolean;
    procedure InvalidateTrayMenus;

    procedure HookWatchdogTick(Sender: TObject);
    function HandleRawKey(const AChar: string): TInjectionOutcome;
    // Item (injection latch): SendInputHelper's status callback. Fires on
    // transitions only, so the balloon is rate-limited to once per latch trip.
    procedure TrayInjectionStatusChanged(AHealthy: Boolean);
    function TrayHint: string;
    procedure AddAllowedApplication;
    procedure AddStartupNotice(const Msg: string);
    procedure FlushStartupNotices;
    procedure Notify(const Msg: string);
    procedure LoadTrayIconFrames;

    procedure OpenFolder(const Path: string);
    procedure OpenLayoutsFolderClick(Sender: TObject);
    procedure ReloadLayoutsClick(Sender: TObject);
    procedure OpenLogFolderClick(Sender: TObject);
    procedure AboutClick(Sender: TObject);
    function ApplicationVersion: string;

    procedure BuildLayoutMenu;
    procedure BuildAppWhitelistMenu;
    procedure UpdateLayoutHeader;
    procedure LayoutItemClick(Sender: TObject);
    // C.2: shared switch logic (menu click and the cycle hotkey both land
    // here) and the hotkey-driven next-layout cycle.
    procedure SwitchToLayoutIndex(Index: Integer);
    procedure CycleToNextLayout;
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
    // Item 3a (watchdog): session unlock and resume-from-sleep can leave the
    // LL keyboard hook silently dead; both transitions restart it.
    procedure WMWtsSessionChange(var Msg: TMessage); message WM_WTSSESSION_CHANGE;
    procedure WMPowerBroadcast(var Msg: TMessage); message WM_POWERBROADCAST;
  end;

var
  gFrmTray: TfrmTray;

implementation

{$R *.dfm}

// Multi-size tray icon frames (16/20/24/32/48), one resource per engine state.
// Generated by tmp/make_icons.py from Keyboard/Resources/vikgreen.png.
{$R '..\Resources\vikicons.res'}

const
  HOTKEY_ID_TOGGLE = 1; // ID for the global hotkey to toggle the engine
  // Item 8c: HOTKEY_ID_ACTION (2) removed with the action hotkey itself.
  HOTKEY_ID_CYCLE = 3;  // C.2: global hotkey that cycles to the next layout
  APP_RUN_NAME = 'Vittix Indic Keyboard';
  APP_WHITELIST_ITEM_BASE = 200;
  // Sentinel tags for the two whitelist actions that are not process toggles.
  APP_WHITELIST_ACTION_ADD = -1;
  APP_WHITELIST_ACTION_EDIT = -2;
  MAX_BALLOON_CHARS = 240;
  ICON_RESOURCE_ON = 'VIK_ICON_ON';
  ICON_RESOURCE_OFF = 'VIK_ICON_OFF';
  APP_CANDIDATES: array[0..3] of string = (
    'CorelDRW.exe',
    'Adobe Illustrator.exe',
    'WinWord.exe',
    'notepad.exe'
  );

{ --------------------------------------------------
  Keyboard handlers (FIX for E2009)
-------------------------------------------------- }

function TfrmTray.HandleRawKey(const AChar: string): TInjectionOutcome;
begin
  Result := ProcessKeyChar(AChar);
end;

{ --------------------------------------------------
  Form lifecycle
-------------------------------------------------- }

procedure TfrmTray.FormCreate(Sender: TObject);
var
  ResolvedLayoutsPath: string;
begin
  Application.Title := 'Vittix Indic Keyboard';

  FStartupNotices := TStringList.Create;

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

  // Double-clicking the tray icon is the fastest path to the primary action.
  TrayIcon.OnDblClick := miEnableClick;

  var LocalAppDataPath: array[0..MAX_PATH] of Char;
  var LogDir: string;
  if SHGetFolderPath(0, CSIDL_LOCAL_APPDATA, 0, 0, LocalAppDataPath) = S_OK then
    LogDir := TPath.Combine(string(LocalAppDataPath), 'Vittix\Logs')
  else
    LogDir := TPath.Combine(ExtractFilePath(Application.ExeName), 'logs');

  // Kept so the tray's "Open log folder" action does not have to recompute it.
  FLogDir := LogDir;

  InitLogger(TPath.Combine(LogDir, 'vittix-keyboard.log'));
  EnableLogger(True);
  LogInfo('Tray form starting');

  // 🔴 REQUIRED: initialize engine
  InitEngineState;
  SetEngineEnabled(GAppSettings.EnableKeyboard);
  miEnable.Checked := EngineEnabled;

  LoadTrayIconFrames;
  UpdateTrayIcon;

  // Built in the DFM, wired here so the handlers can stay private.
  miOpenLayoutsFolder.OnClick := OpenLayoutsFolderClick;
  miReloadLayouts.OnClick := ReloadLayoutsClick;
  miOpenLogFolder.OnClick := OpenLogFolderClick;
  miAbout.OnClick := AboutClick;

  // Build the menus once up front so a malformed whitelist is logged at startup
  // rather than discovered on the first right-click.
  BuildLayoutMenu;
  BuildAppWhitelistMenu;
  FMenusDirty := False;

  // Review fix (issue 6) follow-up: resolve the layouts folder BEFORE the
  // startup log, so the logged `layouts=` path reflects the folder actually
  // used. An installed copy under Program Files cannot write to its
  // exe-relative layouts folder, so resolution lands on the per-user copy
  // created and seeded on first run. When the resolution changed the path
  // (first run), persist it immediately so settings.ini records the writable
  // per-user folder without waiting for the user to open Settings. FormCreate
  // runs only in the production app, so this Save never touches the test
  // sandbox; TAppSettings tests construct their own instances with explicit
  // paths and are unaffected.
  ResolvedLayoutsPath := ResolveLayoutsPath(GAppSettings.LayoutsPath);
  if not SameText(ExcludeTrailingPathDelimiter(ResolvedLayoutsPath),
    ExcludeTrailingPathDelimiter(GAppSettings.LayoutsPath)) then
  begin
    GAppSettings.LayoutsPath := ResolvedLayoutsPath;
    GAppSettings.Save;
  end;

  // Item (shipped layout updates): reconcile the per-user seeded copy with
  // the shipped layouts BEFORE the engine loads them, so fixed glyphs reach
  // existing users. User-modified files are left untouched and reported in
  // the log; every applied update is announced once via the startup balloon.
  var SeedLogLines := TStringList.Create;
  try
    ReconcileSeededLayouts(ResolvedLayoutsPath, ApplicationVersion, SeedLogLines);
    for var I := 0 to SeedLogLines.Count - 1 do
      LogInfo('Seed reconcile: ' + SeedLogLines[I]);

    var UpdatedCount := 0;
    for var I := 0 to SeedLogLines.Count - 1 do
      if SeedLogLines[I].StartsWith('info: updated') then
        Inc(UpdatedCount);
    if UpdatedCount > 0 then
      AddStartupNotice(Format('%d seeded layout file(s) were updated to the '
        + 'shipped version; files you edited were left untouched (details in the log).',
        [UpdatedCount]));
  finally
    SeedLogLines.Free;
  end;

  // Confirms the support actions have what they need without waiting for a click.
  LogInfo(Format('Support actions ready: version=%s layouts=%s logs=%s',
    [ApplicationVersion, GAppSettings.LayoutsPath, FLogDir]));

  // 🔴 REQUIRED: keyboard pipeline
  // Item (injection latch): the tray reacts to the SendInput status so a UIPI
  // block is announced once and the icon reflects the blocked state until the
  // latch re-arms (foreground change, toggle, layout switch, settings apply).
  SetInjectionStatusCallback(TrayInjectionStatusChanged);
  SetKeyHandler(HandleRawKey);
  SetTargetProcessName(GAppSettings.TargetProcessName);
  SetAllowedProcessNames(GAppSettings.AllowedProcessesText);
  // QW3 review fix: the persisted injected-input filter must reach the hook
  // at STARTUP too — ApplyRuntimeSettings was the only caller, so a user who
  // unchecked "ignore injected keystrokes" silently got the default (True)
  // until the first Settings-OK.
  SetIgnoreInjectedInput(GAppSettings.IgnoreInjectedInput);
  // Item 8d: with the neutral defaults (no target, no allowed apps), the
  // first-run notice must teach HOW to enable interception, not just that it
  // is off.
  if (Trim(GAppSettings.AllowedProcessesText) = '') and
     (Trim(GAppSettings.TargetProcessName) = '') then
    AddStartupNotice('No target app is configured yet, so keystrokes are not '
      + 'translated anywhere. Right-click the tray icon and use "Allowed apps '
      + '> Add application...", or open Settings to set a primary app process '
      + 'and an allowed-apps list.')
  else if Trim(GAppSettings.AllowedProcessesText) = '' then
    AddStartupNotice('No allowed apps are configured. Interception stays disabled except for the primary target process.');
  // Load layouts from the resolved folder (see above).

  // Detach the engine first (no-op at startup, but kept symmetric
  // with the reload paths) and guard the load: a failed load must degrade to
  // "no layouts" (hook fails open) instead of an unhandled exception in
  // FormCreate.
  SetActiveLayout(nil);
  try
    gLayoutManager.Initialize(GAppSettings.LayoutsPath);
  except
    on E: Exception do
      AddStartupNotice('Layouts could not be loaded: ' + E.Message);
  end;

  // Notify user if some layouts failed to load. Show only a bounded preview so
  // a directory with many invalid files cannot produce an unusable dialog; the
  // full set is available in the application log.
  if gLayoutManager.LoadErrors.Count > 0 then
  begin
    var LoadSuccessCount := gLayoutManager.LayoutCount;
    var ErrorMsg: string;
    var ShownErrors: Integer;
    ErrorMsg := Format('%d layout(s) failed to load:%s',
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
    AddStartupNotice(ErrorMsg);
  end;

  if GAppSettings.DefaultLayoutID <> '' then
    gLayoutManager.SetActiveLayoutByID(GAppSettings.DefaultLayoutID);

  if gLayoutManager.ActiveLayout <> nil then
  begin
    SetActiveLayout(gLayoutManager.ActiveLayout);
    UpdateLayoutHeader;
  end;

  BuildLayoutMenu;

  // Review fix (issue 8): a hook installation failure (another LL hook
  // refusing us, security software, desktop-less session) must not escape
  // FormCreate and kill the startup. Degrade to "not translating" — the
  // engine is fail-open anyway — and tell the user via the startup balloon,
  // exactly like the layout-load guard above.
  try
    InstallKeyboardHook;
  except
    on E: Exception do
    begin
      LogError('Keyboard hook installation failed: ' + E.Message);
      AddStartupNotice('Keyboard hook could not be installed; keystrokes will not be translated.');
    end;
  end;

  RegisterConfiguredHotkeys;

  // Item 3a (watchdog): every 30 s verify the LL hook is still installed AND
  // alive (heartbeat vs system input), re-install when it is not. Created in
  // code so the DFM stays untouched.
  FHookWatchdog := TTimer.Create(Self);
  FHookWatchdog.Interval := 30000;
  FHookWatchdog.OnTimer := HookWatchdogTick;
  FHookWatchdog.Enabled := True;

  // Item 3a: session unlock re-arms the hook. Only registered so the WTS
  // message arrives; failures are non-fatal (the watchdog still runs).
  if not WTSRegisterSessionNotification(Handle, NOTIFY_FOR_THIS_SESSION) then
    LogError('WTS session notification registration failed; unlock will not restart the hook');

  TrayIcon.Visible := True;
  FlushStartupNotices;
end;

{ Item 3a: the watchdog tick. Recover a missing handle or explicitly force
  replacement of a stale nonzero handle:
  1. The hook handle is gone entirely (something unhooked us).
  2. The handle is still set but Windows stopped dispatching to it (the
     classic silent removal after a slow callback) - detected by a stale
     heartbeat while GetLastInputInfo reports input the hook never saw. }
procedure TfrmTray.HookWatchdogTick(Sender: TObject);
var
  NowTick, LastInput: DWORD;
begin
  if not KeyboardHookInstalled then
  begin
    EnsureKeyboardHookInstalled('watchdog: hook handle missing');
    Exit;
  end;

  NowTick := GetTickCount;
  LastInput := LastSystemInputTick;
  // LastSystemInputTick = 0 means GetLastInputInfo failed: unable to judge,
  // so leave the hook alone (fail-open, never thrash re-installs).
  if (LastInput <> 0) and
     HookHeartbeatIsStale(NowTick, HookHeartbeatTick, LastInput) then
    EnsureKeyboardHookInstalled('watchdog: stale heartbeat, input missed', True);
end;

procedure TfrmTray.WMWtsSessionChange(var Msg: TMessage);
begin
  inherited;
  // WTS_SESSION_UNLOCK: the transition out of a locked session is a known
  // point where LL hooks can end up silently dead. Restart unconditionally.
  if Msg.WParam = WTS_SESSION_UNLOCK then
    RestartKeyboardHook;
end;

procedure TfrmTray.WMPowerBroadcast(var Msg: TMessage);
begin
  inherited;
  // Resume from sleep/hibernate: restart the hook rather than trusting it.
  // PBT_APMRESUMEAUTOMATIC fires on every resume; PBT_APMRESUMESUSPEND only
  // when the resume was user-triggered - handling either covers the case.
  if (Msg.WParam = PBT_APMRESUMEAUTOMATIC) or
     (Msg.WParam = PBT_APMRESUMESUSPEND) then
    RestartKeyboardHook;
end;


procedure TfrmTray.AddStartupNotice(const Msg: string);
begin
  if not Assigned(FStartupNotices) then
    Exit;
  if Trim(Msg) <> '' then
    FStartupNotices.Add(Trim(Msg));
end;

procedure TfrmTray.Notify(const Msg: string);
var
  Text: string;
begin
  Text := Trim(Msg);
  if Text = '' then
    Exit;

  if not TrayIcon.Visible then
  begin
    AddStartupNotice(Text);
    Exit;
  end;

  if Length(Text) > MAX_BALLOON_CHARS then
    Text := Copy(Text, 1, MAX_BALLOON_CHARS - 3) + '...';

  TrayIcon.BalloonTitle := 'Vittix Indic Keyboard';
  TrayIcon.BalloonHint := Text;
  TrayIcon.BalloonFlags := bfWarning;
  TrayIcon.ShowBalloonHint;
end;

procedure TfrmTray.FlushStartupNotices;
var
  Combined: string;
  I: Integer;
begin
  if not Assigned(FStartupNotices) or (FStartupNotices.Count = 0) then
    Exit;

  Combined := '';
  for I := 0 to FStartupNotices.Count - 1 do
  begin
    if Combined <> '' then
      Combined := Combined + sLineBreak;
    Combined := Combined + '- ' + FStartupNotices[I];
  end;
  FStartupNotices.Clear;

  Notify(Combined);
end;

function TfrmTray.TrayHint: string;
var
  StateText, LayoutName, Hotkey: string;
begin
  if EngineEnabled then
    StateText := 'Enabled'
  else
    StateText := 'Disabled';

  LayoutName := '';
  if Assigned(gLayoutManager.ActiveLayout) then
    LayoutName := Trim(gLayoutManager.ActiveLayout.Name);

  Hotkey := Trim(GAppSettings.GetToggleHotkeyText);

  Result := 'Vittix Indic Keyboard - ' + StateText;
  if LayoutName <> '' then
    Result := Result + ' - ' + LayoutName;
  if Hotkey <> '' then
    Result := Result + ' - ' + Hotkey;
  // Item (injection latch): the alternate icon state gets a matching hint, so
  // hovering the blocked icon explains why the "enabled" engine looks greyed.
  if FInjectionBlocked then
    Result := Result + ' - Typing blocked in this app';
end;


procedure TfrmTray.TrayInjectionStatusChanged(AHealthy: Boolean);
begin
  if AHealthy then
  begin
    if FInjectionBlocked then
    begin
      FInjectionBlocked := False;
      LogInfo('Injection latch re-armed; typing resumes');
      UpdateTrayIcon;
    end;
    Exit;
  end;

  // Latch trip: exactly one balloon per episode (the callback fires only on
  // the healthy->unhealthy transition, never per failing keystroke).
  FInjectionBlocked := True;
  LogError('Injection latch tripped; keys pass through unchanged');
  Notify('Typing is blocked in this app, probably because it is running as '
    + 'administrator. Keys pass through unchanged.');
  UpdateTrayIcon;
end;

procedure TfrmTray.FormDestroy(Sender: TObject);
begin
  // Item 3a: release the WTS registration before the window handle dies.
  WTSUnRegisterSessionNotification(Handle);
  FreeAndNil(FHookWatchdog);
  SetInjectionStatusCallback(nil);
  UnregisterConfiguredHotkeys;
  FreeAndNil(FOSK);
  FreeAndNil(FIconEnabled);
  FreeAndNil(FIconDisabled);
  RemoveKeyboardHook;
  FreeAndNil(FStartupNotices);
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
  else if Msg.HotKey = HOTKEY_ID_CYCLE then
  begin
    CycleToNextLayout;
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
var
  Item: TMenuItem;
begin
  if not (Sender is TMenuItem) then
    Exit;

  Item := TMenuItem(Sender);
  case Item.Tag of
    APP_WHITELIST_ACTION_ADD: AddAllowedApplication;
    APP_WHITELIST_ACTION_EDIT: OpenSettings(Sender);
  else
    ToggleAppWhitelistItem(Sender);
  end;
end;

procedure TfrmTray.miSettingsClick(Sender: TObject);
begin
  OpenSettings(Sender);
end;

procedure TfrmTray.InvalidateTrayMenus;
begin
  FMenusDirty := True;
end;

procedure TfrmTray.PopupMenuPopup(Sender: TObject);
begin
  // Rebuild only when the layout set, the allowed-app list or the active layout
  // has changed. The cheap per-open state is always refreshed.
  if FMenusDirty then
  begin
    BuildLayoutMenu;
    BuildAppWhitelistMenu;
    FMenusDirty := False;
  end;

  miEnable.Checked := EngineEnabled;
  UpdateLayoutHeader;
  UpdateTrayIcon;
end;

{ --------------------------------------------------
  UI Helpers
-------------------------------------------------- }

procedure TfrmTray.LoadTrayIconFrames;
var
  IconSize: Integer;
  IconHandle: HICON;
begin
  FreeAndNil(FIconEnabled);
  FreeAndNil(FIconDisabled);

  // The notification area asks for the small icon size, so the frame matching
  // that size has to be picked here. TIcon.LoadFromResourceName does not do it:
  // it always returns a 32x32 HICON, which the shell would then downscale into a
  // blurry blob. LoadImage selects the frame that matches the requested size.
  IconSize := GetSystemMetrics(SM_CXSMICON);
  if IconSize <= 0 then
    IconSize := 16;

  IconHandle := LoadImage(HInstance, ICON_RESOURCE_ON, IMAGE_ICON, IconSize, IconSize, 0);
  if IconHandle <> 0 then
  begin
    FIconEnabled := TIcon.Create;
    FIconEnabled.Handle := IconHandle;
  end;

  IconHandle := LoadImage(HInstance, ICON_RESOURCE_OFF, IMAGE_ICON, IconSize, IconSize, 0);
  if IconHandle <> 0 then
  begin
    FIconDisabled := TIcon.Create;
    FIconDisabled.Handle := IconHandle;
  end;

  LogInfo(Format('Tray icons loaded at %dx%d: enabled=%s disabled=%s',
    [IconSize, IconSize, BoolToStr(Assigned(FIconEnabled), True),
     BoolToStr(Assigned(FIconDisabled), True)]));
end;

procedure TfrmTray.UpdateTrayIcon;
begin
  // TCustomTrayIcon.SetIcon copies the icon into its own FCurrentIcon and calls
  // Refresh, and Refresh is what hands FCurrentIcon.Handle to the shell. Writing
  // to TrayIcon.Icon.Handle instead only changed the component's spare copy, so
  // the notification area kept showing whatever it was first given.
  //
  // Item (injection latch): a tripped latch is an alternate icon state. The
  // engine is still "enabled", but keys are passing through unchanged, so the
  // blocked state shows the same greyed frame as a disabled engine; the hint
  // (and the one-time balloon) tell the two situations apart. Re-arming the
  // latch restores the enabled frame.
  if EngineEnabled and (not FInjectionBlocked) and Assigned(FIconEnabled) then
  begin
    TrayIcon.Icon := FIconEnabled;
    LogInfo('Tray icon applied: enabled');
  end
  else if (not EngineEnabled or FInjectionBlocked) and Assigned(FIconDisabled) then
  begin
    if FInjectionBlocked then
      LogInfo('Tray icon applied: blocked (injection latch tripped)')
    else
      LogInfo('Tray icon applied: disabled');
    TrayIcon.Icon := FIconDisabled;
  end
  else
  begin
    // Resource missing (a stale build, for example): fall back to the single
    // size bitmaps rather than showing no icon at all. The temporary TIcon is
    // safe to free because TIcon.Assign shares the image by reference.
    var FallbackIcon := TIcon.Create;
    try
      if EngineEnabled and (not FInjectionBlocked) then
        ilTrayIcons.GetIcon(0, FallbackIcon)
      else
        ilTrayIcons.GetIcon(1, FallbackIcon);
      TrayIcon.Icon := FallbackIcon;
      LogInfo('Tray icon applied: fallback bitmaps (resource unavailable)');
    finally
      FallbackIcon.Free;
    end;
  end;

  TrayIcon.Hint := TrayHint;
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

      // Item (housekeeping): an empty layout (no mappings) types nothing —
      // offering it in the menu would only confuse; the validator warns
      // about it. Skip it here.
      if Layout.HasNoMappings then
        Continue;

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
  Seen: TStringList;
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
    // Without this, Delphi rewrites the caption to insert an accelerator key,
    // and the caption is what ToggleAppWhitelistItem writes back to settings as
    // the process name. That is how entries like "&notepad.exe" appear.
    Item.AutoHotkeys := maManual;
    miAppWhitelist.Add(Item);
  end;

  Seen := TStringList.Create;
  try
    Seen.CaseSensitive := False;
    for I := Low(APP_CANDIDATES) to High(APP_CANDIDATES) do
      Seen.Add(APP_CANDIDATES[I]);

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
        // Older builds persisted the menu accelerator into the name; strip it so
        // the process name that reaches the hook is the real one.
        CustomApp := Trim(StringReplace(CustomList[I], '&', '', [rfReplaceAll]));
        if CustomApp = '' then Continue;
        if Seen.IndexOf(CustomApp) >= 0 then Continue;

        Seen.Add(CustomApp);
        Item := TMenuItem.Create(miAppWhitelist);
        Item.Caption := CustomApp;
        Item.AutoCheck := False;
        Item.AutoHotkeys := maManual;
        Item.Checked := True; // Custom items are in the allowed text by definition
        Item.Tag := TagCounter;
        Inc(TagCounter);
        Item.OnClick := miAppWhitelistClick;
        miAppWhitelist.Add(Item);
      end;
    finally
      CustomList.Free;
    end;
  finally
    Seen.Free;
  end;

  // Actions, kept below a separator so they are never mistaken for an app name.
  Item := TMenuItem.Create(miAppWhitelist);
  Item.Caption := '-';
  miAppWhitelist.Add(Item);

  Item := TMenuItem.Create(miAppWhitelist);
  Item.Caption := 'Add application...';
  Item.AutoHotkeys := maManual;
  Item.Tag := APP_WHITELIST_ACTION_ADD;
  Item.OnClick := miAppWhitelistClick;
  miAppWhitelist.Add(Item);

  Item := TMenuItem.Create(miAppWhitelist);
  Item.Caption := 'Edit allowed list...';
  Item.AutoHotkeys := maManual;
  Item.Tag := APP_WHITELIST_ACTION_EDIT;
  Item.OnClick := miAppWhitelistClick;
  miAppWhitelist.Add(Item);

  LogInfo(Format('Allowed-apps menu built: %d item(s)', [miAppWhitelist.Count]));
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

// C.2: the shared layout-switch steps, used by the tray menu click and the
// cycle hotkey alike.
procedure TfrmTray.SwitchToLayoutIndex(Index: Integer);
begin
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
  InvalidateTrayMenus;

  // 6. The on-screen keyboard shows the active layout, so refresh it if open.
  if Assigned(FOSK) then
    FOSK.LoadLayout(gLayoutManager.ActiveLayout);
end;

procedure TfrmTray.LayoutItemClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := TMenuItem(Sender).Tag;
  SwitchToLayoutIndex(Index);
end;

// C.2: cycle to the next loaded layout (wraps). No active layout yet starts
// at the first one.
procedure TfrmTray.CycleToNextLayout;
var
  I, Current, NextIndex: Integer;
begin
  if gLayoutManager.LayoutCount < 2 then
  begin
    Notify('Only one layout is loaded; nothing to cycle.');
    Exit;
  end;

  Current := -1;
  for I := 0 to gLayoutManager.LayoutCount - 1 do
    if gLayoutManager.GetLayout(I) = gLayoutManager.ActiveLayout then
    begin
      Current := I;
      Break;
    end;

  if Current < 0 then
    NextIndex := 0
  else
    NextIndex := (Current + 1) mod gLayoutManager.LayoutCount;

  SwitchToLayoutIndex(NextIndex);

  // A hotkey press has no visible menu feedback, so name the new layout.
  if Assigned(gLayoutManager.ActiveLayout) then
    Notify('Layout: ' + gLayoutManager.ActiveLayout.Name);
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
        // Restoring must not raise out of the click handler either; if even the
        // previous settings fail to apply, the balloon carries the reason.
        try
          ApplyRuntimeSettings(PreviousSettings);
        except
          on E2: Exception do
            Notify('Restoring previous settings failed: ' + E2.Message);
        end;
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
  Result.IgnoreInjectedInput := GAppSettings.IgnoreInjectedInput;
  Result.LayoutsPath := GAppSettings.LayoutsPath;
  Result.DefaultLayoutID := GAppSettings.DefaultLayoutID;
  Result.TargetProcessName := GAppSettings.TargetProcessName;
  Result.AllowedProcessesText := GAppSettings.AllowedProcessesText;
  Result.ToggleHotkeyText := GAppSettings.ToggleHotkeyText;
  Result.CycleHotkeyText := GAppSettings.CycleHotkeyText;
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
  // Item 8c: HOTKEY_ID_ACTION is gone with the removed action hotkey; the
  // unregister of a never-registered ID is a harmless no-op anyway.
  UnregisterHotKey(Handle, HOTKEY_ID_CYCLE);
end;

procedure TfrmTray.RegisterConfiguredHotkeys;
var
  Mods: UINT;
  VK: UINT;
  ToggleHotkey: string;
  CycleHotkey: string;
begin
  UnregisterConfiguredHotkeys;

  ToggleHotkey := Trim(GAppSettings.GetToggleHotkeyText);
  if ToggleHotkey <> '' then
  begin
    if not GAppSettings.ParseHotkey(ToggleHotkey, Mods, VK) then
      Notify('Invalid toggle hotkey in settings: ' + ToggleHotkey)
    else if not RegisterHotKey(Handle, HOTKEY_ID_TOGGLE, Mods or MOD_NOREPEAT, VK) then
      Notify('Toggle hotkey is already in use by another app: ' + ToggleHotkey);
  end;

  // C.2: empty default keeps the cycle hotkey unbound until the user opts in.
  CycleHotkey := Trim(GAppSettings.CycleHotkeyText);
  if CycleHotkey <> '' then
  begin
    if not GAppSettings.ParseHotkey(CycleHotkey, Mods, VK) then
      Notify('Invalid layout-cycle hotkey in settings: ' + CycleHotkey)
    else if not RegisterHotKey(Handle, HOTKEY_ID_CYCLE, Mods or MOD_NOREPEAT, VK) then
      Notify('Layout-cycle hotkey is already in use by another app: ' + CycleHotkey);
  end;

  // The shortcut belongs in the menu's shortcut column, not inside the caption.
  // Appending it to the caption broke mnemonic alignment and rendered
  // 'Enable Keyboard ()' when no hotkey was configured.
  miEnable.Caption := '&Enable Keyboard';
  miEnable.ShortCut := TextToShortCut(GAppSettings.GetToggleHotkeyText);
end;

procedure TfrmTray.ApplyRuntimeSettings(const Settings: TKeyboardAppSettingsData);
begin
  if Trim(Settings.LayoutsPath) = '' then
    raise Exception.Create('Layouts path cannot be empty.');

  GAppSettings.EnableKeyboard := Settings.EnableKeyboard;
  GAppSettings.StartWithWindows := Settings.StartWithWindows;
  GAppSettings.IgnoreInjectedInput := Settings.IgnoreInjectedInput;
  GAppSettings.LayoutsPath := IncludeTrailingPathDelimiter(Settings.LayoutsPath);
  GAppSettings.DefaultLayoutID := Settings.DefaultLayoutID;
  GAppSettings.TargetProcessName := Trim(Settings.TargetProcessName);
  GAppSettings.AllowedProcessesText := Trim(Settings.AllowedProcessesText);
  GAppSettings.ToggleHotkeyText := Settings.ToggleHotkeyText;
  GAppSettings.CycleHotkeyText := Settings.CycleHotkeyText;
  GAppSettings.FallbackFont := Settings.FallbackFont;
  GAppSettings.PreviewFontSize := Settings.PreviewFontSize;

  // Review fix (issue 6): a configured path that does not exist or is not
  // writable (installed copy under Program Files) resolves to the per-user
  // layouts folder instead of failing the whole settings apply. The resolved
  // path is persisted with the settings below, so subsequent runs take the
  // fast path (1) directly.
  GAppSettings.LayoutsPath := ResolveLayoutsPath(Settings.LayoutsPath);

  // Reload layouts and re-attach the engine (item 9.5): on a failed reload
  // the helper re-attaches the previously active layout before re-raising,
  // so the caller sees the original error exactly once and typing continues.
  ReloadLayoutsAndActivate(GAppSettings.LayoutsPath, GAppSettings.DefaultLayoutID);
  ResetEngineState;
  ResetInjectionStatus;

  SetEngineEnabled(GAppSettings.EnableKeyboard);
  miEnable.Checked := EngineEnabled;
  SetTargetProcessName(GAppSettings.TargetProcessName);
  SetAllowedProcessNames(GAppSettings.AllowedProcessesText);
  // QW3: the injected-input filter is now a persisted user preference.
  SetIgnoreInjectedInput(GAppSettings.IgnoreInjectedInput);
  UpdateTrayIcon;

  if GAppSettings.StartWithWindows then
    EnableStartup(APP_RUN_NAME, Application.ExeName)
  else
    DisableStartup(APP_RUN_NAME);

  GAppSettings.Save;
  RegisterConfiguredHotkeys;
  UpdateLayoutHeader;
  InvalidateTrayMenus;
end;

procedure TfrmTray.OpenFolder(const Path: string);
begin
  if Trim(Path) = '' then
    Exit;

  if not DirectoryExists(Path) then
  begin
    Notify('Folder not found: ' + Path);
    Exit;
  end;

  ShellExecute(Handle, 'explore', PChar(Path), nil, nil, SW_SHOWNORMAL);
end;

procedure TfrmTray.OpenLayoutsFolderClick(Sender: TObject);
begin
  OpenFolder(GAppSettings.LayoutsPath);
end;

procedure TfrmTray.ReloadLayoutsClick(Sender: TObject);
begin
  // Layout JSON is hand-editable, so there has to be a way to pick up changes
  // without restarting the application.
  //
  // ReloadLayoutsAndActivate detaches the engine, reloads, re-activates the
  // default layout and re-attaches the engine — and on a failed reload it
  // re-attaches the previously active layout BEFORE re-raising, so typing
  // continues unaffected (item 9.5). The whole reload is guarded: a failure
  // is reported as a balloon, never raised out of the click handler.
  try
    ReloadLayoutsAndActivate(GAppSettings.LayoutsPath, GAppSettings.DefaultLayoutID);
    ResetEngineState;

    UpdateLayoutHeader;
    InvalidateTrayMenus;
    UpdateTrayIcon;

    if Assigned(FOSK) then
      FOSK.LoadLayout(gLayoutManager.ActiveLayout);

    if gLayoutManager.LoadErrors.Count > 0 then
      Notify(Format('Reloaded %d layout(s), %d failed. See the log for details.',
        [gLayoutManager.LayoutCount, gLayoutManager.LoadErrors.Count]))
    else
      Notify(Format('Reloaded %d layout(s).', [gLayoutManager.LayoutCount]));
  except
    on E: Exception do
      // The helper already re-attached the engine; only the report remains.
      Notify('Reloading layouts failed: ' + E.Message);
  end;
end;

procedure TfrmTray.OpenLogFolderClick(Sender: TObject);
begin
  OpenFolder(FLogDir);
end;

function TfrmTray.ApplicationVersion: string;
var
  FileName: string;
  Ignored, Len, FixedLen: Cardinal;
  Buffer: TBytes;
  Block: Pointer;
  Fixed: PVSFixedFileInfo;
begin
  // Read it from the executable's own version resource rather than keeping a
  // second copy of the version number in the source.
  Result := 'unknown';
  FileName := Application.ExeName;
  Len := GetFileVersionInfoSize(PChar(FileName), Ignored);
  if Len = 0 then
    Exit;

  SetLength(Buffer, Len);
  if not GetFileVersionInfo(PChar(FileName), 0, Len, Pointer(Buffer)) then
    Exit;
  if not VerQueryValue(Pointer(Buffer), '\', Block, FixedLen) then
    Exit;

  Fixed := PVSFixedFileInfo(Block);
  Result := Format('%d.%d.%d.%d',
    [Fixed.dwFileVersionMS shr 16,
     Fixed.dwFileVersionMS and $FFFF,
     Fixed.dwFileVersionLS shr 16,
     Fixed.dwFileVersionLS and $FFFF]);
end;

procedure TfrmTray.AboutClick(Sender: TObject);
var
  LayoutName, HookState, Hotkey, Text: string;
begin
  if Assigned(gLayoutManager.ActiveLayout) then
    LayoutName := gLayoutManager.ActiveLayout.Name
  else
    LayoutName := 'none';

  if EngineEnabled then
    HookState := 'enabled'
  else
    HookState := 'disabled';

  Hotkey := Trim(GAppSettings.GetToggleHotkeyText);
  if Hotkey = '' then
    Hotkey := 'not set';

  Text := Format(
    'Vittix Indic Keyboard %s' + sLineBreak + sLineBreak +
    'Typing: %s' + sLineBreak +
    'Active layout: %s' + sLineBreak +
    'Layouts loaded: %d' + sLineBreak +
    'Toggle hotkey: %s' + sLineBreak +
    'Layouts folder: %s',
    [ApplicationVersion, HookState, LayoutName, gLayoutManager.LayoutCount, Hotkey,
     GAppSettings.LayoutsPath]);

  // User-initiated and informational, so a dialog is appropriate here.
  MessageBox(Handle, PChar(Text), 'About Vittix Indic Keyboard',
    MB_OK or MB_ICONINFORMATION);
end;

procedure TfrmTray.AddAllowedApplication;
var
  Dialog: TOpenDialog;
  ProcessName: string;
begin
  // Picking the executable is the whole point: the previous workflow required
  // typing a process name into a multiline box in Settings.
  Dialog := TOpenDialog.Create(nil);
  try
    Dialog.Title := 'Add an application to the allowed list';
    Dialog.Filter := 'Applications (*.exe)|*.exe|All files (*.*)|*.*';
    Dialog.Options := Dialog.Options + [ofFileMustExist];
    if not Dialog.Execute then
      Exit;
    ProcessName := ExtractFileName(Dialog.FileName);
  finally
    Dialog.Free;
  end;

  if ProcessName = '' then
    Exit;

  var ProcessList := TStringList.Create;
  try
    ProcessList.StrictDelimiter := True;
    ProcessList.Delimiter := ',';
    ProcessList.DelimitedText := StringReplace(
      StringReplace(GAppSettings.AllowedProcessesText, sLineBreak, ',', [rfReplaceAll]),
      ';', ',', [rfReplaceAll]
    );

    if ProcessList.IndexOf(ProcessName) >= 0 then
    begin
      Notify(ProcessName + ' is already on the allowed list.');
      Exit;
    end;

    ProcessList.Add(ProcessName);
    GAppSettings.AllowedProcessesText :=
      Trim(StringReplace(ProcessList.DelimitedText, ',', sLineBreak, [rfReplaceAll]));
    SetAllowedProcessNames(GAppSettings.AllowedProcessesText);
    GAppSettings.Save;
    InvalidateTrayMenus;

    Notify(ProcessName + ' added to the allowed list.');
  finally
    ProcessList.Free;
  end;
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
  // The caption may carry a menu accelerator; the process name must not.
  Value := StringReplace(Item.Caption, '&', '', [rfReplaceAll]);

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
      Notify('The allowed list is now empty. Interception stays disabled for every app except the primary target process.');
    SetAllowedProcessNames(GAppSettings.AllowedProcessesText);
    GAppSettings.Save;
    InvalidateTrayMenus;
  finally
    ProcessList.Free;
  end;
end;

procedure TfrmTray.UpdateLayoutHeader;
var
  L: TKeyboardLayout;
  StateText: string;
begin
  L := gLayoutManager.ActiveLayout;

  if EngineEnabled then
    StateText := 'ON'
  else
    StateText := 'OFF';

  // One state line answers "is it on" and "which layout" before the user has
  // to open a submenu.
  miLayoutGroupHeader.Caption := 'Vittix Indic Keyboard';

  if Assigned(L) then
  begin
    miLayoutNameHeader.Caption := Format('Engine: %s  -  %s', [StateText, L.Name]);
    miLayoutNameHeader.Default := True; // bold effect in menus
  end
  else
  begin
    miLayoutNameHeader.Caption := Format('Engine: %s  -  no layout', [StateText]);
    miLayoutNameHeader.Default := False;
  end;
end;

end.
