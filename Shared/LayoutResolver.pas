unit LayoutResolver;

{ Single source of truth for "which glyph does this key produce, and where does it
  come from".

  Before this unit the resolution order was implemented three times:

    Shared/VittixKeyboardView.pas       generic modifier scan  (correct)
    LayoutEditor/UI/KeyboardPainter.pas hardcoded 'halant' and 'reph' by name
    Keyboard/Forms/frmOnScreenKeyboard.pas hardcoded 'halant' and 'reph' by name

  The two hardcoded copies silently stopped rendering any layout that named its
  modifiers differently, because they looked up the modifier dictionary by the
  literal key 'halant' rather than scanning for a modifier whose Key matches.

  Resolution order, highest precedence first:

    1. DirectMap      exact key match
    2. PrebaseMap     exact key match, value is the glyph
    3. PostbaseMap    exact key match
    4. Modifiers      any modifier whose Key matches, matched case-insensitively

  A later section never overrides an earlier one; it is shadowed. Redefinitions
  reports those cases so the editor can warn instead of writing a direct entry
  that quietly overrides a matra.
}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  LayoutModel;

type
  TMappingSource = (msNone, msDirect, msPrebase, msPostbase, msModifier);

  TMappingSourceSet = set of TMappingSource;

  TResolvedGlyph = record
    Glyph: string;
    Source: TMappingSource;
    // The modifier's own name when Source is msModifier, otherwise empty.
    ModifierName: string;
    function Found: Boolean;
    function SourceLabel: string;
  end;

  TLayoutResolver = class
  public
    // Resolution for a single key. Never raises; a nil layout or an empty key
    // returns an empty result.
    class function Resolve(const Layout: TKeyboardLayout;
      const Key: string): TResolvedGlyph; static;

    // Convenience for callers that only paint the glyph.
    class function GlyphFor(const Layout: TKeyboardLayout;
      const Key: string): string; static;

    // Every key that is defined in more than one section, mapped to the set of
    // sections that define it. Computed once per call; callers that need it
    // while painting should cache it. Keys defined in a single section are not
    // included, so every entry is a conflict.
    class function Redefinitions(const Layout: TKeyboardLayout)
      : TDictionary<string, TMappingSourceSet>; static;

    // True when the key is defined in more than one section.
    class function IsRedefined(const Layout: TKeyboardLayout;
      const Key: string): Boolean; static;

    // Human-readable name of a source, e.g. 'Direct' or 'Modifiers (reph)'.
    class function SourceLabel(Source: TMappingSource): string; static;

    // Number of sections that define a key. More than one means it is shadowed.
    class function SectionCount(Sections: TMappingSourceSet): Integer; static;
  end;

implementation

{ --------------------------------------------------
  TResolvedGlyph
-------------------------------------------------- }

function TResolvedGlyph.Found: Boolean;
begin
  Result := (Source <> msNone) and (Glyph <> '');
end;

function TResolvedGlyph.SourceLabel: string;
begin
  Result := TLayoutResolver.SourceLabel(Source);
  if (Source = msModifier) and (ModifierName <> '') then
    Result := Result + ' (' + ModifierName + ')';
end;

{ --------------------------------------------------
  TLayoutResolver
-------------------------------------------------- }

class function TLayoutResolver.Resolve(const Layout: TKeyboardLayout;
  const Key: string): TResolvedGlyph;
var
  Matra: TKeyMapping;
  Entry: TPair<string, TKeyMapping>;
  Trimmed: string;
begin
  Result := Default(TResolvedGlyph);

  if (Layout = nil) then
    Exit;

  Trimmed := Trim(Key);
  if Trimmed = '' then
    Exit;

  if Layout.DirectMap.TryGetValue(Trimmed, Result.Glyph) then
  begin
    Result.Source := msDirect;
    Exit;
  end;

  if Layout.PrebaseMap.TryGetValue(Trimmed, Matra) then
  begin
    Result.Glyph := Matra.Glyph;
    Result.Source := msPrebase;
    Exit;
  end;

  if Layout.PostbaseMap.TryGetValue(Trimmed, Result.Glyph) then
  begin
    Result.Source := msPostbase;
    Exit;
  end;

  // Scan every modifier rather than looking up a fixed name, so renaming or
  // adding a modifier keeps rendering.
  for Entry in Layout.Modifiers do
    if SameText(Entry.Value.Key, Trimmed) and (Entry.Value.Glyph <> '') then
    begin
      Result.Glyph := Entry.Value.Glyph;
      Result.Source := msModifier;
      Result.ModifierName := Entry.Key;
      Exit;
    end;
end;

class function TLayoutResolver.GlyphFor(const Layout: TKeyboardLayout;
  const Key: string): string;
begin
  Result := Resolve(Layout, Key).Glyph;
end;

class function TLayoutResolver.Redefinitions(const Layout: TKeyboardLayout)
  : TDictionary<string, TMappingSourceSet>;
var
  Matra: TKeyMapping;
  Entry: TPair<string, TKeyMapping>;
  Single: TPair<string, string>;
  Conflict: TPair<string, TMappingSourceSet>;
  Source: TMappingSourceSet;
  Conflicts: TList<string>;
  Key: string;

  procedure Note(const Key: string; const Which: TMappingSource);
  begin
    if Key = '' then
      Exit;
    if Result.TryGetValue(Key, Source) then
    begin
      Include(Source, Which);
      Result.AddOrSetValue(Key, Source);
    end
    else
    begin
      Source := [Which];
      Result.Add(Key, Source);
    end;
  end;

begin
  Result := TDictionary<string, TMappingSourceSet>.Create;
  if Layout = nil then
    Exit;

  for Single in Layout.DirectMap do
    Note(Single.Key, msDirect);

  for Matra in Layout.PrebaseMap.Values do
    Note(Matra.Key, msPrebase);

  for Single in Layout.PostbaseMap do
    Note(Single.Key, msPostbase);

  for Entry in Layout.Modifiers do
    Note(Entry.Value.Key, msModifier);

  // Drop everything only one section defines; the caller wants conflicts.
  Conflicts := TList<string>.Create;
  try
    for Conflict in Result do
      if SectionCount(Conflict.Value) < 2 then
        Conflicts.Add(Conflict.Key);
    for Key in Conflicts do
      Result.Remove(Key);
  finally
    Conflicts.Free;
  end;
end;

class function TLayoutResolver.SectionCount(Sections: TMappingSourceSet): Integer;
var
  S: TMappingSource;
begin
  Result := 0;
  for S := msDirect to msModifier do
    if S in Sections then
      Inc(Result);
end;

class function TLayoutResolver.IsRedefined(const Layout: TKeyboardLayout;
  const Key: string): Boolean;
var
  Index: TDictionary<string, TMappingSourceSet>;
  Sections: TMappingSourceSet;
begin
  Result := False;
  if (Layout = nil) or (Trim(Key) = '') then
    Exit;

  Index := Redefinitions(Layout);
  try
    if Index.TryGetValue(Trim(Key), Sections) then
      Result := SectionCount(Sections) > 1;
  finally
    Index.Free;
  end;
end;

class function TLayoutResolver.SourceLabel(Source: TMappingSource): string;
begin
  case Source of
    msDirect: Result := 'Direct';
    msPrebase: Result := 'Prebase';
    msPostbase: Result := 'Postbase';
    msModifier: Result := 'Modifiers';
  else
    Result := 'not mapped';
  end;
end;

end.
