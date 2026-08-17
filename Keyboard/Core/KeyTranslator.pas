unit KeyTranslator;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  EngineState;

type
  TOnTranslatedKey = procedure(const AKey: string) of object;

procedure SetTranslatorHandler(AHandler: TOnTranslatedKey);
procedure TranslateKey(const AKey: string);

implementation

var
  TranslatorHandler: TOnTranslatedKey = nil;

{ --------------------------------------------------
  Translate printable character
-------------------------------------------------- }
procedure TranslateKey(const AKey: string);
begin
  if not EngineEnabled then
    Exit;

  if Assigned(TranslatorHandler) then
    TranslatorHandler(AKey);
end;

{ --------------------------------------------------
  Public API
-------------------------------------------------- }

procedure SetTranslatorHandler(AHandler: TOnTranslatedKey);
begin
  TranslatorHandler := AHandler;
end;

end.
