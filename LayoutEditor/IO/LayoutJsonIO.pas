unit LayoutJsonIO;

interface

uses
  LayoutModel,
  LayoutJson;

procedure SaveLayoutToFile(ALayout: TKeyboardLayout; const FileName: string);

implementation

procedure SaveLayoutToFile(ALayout: TKeyboardLayout; const FileName: string);
begin
  LayoutJson.SaveLayoutToFile(ALayout, FileName);
end;

end.
