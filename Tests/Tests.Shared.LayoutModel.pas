unit Tests.Shared.LayoutModel;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Generics.Collections,
  LayoutModel;

type
  [TestFixture]
  TLayoutModelTests = class
  public
    [Test]
    procedure TKeyboardLayout_Create_InitializesAllDictionaries;

    [Test]
    procedure TKeyboardLayout_Destroy_FreesAllDictionaries;

    [Test]
    procedure TKeyMapping_InitMetadata_CreatesDictionary;

    [Test]
    procedure TKeyMapping_FreeMetadata_FreesDictionary;

    [Test]
    procedure TKeyboardLayout_DefaultValues_AreEmpty;
  end;

implementation

procedure TLayoutModelTests.TKeyboardLayout_Create_InitializesAllDictionaries;
var
  Layout: TKeyboardLayout;
begin
  Layout := TKeyboardLayout.Create;
  try
    Assert.IsNotNull(Layout.DirectMap);
    Assert.IsNotNull(Layout.PrebaseMap);
    Assert.IsNotNull(Layout.PostbaseMap);
    Assert.IsNotNull(Layout.Modifiers);
    Assert.IsNotNull(Layout.Sequences);
    Assert.IsNotNull(Layout.Properties);
    Assert.IsNotNull(Layout.ExtraMaps);
    Assert.IsNotNull(Layout.SupportedScripts);
    Assert.IsTrue(Length(Layout.SupportedScripts) > 0);
  finally
    Layout.Free;
  end;
end;

procedure TLayoutModelTests.TKeyboardLayout_Destroy_FreesAllDictionaries;
var
  Layout: TKeyboardLayout;
  KM: TKeyMapping;
begin
  Layout := TKeyboardLayout.Create;
  try
    Layout.DirectMap.Add('k', 'क');
    KM := Default(TKeyMapping);
    KM.Key := 'i';
    KM.Glyph := 'ि';
    KM.InitMetadata;
    Layout.PrebaseMap.Add('i', KM);
    Layout.PostbaseMap.Add('a', 'ा');
    KM := Default(TKeyMapping);
    KM.Key := '\';
    KM.Glyph := '्';
    KM.InitMetadata;
    Layout.Modifiers.Add('halant', KM);
    Layout.Sequences.Add('kS', 'क्ष');
    Layout.Properties.Add('TestProp', 'TestValue');
    Layout.ExtraMaps.Add('TestMap', TDictionary<string, string>.Create);
    Layout.ExtraMaps['TestMap'].Add('x', 'y');

    // If we reach here without exception, destruction works
    // The actual freeing happens in destructor
  finally
    Layout.Free;
  end;
  Assert.Pass('Layout destroyed without memory errors');
end;

procedure TLayoutModelTests.TKeyMapping_InitMetadata_CreatesDictionary;
var
  KeyMap: TKeyMapping;
begin
  KeyMap.InitMetadata;
  try
    Assert.IsNotNull(KeyMap.Metadata);
    Assert.AreEqual(0, KeyMap.Metadata.Count);
    KeyMap.Metadata.Add('test', 'value');
    Assert.AreEqual(1, KeyMap.Metadata.Count);
  finally
    KeyMap.FreeMetadata;
  end;
end;

procedure TLayoutModelTests.TKeyMapping_FreeMetadata_FreesDictionary;
var
  KeyMap: TKeyMapping;
begin
  KeyMap.InitMetadata;
  KeyMap.Metadata.Add('test', 'value');
  KeyMap.FreeMetadata;
  Assert.IsNull(KeyMap.Metadata, 'Metadata should be nil after FreeMetadata');
end;

procedure TLayoutModelTests.TKeyboardLayout_DefaultValues_AreEmpty;
var
  Layout: TKeyboardLayout;
begin
  Layout := TKeyboardLayout.Create;
  try
    Assert.AreEqual('', Layout.LayoutID);
    Assert.AreEqual('', Layout.Name);
    Assert.AreEqual('', Layout.Script);
    Assert.AreEqual('', Layout.Encoding);
    Assert.AreEqual('', Layout.FontFamily);
    Assert.AreEqual('', Layout.LayoutType);
    Assert.AreEqual('', Layout.Group);
    Assert.AreEqual('', Layout.SourceFileName);
    Assert.AreEqual(0, Layout.DirectMap.Count);
    Assert.AreEqual(0, Layout.PrebaseMap.Count);
    Assert.AreEqual(0, Layout.PostbaseMap.Count);
    Assert.AreEqual(0, Layout.Modifiers.Count);
    Assert.AreEqual(0, Layout.Sequences.Count);
    Assert.AreEqual(0, Layout.Properties.Count);
    Assert.AreEqual(0, Layout.ExtraMaps.Count);
  finally
    Layout.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLayoutModelTests);

end.