unit EngineState;

interface

uses
  System.SysUtils;

type
  TEngineState = record
    Enabled: Boolean;
    KeyBuffer: string;
    PendingPrebase: string;
    PendingPostbase: string;
    PendingReph: Boolean;
    CurrentCluster: string;
    LastOutput: string; // Added to resolve E2003 error
  end;

procedure InitEngineState;
procedure ResetEngineState;
function EngineEnabled: Boolean;
procedure SetEngineEnabled(AValue: Boolean);

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

end.
