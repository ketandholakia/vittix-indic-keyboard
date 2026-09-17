unit VittixKeyboardViewReg;

{-------------------------------------------------------------------------
  IDE registration only. The actual TVittixKeyboardView source lives in
  VittixKeyboardViewR.dpk (see Shared\VittixKeyboardView.pas) so it isn't
  compiled into two packages that could both be loaded in the IDE at once.
-------------------------------------------------------------------------}

interface

procedure Register;

implementation

uses
  DesignIntf,
  VittixKeyboardView;

procedure Register;
begin
  RegisterComponents('Vittix', [TVittixKeyboardView]);
end;

end.
