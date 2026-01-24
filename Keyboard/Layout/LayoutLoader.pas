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

function LoadLayoutFromFile(const FileName: string): TKeyboardLayout;
var
  JSON: TJSONObject;
  Obj, Item: TJSONObject;
  Pair: TJSONPair;
  Matra: TPrebaseMatra;
  ModRule: TModifierRule;
begin
  if not FileExists(FileName) then
    raise Exception.Create('Layout file not found: ' + FileName);

  Result := TKeyboardLayout.Create;

  // Get group from parent folder name.
  Result.Group := ExtractFileName(ExtractFileDir(FileName));
  if Result.Group = '' then
    Result.Group := 'Other';

  JSON := TJSONObject.ParseJSONValue(
            TFile.ReadAllText(FileName, TEncoding.UTF8)
          ) as TJSONObject;
  try
    { ---------- METADATA ---------- }
    Result.LayoutID   := JSON.GetValue<string>('layout_id', '');
    Result.Name       := JSON.GetValue<string>('name', '');
    Result.Script     := JSON.GetValue<string>('script', '');
    Result.Encoding   := JSON.GetValue<string>('encoding', '');
    Result.FontFamily := JSON.GetValue<string>('font_family', '');
    Result.LayoutType := JSON.GetValue<string>('layout_type', '');

    { ---------- DIRECT MAP ---------- }
    Obj := JSON.GetValue<TJSONObject>('direct');
    if Assigned(Obj) then
      for Pair in Obj do
        Result.DirectMap.Add(
          Pair.JsonString.Value,
          Pair.JsonValue.Value
        );

    { ---------- PREBASE MATRAS ---------- }
    Obj := JSON.GetValue<TJSONObject>('prebase');
    if Assigned(Obj) then
      for Pair in Obj do
      begin
        Item := Pair.JsonValue as TJSONObject;
        Matra.Glyph := Item.GetValue<string>('glyph');
        Matra.MatraType := Item.GetValue<string>('type', '');
        Result.PrebaseMap.Add(Pair.JsonString.Value, Matra);
      end;

    { ---------- POSTBASE MATRAS ---------- }
    Obj := JSON.GetValue<TJSONObject>('postbase');
    if Assigned(Obj) then
      for Pair in Obj do
        Result.PostbaseMap.Add(
          Pair.JsonString.Value,
          Pair.JsonValue.Value
        );

    { ---------- MODIFIERS ---------- }
    Obj := JSON.GetValue<TJSONObject>('modifiers');
    if Assigned(Obj) then
      for Pair in Obj do
      begin
        Item := Pair.JsonValue as TJSONObject;
        ModRule.Key      := Item.GetValue<string>('key');
        ModRule.Glyph    := Item.GetValue<string>('glyph');
        ModRule.Behavior := Item.GetValue<string>('behavior', '');
        Result.Modifiers.Add(Pair.JsonString.Value, ModRule);
      end;

    { ---------- SEQUENCES / CONJUNCTS ---------- }
    Obj := JSON.GetValue<TJSONObject>('sequences');
    if Assigned(Obj) then
      for Pair in Obj do
        Result.Sequences.Add(
          Pair.JsonString.Value,
          Pair.JsonValue.Value
        );

  finally
    JSON.Free;
  end;
end;

end.
