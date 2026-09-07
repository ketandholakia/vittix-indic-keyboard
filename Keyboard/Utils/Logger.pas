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
procedure CloseLogger;
procedure EnableLogger(AEnable: Boolean);

procedure LogDebug(const Msg: string);
procedure LogInfo(const Msg: string);
procedure LogWarning(const Msg: string);
procedure LogError(const Msg: string);

procedure Log(const Msg: string; Level: TLogLevel = llInfo);

implementation

uses
  System.IOUtils;

var
  gLogFile: string = '';
  gEnabled: Boolean = False;
  gInitialized: Boolean = False;
  gCS: TRTLCriticalSection;
  gLogStream: TFileStream = nil;

const
  MAX_LOG_SIZE = 1 * 1024 * 1024; // 1 MB
  MAX_LOG_FILES = 3;

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

procedure EnsureInitialized;
begin
  if gInitialized then
    Exit;

  // Initialize to default log file if not explicitly initialized
  if gLogFile = '' then
    gLogFile := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'logs\vittix-keyboard.log');

  gInitialized := True;
end;

procedure RotateLogs;
var
  I: Integer;
  OldFile, NewFile: string;
begin
  if Assigned(gLogStream) then
  begin
    gLogStream.Free;
    gLogStream := nil;
  end;

  for I := MAX_LOG_FILES - 1 downto 1 do
  begin
    OldFile := gLogFile + '.' + IntToStr(I);
    NewFile := gLogFile + '.' + IntToStr(I + 1);
    if FileExists(OldFile) then
    begin
      if FileExists(NewFile) then
        System.SysUtils.DeleteFile(NewFile);
      System.SysUtils.RenameFile(OldFile, NewFile);
    end;
  end;

  if FileExists(gLogFile) then
    System.SysUtils.RenameFile(gLogFile, gLogFile + '.1');
end;

procedure WriteLine(const Line: string);
var
  S: UTF8String;
begin
  if not gEnabled then
    Exit;

  // Lazy initialization before first write
  EnsureInitialized;

  EnterCriticalSection(gCS);
  try
    try
      if not Assigned(gLogStream) then
      begin
        ForceDirectories(ExtractFilePath(gLogFile));
        if FileExists(gLogFile) then
        begin
          gLogStream := TFileStream.Create(gLogFile, fmOpenWrite or fmShareDenyWrite);
          gLogStream.Seek(0, soEnd);
        end
        else
          gLogStream := TFileStream.Create(gLogFile, fmCreate or fmShareDenyWrite);
      end;

      if gLogStream.Size > MAX_LOG_SIZE then
      begin
        RotateLogs;
        gLogStream := TFileStream.Create(gLogFile, fmCreate or fmShareDenyWrite);
      end;

      S := UTF8String(Line + sLineBreak);
      gLogStream.WriteBuffer(Pointer(S)^, Length(S));
    except
      // Keep logger failure nonfatal
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
  EnterCriticalSection(gCS);
  try
    if Assigned(gLogStream) then
    begin
      gLogStream.Free;
      gLogStream := nil;
    end;
    gLogFile := ALogFile;
    gInitialized := True;
  finally
    LeaveCriticalSection(gCS);
  end;
end;

procedure CloseLogger;
begin
  EnterCriticalSection(gCS);
  try
    if Assigned(gLogStream) then
    begin
      gLogStream.Free;
      gLogStream := nil;
    end;
  finally
    LeaveCriticalSection(gCS);
  end;
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
  CloseLogger;
  DeleteCriticalSection(gCS);

end.