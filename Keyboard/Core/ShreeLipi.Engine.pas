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
  SetEngineHasActiveLayout(ALayout <> nil);
  ResetEngineState;
  ResetInjectionStatus;
end;

{ --------------------------------------------------
  Emit any pending pre-base matra / reph ra-glyph that was
  consumed but not yet placed, BEFORE we commit a real glyph or
  fall back. Without this the hook has already swallowed the trigger
  key, so dropping this state loses the matra/ra entirely.
-------------------------------------------------- }
procedure FlushPendingPreludes;
var
  ModRule: TKeyMapping;
begin
  if ActiveLayout = nil then
    Exit;

  if gEngineState.PendingReph then
  begin
    if ActiveLayout.Modifiers.TryGetValue('reph', ModRule) then
      SendUnicodeText(ModRule.Glyph);
    gEngineState.PendingReph := False;
  end;

  if gEngineState.PendingPrebase <> '' then
  begin
    SendUnicodeText(gEngineState.PendingPrebase);
    gEngineState.PendingPrebase := '';
  end;
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

    if (AKey = #9) or (AKey = #13) then
    begin
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

    { ---------------- DIRECT CONSONANT ---------------- }
    if ActiveLayout.DirectMap.TryGetValue(AKey, OutGlyph) then
    begin
      FlushPendingPreludes;
      SendUnicodeText(OutGlyph);
      gEngineState.CurrentCluster := OutGlyph;
      Exit;
    end;

    { ---------------- POSTBASE MATRA ---------------- }
    if ActiveLayout.PostbaseMap.TryGetValue(AKey, OutGlyph) then
    begin
      FlushPendingPreludes;
      SendUnicodeText(OutGlyph);
      Exit;
    end;

    { ---------------- HALANT ---------------- }
    if ActiveLayout.Modifiers.TryGetValue('halant', ModRule) then
    begin
      if AKey = ModRule.Key then
      begin
        FlushPendingPreludes;
        SendUnicodeText(ModRule.Glyph);
        Exit;
      end;
    end;

    { ---------------- FALLBACK (English / Symbols) ---------------- }
    // Place any consumed prebase/reph before sending the literal key; the hook
    // has already eaten the trigger key, so dropping it here would lose input.
    FlushPendingPreludes;
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