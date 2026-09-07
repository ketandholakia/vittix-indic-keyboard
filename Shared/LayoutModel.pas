unit LayoutModel;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

const
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
    MapType: string; // e.g. direct, prebase, postbase, modifier, sequence, extra
    Metadata: TDictionary<string, string>; // extensible
    procedure InitMetadata;
    procedure FreeMetadata;
  end;

  TKeyboardLayout = class
  public
    // --- Metadata ---
    SourceFileName: string;
    LayoutID: string;
    Version: string;       // Schema/format version (e.g., "1.0")
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

    SupportedScripts: TArray<string>; // for UI/editor

    constructor Create;
    destructor Destroy; override;
  end;

implementation

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
  Version := '1.0';
  DirectMap   := TDictionary<string, string>.Create;
  PrebaseMap  := TDictionary<string, TKeyMapping>.Create;
  PostbaseMap := TDictionary<string, string>.Create;
  Modifiers   := TDictionary<string, TKeyMapping>.Create;
  Sequences   := TDictionary<string, string>.Create;
  Properties  := TDictionary<string, string>.Create;
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
  if Assigned(ExtraMaps) then
    for Map in ExtraMaps.Values do
      Map.Free;
  ExtraMaps.Free;
  inherited Destroy;
end;

end.