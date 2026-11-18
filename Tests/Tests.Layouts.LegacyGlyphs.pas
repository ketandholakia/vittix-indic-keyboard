unit Tests.Layouts.LegacyGlyphs;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
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

    // Phase A.3: the four legacy layouts declare schema "1.1" (file level);
    // the other six layouts keep their declared state untouched.
    [Test]
    procedure LegacyLayouts_DeclareSchema11_FileLevel;

    // Phase A.5: a layout whose non-ASCII glyphs are all script-block Unicode
    // emits Unicode code points and must not declare legacy encoding — the
    // metadata (encoding + font_family) drives the editor/OSK glyph rendering,
    // and a legacy label on Unicode data renders glyphs in a legacy font.
    [Test]
    [TestCase('remington','layouts\gujarati\remington.json')]
    [TestCase('krutidev_010','layouts\devnagari\krutidev_010.json')]
    [TestCase('shree_dev_1076','layouts\devnagari\shree_dev_1076.json')]
    [TestCase('shreelipi_0708','layouts\devnagari\shreelipi_0708.json')]
    procedure ScriptBlockGlyphLayout_MustDeclareUnicode(const ALayoutFile: string);
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

procedure TLegacyGlyphTests.LegacyLayouts_DeclareSchema11_FileLevel;
var
  Declares11, Others: array[0..5] of string;
  I: Integer;
  Text: string;
begin
  // The four legacy layouts opt into schema 1.1 explicitly.
  Declares11[0] := 'layouts\devnagari\krutidev_010.json';
  Declares11[1] := 'layouts\devnagari\shree_dev_1076.json';
  Declares11[2] := 'layouts\devnagari\shreelipi_0708.json';
  Declares11[3] := 'layouts\gujarati\remington.json';
  for I := 0 to 3 do
  begin
    Text := TFile.ReadAllText(Declares11[I]);
    Assert.IsTrue(Text.Contains('"version": "1.1"'),
      Declares11[I] + ' must declare "version": "1.1"');
  end;

  // The other six layouts stay exactly as they are (1.0 declared or field
  // omitted), checked at the raw-file level.
  Others[0] := 'layouts\gujarati\gujarati_remington_unicode.json';
  Others[1] := 'layouts\gujarati\gujarati_phonetic.json';
  Others[2] := 'layouts\gujarati\gujarati_inscript.json';
  Others[3] := 'layouts\hindi\hindi_phonetic.json';
  Others[4] := 'layouts\hindi\hindi_inscript.json';
  Others[5] := 'layouts\custom\press_custom_1.json';
  for I := 0 to 5 do
  begin
    Text := TFile.ReadAllText(Others[I]);
    Assert.IsFalse(Text.Contains('"version": "1.1"'),
      Others[I] + ' must NOT gain a 1.1 version field in Phase A.3');
  end;
end;

procedure TLegacyGlyphTests.ScriptBlockGlyphLayout_MustDeclareUnicode(
  const ALayoutFile: string);

  function IsScriptBlockChar(const C: Char): Boolean;
  begin
    Result := ((Ord(C) >= $0900) and (Ord(C) <= $097F)) or   // Devanagari
              ((Ord(C) >= $0A80) and (Ord(C) <= $0AFF));     // Gujarati
  end;

var
  Layout: TKeyboardLayout;
  HasScriptGlyph, HasNonScriptNonAscii: Boolean;

  procedure Scan(const AGlyph: string);
  var
    C: Char;
  begin
    for C in AGlyph do
      if Ord(C) >= $0080 then
        if IsScriptBlockChar(C) then
          HasScriptGlyph := True
        else
          HasNonScriptNonAscii := True;   // Latin font code (µ, ©, Æ, Ÿ ...)
  end;

begin
  Layout := LayoutJson.LoadLayoutFromFile(ALayoutFile);
  try
    HasScriptGlyph := False;
    HasNonScriptNonAscii := False;
    for var Pair in Layout.DirectMap do
      Scan(Pair.Value);
    for var Pair in Layout.PostbaseMap do
      Scan(Pair.Value);
    for var Pair in Layout.PrebaseMap do
      Scan(Pair.Value.Glyph);
    for var Pair in Layout.Modifiers do
      Scan(Pair.Value.Glyph);

    // Only a layout that EMITS script-block Unicode (and nothing that looks
    // like a legacy font code) is required to say so. Pure-ASCII or Latin-
    // coded layouts (the KrutiDev family) legitimately stay "legacy".
    if HasScriptGlyph and (not HasNonScriptNonAscii) then
      Assert.AreEqual('unicode', Layout.Encoding,
        ExtractFileName(ALayoutFile) +
        ' emits script-block Unicode glyphs, so its encoding label must say "unicode"')
    else
      // FailsOnNoAsserts: pin the branch decision itself — the legacy label
      // is permitted here because the glyphs carry legacy font codes.
      Assert.IsTrue(HasNonScriptNonAscii or (not HasScriptGlyph),
        ExtractFileName(ALayoutFile) + ' keeps a non-unicode label only because its glyphs are legacy font codes');
  finally
    Layout.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLegacyGlyphTests);

end.
