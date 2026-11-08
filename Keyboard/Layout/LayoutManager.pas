unit LayoutManager;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  LayoutModel,
  LayoutLoader,
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

procedure TLayoutManager.SetActiveLayoutByID(const LayoutID: string);
var
  L: TKeyboardLayout;
begin
  for L in FLayouts do
    if SameText(L.LayoutID, LayoutID) then
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