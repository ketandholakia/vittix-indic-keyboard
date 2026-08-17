unit LayoutManager;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  LayoutModel,
  LayoutLoader;

type
  TLayoutManager = class
  private
    FLayouts: TObjectList<TKeyboardLayout>;
    FActiveLayout: TKeyboardLayout;
    FLayoutsPath: string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Initialize(const ALayoutsPath: string);

    function LayoutCount: Integer;
    function GetLayout(Index: Integer): TKeyboardLayout;

    procedure SetActiveLayout(Index: Integer);
    procedure SetActiveLayoutByID(const LayoutID: string);

    property ActiveLayout: TKeyboardLayout read FActiveLayout;
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
end;

destructor TLayoutManager.Destroy;
begin
  FLayouts.Free;
  inherited;
end;

{ --------------------------------------------------
  Initialize & load all layouts
-------------------------------------------------- }

procedure TLayoutManager.Initialize(const ALayoutsPath: string);
var
  Files: TArray<string>;   // ✅ FIX
  FileName: string;
  Layout: TKeyboardLayout;
  FirstLoadError: string;
begin
  FLayouts.Clear;
  FActiveLayout := nil;
  FirstLoadError := '';
  FLayoutsPath := IncludeTrailingPathDelimiter(ALayoutsPath);

  if not DirectoryExists(FLayoutsPath) then
    raise Exception.Create('Layouts folder not found: ' + FLayoutsPath);

  Files := TDirectory.GetFiles(
    FLayoutsPath,
    '*.json',
    TSearchOption.soAllDirectories
  );

  for FileName in Files do
  begin
    try
      Layout := LoadLayoutFromFile(FileName);
      FLayouts.Add(Layout);
    except
      on E: Exception do
        if FirstLoadError = '' then
          FirstLoadError := Format('%s: %s', [FileName, E.Message]);
    end;
  end;

  if FLayouts.Count > 0 then
    FActiveLayout := FLayouts[0];
  
  if FLayouts.Count = 0 then
  begin
    if FirstLoadError <> '' then
      raise Exception.Create('No layouts could be loaded. First error: ' + FirstLoadError);

    raise Exception.Create('No layout files were found in: ' + FLayoutsPath);
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

