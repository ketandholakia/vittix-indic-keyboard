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
  Batch the full string into one SendInput call so multi-character
  clusters cannot be interleaved between characters.
-------------------------------------------------- }

procedure SendUnicodeText(const S: string);
var
  I, Len: Integer;
  Inputs: array of TInput;
begin
  Len := Length(S);
  if Len = 0 then
    Exit;

  SetLength(Inputs, Len * 2);
  for I := 0 to Len - 1 do
  begin
    ZeroMemory(@Inputs[I * 2], SizeOf(TInput));
    Inputs[I * 2].Itype := INPUT_KEYBOARD;
    Inputs[I * 2].ki.wScan := Ord(S[I + 1]);
    Inputs[I * 2].ki.dwFlags := KEYEVENTF_UNICODE;

    ZeroMemory(@Inputs[I * 2 + 1], SizeOf(TInput));
    Inputs[I * 2 + 1].Itype := INPUT_KEYBOARD;
    Inputs[I * 2 + 1].ki.wScan := Ord(S[I + 1]);
    Inputs[I * 2 + 1].ki.dwFlags := KEYEVENTF_UNICODE or KEYEVENTF_KEYUP;
  end;

  SendInput(Len * 2, Inputs[0], SizeOf(TInput));
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
