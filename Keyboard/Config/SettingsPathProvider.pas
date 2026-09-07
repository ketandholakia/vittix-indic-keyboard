unit SettingsPathProvider;

interface

type
  // M2.3: narrow settings-location seam. When installed, it supplies the INI
  // path for every TAppSettings constructed without an explicit path -
  // including the process-global instance created at unit initialization - so
  // a test host can redirect all settings I/O away from the real user profile.
  // A plain function type + setter matches the project's existing seam style
  // (TSendInputProc, TEngineOutputHandler); no DI framework, no interfaces.
  TSettingsPathProvider = function(out ALegacyPath: string): string;

procedure SetSettingsPathProvider(AProvider: TSettingsPathProvider);
function GetSettingsPathProvider: TSettingsPathProvider;

implementation

var
  GProvider: TSettingsPathProvider = nil;

procedure SetSettingsPathProvider(AProvider: TSettingsPathProvider);
begin
  // nil restores the production per-user profile location.
  GProvider := AProvider;
end;

function GetSettingsPathProvider: TSettingsPathProvider;
begin
  Result := GProvider;
end;

end.
