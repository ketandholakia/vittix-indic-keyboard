unit Tests.Shared.LayoutJson;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  System.JSON,
  LayoutModel,
  LayoutJson;

type
  [TestFixture]
  TLayoutJsonTests = class
  public
    [Test]
    procedure LayoutToJson_RoundTrip_PreservesData;

    [Test]
    procedure LayoutFromJson_ValidJson_ReturnsLayout;

    [Test]
    procedure LayoutFromJson_InvalidJson_RaisesException;

    [Test]
    procedure SaveAndLoadLayoutFile_Works;

    [Test]
    procedure LoadLayoutFromFile_UTF16LE_WithBOM_Works;

    [Test]
    procedure LoadLayoutFromFile_UTF8_WithBOM_Works;

    [Test]
    procedure LoadLayoutFromFile_UTF8_NoBOM_Works;

    [Test]
    procedure LayoutFromJson_DuplicatePrebaseKey_RaisesException;

    [Test]
    procedure LayoutFromJson_DuplicateModifierKey_RaisesException;
  end;

implementation

function CreateTestLayout: TKeyboardLayout;
begin
  Result := TKeyboardLayout.Create;
  Result.LayoutID := 'test-roundtrip';
  Result.Name := 'Roundtrip Test';
  Result.Script := 'Devanagari';
  Result.Encoding := 'unicode';
  Result.FontFamily := 'Nirmala UI';
  Result.LayoutType := 'phonetic';
  Result.Group := 'Test';
  Result.DirectMap.Add('k', 'क');
  Result.DirectMap.Add('g', 'ग');
  Result.PostbaseMap.Add('a', 'ा');
  Result.Sequences.Add('kS', 'क्ष');
end;

procedure TLayoutJsonTests.LayoutToJson_RoundTrip_PreservesData;
var
  Layout: TKeyboardLayout;
  JsonText: string;
  LoadedLayout: TKeyboardLayout;
begin
  Layout := CreateTestLayout;
  try
    JsonText := LayoutToJson(Layout);
    Assert.IsTrue(JsonText.Contains('test-roundtrip'), 'JSON should contain layout_id');
    Assert.IsTrue(JsonText.Contains('Roundtrip Test'), 'JSON should contain name');

    LoadedLayout := LayoutFromJson(JsonText);
    try
      Assert.AreEqual(Layout.LayoutID, LoadedLayout.LayoutID);
      Assert.AreEqual(Layout.Name, LoadedLayout.Name);
      Assert.AreEqual(Layout.Script, LoadedLayout.Script);
      Assert.AreEqual(Layout.Encoding, LoadedLayout.Encoding);
      Assert.AreEqual(Layout.FontFamily, LoadedLayout.FontFamily);
      Assert.AreEqual(Layout.LayoutType, LoadedLayout.LayoutType);
      Assert.AreEqual(Layout.DirectMap.Count, LoadedLayout.DirectMap.Count);
      Assert.AreEqual(Layout.PostbaseMap.Count, LoadedLayout.PostbaseMap.Count);
      Assert.AreEqual(Layout.Sequences.Count, LoadedLayout.Sequences.Count);
      Assert.AreEqual(Layout.DirectMap['k'], LoadedLayout.DirectMap['k']);
      Assert.AreEqual(Layout.PostbaseMap['a'], LoadedLayout.PostbaseMap['a']);
      Assert.AreEqual(Layout.Sequences['kS'], LoadedLayout.Sequences['kS']);
    finally
      LoadedLayout.Free;
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutJsonTests.LayoutFromJson_ValidJson_ReturnsLayout;
const
  ValidJson = '{"layout_id":"json-test","name":"JSON Test","script":"Gujarati","encoding":"legacy",' +
              '"font_family":"Shruti","layout_type":"standard","properties":{},' +
              '"direct":{"a":"અ"},"prebase":{},"postbase":{},"modifiers":{},"sequences":{},"extra_maps":{}}';
var
  Layout: TKeyboardLayout;
begin
  Layout := LayoutFromJson(ValidJson);
  try
    Assert.IsNotNull(Layout);
    Assert.AreEqual('json-test', Layout.LayoutID);
    Assert.AreEqual('JSON Test', Layout.Name);
    Assert.AreEqual('Gujarati', Layout.Script);
    Assert.AreEqual('legacy', Layout.Encoding);
    Assert.AreEqual('Shruti', Layout.FontFamily);
    Assert.AreEqual('standard', Layout.LayoutType);
    Assert.AreEqual(1, Layout.DirectMap.Count);
    Assert.AreEqual('અ', Layout.DirectMap['a']);
  finally
    Layout.Free;
  end;
end;

procedure TLayoutJsonTests.LayoutFromJson_InvalidJson_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      LayoutFromJson('not valid json');
    end,
    Exception,
    'Invalid JSON should raise exception'
  );
end;

procedure TLayoutJsonTests.SaveAndLoadLayoutFile_Works;
var
  Layout: TKeyboardLayout;
  TempFile: string;
  LoadedLayout: TKeyboardLayout;
begin
  Layout := CreateTestLayout;
  try
    TempFile := TPath.Combine(TPath.GetTempPath, 'vittix_test_layout_' + TPath.GetRandomFileName + '.json');
    try
      SaveLayoutToFile(Layout, TempFile);
      Assert.IsTrue(TFile.Exists(TempFile), 'Layout file should be created');

      LoadedLayout := LoadLayoutFromFile(TempFile);
      try
        Assert.AreEqual(Layout.LayoutID, LoadedLayout.LayoutID);
        Assert.AreEqual(Layout.Name, LoadedLayout.Name);
        Assert.AreEqual(Layout.DirectMap.Count, LoadedLayout.DirectMap.Count);
      finally
        LoadedLayout.Free;
      end;
    finally
      if TFile.Exists(TempFile) then
        TFile.Delete(TempFile);
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutJsonTests.LoadLayoutFromFile_UTF16LE_WithBOM_Works;
var
  TempFile: string;
  Layout: TKeyboardLayout;
  LoadedLayout: TKeyboardLayout;
  UTF16Bytes: TBytes;
  Preamble: TBytes;
  AllBytes: TBytes;
begin
  // Create a minimal valid layout JSON with Unicode content
  Layout := CreateTestLayout;
  try
    // Save as UTF-16LE with BOM (simulating legacy layout files)
    TempFile := TPath.Combine(TPath.GetTempPath, 'vittix_test_utf16le_' + TPath.GetRandomFileName + '.json');
    try
      // Use LayoutToJson to get valid JSON, then write as UTF-16LE with BOM
      UTF16Bytes := TEncoding.Unicode.GetBytes(LayoutToJson(Layout));
      Preamble := TEncoding.Unicode.GetPreamble; // FF FE
      SetLength(AllBytes, Length(Preamble) + Length(UTF16Bytes));
      Move(Preamble[0], AllBytes[0], Length(Preamble));
      Move(UTF16Bytes[0], AllBytes[Length(Preamble)], Length(UTF16Bytes));
      
      TFile.WriteAllBytes(TempFile, AllBytes);
      Assert.IsTrue(TFile.Exists(TempFile), 'UTF-16LE layout file should be created');

      // This should not raise "No mapping for Unicode character" error
      LoadedLayout := LoadLayoutFromFile(TempFile);
      try
        Assert.AreEqual(Layout.LayoutID, LoadedLayout.LayoutID);
        Assert.AreEqual(Layout.Name, LoadedLayout.Name);
        Assert.AreEqual(Layout.DirectMap.Count, LoadedLayout.DirectMap.Count);
        Assert.AreEqual('क', LoadedLayout.DirectMap['k']);
        Assert.AreEqual('ग', LoadedLayout.DirectMap['g']);
      finally
        LoadedLayout.Free;
      end;
    finally
      if TFile.Exists(TempFile) then
        TFile.Delete(TempFile);
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutJsonTests.LoadLayoutFromFile_UTF8_WithBOM_Works;
var
  TempFile: string;
  Layout: TKeyboardLayout;
  LoadedLayout: TKeyboardLayout;
begin
  Layout := CreateTestLayout;
  try
    TempFile := TPath.Combine(TPath.GetTempPath, 'vittix_test_utf8bom_' + TPath.GetRandomFileName + '.json');
    try
      // Write as UTF-8 with BOM
      TFile.WriteAllText(TempFile, LayoutToJson(Layout), TEncoding.UTF8);
      Assert.IsTrue(TFile.Exists(TempFile), 'UTF-8+BOM layout file should be created');

      LoadedLayout := LoadLayoutFromFile(TempFile);
      try
        Assert.AreEqual(Layout.LayoutID, LoadedLayout.LayoutID);
        Assert.AreEqual('क', LoadedLayout.DirectMap['k']);
      finally
        LoadedLayout.Free;
      end;
    finally
      if TFile.Exists(TempFile) then
        TFile.Delete(TempFile);
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutJsonTests.LoadLayoutFromFile_UTF8_NoBOM_Works;
var
  TempFile: string;
  Layout: TKeyboardLayout;
  LoadedLayout: TKeyboardLayout;
  Utf8NoBOM: TUTF8Encoding;
begin
  Layout := CreateTestLayout;
  try
    TempFile := TPath.Combine(TPath.GetTempPath, 'vittix_test_utf8nobom_' + TPath.GetRandomFileName + '.json');
    try
      // Write as UTF-8 without BOM
      Utf8NoBOM := TUTF8Encoding.Create(False);
      try
        TFile.WriteAllText(TempFile, LayoutToJson(Layout), Utf8NoBOM);
      finally
        Utf8NoBOM.Free;
      end;
      Assert.IsTrue(TFile.Exists(TempFile), 'UTF-8 no-BOM layout file should be created');

      LoadedLayout := LoadLayoutFromFile(TempFile);
      try
        Assert.AreEqual(Layout.LayoutID, LoadedLayout.LayoutID);
        Assert.AreEqual('क', LoadedLayout.DirectMap['k']);
      finally
        LoadedLayout.Free;
      end;
    finally
      if TFile.Exists(TempFile) then
        TFile.Delete(TempFile);
    end;
  finally
    Layout.Free;
  end;
end;

procedure TLayoutJsonTests.LayoutFromJson_DuplicatePrebaseKey_RaisesException;
var
  Root, PrebaseObj, KeyMapObj, KeyMapObj2: TJSONObject;
  JsonText: string;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('layout_id', 'dup-test');
    Root.AddPair('name', 'Dup Test');
    Root.AddPair('script', 'Devanagari');
    Root.AddPair('encoding', 'unicode');
    Root.AddPair('font_family', 'Nirmala UI');
    Root.AddPair('layout_type', 'phonetic');
    Root.AddPair('direct', TJSONObject.Create);
    Root.AddPair('postbase', TJSONObject.Create);
    Root.AddPair('modifiers', TJSONObject.Create);
    Root.AddPair('sequences', TJSONObject.Create);
    Root.AddPair('extra_maps', TJSONObject.Create);

    PrebaseObj := TJSONObject.Create;
    KeyMapObj := TJSONObject.Create;
    KeyMapObj.AddPair('key', 'k');
    KeyMapObj.AddPair('glyph', '\u0915');
    KeyMapObj.AddPair('map_type', 'prebase');
    PrebaseObj.AddPair('dup', KeyMapObj);

    KeyMapObj2 := TJSONObject.Create;
    KeyMapObj2.AddPair('key', 'k');
    KeyMapObj2.AddPair('glyph', '\u0915');
    KeyMapObj2.AddPair('map_type', 'prebase');
    PrebaseObj.AddPair('dup', KeyMapObj2);

    Root.AddPair('prebase', PrebaseObj);

    JsonText := Root.ToJSON;
  finally
    Root.Free;
  end;

  Assert.WillRaise(
    procedure
    begin
      LayoutFromJson(JsonText);
    end,
    Exception,
    'Duplicate prebase key should raise exception'
  );
end;

procedure TLayoutJsonTests.LayoutFromJson_DuplicateModifierKey_RaisesException;
var
  Root, ModifiersObj, KeyMapObj, KeyMapObj2: TJSONObject;
  JsonText: string;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('layout_id', 'dup-mod');
    Root.AddPair('name', 'Dup Mod');
    Root.AddPair('script', 'Devanagari');
    Root.AddPair('encoding', 'unicode');
    Root.AddPair('font_family', 'Nirmala UI');
    Root.AddPair('layout_type', 'phonetic');
    Root.AddPair('direct', TJSONObject.Create);
    Root.AddPair('prebase', TJSONObject.Create);
    Root.AddPair('postbase', TJSONObject.Create);
    Root.AddPair('sequences', TJSONObject.Create);
    Root.AddPair('extra_maps', TJSONObject.Create);

    ModifiersObj := TJSONObject.Create;
    KeyMapObj := TJSONObject.Create;
    KeyMapObj.AddPair('key', 'h');
    KeyMapObj.AddPair('glyph', '\u0942');
    KeyMapObj.AddPair('map_type', 'modifier');
    ModifiersObj.AddPair('dup', KeyMapObj);

    KeyMapObj2 := TJSONObject.Create;
    KeyMapObj2.AddPair('key', 'h');
    KeyMapObj2.AddPair('glyph', '\u0942');
    KeyMapObj2.AddPair('map_type', 'modifier');
    ModifiersObj.AddPair('dup', KeyMapObj2);

    Root.AddPair('modifiers', ModifiersObj);

    JsonText := Root.ToJSON;
  finally
    Root.Free;
  end;

  Assert.WillRaise(
    procedure
    begin
      LayoutFromJson(JsonText);
    end,
    Exception,
    'Duplicate modifier key should raise exception'
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TLayoutJsonTests);

end.