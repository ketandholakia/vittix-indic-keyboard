unit Tests.Shared.LayoutJson;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
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

initialization
  TDUnitX.RegisterTestFixture(TLayoutJsonTests);

end.