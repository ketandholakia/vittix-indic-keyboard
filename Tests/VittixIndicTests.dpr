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
  Tests.Shared.LayoutValidation in 'Tests.Shared.LayoutValidation.pas',
  Tests.Shared.LayoutJson in 'Tests.Shared.LayoutJson.pas',
  Tests.Shared.LayoutModel in 'Tests.Shared.LayoutModel.pas',
  Tests.Layouts.RealLayouts in 'Tests.Layouts.RealLayouts.pas',
  Tests.Utils.Logger in 'Tests.Utils.Logger.pas';

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