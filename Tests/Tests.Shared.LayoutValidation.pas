unit Tests.Shared.LayoutValidation;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Generics.Collections,
  LayoutModel,
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
      Assert.IsTrue(ResultObj.ToString.IndexOf('direct_classes') < 0,
        'consistent direct_classes entries must not warn');
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
