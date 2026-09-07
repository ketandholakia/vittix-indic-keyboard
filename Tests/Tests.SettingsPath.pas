unit Tests.SettingsPath;

interface

implementation

uses
  System.IOUtils,
  System.SysUtils,
  SettingsPathProvider;

var
  GTestSettingsDir: string;

function TestSettingsPath(out ALegacyPath: string): string;
begin
  // Deterministic, isolated location under TEMP. The directory is created on
  // demand by whatever actually writes there; this unit initialization
  // performs no filesystem operation at all.
  ALegacyPath := '';
  Result := TPath.Combine(GTestSettingsDir, 'settings.ini');
end;

initialization
  // M2.3: redirect every process-global TAppSettings created at unit
  // initialization (GAppSettings) away from the real user profile, so the
  // test host never creates %USERPROFILE%\Vittix nor migrates the legacy
  // exe-relative settings.ini. This unit must be listed before AppSettings in
  // the test .dpr so it initializes first; it deliberately does not use
  // AppSettings itself (a used unit always initializes first).
  GTestSettingsDir := TPath.Combine(TPath.GetTempPath, 'VittixTestSettings');
  SetSettingsPathProvider(TestSettingsPath);

finalization
  SetSettingsPathProvider(nil);
  try
    if TDirectory.Exists(GTestSettingsDir) then
      TDirectory.Delete(GTestSettingsDir, True);
  except
    // Best effort cleanup in unit finalization
  end;

end.