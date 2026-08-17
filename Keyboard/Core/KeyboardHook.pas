unit KeyboardHook;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.PsAPI,
  System.StrUtils,
  System.SysUtils,
  EngineState,
  Logger;

type
  TOnKeyChar = procedure(const AChar: string) of object;

procedure InstallKeyboardHook;
procedure RemoveKeyboardHook;
procedure SetKeyHandler(AHandler: TOnKeyChar);
procedure SetTargetProcessName(const AProcessName: string);
procedure SetAllowedProcessNames(const AProcessNames: string);

implementation

{ ==================================================
  EXPLICIT WinAPI STRUCT (BULLETPROOF)
  ================================================== }

type
  PKBDLLHookStruct = ^TKBDLLHookStruct;
  TKBDLLHookStruct = record
    vkCode: DWORD;
    scanCode: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: ULONG_PTR;
  end;

var
  KBHook: HHOOK = 0;
  KeyHandler: TOnKeyChar = nil;
  TargetProcessName: string = 'CorelDRW.exe';
  AllowedProcessNames: string = 'CorelDRW.exe';

const
  PROCESS_QUERY_LIMITED_INFORMATION = $1000;

{ --------------------------------------------------
  Convert Virtual Key to Unicode character
-------------------------------------------------- }
function VKToChar(vkCode: DWORD; scanCode: DWORD): string;
var
  KeyboardState: TKeyboardState;
  WideBuf: array[0..3] of WideChar;
  Len: Integer;
begin
  Result := '';

  GetKeyboardState(KeyboardState);

  Len := ToUnicode(
    vkCode,
    scanCode,
    KeyboardState,
    WideBuf,
    Length(WideBuf),
    0
  );

  // Handle surrogate pairs (Len can be 2 for SMP characters)
  if Len = 1 then
    Result := WideBuf[0]
  else if Len > 1 then
    SetString(Result, PWideChar(@WideBuf[0]), Len);
end;

function GetForegroundProcessName: string;
var
  ForegroundWnd: HWND;
  ProcessId: DWORD;
  ProcessHandle: THandle;
  Buffer: array[0..MAX_PATH - 1] of Char;
  Len: DWORD;
begin
  Result := '';
  ForegroundWnd := GetForegroundWindow;
  if ForegroundWnd = 0 then
    Exit;

  GetWindowThreadProcessId(ForegroundWnd, ProcessId);
  if ProcessId = 0 then
    Exit;

  ProcessHandle := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, ProcessId);
  if ProcessHandle = 0 then
    Exit;

  try
    Len := GetModuleFileNameEx(ProcessHandle, 0, Buffer, Length(Buffer));
    if Len > 0 then
      Result := ExtractFileName(Buffer);
  finally
    CloseHandle(ProcessHandle);
  end;
end;

function GetForegroundWindowTitle: string;
var
  ForegroundWnd: HWND;
  Buffer: array[0..MAX_PATH - 1] of Char;
begin
  Result := '';
  ForegroundWnd := GetForegroundWindow;
  if ForegroundWnd = 0 then
    Exit;
  if GetWindowText(ForegroundWnd, Buffer, Length(Buffer)) > 0 then
    Result := Buffer;
end;

function IsProcessAllowed(const ProcessName: string): Boolean;
var
  Names: TArray<string>;
  Name: string;
begin
  Result := False;
  if Trim(AllowedProcessNames) = '' then
    Exit(False);
  Names := AllowedProcessNames.Split([',', ';', #13, #10]);
  for Name in Names do
    if SameText(Trim(Name), ProcessName) then
      Exit(True);
end;

function IsTargetAppActive: Boolean;
var
  ActiveProcessName: string;
begin
  ActiveProcessName := GetForegroundProcessName;
  Result := IsProcessAllowed(ActiveProcessName) or
    ((TargetProcessName <> '') and SameText(ActiveProcessName, TargetProcessName));
end;

{ --------------------------------------------------
  Low-level keyboard hook procedure
-------------------------------------------------- }
function LowLevelKeyboardProc(
  nCode: Integer;
  wParam: WPARAM;
  lParam: LPARAM
): LRESULT; stdcall;
var
  KBD: PKBDLLHookStruct;
  Ch: string;
begin
  // If Windows says ignore, pass it on
  if nCode <> HC_ACTION then
    Exit(CallNextHookEx(KBHook, nCode, wParam, lParam));

  if not EngineEnabled then
    Exit(CallNextHookEx(KBHook, nCode, wParam, lParam));

  if not IsTargetAppActive then
    Exit(CallNextHookEx(KBHook, nCode, wParam, lParam));

  if (wParam <> WM_KEYDOWN) and (wParam <> WM_SYSKEYDOWN) then
    Exit(CallNextHookEx(KBHook, nCode, wParam, lParam));

  KBD := PKBDLLHookStruct(lParam);

  // Ignore modifier & control keys
  case KBD.vkCode of
    VK_SHIFT, VK_LSHIFT, VK_RSHIFT,
    VK_CONTROL, VK_LCONTROL, VK_RCONTROL,
    VK_MENU, VK_LMENU, VK_RMENU,
    VK_CAPITAL, VK_ESCAPE:
      Exit(CallNextHookEx(KBHook, nCode, wParam, lParam));
  end;

  // Handle BACKSPACE explicitly
  if KBD.vkCode = VK_BACK then
  begin
    if Assigned(KeyHandler) then
    begin
      KeyHandler(#8);  // ASCII Backspace
      Result := 1;     // BLOCK original
      Exit;
    end;
  end;

  // Convert VK → Unicode char
  Ch := VKToChar(KBD.vkCode, KBD.scanCode);
  if Ch = '' then
    Exit(CallNextHookEx(KBHook, nCode, wParam, lParam));

  // Pass to engine
  if Assigned(KeyHandler) then
  begin
    KeyHandler(Ch);

    // 🔴 BLOCK original keystroke
    Result := 1;
    Exit;
  end;

  Result := CallNextHookEx(KBHook, nCode, wParam, lParam);
end;

{ --------------------------------------------------
  Public API
-------------------------------------------------- }

procedure SetKeyHandler(AHandler: TOnKeyChar);
begin
  KeyHandler := AHandler;
end;

procedure SetTargetProcessName(const AProcessName: string);
begin
  TargetProcessName := Trim(AProcessName);
end;

procedure SetAllowedProcessNames(const AProcessNames: string);
begin
  AllowedProcessNames := Trim(AProcessNames);
end;

procedure InstallKeyboardHook;
begin
  if KBHook <> 0 then
    Exit;

  LogInfo('Installing keyboard hook');
  KBHook := SetWindowsHookEx(
    WH_KEYBOARD_LL,
    @LowLevelKeyboardProc,
    HInstance,
    0
  );

  if KBHook = 0 then
  begin
    LogError('Keyboard hook installation failed');
    RaiseLastOSError;
  end;
end;

procedure RemoveKeyboardHook;
begin
  if KBHook <> 0 then
  begin
    LogInfo('Removing keyboard hook');
    UnhookWindowsHookEx(KBHook);
    KBHook := 0;
  end;
end;

end.
