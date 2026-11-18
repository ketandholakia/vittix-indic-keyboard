unit Tests.Layouts.LegacyGlyphs;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  LayoutModel,
  LayoutJson,
  LayoutValidation,
  Tests.Layouts.RealLayouts;

type
  [TestFixture]
  [Category('LegacyGlyphs')]
  TLegacyGlyphTests = class
  public
    // Phase A.1 data-integrity gate: the shipped legacy layouts were authored
    // with a cp437 mis-decode (UTF-8 bytes read through cp437). Every glyph
    // character must now be ASCII, Latin-1 Supplement, Latin Extended-A,
    // Devanagari or Gujarati — box-drawing (U+2500-U+25FF) and Greek
    // (U+0370-U+03FF, the cp437 alpha signature) are the tell-tale remnants.
    [Test]
    [TestCase('remington','layouts\gujarati\remington.json')]
    [TestCase('krutidev_010','layouts\devnagari\krutidev_010.json')]
    [TestCase('shree_dev_1076','layouts\devnagari\shree_dev_1076.json')]
    [TestCase('shreelipi_0708','layouts\devnagari\shreelipi_0708.json')]
    procedure LegacyGlyphCodepoints_WithinAllowedBlocks(const ALayoutFile: string);

    // Engine behavior after the repair (remington, decoded glyphs).
    [Test]
    procedure Remington_TypeK_EmitsConsonantGlyph;
    [Test]
    procedure Remington_TypeKA_AttachesAaMatra;

    // Phase A.2: direct_classes completion. Kruti Dev documented convention
    // (Kruti Dev 010 typing chart): the unshifted semicolon key types म, so
    // "m" -> ";" is a consonant. q ("Q") and Q ("qq") stay UNLISTED: the
    // chart sources disagree on what the font strings "Q"/"qq" render as,
    // and deciding requires the real font — unlisted keeps legacy behavior.
    [Test]
    procedure Krutidev010_MClassifiedConsonant_QAndQUnlisted;
    [Test]
    procedure Shreelipi0708_MClassifiedConsonant_QAndQUnlisted;
    [Test]
    procedure ShreeDev1076_HasNoQOrQKeys;
  end;

implementation

function IsAllowedGlyphChar(const C: Char): Boolean;
var
  Code: Integer;
begin
  Code := Ord(C);
  Result :=
    (Code < $0080) or                            // ASCII (legacy font keys)
    ((Code >= $0080) and (Code <= $00FF)) or     // Latin-1 Supplement (µ, ©, Æ)
    ((Code >= $0100) and (Code <= $017F)) or     // Latin Extended-A (Ÿ)
    ((Code >= $0900) and (Code <= $097F)) or     // Devanagari
    ((Code >= $0A80) and (Code <= $0AFF));       // Gujarati
end;

procedure TLegacyGlyphTests.LegacyGlyphCodepoints_WithinAllowedBlocks(
  const ALayoutFile: string);
var
  Layout: TKeyboardLayout;
  Violations: string;

  procedure CheckGlyph(const AWhere, AGlyph: string);
  var
    Ch: Char;
    BoxDrawing, Greek: Boolean;
  begin
    for Ch in AGlyph do
    begin
      if IsAllowedGlyphChar(Ch) then
        Continue;
      BoxDrawing := (Ord(Ch) >= $2500) and (Ord(Ch) <= $25FF);
      Greek := (Ord(Ch) >= $0370) and (Ord(Ch) <= $03FF);
      if BoxDrawing then
        Violations := Violations + Format('%s: %s has box-drawing char U+%.4x (cp437 mojibake); ',
          [ExtractFileName(ALayoutFile), AWhere, Ord(Ch)])
      else if Greek then
        Violations := Violations + Format('%s: %s has Greek char U+%.4x (cp437 alpha signature); ',
          [ExtractFileName(ALayoutFile), AWhere, Ord(Ch)])
      else
        Violations := Violations + Format('%s: %s has char U+%.4x outside allowed blocks; ',
          [ExtractFileName(ALayoutFile), AWhere, Ord(Ch)]);
    end;
  end;

begin
  Layout := LayoutJson.LoadLayoutFromFile(ALayoutFile);
  try
    Violations := '';
    for var Pair in Layout.DirectMap do
      CheckGlyph('direct.' + Pair.Key, Pair.Value);
    for var Pair in Layout.PostbaseMap do
      CheckGlyph('postbase.' + Pair.Key, Pair.Value);
    for var Pair in Layout.PrebaseMap do
      CheckGlyph('prebase.' + Pair.Key, Pair.Value.Glyph);
    for var Pair in Layout.Modifiers do
      CheckGlyph('modifiers.' + Pair.Key, Pair.Value.Glyph);

    Assert.AreEqual('', Violations, 'mojibake glyphs remain in ' + ALayoutFile);
  finally
    Layout.Free;
  end;
end;

procedure TLegacyGlyphTests.Remington_TypeK_EmitsConsonantGlyph;
var
  Layout: TKeyboardLayout;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\gujarati\remington.json');
  try
    // direct.k is the decoded U+0A95 (Gujarati KA); the legacy mojibake
    // string used to emit box-drawing/Greek noise instead. NOTE: this unit
    // must stay UTF-8 WITH BOM or the Gujarati literals below miscompile.
    Assert.AreEqual('ક', TypeSequence(Layout, 'k'),
      'remington: typing k must emit the decoded Gujarati KA glyph');
  finally
    Layout.Free;
  end;
end;

procedure TLegacyGlyphTests.Remington_TypeKA_AttachesAaMatra;
var
  Layout: TKeyboardLayout;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\gujarati\remington.json');
  try
    // k is consonant-class in remington, so the following A must add the
    // decoded aa-matra (postbase.A, U+0ABE), not the standalone vowel glyph.
    Assert.AreEqual('કા', TypeSequence(Layout, 'kA'),
      'remington: consonant + A must produce the decoded aa-matra glyph');
  finally
    Layout.Free;
  end;
end;

procedure TLegacyGlyphTests.Krutidev010_MClassifiedConsonant_QAndQUnlisted;
var
  Layout: TKeyboardLayout;
  KeyClass: string;
  ResultObj: TLayoutValidationResult;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\devnagari\krutidev_010.json');
  try
    Assert.IsTrue(Layout.DirectClasses.TryGetValue('m', KeyClass) and
      (KeyClass = 'consonant'),
      'krutidev: m (types ";" = म per Kruti Dev chart) must be consonant-class');
    Assert.IsFalse(Layout.DirectClasses.ContainsKey('q'),
      'krutidev: q (types "Q") must stay unlisted — glyph class needs the real font');
    Assert.IsFalse(Layout.DirectClasses.ContainsKey('Q'),
      'krutidev: Q (types "qq") must stay unlisted — glyph class needs the real font');

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.IsValid, 'krutidev_010 must still validate: ' + ResultObj.ToString);
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLegacyGlyphTests.Shreelipi0708_MClassifiedConsonant_QAndQUnlisted;
var
  Layout: TKeyboardLayout;
  KeyClass: string;
  ResultObj: TLayoutValidationResult;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\devnagari\shreelipi_0708.json');
  try
    Assert.IsTrue(Layout.DirectClasses.TryGetValue('m', KeyClass) and
      (KeyClass = 'consonant'),
      'shreelipi_0708: m (types ";" per the same Remington-style map) must be consonant-class');
    Assert.IsFalse(Layout.DirectClasses.ContainsKey('q'),
      'shreelipi_0708: q (types "Q") must stay unlisted — glyph class needs the real font');
    Assert.IsFalse(Layout.DirectClasses.ContainsKey('Q'),
      'shreelipi_0708: Q (types "qq") must stay unlisted — glyph class needs the real font');

    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.IsValid, 'shreelipi_0708 must still validate: ' + ResultObj.ToString);
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLegacyGlyphTests.ShreeDev1076_HasNoQOrQKeys;
var
  Layout: TKeyboardLayout;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\devnagari\shree_dev_1076.json');
  try
    // shree_dev_1076 has no q/Q direct entries at all, so there is nothing
    // to classify for A.2 in this layout.
    Assert.IsFalse(Layout.DirectMap.ContainsKey('q'),
      'shree_dev_1076 has no q key in its direct map');
    Assert.IsFalse(Layout.DirectMap.ContainsKey('Q'),
      'shree_dev_1076 has no Q key in its direct map');
  finally
    Layout.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLegacyGlyphTests);

end.
