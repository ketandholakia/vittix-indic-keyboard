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

  TLayoutValidationResult = record
    IsValid: Boolean;
    Errors: TValidationErrors;
    constructor Create;
    destructor Destroy;
    procedure Clear;
    function HasErrors: Boolean;
    function ErrorCount: Integer;
    function WarningCount: Integer;
    function ToString: string;
  end;

  TLayoutValidation = class
  public
    class procedure ValidateLayout(
      const ALayout: TKeyboardLayout;
      const AErrors: TValidationErrors;
      const ACheckRequiredFields: Boolean = True;
      const ACheckCrossMapDuplicates: Boolean = True;
      const ACheckSequenceContent: Boolean = False
    ); static;

    class function ValidateAndReport(
      const ALayout: TKeyboardLayout;
      const ACheckRequiredFields: Boolean = True;
      const ACheckCrossMapDuplicates: Boolean = True;
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
  Errors := TValidationErrors.Create;
  IsValid := True;
end;

destructor TLayoutValidationResult.Destroy;
begin
  Errors.Free;
  inherited;
end;

procedure TLayoutValidationResult.Clear;
begin
  Errors.Clear;
  IsValid := True;
end;

function TLayoutValidationResult.HasErrors: Boolean;
var
  E: TValidationError;
begin
  Result := False;
  for E in Errors do
    if E.Severity = vsError then
      Exit(True);
end;

function TLayoutValidationResult.ErrorCount: Integer;
var
  E: TValidationError;
begin
  Result := 0;
  for E in Errors do
    if E.Severity = vsError then
      Inc(Result);
end;

function TLayoutValidationResult.WarningCount: Integer;
var
  E: TValidationError;
begin
  Result := 0;
  for E in Errors do
    if E.Severity = vsWarning then
      Inc(Result);
end;

function TLayoutValidationResult.ToString: string;
var
  E: TValidationError;
begin
  Result := '';
  for E in Errors do
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
  const ACheckCrossMapDuplicates: Boolean = True;
  const ACheckSequenceContent: Boolean = False
);
var
  SeenKeys: TDictionary<string, string>;
  PairStr: TPair<string, string>;
  PairMatra: TPair<string, TKeyMapping>;
  PairMod: TPair<string, TKeyMapping;
  Key: string;
  Value: string;
  MapName: string;
  ExtraMap: TDictionary<string, string>;
  ExtraPair: TPair<string, string>;
  PairProp: TPair<string, string>;
  Pair: TJSONPair; // Not used, but keep for consistency
begin
  if not Assigned(AErrors) then
    Exit;

  AErrors.Clear;

  if not Assigned(ALayout) then
  begin
    AErrors.Add(TValidationError.Create(vsError, 'General', '', 'Layout is not assigned'));
    Exit;
  end;

  // Helper to add error
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

  // Check required fields
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
      AddError(vsError, 'Layout', 'FontFamily', 'FontFamily is required');
    if ALayout.LayoutType = '' then
      AddError(vsError, 'Layout', 'LayoutType', 'LayoutType is required');
  end;

  SeenKeys := TDictionary<string, string>.Create;
  try
    // Helper to check and register key
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

    // ---------------- DIRECT MAP ----------------
    for PairStr in ALayout.DirectMap do
    begin
      if PairStr.Key = '' then
        AddError(vsError, 'Direct', PairStr.Key, 'Empty key detected');
      if PairStr.Value = '' then
        AddError(vsError, 'Direct', PairStr.Key, 'Empty glyph for key "' + PairStr.Key + '"');
      CheckAndRegisterKey(PairStr.Key, 'Direct');
    end;

    // ---------------- PREBASE MAP ----------------
    for PairMatra in ALayout.PrebaseMap do
    begin
      if PairMatra.Value.Glyph = '' then
        AddError(vsError, 'Prebase', PairMatra.Key, 'Empty glyph for key "' + PairMatra.Key + '"');

      // Validate Key matches map key
      if PairMatra.Value.Key <> PairMatra.Key then
        AddError(vsWarning, 'Prebase', PairMatra.Key,
          Format('KeyMapping.Key ("%s") does not match map key ("%s")', [PairMatra.Value.Key, PairMatra.Key]));

      // Validate MapType
      if PairMatra.Value.MapType = '' then
        AddError(vsWarning, 'Prebase', PairMatra.Key, 'MapType is empty');

      // Validate Metadata keys
      for PairProp in PairMatra.Value.Metadata do
      begin
        if PairProp.Key = '' then
          AddError(vsWarning, 'Prebase.Metadata', PairMatra.Key, 'Empty metadata key');
      end;

      CheckAndRegisterKey(PairMatra.Key, 'Prebase');
    end;

    // ---------------- POSTBASE MAP ----------------
    for PairStr in ALayout.PostbaseMap do
    begin
      if PairStr.Value = '' then
        AddError(vsError, 'Postbase', PairStr.Key, 'Empty glyph for key "' + PairStr.Key + '"');
      CheckAndRegisterKey(PairStr.Key, 'Postbase');
    end;

    // ---------------- MODIFIERS ----------------
    for PairMod in ALayout.Modifiers do
    begin
      if PairMod.Value.Key = '' then
        AddError(vsError, 'Modifiers', PairMod.Key, 'Modifier "' + PairMod.Key + '" has empty key');
      if PairMod.Value.Glyph = '' then
        AddError(vsError, 'Modifiers', PairMod.Key, 'Modifier "' + PairMod.Key + '" has empty glyph');

      // Validate MapType
      if PairMod.Value.MapType = '' then
        AddError(vsWarning, 'Modifiers', PairMod.Key, 'MapType is empty');

      // Validate Key matches map key
      if PairMod.Value.Key <> PairMod.Key then
        AddError(vsWarning, 'Modifiers', PairMod.Key,
          Format('KeyMapping.Key ("%s") does not match map key ("%s")', [PairMod.Value.Key, PairMod.Key]));

      // Validate Metadata keys
      for PairProp in PairMod.Value.Metadata do
      begin
        if PairProp.Key = '' then
          AddError(vsWarning, 'Modifiers.Metadata', PairMod.Key, 'Empty metadata key');
      end;

      CheckAndRegisterKey(PairMod.Key, 'Modifiers');
    end;

    // ---------------- POSTBASE MAP ----------------
    for PairStr in ALayout.PostbaseMap do
    begin
      if PairStr.Value = '' then
        AddError(vsError, 'Postbase', PairStr.Key, 'Empty glyph for key "' + PairStr.Key + '"');
      CheckAndRegisterKey(PairStr.Key, 'Postbase');
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

      // Cross-map duplicate check for sequence keys
      if ACheckCrossMapDuplicates then
        CheckAndRegisterKey(PairStr.Key, 'Sequences');
    end;

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

      // Cross-map duplicate check for ExtraMaps keys
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

    // Cross-map duplicate check for Properties keys
    if ACheckCrossMapDuplicates then
    begin
      for PairProp in ALayout.Properties do
        CheckAndRegisterKey(PairProp.Key, 'Properties', PairProp.Key);
    end;

    // ---------------- CROSS-MAP DUPLICATE CHECK ----------------
    // This is already handled by CheckAndRegisterKey using SeenKeys dictionary
    // which is shared across all map types

  finally
    SeenKeys.Free;
  end;
end;

class function TLayoutValidation.ValidateAndReport(
  const ALayout: TKeyboardLayout;
  const ACheckRequiredFields: Boolean = True;
  const ACheckCrossMapDuplicates: Boolean = True;
  const ACheckSequenceContent: Boolean = False
): TLayoutValidationResult;
var
  Errors: TValidationErrors;
begin
  Result := TLayoutValidationResult.Create;
  Errors := TValidationErrors.Create;
  try
    ValidateLayout(ALayout, Errors, ACheckRequiredFields, ACheckCrossMapDuplicates, ACheckSequenceContent);
    Result.Errors := Errors;
    Result.IsValid := not Errors.HasErrors;
  except
    Errors.Free;
    raise;
  end;
end;

class function TLayoutValidation.IsValidLayout(const ALayout: TKeyboardLayout): Boolean;
var
  ResultRecord: TLayoutValidationResult;
begin
  ResultRecord := ValidateAndReport(ALayout);
  try
    Result := ResultRecord.IsValid;
  finally
    ResultRecord.Free;
  end;
end;

end.