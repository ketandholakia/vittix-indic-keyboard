unit LayoutLoader;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  LayoutModel,
  LayoutJson,
  LayoutValidation;

function LoadLayoutFromFile(const FileName: string): TKeyboardLayout;

implementation

function LoadLayoutFromFile(const FileName: string): TKeyboardLayout;
var
  ResultObj: TLayoutValidationResult;
begin
  Result := LayoutJson.LoadLayoutFromFile(FileName);
  try
    // Runtime-specific enrichment
    Result.SourceFileName := FileName;
    // Get group from parent folder name.
    Result.Group := ExtractFileName(ExtractFileDir(FileName));
    if Result.Group = '' then
      Result.Group := 'Other';

    // Validate layout — reject if errors found
    ResultObj := TLayoutValidation.ValidateAndReport(Result);
    try
      if not ResultObj.IsValid then
        raise Exception.Create('Layout validation failed for ' + FileName + sLineBreak +
          ResultObj.ToString);
    finally
      ResultObj.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.