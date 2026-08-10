unit LayoutLoader;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.Generics.Collections,
  LayoutModel;

function LoadLayoutFromFile(const FileName: string): TKeyboardLayout;

implementation

function ReadScalarJsonValue(AValue: TJSONValue): string;
begin
  if not Assigned(AValue) then
    Exit('');

  if (AValue is TJSONObject) or (AValue is TJSONArray) then
    raise Exception.Create('Expected a scalar JSON value but found an object/array.');

  Result := AValue.Value;
end;

function LoadLayoutFromFile(const FileName: string): TKeyboardLayout;
var
  JSON: TJSONObject;
  Obj, Item, MetaObj: TJSONObject;
  Pair, PairProp, ExtraPair: TJSONPair;
  Matra, ModRule: TKeyMapping;
  JSONText: string;
begin
  if not FileExists(FileName) then
    raise Exception.Create('Layout file not found: ' + FileName);

  JSONText := Trim(TFile.ReadAllText(FileName, TEncoding.UTF8));
  if JSONText = '' then
    raise Exception.Create('Layout file is empty');

  JSON := TJSONObject.ParseJSONValue(JSONText) as TJSONObject;
  if not Assigned(JSON) then
    raise Exception.Create('Layout file does not contain a valid JSON object');

  Result := TKeyboardLayout.Create;
  try
    Result.SourceFileName := FileName;
    // Get group from parent folder name.
    Result.Group := ExtractFileName(ExtractFileDir(FileName));
    if Result.Group = '' then
      Result.Group := 'Other';

  try
    { ---------- METADATA ---------- }
    Result.LayoutID   := JSON.GetValue<string>('layout_id', '');
    Result.Name       := JSON.GetValue<string>('name', '');
    Result.Script     := JSON.GetValue<string>('script', '');
    Result.Encoding   := JSON.GetValue<string>('encoding', '');
    Result.FontFamily := JSON.GetValue<string>('font_family', '');
    Result.LayoutType := JSON.GetValue<string>('layout_type', '');

    Obj := JSON.GetValue<TJSONObject>('properties');
    if Assigned(Obj) then
      for PairProp in Obj do
        Result.Properties.AddOrSetValue(
          PairProp.JsonString.Value,
          ReadScalarJsonValue(PairProp.JsonValue)
        );

    { ---------- DIRECT MAP ---------- }
    Obj := JSON.GetValue<TJSONObject>('direct');
    if Assigned(Obj) then
      for Pair in Obj do
        Result.DirectMap.Add(
          Pair.JsonString.Value,
          ReadScalarJsonValue(Pair.JsonValue)
        );

    { ---------- PREBASE MAP (generic) ---------- }
    Obj := JSON.GetValue<TJSONObject>('prebase');
    if Assigned(Obj) then
      for Pair in Obj do
      begin
        Item := Pair.JsonValue as TJSONObject;
        Matra.Key := Item.GetValue<string>('key', '');
        Matra.Glyph := Item.GetValue<string>('glyph', '');
        Matra.MapType := Item.GetValue<string>('map_type', 'prebase');
        if Matra.MapType = 'prebase' then
          Matra.MapType := Item.GetValue<string>('type', 'prebase');
        Matra.InitMetadata;
        MetaObj := Item.GetValue<TJSONObject>('metadata');
        if Assigned(MetaObj) then
          for PairProp in MetaObj do
            Matra.Metadata.Add(PairProp.JsonString.Value, ReadScalarJsonValue(PairProp.JsonValue));
        Result.PrebaseMap.Add(Pair.JsonString.Value, Matra);
      end;

    { ---------- POSTBASE MATRAS ---------- }
    Obj := JSON.GetValue<TJSONObject>('postbase');
    if Assigned(Obj) then
      for Pair in Obj do
        Result.PostbaseMap.Add(
          Pair.JsonString.Value,
          ReadScalarJsonValue(Pair.JsonValue)
        );

    { ---------- MODIFIERS (generic) ---------- }
    Obj := JSON.GetValue<TJSONObject>('modifiers');
    if Assigned(Obj) then
      for Pair in Obj do
      begin
        Item := Pair.JsonValue as TJSONObject;
        ModRule.Key := Item.GetValue<string>('key', '');
        ModRule.Glyph := Item.GetValue<string>('glyph', '');
        ModRule.MapType := Item.GetValue<string>('map_type', 'modifier');
        if ModRule.MapType = 'modifier' then
          ModRule.MapType := Item.GetValue<string>('behavior', 'modifier');
        ModRule.InitMetadata;
        MetaObj := Item.GetValue<TJSONObject>('metadata');
        if Assigned(MetaObj) then
          for PairProp in MetaObj do
            ModRule.Metadata.Add(PairProp.JsonString.Value, ReadScalarJsonValue(PairProp.JsonValue));
        Result.Modifiers.Add(Pair.JsonString.Value, ModRule);
      end;

    { ---------- SEQUENCES / CONJUNCTS ---------- }
    Obj := JSON.GetValue<TJSONObject>('sequences');
    if Assigned(Obj) then
      for Pair in Obj do
        Result.Sequences.Add(
          Pair.JsonString.Value,
          ReadScalarJsonValue(Pair.JsonValue)
        );

  finally
    JSON.Free;
  end;
  except
    Result.Free;
    raise;
  end;
end;

end.
