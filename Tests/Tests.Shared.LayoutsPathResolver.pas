unit Tests.Shared.LayoutsPathResolver;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IniFiles,
  System.IOUtils,
  System.Hash,
  System.JSON,
  LayoutsPathResolver;

type
  // Review fix (issue 6) follow-up: the three-step layouts-folder resolution
  // core now lives in the shared LayoutsPathResolver unit (used by the tray
  // app AND the standalone editor), so its tests moved here from
  // Tests.Keyboard.AppSettings. All tests run against private temporary
  // directories - no user profile access.
  [TestFixture]
  TLayoutsPathResolverTests = class
  strict private
    FDir: string;
    function NewTempDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ConfiguredWritable_Wins;
    [Test]
    procedure ConfiguredMissing_SeedsAppDataLayouts;
    [Test]
    procedure Seeding_SkipsBackupFolders;
    [Test]
    procedure AppDataAlreadyPresent_IsNotReseeded;
    [Test]
    procedure AppDataCreationFails_FallsBackToFallbackDir;
    [Test]
    procedure ReadConfiguredLayoutsPath_ReturnsIniValue_AbsoluteAndRelative;
    [Test]
    procedure ReadConfiguredLayoutsPath_MissingOrEmptyIni_ReturnsEmpty;
    [Test]
    procedure DefaultAppDataRoot_PointsAtTheVittixFolder;
    [Test]
    procedure SeededUpdate_NonAppDataPath_IsUntouched;
    [Test]
    procedure SeededUpdate_MissingPerUserFile_IsCopied;
    [Test]
    procedure SeededUpdate_UnchangedFileWithNewerShipped_IsOverwritten;
    [Test]
    procedure SeededUpdate_UserModifiedFile_IsLeftAloneWithWarning;
    [Test]
    procedure SeededUpdate_BootstrapWithoutManifest_AdoptsIdenticalFiles;
    [Test]
    procedure SeededUpdate_UserCreatedFiles_NeverTouched;
    [Test]
    procedure SeededUpdate_ManifestWritten_RecordsHashesAndVersion;
    [Test]
    procedure SeededUpdate_InvalidManifestFiles_DoesNotBlockStartup;
    [Test]
    procedure SeededUpdate_LockedUserFile_IsLeftAlone_AndOtherFilesContinue;
  end;

implementation

procedure TLayoutsPathResolverTests.Setup;
begin
  FDir := TPath.GetFullPath(TPath.Combine(TPath.GetTempPath,
    'VittixLayoutsResolveTests_' + TGUID.NewGuid.ToString));
  TDirectory.CreateDirectory(FDir);
end;

procedure TLayoutsPathResolverTests.TearDown;
begin
  try
    if TDirectory.Exists(FDir) then
      TDirectory.Delete(FDir, True);
  except
    // Best-effort cleanup.
  end;
  FDir := '';
end;

function TLayoutsPathResolverTests.NewTempDir: string;
begin
  Result := TPath.Combine(FDir, 'root_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(Result);
end;

// (1) An existing, writable configured path is used as-is.
procedure TLayoutsPathResolverTests.ConfiguredWritable_Wins;
var
  Configured, Resolved: string;
begin
  Configured := NewTempDir;
  TFile.WriteAllText(TPath.Combine(Configured, 'layout.json'), '{}');
  Resolved := ResolveLayoutsPath(Configured, NewTempDir, NewTempDir + '\fallback');

  Assert.AreEqual(Configured, Resolved,
    'a writable configured path must win over every fallback');
end;

// (2) A missing configured path falls back to <appdata>\layouts, which is
// created on demand and seeded ONCE from the fallback (installed) folder.
procedure TLayoutsPathResolverTests.ConfiguredMissing_SeedsAppDataLayouts;
var
  AppDataRoot, Fallback, Resolved: string;
begin
  AppDataRoot := NewTempDir;
  Fallback := NewTempDir;
  // Seed source: a layout at the root AND one in a script subfolder, so the
  // recursive copy is proven.
  TFile.WriteAllText(TPath.Combine(Fallback, 'base.json'), '{}');
  TDirectory.CreateDirectory(TPath.Combine(Fallback, 'devnagari'));
  TFile.WriteAllText(TPath.Combine(Fallback, 'devnagari', 'sub.json'), '{}');

  Resolved := ResolveLayoutsPath(TPath.Combine(FDir, 'NotThere'), AppDataRoot, Fallback);

  Assert.AreEqual(TPath.Combine(AppDataRoot, 'layouts'), Resolved,
    'the per-user layouts folder must be used');
  Assert.IsTrue(TFile.Exists(TPath.Combine(Resolved, 'base.json')),
    'the shipped defaults must be copied');
  Assert.IsTrue(TFile.Exists(TPath.Combine(Resolved, 'devnagari', 'sub.json')),
    'script subfolders must be copied recursively');
end;

// Item (backup files are loaded as layouts): the seeding copy must not carry
// editor _backup folders into the fresh per-user layouts home.
procedure TLayoutsPathResolverTests.Seeding_SkipsBackupFolders;
var
  AppDataRoot, Fallback, Resolved: string;
begin
  AppDataRoot := NewTempDir;
  Fallback := NewTempDir;
  TFile.WriteAllText(TPath.Combine(Fallback, 'real.json'), '{}');
  TDirectory.CreateDirectory(TPath.Combine(Fallback, '_backup'));
  TFile.WriteAllText(TPath.Combine(Fallback, '_backup', 'real_stale.json'), '{}');

  Resolved := ResolveLayoutsPath(TPath.Combine(FDir, 'NotThere'), AppDataRoot, Fallback);

  Assert.IsTrue(TFile.Exists(TPath.Combine(Resolved, 'real.json')),
    'the shipped layout must be seeded');
  Assert.IsFalse(TDirectory.Exists(TPath.Combine(Resolved, '_backup')),
    'a backup folder next to the shipped layouts must not be copied');
end;

// The per-user copy is created once: an existing appdata layouts folder is
// reused as-is and never re-seeded (it may hold user edits).
procedure TLayoutsPathResolverTests.AppDataAlreadyPresent_IsNotReseeded;
var
  AppDataRoot, Fallback, AppDataLayouts, Resolved: string;
begin
  AppDataRoot := NewTempDir;
  Fallback := NewTempDir;
  TFile.WriteAllText(TPath.Combine(Fallback, 'shipped.json'), '{}');

  AppDataLayouts := TPath.Combine(AppDataRoot, 'layouts');
  TDirectory.CreateDirectory(AppDataLayouts);
  TFile.WriteAllText(TPath.Combine(AppDataLayouts, 'user-edit.json'), '{}');

  Resolved := ResolveLayoutsPath(TPath.Combine(FDir, 'NotThere'), AppDataRoot, Fallback);

  Assert.AreEqual(AppDataLayouts, Resolved);
  Assert.IsTrue(TFile.Exists(TPath.Combine(Resolved, 'user-edit.json')),
    'existing per-user content must be untouched');
  Assert.IsFalse(TFile.Exists(TPath.Combine(Resolved, 'shipped.json')),
    'an existing folder must not be re-seeded');
end;

// (3) When the app-data root cannot host the layouts folder (here: the root
// path goes THROUGH an existing file), the exe-relative fallback is used.
procedure TLayoutsPathResolverTests.AppDataCreationFails_FallsBackToFallbackDir;
var
  Blocker, Fallback, Resolved: string;
begin
  Blocker := TPath.Combine(FDir, 'blocker.txt');
  TFile.WriteAllText(Blocker, 'this file blocks directory creation below it');
  Fallback := NewTempDir;

  // Root = <blocker.txt>\Vittix - ForceDirectories must fail on it.
  Resolved := ResolveLayoutsPath(TPath.Combine(FDir, 'NotThere'),
    TPath.Combine(Blocker, 'Vittix'), Fallback);

  Assert.AreEqual(Fallback, Resolved,
    'a failing app-data creation must fall back to the fallback folder');
end;

// --------------------------------------------------------------
// Item (shipped layout updates never reach existing users): the reconcile
// pass over the per-user seeded copy. All tests use temp dirs for both the
// per-user copy and the shipped tree; the per-user dir is laid out exactly
// like the resolver creates it (<root>\layouts).
// --------------------------------------------------------------

// The reconcile must no-op entirely when the resolved dir is NOT the per-user
// app-data copy (custom configured folder, exe-relative fallback).
procedure TLayoutsPathResolverTests.SeededUpdate_NonAppDataPath_IsUntouched;
var
  PerUser, Shipped, Custom: string;
  Log: TStringList;
begin
  PerUser := NewTempDir;
  Shipped := NewTempDir;
  TFile.WriteAllText(TPath.Combine(Shipped, 'a.json'), 'shipped-v2');
  Custom := NewTempDir;
  TFile.WriteAllText(TPath.Combine(Custom, 'a.json'), 'custom');

  Log := TStringList.Create;
  try
    UpdateSeededLayouts(Custom, PerUser, Shipped, '9.9', Log);

    Assert.AreEqual('custom', TFile.ReadAllText(TPath.Combine(Custom, 'a.json')),
      'a non-app-data layouts folder must never be reconciled');
    Assert.IsFalse(TFile.Exists(TPath.Combine(Custom, '.seed.json')),
      'no manifest may be written outside the per-user copy');
    Assert.AreEqual(0, Log.Count, 'a no-op reconcile reports nothing');
  finally
    Log.Free;
  end;
end;

procedure TLayoutsPathResolverTests.SeededUpdate_MissingPerUserFile_IsCopied;
var
  PerUserRoot, Shipped, Resolved: string;
begin
  PerUserRoot := NewTempDir;
  Shipped := NewTempDir;
  TDirectory.CreateDirectory(TPath.Combine(Shipped, 'gujarati'));
  TFile.WriteAllText(TPath.Combine(Shipped, 'gujarati', 'new.json'), 'shipped-content');

  Resolved := TPath.Combine(PerUserRoot, 'layouts');
  TDirectory.CreateDirectory(Resolved);
  TFile.WriteAllText(TPath.Combine(Resolved, '.seed.json'),
    '{"app_version":"1.0","files":{}}');

  UpdateSeededLayouts(Resolved, PerUserRoot, Shipped, '1.1', nil);

  Assert.AreEqual('shipped-content',
    TFile.ReadAllText(TPath.Combine(Resolved, 'gujarati', 'new.json')),
    'a per-user file missing from the seed must be copied');
end;

// The core scenario: the user never edited the file (its hash matches the
// recorded seed), the shipped file changed -> overwrite after EnsureBackup.
procedure TLayoutsPathResolverTests.SeededUpdate_UnchangedFileWithNewerShipped_IsOverwritten;
var
  PerUserRoot, Shipped, Resolved, BackupDir: string;
  Json: TJSONValue;
begin
  PerUserRoot := NewTempDir;
  Shipped := NewTempDir;
  Resolved := TPath.Combine(PerUserRoot, 'layouts');
  TDirectory.CreateDirectory(Resolved);

  // Record the OLD shipped content in the manifest.
  TFile.WriteAllText(TPath.Combine(Resolved, 'rem.json'), 'old-shipped');
  TFile.WriteAllText(TPath.Combine(Shipped, 'rem.json'), 'old-shipped');
  UpdateSeededLayouts(Resolved, PerUserRoot, Shipped, '1.0', nil);

  // A new release ships a fixed file.
  TFile.WriteAllText(TPath.Combine(Shipped, 'rem.json'), 'fixed-shipped');
  UpdateSeededLayouts(Resolved, PerUserRoot, Shipped, '1.1', nil);

  Assert.AreEqual('fixed-shipped', TFile.ReadAllText(TPath.Combine(Resolved, 'rem.json')),
    'an unmodified seeded file must receive the shipped fix');

  BackupDir := TPath.Combine(Resolved, '_backup');
  Assert.IsTrue(TDirectory.Exists(BackupDir) and
    (Length(TDirectory.GetFiles(BackupDir, '*.json')) > 0),
    'the overwritten user copy must be backed up first');

  Json := TJSONObject.ParseJSONValue(TFile.ReadAllText(TPath.Combine(Resolved, '.seed.json')));
  try
    Assert.AreEqual(THashSHA2.GetHashStringFromFile(TPath.Combine(Shipped, 'rem.json')),
      ((Json as TJSONObject).GetValue('files') as TJSONObject).GetValue('rem.json').Value,
      'the manifest must record the new shipped hash');
    Assert.AreEqual('1.1', (Json as TJSONObject).GetValue('app_version').Value,
      'the manifest must record the app version');
  finally
    Json.Free;
  end;
end;

procedure TLayoutsPathResolverTests.SeededUpdate_UserModifiedFile_IsLeftAloneWithWarning;
var
  PerUserRoot, Shipped, Resolved: string;
  Log: TStringList;
begin
  PerUserRoot := NewTempDir;
  Shipped := NewTempDir;
  Resolved := TPath.Combine(PerUserRoot, 'layouts');
  TDirectory.CreateDirectory(Resolved);

  TFile.WriteAllText(TPath.Combine(Resolved, 'rem.json'), 'old-shipped');
  TFile.WriteAllText(TPath.Combine(Shipped, 'rem.json'), 'old-shipped');
  UpdateSeededLayouts(Resolved, PerUserRoot, Shipped, '1.0', nil);

  // The user edits their copy; the release ships a fix.
  TFile.WriteAllText(TPath.Combine(Resolved, 'rem.json'), 'my edits');
  TFile.WriteAllText(TPath.Combine(Shipped, 'rem.json'), 'fixed-shipped');

  Log := TStringList.Create;
  try
    UpdateSeededLayouts(Resolved, PerUserRoot, Shipped, '1.1', Log);

    Assert.AreEqual('my edits', TFile.ReadAllText(TPath.Combine(Resolved, 'rem.json')),
      'a user-modified file must be left alone');
    Assert.IsFalse(TDirectory.Exists(TPath.Combine(Resolved, '_backup')),
      'no backup may be created when nothing is overwritten');
    Assert.IsTrue(Log.Text.Contains('warning'),
      'the skipped update must be reported');
    Assert.IsFalse(Log.Text.Contains('info: updated'),
      'no update may be reported for a user-modified file');
  finally
    Log.Free;
  end;
end;

// Existing users upgrading from a build without the manifest: files whose
// content still equals the shipped version are adopted (recorded in the
// manifest); differing files are treated as user-modified.
procedure TLayoutsPathResolverTests.SeededUpdate_BootstrapWithoutManifest_AdoptsIdenticalFiles;
var
  PerUserRoot, Shipped, Resolved: string;
begin
  PerUserRoot := NewTempDir;
  Shipped := NewTempDir;
  Resolved := TPath.Combine(PerUserRoot, 'layouts');
  TDirectory.CreateDirectory(Resolved);

  // Seeded by an older build: one file unchanged, one edited, no manifest.
  TFile.WriteAllText(TPath.Combine(Resolved, 'unchanged.json'), 'same');
  TFile.WriteAllText(TPath.Combine(Resolved, 'edited.json'), 'user text');
  TFile.WriteAllText(TPath.Combine(Shipped, 'unchanged.json'), 'same');
  TFile.WriteAllText(TPath.Combine(Shipped, 'edited.json'), 'same');

  UpdateSeededLayouts(Resolved, PerUserRoot, Shipped, '1.1', nil);

  // The unchanged file must now receive a shipped fix (it was adopted).
  TFile.WriteAllText(TPath.Combine(Shipped, 'unchanged.json'), 'fixed');
  UpdateSeededLayouts(Resolved, PerUserRoot, Shipped, '1.2', nil);
  Assert.AreEqual('fixed', TFile.ReadAllText(TPath.Combine(Resolved, 'unchanged.json')),
    'an adopted (identical) file must be tracked and updatable');

  // The edited file stays untouched.
  Assert.AreEqual('user text', TFile.ReadAllText(TPath.Combine(Resolved, 'edited.json')),
    'a differing unmanifested file must be treated as user-modified');
end;

procedure TLayoutsPathResolverTests.SeededUpdate_UserCreatedFiles_NeverTouched;
var
  PerUserRoot, Shipped, Resolved: string;
begin
  PerUserRoot := NewTempDir;
  Shipped := NewTempDir;
  Resolved := TPath.Combine(PerUserRoot, 'layouts');
  TDirectory.CreateDirectory(Resolved);

  TFile.WriteAllText(TPath.Combine(Resolved, 'mine.json'), 'user-created');
  TFile.WriteAllText(TPath.Combine(Resolved, 'mine2.json'), 'user-created-2');

  UpdateSeededLayouts(Resolved, PerUserRoot, Shipped, '1.1', nil);

  Assert.AreEqual('user-created', TFile.ReadAllText(TPath.Combine(Resolved, 'mine.json')),
    'files the user created must never be touched');
  Assert.IsTrue(TFile.Exists(TPath.Combine(Resolved, 'mine2.json')));
  Assert.IsFalse(TFile.Exists(TPath.Combine(Shipped, 'mine.json')),
    'nothing flows back into the shipped tree');
end;

procedure TLayoutsPathResolverTests.SeededUpdate_ManifestWritten_RecordsHashesAndVersion;
var
  PerUserRoot, Shipped, Resolved: string;
  Json: TJSONValue;
begin
  PerUserRoot := NewTempDir;
  Shipped := NewTempDir;
  Resolved := TPath.Combine(PerUserRoot, 'layouts');
  TDirectory.CreateDirectory(Resolved);
  TFile.WriteAllText(TPath.Combine(Shipped, 'a.json'), 'content-a');

  UpdateSeededLayouts(Resolved, PerUserRoot, Shipped, '3.2.1.0', nil);

  Json := TJSONObject.ParseJSONValue(TFile.ReadAllText(TPath.Combine(Resolved, '.seed.json')));
  try
    Assert.IsNotNull(Json, 'the manifest must be written');
    Assert.AreEqual('3.2.1.0', (Json as TJSONObject).GetValue('app_version').Value);
    Assert.AreEqual(64,
      Length(((Json as TJSONObject).GetValue('files') as TJSONObject).GetValue('a.json').Value),
      'the manifest records the SHA-256 hex of the shipped content');
    Assert.AreEqual(THashSHA2.GetHashStringFromFile(TPath.Combine(Shipped, 'a.json')),
      ((Json as TJSONObject).GetValue('files') as TJSONObject).GetValue('a.json').Value,
      'the recorded hash matches the shipped file');
  finally
    Json.Free;
  end;
end;

procedure TLayoutsPathResolverTests.SeededUpdate_LockedUserFile_IsLeftAlone_AndOtherFilesContinue;
var
  PerUserRoot, Shipped, Resolved: string;
  Locked: TFileStream;
  Log: TStringList;
begin
  PerUserRoot := NewTempDir;
  Shipped := NewTempDir;
  Resolved := TPath.Combine(PerUserRoot, 'layouts');
  TDirectory.CreateDirectory(Resolved);
  TFile.WriteAllText(TPath.Combine(Resolved, 'a.json'), 'user-edit');
  TFile.WriteAllText(TPath.Combine(Shipped, 'a.json'), 'shipped');
  TFile.WriteAllText(TPath.Combine(Shipped, 'b.json'), 'new-layout');
  Log := TStringList.Create;
  Locked := TFileStream.Create(TPath.Combine(Resolved, 'a.json'), fmOpenRead or fmShareExclusive);
  try
    UpdateSeededLayouts(Resolved, PerUserRoot, Shipped, '1.1', Log);
    Assert.IsTrue(Log.Text.Contains('warning: could not reconcile'));
    Assert.AreEqual('new-layout', TFile.ReadAllText(TPath.Combine(Resolved, 'b.json')));
  finally
    Locked.Free;
    Log.Free;
  end;
  Assert.AreEqual('user-edit', TFile.ReadAllText(TPath.Combine(Resolved, 'a.json')));
end;

procedure TLayoutsPathResolverTests.SeededUpdate_InvalidManifestFiles_DoesNotBlockStartup;
var
  PerUserRoot, Shipped, Resolved: string;
begin
  PerUserRoot := NewTempDir;
  Shipped := NewTempDir;
  Resolved := TPath.Combine(PerUserRoot, 'layouts');
  TDirectory.CreateDirectory(Resolved);
  TFile.WriteAllText(TPath.Combine(Resolved, '.seed.json'),
    '{"files":[] }');
  TFile.WriteAllText(TPath.Combine(Resolved, 'a.json'), 'user-edit');
  TFile.WriteAllText(TPath.Combine(Shipped, 'a.json'), 'shipped');
  TFile.WriteAllText(TPath.Combine(Shipped, 'b.json'), 'new-layout');

  UpdateSeededLayouts(Resolved, PerUserRoot, Shipped, '1.1', nil);

  Assert.AreEqual('user-edit', TFile.ReadAllText(TPath.Combine(Resolved, 'a.json')));
  Assert.AreEqual('new-layout', TFile.ReadAllText(TPath.Combine(Resolved, 'b.json')));
end;

procedure TLayoutsPathResolverTests.ReadConfiguredLayoutsPath_ReturnsIniValue_AbsoluteAndRelative;
var
  IniPath, ExeDir, Raw: string;
  Ini: TIniFile;
begin
  ExeDir := NewTempDir;
  IniPath := TPath.Combine(FDir, 'settings.ini');

  // No ini at all: empty.
  Assert.AreEqual('', ReadConfiguredLayoutsPath(IniPath, ExeDir),
    'a missing settings.ini must yield an empty configured path');

  // Absolute value passes through.
  Ini := TIniFile.Create(IniPath);
  try
    Ini.WriteString('Layouts', 'Path', 'D:\MyLayouts');
  finally
    Ini.Free;
  end;
  Assert.AreEqual('D:\MyLayouts', ReadConfiguredLayoutsPath(IniPath, ExeDir));

  // A stored relative path resolves against the application folder, like
  // TAppSettings.Load does.
  Ini := TIniFile.Create(IniPath);
  try
    Ini.WriteString('Layouts', 'Path', 'layouts');
  finally
    Ini.Free;
  end;
  Raw := ReadConfiguredLayoutsPath(IniPath, ExeDir);
  Assert.IsTrue(TPath.IsPathRooted(Raw),
    'relative values must be absolutized: ExeDir=' + ExeDir + '; Raw=' + Raw);
  Assert.AreEqual(IncludeTrailingPathDelimiter(ExeDir) + 'layouts', Raw);
end;

procedure TLayoutsPathResolverTests.ReadConfiguredLayoutsPath_MissingOrEmptyIni_ReturnsEmpty;
var
  IniPath: string;
  Ini: TIniFile;
begin
  // An ini WITHOUT the key yields empty (resolver then uses the app-data copy).
  IniPath := TPath.Combine(FDir, 'settings.ini');
  Ini := TIniFile.Create(IniPath);
  try
    Ini.WriteString('General', 'EnableKeyboard', '1');
  finally
    Ini.Free;
  end;
  Assert.AreEqual('', ReadConfiguredLayoutsPath(IniPath, NewTempDir),
    'a settings.ini without [Layouts] Path must yield empty');
end;

procedure TLayoutsPathResolverTests.DefaultAppDataRoot_PointsAtTheVittixFolder;
begin
  // Read-only sanity: no writes, no profile mutation.
  Assert.IsTrue(Trim(DefaultAppDataRoot) <> '', 'the app-data root must resolve');
  Assert.AreEqual('Vittix', ExtractFileName(ExcludeTrailingPathDelimiter(DefaultAppDataRoot)),
    'the root must be the Vittix folder');
end;

initialization
  TDUnitX.RegisterTestFixture(TLayoutsPathResolverTests);

end.
