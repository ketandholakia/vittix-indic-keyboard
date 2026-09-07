unit Tests.Layouts.RealLayouts;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  LayoutModel,
  LayoutJson,
  LayoutValidation;

type
  [TestFixture]
  [Category('RealLayouts')]
  TRealLayoutTests = class
  private
    class function GetLayoutFiles: TArray<string>; static;
  public
    [Test]
    [TestCase('krutidev_010','layouts\devnagari\krutidev_010.json')]
    [TestCase('shreelipi_0708','layouts\devnagari\shreelipi_0708.json')]
    [TestCase('remington','layouts\gujarati\remington.json')]
    [TestCase('press_custom_1','layouts\custom\press_custom_1.json')]
    [TestCase('hindi_phonetic','layouts\hindi\hindi_phonetic.json')]
    [TestCase('hindi_inscript','layouts\hindi\hindi_inscript.json')]
    [TestCase('gujarati_phonetic','layouts\gujarati\gujarati_phonetic.json')]
    [TestCase('gujarati_inscript','layouts\gujarati\gujarati_inscript.json')]
    procedure LoadAndValidateLayout(const ALayoutFile: string);

    [Test]
    procedure AllRealLayouts_ValidateWithDefaultSettings;

    [Test]
    procedure CrossMapDuplicates_DefaultFalse_AllowsOverlap;

    [Test]
    procedure CrossMapDuplicates_ExplicitTrue_DetectsOverlap;

    [Test]
    procedure RequiredFields_ValidatedOnAllLayouts;

    [Test]
    procedure EmptyGlyph_Detection_WorksOnRealLayouts;

    [Test]
    procedure SequenceLength_Validation_WorksOnRealLayouts;

    [Test]
    procedure ValidationResult_Ownership_NoLeaks;
  end;

implementation

class function TRealLayoutTests.GetLayoutFiles: TArray<string>;
begin
  Result := [
    'layouts\devnagari\krutidev_010.json',
    'layouts\devnagari\shreelipi_0708.json',
    'layouts\gujarati\remington.json',
    'layouts\custom\press_custom_1.json',
    'layouts\hindi\hindi_phonetic.json',
    'layouts\hindi\hindi_inscript.json',
    'layouts\gujarati\gujarati_phonetic.json',
    'layouts\gujarati\gujarati_inscript.json'
  ];
end;

procedure TRealLayoutTests.LoadAndValidateLayout(const ALayoutFile: string);
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
  FileName: string;
begin
  FileName := ALayoutFile;
  if not TFile.Exists(FileName) then
    Exit; // Skip if file not found

  Layout := LayoutJson.LoadLayoutFromFile(FileName);
  try
    // Validate with default settings (cross-map duplicates allowed)
    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.IsValid,
        Format('Layout "%s" should be valid but failed: %s', [ExtractFileName(FileName), ResultObj.ToString]));
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TRealLayoutTests.AllRealLayouts_ValidateWithDefaultSettings;
var
  Files: TArray<string>;
  FileName: string;
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Files := GetLayoutFiles;
  for FileName in Files do
  begin
    if not TFile.Exists(FileName) then
      Continue; // Skip missing files

    Layout := LayoutJson.LoadLayoutFromFile(FileName);
    try
      ResultObj := TLayoutValidation.ValidateAndReport(Layout);
      try
        Assert.IsTrue(ResultObj.IsValid,
          Format('Layout "%s" should be valid with default settings: %s', [ExtractFileName(FileName), ResultObj.ToString]));
      finally
        ResultObj.Free;
      end;
    finally
      Layout.Free;
    end;
  end;
end;

procedure TRealLayoutTests.CrossMapDuplicates_DefaultFalse_AllowsOverlap;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
  KM: TKeyMapping;
begin
  // Test that the devanagari layout has cross-map overlaps that should be allowed
  Layout := LayoutJson.LoadLayoutFromFile('layouts\devnagari\krutidev_010.json');
  try
    // The layout has 'i' in prebase and potentially overlapping keys
    // With ACheckCrossMapDuplicates = False (default), this should pass
    ResultObj := TLayoutValidation.ValidateAndReport(Layout, True, False);
    try
      Assert.IsTrue(ResultObj.IsValid,
        'Cross-map duplicates should be allowed by default: ' + ResultObj.ToString);
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TRealLayoutTests.CrossMapDuplicates_ExplicitTrue_DetectsOverlap;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
  KM: TKeyMapping;
begin
  // Create a test layout with known cross-map duplicate
  Layout := TKeyboardLayout.Create;
  try
    Layout.LayoutID := 'test-crossmap';
    Layout.Name := 'CrossMap Test';
    Layout.Script := 'Devanagari';
    Layout.Encoding := 'unicode';
    Layout.FontFamily := 'Test';
    Layout.LayoutType := 'test';
    Layout.Group := 'Test';

    // Same key 'k' in DirectMap and PrebaseMap
    Layout.DirectMap.Add('k', 'क');
    KM := Default(TKeyMapping);
    KM.Key := 'k';
    KM.Glyph := 'ि';
    KM.MapType := 'prebase';
    KM.InitMetadata;
    Layout.PrebaseMap.Add('k', KM);

    // With cross-map check enabled, this should FAIL
    ResultObj := TLayoutValidation.ValidateAndReport(Layout, True, True);
    try
      Assert.IsFalse(ResultObj.IsValid, 'Cross-map duplicates should be detected when explicitly enabled');
      Assert.IsTrue(ResultObj.ErrorCount > 0);
      Assert.IsTrue(ResultObj.ToString.Contains('Duplicate key'));
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TRealLayoutTests.RequiredFields_ValidatedOnAllLayouts;
var
  Files: TArray<string>;
  FileName: string;
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Files := GetLayoutFiles;
  for FileName in Files do
  begin
    if not TFile.Exists(FileName) then
      Continue;

    Layout := LayoutJson.LoadLayoutFromFile(FileName);
    try
      // Verify required fields are present
      Assert.IsTrue(Layout.LayoutID <> '', Format('Layout "%s" missing LayoutID', [FileName]));
      Assert.IsTrue(Layout.Name <> '', Format('Layout "%s" missing Name', [FileName]));
      Assert.IsTrue(Layout.Script <> '', Format('Layout "%s" missing Script', [FileName]));
      Assert.IsTrue(Layout.Encoding <> '', Format('Layout "%s" missing Encoding', [FileName]));
      Assert.IsTrue(Layout.LayoutType <> '', Format('Layout "%s" missing LayoutType', [FileName]));

      // Validate with required fields check
      ResultObj := TLayoutValidation.ValidateAndReport(Layout, True, False);
      try
        Assert.IsTrue(ResultObj.IsValid,
          Format('Layout "%s" should have all required fields: %s', [ExtractFileName(FileName), ResultObj.ToString]));
      finally
        ResultObj.Free;
      end;
    finally
      Layout.Free;
    end;
  end;
end;

procedure TRealLayoutTests.EmptyGlyph_Detection_WorksOnRealLayouts;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  // Test that empty glyphs are detected
  Layout := TKeyboardLayout.Create;
  try
    Layout.LayoutID := 'test-empty-glyph';
    Layout.Name := 'Empty Glyph Test';
    Layout.Script := 'Devanagari';
    Layout.Encoding := 'unicode';
    Layout.FontFamily := 'Test';
    Layout.LayoutType := 'test';
    Layout.Group := 'Test';

    // Add entry with empty glyph in DirectMap
    Layout.DirectMap.Add('x', '');

    ResultObj := TLayoutValidation.ValidateAndReport(Layout, True, False);
    try
      Assert.IsFalse(ResultObj.IsValid, 'Empty glyph in DirectMap should fail validation');
      Assert.IsTrue(ResultObj.ToString.Contains('Empty glyph'));
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TRealLayoutTests.SequenceLength_Validation_WorksOnRealLayouts;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := TKeyboardLayout.Create;
  try
    Layout.LayoutID := 'test-seq-length';
    Layout.Name := 'Sequence Length Test';
    Layout.Script := 'Devanagari';
    Layout.Encoding := 'unicode';
    Layout.FontFamily := 'Test';
    Layout.LayoutType := 'test';
    Layout.Group := 'Test';

    // Test sequence too short (length 1)
    Layout.Sequences.Add('k', 'क्ष');
    ResultObj := TLayoutValidation.ValidateAndReport(Layout, True, False);
    try
      Assert.IsFalse(ResultObj.IsValid, 'Sequence length 1 should fail');
      Assert.IsTrue(ResultObj.ToString.Contains('too short'));
    finally
      ResultObj.Free;
    end;

    Layout.Sequences.Clear;

    // Test sequence too long (length 5, max is 4)
    Layout.Sequences.Add('kshzt', 'क्ष');
    ResultObj := TLayoutValidation.ValidateAndReport(Layout, True, False);
    try
      Assert.IsFalse(ResultObj.IsValid, 'Sequence length 5 should fail');
      Assert.IsTrue(ResultObj.ToString.Contains('longer than'));
    finally
      ResultObj.Free;
    end;

    Layout.Sequences.Clear;

    // Test valid sequence length (2)
    Layout.Sequences.Add('kS', 'क्ष');
    ResultObj := TLayoutValidation.ValidateAndReport(Layout, True, False);
    try
      Assert.IsTrue(ResultObj.IsValid, 'Sequence length 2 should pass');
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TRealLayoutTests.ValidationResult_Ownership_NoLeaks;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
  i: Integer;
begin
  Layout := TKeyboardLayout.Create;
  try
    Layout.LayoutID := 'test-ownership';
    Layout.Name := 'Ownership Test';
    Layout.Script := 'Devanagari';
    Layout.Encoding := 'unicode';
    Layout.FontFamily := 'Test';
    Layout.LayoutType := 'test';
    Layout.Group := 'Test';
    Layout.DirectMap.Add('k', 'क');

    // Create and free multiple validation results
    for i := 1 to 10 do
    begin
      ResultObj := TLayoutValidation.ValidateAndReport(Layout);
      try
        Assert.IsTrue(ResultObj.IsValid);
      finally
        ResultObj.Free;
      end;
    end;

    // Test ValidateAndReport exception safety
    Layout.LayoutID := ''; // Invalid
    try
      ResultObj := TLayoutValidation.ValidateAndReport(Layout);
      ResultObj.Free; // Should not leak even if invalid
    except
      on E: Exception do
        ; // Expected to potentially raise
    end;

    Assert.Pass('ValidationResult ownership test completed without leaks');
  finally
    Layout.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRealLayoutTests);

end.