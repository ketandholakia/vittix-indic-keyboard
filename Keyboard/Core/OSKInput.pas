unit OSKInput;

interface

uses
  System.SysUtils;

// QW2 (OSK click-to-type): maps a physical key name reported by the
// on-screen keyboard view — its rows always carry UPPERCASE letters, and the
// shifted rows swap the symbol keys — plus the view's shift state to the
// character the typing engine expects. Direct maps distinguish 'k' from
// 'K', so an unshifted click must reach the engine as the lowercase key.
// Multi-char names are the special keys (Space, Backspace, Shift, ...),
// which never fire OnKeySelect; mapping them to '' keeps a future firing
// from typing garbage. Pure function: no engine, no UI.
function OSKKeyNameToEngineKey(const AKeyName: string;
  const AShiftState: Boolean): string;

implementation

function OSKKeyNameToEngineKey(const AKeyName: string;
  const AShiftState: Boolean): string;
begin
  if Length(AKeyName) <> 1 then
    Exit('');

  Result := AKeyName;
  if (not AShiftState) and (Result[1] >= 'A') and (Result[1] <= 'Z') then
    Result := LowerCase(Result);
end;

end.
