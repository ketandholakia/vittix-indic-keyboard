unit EngineState;

interface

uses
  System.SysUtils;

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
    // Item 6: UTF-16 code-unit lengths of the glyphs this engine emitted,
    // most recent last. One Backspace deletes the last emitted glyph, which
    // can span several units ("vks", ",%#"). Survives individual backspaces;
    // cleared by every full reset (disable, layout switch, Tab/Enter,
    // navigation/focus pass-throughs).
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