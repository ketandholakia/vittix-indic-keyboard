unit SendInputHelper;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  Logger;

type
  // Semantic result for one SendInput batch.  Callers deliberately receive no
  // record counts: they only need to know whether it is safe to pass through
  // the original physical key.
  TInjectionOutcome = (
    ioNoOutput,
    ioSuccess,
    ioZeroAccepted,
    ioPartialAccepted,
    // Item 4: the engine produced nothing and consumed nothing, so the
    // original physical key should go through natively — no reinjection.
    ioPassThrough
  );

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

function SendUnicodeText(const S: string): TInjectionOutcome;
function SendUnicodeChar(AChar: WideChar): TInjectionOutcome;

function SendBackspace(Count: Integer = 1): TInjectionOutcome;
function SendVirtualKey(VK: Word): TInjectionOutcome;

procedure SetSendInputHook(AHook: TSendInputProc);

{ --------------------------------------------------
  Injection status
  SendInput calls can fail (most notably UIPI blocks a target
  running at a higher integrity level than us). Consumers use
  this to fail open rather than eat the user's keystrokes.
-------------------------------------------------- }
function InjectionOK: Boolean;
procedure ResetInjectionStatus;
function CombineInjectionOutcomes(const ACurrent, ANext: TInjectionOutcome): TInjectionOutcome;

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

function CombineInjectionOutcomes(const ACurrent, ANext: TInjectionOutcome): TInjectionOutcome;
begin
  // Any accepted side effect paired with a failure is partial-equivalent: the
  // original physical event must not be replayed into potentially changed text.
  if (ACurrent = ioPartialAccepted) or (ANext = ioPartialAccepted) then
    Exit(ioPartialAccepted);
  if ACurrent = ioNoOutput then
    Exit(ANext);
  if ANext = ioNoOutput then
    Exit(ACurrent);
  // ioPassThrough only survives when nothing was emitted and nothing failed:
  // any real outcome supersedes it, because once output exists the original
  // physical key can no longer pass through natively.
  if ACurrent = ioPassThrough then
    Exit(ANext);
  if ANext = ioPassThrough then
    Exit(ACurrent);
  if ACurrent = ioSuccess then
  begin
    if ANext = ioZeroAccepted then
      Exit(ioPartialAccepted);
    Exit(ANext);
  end;
  if ANext = ioSuccess then
  begin
    if ACurrent = ioZeroAccepted then
      Exit(ioPartialAccepted);
    Exit(ACurrent);
  end;
  Result := ioZeroAccepted;
end;

// Submit a batch of INPUT records through the boundary and require that the
// Win32 API accepted the EXACT requested number of records. Partial acceptance
// is a failure, never partial success.
function SubmitInputs(const Inputs: array of TInput; const What: string): TInjectionOutcome;
var
  Requested: Integer;
  Returned: UINT;
begin
  Requested := Length(Inputs);
  if Requested = 0 then
    Exit(ioNoOutput);

  Returned := DoSendInput(Requested, @Inputs[0], SizeOf(TInput));

  if Returned = Cardinal(Requested) then
    Exit(ioSuccess);

  MarkInjectionFailure(What,
    Format('SendInput accepted %d of %d input record(s)',
      [Integer(Returned), Requested]));
  if Returned = 0 then
    Result := ioZeroAccepted
  else
    Result := ioPartialAccepted;
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

function SendUnicodeChar(AChar: WideChar): TInjectionOutcome;
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

  Result := SubmitInputs(Inputs, 'SendUnicodeChar');
end;

{ --------------------------------------------------
  Send Unicode string safely
  Batch the full string into one SendInput call so multi-character
  clusters cannot be interleaved between characters. Success requires
  the exact record count (2 per code unit).
-------------------------------------------------- }

function SendUnicodeText(const S: string): TInjectionOutcome;
var
  I, Len: Integer;
  Inputs: array of TInput;
begin
  Len := Length(S);
  if Len = 0 then
    Exit(ioNoOutput);

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

  Result := SubmitInputs(Inputs, 'SendUnicodeText');
end;

{ --------------------------------------------------
  Send Backspace(s).
  The full sequence (down/up per backspace) is batched into one
  SendInput call and verified against the exact record count.
-------------------------------------------------- }

function SendBackspace(Count: Integer): TInjectionOutcome;
var
  I: Integer;
  Inputs: array of TInput;
begin
  if Count <= 0 then
    Exit(ioNoOutput);

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

  Result := SubmitInputs(Inputs, 'SendBackspace');
end;

{ --------------------------------------------------
  Send a virtual key (non-Unicode).
  Down and up are batched into one SendInput call and verified together.
-------------------------------------------------- }

function SendVirtualKey(VK: Word): TInjectionOutcome;
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

  Result := SubmitInputs(Inputs, 'SendVirtualKey');
end;

end.
