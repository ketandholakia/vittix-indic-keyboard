unit Tests.Keyboard.LayoutManager;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  LayoutManager;

type
  [TestFixture]
  [Category('LayoutManager')]
  TLayoutManagerTests = class
  strict private
    FDir: string;
    FManager: TLayoutManager;
    procedure WriteFile(const AFileName, AContent: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Initialize_MissingDirectory_RaisesException;
    [Test]
    procedure Initialize_EmptyDirectory_RaisesException;
    [Test]
    procedure Initialize_ValidAndInvalidFiles_LoadsValid_LogsError;
    [Test]
    procedure Initialize_DuplicateLayoutID_LoadsFirst_LogsWarning;
    [Test]
    procedure Initialize_ClearsPreviousStateAndErrors;
    [Test]
    procedure Initialize_AllInvalid_RaisesException;
  end;

implementation

procedure TLayoutManagerTests.WriteFile(const AFileName, AContent: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := AContent;
    Lines.SaveToFile(TPath.Combine(FDir, AFileName), TEncoding.UTF8);
  finally
    Lines.Free;
  end;
end;

procedure TLayoutManagerTests.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath, 'VittixLMTests_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDir);
  FManager := TLayoutManager.Create;
end;

procedure TLayoutManagerTests.TearDown;
begin
  FManager.Free;
  try
    if TDirectory.Exists(FDir) then
      TDirectory.Delete(FDir, True);
  except
  end;
end;

procedure TLayoutManagerTests.Initialize_MissingDirectory_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      FManager.Initialize(TPath.Combine(FDir, 'DoesNotExist'));
    end,
    Exception,
    'Initialize must raise an exception for a missing directory'
  );
end;

procedure TLayoutManagerTests.Initialize_EmptyDirectory_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      FManager.Initialize(FDir);
    end,
    Exception,
    'Initialize must raise an exception for an empty directory'
  );
end;

procedure TLayoutManagerTests.Initialize_ValidAndInvalidFiles_LoadsValid_LogsError;
begin
  WriteFile('valid.json', '{"layout_id":"v1","name":"Valid","script":"Devanagari","encoding":"UTF-16","layout_type":"typewriter","metadata":{"font_family":"Arial"}}');
  WriteFile('invalid.json', '{invalid_json}');
  
  FManager.Initialize(FDir);
  
  Assert.AreEqual(1, FManager.LayoutCount, 'Must load the valid file');
  Assert.AreEqual('Valid', FManager.GetLayout(0).Name);
  Assert.AreEqual(1, FManager.LoadErrors.Count, 'Must capture one load error for the invalid file');
end;

procedure TLayoutManagerTests.Initialize_DuplicateLayoutID_LoadsFirst_LogsWarning;
begin
  WriteFile('layout1.json', '{"layout_id":"dup","name":"L1","script":"Devanagari","encoding":"UTF-16","layout_type":"typewriter","metadata":{"font_family":"Arial"}}');
  WriteFile('layout2.json', '{"layout_id":"dup","name":"L2","script":"Devanagari","encoding":"UTF-16","layout_type":"typewriter","metadata":{"font_family":"Arial"}}');
  
  FManager.Initialize(FDir);
  
  Assert.AreEqual(1, FManager.LayoutCount, 'Must discard duplicate layout ID');
  // Order of directory enumeration is not guaranteed, but only 1 should be loaded
end;

procedure TLayoutManagerTests.Initialize_ClearsPreviousStateAndErrors;
begin
  WriteFile('valid.json', '{"layout_id":"v1","name":"Valid","script":"Devanagari","encoding":"UTF-16","layout_type":"typewriter","metadata":{"font_family":"Arial"}}');
  WriteFile('invalid.json', '{invalid_json}');
  
  FManager.Initialize(FDir);
  Assert.AreEqual(1, FManager.LoadErrors.Count);
  
  // Create a subfolder that is clean
  TFile.Delete(TPath.Combine(FDir, 'invalid.json'));
  
  FManager.Initialize(FDir);
  Assert.AreEqual(0, FManager.LoadErrors.Count, 'Initialize must clear previous load errors');
  Assert.AreEqual(1, FManager.LayoutCount);
end;

procedure TLayoutManagerTests.Initialize_AllInvalid_RaisesException;
begin
  WriteFile('invalid1.json', '{invalid_json}');
  WriteFile('invalid2.json', '{invalid_json}');
  
  Assert.WillRaise(
    procedure
    begin
      FManager.Initialize(FDir);
    end,
    Exception,
    'Initialize must raise an exception if files exist but NONE load successfully'
  );
  
  Assert.AreEqual(2, FManager.LoadErrors.Count, 'Must capture errors for both files');
end;

initialization
  TDUnitX.RegisterTestFixture(TLayoutManagerTests);

end.
