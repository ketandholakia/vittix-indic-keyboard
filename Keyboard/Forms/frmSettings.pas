unit frmSettings;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  AppSettings;

type
  TfrmSettings = class(TForm)
    lblToggleHotkey: TLabel;
    edtToggleHotkey: TEdit;
    lblActionHotkey: TLabel;
    edtActionHotkey: TEdit;
    lblTargetProcess: TLabel;
    edtTargetProcess: TEdit;
    lblAllowedApps: TLabel;
    memAllowedApps: TMemo;
    lblHotkeyHelp: TLabel;
    btnOK: TButton;
    btnCancel: TButton;
    procedure btnOKClick(Sender: TObject);
    procedure edtActionHotkeyKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure edtToggleHotkeyKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    procedure CaptureHotkey(Edit: TEdit; var Key: Word; Shift: TShiftState;
      AllowBlank: Boolean);
    function BuildHotkeyText(Key: Word; Shift: TShiftState): string;
    function KeyToHotkeyToken(Key: Word): string;
    function NormalizeHotkeyInput(const Value: string; AllowBlank: Boolean;
      out Normalized: string): Boolean;
  public
    class function Execute(var Settings: TKeyboardAppSettingsData; LayoutNames,
      LayoutIDs: TStrings): Boolean;
  end;

implementation

{$R *.dfm}

function TfrmSettings.BuildHotkeyText(Key: Word; Shift: TShiftState): string;
var
  KeyToken: string;
begin
  KeyToken := KeyToHotkeyToken(Key);
  if KeyToken = '' then
    Exit('');

  Result := '';
  if ssCtrl in Shift then
    Result := 'Ctrl';
  if ssAlt in Shift then
  begin
    if Result <> '' then
      Result := Result + '+';
    Result := Result + 'Alt';
  end;
  if ssShift in Shift then
  begin
    if Result <> '' then
      Result := Result + '+';
    Result := Result + 'Shift';
  end;
  if Result <> '' then
    Result := Result + '+';
  Result := Result + KeyToken;
end;

procedure TfrmSettings.btnOKClick(Sender: TObject);
var
  NormalizedToggle: string;
  NormalizedAction: string;
begin
  if not NormalizeHotkeyInput(edtToggleHotkey.Text, False, NormalizedToggle) then
  begin
    MessageDlg(
      'Toggle hotkey must use keys like Ctrl+Alt+K, Ctrl+Shift+F2, or Alt+Space.',
      mtError, [mbOK], 0
    );
    edtToggleHotkey.SetFocus;
    Exit;
  end;

  if not NormalizeHotkeyInput(edtActionHotkey.Text, True, NormalizedAction) then
  begin
    MessageDlg(
      'Action hotkey must be blank or use keys like Ctrl+Alt+K, Ctrl+Shift+F2, or Alt+Space.',
      mtError, [mbOK], 0
    );
    edtActionHotkey.SetFocus;
    Exit;
  end;

  edtToggleHotkey.Text := NormalizedToggle;
  edtActionHotkey.Text := NormalizedAction;
  ModalResult := mrOk;
end;

procedure TfrmSettings.CaptureHotkey(Edit: TEdit; var Key: Word;
  Shift: TShiftState; AllowBlank: Boolean);
var
  HotkeyText: string;
begin
  if Key in [VK_TAB] then
    Exit;

  if Key in [VK_BACK, VK_DELETE] then
  begin
    if AllowBlank then
      Edit.Text := ''
    else
      MessageDlg('This hotkey is required.', mtInformation, [mbOK], 0);
    Key := 0;
    Exit;
  end;

  HotkeyText := BuildHotkeyText(Key, Shift);
  if HotkeyText <> '' then
    Edit.Text := HotkeyText;

  Key := 0;
end;

procedure TfrmSettings.edtActionHotkeyKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  CaptureHotkey(edtActionHotkey, Key, Shift, True);
end;

procedure TfrmSettings.edtToggleHotkeyKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  CaptureHotkey(edtToggleHotkey, Key, Shift, False);
end;

class function TfrmSettings.Execute(var Settings: TKeyboardAppSettingsData;
  LayoutNames, LayoutIDs: TStrings): Boolean;
var
  Form: TfrmSettings;
begin
  Form := TfrmSettings.Create(nil);
  try
    Form.edtToggleHotkey.Text := Settings.ToggleHotkeyText;
    Form.edtActionHotkey.Text := Settings.ActionHotkeyText;
    Form.edtTargetProcess.Text := Settings.TargetProcessName;
    Form.memAllowedApps.Lines.Text := Settings.AllowedProcessesText;

    Result := Form.ShowModal = mrOk;

    if Result then
    begin
      Settings.ToggleHotkeyText := Trim(Form.edtToggleHotkey.Text);
      Settings.ActionHotkeyText := Trim(Form.edtActionHotkey.Text);
      Settings.TargetProcessName := Trim(Form.edtTargetProcess.Text);
      Settings.AllowedProcessesText := Trim(Form.memAllowedApps.Lines.Text);
    end;
  finally
    Form.Free;
  end;
end;

function TfrmSettings.NormalizeHotkeyInput(const Value: string;
  AllowBlank: Boolean; out Normalized: string): Boolean;
var
  Parts: TArray<string>;
  Part: string;
  Token: string;
  KeyToken: string;
  HasCtrl: Boolean;
  HasAlt: Boolean;
  HasShift: Boolean;
  HasWin: Boolean;
  FKeyNumber: Integer;
begin
  Normalized := '';
  Token := Trim(Value);

  if Token = '' then
  begin
    Result := AllowBlank;
    Exit;
  end;

  Parts := Token.Split(['+']);
  HasCtrl := False;
  HasAlt := False;
  HasShift := False;
  HasWin := False;
  KeyToken := '';

  for Part in Parts do
  begin
    Token := UpperCase(Trim(Part));
    if Token = '' then
    begin
      Result := False;
      Exit;
    end;

    if Token = 'CTRL' then
    begin
      if HasCtrl then
      begin
        Result := False;
        Exit;
      end;
      HasCtrl := True;
    end
    else if Token = 'ALT' then
    begin
      if HasAlt then
      begin
        Result := False;
        Exit;
      end;
      HasAlt := True;
    end
    else if Token = 'SHIFT' then
    begin
      if HasShift then
      begin
        Result := False;
        Exit;
      end;
      HasShift := True;
    end
    else if (Token = 'WIN') or (Token = 'WINDOWS') then
    begin
      if HasWin then
      begin
        Result := False;
        Exit;
      end;
      HasWin := True;
    end
    else
    begin
      if KeyToken <> '' then
      begin
        Result := False;
        Exit;
      end;

      if Token = 'SPACE' then
        KeyToken := 'Space'
      else if (Length(Token) >= 2) and (Token[1] = 'F') and
        TryStrToInt(Copy(Token, 2), FKeyNumber) and (FKeyNumber >= 1) and
        (FKeyNumber <= 24) then
        KeyToken := 'F' + IntToStr(FKeyNumber)
      else if (Length(Token) = 1) and CharInSet(Token[1], ['A'..'Z', '0'..'9']) then
        KeyToken := Token
      else
      begin
        Result := False;
        Exit;
      end;
    end;
  end;

  if KeyToken = '' then
  begin
    Result := False;
    Exit;
  end;

  if HasCtrl then
    Normalized := 'Ctrl';
  if HasAlt then
  begin
    if Normalized <> '' then
      Normalized := Normalized + '+';
    Normalized := Normalized + 'Alt';
  end;
  if HasShift then
  begin
    if Normalized <> '' then
      Normalized := Normalized + '+';
    Normalized := Normalized + 'Shift';
  end;
  if HasWin then
  begin
    if Normalized <> '' then
      Normalized := Normalized + '+';
    Normalized := Normalized + 'Win';
  end;
  if Normalized <> '' then
    Normalized := Normalized + '+';
  Normalized := Normalized + KeyToken;

  Result := True;
end;

function TfrmSettings.KeyToHotkeyToken(Key: Word): string;
begin
  case Key of
    Ord('0')..Ord('9'),
    Ord('A')..Ord('Z'):
      Result := Char(Key);
    VK_SPACE:
      Result := 'Space';
    VK_F1..VK_F24:
      Result := 'F' + IntToStr(Key - VK_F1 + 1);
  else
    Result := '';
  end;
end;

end.
