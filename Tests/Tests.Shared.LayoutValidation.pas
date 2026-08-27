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

    ResultObj := TLayoutValidation.ValidateAndReport(Layout, True, False); // ACheckCrossMapDuplicates = False
    try
      Assert.IsTrue(ResultObj.IsValid, 'Cross-map duplicates should be allowed by default: ' + ResultObj.ToString);
    finally
      ResultObj.Free;
    end;
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

initialization
  TDUnitX.RegisterTestFixture(TLayoutValidationTests);

end.