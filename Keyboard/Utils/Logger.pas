unit Logger;

interface

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows;

type
  TLogLevel = (
    llDebug,
    llInfo,
    llWarning,
    llError
  );

procedure InitLogger(const ALogFile: string);
procedure EnableLogger(AEnable: Boolean);

procedure LogDebug(const Msg: string);
procedure LogInfo(const Msg: string);
procedure LogWarning(const Msg: string);
procedure LogError(const Msg: string);

procedure Log(const Msg: string; Level: TLogLevel = llInfo);

implementation

var
  gLogFile: string = '';
  gEnabled: Boolean = False;
  gCS: TRTLCriticalSection;

{ --------------------------------------------------
  Internal helpers
-------------------------------------------------- }

function LevelToStr(Level: TLogLevel): string;
begin
  case Level of
    llDebug:   Result := 'DEBUG';
    llInfo:    Result := 'INFO';
    llWarning: Result := 'WARN';
    llError:   Result := 'ERROR';
  else
    Result := 'INFO';
  end;
end;

procedure WriteLine(const Line: string);
var
  FS: TFileStream;
  S: UTF8String;
begin
  if not gEnabled then
    Exit;

  if gLogFile = '' then
    Exit;

  EnterCriticalSection(gCS);
  try
    ForceDirectories(ExtractFilePath(gLogFile));

    if FileExists(gLogFile) then
      FS := TFileStream.Create(gLogFile, fmOpenWrite or fmShareDenyNone)
    else
      FS := TFileStream.Create(gLogFile, fmCreate or fmShareDenyNone);

    try
      FS.Seek(0, soEnd);
      S := UTF8String(Line + sLineBreak);
      FS.WriteBuffer(Pointer(S)^, Length(S));
    finally
      FS.Free;
    end;
  finally
    LeaveCriticalSection(gCS);
  end;
end;

{ --------------------------------------------------
  Public API
-------------------------------------------------- }

procedure InitLogger(const ALogFile: string);
begin
  gLogFile := ALogFile;
  // NOTE: gCS is already initialized in the 'initialization' section below.
  // Do NOT call InitializeCriticalSection here — double init is undefined behavior.
end;

procedure EnableLogger(AEnable: Boolean);
begin
  gEnabled := AEnable;
end;

procedure Log(const Msg: string; Level: TLogLevel);
begin
  WriteLine(
    Format(
      '[%s] [%s] %s',
      [
        FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now),
        LevelToStr(Level),
        Msg
      ]
    )
  );
end;

procedure LogDebug(const Msg: string);
begin
  Log(Msg, llDebug);
end;

procedure LogInfo(const Msg: string);
begin
  Log(Msg, llInfo);
end;

procedure LogWarning(const Msg: string);
begin
  Log(Msg, llWarning);
end;

procedure LogError(const Msg: string);
begin
  Log(Msg, llError);
end;

initialization
  InitializeCriticalSection(gCS);

finalization
  DeleteCriticalSection(gCS);

end.
