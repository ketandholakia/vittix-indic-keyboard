unit ShreeLipi.Engine;

interface

uses
  System.SysUtils,
  Winapi.Windows,
  EngineState,
  LayoutModel,
  SendInputHelper,
  Logger;

procedure SetActiveLayout(ALayout: TKeyboardLayout);
procedure ProcessKeyChar(const AKey: string);

implementation

var
  ActiveLayout: TKeyboardLayout = nil;

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
  try
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
      SendUnicodeText(OutGlyph);
      gEngineState.KeyBuffer := '';
      gEngineState.CurrentCluster := OutGlyph;
      Exit;
    end
    else if Length(gEngineState.KeyBuffer) > MAX_SEQUENCE_KEY_LEN - 1 then
      gEngineState.KeyBuffer := AKey;

    { ---------------- DIRECT CONSONANT ---------------- }
    if ActiveLayout.DirectMap.TryGetValue(AKey, OutGlyph) then
    begin
      // Reph must come first
      if gEngineState.PendingReph then
      begin
        if ActiveLayout.Modifiers.TryGetValue('reph', ModRule) then
          SendUnicodeText(ModRule.Glyph);

        gEngineState.PendingReph := False;
      end;

      // Pre-base matra before consonant
      if gEngineState.PendingPrebase <> '' then
      begin
        SendUnicodeText(gEngineState.PendingPrebase);
        gEngineState.PendingPrebase := '';
      end;

      // This key has already resolved; do not let it leak into a later sequence match.
      gEngineState.KeyBuffer := '';
      SendUnicodeText(OutGlyph);
      gEngineState.CurrentCluster := OutGlyph;
      Exit;
    end;

    { ---------------- POSTBASE MATRA ---------------- }
    if ActiveLayout.PostbaseMap.TryGetValue(AKey, OutGlyph) then
    begin
      // This key has already resolved; do not let it leak into a later sequence match.
      gEngineState.KeyBuffer := '';
      SendUnicodeText(OutGlyph);
      Exit;
    end;

    { ---------------- HALANT ---------------- }
    if ActiveLayout.Modifiers.TryGetValue('halant', ModRule) then
    begin
      if AKey = ModRule.Key then
      begin
        // This key has already resolved; do not let it leak into a later sequence match.
        gEngineState.KeyBuffer := '';
        SendUnicodeText(ModRule.Glyph);
        Exit;
      end;
    end;

    { ---------------- FALLBACK (English / Symbols) ---------------- }
    ResetEngineState;
    SendUnicodeText(AKey);
  except
    on E: Exception do
    begin
      LogError('ProcessKeyChar failed for "' + AKey + '": ' + E.Message);
      raise;
    end;
  end;
end;

end.
