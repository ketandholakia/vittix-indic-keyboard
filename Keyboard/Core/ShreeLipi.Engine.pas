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
  Low-level SendInput helper (UNICODE safe)
-------------------------------------------------- }
procedure SendText(const S: string);
var
  I: Integer;
  Inp: TInput;
begin
  for I := 1 to Length(S) do
  begin
    ZeroMemory(@Inp, SizeOf(Inp));
    Inp.Itype := INPUT_KEYBOARD;
    Inp.ki.wScan := Ord(S[I]);
    Inp.ki.dwFlags := KEYEVENTF_UNICODE;
    SendInput(1, Inp, SizeOf(Inp));

    Inp.ki.dwFlags := KEYEVENTF_UNICODE or KEYEVENTF_KEYUP;
    SendInput(1, Inp, SizeOf(Inp));
  end;

  // ✅ FIX: use gEngineState
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
  Matra: TPrebaseMatra;
  ModRule: TModifierRule;
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
