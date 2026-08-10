unit LayoutModel;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  // Generic key-value metadata for extensibility
  TLayoutProperty = record
    Name: string;
    Value: string;
  end;

  // Extensible key mapping record
  TKeyMapping = record
    Key: string;
    Glyph: string;
    MapType: string; // e.g. direct, prebase, postbase, modifier, sequence, extra
    Metadata: TDictionary<string, string>; // extensible
    procedure InitMetadata;
    procedure FreeMetadata;
  end;

  TKeyboardLayout = class
  public
    // --- Metadata ---
    SourceFileName: string;
    LayoutID: string;
    Name: string;
    Script: string;        // Devanagari, Gujarati, etc.
    Encoding: string;      // legacy / unicode
    FontFamily: string;    // SHREE-GUJ-0708, etc.
    LayoutType: string;    // standard / remington / phonetic
    Group: string;
    Properties: TDictionary<string, string>; // extensible metadata

    // --- Key maps ---
    DirectMap: TDictionary<string, string>;            // k → ¬
    PrebaseMap: TDictionary<string, TKeyMapping>;      // f → i-matra (generic)
    PostbaseMap: TDictionary<string, string>;          // = → ा
    Modifiers: TDictionary<string, TKeyMapping>;       // halant, reph (generic)
    Sequences: TDictionary<string, string>;            // k\s → क्ष
    ExtraMaps: TDictionary<string, TDictionary<string, string>>; // for future scripts

    SupportedScripts: TArray<string>; // for UI/editor

    constructor Create;
    destructor Destroy; override;
    function ToJSON: string;
    class function FromJSON(const JSONText: string): TKeyboardLayout;
  end;

implementation
uses
  System.JSON;

{ --------------------------------------------------
  TKeyMapping helpers
-------------------------------------------------- }
procedure TKeyMapping.InitMetadata;
begin
  Metadata := TDictionary<string, string>.Create;
end;

procedure TKeyMapping.FreeMetadata;
begin
  if Assigned(Metadata) then
  begin
    Metadata.Free;
    Metadata := nil;
  end;
end;

{ --------------------------------------------------
  Constructor
-------------------------------------------------- }
constructor TKeyboardLayout.Create;
begin
  inherited Create;
  DirectMap   := TDictionary<string, string>.Create;
  PrebaseMap  := TDictionary<string, TKeyMapping>.Create;
  PostbaseMap := TDictionary<string, string>.Create;
  Modifiers   := TDictionary<string, TKeyMapping>.Create;
  Sequences   := TDictionary<string, string>.Create;
  Properties  := TDictionary<string, string>.Create;
  ExtraMaps   := TDictionary<string, TDictionary<string, string>>.Create;
  SupportedScripts := TArray<string>.Create('Devanagari', 'Gujarati', 'Tamil', 'Bengali', 'Kannada', 'Malayalam', 'Oriya', 'Punjabi', 'Telugu', 'Sinhala');
end;

{ --------------------------------------------------
  Destructor
-------------------------------------------------- }
destructor TKeyboardLayout.Destroy;
var
  Map: TDictionary<string, string>;
  KeyMap: TKeyMapping;
begin
  // Free per-entry metadata dictionaries in PrebaseMap
  if Assigned(PrebaseMap) then
    for KeyMap in PrebaseMap.Values do
      KeyMap.FreeMetadata;

  // Free per-entry metadata dictionaries in Modifiers
  if Assigned(Modifiers) then
    for KeyMap in Modifiers.Values do
      KeyMap.FreeMetadata;

  DirectMap.Free;
  PrebaseMap.Free;
  PostbaseMap.Free;
  Modifiers.Free;
  Sequences.Free;
  Properties.Free;
  if Assigned(ExtraMaps) then
    for Map in ExtraMaps.Values do
      Map.Free;
  ExtraMaps.Free;
  inherited Destroy;
end;

function TKeyboardLayout.ToJSON: string;
var
  Root, Obj, Item, MetaObj: TJSONObject;
  PairStr: TPair<string, string>;
  PairMap: TPair<string, TKeyMapping>;
  PairProp: TPair<string, string>;
  MapName: string;
  ExtraMap: TDictionary<string, string>;
  ExtraPair: TPair<string, string>;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('layout_id', LayoutID);
    Root.AddPair('name', Name);
    Root.AddPair('script', Script);
    Root.AddPair('encoding', Encoding);
    Root.AddPair('font_family', FontFamily);
    Root.AddPair('layout_type', LayoutType);

    // Serialize Properties
    Obj := TJSONObject.Create;
    for PairProp in Properties do
      Obj.AddPair(PairProp.Key, PairProp.Value);
    Root.AddPair('properties', Obj);

    // DirectMap
    Obj := TJSONObject.Create;
    for PairStr in DirectMap do
      Obj.AddPair(PairStr.Key, PairStr.Value);
    Root.AddPair('direct', Obj);

    // PrebaseMap (generic)
    Obj := TJSONObject.Create;
    for PairMap in PrebaseMap do
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
    for PairStr in PostbaseMap do
      Obj.AddPair(PairStr.Key, PairStr.Value);
    Root.AddPair('postbase', Obj);

    // Modifiers (generic)
    Obj := TJSONObject.Create;
    for PairMap in Modifiers do
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
    for PairStr in Sequences do
      Obj.AddPair(PairStr.Key, PairStr.Value);
    Root.AddPair('sequences', Obj);

    // ExtraMaps
    Obj := TJSONObject.Create;
    for MapName in ExtraMaps.Keys do
    begin
      MetaObj := TJSONObject.Create;
      ExtraMap := ExtraMaps[MapName];
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

class function TKeyboardLayout.FromJSON(const JSONText: string): TKeyboardLayout;
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
    Result.LayoutID   := JSON.GetValue<string>('layout_id', '');
    Result.Name       := JSON.GetValue<string>('name', '');
    Result.Script     := JSON.GetValue<string>('script', '');
    Result.Encoding   := JSON.GetValue<string>('encoding', '');
    Result.FontFamily := JSON.GetValue<string>('font_family', '');
    Result.LayoutType := JSON.GetValue<string>('layout_type', '');

    // Properties
    Obj := JSON.GetValue<TJSONObject>('properties');
    if Assigned(Obj) then
      for PairProp in Obj do
        Result.Properties.Add(PairProp.JsonString.Value, PairProp.JsonValue.Value);

    // DirectMap
    Obj := JSON.GetValue<TJSONObject>('direct');
    if Assigned(Obj) then
      for Pair in Obj do
        Result.DirectMap.Add(Pair.JsonString.Value, Pair.JsonValue.Value);

    // PrebaseMap (generic)
    Obj := JSON.GetValue<TJSONObject>('prebase');
    if Assigned(Obj) then
      for Pair in Obj do
      begin
        Item := Pair.JsonValue as TJSONObject;
        KeyMap.Key := Item.GetValue<string>('key', '');
        KeyMap.Glyph := Item.GetValue<string>('glyph', '');
        KeyMap.MapType := Item.GetValue<string>('map_type', 'prebase');
        KeyMap.InitMetadata;
        MetaObj := Item.GetValue<TJSONObject>('metadata');
        if Assigned(MetaObj) then
          for PairProp in MetaObj do
            KeyMap.Metadata.Add(PairProp.JsonString.Value, PairProp.JsonValue.Value);
        Result.PrebaseMap.Add(Pair.JsonString.Value, KeyMap);
      end;

    // PostbaseMap
    Obj := JSON.GetValue<TJSONObject>('postbase');
    if Assigned(Obj) then
      for Pair in Obj do
        Result.PostbaseMap.Add(Pair.JsonString.Value, Pair.JsonValue.Value);

    // Modifiers (generic)
    Obj := JSON.GetValue<TJSONObject>('modifiers');
    if Assigned(Obj) then
      for Pair in Obj do
      begin
        Item := Pair.JsonValue as TJSONObject;
        KeyMap.Key := Item.GetValue<string>('key', '');
        KeyMap.Glyph := Item.GetValue<string>('glyph', '');
        KeyMap.MapType := Item.GetValue<string>('map_type', 'modifier');
        KeyMap.InitMetadata;
        MetaObj := Item.GetValue<TJSONObject>('metadata');
        if Assigned(MetaObj) then
          for PairProp in MetaObj do
            KeyMap.Metadata.Add(PairProp.JsonString.Value, PairProp.JsonValue.Value);
        Result.Modifiers.Add(Pair.JsonString.Value, KeyMap);
      end;

    // Sequences
    Obj := JSON.GetValue<TJSONObject>('sequences');
    if Assigned(Obj) then
      for Pair in Obj do
        Result.Sequences.Add(Pair.JsonString.Value, Pair.JsonValue.Value);

    // ExtraMaps
    Obj := JSON.GetValue<TJSONObject>('extra_maps');
    if Assigned(Obj) then
      for Pair in Obj do
      begin
        MapName := Pair.JsonString.Value;
        MetaObj := Pair.JsonValue as TJSONObject;
        ExtraMap := TDictionary<string, string>.Create;
        for ExtraPair in MetaObj do
          ExtraMap.Add(ExtraPair.JsonString.Value, ExtraPair.JsonValue.Value);
        Result.ExtraMaps.Add(MapName, ExtraMap);
      end;
  finally
    JSON.Free;
  end;
end;

end.