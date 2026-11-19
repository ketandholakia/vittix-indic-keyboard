unit Tests.LayoutEditor.MappingSync;

interface

uses
  DUnitX.TestFramework,
  LayoutModel;

type
  [TestFixture]
  TLayoutEditorMappingSyncTests = class
  private
    function NewMapping(const AKey, AGlyph, AMapType: string): TKeyMapping;
    procedure AddMetadata(var Mapping: TKeyMapping; const AName, AValue: string);
  public
    [Test]
    procedure PrebaseEdit_PreservesMapTypeAndMetadata;
    [Test]
    procedure ModifierEdit_PreservesMultipleMetadataFields;
    [Test]
    procedure Sync_DeletesRemovedMappingAndItsMetadata;
    [Test]
    procedure Sync_NewMappingUsesCollectionDefaultAndEmptyMetadata;
    [Test]
    procedure Sync_ExistingMappingWithoutMetadata_RemainsWithoutMetadata;
    [Test]
    procedure RoundTrip_EditedRichMappingsPreserveSemanticData;

    // Regression coverage for the filtered-grid data loss: applying the rows a
    // search filter leaves on screen must never touch the rows it hides.
    [Test]
    procedure VisibleSync_KeepsEntriesNoVisibleRowOwns;
    [Test]
    procedure VisibleSync_UpdatesOwnedKeyInPlace;
    [Test]
    procedure VisibleSync_DeletesOwnedKeyWhenItsRowIsCleared;
    [Test]
    procedure VisibleKeyedSync_LeavesFilteredOutNamesIntact;
    [Test]
    procedure VisibleKeyedSync_PreservesRichDataOfTouchedName;
    [Test]
    procedure VisibleKeyedSync_DeletesOwnedNameWithoutValue;

    // Item 9.4: the direct_classes section must survive the editor's save and
    // undo/redo serialization (LayoutToJson/LayoutFromJson) and a direct-grid
    // sync performed in between, since the editor edits the model in place.
    [Test]
    procedure DirectClasses_JsonRoundTrip_Preserved;
    [Test]
    procedure DirectClasses_SurvivesVisibleGridSync_AndSave;
    [Test]
    procedure DirectClasses_SyncFromGrid_AddsUpdatesAndDeletes;
  end;

implementation

uses
  System.Generics.Collections,
  LayoutJson,
  LayoutMappingSync;

function TLayoutEditorMappingSyncTests.NewMapping(const AKey, AGlyph,
  AMapType: string): TKeyMapping;
begin
  Result := Default(TKeyMapping);
  Result.Key := AKey;
  Result.Glyph := AGlyph;
  Result.MapType := AMapType;
  Result.InitMetadata;
end;

procedure TLayoutEditorMappingSyncTests.AddMetadata(var Mapping: TKeyMapping;
  const AName, AValue: string);
begin
  Mapping.Metadata.Add(AName, AValue);
end;

procedure TLayoutEditorMappingSyncTests.PrebaseEdit_PreservesMapTypeAndMetadata;
var
  Map: TDictionary<string, TKeyMapping>;
  Mapping: TKeyMapping;
  Edited: TArray<TEditorMapping>;
begin
  Map := TDictionary<string, TKeyMapping>.Create;
  try
    Mapping := NewMapping('f', 'i', 'custom-prebase');
    AddMetadata(Mapping, 'source', 'legacy');
    Map.Add('f', Mapping);
    SetLength(Edited, 1);
    Edited[0].Name := 'f';
    Edited[0].Key := 'f';
    Edited[0].Glyph := 'I';

    SyncPrebaseMappings(Map, Edited);

    Mapping := Map['f'];
    Assert.AreEqual('I', Mapping.Glyph);
    Assert.AreEqual('custom-prebase', Mapping.MapType);
    Assert.AreEqual('legacy', Mapping.Metadata['source']);
  finally
    for Mapping in Map.Values do
      Mapping.FreeMetadata;
    Map.Free;
  end;
end;

procedure TLayoutEditorMappingSyncTests.ModifierEdit_PreservesMultipleMetadataFields;
var
  Map: TDictionary<string, TKeyMapping>;
  Mapping: TKeyMapping;
  Edited: TArray<TEditorMapping>;
begin
  Map := TDictionary<string, TKeyMapping>.Create;
  try
    Mapping := NewMapping('d', 'halant', 'custom-modifier');
    AddMetadata(Mapping, 'source', 'legacy');
    AddMetadata(Mapping, 'priority', 'high');
    Map.Add('halant', Mapping);
    SetLength(Edited, 1);
    Edited[0].Name := 'halant';
    Edited[0].Key := 'd';
    Edited[0].Glyph := 'virama';

    SyncModifierMappings(Map, Edited);

    Mapping := Map['halant'];
    Assert.AreEqual('virama', Mapping.Glyph);
    Assert.AreEqual('custom-modifier', Mapping.MapType);
    Assert.AreEqual('legacy', Mapping.Metadata['source']);
    Assert.AreEqual('high', Mapping.Metadata['priority']);
  finally
    for Mapping in Map.Values do
      Mapping.FreeMetadata;
    Map.Free;
  end;
end;

procedure TLayoutEditorMappingSyncTests.Sync_DeletesRemovedMappingAndItsMetadata;
var
  Map: TDictionary<string, TKeyMapping>;
  Mapping: TKeyMapping;
  Edited: TArray<TEditorMapping>;
begin
  Map := TDictionary<string, TKeyMapping>.Create;
  try
    Mapping := NewMapping('f', 'i', 'prebase');
    AddMetadata(Mapping, 'source', 'removed');
    Map.Add('f', Mapping);
    SetLength(Edited, 0);

    SyncPrebaseMappings(Map, Edited);

    Assert.IsFalse(Map.ContainsKey('f'));
  finally
    for Mapping in Map.Values do
      Mapping.FreeMetadata;
    Map.Free;
  end;
end;

procedure TLayoutEditorMappingSyncTests.Sync_NewMappingUsesCollectionDefaultAndEmptyMetadata;
var
  Map: TDictionary<string, TKeyMapping>;
  Mapping: TKeyMapping;
  Edited: TArray<TEditorMapping>;
begin
  Map := TDictionary<string, TKeyMapping>.Create;
  try
    SetLength(Edited, 1);
    Edited[0].Name := 'f';
    Edited[0].Key := 'f';
    Edited[0].Glyph := 'i';

    SyncPrebaseMappings(Map, Edited);

    Mapping := Map['f'];
    Assert.AreEqual('prebase', Mapping.MapType);
    Assert.IsNotNull(Mapping.Metadata);
    Assert.AreEqual(0, Mapping.Metadata.Count);
  finally
    for Mapping in Map.Values do
      Mapping.FreeMetadata;
    Map.Free;
  end;
end;

procedure TLayoutEditorMappingSyncTests.Sync_ExistingMappingWithoutMetadata_RemainsWithoutMetadata;
var
  Map: TDictionary<string, TKeyMapping>;
  Mapping: TKeyMapping;
  Edited: TArray<TEditorMapping>;
begin
  Map := TDictionary<string, TKeyMapping>.Create;
  try
    Mapping := Default(TKeyMapping);
    Mapping.Key := 'f';
    Mapping.Glyph := 'i';
    Mapping.MapType := 'legacy-prebase';
    Map.Add('f', Mapping);
    SetLength(Edited, 1);
    Edited[0].Name := 'f';
    Edited[0].Key := 'f';
    Edited[0].Glyph := 'I';

    SyncPrebaseMappings(Map, Edited);

    Mapping := Map['f'];
    Assert.AreEqual('I', Mapping.Glyph);
    Assert.AreEqual('legacy-prebase', Mapping.MapType);
    Assert.IsNull(Mapping.Metadata);
  finally
    for Mapping in Map.Values do
      Mapping.FreeMetadata;
    Map.Free;
  end;
end;

procedure TLayoutEditorMappingSyncTests.RoundTrip_EditedRichMappingsPreserveSemanticData;
var
  Layout, Reloaded: TKeyboardLayout;
  Mapping: TKeyMapping;
  PrebaseEdits, ModifierEdits: TArray<TEditorMapping>;
  Json: string;
begin
  Layout := TKeyboardLayout.Create;
  try
    Mapping := NewMapping('f', 'i', 'legacy-prebase');
    AddMetadata(Mapping, 'source', 'imported');
    Layout.PrebaseMap.Add('f', Mapping);
    Mapping := NewMapping('d', 'halant', 'legacy-modifier');
    AddMetadata(Mapping, 'source', 'imported');
    AddMetadata(Mapping, 'priority', 'high');
    Layout.Modifiers.Add('halant', Mapping);

    SetLength(PrebaseEdits, 1);
    PrebaseEdits[0].Name := 'f';
    PrebaseEdits[0].Key := 'f';
    PrebaseEdits[0].Glyph := 'I';
    SetLength(ModifierEdits, 1);
    ModifierEdits[0].Name := 'halant';
    ModifierEdits[0].Key := 'd';
    ModifierEdits[0].Glyph := 'virama';
    SyncPrebaseMappings(Layout.PrebaseMap, PrebaseEdits);
    SyncModifierMappings(Layout.Modifiers, ModifierEdits);

    Json := LayoutToJson(Layout);
    Reloaded := LayoutFromJson(Json);
    try
      Mapping := Reloaded.PrebaseMap['f'];
      Assert.AreEqual('I', Mapping.Glyph);
      Assert.AreEqual('legacy-prebase', Mapping.MapType);
      Assert.AreEqual('imported', Mapping.Metadata['source']);
      Mapping := Reloaded.Modifiers['halant'];
      Assert.AreEqual('virama', Mapping.Glyph);
      Assert.AreEqual('legacy-modifier', Mapping.MapType);
      Assert.AreEqual('imported', Mapping.Metadata['source']);
      Assert.AreEqual('high', Mapping.Metadata['priority']);
    finally
      Reloaded.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutEditorMappingSyncTests.VisibleSync_KeepsEntriesNoVisibleRowOwns;
var
  Map: TDictionary<string, string>;
  Rows: TArray<TStringMappingRow>;
  Owned: TArray<string>;
begin
  Map := TDictionary<string, string>.Create;
  try
    Map.Add('k', 'v');
    Map.Add('g', 'h');
    Map.Add('z', 'x');

    // The grid is filtered down to "k" only, and the user edits that one row.
    SetLength(Rows, 1);
    Rows[0].Key := 'k';
    Rows[0].Value := 'V';
    SetLength(Owned, 1);
    Owned[0] := 'k';

    SyncVisibleStringMap(Map, Rows, Owned);

    Assert.AreEqual(3, Map.Count);
    Assert.AreEqual('V', Map['k']);
    Assert.AreEqual('h', Map['g']);
    Assert.AreEqual('x', Map['z']);
  finally
    Map.Free;
  end;
end;

procedure TLayoutEditorMappingSyncTests.VisibleSync_UpdatesOwnedKeyInPlace;
var
  Map: TDictionary<string, string>;
  Rows: TArray<TStringMappingRow>;
  Owned: TArray<string>;
begin
  Map := TDictionary<string, string>.Create;
  try
    Map.Add('k', 'v');
    SetLength(Rows, 1);
    Rows[0].Key := 'k';
    Rows[0].Value := 'new';
    SetLength(Owned, 1);
    Owned[0] := 'k';

    SyncVisibleStringMap(Map, Rows, Owned);

    Assert.AreEqual(1, Map.Count);
    Assert.AreEqual('new', Map['k']);
  finally
    Map.Free;
  end;
end;

procedure TLayoutEditorMappingSyncTests.VisibleSync_DeletesOwnedKeyWhenItsRowIsCleared;
var
  Map: TDictionary<string, string>;
  Rows: TArray<TStringMappingRow>;
  Owned: TArray<string>;
begin
  Map := TDictionary<string, string>.Create;
  try
    Map.Add('k', 'v');
    Map.Add('g', 'h');

    // "k" is on screen and its glyph was cleared; "g" is hidden by the filter.
    SetLength(Rows, 1);
    Rows[0].Key := 'k';
    Rows[0].Value := '';
    SetLength(Owned, 1);
    Owned[0] := 'k';

    SyncVisibleStringMap(Map, Rows, Owned);

    Assert.AreEqual(1, Map.Count);
    Assert.IsFalse(Map.ContainsKey('k'));
    Assert.AreEqual('h', Map['g']);
  finally
    Map.Free;
  end;
end;

procedure TLayoutEditorMappingSyncTests.VisibleKeyedSync_LeavesFilteredOutNamesIntact;
var
  Map: TDictionary<string, TKeyMapping>;
  Mapping: TKeyMapping;
  Edited: TArray<TEditorMapping>;
  Owned: TArray<string>;
begin
  Map := TDictionary<string, TKeyMapping>.Create;
  try
    Mapping := NewMapping('f', 'i', 'legacy-prebase');
    Map.Add('f', Mapping);
    Mapping := NewMapping('g', 'u', 'legacy-prebase');
    Map.Add('g', Mapping);

    // Filter shows only "f".
    SetLength(Edited, 1);
    Edited[0].Name := 'f';
    Edited[0].Key := 'f';
    Edited[0].Glyph := 'I';
    SetLength(Owned, 1);
    Owned[0] := 'f';

    SyncVisibleMappings(Map, Edited, Owned, 'prebase');

    Assert.AreEqual(2, Map.Count);
    Assert.AreEqual('I', Map['f'].Glyph);
    Assert.AreEqual('u', Map['g'].Glyph);
  finally
    for Mapping in Map.Values do
      Mapping.FreeMetadata;
    Map.Free;
  end;
end;

procedure TLayoutEditorMappingSyncTests.VisibleKeyedSync_PreservesRichDataOfTouchedName;
var
  Map: TDictionary<string, TKeyMapping>;
  Mapping: TKeyMapping;
  Edited: TArray<TEditorMapping>;
  Owned: TArray<string>;
begin
  Map := TDictionary<string, TKeyMapping>.Create;
  try
    Mapping := NewMapping('f', 'i', 'custom-prebase');
    AddMetadata(Mapping, 'source', 'legacy');
    Map.Add('f', Mapping);

    SetLength(Edited, 1);
    Edited[0].Name := 'f';
    Edited[0].Key := 'f';
    Edited[0].Glyph := 'I';
    SetLength(Owned, 1);
    Owned[0] := 'f';

    SyncVisibleMappings(Map, Edited, Owned, 'prebase');

    Mapping := Map['f'];
    Assert.AreEqual('I', Mapping.Glyph);
    Assert.AreEqual('custom-prebase', Mapping.MapType);
    Assert.AreEqual('legacy', Mapping.Metadata['source']);
  finally
    for Mapping in Map.Values do
      Mapping.FreeMetadata;
    Map.Free;
  end;
end;

procedure TLayoutEditorMappingSyncTests.VisibleKeyedSync_DeletesOwnedNameWithoutValue;
var
  Map: TDictionary<string, TKeyMapping>;
  Mapping: TKeyMapping;
  Edited: TArray<TEditorMapping>;
  Owned: TArray<string>;
begin
  Map := TDictionary<string, TKeyMapping>.Create;
  try
    Mapping := NewMapping('f', 'i', 'prebase');
    AddMetadata(Mapping, 'source', 'removed');
    Map.Add('f', Mapping);
    Mapping := NewMapping('g', 'u', 'prebase');
    Map.Add('g', Mapping);

    // Only "f" is on screen and it was cleared.
    SetLength(Edited, 0);
    SetLength(Owned, 1);
    Owned[0] := 'f';

    SyncVisibleMappings(Map, Edited, Owned, 'prebase');

    Assert.AreEqual(1, Map.Count);
    Assert.IsFalse(Map.ContainsKey('f'));
    Assert.AreEqual('u', Map['g'].Glyph);
  finally
    for Mapping in Map.Values do
      Mapping.FreeMetadata;
    Map.Free;
  end;
end;

procedure TLayoutEditorMappingSyncTests.DirectClasses_JsonRoundTrip_Preserved;
var
  Layout, Reloaded: TKeyboardLayout;
  Json: string;
begin
  Layout := TKeyboardLayout.Create;
  try
    Layout.DirectMap.Add('k', 'K');
    Layout.DirectMap.Add('a', 'AVowel');
    Layout.DirectClasses.Add('k', 'consonant');
    Layout.DirectClasses.Add('a', 'vowel');

    Json := LayoutToJson(Layout);
    Reloaded := LayoutFromJson(Json);
    try
      Assert.AreEqual('consonant', Reloaded.DirectClasses['k'],
        'direct_classes must survive LayoutToJson/LayoutFromJson');
      Assert.AreEqual('vowel', Reloaded.DirectClasses['a']);
      Assert.AreEqual(2, Reloaded.DirectClasses.Count);
    finally
      Reloaded.Free;
    end;
  finally
    Layout.Free;
  end;
end;

// The editor keeps the layout object in memory, syncs the visible grid rows
// into it, and serializes the WHOLE model on save — so an unrelated grid edit
// must not disturb the direct_classes metadata.
procedure TLayoutEditorMappingSyncTests.DirectClasses_SurvivesVisibleGridSync_AndSave;
var
  Layout, Reloaded: TKeyboardLayout;
  Rows: TArray<TStringMappingRow>;
  Owned: TArray<string>;
  Json: string;
begin
  Layout := TKeyboardLayout.Create;
  try
    Layout.DirectMap.Add('k', 'K');
    Layout.DirectMap.Add('a', 'AVowel');
    Layout.DirectClasses.Add('k', 'consonant');
    Layout.DirectClasses.Add('a', 'vowel');

    // The user edits the 'k' row in the Direct grid (filtered view).
    SetLength(Rows, 1);
    Rows[0].Key := 'k';
    Rows[0].Value := 'KK';
    SetLength(Owned, 1);
    Owned[0] := 'k';
    SyncVisibleStringMap(Layout.DirectMap, Rows, Owned);

    Json := LayoutToJson(Layout);
    Reloaded := LayoutFromJson(Json);
    try
      Assert.AreEqual('KK', Reloaded.DirectMap['k'], 'the grid edit applied');
      Assert.AreEqual('vowel', Reloaded.DirectClasses['a'],
        'direct_classes must survive a grid edit plus save');
      Assert.AreEqual('consonant', Reloaded.DirectClasses['k']);
    finally
      Reloaded.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutEditorMappingSyncTests.DirectClasses_SyncFromGrid_AddsUpdatesAndDeletes;
var
  Classes: TDictionary<string, string>;
  Rows: TArray<TStringMappingRow>;
  Owned: TArray<string>;
begin
  Classes := TDictionary<string, string>.Create;
  try
    Classes.Add('k', 'consonant');
    Classes.Add('t', 'consonant');
    Classes.Add('a', 'vowel');

    // Grid currently displays 'k' (modified to vowel), 't' (cleared class), 's' (newly classified)
    // while 'a' is filtered out.
    SetLength(Owned, 3);
    Owned[0] := 'k';
    Owned[1] := 't';
    Owned[2] := 's';

    SetLength(Rows, 3);
    Rows[0].Key := 'k';
    Rows[0].Value := 'vowel';       // update
    Rows[1].Key := 't';
    Rows[1].Value := '';            // deletion from direct_classes
    Rows[2].Key := 's';
    Rows[2].Value := 'consonant';    // addition

    SyncVisibleStringMap(Classes, Rows, Owned);

    Assert.AreEqual('vowel', Classes['k'], 'k class was updated to vowel');
    Assert.IsFalse(Classes.ContainsKey('t'), 't was cleared so it was removed from direct_classes');
    Assert.AreEqual('consonant', Classes['s'], 's was added to direct_classes');
    Assert.AreEqual('vowel', Classes['a'], 'filtered-out a was preserved untouched');
  finally
    Classes.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLayoutEditorMappingSyncTests);

end.
