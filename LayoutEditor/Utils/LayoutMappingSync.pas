unit LayoutMappingSync;

interface

uses
  System.Generics.Collections,
  LayoutModel;

type
  // Values represented by the editor grids.  MapType and Metadata deliberately
  // do not appear here: the grids do not own or edit those fields.
  TEditorMapping = record
    Name: string;
    Key: string;
    Glyph: string;
  end;

  // A row of a key/value grid such as Direct, Postbase or Sequences.
  TStringMappingRow = record
    Key: string;
    Value: string;
  end;

procedure SyncPrebaseMappings(const Map: TDictionary<string, TKeyMapping>;
  const EditedMappings: TArray<TEditorMapping>);
procedure SyncModifierMappings(const Map: TDictionary<string, TKeyMapping>;
  const EditedMappings: TArray<TEditorMapping>);

{ Ownership-scoped sync.

  The editor grids are rewritten whenever a search filter is applied, so the
  rows on screen are a subset of the model.  The whole-collection sync above
  treats "not on screen" as "deleted", which silently destroys every mapping a
  filter hides.  The two routines below only ever touch the names the visible
  rows are responsible for:

    * OwnedKeys[i] is the model name that grid row i represented before this
      edit, or '' for a row the user just added.
    * A name a visible row used to own but no longer supplies a value for is
      deleted.  Everything else is left exactly as it was.                                     }

procedure SyncVisibleStringMap(Map: TDictionary<string, string>;
  const Rows: TArray<TStringMappingRow>; const OwnedKeys: TArray<string>);

procedure SyncVisibleMappings(Map: TDictionary<string, TKeyMapping>;
  const EditedMappings: TArray<TEditorMapping>; const OwnedKeys: TArray<string>;
  const DefaultMapType: string);

implementation

uses
  System.SysUtils,
  System.Generics.Defaults;

procedure RemoveDeletedMappings(const Map: TDictionary<string, TKeyMapping>;
  const RetainedNames: TDictionary<string, Boolean>);
var
  Name: string;
  Mapping: TKeyMapping;
  DeletedNames: TList<string>;
begin
  DeletedNames := TList<string>.Create;
  try
    for Name in Map.Keys do
      if not RetainedNames.ContainsKey(Name) then
        DeletedNames.Add(Name);

    for Name in DeletedNames do
    begin
      Mapping := Map[Name];
      // TKeyMapping.Metadata is manually owned by the layout; dictionary
      // removal alone will not release it.
      Mapping.FreeMetadata;
      Map.Remove(Name);
    end;
  finally
    DeletedNames.Free;
  end;
end;

procedure SyncMappings(const Map: TDictionary<string, TKeyMapping>;
  const EditedMappings: TArray<TEditorMapping>; const DefaultMapType: string);
var
  Edited: TEditorMapping;
  Mapping: TKeyMapping;
  RetainedNames: TDictionary<string, Boolean>;
begin
  RetainedNames := TDictionary<string, Boolean>.Create;
  try
    for Edited in EditedMappings do
    begin
      RetainedNames.AddOrSetValue(Edited.Name, True);
      if Map.TryGetValue(Edited.Name, Mapping) then
      begin
        // Preserve MapType and the existing Metadata dictionary.  Updating a
        // value in the dictionary copies only the record, not its ownership.
        Mapping.Key := Edited.Key;
        Mapping.Glyph := Edited.Glyph;
      end
      else
      begin
        Mapping := Default(TKeyMapping);
        Mapping.Key := Edited.Key;
        Mapping.Glyph := Edited.Glyph;
        Mapping.MapType := DefaultMapType;
        Mapping.InitMetadata;
      end;
      Map.AddOrSetValue(Edited.Name, Mapping);
    end;

    RemoveDeletedMappings(Map, RetainedNames);
  finally
    RetainedNames.Free;
  end;
end;

procedure SyncPrebaseMappings(const Map: TDictionary<string, TKeyMapping>;
  const EditedMappings: TArray<TEditorMapping>);
begin
  SyncMappings(Map, EditedMappings, 'prebase');
end;

procedure SyncModifierMappings(const Map: TDictionary<string, TKeyMapping>;
  const EditedMappings: TArray<TEditorMapping>);
begin
  SyncMappings(Map, EditedMappings, 'modifier');
end;

procedure SyncVisibleStringMap(Map: TDictionary<string, string>;
  const Rows: TArray<TStringMappingRow>; const OwnedKeys: TArray<string>);
var
  Work: TDictionary<string, string>;
  Pair: TPair<string, string>;
  Name, RowKey: string;
  I: Integer;
  StillSupplied: Boolean;
begin
  Work := TDictionary<string, string>.Create;
  try
    // Start from the full model so nothing a filter hides can be lost.
    for Pair in Map do
      Work.AddOrSetValue(Pair.Key, Pair.Value);

    // Apply the rows that are on screen.
    for I := 0 to High(Rows) do
      if (Rows[I].Key <> '') and (Rows[I].Value <> '') then
        Work.AddOrSetValue(Rows[I].Key, Rows[I].Value);

    // A name a visible row owned, and no longer supplies a value for, is a
    // deletion.  Names owned by rows that are filtered out are untouched.
    for I := 0 to High(OwnedKeys) do
    begin
      Name := OwnedKeys[I];
      if Name = '' then
        Continue;

      StillSupplied := False;
      for var J := 0 to High(Rows) do
      begin
        RowKey := Rows[J].Key;
        if (RowKey <> '') and SameText(RowKey, Name) and (Rows[J].Value <> '') then
        begin
          StillSupplied := True;
          Break;
        end;
      end;

      if not StillSupplied then
        Work.Remove(Name);
    end;

    Map.Clear;
    for Pair in Work do
      Map.AddOrSetValue(Pair.Key, Pair.Value);
  finally
    Work.Free;
  end;
end;

procedure SyncVisibleMappings(Map: TDictionary<string, TKeyMapping>;
  const EditedMappings: TArray<TEditorMapping>; const OwnedKeys: TArray<string>;
  const DefaultMapType: string);
var
  Edited: TEditorMapping;
  Mapping: TKeyMapping;
  SuppliedNames: TDictionary<string, Boolean>;
  Name: string;
  I: Integer;
begin
  SuppliedNames := TDictionary<string, Boolean>.Create;
  try
    for Edited in EditedMappings do
    begin
      if (Edited.Name = '') or (Edited.Glyph = '') then
        Continue;

      SuppliedNames.AddOrSetValue(Edited.Name, True);

      if Map.TryGetValue(Edited.Name, Mapping) then
      begin
        // Preserve MapType and the existing Metadata dictionary.  Updating a
        // value in the dictionary copies only the record, not its ownership.
        Mapping.Key := Edited.Key;
        Mapping.Glyph := Edited.Glyph;
      end
      else
      begin
        Mapping := Default(TKeyMapping);
        Mapping.Key := Edited.Key;
        Mapping.Glyph := Edited.Glyph;
        Mapping.MapType := DefaultMapType;
        Mapping.InitMetadata;
      end;
      Map.AddOrSetValue(Edited.Name, Mapping);
    end;

    for I := 0 to High(OwnedKeys) do
    begin
      Name := OwnedKeys[I];
      if (Name = '') or SuppliedNames.ContainsKey(Name) then
        Continue;
      if not Map.TryGetValue(Name, Mapping) then
        Continue;

      Mapping.FreeMetadata;
      Map.Remove(Name);
    end;
  finally
    SuppliedNames.Free;
  end;
end;

end.
