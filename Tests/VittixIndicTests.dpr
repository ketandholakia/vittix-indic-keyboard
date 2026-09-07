program VittixIndicTests;

{$APPTYPE CONSOLE}

{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.TestRunner,
  LayoutModel in '..\Shared\LayoutModel.pas',
  LayoutJson in '..\Shared\LayoutJson.pas',
  LayoutValidation in '..\Shared\LayoutValidation.pas',
  Logger in '..\Keyboard\Utils\Logger.pas',
  SendInputHelper in '..\Keyboard\Utils\SendInputHelper.pas',
  EngineState in '..\Keyboard\Core\EngineState.pas',
  ShreeLipi.Engine in '..\Keyboard\Core\ShreeLipi.Engine.pas',
  KeyboardHook in '..\Keyboard\Core\KeyboardHook.pas',
  SettingsPathProvider in '..\Keyboard\Config\SettingsPathProvider.pas',
  LayoutManager in '..\Keyboard\Layout\LayoutManager.pas',
  LayoutLoader in '..\Keyboard\Layout\LayoutLoader.pas',
  Tests.SettingsPath in 'Tests.SettingsPath.pas',
  AppSettings in '..\Keyboard\Config\AppSettings.pas',
  Tests.Shared.LayoutValidation in 'Tests.Shared.LayoutValidation.pas',
  Tests.Shared.LayoutJson in 'Tests.Shared.LayoutJson.pas',
  Tests.Shared.LayoutModel in 'Tests.Shared.LayoutModel.pas',
  Tests.Layouts.RealLayouts in 'Tests.Layouts.RealLayouts.pas',
  Tests.Utils.Logger in 'Tests.Utils.Logger.pas',
  Tests.Engine.PendingState in 'Tests.Engine.PendingState.pas',
  Tests.Engine.OutputBoundary in 'Tests.Engine.OutputBoundary.pas',
  Tests.Utils.SendInputHelper in 'Tests.Utils.SendInputHelper.pas',
  Tests.Keyboard.HookPolicy in 'Tests.Keyboard.HookPolicy.pas',
  Tests.Keyboard.AppSettings in 'Tests.Keyboard.AppSettings.pas',
  Tests.Engine.State in 'Tests.Engine.State.pas',
  Tests.Keyboard.Hotkeys in 'Tests.Keyboard.Hotkeys.pas',
  Tests.Keyboard.LayoutManager in 'Tests.Keyboard.LayoutManager.pas',
  Tests.Keyboard.AppSettingsMigration in 'Tests.Keyboard.AppSettingsMigration.pas',
  Tests.Keyboard.ProcessFilter in 'Tests.Keyboard.ProcessFilter.pas';

var
  runner: ITestRunner;
  results: IRunResults;
  logger: ITestLogger;

begin
  try
    // Create the runner
    runner := TDUnitX.CreateRunner;
    runner.UseRTTI := True;
    runner.FailsOnNoAsserts := True;

    // Console logger
    logger := TDUnitXConsoleLogger.Create(False);
    runner.AddLogger(logger);

    // Run tests
    results := runner.Execute;
    runner := nil;

    // Exit code for CI
    if not results.AllPassed then
      System.ExitCode := 1
    else
      System.ExitCode := 0;

    results := nil;

  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 2;
    end;
  end;
end.