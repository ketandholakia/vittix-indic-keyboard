unit LayoutJson;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.Generics.Collections,
  LayoutModel;

function LayoutToJson(const ALayout: TKeyboardLayout): string;
function LayoutFromJson(const JSONText: string): TKeyboardLayout;

procedure SaveLayoutToFile(const ALayout: TKeyboardLayout; const FileName: string);
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

function LayoutToJson(const ALayout: TKeyboardLayout): string;
var
  Root, Obj, Item, MetaObj: TJSONObject;
  PairStr: TPair<string, string>;
  PairMap: TPair<string, TKeyMapping>;
  PairProp: TPair<string, string>;
  MapName: string;
  ExtraMap: TDictionary<string, string>;
  ExtraPair: TPair<string, string>;
begin
  if not Assigned(ALayout) then
    raise Exception.Create('No layout to serialize');

  Root := TJSONObject.Create;
  try
    Root.AddPair('layout_id', ALayout.LayoutID);
    Root.AddPair('name', ALayout.Name);
    Root.AddPair('script', ALayout.Script);
    Root.AddPair('encoding', ALayout.Encoding);
    Root.AddPair('font_family', ALayout.FontFamily);
    Root.AddPair('layout_type', ALayout.LayoutType);

    // Serialize Properties
    Obj := TJSONObject.Create;
    for PairProp in ALayout.Properties do
      Obj.AddPair(PairProp.Key, PairProp.Value);
    Root.AddPair('properties', Obj);

    // DirectMap
    Obj := TJSONObject.Create;
    for PairStr in ALayout.DirectMap do
      Obj.AddPair(PairStr.Key, PairStr.Value);
    Root.AddPair('direct', Obj);

    // PrebaseMap (generic)
    Obj := TJSONObject.Create;
    for PairMap in ALayout.PrebaseMap do
    begin
      Item := TJSONObject.Create;
      Item.AddPair('key', PairMap.Value.Key);
      Item.AddPair('glyph', PairMap.Value.Glyph);
      Item.AddPair('map_type', PairMap.Value.MapType);
      // Serialize Metadata
      MetaObj := TJSONObject.Create;
      if Assigned(PairMap.Value.Metadata) then
        for PairProp in PairMap.Value.Metadata do
          MetaObj.AddPair(PairProp.Key, PairProp.Value);
      Item.AddPair('metadata', MetaObj);
      Obj.AddPair(PairMap.Key, Item);
    end;
    Root.AddPair('prebase', Obj);

    // PostbaseMap
    Obj := TJSONObject.Create;
    for PairStr in ALayout.PostbaseMap do
      Obj.AddPair(PairStr.Key, PairStr.Value);
    Root.AddPair('postbase', Obj);

    // Modifiers (generic)
    Obj := TJSONObject.Create;
    for PairMap in ALayout.Modifiers do
    begin
      Item := TJSONObject.Create;
      Item.AddPair('key', PairMap.Value.Key);
      Item.AddPair('glyph', PairMap.Value.Glyph);
      Item.AddPair('map_type', PairMap.Value.MapType);
      MetaObj := TJSONObject.Create;
      if Assigned(PairMap.Value.Metadata) then
        for PairProp in PairMap.Value.Metadata do
          MetaObj.AddPair(PairProp.Key, PairProp.Value);
      Item.AddPair('metadata', MetaObj);
      Obj.AddPair(PairMap.Key, Item);
    end;
    Root.AddPair('modifiers', Obj);

    // Sequences
    Obj := TJSONObject.Create;
    for PairStr in ALayout.Sequences do
      Obj.AddPair(PairStr.Key, PairStr.Value);
    Root.AddPair('sequences', Obj);

    // ExtraMaps
    Obj := TJSONObject.Create;
    for MapName in ALayout.ExtraMaps.Keys do
    begin
      MetaObj := TJSONObject.Create;
      ExtraMap := ALayout.ExtraMaps[MapName];
      for ExtraPair in ExtraMap do
        MetaObj.AddPair(ExtraPair.Key, ExtraPair.Value);
      Obj.AddPair(MapName, MetaObj);
    end;
    Root.AddPair('extra_maps', Obj);

    Result := Root.Format(2);
  finally
    Root.Free;
  end;
end;

function LayoutFromJson(const JSONText: string): TKeyboardLayout;
var
  JSON, Obj, Item, MetaObj: TJSONObject;
  Pair: TJSONPair;
  KeyMap: TKeyMapping;
  PairProp: TJSONPair;
  MapName: string;
  ExtraMap: TDictionary<string, string>;
  ExtraPair: TJSONPair;
begin
  Result := TKeyboardLayout.Create;
  JSON := TJSONObject.ParseJSONValue(JSONText) as TJSONObject;
  try
    try
      if not Assigned(JSON) then
        raise Exception.Create('Invalid layout JSON: root object could not be parsed');

      Result.LayoutID   := JSON.GetValue<string>('layout_id', '');
      Result.Name       := JSON.GetValue<string>('name', '');
      Result.Script     := JSON.GetValue<string>('script', '');
      Result.Encoding   := JSON.GetValue<string>('encoding', '');
      Result.FontFamily := JSON.GetValue<string>('font_family', '');
      Result.LayoutType := JSON.GetValue<string>('layout_type', '');

      // Properties (optional)
      Obj := JSON.GetValue('properties') as TJSONObject;
      if Assigned(Obj) then
        for PairProp in Obj do
          Result.Properties.AddOrSetValue(
            PairProp.JsonString.Value,
            PairProp.JsonValue.Value
          );

      // DirectMap
      Obj := JSON.GetValue('direct') as TJSONObject;
      if Assigned(Obj) then
        for Pair in Obj do
          Result.DirectMap.Add(
            Pair.JsonString.Value,
            ReadScalarJsonValue(Pair.JsonValue)
          );

      // PrebaseMap (generic)
      Obj := JSON.GetValue('prebase') as TJSONObject;
      if Assigned(Obj) then
        for Pair in Obj do
        begin
          Item := Pair.JsonValue as TJSONObject;
          KeyMap.Key := Item.GetValue<string>('key', '');
          KeyMap.Glyph := Item.GetValue<string>('glyph', '');
          KeyMap.MapType := Item.GetValue<string>('map_type', 'prebase');
          // Legacy fallback: if map_type is default 'prebase', check old 'type' field
          if KeyMap.MapType = 'prebase' then
            KeyMap.MapType := Item.GetValue<string>('type', 'prebase');
          KeyMap.InitMetadata;
          MetaObj := Item.GetValue('metadata') as TJSONObject;
          if Assigned(MetaObj) then
            for PairProp in MetaObj do
              KeyMap.Metadata.Add(PairProp.JsonString.Value, ReadScalarJsonValue(PairProp.JsonValue));
          Result.PrebaseMap.Add(Pair.JsonString.Value, KeyMap);
        end;

      // PostbaseMap
      Obj := JSON.GetValue('postbase') as TJSONObject;
      if Assigned(Obj) then
        for Pair in Obj do
          Result.PostbaseMap.Add(
            Pair.JsonString.Value,
            ReadScalarJsonValue(Pair.JsonValue)
          );

      // Modifiers (generic)
      Obj := JSON.GetValue('modifiers') as TJSONObject;
      if Assigned(Obj) then
        for Pair in Obj do
        begin
          Item := Pair.JsonValue as TJSONObject;
          KeyMap.Key := Item.GetValue<string>('key', '');
          KeyMap.Glyph := Item.GetValue<string>('glyph', '');
          KeyMap.MapType := Item.GetValue<string>('map_type', 'modifier');
          // Legacy fallback: if map_type is default 'modifier', check old 'behavior' field
          if KeyMap.MapType = 'modifier' then
            KeyMap.MapType := Item.GetValue<string>('behavior', 'modifier');
          KeyMap.InitMetadata;
          MetaObj := Item.GetValue('metadata') as TJSONObject;
          if Assigned(MetaObj) then
            for PairProp in MetaObj do
              KeyMap.Metadata.Add(PairProp.JsonString.Value, ReadScalarJsonValue(PairProp.JsonValue));
          Result.Modifiers.Add(Pair.JsonString.Value, KeyMap);
        end;

      // Sequences
      Obj := JSON.GetValue('sequences') as TJSONObject;
      if Assigned(Obj) then
        for Pair in Obj do
          Result.Sequences.Add(
            Pair.JsonString.Value,
            ReadScalarJsonValue(Pair.JsonValue)
          );

      // ExtraMaps (optional)
      Obj := JSON.GetValue('extra_maps') as TJSONObject;
      if Assigned(Obj) then
        for Pair in Obj do
        begin
          MapName := Pair.JsonString.Value;
          MetaObj := Pair.JsonValue as TJSONObject;
          ExtraMap := TDictionary<string, string>.Create;
          for ExtraPair in MetaObj do
            ExtraMap.Add(ExtraPair.JsonString.Value, ReadScalarJsonValue(ExtraPair.JsonValue));
          Result.ExtraMaps.Add(MapName, ExtraMap);
        end;
    except
      Result.Free;
      raise;
    end;
  finally
    JSON.Free;
  end;
end;

procedure SaveLayoutToFile(const ALayout: TKeyboardLayout; const FileName: string);
var
  JSONText: string;
begin
  JSONText := LayoutToJson(ALayout);
  TDirectory.CreateDirectory(ExtractFileDir(FileName));
  TFile.WriteAllText(FileName, JSONText, TEncoding.UTF8);
end;

function LoadLayoutFromFile(const FileName: string): TKeyboardLayout;
var
  JSONText: string;
  Stream: TFileStream;
  Bytes: TBytes;
  Encoding: TEncoding;
  Preamble: TBytes;
begin
  if not FileExists(FileName) then
    raise Exception.Create('Layout file not found: ' + FileName);

  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Bytes, Stream.Size);
    if Stream.Size > 0 then
      Stream.ReadBuffer(Bytes[0], Stream.Size);
  finally
    Stream.Free;
  end;

  if Length(Bytes) = 0 then
    raise Exception.Create('Layout file is empty');

  Encoding := TEncoding.UTF8;
  Preamble := Encoding.GetPreamble;
  if (Length(Bytes) >= Length(Preamble)) and
     (CompareMem(@Bytes[0], @Preamble[0], Length(Preamble))) then
  begin
    // UTF-8 BOM present
    Encoding := TEncoding.UTF8;
  end
  else
  begin
    Preamble := TEncoding.Unicode.GetPreamble; // UTF-16LE = FF FE
    if (Length(Bytes) >= Length(Preamble)) and
       (CompareMem(@Bytes[0], @Preamble[0], Length(Preamble))) then
    begin
      Encoding := TEncoding.Unicode; // UTF-16LE
    end
    else
    begin
      Preamble := TEncoding.BigEndianUnicode.GetPreamble; // UTF-16BE = FE FF
      if (Length(Bytes) >= Length(Preamble)) and
         (CompareMem(@Bytes[0], @Preamble[0], Length(Preamble))) then
      begin
        Encoding := TEncoding.BigEndianUnicode; // UTF-16BE
      end;
    end;
  end;

  JSONText := Trim(Encoding.GetString(Bytes));
  if JSONText = '' then
    raise Exception.Create('Layout file is empty');

  Result := LayoutFromJson(JSONText);
end;

end.