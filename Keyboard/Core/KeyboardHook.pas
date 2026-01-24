unit KeyboardHook;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  EngineState;

type
  TOnKeyChar = procedure(const AChar: string) of object;

procedure InstallKeyboardHook;
procedure RemoveKeyboardHook;
procedure SetKeyHandler(AHandler: TOnKeyChar);

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

  if Len > 0 then
    Result := WideBuf[0];
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

procedure InstallKeyboardHook;
begin
  if KBHook <> 0 then
    Exit;

  KBHook := SetWindowsHookEx(
    WH_KEYBOARD_LL,
    @LowLevelKeyboardProc,
    HInstance,
    0
  );

  if KBHook = 0 then
    RaiseLastOSError;
end;

procedure RemoveKeyboardHook;
begin
  if KBHook <> 0 then
  begin
    UnhookWindowsHookEx(KBHook);
    KBHook := 0;
  end;
end;

end.
