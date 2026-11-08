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
function ProcessKeyChar(const AKey: string): TInjectionOutcome;
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
function EmitOutput(const AAction: TEngineOutputAction; const AText: string): TInjectionOutcome;
begin
  Result := ioNoOutput;
  if Assigned(OnOutput) then
  begin
    OnOutput(AAction, AText);
    Exit(ioSuccess);
  end
  else
  case AAction Of
    eoEmitText:        Result := SendUnicodeText(AText);
    eoEmitBackspace:   Result := SendBackspace;
    eoResetState:
      begin
        ResetEngineState;
        Result := ioNoOutput;
      end;
    end;
end;

{ --------------------------------------------------
  Emit any pending pre-base matra / reph ra-glyph that was
  consumed but not yet placed, BEFORE we commit a real glyph or
  fall back. Without this the hook has already swallowed the trigger
  key, so dropping this state loses the matra/ra entirely.
-------------------------------------------------- }
procedure FlushPendingPreludes(var AOutcome: TInjectionOutcome);
var
  ModRule: TKeyMapping;
begin
  if ActiveLayout = nil then
    Exit;

  if gEngineState.PendingReph then
  begin
    if ActiveLayout.Modifiers.TryGetValue('reph', ModRule) then
      AOutcome := CombineInjectionOutcomes(AOutcome, EmitOutput(eoEmitText, ModRule.Glyph));
    gEngineState.PendingReph := False;
  end;

  if gEngineState.PendingPrebase <> '' then
  begin
    AOutcome := CombineInjectionOutcomes(AOutcome,
      EmitOutput(eoEmitText, gEngineState.PendingPrebase));
    gEngineState.PendingPrebase := '';
  end;
end;

{ --------------------------------------------------
  Public API
-------------------------------------------------- }

procedure SetActiveLayout(ALayout: TKeyboardLayout);
var
  Outcome: TInjectionOutcome;
begin
  // M1.1: commit any consumed pending matra/reph using the OLD active layout's
  // glyphs before switching, so input typed in the previous layout is not
  // silently dropped on a layout switch.
  Outcome := ioNoOutput;
  FlushPendingPreludes(Outcome);

  ActiveLayout := ALayout;
  SetEngineHasActiveLayout(ALayout <> nil);
  EmitOutput(eoResetState, '');
  ResetInjectionStatus;
end;

{ --------------------------------------------------
  Core typing logic
-------------------------------------------------- }
function ProcessKeyChar(const AKey: string): TInjectionOutcome;
var
  OutGlyph: string;
  Matra: TKeyMapping;
  ModRule: TKeyMapping;
  Outcome: TInjectionOutcome;
begin
  Outcome := ioNoOutput;
  try
    // ---------------- BACKSPACE ----------------
    if AKey = #8 then
    begin
      // Reset pending state first. Cancelling a pending prebase/reph does NOT
      // clear the cluster context: nothing was deleted from the screen, so the
      // last emitted output is still the consonant and the next vowel key must
      // stay contextual.
      if gEngineState.PendingPrebase <> '' then
      begin
        gEngineState.PendingPrebase := '';
        Exit(ioSuccess);
      end;

      if gEngineState.PendingReph then
      begin
        gEngineState.PendingReph := False;
        Exit(ioSuccess);
      end;

      // A real backspace deletes emitted output, so the "last output was a
      // consonant" context can no longer be trusted.
      gEngineState.CurrentCluster := '';
      // Send real backspace through the output boundary
      Outcome := CombineInjectionOutcomes(Outcome, EmitOutput(eoEmitBackspace, ''));
      EmitOutput(eoResetState, '');
      if Outcome <> ioSuccess then
        ResetEngineState;
      Exit(Outcome);
    end;

    if (AKey = #9) or (AKey = #13) then
    begin
      // M1.1: commit any consumed pending matra/reph BEFORE the Tab/Enter so the
      // already-consumed keystroke is not silently lost on the control key.
      // Tab/Enter leave the field's text flow, so the cluster context ends here.
      FlushPendingPreludes(Outcome);
      gEngineState.CurrentCluster := '';
      EmitOutput(eoResetState, '');
      if Outcome <> ioSuccess then
        ResetEngineState;
      Exit(Outcome);
    end;

    if not EngineEnabled then
      Exit(ioSuccess);

    if ActiveLayout = nil then
      Exit(ioSuccess);

    { ---------------- REPH ---------------- }
    if ActiveLayout.Modifiers.TryGetValue('reph', ModRule) then
    begin
      if AKey = ModRule.Key then
      begin
        gEngineState.PendingReph := True;
        Exit(ioSuccess);
      end;
    end;

    { ---------------- PREBASE MATRA (િ) ---------------- }
    if ActiveLayout.PrebaseMap.TryGetValue(AKey, Matra) then
    begin
      gEngineState.PendingPrebase := Matra.Glyph;
      Exit(ioSuccess);
    end;

    { ---------------- CONTEXTUAL POSTBASE MATRA ---------------- }
    // Item 2: legacy layouts (krutidev, shree-lipi, remington) put the same
    // vowel key in both DirectMap and PostbaseMap with different glyphs —
    // direct A = "vk" (standalone vowel), postbase A = "k" (aa-matra). After a
    // consonant (CurrentCluster holds the last emitted consonant glyph) the
    // matra reading must win, so the postbase map is consulted BEFORE the
    // direct map. Unicode/phonetic layouts keep the two maps disjoint, so this
    // reordering can never change their output.
    // TODO(phonetic): the engine still has no inherent-vowel or auto-halant
    // support, so a phonetic layout cannot suppress the inherent vowel of a
    // consonant glyph or build half-consonant forms automatically. The
    // validator emits a warning for phonetic layouts documenting this.
    if (gEngineState.CurrentCluster <> '') and
       ActiveLayout.PostbaseMap.TryGetValue(AKey, OutGlyph) then
    begin
      FlushPendingPreludes(Outcome);
      Outcome := CombineInjectionOutcomes(Outcome, EmitOutput(eoEmitText, OutGlyph));
      // A matra is not a consonant: the cluster context ends here.
      gEngineState.CurrentCluster := '';
      if Outcome <> ioSuccess then
        ResetEngineState;
      Exit(Outcome);
    end;

    { ---------------- DIRECT CONSONANT ---------------- }
    if ActiveLayout.DirectMap.TryGetValue(AKey, OutGlyph) then
    begin
      FlushPendingPreludes(Outcome);
      Outcome := CombineInjectionOutcomes(Outcome, EmitOutput(eoEmitText, OutGlyph));
      gEngineState.CurrentCluster := OutGlyph;
      if Outcome <> ioSuccess then
        ResetEngineState;
      Exit(Outcome);
    end;

    { ---------------- POSTBASE MATRA ---------------- }
    if ActiveLayout.PostbaseMap.TryGetValue(AKey, OutGlyph) then
    begin
      FlushPendingPreludes(Outcome);
      Outcome := CombineInjectionOutcomes(Outcome, EmitOutput(eoEmitText, OutGlyph));
      // A matra is a non-consonant output: the cluster context ends here.
      gEngineState.CurrentCluster := '';
      if Outcome <> ioSuccess then
        ResetEngineState;
      Exit(Outcome);
    end;

    { ---------------- HALANT ---------------- }
    if ActiveLayout.Modifiers.TryGetValue('halant', ModRule) then
    begin
      if AKey = ModRule.Key then
      begin
        FlushPendingPreludes(Outcome);
        Outcome := CombineInjectionOutcomes(Outcome, EmitOutput(eoEmitText, ModRule.Glyph));
        // The halant glyph is a non-consonant output: the cluster context ends.
        gEngineState.CurrentCluster := '';
        if Outcome <> ioSuccess then
          ResetEngineState;
        Exit(Outcome);
      end;
    end;

    { ---------------- FALLBACK (English / Symbols) ---------------- }
    // Place any consumed prebase/reph before sending the literal key; the hook
    // has already eaten the trigger key, so dropping it here would lose input.
    FlushPendingPreludes(Outcome);
    gEngineState.CurrentCluster := '';
    EmitOutput(eoResetState, '');
    Outcome := CombineInjectionOutcomes(Outcome, EmitOutput(eoEmitText, AKey));
    if Outcome <> ioSuccess then
      ResetEngineState;
    Result := Outcome;
  except
    on E: Exception do
    begin
      LogError('ProcessKeyChar failed for "' + AKey + '": ' + E.Message);
      raise;
    end;
  end;
end;

end.
