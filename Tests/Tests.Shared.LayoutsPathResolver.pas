unit Tests.Shared.LayoutsPathResolver;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IniFiles,
  System.IOUtils,
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
  end;

implementation

procedure TLayoutsPathResolverTests.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath,
    'VittixLayoutsResolveTests_' + TGUID.NewGuid.ToString);
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
  Assert.IsTrue(TPath.IsPathRooted(Raw), 'relative values must be absolutized');
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
