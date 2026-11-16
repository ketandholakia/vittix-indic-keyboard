unit EngineState;

interface

uses
  System.SysUtils;

const
  // Item 9.1: the emitted-length stack is bounded so long pass-through runs
  // (digits, punctuation, foreign text) cannot grow it without bound; the
  // oldest entries are dropped. Deep backspacing into text typed before the
  // window covered by the stack fails safe to single-unit deletion.
  MAX_EMITTED_UNITS = 256;

type
  TEngineState = record
    Enabled: Boolean;
    HasActiveLayout: Boolean;
    KeyBuffer: string;
    PendingPrebase: string;
    PendingPostbase: string;
    PendingReph: Boolean;
    CurrentCluster: string;
    LastOutput: string; // Added to resolve E2003 error
    // Item 6: UTF-16 code-unit lengths of what this engine (or a native
    // pass-through key) put on screen, most recent last. One Backspace deletes
    // the last glyph, which can span several units ("vks", ",%#"). Survives
    // individual backspaces and natively-passed printable keys (item 9.1);
    // cleared only by events that may move the caret or change the field:
    // disable, layout switch, Tab/Enter, navigation/shortcut/foreground
    // resets, and injection failure. Bounded by MAX_EMITTED_UNITS.
    EmittedUnits: TArray<Integer>;
  end;

procedure InitEngineState;
procedure ResetEngineState;
function EngineEnabled: Boolean;
procedure SetEngineEnabled(AValue: Boolean);
function EngineHasActiveLayout: Boolean;
procedure SetEngineHasActiveLayout(AValue: Boolean);

var
  gEngineState: TEngineState;

implementation

procedure InitEngineState;
begin
  gEngineState := Default(TEngineState);
  gEngineState.Enabled := True;
end;

procedure ResetEngineState;
begin
  gEngineState.KeyBuffer := '';
  gEngineState.PendingPrebase := '';
  gEngineState.PendingPostbase := '';
  gEngineState.PendingReph := False;
  gEngineState.CurrentCluster := '';
  gEngineState.LastOutput := ''; // Initialize LastOutput
  // Item 6: the emitted-length stack is part of the typing flow, so every
  // reset abandons it (the next Backspace then fails safe to one unit).
  gEngineState.EmittedUnits := nil;
end;

function EngineEnabled: Boolean;
begin
  Result := gEngineState.Enabled;
end;

procedure SetEngineEnabled(AValue: Boolean);
begin
  gEngineState.Enabled := AValue;
  if not AValue then
    ResetEngineState;
end;

function EngineHasActiveLayout: Boolean;
begin
  Result := gEngineState.HasActiveLayout;
end;

procedure SetEngineHasActiveLayout(AValue: Boolean);
begin
  gEngineState.HasActiveLayout := AValue;
end;

end.