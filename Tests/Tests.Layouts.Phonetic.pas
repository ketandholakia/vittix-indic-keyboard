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
    // Phase B.2: types AKeys against ALayout and records EVERY output
    // boundary event in AEvents (text payloads verbatim, backspace/reset as
    // '<bs>'/'<reset>'), so tests can assert emission ATOMICITY, not just
    // concatenated output. Uses the same seams as TypeSequence.
    procedure TypeIntoEvents(ALayout: TKeyboardLayout; const AKeys: string;
      AEvents: TStringList);
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

    // Phase B.2: auto-halant. A consonant key while a consonant cluster is
    // open becomes a half-form (halant glyph + consonant, ONE atomic
    // emission) in a phonetic layout that declared join_next.
    [Test]
    procedure AutoHalant_KK_IsOneAtomicEmission;
    [Test]
    procedure AutoHalant_BasicSequences;
    [Test]
    procedure AutoHalant_None_AfterVowelOrMatraOrVowelStart;
    [Test]
    procedure AutoHalant_ExplicitHalantStillWorks;
    [Test]
    procedure AutoHalant_LegacyLayouts_Unaffected;
    [Test]
    procedure AutoHalant_RequiresPhoneticAndJoinNextTag;
    [Test]
    procedure AutoHalant_HindiLayout;

    // Phase B.3: inherent-vowel suppression. In a phonetic layout that
    // declares properties "inherent_vowel_key", that vowel-classified key
    // right after an open consonant cluster emits nothing (the inherent
    // vowel is already visible in the consonant glyph) and ends the cluster.
    [Test]
    procedure InherentVowel_KA_Absorbed;
    [Test]
    procedure InherentVowel_KAK_TwoFullConsonants;
    [Test]
    procedure InherentVowel_NonAbsorbed_Cases;
    [Test]
    procedure InherentVowel_Absorption_LeavesOneBackspaceUnit;
    [Test]
    procedure InherentVowel_LegacyLayouts_Unaffected;
    [Test]
    procedure InherentVowel_RequiresTheProperty;

    // Phase B.4: the reph rule is located by its "behavior":
    // "move_to_cluster_start" tag, falling back to the historical rule name
    // 'reph'. Pending/flush mechanics unchanged.
    [Test]
    procedure Reph_RuleName_FallbackStillWorks;
    [Test]
    procedure Reph_BehaviorTag_RenamedRuleWorks;
    [Test]
    procedure Reph_TaggedRules_InRealLayouts;
    [Test]
    procedure Reph_Absent_NoInterference;
  end;

implementation

var
  GPhoneticEvents: TStringList = nil;

procedure CapturePhoneticAction(const AAction: TEngineOutputAction; const AText: string);
begin
  if not Assigned(GPhoneticEvents) then
    Exit;
  case AAction of
    // eoResetState is engine-internal bookkeeping (layout switches, fallback
    // commits) - assertions care about emitted text and backspaces only.
    eoEmitText:      GPhoneticEvents.Add(AText);
    eoEmitBackspace: GPhoneticEvents.Add('<bs>');
  end;
end;

procedure TPhoneticLayoutTests.TypeIntoEvents(ALayout: TKeyboardLayout;
  const AKeys: string; AEvents: TStringList);
var
  Ch: Char;
begin
  InitEngineState;
  SetEngineEnabled(True);
  GPhoneticEvents := AEvents;
  try
    SetEngineOutputHandler(CapturePhoneticAction);
    SetActiveLayout(ALayout);
    AEvents.Clear;
    for Ch in AKeys do
      ProcessKeyChar(Ch);
  finally
    // Detach the capture BEFORE switching layouts, or the nil-layout reset
    // would append a trailing event to the caller's list.
    SetEngineOutputHandler(nil);
    ResetEngineState;
    SetActiveLayout(nil);
    GPhoneticEvents := nil;
  end;
end;

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

procedure TPhoneticLayoutTests.AutoHalant_KK_IsOneAtomicEmission;
var
  Layout: TKeyboardLayout;
  Events: TStringList;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\gujarati\gujarati_phonetic.json');
  Events := TStringList.Create;
  try
    TypeIntoEvents(Layout, 'kk', Events);
    Assert.AreEqual(2, Events.Count, 'k emits once; the second k emits halant+consonant ATOMICALLY');
    Assert.AreEqual('ક', Events[0], 'the first k emits the plain consonant');
    Assert.AreEqual('્ક', Events[1], 'the second k emits the halant glyph and the consonant as ONE string');
  finally
    Events.Free;
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.AutoHalant_BasicSequences;
var
  Layout: TKeyboardLayout;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\gujarati\gujarati_phonetic.json');
  try
    Assert.AreEqual('ક્ર', TypeSequence(Layout, 'kr'), 'r after k becomes a half-form');
    Assert.AreEqual('ક્ખ', TypeSequence(Layout, 'kK'), 'shifted consonants half-form too');
    Assert.AreEqual('ક્ક્સ', TypeSequence(Layout, 'kks'), 'the cluster moves to the new consonant');
  finally
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.AutoHalant_None_AfterVowelOrMatraOrVowelStart;
var
  Layout: TKeyboardLayout;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\gujarati\gujarati_phonetic.json');
  try
    Assert.AreEqual('અક', TypeSequence(Layout, 'ak'),
      'word-start vowel is standalone; the following consonant is fresh');
    Assert.AreEqual('કાક', TypeSequence(Layout, 'kwk'),
      'a matra (other-class direct) ends the cluster; no halant across it');
    Assert.AreEqual('ક્ક', TypeSequence(Layout, 'k\k'),
      'explicit halant path unchanged and produces the same half-form');
  finally
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.AutoHalant_ExplicitHalantStillWorks;
var
  Layout: TKeyboardLayout;
  Events: TStringList;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\gujarati\gujarati_phonetic.json');
  Events := TStringList.Create;
  try
    TypeIntoEvents(Layout, 'k\k', Events);
    // The explicit halant path emits the halant glyph verbatim (cluster
    // ends), then the consonant opens a fresh cluster - same visible output
    // as auto-halant, but through the untouched explicit path.
    Assert.AreEqual('ક', Events[0]);
    Assert.AreEqual('્', Events[1]);
    Assert.AreEqual('ક', Events[2]);
  finally
    Events.Free;
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.AutoHalant_LegacyLayouts_Unaffected;
var
  Layout: TKeyboardLayout;
begin
  // Legacy font-key layouts must keep emitting their strings verbatim.
  Layout := LayoutJson.LoadLayoutFromFile('layouts\devnagari\krutidev_010.json');
  try
    Assert.AreEqual('ds', TypeSequence(Layout, 'ks'),
      'krutidev: k then s keeps the historical "d"+"s" output');
  finally
    Layout.Free;
  end;

  Layout := LayoutJson.LoadLayoutFromFile('layouts\gujarati\remington.json');
  try
    Assert.AreEqual('કક', TypeSequence(Layout, 'kk'),
      'remington: no auto-halant (not a phonetic layout, despite its join_next tag)');
  finally
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.AutoHalant_RequiresPhoneticAndJoinNextTag;
var
  Layout: TKeyboardLayout;
  Events: TStringList;
begin
  // Synthetic phonetic WITHOUT the join_next tag: consonants stay verbatim.
  Layout := CreateSynthetic(True, False, False);
  Events := TStringList.Create;
  try
    TypeIntoEvents(Layout, 'kk', Events);
    Assert.AreEqual(2, Events.Count, 'no join_next tag: no auto-halant');
    Assert.AreEqual('ક', Events[0]);
    Assert.AreEqual('ક', Events[1]);
  finally
    Events.Free;
    Layout.Free;
  end;

  // ...and with the tag present the synthetic layout auto-halants too,
  // proving the rule is data-driven, not tied to the shipped files.
  Layout := CreateSynthetic(True, True, False);
  Events := TStringList.Create;
  try
    TypeIntoEvents(Layout, 'kk', Events);
    Assert.AreEqual(2, Events.Count);
    Assert.AreEqual('્ક', Events[1], 'synthetic phonetic with join_next auto-halants');
  finally
    Events.Free;
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.AutoHalant_HindiLayout;
var
  Layout: TKeyboardLayout;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\hindi\hindi_phonetic.json');
  try
    Assert.AreEqual('क्क', TypeSequence(Layout, 'kk'), 'hindi phonetic: kk gives the half-form');
    Assert.AreEqual('क्य', TypeSequence(Layout, 'ky'), 'hindi phonetic: ky gives the half-form');
  finally
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.InherentVowel_KA_Absorbed;
var
  Layout: TKeyboardLayout;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\gujarati\gujarati_phonetic.json');
  try
    Assert.AreEqual('ક', TypeSequence(Layout, 'ka'),
      'gujarati: the inherent vowel after a consonant is absorbed');
  finally
    Layout.Free;
  end;

  Layout := LayoutJson.LoadLayoutFromFile('layouts\hindi\hindi_phonetic.json');
  try
    Assert.AreEqual('क', TypeSequence(Layout, 'ka'),
      'hindi: the inherent vowel after a consonant is absorbed');
  finally
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.InherentVowel_KAK_TwoFullConsonants;
var
  Layout: TKeyboardLayout;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\gujarati\gujarati_phonetic.json');
  try
    // Absorption ENDS the cluster, so the second k is fresh: two full
    // consonants, no half-form. Contrast kk (B.2) which half-forms.
    Assert.AreEqual('કક', TypeSequence(Layout, 'kak'),
      'absorption closes the cluster; no auto-halant across it');
  finally
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.InherentVowel_NonAbsorbed_Cases;
var
  Layout: TKeyboardLayout;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\gujarati\gujarati_phonetic.json');
  try
    Assert.AreEqual('અ', TypeSequence(Layout, 'a'),
      'word-start a is the standalone vowel');
    Assert.AreEqual('કઆ', TypeSequence(Layout, 'kA'),
      'capital A is the standalone long vowel, never absorbed');
    Assert.AreEqual('કઇ', TypeSequence(Layout, 'ki'),
      'other vowels are never absorbed');
    Assert.AreEqual('કાઅ', TypeSequence(Layout, 'kwa'),
      'DECISION 3: after a matra the cluster is closed; a is standalone again');
  finally
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.InherentVowel_Absorption_LeavesOneBackspaceUnit;
var
  Layout: TKeyboardLayout;
  Events: TStringList;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\gujarati\gujarati_phonetic.json');
  Events := TStringList.Create;
  try
    TypeIntoEvents(Layout, 'ka' + #8, Events);
    // Absorption emits nothing, so the stack holds only the consonant: one
    // backspace deletes it whole.
    Assert.AreEqual(2, Events.Count, 'absorption adds no emission');
    Assert.AreEqual('ક', Events[0]);
    Assert.AreEqual('<bs>', Events[1], 'exactly one backspace unit for ka');
  finally
    Events.Free;
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.InherentVowel_LegacyLayouts_Unaffected;
var
  Layout: TKeyboardLayout;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\devnagari\krutidev_010.json');
  try
    Assert.AreEqual('dv', TypeSequence(Layout, 'ka'),
      'krutidev: a keeps emitting its font-key string verbatim');
  finally
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.InherentVowel_RequiresTheProperty;
var
  Layout: TKeyboardLayout;
  Events: TStringList;
begin
  // Synthetic phonetic WITH classes+join_next but WITHOUT the property:
  // 'a' keeps emitting the standalone vowel (DECISION 2: strict opt-in).
  Layout := CreateSynthetic(True, True, False);
  Events := TStringList.Create;
  try
    TypeIntoEvents(Layout, 'ka', Events);
    Assert.AreEqual(2, Events.Count, 'no inherent_vowel_key property: no absorption');
    Assert.AreEqual('ક', Events[0]);
    Assert.AreEqual('અ', Events[1]);
  finally
    Events.Free;
    Layout.Free;
  end;

  // ...and with the property the synthetic layout absorbs, proving the
  // rule is data-driven, not tied to the shipped files.
  Layout := CreateSynthetic(True, True, True);
  Events := TStringList.Create;
  try
    TypeIntoEvents(Layout, 'ka', Events);
    Assert.AreEqual(1, Events.Count, 'property present: a is absorbed');
    Assert.AreEqual('ક', Events[0]);
  finally
    Events.Free;
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.Reph_RuleName_FallbackStillWorks;
var
  Layout: TKeyboardLayout;
  Events: TStringList;
  KM: TKeyMapping;
begin
  // A legacy-style layout: rule named 'reph', no behavior tag at all.
  Layout := CreateSynthetic(True, False, False);
  KM := Default(TKeyMapping);
  KM.Key := 'R';
  KM.Glyph := 'ર્';
  KM.MapType := 'modifier';
  KM.InitMetadata;
  Layout.Modifiers.Add('reph', KM);
  Layout.DirectMap.AddOrSetValue('d', 'દ');
  Events := TStringList.Create;
  try
    TypeIntoEvents(Layout, 'Rk', Events);
    Assert.AreEqual(2, Events.Count, 'the reph glyph flushes before the consonant');
    Assert.AreEqual('ર્', Events[0]);
    Assert.AreEqual('ક', Events[1]);
  finally
    Events.Free;
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.Reph_BehaviorTag_RenamedRuleWorks;
var
  Layout: TKeyboardLayout;
  Events: TStringList;
  KM: TKeyMapping;
begin
  // A layout that tags the behavior but names the rule differently: the
  // engine must find it by "behavior": "move_to_cluster_start", not by the
  // hardcoded name 'reph'.
  Layout := CreateSynthetic(True, False, False);
  KM := Default(TKeyMapping);
  KM.Key := 'R';
  KM.Glyph := 'ર્';
  KM.MapType := 'move_to_cluster_start';
  KM.InitMetadata;
  Layout.Modifiers.Add('reph_1', KM);
  Layout.DirectMap.AddOrSetValue('d', 'દ');
  Events := TStringList.Create;
  try
    TypeIntoEvents(Layout, 'Rk', Events);
    Assert.AreEqual(2, Events.Count, 'the tagged rule must be found by its behavior');
    Assert.AreEqual('ર્', Events[0]);
    Assert.AreEqual('ક', Events[1]);
  finally
    Events.Free;
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.Reph_TaggedRules_InRealLayouts;
var
  Layout: TKeyboardLayout;
begin
  // Both real reph rules carry the behavior tag; the pending/flush
  // mechanics must be unchanged by the metadata-driven lookup.
  Layout := LayoutJson.LoadLayoutFromFile('layouts\devnagari\krutidev_010.json');
  try
    Assert.AreEqual('dZd', TypeSequence(Layout, 'kZk'),
      'krutidev: reph glyph flushes before the next consonant');
  finally
    Layout.Free;
  end;

  Layout := LayoutJson.LoadLayoutFromFile('layouts\gujarati\remington.json');
  try
    Assert.AreEqual('કર્દ', TypeSequence(Layout, 'kZd'),
      'remington: reph flushes before the next consonant');
  finally
    Layout.Free;
  end;
end;

procedure TPhoneticLayoutTests.Reph_Absent_NoInterference;
var
  Layout: TKeyboardLayout;
  Events: TStringList;
begin
  // No reph rule at all: 'R' is unmatched and passes through natively
  // (no emission), the consonant types normally.
  Layout := CreateSynthetic(True, False, False);
  Events := TStringList.Create;
  try
    TypeIntoEvents(Layout, 'Rk', Events);
    Assert.AreEqual(1, Events.Count, 'an unmatched key must not inject anything');
    Assert.AreEqual('ક', Events[0]);
  finally
    Events.Free;
    Layout.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPhoneticLayoutTests);

end.
