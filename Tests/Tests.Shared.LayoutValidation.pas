unit Tests.Shared.LayoutValidation;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Generics.Collections,
  LayoutModel,
  LayoutJson,
  LayoutValidation;

type
  [TestFixture]
  TLayoutValidationTests = class
  public
    [Test]
    procedure ValidLayout_PassesValidation;

    [Test]
    procedure EmptyLayoutID_FailsValidation;

    [Test]
    procedure EmptyName_FailsValidation;

    [Test]
    procedure CrossMapDuplicates_AllowedByDefault;

    [Test]
    procedure CrossMapDuplicate_DetectedWhenEnabled;

    [Test]
    procedure CrossMapDuplicate_UsesModifierPhysicalKeyWhenEnabled;

    [Test]
    procedure UnsupportedSchemaVersion_FailsValidation;

    [Test]
    procedure EmptySchemaVersion_FailsValidation;

    [Test]
    procedure LegacyDefaultSchemaVersion_PassesValidation;

    // Phase A.3: schema 1.1 — the validator accepts BOTH declared versions.
    [Test]
    procedure SchemaVersion_1_0_Accepted;

    [Test]
    procedure SchemaVersion_1_1_Accepted;

    [Test]
    procedure SchemaVersion_0_9_Rejected;

    [Test]
    procedure SchemaVersion_1_2_Rejected;

    [Test]
    procedure SchemaVersion_AbsentInJsonDefaultsToCurrentAndPasses;

    [Test]
    procedure AllTenRealLayouts_Validate;

    [Test]
    procedure LayoutJsonRoundTrip_PreservesDeclaredVersion;

    [Test]
    procedure Sequences_AreWarningsAndRemainCompatible;

    [Test]
    procedure Validation_DoesNotMutateRichMapping;

    [Test]
    procedure EmptyGlyphInDirectMap_FailsValidation;

    [Test]
    procedure SequenceTooShort_FailsValidation;

    [Test]
    procedure SequenceTooLong_FailsValidation;

    [Test]
    procedure EmptySequenceOutput_FailsValidation;

    [Test]
    procedure ValidationResult_IsValidWhenNoErrors;

    [Test]
    procedure ValidationResult_HasErrorsWhenErrorsAdded;

    [Test]
    procedure DirectClasses_UnknownKey_Warns;

    [Test]
    procedure DirectClasses_KnownKeys_NoWarning;

    // Phase B.5: the engine now implements auto-halant (join_next) and
    // inherent-vowel absorption (inherent_vowel_key) for phonetic layouts.
    // The blanket phonetic warning is retired; phonetic layouts are warned
    // only for the opt-ins they are missing.
    [Test]
    procedure PhoneticLayout_MissingOptIns_WarnsWithGuidance;

    [Test]
    procedure PhoneticLayout_WithOptIns_NoWarning;

    [Test]
    procedure PhoneticLayout_PartialOptIns_WarnListsMissing;

    [Test]
    procedure RenamedRephRule_NotWarnedAsUnexecutedMetadata;
  end;

implementation

function CreateMinimalValidLayout: TKeyboardLayout;
begin
  Result := TKeyboardLayout.Create;
  Result.LayoutID := 'test-layout';
  Result.Name := 'Test Layout';
  Result.Script := 'Devanagari';
  Result.Encoding := 'unicode';
  Result.FontFamily := 'Nirmala UI';
  Result.LayoutType := 'phonetic';
  Result.Group := 'Test';
end;

procedure TLayoutValidationTests.ValidLayout_PassesValidation;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.DirectMap.Add('k', 'क');
    Layout.PostbaseMap.Add('a', 'ा');

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.IsValid, 'Valid layout should pass validation: ' + ResultObj.ToString);
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.EmptyLayoutID_FailsValidation;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.LayoutID := ''; // Invalid

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsFalse(ResultObj.IsValid, 'Empty LayoutID should fail validation');
      Assert.IsTrue(ResultObj.ErrorCount > 0, 'Should have at least one error');
      Assert.IsTrue(ResultObj.ToString.Contains('LayoutID'), 'Error should mention LayoutID');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.EmptyName_FailsValidation;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.Name := ''; // Invalid

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsFalse(ResultObj.IsValid, 'Empty Name should fail validation');
      Assert.IsTrue(ResultObj.ErrorCount > 0, 'Should have at least one error');
      Assert.IsTrue(ResultObj.ToString.Contains('Name'), 'Error should mention Name');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.CrossMapDuplicates_AllowedByDefault;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
  KM: TKeyMapping;
begin
  Layout := CreateMinimalValidLayout;
  try
    // Same key 'k' in DirectMap and PrebaseMap - should be VALID by default
    Layout.DirectMap.Add('k', 'क');
    KM := Default(TKeyMapping);
    KM.Key := 'k';
    KM.Glyph := 'ि';
    KM.MapType := 'prebase';
    KM.InitMetadata;
    Layout.PrebaseMap.Add('k', KM);

    ResultObj := TLayoutValidation.ValidateAndReport(Layout, True, False); // structural-only validation intentionally permits overlap
    try
      Assert.IsTrue(ResultObj.IsValid, 'Cross-map duplicates should be allowed by default: ' + ResultObj.ToString);
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.CrossMapDuplicate_UsesModifierPhysicalKeyWhenEnabled;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
  KM: TKeyMapping;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.DirectMap.Add('d', 'x');
    KM := Default(TKeyMapping);
    KM.Key := 'd';
    KM.Glyph := 'halant';
    KM.MapType := 'modifier';
    KM.InitMetadata;
    Layout.Modifiers.Add('halant', KM);

    ResultObj := TLayoutValidation.ValidateAndReport(Layout, True, True);
    try
      Assert.IsFalse(ResultObj.IsValid,
        'The opt-in collision diagnostic must use a modifier physical key');
      Assert.IsTrue(ResultObj.ToString.Contains('Duplicate key "d"'));
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.UnsupportedSchemaVersion_FailsValidation;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.Version := '2.0';
    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsFalse(ResultObj.IsValid);
      Assert.IsTrue(ResultObj.ToString.Contains('Unsupported layout schema version'));
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.EmptySchemaVersion_FailsValidation;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.Version := '';
    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsFalse(ResultObj.IsValid);
      Assert.IsTrue(ResultObj.ToString.Contains('Unsupported layout schema version'));
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.LegacyDefaultSchemaVersion_PassesValidation;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Assert.AreEqual(CURRENT_LAYOUT_SCHEMA_VERSION, Layout.Version);
    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.IsValid, ResultObj.ToString);
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.Sequences_AreWarningsAndRemainCompatible;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.Sequences.Add('ks', 'conjunct');
    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.IsValid,
        'Legacy sequences are retained but explicitly warned about');
      Assert.IsTrue(ResultObj.WarningCount > 0);
      Assert.IsTrue(ResultObj.ToString.Contains('not supported by the engine'));
      // The warning's example conjunct is a Devanagari literal; this unit
      // has a BOM so the literal is the REAL conjunct. If the production
      // unit ever loses its BOM, the message compiles as cp1252 mojibake
      // and this assertion catches it.
      Assert.IsTrue(ResultObj.ToString.Contains('क्ष'),
        'the sequences warning must show the real Devanagari conjunct');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.Validation_DoesNotMutateRichMapping;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
  KM: TKeyMapping;
begin
  Layout := CreateMinimalValidLayout;
  try
    KM := Default(TKeyMapping);
    KM.Key := 'f';
    KM.Glyph := 'i';
    KM.MapType := 'legacy-prebase';
    KM.InitMetadata;
    KM.Metadata.Add('source', 'imported');
    Layout.PrebaseMap.Add('f', KM);

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.IsValid, ResultObj.ToString);
    finally
      ResultObj.Free;
    end;
    KM := Layout.PrebaseMap['f'];
    Assert.AreEqual('legacy-prebase', KM.MapType);
    Assert.AreEqual('imported', KM.Metadata['source']);
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.CrossMapDuplicate_DetectedWhenEnabled;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
  KM: TKeyMapping;
begin
  Layout := CreateMinimalValidLayout;
  try
    // Same key 'k' in DirectMap and PrebaseMap - should be detected when cross-map check enabled
    Layout.DirectMap.Add('k', 'क');
    KM := Default(TKeyMapping);
    KM.Key := 'k';
    KM.Glyph := 'ि';
    KM.MapType := 'prebase';
    KM.InitMetadata;
    Layout.PrebaseMap.Add('k', KM);

    // With cross-map check enabled, this should fail
    ResultObj := TLayoutValidation.ValidateAndReport(Layout, True, True); // ACheckCrossMapDuplicates = True
    try
      Assert.IsFalse(ResultObj.IsValid, 'Cross-map duplicates should be detected when enabled');
      Assert.IsTrue(ResultObj.ErrorCount > 0, 'Should have at least one error');
      Assert.IsTrue(ResultObj.ToString.Contains('Duplicate key'), 'Error should mention duplicate key');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.EmptyGlyphInDirectMap_FailsValidation;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.DirectMap.Add('k', ''); // Empty glyph

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsFalse(ResultObj.IsValid, 'Empty glyph in DirectMap should fail');
      Assert.IsTrue(ResultObj.ToString.Contains('Empty glyph'), 'Error should mention empty glyph');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.SequenceTooShort_FailsValidation;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.Sequences.Add('k', 'क्ष'); // Length 1 - too short

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsFalse(ResultObj.IsValid, 'Sequence too short should fail');
      Assert.IsTrue(ResultObj.ToString.Contains('too short'), 'Error should mention too short');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.SequenceTooLong_FailsValidation;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.Sequences.Add('kshz', 'क्ष'); // Length 4 - MAX_SEQUENCE_KEY_LEN is 4, so this is actually max length
    // Let's test length 5
    Layout.Sequences.Add('kshzt', 'क्ष'); // Length 5 - too long

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsFalse(ResultObj.IsValid, 'Sequence too long should fail');
      Assert.IsTrue(ResultObj.ToString.Contains('longer than'), 'Error should mention too long');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.EmptySequenceOutput_FailsValidation;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.Sequences.Add('kS', ''); // Empty output

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsFalse(ResultObj.IsValid, 'Empty sequence output should fail');
      Assert.IsTrue(ResultObj.ToString.Contains('empty output'), 'Error should mention empty output');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.ValidationResult_IsValidWhenNoErrors;
var
  ResultObj: TLayoutValidationResult;
begin
  ResultObj := TLayoutValidationResult.Create;
  try
    Assert.IsTrue(ResultObj.IsValid, 'New result should be valid');
    Assert.AreEqual(0, ResultObj.ErrorCount);
    Assert.AreEqual(0, ResultObj.WarningCount);
  finally
    ResultObj.Free;
  end;
end;

procedure TLayoutValidationTests.ValidationResult_HasErrorsWhenErrorsAdded;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.LayoutID := ''; // Invalid

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsFalse(ResultObj.IsValid, 'Should be invalid');
      Assert.IsTrue(ResultObj.HasErrors, 'Should have errors');
      Assert.IsTrue(ResultObj.ErrorCount > 0, 'Error count should be > 0');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

// Item 9.4: every direct_classes entry must reference a key that actually
// exists in the direct map; a stale entry is a warning (authoring mistake),
// never an error (the layout still loads and types).
procedure TLayoutValidationTests.DirectClasses_UnknownKey_Warns;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.DirectMap.Add('k', 'क');
    Layout.DirectClasses.Add('x', 'consonant');   // 'x' is not in direct

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.IsValid,
        'a stale direct_classes entry is a warning, not an error');
      Assert.IsTrue(ResultObj.WarningCount > 0,
        'a direct_classes key missing from direct must warn');
      Assert.IsTrue(ResultObj.ToString.Contains('direct_classes'),
        'the warning must name the direct_classes section');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.DirectClasses_KnownKeys_NoWarning;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.DirectMap.Add('k', 'क');
    Layout.DirectMap.Add('a', 'अ');
    Layout.DirectClasses.Add('k', 'consonant');
    Layout.DirectClasses.Add('a', 'vowel');

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      // Targets the stale-entry warning specifically; the generic word
      // "direct_classes" also appears in the Phase B.5 phonetic opt-in
      // warning, which is unrelated here.
      Assert.IsTrue(ResultObj.ToString.IndexOf('missing from the direct map') < 0,
        'consistent direct_classes entries must not warn');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

// Phase A.3: the validator accepts every version the build understands and
// keeps rejecting anything else with the established message shape.
procedure TLayoutValidationTests.SchemaVersion_1_0_Accepted;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.Version := '1.0';
    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.IsValid, 'declared 1.0 must stay supported: ' + ResultObj.ToString);
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.SchemaVersion_1_1_Accepted;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.Version := '1.1';
    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.IsValid, 'declared 1.1 must be supported: ' + ResultObj.ToString);
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.SchemaVersion_0_9_Rejected;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.Version := '0.9';
    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsFalse(ResultObj.IsValid);
      Assert.IsTrue(ResultObj.ToString.Contains('Unsupported layout schema version'));
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.SchemaVersion_1_2_Rejected;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.Version := '1.2';
    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsFalse(ResultObj.IsValid);
      Assert.IsTrue(ResultObj.ToString.Contains('Unsupported layout schema version'));
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

// Layout files that omit the version field keep their legacy tolerance:
// they load as the CURRENT schema version and pass validation.
procedure TLayoutValidationTests.SchemaVersion_AbsentInJsonDefaultsToCurrentAndPasses;
const
  NoVersionJson = '{"layout_id":"no-version","name":"No Version","script":"Gujarati",' +
    '"encoding":"unicode","font_family":"Shruti","layout_type":"standard",' +
    '"direct":{"a":"x"},"prebase":{},"postbase":{},"modifiers":{},"sequences":{},"extra_maps":{}}';
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := LayoutFromJson(NoVersionJson);
  try
    Assert.AreEqual(CURRENT_LAYOUT_SCHEMA_VERSION, Layout.Version,
      'an absent version field must default to the current schema version');
    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.IsValid, ResultObj.ToString);
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.AllTenRealLayouts_Validate;
var
  Files: array[0..9] of string;
  I: Integer;
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Files[0] := 'layouts\devnagari\krutidev_010.json';
  Files[1] := 'layouts\devnagari\shree_dev_1076.json';
  Files[2] := 'layouts\devnagari\shreelipi_0708.json';
  Files[3] := 'layouts\gujarati\remington.json';
  Files[4] := 'layouts\gujarati\gujarati_remington_unicode.json';
  Files[5] := 'layouts\gujarati\gujarati_phonetic.json';
  Files[6] := 'layouts\gujarati\gujarati_inscript.json';
  Files[7] := 'layouts\hindi\hindi_phonetic.json';
  Files[8] := 'layouts\hindi\hindi_inscript.json';
  Files[9] := 'layouts\custom\press_custom_1.json';

  for I := Low(Files) to High(Files) do
  begin
    Layout := LayoutJson.LoadLayoutFromFile(Files[I]);
    try
      ResultObj := TLayoutValidation.ValidateAndReport(Layout);
      try
        Assert.IsTrue(ResultObj.IsValid,
          Format('real layout "%s" must validate: %s', [Files[I], ResultObj.ToString]));
      finally
        ResultObj.Free;
      end;
    finally
      Layout.Free;
    end;
  end;
end;

procedure TLayoutValidationTests.LayoutJsonRoundTrip_PreservesDeclaredVersion;
var
  Layout, Loaded: TKeyboardLayout;
  JsonText: string;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.Version := '1.0';
    JsonText := LayoutToJson(Layout);
    Loaded := LayoutFromJson(JsonText);
    try
      Assert.AreEqual('1.0', Loaded.Version, 'declared 1.0 must round-trip');
    finally
      Loaded.Free;
    end;

    Layout.Version := '1.1';
    JsonText := LayoutToJson(Layout);
    Loaded := LayoutFromJson(JsonText);
    try
      Assert.AreEqual('1.1', Loaded.Version, 'declared 1.1 must round-trip');
    finally
      Loaded.Free;
    end;
  finally
    Layout.Free;
  end;
end;

// Phase B.5: the engine implements auto-halant (join_next) and inherent-
// vowel absorption (inherent_vowel_key) for phonetic layouts. Warn only
// for the opt-ins a phonetic layout is missing; retire the blanket warning.
procedure TLayoutValidationTests.PhoneticLayout_MissingOptIns_WarnsWithGuidance;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout; // LayoutType = 'phonetic', no opt-ins
  try
    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.IsValid,
        'missing phonetic opt-ins are a warning, not an error');
      Assert.IsTrue(ResultObj.ToString.Contains('Phonetic layout'),
        'missing opt-ins must warn');
      Assert.IsTrue(ResultObj.ToString.Contains('join_next'),
        'the warning must mention the join_next opt-in');
      Assert.IsTrue(ResultObj.ToString.Contains('inherent_vowel_key'),
        'the warning must mention the inherent_vowel_key opt-in');
      Assert.IsTrue(ResultObj.ToString.Contains('direct_classes'),
        'the warning must mention the direct_classes requirement');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.PhoneticLayout_WithOptIns_NoWarning;
var
  Layout: TKeyboardLayout;
  KM: TKeyMapping;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.DirectMap.Add('k', 'क');
    Layout.DirectClasses.Add('k', 'consonant');
    KM := Default(TKeyMapping);
    KM.Key := '\';
    KM.Glyph := '्';
    KM.MapType := 'join_next';
    KM.InitMetadata;
    Layout.Modifiers.Add('halant', KM);
    Layout.Properties.Add('inherent_vowel_key', 'a');

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.ToString.IndexOf('Phonetic layout') < 0,
        'a fully opted-in phonetic layout must not warn');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutValidationTests.PhoneticLayout_PartialOptIns_WarnListsMissing;
var
  Layout: TKeyboardLayout;
  KM: TKeyMapping;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    // Classes + join_next present, inherent_vowel_key absent.
    Layout.DirectMap.Add('k', 'क');
    Layout.DirectClasses.Add('k', 'consonant');
    KM := Default(TKeyMapping);
    KM.Key := '\';
    KM.Glyph := '्';
    KM.MapType := 'join_next';
    KM.InitMetadata;
    Layout.Modifiers.Add('halant', KM);

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.ToString.Contains('Phonetic layout'),
        'a partially opted-in phonetic layout still warns');
      Assert.IsTrue(ResultObj.ToString.Contains('inherent_vowel_key'),
        'the warning must name the still-missing opt-in');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

// Phase B.4 made the engine execute any modifier tagged
// "behavior": "move_to_cluster_start" — such a rule must no longer be
// reported as unexecuted metadata just because its rule name is not 'reph'.
procedure TLayoutValidationTests.RenamedRephRule_NotWarnedAsUnexecutedMetadata;
var
  Layout: TKeyboardLayout;
  KM: TKeyMapping;
  ResultObj: TLayoutValidationResult;
begin
  Layout := CreateMinimalValidLayout;
  try
    Layout.DirectMap.Add('k', 'क');
    KM := Default(TKeyMapping);
    KM.Key := 'R';
    KM.Glyph := 'र्';
    KM.MapType := 'move_to_cluster_start';
    KM.InitMetadata;
    Layout.Modifiers.Add('reph_1', KM);

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.IsValid, ResultObj.ToString);
      Assert.IsTrue(ResultObj.ToString.IndexOf('not executed by the engine') < 0,
        'a move_to_cluster_start rule IS executed and must not warn');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLayoutValidationTests);

end.
