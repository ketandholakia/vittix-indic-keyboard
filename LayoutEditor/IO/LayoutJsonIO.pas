unit LayoutJsonIO;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.Generics.Collections,
  LayoutModel;

procedure SaveLayoutToFile(ALayout: TKeyboardLayout; const FileName: string);

implementation

procedure SaveLayoutToFile(ALayout: TKeyboardLayout; const FileName: string);
var
  Root, Obj, Item, MetaObj: TJSONObject;
  PairStr: TPair<string, string>;
  PairMatra: TPair<string, TKeyMapping>;
  PairMod: TPair<string, TKeyMapping>;
  JSONText: string;
begin
  if ALayout = nil then
    raise Exception.Create('No layout to save');

  Root := TJSONObject.Create;
  try
    { ---------- METADATA ---------- }
    Root.AddPair('layout_id', ALayout.LayoutID);
    Root.AddPair('name', ALayout.Name);
    Root.AddPair('script', ALayout.Script);
    Root.AddPair('encoding', ALayout.Encoding);
    Root.AddPair('font_family', ALayout.FontFamily);
    Root.AddPair('layout_type', ALayout.LayoutType);

    { ---------- PROPERTIES ---------- }
    Obj := TJSONObject.Create;
    for PairStr in ALayout.Properties do
      Obj.AddPair(PairStr.Key, PairStr.Value);
    Root.AddPair('properties', Obj);

    { ---------- DIRECT MAP ---------- }
    Obj := TJSONObject.Create;
    for PairStr in ALayout.DirectMap do
      Obj.AddPair(PairStr.Key, PairStr.Value);
    Root.AddPair('direct', Obj);

    { ---------- PREBASE MAP (generic) ---------- }
    Obj := TJSONObject.Create;
    for PairMatra in ALayout.PrebaseMap do
    begin
      Item := TJSONObject.Create;
      Item.AddPair('key', PairMatra.Value.Key);
      Item.AddPair('glyph', PairMatra.Value.Glyph);
      Item.AddPair('map_type', PairMatra.Value.MapType);
      MetaObj := TJSONObject.Create;
      if Assigned(PairMatra.Value.Metadata) then
        for var PairMeta in PairMatra.Value.Metadata do
          MetaObj.AddPair(PairMeta.Key, PairMeta.Value);
      Item.AddPair('metadata', MetaObj);
      Obj.AddPair(PairMatra.Key, Item);
    end;
    Root.AddPair('prebase', Obj);

    { ---------- POSTBASE MATRAS ---------- }
    Obj := TJSONObject.Create;
    for PairStr in ALayout.PostbaseMap do
      Obj.AddPair(PairStr.Key, PairStr.Value);
    Root.AddPair('postbase', Obj);

    { ---------- MODIFIERS (generic) ---------- }
    Obj := TJSONObject.Create;
    for PairMod in ALayout.Modifiers do
    begin
      Item := TJSONObject.Create;
      Item.AddPair('key', PairMod.Value.Key);
      Item.AddPair('glyph', PairMod.Value.Glyph);
      Item.AddPair('map_type', PairMod.Value.MapType);
      MetaObj := TJSONObject.Create;
      if Assigned(PairMod.Value.Metadata) then
        for var PairMeta2 in PairMod.Value.Metadata do
          MetaObj.AddPair(PairMeta2.Key, PairMeta2.Value);
      Item.AddPair('metadata', MetaObj);
      Obj.AddPair(PairMod.Key, Item);
    end;
    Root.AddPair('modifiers', Obj);

    { ---------- SEQUENCES ---------- }
    Obj := TJSONObject.Create;
    for PairStr in ALayout.Sequences do
      Obj.AddPair(PairStr.Key, PairStr.Value);
    Root.AddPair('sequences', Obj);

    { ---------- WRITE FILE ---------- }
    JSONText := Root.Format(2);
    TDirectory.CreateDirectory(ExtractFileDir(FileName));
    TFile.WriteAllText(FileName, JSONText, TEncoding.UTF8);

  finally
    Root.Free;
  end;
end;

end.
