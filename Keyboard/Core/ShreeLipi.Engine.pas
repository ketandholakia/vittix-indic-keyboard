unit ShreeLipi.Engine;

interface

uses
  System.SysUtils,
  Winapi.Windows,
  EngineState,
  LayoutModel,
  SendInputHelper,
  Logger;

type
  // M2.1: engine output boundary. The engine decides WHAT to output (
  // translation, pending-state commits, backspace) and routes each decision as a
  // discrete action through this seam. The OUTPUT IMPLEMENTATION (default = the
  // hardened SendInputHelper-backed layer) owns physical injection. Tests capture
  // these actions to verify engine decisions without sending real keystrokes.

  TEngineOutputAction = (
    eoEmitText,        // payload = text to insert (via SendUnicodeText (
    eoEmitBackspace,   // no payload --- explicit backspace decision (via SendBackspace (
    eoResetState        // no payload --- engine cleared/committed its state (via ResetEngineState (
  );
  TEngineOutputHandler = procedure(
    const AAction: TEngineOutputAction;
    const AText: string
  );

procedure SetActiveLayout(ALayout: TKeyboardLayout);
procedure ProcessKeyChar(const AKey: string);
procedure SetEngineOutputHandler(AHandler: TEngineOutputHandler);

implementation

var
  ActiveLayout: TKeyboardLayout = nil;
  OnOutput: TEngineOutputHandler = nil;

procedure SetEngineOutputHandler(AHandler: TEngineOutputHandler);
begin
  // nil restores the default physical output path via SendInputHelper.
  OnOutput := AHandler;
end;

// Route an output action through the boundary. With no injected handler the
// actions are dispatched to the hardened SendInputHelper-backed output layer.
procedure EmitOutput(const AAction: TEngineOutputAction; const AText: string);
begin
  if Assigned(OnOutput) then
    OnOutput(AAction, AText)
  else
  case AAction Of
    eoEmitText:        SendUnicodeText(AText);
      eoEmitBackspace:     SendBackspace;
      eoResetState:         ResetEngineState;
    end;
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
      EmitOutput(eoEmitText, ModRule.Glyph);
    gEngineState.PendingReph := False;
  end;

  if gEngineState.PendingPrebase <> '' then
  begin
    EmitOutput(eoEmitText, gEngineState.PendingPrebase);
    gEngineState.PendingPrebase := '';
  end;
end;

{ --------------------------------------------------
  Public API
-------------------------------------------------- }

procedure SetActiveLayout(ALayout: TKeyboardLayout);
begin
  // M1.1: commit any consumed pending matra/reph using the OLD active layout's
  // glyphs before switching, so input typed in the previous layout is not
  // silently dropped on a layout switch.
  FlushPendingPreludes;

  ActiveLayout := ALayout;
  SetEngineHasActiveLayout(ALayout <> nil);
  EmitOutput(eoResetState, '');
  ResetInjectionStatus;
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

      // Send real backspace through the output boundary
      EmitOutput(eoEmitBackspace, '');
      EmitOutput(eoResetState, '');
      Exit;
    end;

    if (AKey = #9) or (AKey = #13) then
    begin
      // M1.1: commit any consumed pending matra/reph BEFORE the Tab/Enter so the
      // already-consumed keystroke is not silently lost on the control key.
      FlushPendingPreludes;
      EmitOutput(eoResetState, '');
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
      EmitOutput(eoEmitText, OutGlyph);
      gEngineState.CurrentCluster := OutGlyph;
      Exit;
    end;

    { ---------------- POSTBASE MATRA ---------------- }
    if ActiveLayout.PostbaseMap.TryGetValue(AKey, OutGlyph) then
    begin
      FlushPendingPreludes;
      EmitOutput(eoEmitText, OutGlyph);
      Exit;
    end;

    { ---------------- HALANT ---------------- }
    if ActiveLayout.Modifiers.TryGetValue('halant', ModRule) then
    begin
      if AKey = ModRule.Key then
      begin
        FlushPendingPreludes;
        EmitOutput(eoEmitText, ModRule.Glyph);
        Exit;
      end;
    end;

    { ---------------- FALLBACK (English / Symbols) ---------------- }
    // Place any consumed prebase/reph before sending the literal key; the hook
    // has already eaten the trigger key, so dropping it here would lose input.
    FlushPendingPreludes;
    EmitOutput(eoResetState, '');
    EmitOutput(eoEmitText, AKey);
  except
    on E: Exception do
    begin
      LogError('ProcessKeyChar failed for "' + AKey + '": ' + E.Message);
      raise;
    end;
  end;
end;

end.