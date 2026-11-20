unit LayoutManager;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.StrUtils,
  System.Generics.Collections,
  LayoutModel,
  LayoutLoader,
  BackupManager,
  Logger;

type
  TLayoutManager = class
  private
    FLayouts: TObjectList<TKeyboardLayout>;
    FActiveLayout: TKeyboardLayout;
    FLayoutsPath: string;
    FLoadErrors: TStrings;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Initialize(const ALayoutsPath: string);

    function LayoutCount: Integer;
    function GetLayout(Index: Integer): TKeyboardLayout;

    procedure SetActiveLayout(Index: Integer);
    procedure SetActiveLayoutByID(const LayoutID: string);

    property ActiveLayout: TKeyboardLayout read FActiveLayout;
    property LoadErrors: TStrings read FLoadErrors;
  end;

var
  gLayoutManager: TLayoutManager; // ✅ RENAMED

implementation

{ --------------------------------------------------
  Constructor / Destructor
-------------------------------------------------- }

constructor TLayoutManager.Create;
begin
  FLayouts := TObjectList<TKeyboardLayout>.Create(True); // owns objects
  FLoadErrors := TStringList.Create;
end;

destructor TLayoutManager.Destroy;
begin
  FLayouts.Free;
  FLoadErrors.Free;
  inherited Destroy;
end;

{ --------------------------------------------------
  Initialize & load all layouts
-------------------------------------------------- }

// Item: a stale editor backup (<layoutdir>\_backup\<name>_<timestamp>.json)
// carries the SAME layout_id as the live file it was copied from, and sorted
// order puts the '_backup' folder before lowercase file names - so without
// this check the stale copy could win the duplicate-ID race and replace the
// real layout. The one shared matcher lives in BackupManager
// (PathInBackupFolder); LoadErrors is untouched, a skipped backup is not a
// load failure.

procedure TLayoutManager.Initialize(const ALayoutsPath: string);
var
  Files: TArray<string>;
  FileName: string;
  Layout: TKeyboardLayout;
  SeenLayoutIDs: TDictionary<string, string>;
  NewLayouts: TObjectList<TKeyboardLayout>;
  OldLayouts: TObjectList<TKeyboardLayout>;
begin
  // Load into a staged list and swap it in only on success: a failed reload
  // (missing folder, all-invalid files) must keep the previous layouts alive,
  // because the engine and the tray still reference them.
  NewLayouts := TObjectList<TKeyboardLayout>.Create(True);
  SeenLayoutIDs := TDictionary<string, string>.Create;
  try
    // Clear prior load errors so a reload does not accumulate stale entries.
    FLoadErrors.Clear;
    FLayoutsPath := IncludeTrailingPathDelimiter(ALayoutsPath);
    LogInfo('Loading layouts from ' + FLayoutsPath);

    if not DirectoryExists(FLayoutsPath) then
      raise Exception.Create('Layouts folder not found: ' + FLayoutsPath);

    Files := TDirectory.GetFiles(
      FLayoutsPath,
      '*.json',
      TSearchOption.soAllDirectories
    );
    // Sorted order makes the default layout (first file loaded) deterministic
    // instead of dependent on OS directory enumeration.
    TArray.Sort<string>(Files);

    for FileName in Files do
    begin
      // Editor backup copies never load as layouts (item: backup files are
      // loaded as layouts). Checked before the parse so a malformed backup
      // cannot even reach LoadErrors.
      if PathInBackupFolder(FileName) then
        Continue;

      // Dotfiles are control data, not layouts (.seed.json from the shipped
      // update mechanism lives in the layouts root).
      if ExtractFileName(FileName).StartsWith('.') then
        Continue;

      try
        Layout := LoadLayoutFromFile(FileName);
        if (Layout.LayoutID <> '') and SeenLayoutIDs.ContainsKey(Layout.LayoutID) then
        begin
          LogWarning(Format('Duplicate layout ID "%s" in %s; keeping %s', [
            Layout.LayoutID,
            FileName,
            SeenLayoutIDs[Layout.LayoutID]
          ]));
          Layout.Free;
          Continue;
        end;
        if Layout.LayoutID <> '' then
          SeenLayoutIDs.Add(Layout.LayoutID, FileName);
        NewLayouts.Add(Layout);
      except
        on E: Exception do
        begin
          FLoadErrors.Add(Format('%s: %s', [FileName, E.Message]));
          LogWarning(Format('Failed to load layout %s: %s', [FileName, E.Message]));
        end;
      end;
    end;

    if NewLayouts.Count = 0 then
    begin
      if FLoadErrors.Count > 0 then
      begin
        // Files existed but none parsed: report this as an all-invalid directory,
        // not as an empty one.
        LogError('Layout loading failed: ' + FLoadErrors[0]);
        raise Exception.Create('No layouts could be loaded. First error: ' + FLoadErrors[0]);
      end;

      LogError('No layout files found in ' + FLayoutsPath);
      raise Exception.Create('No layout files were found in: ' + FLayoutsPath);
    end;

    // Success: swap the staged list in, then release the previous set. The
    // default layout is the first file in sorted order.
    OldLayouts := FLayouts;
    FLayouts := NewLayouts;
    NewLayouts := nil;
    FActiveLayout := FLayouts[0];
    OldLayouts.Free;
    LogInfo(Format('Loaded %d layouts', [FLayouts.Count]));
  finally
    // On any failure the staged list is freed here and the previous set is
    // untouched; on success this is a no-op (ownership was transferred).
    NewLayouts.Free;
    SeenLayoutIDs.Free;
  end;
end;


{ --------------------------------------------------
  Accessors
-------------------------------------------------- }

function TLayoutManager.LayoutCount: Integer;
begin
  Result := FLayouts.Count;
end;

function TLayoutManager.GetLayout(Index: Integer): TKeyboardLayout;
begin
  Result := FLayouts[Index];
end;

{ --------------------------------------------------
  Activate layout
-------------------------------------------------- }

procedure TLayoutManager.SetActiveLayout(Index: Integer);
begin
  if (Index < 0) or (Index >= FLayouts.Count) then
    Exit;

  FActiveLayout := FLayouts[Index];
end;

{ Item (housekeeping): layout_id style is canonicalized before comparison —
  lowercased, hyphens mapped to underscores. This IS the alias map: layout
  files were renamed to the underscore-only style, but a saved DefaultLayout
  in settings.ini written by an older build (e.g. 'krutidev-010') keeps
  resolving to the renamed layout 'krutidev_010'. No stored alias table to
  drift out of sync; both spellings work forever. }
function CanonicalLayoutID(const AID: string): string;
begin
  Result := ReplaceText(Trim(AID), '-', '_').ToLower;
end;

procedure TLayoutManager.SetActiveLayoutByID(const LayoutID: string);
var
  L: TKeyboardLayout;
  Wanted: string;
begin
  Wanted := CanonicalLayoutID(LayoutID);
  if Wanted = '' then
    Exit;

  for L in FLayouts do
    if CanonicalLayoutID(L.LayoutID) = Wanted then
    begin
      FActiveLayout := L;
      Exit;
    end;
end;

{ --------------------------------------------------
  Global initialization
-------------------------------------------------- }

initialization
  gLayoutManager := TLayoutManager.Create;

finalization
  gLayoutManager.Free;

end.