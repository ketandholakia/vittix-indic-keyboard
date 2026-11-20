unit LayoutValidation;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  LayoutModel;

type
  TValidationSeverity = (vsError, vsWarning);

  TValidationError = record
    Severity: TValidationSeverity;
    Section: string;
    Key: string;
    Message: string;
    function ToString: string;
  end;

  TValidationErrors = TList<TValidationError>;

  TLayoutValidationResult = class
  private
    FIsValid: Boolean;
    FErrors: TValidationErrors;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function HasErrors: Boolean;
    function ErrorCount: Integer;
    function WarningCount: Integer;
    function ToString: string;
    property IsValid: Boolean read FIsValid write FIsValid;
    property Errors: TValidationErrors read FErrors;
  end;

  TLayoutValidation = class
  public
    class procedure ValidateLayout(
      const ALayout: TKeyboardLayout;
      const AErrors: TValidationErrors;
      const ACheckRequiredFields: Boolean = True;
      // Legacy layouts deliberately overlap maps; callers can opt into this
      // structural diagnostic when authoring a new layout.
      const ACheckCrossMapDuplicates: Boolean = False;
      const ACheckSequenceContent: Boolean = False
    ); static;

    class function ValidateAndReport(
      const ALayout: TKeyboardLayout;
      const ACheckRequiredFields: Boolean = True;
      const ACheckCrossMapDuplicates: Boolean = False;
      const ACheckSequenceContent: Boolean = False
    ): TLayoutValidationResult; static;

    class function IsValidLayout(const ALayout: TKeyboardLayout): Boolean; static;
  end;

implementation

{ TValidationError }

function TValidationError.ToString: string;
begin
  if Key <> '' then
    Result := Format('[%s] %s: %s', [Section, Key, Message])
  else
    Result := Format('[%s] %s', [Section, Message]);
end;

{ TLayoutValidationResult }

constructor TLayoutValidationResult.Create;
begin
  inherited Create;
  FErrors := TValidationErrors.Create;
  FIsValid := True;
end;

destructor TLayoutValidationResult.Destroy;
begin
  FErrors.Free;
  inherited Destroy;
end;

procedure TLayoutValidationResult.Clear;
begin
  FErrors.Clear;
  FIsValid := True;
end;

function TLayoutValidationResult.HasErrors: Boolean;
var
  E: TValidationError;
begin
  Result := False;
  for E in FErrors do
    if E.Severity = vsError then
      Exit(True);
end;

function TLayoutValidationResult.ErrorCount: Integer;
var
  E: TValidationError;
begin
  Result := 0;
  for E in FErrors do
    if E.Severity = vsError then
      Inc(Result);
end;

function TLayoutValidationResult.WarningCount: Integer;
var
  E: TValidationError;
begin
  Result := 0;
  for E in FErrors do
    if E.Severity = vsWarning then
      Inc(Result);
end;

function TLayoutValidationResult.ToString: string;
var
  E: TValidationError;
begin
  Result := '';
  for E in FErrors do
  begin
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + E.ToString;
  end;
end;

{ TLayoutValidation }

class procedure TLayoutValidation.ValidateLayout(
  const ALayout: TKeyboardLayout;
  const AErrors: TValidationErrors;
  const ACheckRequiredFields: Boolean = True;
  const ACheckCrossMapDuplicates: Boolean = False;
  const ACheckSequenceContent: Boolean = False
);

  procedure AddError(const ASeverity: TValidationSeverity; const ASection, AKey, AMessage: string);
  var
    E: TValidationError;
  begin
    E.Severity := ASeverity;
    E.Section := ASection;
    E.Key := AKey;
    E.Message := AMessage;
    AErrors.Add(E);
  end;

var
  SeenKeys: TDictionary<string, string>;
  PairStr: TPair<string, string>;
  PairMatra: TPair<string, TKeyMapping>;
  PairMod: TPair<string, TKeyMapping>;
  MapName: string;
  ExtraMap: TDictionary<string, string>;
  ExtraPair: TPair<string, string>;
  PairProp: TPair<string, string>;
  HasJoinNext, HasInherentKey: Boolean;
  Missing: string;
  MoveToClusterStartCount: Integer;
  InherentKey, InherentClass: string;

  procedure CheckAndRegisterKey(const AKey, ASection: string; const AKeyForSeen: string = '');
  var
    KeyToCheck: string;
  begin
    if AKeyForSeen <> '' then
      KeyToCheck := AKeyForSeen
    else
      KeyToCheck := AKey;

    if KeyToCheck = '' then
      AddError(vsError, ASection, AKey, 'Empty key detected')
    else if SeenKeys.ContainsKey(KeyToCheck) then
      AddError(vsError, ASection, AKey,
        Format('Duplicate key "%s" also used in %s', [KeyToCheck, SeenKeys[KeyToCheck]]))
    else
      SeenKeys.Add(KeyToCheck, ASection);
  end;

begin
  if not Assigned(AErrors) then
    Exit;

  AErrors.Clear;

  if not Assigned(ALayout) then
  begin
    AddError(vsError, 'General', '', 'Layout is not assigned');
    Exit;
  end;

  if ACheckRequiredFields then
  begin
    if ALayout.LayoutID = '' then
      AddError(vsError, 'Layout', 'LayoutID', 'LayoutID is required');
    if ALayout.Name = '' then
      AddError(vsError, 'Layout', 'Name', 'Layout Name is required');
    if ALayout.Script = '' then
      AddError(vsError, 'Layout', 'Script', 'Script is required');
    if ALayout.Encoding = '' then
      AddError(vsError, 'Layout', 'Encoding', 'Encoding is required');
    if ALayout.FontFamily = '' then
      AddError(vsWarning, 'Layout', 'FontFamily', 'FontFamily is empty');
    if ALayout.LayoutType = '' then
      AddError(vsError, 'Layout', 'LayoutType', 'LayoutType is required');
  end;

  // Parsing and runtime execution implement the listed schema versions.
  // Loading a declared version we do not understand would falsely claim
  // compatibility. (Phase A.3: 1.0 layouts stay supported alongside 1.1.)
  if not IsSupportedLayoutSchemaVersion(ALayout.Version) then
    AddError(vsError, 'Layout', 'Version',
      Format('Unsupported layout schema version "%s"; supported version is "%s"',
        [ALayout.Version, SupportedLayoutSchemaVersionsText]));

  // Item (housekeeping): layout_id style. Underscores are the canonical form;
  // hyphens still WORK (SetActiveLayoutByID compares canonicalized IDs) but
  // a warning nudges new layouts to the one style.
  if Pos('-', ALayout.LayoutID) > 0 then
    AddError(vsWarning, 'Layout', 'LayoutID',
      Format('LayoutID "%s" contains hyphens; the canonical style is underscores only',
        [ALayout.LayoutID]));

  // Phase B.5: phonetic opt-in tracking for the engine-feature warning.
  // Review D.4: a PRESENT property counts as the opt-in taken, even when its
  // value is empty or malformed — the specific cross-check warning below
  // names the problem, and firing the generic missing-opt-in warning on top
  // double-reports the same defect.
  HasJoinNext := False;
  HasInherentKey := ALayout.Properties.ContainsKey('inherent_vowel_key');
  MoveToClusterStartCount := 0;

  SeenKeys := TDictionary<string, string>.Create;
  try
    // ---------------- DIRECT MAP ----------------
    for PairStr in ALayout.DirectMap do
    begin
      if PairStr.Key = '' then
        AddError(vsError, 'Direct', PairStr.Key, 'Empty key detected');
      if PairStr.Value = '' then
        AddError(vsError, 'Direct', PairStr.Key, 'Empty glyph for key "' + PairStr.Key + '"');
      if ACheckCrossMapDuplicates then
        CheckAndRegisterKey(PairStr.Key, 'Direct');
    end;

    // ---------------- PREBASE MAP ----------------
    for PairMatra in ALayout.PrebaseMap do
    begin
      if PairMatra.Value.Glyph = '' then
        AddError(vsError, 'Prebase', PairMatra.Key, 'Empty glyph for key "' + PairMatra.Key + '"');

      if PairMatra.Value.Key <> PairMatra.Key then
        AddError(vsWarning, 'Prebase', PairMatra.Key,
          Format('KeyMapping.Key ("%s") does not match map key ("%s")', [PairMatra.Value.Key, PairMatra.Key]));

      if PairMatra.Value.MapType = '' then
        AddError(vsWarning, 'Prebase', PairMatra.Key, 'MapType is empty');

      if Assigned(PairMatra.Value.Metadata) then
        for PairProp in PairMatra.Value.Metadata do
        begin
          if PairProp.Key = '' then
            AddError(vsWarning, 'Prebase.Metadata', PairMatra.Key, 'Empty metadata key');
        end;

      if ACheckCrossMapDuplicates then
        CheckAndRegisterKey(PairMatra.Key, 'Prebase');
    end;

    // ---------------- POSTBASE MAP ----------------
    for PairStr in ALayout.PostbaseMap do
    begin
      if PairStr.Value = '' then
        AddError(vsError, 'Postbase', PairStr.Key, 'Empty glyph for key "' + PairStr.Key + '"');
      if ACheckCrossMapDuplicates then
        CheckAndRegisterKey(PairStr.Key, 'Postbase');
    end;

    // ---------------- DIRECT CLASSES (item 9.4) ----------------
    // Every direct_classes entry must reference a key that exists in the
    // direct map, and carry a class the engine understands. The engine gates
    // half-forms and cluster behavior on SameText 'consonant'/'vowel' — any
    // other value silently behaves as "other", changing runtime output with
    // no visible cause, so unknown values are warned (never errors).
    for PairStr in ALayout.DirectClasses do
    begin
      if not ALayout.DirectMap.ContainsKey(PairStr.Key) then
        AddError(vsWarning, 'DirectClasses', PairStr.Key,
          Format('direct_classes key "%s" (%s) is missing from the direct map',
            [PairStr.Key, PairStr.Value]));
      if (not SameText(PairStr.Value, 'consonant')) and
         (not SameText(PairStr.Value, 'vowel')) and
         (not SameText(PairStr.Value, 'other')) then
        AddError(vsWarning, 'DirectClasses', PairStr.Key,
          Format('direct_classes key "%s" has unknown class "%s" (expected consonant, vowel, or other)',
            [PairStr.Key, PairStr.Value]));
    end;

    // ---------------- MODIFIERS ----------------
    for PairMod in ALayout.Modifiers do
    begin
      if PairMod.Value.Key = '' then
        AddError(vsError, 'Modifiers', PairMod.Key, 'Modifier "' + PairMod.Key + '" has empty key');
      if PairMod.Value.Glyph = '' then
        AddError(vsError, 'Modifiers', PairMod.Key, 'Modifier "' + PairMod.Key + '" has empty glyph');

      if PairMod.Value.MapType = '' then
        AddError(vsWarning, 'Modifiers', PairMod.Key, 'MapType is empty');

      if PairMod.Value.Key <> PairMod.Key then
        AddError(vsWarning, 'Modifiers', PairMod.Key,
          Format('KeyMapping.Key ("%s") does not match map key ("%s")', [PairMod.Value.Key, PairMod.Key]));

      if Assigned(PairMod.Value.Metadata) then
        for PairProp in PairMod.Value.Metadata do
        begin
          if PairProp.Key = '' then
            AddError(vsWarning, 'Modifiers.Metadata', PairMod.Key, 'Empty metadata key');
        end;

      // Phase B.2/B.4: the engine executes auto-halant via a join_next tag.
      if SameText(PairMod.Value.MapType, 'join_next') then
        HasJoinNext := True;

      if SameText(PairMod.Value.MapType, 'move_to_cluster_start') then
      begin
        Inc(MoveToClusterStartCount);
        if MoveToClusterStartCount > 1 then
          AddError(vsWarning, 'Modifiers', PairMod.Key,
            'Multiple modifier rules declare behavior "move_to_cluster_start"; only the first will be executed by the engine');
      end;

      // The dictionary key names a modifier rule; runtime lookup uses the
      // physical key stored in the mapping. Executed rules: reph and halant
      // by name, and ANY rule tagged "behavior": "move_to_cluster_start"
      // (Phase B.4) — everything else is authoring metadata and warned.
      if (PairMod.Key <> 'reph') and (PairMod.Key <> 'halant') and
         (not SameText(PairMod.Value.MapType, 'move_to_cluster_start')) then
        AddError(vsWarning, 'Modifiers', PairMod.Key,
          'Modifier is retained as metadata but is not executed by the engine');

      if ACheckCrossMapDuplicates and
         (((PairMod.Key = 'reph') or (PairMod.Key = 'halant')) or
          SameText(PairMod.Value.MapType, 'move_to_cluster_start')) then
        CheckAndRegisterKey(PairMod.Value.Key, 'Modifiers');
    end;

    // ---------------- SEQUENCES ----------------
    for PairStr in ALayout.Sequences do
    begin
      if PairStr.Key.Length < 2 then
        AddError(vsError, 'Sequences', PairStr.Key, 'Sequence "' + PairStr.Key + '" is too short');
      if PairStr.Key.Length > MAX_SEQUENCE_KEY_LEN then
        AddError(vsError, 'Sequences', PairStr.Key,
          'Sequence "' + PairStr.Key + '" is longer than the maximum supported length (' +
          IntToStr(MAX_SEQUENCE_KEY_LEN) + ')');

      if PairStr.Value = '' then
        AddError(vsError, 'Sequences', PairStr.Key, 'Sequence "' + PairStr.Key + '" has empty output');

      if ACheckCrossMapDuplicates then
        CheckAndRegisterKey(PairStr.Key, 'Sequences');
    end;

    // ---------------- SEQUENCES DEPRECATION WARNING ----------------
    // Sequences are currently not supported by the engine (the direct-map path
    // clears KeyBuffer before a multi-key sequence can accumulate, and the reph
    // rule intercepts 'R' before the sequence check). Use halant-based conjunct
    // input instead (e.g., key + '\' + next_key for क्ष). This warning will be
    // removed when proper sequence/prefix-matching support is implemented.
    if ALayout.Sequences.Count > 0 then
      AddError(vsWarning, 'Sequences', '',
        'Sequences are currently not supported by the engine. ' +
        'Use halant-based conjunct input (e.g., type "k\ + s" for क्ष) instead. ' +
        'This warning will be removed when sequence support is implemented.');

    // ---------------- EXTRA MAPS ----------------
    for MapName in ALayout.ExtraMaps.Keys do
    begin
      ExtraMap := ALayout.ExtraMaps[MapName];
      if ExtraMap.Count = 0 then
        AddError(vsWarning, 'ExtraMaps', MapName, 'ExtraMap "' + MapName + '" is empty');

      for ExtraPair in ExtraMap do
      begin
        if ExtraPair.Key = '' then
          AddError(vsError, 'ExtraMaps.' + MapName, ExtraPair.Key, 'Empty key detected');
        if ExtraPair.Value = '' then
          AddError(vsError, 'ExtraMaps.' + MapName, ExtraPair.Key, 'Empty value for key "' + ExtraPair.Key + '"');
      end;

      if ACheckCrossMapDuplicates then
      begin
        for ExtraPair in ExtraMap do
          CheckAndRegisterKey(ExtraPair.Key, 'ExtraMaps.' + MapName, ExtraPair.Key);
      end;
    end;

    // ---------------- PROPERTIES ----------------
    for PairProp in ALayout.Properties do
    begin
      if PairProp.Key = '' then
        AddError(vsWarning, 'Properties', PairProp.Key, 'Empty property key');
    end;

    // Item (housekeeping): an EMPTY layout (no direct, prebase, postbase or
    // modifier mappings at all) types nothing. Warn so it is visible; the
    // tray menu hides such layouts so they cannot be picked as the active one.
    if (ALayout.DirectMap.Count = 0) and (ALayout.PrebaseMap.Count = 0) and
       (ALayout.PostbaseMap.Count = 0) and (ALayout.Modifiers.Count = 0) then
      AddError(vsWarning, 'Layout', 'Mappings',
        'Layout has no mappings (direct, prebase, postbase and modifiers are all empty); it types nothing and is hidden from the tray menu');

    if ACheckCrossMapDuplicates then
    begin
      for PairProp in ALayout.Properties do
        CheckAndRegisterKey(PairProp.Key, 'Properties', PairProp.Key);
    end;

    if ALayout.Properties.TryGetValue('inherent_vowel_key', InherentKey) then
    begin
      if Trim(InherentKey) = '' then
        AddError(vsWarning, 'Properties', 'inherent_vowel_key',
          'Property "inherent_vowel_key" has an empty value')
      else
      begin
        if not ALayout.DirectMap.ContainsKey(InherentKey) then
          AddError(vsWarning, 'Properties', 'inherent_vowel_key',
            Format('Property "inherent_vowel_key" specifies key "%s", which is not defined in DirectMap', [InherentKey]));

        if ALayout.DirectClasses.Count > 0 then
        begin
          if not ALayout.DirectClasses.TryGetValue(InherentKey, InherentClass) then
            AddError(vsWarning, 'Properties', 'inherent_vowel_key',
              Format('Property "inherent_vowel_key" specifies key "%s", which is missing from direct_classes (must be "vowel")', [InherentKey]))
          else if not SameText(InherentClass, 'vowel') then
            AddError(vsWarning, 'Properties', 'inherent_vowel_key',
              Format('Property "inherent_vowel_key" specifies key "%s" classified as "%s" instead of "vowel"', [InherentKey, InherentClass]));
        end;
      end;
    end;

    // ---------------- PHONETIC ENGINE OPT-INS (Phase B.5) ----------------
    // The engine implements auto-halant (a phonetic layout's halant modifier
    // tagged "behavior": "join_next") and inherent-vowel absorption
    // (properties "inherent_vowel_key"), both gated on direct_classes
    // classification. Warn only for the opt-ins a phonetic layout is
    // missing; without them half-forms need explicit halant input.
    if SameText(ALayout.LayoutType, 'phonetic') then
    begin
      Missing := '';
      if not HasJoinNext then
        Missing := Missing + 'halant modifier "join_next", ';
      if not HasInherentKey then
        Missing := Missing + 'properties "inherent_vowel_key", ';
      if ALayout.DirectClasses.Count = 0 then
        Missing := Missing + 'direct_classes classification, ';
      if Missing <> '' then
      begin
        SetLength(Missing, Length(Missing) - 2); // drop the trailing ", "
        AddError(vsWarning, 'Layout', 'LayoutType',
          'Phonetic layout: engine features need ' + Missing +
          ' (auto-halant = join_next, inherent-vowel absorption = inherent_vowel_key, ' +
          'consonant/vowel gating = direct_classes); without them half-forms need explicit halant input.');
      end;
    end;

  finally
    SeenKeys.Free;
  end;
end;

class function TLayoutValidation.ValidateAndReport(
  const ALayout: TKeyboardLayout;
  const ACheckRequiredFields: Boolean = True;
  const ACheckCrossMapDuplicates: Boolean = False;
  const ACheckSequenceContent: Boolean = False
): TLayoutValidationResult;
begin
  Result := TLayoutValidationResult.Create;
  try
    ValidateLayout(ALayout, Result.FErrors, ACheckRequiredFields, ACheckCrossMapDuplicates, ACheckSequenceContent);
    Result.FIsValid := not Result.HasErrors;
  except
    Result.Free;
    raise;
  end;
end;

class function TLayoutValidation.IsValidLayout(const ALayout: TKeyboardLayout): Boolean;
var
  ResultObj: TLayoutValidationResult;
begin
  ResultObj := ValidateAndReport(ALayout);
  try
    Result := ResultObj.IsValid;
  finally
    ResultObj.Free;
  end;
end;

end.
