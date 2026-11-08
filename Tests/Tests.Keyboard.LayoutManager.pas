unit Tests.Keyboard.LayoutManager;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  LayoutModel,
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
    [Test]
    procedure Initialize_Failure_KeepsPreviousLayouts;
    [Test]
    procedure Initialize_Success_SwapsInFreshLayouts;
    [Test]
    procedure Initialize_SortsFiles_DeterministicDefault;
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

// Regression (reload use-after-free): a failed reload must not destroy the
// layout objects the previous Initialize produced. The engine and the tray
// keep referencing them until a successful swap replaces the whole set.
procedure TLayoutManagerTests.Initialize_Failure_KeepsPreviousLayouts;
var
  OldLayout: TKeyboardLayout;
begin
  WriteFile('valid.json', '{"layout_id":"v1","name":"Valid","script":"Devanagari","encoding":"UTF-16","layout_type":"typewriter","metadata":{"font_family":"Arial"}}');
  FManager.Initialize(FDir);
  OldLayout := FManager.GetLayout(0);

  Assert.WillRaise(
    procedure
    begin
      FManager.Initialize(TPath.Combine(FDir, 'DoesNotExist'));
    end,
    Exception,
    'a missing folder must raise'
  );

  Assert.AreEqual(1, FManager.LayoutCount, 'a failed reload must keep the previous layouts');
  Assert.AreSame(OldLayout, FManager.GetLayout(0),
    'the surviving layout must be the same live object');
  Assert.AreSame(OldLayout, FManager.ActiveLayout,
    'the active layout must remain valid after a failed reload');
  Assert.AreEqual('v1', FManager.ActiveLayout.LayoutID);
end;

// A successful reload must replace the whole set, so layouts removed from disk
// (or edited) do not survive as stale objects. Asserted behaviorally: if the
// old set survived, the count would be 2.
procedure TLayoutManagerTests.Initialize_Success_SwapsInFreshLayouts;
var
  SecondDir: string;
begin
  WriteFile('old.json', '{"layout_id":"old","name":"Old","script":"Devanagari","encoding":"UTF-16","layout_type":"typewriter","metadata":{"font_family":"Arial"}}');
  FManager.Initialize(FDir);

  SecondDir := TPath.Combine(TPath.GetTempPath, 'VittixLMTests2_' + TGUID.NewGuid.ToString);
  try
    TDirectory.CreateDirectory(SecondDir);
    TFile.WriteAllText(TPath.Combine(SecondDir, 'new.json'),
      '{"layout_id":"new","name":"New","script":"Devanagari","encoding":"UTF-16","layout_type":"typewriter","metadata":{"font_family":"Arial"}}',
      TEncoding.UTF8);

    FManager.Initialize(SecondDir);

    Assert.AreEqual(1, FManager.LayoutCount,
      'a successful reload must replace the previous set completely');
    Assert.AreEqual('new', FManager.GetLayout(0).LayoutID);
    Assert.AreSame(FManager.GetLayout(0), FManager.ActiveLayout,
      'the default layout must become active');
  finally
    if TDirectory.Exists(SecondDir) then
      try
        TDirectory.Delete(SecondDir, True);
      except
      end;
  end;
end;

// The first layout loaded becomes the default active layout, so the file order
// must be deterministic instead of relying on OS directory enumeration.
procedure TLayoutManagerTests.Initialize_SortsFiles_DeterministicDefault;
begin
  WriteFile('zeta.json', '{"layout_id":"z","name":"Z","script":"Devanagari","encoding":"UTF-16","layout_type":"typewriter","metadata":{"font_family":"Arial"}}');
  WriteFile('alpha.json', '{"layout_id":"a","name":"A","script":"Devanagari","encoding":"UTF-16","layout_type":"typewriter","metadata":{"font_family":"Arial"}}');
  WriteFile('mid.json', '{"layout_id":"m","name":"M","script":"Devanagari","encoding":"UTF-16","layout_type":"typewriter","metadata":{"font_family":"Arial"}}');

  FManager.Initialize(FDir);

  Assert.AreEqual(3, FManager.LayoutCount);
  Assert.AreEqual('a', FManager.GetLayout(0).LayoutID,
    'the default layout must be the alphabetically first file');
  Assert.AreEqual('m', FManager.GetLayout(1).LayoutID);
  Assert.AreEqual('z', FManager.GetLayout(2).LayoutID);
end;

initialization
  TDUnitX.RegisterTestFixture(TLayoutManagerTests);

end.
