unit SendInputHelper;

interface

uses
  Winapi.Windows,
  System.SysUtils;

{ --------------------------------------------------
  Low-level keyboard output helpers
-------------------------------------------------- }

procedure SendUnicodeText(const S: string);
procedure SendUnicodeChar(AChar: WideChar);

procedure SendBackspace(Count: Integer = 1);
procedure SendVirtualKey(VK: Word);

implementation

{ --------------------------------------------------
  Internal helper
-------------------------------------------------- }

procedure SendKeyInput(
  AScanCode: Word;
  AFlags: DWORD
);
var
  Inp: TInput;
begin
  ZeroMemory(@Inp, SizeOf(Inp));
  Inp.Itype := INPUT_KEYBOARD;
  Inp.ki.wScan := AScanCode;
  Inp.ki.dwFlags := AFlags or KEYEVENTF_UNICODE;
  SendInput(1, Inp, SizeOf(Inp));
end;

{ --------------------------------------------------
  Send a single Unicode character
-------------------------------------------------- }

procedure SendUnicodeChar(AChar: WideChar);
begin
  // key down
  SendKeyInput(Ord(AChar), 0);

  // key up
  SendKeyInput(Ord(AChar), KEYEVENTF_KEYUP);
end;

{ --------------------------------------------------
  Send Unicode string safely
-------------------------------------------------- }

procedure SendUnicodeText(const S: string);
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    SendUnicodeChar(S[I]);
end;

{ --------------------------------------------------
  Send Backspace(s)
-------------------------------------------------- }

procedure SendBackspace(Count: Integer);
var
  I: Integer;
  Inp: TInput;
begin
  for I := 1 to Count do
  begin
    ZeroMemory(@Inp, SizeOf(Inp));
    Inp.Itype := INPUT_KEYBOARD;
    Inp.ki.wVk := VK_BACK;
    SendInput(1, Inp, SizeOf(Inp));

    Inp.ki.dwFlags := KEYEVENTF_KEYUP;
    SendInput(1, Inp, SizeOf(Inp));
  end;
end;

{ --------------------------------------------------
  Send a virtual key (non-Unicode)
-------------------------------------------------- }

procedure SendVirtualKey(VK: Word);
var
  Inp: TInput;
begin
  ZeroMemory(@Inp, SizeOf(Inp));
  Inp.Itype := INPUT_KEYBOARD;
  Inp.ki.wVk := VK;
  SendInput(1, Inp, SizeOf(Inp));

  Inp.ki.dwFlags := KEYEVENTF_KEYUP;
  SendInput(1, Inp, SizeOf(Inp));
end;

end.
