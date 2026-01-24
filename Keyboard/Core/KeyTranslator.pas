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
procedure TranslateVK(vkCode: DWORD);

implementation

var
  TranslatorHandler: TOnTranslatedKey = nil;

{ --------------------------------------------------
  Send special keys directly to OS
-------------------------------------------------- }
procedure SendVK(vk: WORD);
var
  Inp: TInput;
begin
  ZeroMemory(@Inp, SizeOf(Inp));
  Inp.Itype := INPUT_KEYBOARD;
  Inp.ki.wVk := vk;
  SendInput(1, Inp, SizeOf(Inp));

  Inp.ki.dwFlags := KEYEVENTF_KEYUP;
  SendInput(1, Inp, SizeOf(Inp));
end;

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
  Translate virtual keys (space, backspace, etc.)
-------------------------------------------------- }
procedure TranslateVK(vkCode: DWORD);
begin
  if not EngineEnabled then
    Exit;

  case vkCode of
    VK_SPACE:
      begin
        // Commit cluster, reset state
        ResetEngineState;
        SendVK(VK_SPACE);
      end;

    VK_RETURN:
      begin
        ResetEngineState;
        SendVK(VK_RETURN);
      end;

    VK_TAB:
      begin
        ResetEngineState;
        SendVK(VK_TAB);
      end;

    VK_BACK:
      begin
        // Future: cluster-aware backspace
        ResetEngineState;
        SendVK(VK_BACK);
      end;

    VK_ESCAPE:
      begin
        ResetEngineState;
      end;
  end;
end;

{ --------------------------------------------------
  Public API
-------------------------------------------------- }

procedure SetTranslatorHandler(AHandler: TOnTranslatedKey);
begin
  TranslatorHandler := AHandler;
end;

end.
