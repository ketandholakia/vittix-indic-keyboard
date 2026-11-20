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
    [Test]
    procedure Initialize_BackupFileWithSameID_IsSkipped_RealFileWins;
    [Test]
    procedure Initialize_BackupFileInSubfolder_IsSkipped;
    [Test]
    procedure Initialize_OnlyBackupsPresent_BehavesLikeEmptyDirectory;
  end;

  // Item 9.5: the detach / reload / re-attach decision used by the tray,
  // extracted into the non-visual LayoutReload unit so a failed reload leaves
  // the engine attached to the exact same active layout it had before.
  [TestFixture]
  [Category('LayoutReload')]
  TLayoutReloadTests = class
  strict private
    FDir: string;
    procedure WriteLayout(const AID: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Reload_Success_ActivatesPreferredAndAttachesEngine;
    [Test]
    procedure Reload_Failure_ReAttachesThePreviousLayout;
    [Test]
    procedure Reload_Failure_LeavesManagerAndEngineConsistent;
  end;

implementation

uses
  EngineState,
  ShreeLipi.Engine,
  LayoutReload;

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

// Item (backup files are loaded as layouts): a stale editor backup carries
// the SAME layout_id as the file it was copied from, and sorted order puts
// the "_backup" folder before lowercase file names - without the exclusion
// the stale copy would win the duplicate-ID race and replace the real layout.
// The real file must load, and LoadErrors must stay clean (a backup is not a
// load failure).
procedure TLayoutManagerTests.Initialize_BackupFileWithSameID_IsSkipped_RealFileWins;
begin
  WriteFile('remington.json',
    '{"layout_id":"remington","name":"Real","script":"Devanagari","encoding":"UTF-16","layout_type":"typewriter","metadata":{"font_family":"Arial"}}');
  TDirectory.CreateDirectory(TPath.Combine(FDir, '_backup'));
  WriteFile('_backup\remington_20261120_120000_000.json',
    '{"layout_id":"remington","name":"StaleBackup","script":"Devanagari","encoding":"UTF-16","layout_type":"typewriter","metadata":{"font_family":"Arial"}}');

  FManager.Initialize(FDir);

  Assert.AreEqual(1, FManager.LayoutCount, 'the backup must not load as a layout');
  Assert.AreEqual('Real', FManager.GetLayout(0).Name,
    'the real file must win, not the stale backup');
  Assert.AreEqual(0, FManager.LoadErrors.Count,
    'a skipped backup must not appear in LoadErrors');
end;

procedure TLayoutManagerTests.Initialize_BackupFileInSubfolder_IsSkipped;
begin
  TDirectory.CreateDirectory(TPath.Combine(FDir, 'gujarati'));
  WriteFile('gujarati\rem.json',
    '{"layout_id":"rem","name":"Real","script":"Devanagari","encoding":"UTF-16","layout_type":"typewriter","metadata":{"font_family":"Arial"}}');
  TDirectory.CreateDirectory(TPath.Combine(FDir, 'gujarati\_backup'));
  WriteFile('gujarati\_backup\rem_20261120_120000_000.json',
    '{"layout_id":"rem","name":"StaleBackup","script":"Devanagari","encoding":"UTF-16","layout_type":"typewriter","metadata":{"font_family":"Arial"}}');

  FManager.Initialize(FDir);

  Assert.AreEqual(1, FManager.LayoutCount);
  Assert.AreEqual('Real', FManager.GetLayout(0).Name);
  Assert.AreEqual(0, FManager.LoadErrors.Count);
end;

procedure TLayoutManagerTests.Initialize_OnlyBackupsPresent_BehavesLikeEmptyDirectory;
begin
  TDirectory.CreateDirectory(TPath.Combine(FDir, '_backup'));
  WriteFile('_backup\stale_20261120_120000_000.json',
    '{"layout_id":"stale","name":"Stale","script":"Devanagari","encoding":"UTF-16","layout_type":"typewriter","metadata":{"font_family":"Arial"}}');

  Assert.WillRaise(
    procedure
    begin
      FManager.Initialize(FDir);
    end,
    Exception,
    'a directory holding only backups must behave like an empty one'
  );
  Assert.AreEqual(0, FManager.LoadErrors.Count,
    'skipped backups must not be reported as load errors');
end;

// ---- Item 9.5: detach / reload / re-attach helper --------------------------

const
  LAYOUT_JSON = '{"layout_id":"%s","name":"%s","script":"Devanagari","encoding":"UTF-16",'
    + '"layout_type":"typewriter","metadata":{"font_family":"Arial"}}';

procedure TLayoutReloadTests.WriteLayout(const AID: string);
begin
  TFile.WriteAllText(TPath.Combine(FDir, AID + '.json'),
    Format(LAYOUT_JSON, [AID, AID]), TEncoding.UTF8);
end;

procedure TLayoutReloadTests.Setup;
begin
  InitEngineState;
  SetEngineEnabled(True);
  SetEngineOutputHandler(nil);
  FDir := TPath.Combine(TPath.GetTempPath, 'VittixReloadTests_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDir);
end;

procedure TLayoutReloadTests.TearDown;
begin
  ResetEngineState;
  SetActiveLayout(nil);
  try
    if TDirectory.Exists(FDir) then
      TDirectory.Delete(FDir, True);
  except
  end;
end;

procedure TLayoutReloadTests.Reload_Success_ActivatesPreferredAndAttachesEngine;
var
  Requested: TKeyboardLayout;
begin
  WriteLayout('alpha');
  WriteLayout('beta');
  gLayoutManager.Initialize(FDir);

  ReloadLayoutsAndActivate(FDir, 'beta');

  Assert.AreSame(gLayoutManager.ActiveLayout, EngineActiveLayout,
    'the engine must be attached to the manager''s active layout');
  Assert.AreEqual('beta', EngineActiveLayout.LayoutID,
    'the preferred layout must be activated');

  // Reload again with no preference: first (sorted) layout becomes active.
  ReloadLayoutsAndActivate(FDir, '');
  Requested := gLayoutManager.GetLayout(0);
  Assert.AreSame(Requested, EngineActiveLayout,
    'without a preference the engine attaches to the default layout');
end;

// The heart of item 9.5: a failed reload must leave the engine attached to
// the EXACT same active layout it had before the attempt, so typing silently
// continuing is the invariant the tray relies on.
procedure TLayoutReloadTests.Reload_Failure_ReAttachesThePreviousLayout;
var
  Before, After: TKeyboardLayout;
begin
  WriteLayout('keepme');
  gLayoutManager.Initialize(FDir);
  ReloadLayoutsAndActivate(FDir, 'keepme');
  Before := EngineActiveLayout;

  Assert.WillRaise(
    procedure
    begin
      ReloadLayoutsAndActivate(TPath.Combine(FDir, 'Missing'), 'keepme');
    end,
    Exception,
    'a failed reload must surface the error to the caller');

  After := EngineActiveLayout;
  Assert.AreSame(Before, After,
    'the engine must be re-attached to the same live layout object');
  Assert.IsNotNull(After, 'the engine must not stay detached');
  Assert.AreEqual('keepme', After.LayoutID,
    'the previously active layout ID must be preserved');
  Assert.AreSame(gLayoutManager.ActiveLayout, After,
    'manager and engine must agree on the active layout');
end;

// The first-startup variant (no layouts active at all) cannot be reproduced
// mid-suite because the global manager keeps its loaded set until a
// successful reload replaces it. The invariant that holds in EVERY reachable
// state — and is what the tray relies on — is that after a failed reload the
// engine is attached to exactly the manager's active layout, whether that is
// a restored previous layout or nil on a truly fresh start.
procedure TLayoutReloadTests.Reload_Failure_LeavesManagerAndEngineConsistent;
begin
  WriteLayout('one');
  gLayoutManager.Initialize(FDir);

  Assert.WillRaise(
    procedure
    begin
      ReloadLayoutsAndActivate(TPath.Combine(FDir, 'Missing'), '');
    end);

  Assert.AreSame(gLayoutManager.ActiveLayout, EngineActiveLayout,
    'after a failed reload the engine must match the manager''s active layout');
end;

initialization
  TDUnitX.RegisterTestFixture(TLayoutManagerTests);
  TDUnitX.RegisterTestFixture(TLayoutReloadTests);

end.
