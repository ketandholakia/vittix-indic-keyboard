unit ShreeLipi.Engine;

interface

uses
  System.SysUtils,
  Winapi.Windows,
  EngineState,
  LayoutModel;

procedure SetActiveLayout(ALayout: TKeyboardLayout);
procedure ProcessKeyChar(const AKey: string);

implementation

var
  ActiveLayout: TKeyboardLayout = nil;

{ --------------------------------------------------
  Low-level SendInput helper (UNICODE safe, BATCHED)
  Sends the entire grapheme cluster as a single batch
  of INPUT structures to prevent cluster breakage.
-------------------------------------------------- }
procedure SendText(const S: string);
var
  I, Len: Integer;
  Inputs: array of TInput;
begin
  Len := Length(S);
  if Len = 0 then
    Exit;

  // Build all key-down + key-up events in one array
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

  // Send entire cluster atomically
  SendInput(Len * 2, Inputs[0], SizeOf(TInput));

  gEngineState.LastOutput := S;
end;

procedure SendBackspace;
var
  Inp: TInput;
begin
  ZeroMemory(@Inp, SizeOf(Inp));
  Inp.Itype := INPUT_KEYBOARD;
  Inp.ki.wVk := VK_BACK;
  SendInput(1, Inp, SizeOf(Inp));

  Inp.ki.dwFlags := KEYEVENTF_KEYUP;
  SendInput(1, Inp, SizeOf(Inp));
end;

{ --------------------------------------------------
  Public API
-------------------------------------------------- }

procedure SetActiveLayout(ALayout: TKeyboardLayout);
begin
  ActiveLayout := ALayout;
  ResetEngineState;
end;

{ --------------------------------------------------
  Core typing logic
-------------------------------------------------- }
procedure ProcessKeyChar(const AKey: string);
var
  OutGlyph: string;
  Matra: TKeyMapping;
  ModRule: TKeyMapping;
begin
  // ---------------- BACKSPACE ----------------
  if AKey = #8 then
  begin
    // Reset pending state first
    if gEngineState.PendingPrebase <> '' then
    begin
      gEngineState.PendingPrebase := '';
      Exit;
    end;

    if gEngineState.PendingReph then
    begin
      gEngineState.PendingReph := False;
      Exit;
    end;

    // Send real backspace
    SendBackspace;
    ResetEngineState;
    Exit;
  end;

  if not EngineEnabled then
    Exit;

  if ActiveLayout = nil then
    Exit;

  { ---------------- REPH ---------------- }
  if ActiveLayout.Modifiers.TryGetValue('reph', ModRule) then
  begin
    if AKey = ModRule.Key then
    begin
      gEngineState.PendingReph := True;
      Exit;
    end;
  end;

  { ---------------- PREBASE MATRA (િ) ---------------- }
  if ActiveLayout.PrebaseMap.TryGetValue(AKey, Matra) then
  begin
    gEngineState.PendingPrebase := Matra.Glyph;
    Exit;
  end;

  { ---------------- SEQUENCES / CONJUNCTS ---------------- }
  gEngineState.KeyBuffer := gEngineState.KeyBuffer + AKey;

  if ActiveLayout.Sequences.TryGetValue(gEngineState.KeyBuffer, OutGlyph) then
  begin
    SendText(OutGlyph);
    gEngineState.KeyBuffer := '';
    gEngineState.CurrentCluster := OutGlyph;
    Exit;
  end
  else if Length(gEngineState.KeyBuffer) > 3 then
    gEngineState.KeyBuffer := AKey;

  { ---------------- DIRECT CONSONANT ---------------- }
  if ActiveLayout.DirectMap.TryGetValue(AKey, OutGlyph) then
  begin
    // Reph must come first
    if gEngineState.PendingReph then
    begin
      if ActiveLayout.Modifiers.TryGetValue('reph', ModRule) then
        SendText(ModRule.Glyph);

      gEngineState.PendingReph := False;
    end;

    // Pre-base matra before consonant
    if gEngineState.PendingPrebase <> '' then
    begin
      SendText(gEngineState.PendingPrebase);
      gEngineState.PendingPrebase := '';
    end;

    SendText(OutGlyph);
    gEngineState.CurrentCluster := OutGlyph;
    Exit;
  end;

  { ---------------- POSTBASE MATRA ---------------- }
  if ActiveLayout.PostbaseMap.TryGetValue(AKey, OutGlyph) then
  begin
    SendText(OutGlyph);
    Exit;
  end;

  { ---------------- HALANT ---------------- }
  if ActiveLayout.Modifiers.TryGetValue('halant', ModRule) then
  begin
    if AKey = ModRule.Key then
    begin
      SendText(ModRule.Glyph);
      Exit;
    end;
  end;

  { ---------------- FALLBACK (English / Symbols) ---------------- }
  ResetEngineState;
  SendText(AKey);
end;

end.
