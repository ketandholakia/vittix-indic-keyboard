unit Validation;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  LayoutModel;

type
  TValidationError = record
    Section: string;
    Message: string;
  end;

  TValidationErrors = TList<TValidationError>;

procedure ValidateLayout(
  ALayout: TKeyboardLayout;
  Errors: TValidationErrors
);

implementation

procedure AddError(
  Errors: TValidationErrors;
  const Section, Msg: string
);
var
  E: TValidationError;
begin
  E.Section := Section;
  E.Message := Msg;
  Errors.Add(E);
end;

procedure ValidateLayout(
  ALayout: TKeyboardLayout;
  Errors: TValidationErrors
);
var
  SeenKeys: TDictionary<string, string>;
  PairStr: TPair<string, string>;
  PairMatra: TPair<string, TKeyMapping>;
  PairMod: TPair<string, TKeyMapping>;
begin
  Errors.Clear;

  if ALayout = nil then
  begin
    AddError(Errors, 'General', 'Layout is not assigned');
    Exit;
  end;

  SeenKeys := TDictionary<string, string>.Create;
  try
    { ---------------- DIRECT MAP ---------------- }
    for PairStr in ALayout.DirectMap do
    begin
      if PairStr.Key = '' then
        AddError(Errors, 'Direct', 'Empty key detected');

      if PairStr.Value = '' then
        AddError(Errors, 'Direct', 'Empty glyph for key "' + PairStr.Key + '"');

      if SeenKeys.ContainsKey(PairStr.Key) then
        AddError(
          Errors,
          'Direct',
          'Duplicate key "' + PairStr.Key + '" also used in ' +
          SeenKeys[PairStr.Key]
        )
      else
        SeenKeys.Add(PairStr.Key, 'Direct');
    end;

    { ---------------- PREBASE ---------------- }
    for PairMatra in ALayout.PrebaseMap do
    begin
      if PairMatra.Value.Glyph = '' then
        AddError(
          Errors,
          'Prebase',
          'Empty glyph for key "' + PairMatra.Key + '"'
        );

      if SeenKeys.ContainsKey(PairMatra.Key) then
        AddError(
          Errors,
          'Prebase',
          'Key "' + PairMatra.Key + '" conflicts with ' +
          SeenKeys[PairMatra.Key]
        )
      else
        SeenKeys.Add(PairMatra.Key, 'Prebase');
    end;

    { ---------------- POSTBASE ---------------- }
    for PairStr in ALayout.PostbaseMap do
    begin
      if PairStr.Value = '' then
        AddError(
          Errors,
          'Postbase',
          'Empty glyph for key "' + PairStr.Key + '"'
        );

      if SeenKeys.ContainsKey(PairStr.Key) then
        AddError(
          Errors,
          'Postbase',
          'Key "' + PairStr.Key + '" conflicts with ' +
          SeenKeys[PairStr.Key]
        )
      else
        SeenKeys.Add(PairStr.Key, 'Postbase');
    end;

    { ---------------- MODIFIERS ---------------- }
    for PairMod in ALayout.Modifiers do
    begin
      if PairMod.Value.Key = '' then
        AddError(
          Errors,
          'Modifiers',
          'Modifier "' + PairMod.Key + '" has empty key'
        );

      if PairMod.Value.Glyph = '' then
        AddError(
          Errors,
          'Modifiers',
          'Modifier "' + PairMod.Key + '" has empty glyph'
        );
    end;

    { ---------------- SEQUENCES ---------------- }
    for PairStr in ALayout.Sequences do
    begin
      if PairStr.Key.Length < 2 then
        AddError(
          Errors,
          'Sequences',
          'Sequence "' + PairStr.Key + '" is too short'
        );
      if PairStr.Key.Length > MAX_SEQUENCE_KEY_LEN then
        AddError(
          Errors,
          'Sequences',
          'Sequence "' + PairStr.Key + '" is longer than the maximum supported length (' +
          IntToStr(MAX_SEQUENCE_KEY_LEN) + ')'
        );

      if PairStr.Value = '' then
        AddError(
          Errors,
          'Sequences',
          'Sequence "' + PairStr.Key + '" has empty output'
        );
    end;

  finally
    SeenKeys.Free;
  end;
end;

end.
