unit Tests.Shared.LayoutResolver;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Generics.Collections,
  LayoutModel,
  LayoutResolver;

type
  [TestFixture]
  TLayoutResolverTests = class
  public
    [Test]
    procedure Resolve_DirectWinsOverLowerSections;
    [Test]
    procedure Resolve_ReportsSourcePerSection;
    [Test]
    procedure Resolve_EmptyKeyOrNilLayout_ReturnsNothing;
    [Test]
    procedure Resolve_ModifierWithNonStandardName_StillResolves;
    [Test]
    procedure Resolve_ModifierNameIsReported;
    [Test]
    procedure Resolve_EmptyGlyph_IsNotReportedAsFound;
    [Test]
    procedure GlyphFor_MatchesResolve;
    [Test]
    procedure Redefinitions_FlagsKeyDefinedInTwoSections;
    [Test]
    procedure Redefinitions_IsEmptyForCleanLayout;
    [Test]
    procedure IsRedefined_TrueForShadowedKey_FalseForUniqueKey;
    [Test]
    procedure SourceLabel_NamesEverySource;
    [Test]
    procedure SectionCount_CountsDistinctSections;
  end;

implementation

{ --------------------------------------------------
  helpers
-------------------------------------------------- }

function NewModifier(const Key, Glyph, MapType: string): TKeyMapping;
begin
  Result := Default(TKeyMapping);
  Result.Key := Key;
  Result.Glyph := Glyph;
  Result.MapType := MapType;
  Result.InitMetadata;
end;

{ --------------------------------------------------
  Resolve
-------------------------------------------------- }

procedure TLayoutResolverTests.Resolve_DirectWinsOverLowerSections;
var
  Layout: TKeyboardLayout;
  Resolved: TResolvedGlyph;
begin
  Layout := TKeyboardLayout.Create;
  try
    // The same key defined in every section. Direct has the highest precedence.
    Layout.DirectMap.Add('k', 'DIRECT');
    Layout.PrebaseMap.Add('k', NewModifier('k', 'PREBASE', 'prebase'));
    Layout.PostbaseMap.Add('k', 'POSTBASE');
    Layout.Modifiers.Add('halant', NewModifier('k', 'MODIFIER', 'modifier'));

    Resolved := TLayoutResolver.Resolve(Layout, 'k');

    Assert.AreEqual('DIRECT', Resolved.Glyph);
    Assert.AreEqual(msDirect, Resolved.Source);
  finally
    Layout.Free;
  end;
end;

procedure TLayoutResolverTests.Resolve_ReportsSourcePerSection;
var
  Layout: TKeyboardLayout;
begin
  Layout := TKeyboardLayout.Create;
  try
    Layout.DirectMap.Add('a', 'A');
    Layout.PrebaseMap.Add('b', NewModifier('b', 'B', 'prebase'));
    Layout.PostbaseMap.Add('c', 'C');
    Layout.Modifiers.Add('halant', NewModifier('d', 'D', 'modifier'));

    Assert.AreEqual(msDirect, TLayoutResolver.Resolve(Layout, 'a').Source);
    Assert.AreEqual(msPrebase, TLayoutResolver.Resolve(Layout, 'b').Source);
    Assert.AreEqual(msPostbase, TLayoutResolver.Resolve(Layout, 'c').Source);
    Assert.AreEqual(msModifier, TLayoutResolver.Resolve(Layout, 'd').Source);
    Assert.AreEqual(msNone, TLayoutResolver.Resolve(Layout, 'zz').Source);
  finally
    Layout.Free;
  end;
end;

procedure TLayoutResolverTests.Resolve_EmptyKeyOrNilLayout_ReturnsNothing;
begin
  Assert.IsFalse(TLayoutResolver.Resolve(nil, 'k').Found);
  Assert.AreEqual('', TLayoutResolver.Resolve(nil, 'k').Glyph);

  var Layout := TKeyboardLayout.Create;
  try
    Layout.DirectMap.Add('k', 'K');
    Assert.IsFalse(TLayoutResolver.Resolve(Layout, '').Found);
    Assert.IsFalse(TLayoutResolver.Resolve(Layout, '   ').Found);
  finally
    Layout.Free;
  end;
end;

procedure TLayoutResolverTests.Resolve_ModifierWithNonStandardName_StillResolves;
var
  Layout: TKeyboardLayout;
  Resolved: TResolvedGlyph;
begin
  // Regression: two of the three previous copies looked the modifier up by the
  // literal name 'halant', so any layout naming it differently stopped drawing.
  Layout := TKeyboardLayout.Create;
  try
    Layout.Modifiers.Add('virama', NewModifier('\', 'VIRAMA', 'modifier'));

    Resolved := TLayoutResolver.Resolve(Layout, '\');

    Assert.AreEqual('VIRAMA', Resolved.Glyph);
    Assert.AreEqual(msModifier, Resolved.Source);
  finally
    Layout.Free;
  end;
end;

procedure TLayoutResolverTests.Resolve_ModifierNameIsReported;
var
  Layout: TKeyboardLayout;
  Resolved: TResolvedGlyph;
begin
  Layout := TKeyboardLayout.Create;
  try
    Layout.Modifiers.Add('reph', NewModifier('r', 'REPH', 'modifier'));

    Resolved := TLayoutResolver.Resolve(Layout, 'r');

    Assert.AreEqual('reph', Resolved.ModifierName);
    Assert.AreEqual('Modifiers (reph)', Resolved.SourceLabel);
  finally
    Layout.Free;
  end;
end;

procedure TLayoutResolverTests.Resolve_EmptyGlyph_IsNotReportedAsFound;
var
  Layout: TKeyboardLayout;
  Resolved: TResolvedGlyph;
begin
  Layout := TKeyboardLayout.Create;
  try
    Layout.PrebaseMap.Add('f', NewModifier('f', '', 'prebase'));

    Resolved := TLayoutResolver.Resolve(Layout, 'f');

    Assert.AreEqual(msPrebase, Resolved.Source);
    Assert.IsFalse(Resolved.Found, 'an empty glyph must not count as a mapping');
  finally
    Layout.Free;
  end;
end;

procedure TLayoutResolverTests.GlyphFor_MatchesResolve;
var
  Layout: TKeyboardLayout;
begin
  Layout := TKeyboardLayout.Create;
  try
    Layout.PostbaseMap.Add('c', 'C');
    Assert.AreEqual(TLayoutResolver.Resolve(Layout, 'c').Glyph,
      TLayoutResolver.GlyphFor(Layout, 'c'));
    Assert.AreEqual('C', TLayoutResolver.GlyphFor(Layout, 'c'));
  finally
    Layout.Free;
  end;
end;

{ --------------------------------------------------
  Redefinitions
-------------------------------------------------- }

procedure TLayoutResolverTests.Redefinitions_FlagsKeyDefinedInTwoSections;
var
  Layout: TKeyboardLayout;
  Index: TDictionary<string, TMappingSourceSet>;
  Sections: TMappingSourceSet;
begin
  Layout := TKeyboardLayout.Create;
  try
    Layout.DirectMap.Add('f', 'DIRECT-F');
    Layout.PrebaseMap.Add('f', NewModifier('f', 'PREBASE-F', 'prebase'));
    Layout.DirectMap.Add('unique', 'U');

    Index := TLayoutResolver.Redefinitions(Layout);
    try
      Assert.IsTrue(Index.TryGetValue('f', Sections));
      Assert.IsTrue(msDirect in Sections);
      Assert.IsTrue(msPrebase in Sections);
      Assert.AreEqual(2, TLayoutResolver.SectionCount(Sections));
      Assert.IsFalse(Index.ContainsKey('unique'), 'a singly-defined key is not a redefinition');
    finally
      Index.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutResolverTests.Redefinitions_IsEmptyForCleanLayout;
var
  Layout: TKeyboardLayout;
  Index: TDictionary<string, TMappingSourceSet>;
begin
  Layout := TKeyboardLayout.Create;
  try
    Layout.DirectMap.Add('a', 'A');
    Layout.PrebaseMap.Add('b', NewModifier('b', 'B', 'prebase'));
    Layout.PostbaseMap.Add('c', 'C');
    Layout.Modifiers.Add('halant', NewModifier('d', 'D', 'modifier'));

    Index := TLayoutResolver.Redefinitions(Layout);
    try
      Assert.AreEqual(0, Index.Count);
    finally
      Index.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutResolverTests.IsRedefined_TrueForShadowedKey_FalseForUniqueKey;
var
  Layout: TKeyboardLayout;
begin
  Layout := TKeyboardLayout.Create;
  try
    Layout.DirectMap.Add('f', 'A');
    Layout.Modifiers.Add('halant', NewModifier('f', 'B', 'modifier'));
    Layout.DirectMap.Add('solo', 'S');

    Assert.IsTrue(TLayoutResolver.IsRedefined(Layout, 'f'));
    Assert.IsFalse(TLayoutResolver.IsRedefined(Layout, 'solo'));
    Assert.IsFalse(TLayoutResolver.IsRedefined(Layout, ''));
    Assert.IsFalse(TLayoutResolver.IsRedefined(nil, 'f'));
  finally
    Layout.Free;
  end;
end;

{ --------------------------------------------------
  SourceLabel / SectionCount
-------------------------------------------------- }

procedure TLayoutResolverTests.SourceLabel_NamesEverySource;
begin
  Assert.AreEqual('Direct', TLayoutResolver.SourceLabel(msDirect));
  Assert.AreEqual('Prebase', TLayoutResolver.SourceLabel(msPrebase));
  Assert.AreEqual('Postbase', TLayoutResolver.SourceLabel(msPostbase));
  Assert.AreEqual('Modifiers', TLayoutResolver.SourceLabel(msModifier));
  Assert.AreEqual('not mapped', TLayoutResolver.SourceLabel(msNone));
end;

procedure TLayoutResolverTests.SectionCount_CountsDistinctSections;
begin
  Assert.AreEqual(0, TLayoutResolver.SectionCount([]));
  Assert.AreEqual(1, TLayoutResolver.SectionCount([msDirect]));
  Assert.AreEqual(2, TLayoutResolver.SectionCount([msDirect, msPostbase]));
  Assert.AreEqual(4, TLayoutResolver.SectionCount([msDirect, msPrebase, msPostbase, msModifier]));
end;

end.
