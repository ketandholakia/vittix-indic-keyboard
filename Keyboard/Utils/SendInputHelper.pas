unit SendInputHelper;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  Logger;

{ --------------------------------------------------
  Low-level keyboard output helpers
-------------------------------------------------- }

procedure SendUnicodeText(const S: string);
procedure SendUnicodeChar(AChar: WideChar);

procedure SendBackspace(Count: Integer = 1);
procedure SendVirtualKey(VK: Word);

{ --------------------------------------------------
  Injection status
  SendInput calls can fail (most notably UIPI blocks a target
  running at a higher integrity level than us). Consumers use
  this to fail open rather than eat the user's keystrokes.
-------------------------------------------------- }
function InjectionOK: Boolean;
procedure ResetInjectionStatus;

implementation

var
  gInjectionOK: Boolean = True;

function InjectionOK: Boolean;
begin
  Result := gInjectionOK;
end;

procedure ResetInjectionStatus;
begin
  gInjectionOK := True;
end;

procedure MarkInjectionFailure(const What: string);
begin
  gInjectionOK := False;
  LogError(What + ': SendInput reported 0 (blocked?); interception will pass keys through');
end;

{ --------------------------------------------------
  Internal helper
-------------------------------------------------- }

function SendKeyInput(
  AScanCode: Word;
  AFlags: DWORD
): Cardinal;
var
  Inp: TInput;
begin
  ZeroMemory(@Inp, SizeOf(Inp));
  Inp.Itype := INPUT_KEYBOARD;
  Inp.ki.wScan := AScanCode;
  Inp.ki.dwFlags := AFlags or KEYEVENTF_UNICODE;
  Result := SendInput(1, Inp, SizeOf(Inp));
end;

{ --------------------------------------------------
  Send a single Unicode character
-------------------------------------------------- }

procedure SendUnicodeChar(AChar: WideChar);
begin
  // key down
  if SendKeyInput(Ord(AChar), 0) = 0 then
    MarkInjectionFailure('SendUnicodeChar (down)')
  else
    gInjectionOK := True;

  // key up
  if SendKeyInput(Ord(AChar), KEYEVENTF_KEYUP) = 0 then
    MarkInjectionFailure('SendUnicodeChar (up)')
  else
    gInjectionOK := True;
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

  if SendInput(Len * 2, Inputs[0], SizeOf(TInput)) = 0 then
    MarkInjectionFailure('SendUnicodeText')
  else
    gInjectionOK := True;
end;

{ --------------------------------------------------
  Send Backspace(s)
-------------------------------------------------- }

procedure SendBackspace(Count: Integer);
var
  I: Integer;
  Inp: TInput;
  Ok: Boolean;
begin
  Ok := True;
  for I := 1 to Count do
  begin
    ZeroMemory(@Inp, SizeOf(Inp));
    Inp.Itype := INPUT_KEYBOARD;
    Inp.ki.wVk := VK_BACK;
    Ok := (SendInput(1, Inp, SizeOf(Inp)) <> 0) and Ok;

    Inp.ki.dwFlags := KEYEVENTF_KEYUP;
    Ok := (SendInput(1, Inp, SizeOf(Inp)) <> 0) and Ok;
  end;

  if Ok then
    gInjectionOK := True
  else
    MarkInjectionFailure('SendBackspace');
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
  if SendInput(1, Inp, SizeOf(Inp)) = 0 then
    MarkInjectionFailure('SendVirtualKey (down)')
  else
    gInjectionOK := True;

  Inp.ki.dwFlags := KEYEVENTF_KEYUP;
  if SendInput(1, Inp, SizeOf(Inp)) = 0 then
    MarkInjectionFailure('SendVirtualKey (up)')
  else
    gInjectionOK := True;
end;

end.