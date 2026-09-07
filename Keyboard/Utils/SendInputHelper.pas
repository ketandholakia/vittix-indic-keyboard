unit SendInputHelper;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  Logger;

type
  // Injectable boundary for the Win32 SendInput call (M1.2). By default the
  // production path calls the real Win32 SendInput. Tests install a fake hook to
  // simulate complete success, zero accepted, or partial acceptance without
  // sending real keystrokes (working rule #4).
  TSendInputProc = function(
    cInputs: UINT;
    pInputs: PInput;
    cbSize: Integer
  ): UINT; stdcall;

{ --------------------------------------------------
  Low-level keyboard output helpers
-------------------------------------------------- }

procedure SendUnicodeText(const S: string);
procedure SendUnicodeChar(AChar: WideChar);

procedure SendBackspace(Count: Integer = 1);
procedure SendVirtualKey(VK: Word);

procedure SetSendInputHook(AHook: TSendInputProc);

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
  OnSendInput: TSendInputProc = nil;

function DoSendInput(cInputs: UINT; pInputs: PInput; cbSize: Integer): UINT;
begin
  if Assigned(OnSendInput) then
    Result := OnSendInput(cInputs, pInputs, cbSize)
  else
    Result := SendInput(cInputs, pInputs, cbSize);
end;

procedure SetSendInputHook(AHook: TSendInputProc);
begin
  // nil restores the default (real SendInput) behavior.
  OnSendInput := AHook;
end;

function InjectionOK: Boolean;
begin
  Result := gInjectionOK;
end;

procedure ResetInjectionStatus;
begin
  // The ONLY explicit recovery from a failed/partial injection. A later
  // successful SendInput never re-arms injection (it would conceal a failure).
  gInjectionOK := True;
end;

procedure MarkInjectionFailure(const What, Detail: string);
begin
  // Log only on the transition into the failed state to avoid flooding.
  if gInjectionOK then
    LogError(What + ': ' + Detail + '; interception will pass keys through');
  gInjectionOK := False;
end;

// Submit a batch of INPUT records through the boundary and require that the
// Win32 API accepted the EXACT requested number of records. Partial acceptance
// is a failure, never partial success.
function SubmitInputs(const Inputs: array of TInput; const What: string): Boolean;
var
  Requested: Integer;
  Returned: UINT;
begin
  Requested := Length(Inputs);
  if Requested = 0 then
    Exit(True);

  Returned := DoSendInput(Requested, @Inputs[0], SizeOf(TInput));

  if Returned = Cardinal(Requested) then
    Exit(True);

  MarkInjectionFailure(What,
    Format('SendInput accepted %d of %d input record(s)',
      [Integer(Returned), Requested]));
  Result := False;
end;
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
  Result := DoSendInput(1, @Inp, SizeOf(Inp));
end;

{ --------------------------------------------------
  Send a single Unicode character.
  Key-down and key-up are batched into ONE SendInput call so the
  complete pair is verified together and a late key-up can never
  conceal a failed key-down.
-------------------------------------------------- }

procedure SendUnicodeChar(AChar: WideChar);
var
  Inputs: array[0..1] of TInput;
begin
  // key down
  ZeroMemory(@Inputs[0], SizeOf(TInput));
  Inputs[0].Itype := INPUT_KEYBOARD;
  Inputs[0].ki.wScan := Ord(AChar);
  Inputs[0].ki.dwFlags := KEYEVENTF_UNICODE;

  // key up
  ZeroMemory(@Inputs[1], SizeOf(TInput));
  Inputs[1].Itype := INPUT_KEYBOARD;
  Inputs[1].ki.wScan := Ord(AChar);
  Inputs[1].ki.dwFlags := KEYEVENTF_UNICODE or KEYEVENTF_KEYUP;

  SubmitInputs(Inputs, 'SendUnicodeChar');
end;

{ --------------------------------------------------
  Send Unicode string safely
  Batch the full string into one SendInput call so multi-character
  clusters cannot be interleaved between characters. Success requires
  the exact record count (2 per code unit).
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

  SubmitInputs(Inputs, 'SendUnicodeText');
end;

{ --------------------------------------------------
  Send Backspace(s).
  The full sequence (down/up per backspace) is batched into one
  SendInput call and verified against the exact record count.
-------------------------------------------------- }

procedure SendBackspace(Count: Integer);
var
  I: Integer;
  Inputs: array of TInput;
begin
  if Count <= 0 then
    Exit;

  SetLength(Inputs, Count * 2);
  for I := 0 to Count - 1 do
  begin
    ZeroMemory(@Inputs[I * 2], SizeOf(TInput));
    Inputs[I * 2].Itype := INPUT_KEYBOARD;
    Inputs[I * 2].ki.wVk := VK_BACK;

    ZeroMemory(@Inputs[I * 2 + 1], SizeOf(TInput));
    Inputs[I * 2 + 1].Itype := INPUT_KEYBOARD;
    Inputs[I * 2 + 1].ki.wVk := VK_BACK;
    Inputs[I * 2 + 1].ki.dwFlags := KEYEVENTF_KEYUP;
  end;

  SubmitInputs(Inputs, 'SendBackspace');
end;

{ --------------------------------------------------
  Send a virtual key (non-Unicode).
  Down and up are batched into one SendInput call and verified together.
-------------------------------------------------- }

procedure SendVirtualKey(VK: Word);
var
  Inputs: array[0..1] of TInput;
begin
  ZeroMemory(@Inputs[0], SizeOf(TInput));
  Inputs[0].Itype := INPUT_KEYBOARD;
  Inputs[0].ki.wVk := VK;

  ZeroMemory(@Inputs[1], SizeOf(TInput));
  Inputs[1].Itype := INPUT_KEYBOARD;
  Inputs[1].ki.wVk := VK;
  Inputs[1].ki.dwFlags := KEYEVENTF_KEYUP;

  SubmitInputs(Inputs, 'SendVirtualKey');
end;

end.
