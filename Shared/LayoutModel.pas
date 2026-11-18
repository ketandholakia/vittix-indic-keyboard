unit LayoutModel;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

const
  // The schema version this build authors (LayoutJson writes it, and it is
  // the default for layout files that omit the version field).
  CURRENT_LAYOUT_SCHEMA_VERSION = '1.1';

  // Every declared schema version this build loads and executes. "1.0"
  // layouts (the pre-1.1 files) remain fully supported; a declared version
  // outside this list is rejected rather than falsely claimed compatible.
  SUPPORTED_LAYOUT_SCHEMA_VERSIONS: array[0..1] of string = ('1.0', '1.1');

  // Maximum permitted length of a multi-key sequence key. The runtime engine no
  // longer matches multi-key sequences (legacy feature that never fired and
  // conflicted with the reph mechanism); the constant is retained so the editor
  // and validator keep authoring overlong sequence keys out of layout files.
  MAX_SEQUENCE_KEY_LEN = 4;

type

  // Generic key-value metadata for extensibility
  TLayoutProperty = record
    Name: string;
    Value: string;
  end;

  // Extensible key mapping record
  TKeyMapping = record
    Key: string;
    Glyph: string;
    // MapType carries the modifier's "behavior" tag when present (parsed by
    // LayoutFromJson): "move_to_cluster_start" (reph — the engine resolves
    // the rule by this tag, Phase B.4) and "join_next" (the phonetic halant
    // that drives auto-halant, Phase B.2). Plain map names otherwise:
    // direct, prebase, postbase, modifier, sequence, extra.
    MapType: string;
    Metadata: TDictionary<string, string>;
    procedure InitMetadata;
    procedure FreeMetadata;
  end;

  TKeyboardLayout = class
  public
    // --- Metadata ---
    SourceFileName: string;
    LayoutID: string;
    Version: string;       // Schema/format version (e.g., "1.0", "1.1")
    Name: string;
    Script: string;        // Devanagari, Gujarati, etc.
    Encoding: string;      // legacy / unicode
    FontFamily: string;    // SHREE-GUJ-0708, etc.
    LayoutType: string;    // standard / remington / phonetic
    Group: string;
    Properties: TDictionary<string, string>; // extensible metadata

    // --- Key maps ---
    DirectMap: TDictionary<string, string>;            // k → ¬
    PrebaseMap: TDictionary<string, TKeyMapping>;      // f → i-matra (generic)
    PostbaseMap: TDictionary<string, string>;          // = → ा
    Modifiers: TDictionary<string, TKeyMapping>;       // halant, reph (generic)
    Sequences: TDictionary<string, string>;            // k\s → क्ष
    ExtraMaps: TDictionary<string, TDictionary<string, string>>; // for future scripts

    // Item 9.4: optional per-key classification of DIRECT entries
    // ("consonant" | "vowel" | "other"). The engine opens its consonant
    // cluster context only for "consonant"-class direct outputs; unlisted
    // keys (and layouts without the section) keep the historical behavior —
    // every direct output opens the cluster. Optional: absent for layouts
    // that do not opt in.
    DirectClasses: TDictionary<string, string>;

    SupportedScripts: TArray<string>; // for UI/editor

    constructor Create;
    destructor Destroy; override;
  end;

// True when AVersion is a declared schema version this build understands.
function IsSupportedLayoutSchemaVersion(const AVersion: string): Boolean;

// "1.0, 1.1" — for validator messages listing what IS supported.
function SupportedLayoutSchemaVersionsText: string;

implementation

{ --------------------------------------------------
  Schema version helpers
-------------------------------------------------- }
function IsSupportedLayoutSchemaVersion(const AVersion: string): Boolean;
var
  V: string;
begin
  for V in SUPPORTED_LAYOUT_SCHEMA_VERSIONS do
    if AVersion = V then
      Exit(True);
  Result := False;
end;

function SupportedLayoutSchemaVersionsText: string;
var
  V: string;
begin
  Result := '';
  for V in SUPPORTED_LAYOUT_SCHEMA_VERSIONS do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + V;
  end;
end;

{ --------------------------------------------------
  TKeyMapping helpers
-------------------------------------------------- }
procedure TKeyMapping.InitMetadata;
begin
  Metadata := TDictionary<string, string>.Create;
end;

procedure TKeyMapping.FreeMetadata;
begin
  if Assigned(Metadata) then
  begin
    Metadata.Free;
    Metadata := nil;
  end;
end;

{ --------------------------------------------------
  Constructor
-------------------------------------------------- }
constructor TKeyboardLayout.Create;
begin
  inherited Create;
  Version := CURRENT_LAYOUT_SCHEMA_VERSION;
  DirectMap   := TDictionary<string, string>.Create;
  PrebaseMap  := TDictionary<string, TKeyMapping>.Create;
  PostbaseMap := TDictionary<string, string>.Create;
  Modifiers   := TDictionary<string, TKeyMapping>.Create;
  Sequences   := TDictionary<string, string>.Create;
  Properties  := TDictionary<string, string>.Create;
  DirectClasses := TDictionary<string, string>.Create;
  ExtraMaps   := TDictionary<string, TDictionary<string, string>>.Create;
  SupportedScripts := TArray<string>.Create('Devanagari', 'Gujarati', 'Tamil', 'Bengali', 'Kannada', 'Malayalam', 'Oriya', 'Punjabi', 'Telugu', 'Sinhala');
end;

{ --------------------------------------------------
  Destructor
-------------------------------------------------- }
destructor TKeyboardLayout.Destroy;
var
  Map: TDictionary<string, string>;
  KeyMap: TKeyMapping;
begin
  // Free per-entry metadata dictionaries in PrebaseMap
  if Assigned(PrebaseMap) then
    for KeyMap in PrebaseMap.Values do
      KeyMap.FreeMetadata;

  // Free per-entry metadata dictionaries in Modifiers
  if Assigned(Modifiers) then
    for KeyMap in Modifiers.Values do
      KeyMap.FreeMetadata;

  DirectMap.Free;
  PrebaseMap.Free;
  PostbaseMap.Free;
  Modifiers.Free;
  Sequences.Free;
  Properties.Free;
  DirectClasses.Free;
  if Assigned(ExtraMaps) then
    for Map in ExtraMaps.Values do
      Map.Free;
  ExtraMaps.Free;
  inherited Destroy;
end;

end.
