unit WinStartup;

interface

uses
  System.SysUtils,
  Winapi.Windows,
  Registry;   // ✅ FIXED

{ --------------------------------------------------
  Windows Startup helper
-------------------------------------------------- }

procedure EnableStartup(const AppName, AppPath: string);
procedure DisableStartup(const AppName: string);
function IsStartupEnabled(const AppName: string): Boolean;

implementation

const
  RUN_KEY = '\Software\Microsoft\Windows\CurrentVersion\Run';

{ --------------------------------------------------
  Enable app at startup (HKCU)
-------------------------------------------------- }

procedure EnableStartup(const AppName, AppPath: string);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;

    if Reg.OpenKey(RUN_KEY, True) then
      Reg.WriteString(AppName, '"' + AppPath + '"');
  finally
    Reg.Free;
  end;
end;

{ --------------------------------------------------
  Disable app at startup
-------------------------------------------------- }

procedure DisableStartup(const AppName: string);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;

    if Reg.OpenKey(RUN_KEY, False) then
      if Reg.ValueExists(AppName) then
        Reg.DeleteValue(AppName);
  finally
    Reg.Free;
  end;
end;

{ --------------------------------------------------
  Check startup status
-------------------------------------------------- }

function IsStartupEnabled(const AppName: string): Boolean;
var
  Reg: TRegistry;
begin
  Result := False;

  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;

    if Reg.OpenKey(RUN_KEY, False) then
      Result := Reg.ValueExists(AppName);
  finally
    Reg.Free;
  end;
end;

end.

