unit LayoutModel;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  { ---------- Pre-base matra (e.g. i-matra) ---------- }
  TPrebaseMatra = record
    Glyph: string;      // legacy glyph code
    MatraType: string;  // metadata (i-matra, etc.)
  end;

  { ---------- Modifier rule (halant, reph, etc.) ---------- }
  TModifierRule = record
    Key: string;        // key pressed (e.g. "\", "Z")
    Glyph: string;      // glyph to inject
    Behavior: string;   // join_next, move_to_cluster_start, etc.
  end;

  { ---------- Keyboard layout model ---------- }
  TKeyboardLayout = class
  public
    // --- Metadata ---
    LayoutID: string;
    Name: string;
    Script: string;        // Devanagari, Gujarati, etc.
    Encoding: string;      // legacy / unicode
    FontFamily: string;    // SHREE-GUJ-0708, etc.
    LayoutType: string;    // standard / remington / phonetic
    Group: string;

    // --- Key maps ---
    DirectMap: TDictionary<string, string>;            // k → ¬
    PrebaseMap: TDictionary<string, TPrebaseMatra>;    // f → i-matra
    PostbaseMap: TDictionary<string, string>;          // = → ा
    Modifiers: TDictionary<string, TModifierRule>;     // halant, reph
    Sequences: TDictionary<string, string>;            // k\s → क्ष

    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ --------------------------------------------------
  Constructor
-------------------------------------------------- }
constructor TKeyboardLayout.Create;
begin
  inherited Create;

  DirectMap   := TDictionary<string, string>.Create;
  PrebaseMap  := TDictionary<string, TPrebaseMatra>.Create;
  PostbaseMap := TDictionary<string, string>.Create;
  Modifiers   := TDictionary<string, TModifierRule>.Create;
  Sequences   := TDictionary<string, string>.Create;
end;

{ --------------------------------------------------
  Destructor
-------------------------------------------------- }
destructor TKeyboardLayout.Destroy;
begin
  DirectMap.Free;
  PrebaseMap.Free;
  PostbaseMap.Free;
  Modifiers.Free;
  Sequences.Free;

  inherited Destroy;
end;

end.
