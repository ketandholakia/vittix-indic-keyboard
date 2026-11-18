unit Tests.Layouts.Phonetic;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  LayoutModel,
  LayoutJson,
  LayoutValidation,
  EngineState,
  ShreeLipi.Engine,
  Tests.Layouts.RealLayouts;

type
  [TestFixture]
  [Category('Phonetic')]
  TPhoneticLayoutTests = class
  private
    // Builds a synthetic phonetic layout for engine-rule tests. The two real
    // phonetic layouts are the reference data; the synthetic one isolates
    // individual opt-ins (classification, join_next, inherent_vowel_key).
    function CreateSynthetic(const AWithClasses, AJoinNext,
      AInherentProp: Boolean): TKeyboardLayout;
  public
    // Phase B.1 data gates: the phonetic layouts must classify every direct
    // key, and the class must match the glyph's script-block identity.
    [Test]
    procedure PhoneticDirectClasses_CoverEveryDirectKey;
    [Test]
    [TestCase('gujarati_phonetic','layouts\gujarati\gujarati_phonetic.json')]
    [TestCase('hindi_phonetic','layouts\hindi\hindi_phonetic.json')]
    procedure PhoneticDirectClasses_MatchGlyphIdentity(const ALayoutFile: string);
    [Test]
    procedure PhoneticHalant_DeclaresJoinNext;
    [Test]
    procedure PhoneticLayouts_StillValidate;
  end;

implementation

function TPhoneticLayoutTests.CreateSynthetic(const AWithClasses, AJoinNext,
  AInherentProp: Boolean): TKeyboardLayout;
var
  KM: TKeyMapping;
begin
  Result := TKeyboardLayout.Create;
  Result.LayoutID := 'synthetic-phonetic';
  Result.Name := 'Synthetic Phonetic';
  Result.Script := 'Gujarati';
  Result.Encoding := 'unicode';
  Result.FontFamily := 'Arial';
  Result.LayoutType := 'phonetic';

  Result.DirectMap.Add('k', 'ક');
  Result.DirectMap.Add('s', 'સ');
  Result.DirectMap.Add('a', 'અ');
  Result.DirectMap.Add('w', 'ા');

  if AWithClasses then
  begin
    Result.DirectClasses.Add('k', 'consonant');
    Result.DirectClasses.Add('s', 'consonant');
    Result.DirectClasses.Add('a', 'vowel');
    Result.DirectClasses.Add('w', 'other');
  end;

  if AJoinNext then
  begin
    KM := Default(TKeyMapping);
    KM.Key := '\';
    KM.Glyph := '્';
    KM.MapType := 'join_next'; // what LayoutFromJson builds from "behavior"
    KM.InitMetadata;
    Result.Modifiers.Add('halant', KM);
  end;

  if AInherentProp then
    Result.Properties.Add('inherent_vowel_key', 'a');
end;

procedure TPhoneticLayoutTests.PhoneticDirectClasses_CoverEveryDirectKey;
var
  Layout: TKeyboardLayout;
  Missing: string;

  procedure Check(const ALayoutFile: string);
  var
    Pair: TPair<string, string>;
  begin
    Layout := LayoutJson.LoadLayoutFromFile(ALayoutFile);
    try
      for Pair in Layout.DirectMap do
        if not Layout.DirectClasses.ContainsKey(Pair.Key) then
          Missing := Missing + Format('%s:%s ', [ExtractFileName(ALayoutFile), Pair.Key]);
    finally
      Layout.Free;
    end;
  end;

begin
  Missing := '';
  Check('layouts\gujarati\gujarati_phonetic.json');
  Check('layouts\hindi\hindi_phonetic.json');
  Assert.AreEqual('', Missing, 'phonetic direct keys missing direct_classes');
end;

procedure TPhoneticLayoutTests.PhoneticDirectClasses_MatchGlyphIdentity(
  const ALayoutFile: string);
var
  Layout: TKeyboardLayout;
  Violations: string;
  IsDevanagari: Boolean;
  KeyClass: string;

  function InConsonantRange(const C: Char): Boolean;
  begin
    if IsDevanagari then
      Result := (Ord(C) >= $0915) and (Ord(C) <= $0939)
    else
      Result := (Ord(C) >= $0A95) and (Ord(C) <= $0AB9);
  end;

  function InIndependentVowelRange(const C: Char): Boolean;
  begin
    if IsDevanagari then
      Result := (Ord(C) >= $0905) and (Ord(C) <= $0914)
    else
      Result := (Ord(C) >= $0A85) and (Ord(C) <= $0A94);
  end;

  function InVowelSignRange(const C: Char): Boolean;
  begin
    if IsDevanagari then
      Result := (Ord(C) >= $093E) and (Ord(C) <= $094D)
    else
      Result := (Ord(C) >= $0ABE) and (Ord(C) <= $0ACD);
  end;

  procedure CheckGlyph(const AKey, AGlyph, AClass: string);
  var
    Ch: Char;
    AllConsonant, AllVowel, AllSign: Boolean;
  begin
    AllConsonant := AGlyph <> '';
    AllVowel := AGlyph <> '';
    AllSign := AGlyph <> '';
    for Ch in AGlyph do
    begin
      if not InConsonantRange(Ch) then AllConsonant := False;
      if not InIndependentVowelRange(Ch) then AllVowel := False;
      if not InVowelSignRange(Ch) then AllSign := False;
    end;

    if SameText(AClass, 'consonant') then
    begin
      if not AllConsonant then
        Violations := Violations + Format('%s: %s classed consonant but glyph %s is not; ',
          [ExtractFileName(ALayoutFile), AKey, AGlyph]);
    end
    else if SameText(AClass, 'vowel') then
    begin
      if not AllVowel then
        Violations := Violations + Format('%s: %s classed vowel but glyph %s is not; ',
          [ExtractFileName(ALayoutFile), AKey, AGlyph]);
    end
    else if SameText(AClass, 'other') then
    begin
      if not AllSign then
        Violations := Violations + Format('%s: %s classed other but glyph %s is not a vowel sign; ',
          [ExtractFileName(ALayoutFile), AKey, AGlyph]);
    end
    else
      Violations := Violations + Format('%s: %s has unknown class %s; ',
        [ExtractFileName(ALayoutFile), AKey, AClass]);
  end;

begin
  Layout := LayoutJson.LoadLayoutFromFile(ALayoutFile);
  try
    IsDevanagari := SameText(Layout.Script, 'Devanagari');
    Violations := '';
    for var Pair in Layout.DirectMap do
      if Layout.DirectClasses.TryGetValue(Pair.Key, KeyClass) then
        CheckGlyph(Pair.Key, Pair.Value, KeyClass)
      else
        Violations := Violations + Format('%s: %s has no direct_classes entry; ',
          [ExtractFileName(ALayoutFile), Pair.Key]);
    Assert.AreEqual('', Violations, 'phonetic class/glyph mismatches in ' + ALayoutFile);
  finally
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.PhoneticHalant_DeclaresJoinNext;
var
  Layout: TKeyboardLayout;
  Rule: TKeyMapping;

  procedure Check(const ALayoutFile: string);
  begin
    Layout := LayoutJson.LoadLayoutFromFile(ALayoutFile);
    try
      Assert.IsTrue(Layout.Modifiers.TryGetValue('halant', Rule),
        ExtractFileName(ALayoutFile) + ' must have a halant modifier');
      Assert.AreEqual('join_next', Rule.MapType,
        ExtractFileName(ALayoutFile) + ': halant must declare "behavior": "join_next"');
    finally
      Layout.Free;
    end;
  end;

begin
  Check('layouts\gujarati\gujarati_phonetic.json');
  Check('layouts\hindi\hindi_phonetic.json');
end;

procedure TPhoneticLayoutTests.PhoneticLayouts_StillValidate;
var
  Layout: TKeyboardLayout;
  ResultObj: TLayoutValidationResult;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\gujarati\gujarati_phonetic.json');
  try
    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.IsValid, 'gujarati_phonetic: ' + ResultObj.ToString);
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;

  Layout := LayoutJson.LoadLayoutFromFile('layouts\hindi\hindi_phonetic.json');
  try
    ResultObj := TLayoutValidation.ValidateAndReport(Layout);
    try
      Assert.IsTrue(ResultObj.IsValid, 'hindi_phonetic: ' + ResultObj.ToString);
    finally
      ResultObj.Free;
    end;
  finally
    Layout.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPhoneticLayoutTests);

end.
