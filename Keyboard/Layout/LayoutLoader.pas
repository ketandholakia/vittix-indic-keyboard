unit LayoutLoader;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  LayoutModel,
  LayoutJson;

function LoadLayoutFromFile(const FileName: string): TKeyboardLayout;

implementation

function LoadLayoutFromFile(const FileName: string): TKeyboardLayout;
begin
  Result := LayoutJson.LoadLayoutFromFile(FileName);
  
  // Runtime-specific enrichment
  Result.SourceFileName := FileName;
  // Get group from parent folder name.
  Result.Group := ExtractFileName(ExtractFileDir(FileName));
  if Result.Group = '' then
    Result.Group := 'Other';
end;

end.