program HookOrderTest;

{ Manual hooks integration test (item: housekeeping). See README.md next to
  this file for how to run it. This app installs the REAL low-level keyboard
  hook, wires the REAL engine behind it, and scripts REAL input events
  (SendInput, untagged) so the whole production pipeline - hook callback ->
  HandleKeyEvent -> engine -> SendInput output - runs end to end with no
  test seams. It is interactive by design: not part of verify.bat, never run
  by the automated suite. }

{$APPTYPE GUI}

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.Dialogs,
  Logger in '..\..\..\Keyboard\Utils\Logger.pas',
  LayoutModel in '..\..\..\Shared\LayoutModel.pas',
  SendInputHelper in '..\..\..\Keyboard\Utils\SendInputHelper.pas',
  EngineState in '..\..\..\Keyboard\Core\EngineState.pas',
  ShreeLipi.Engine in '..\..\..\Keyboard\Core\ShreeLipi.Engine.pas',
  KeyboardHook in '..\..\..\Keyboard\Core\KeyboardHook.pas';

type
  TFormOrderTest = class(TForm)
  private
    Memo: TMemo;
    Status: TLabel;
    btnPrebaseEnter: TButton;
    btnPrebaseShiftTab: TButton;
    btnPlainEnter: TButton;
    btnClear: TButton;
    // TOnKeyChar is a method pointer: the engine path handler lives here.
    function EngineKey(const AChar: string): TInjectionOutcome;
    procedure BuildLayoutAndWire;
    procedure SendVK(VK, Scan: Word; ADown: Boolean);
    procedure FocusMemo;
    procedure DoPrebaseEnter(Sender: TObject);
    procedure DoPrebaseShiftTab(Sender: TObject);
    procedure DoPlainEnter(Sender: TObject);
    procedure DoClear(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

const
  // Winapi.Windows does not declare letter VKs; the US-layout values are
  // fixed ($41..$5A).
  VK_K = $4B;
  VK_I = $49;
  US_SCAN_K = $25;   // physical K
  US_SCAN_I = $17;   // physical I
  US_SCAN_ENTER = $1C;
  US_SCAN_TAB = $0F;

var
  FormOrderTest: TFormOrderTest;

constructor TFormOrderTest.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'Vittix hook order test (manual)';
  Position := poScreenCenter;
  ClientWidth := 560;
  ClientHeight := 380;

  Status := TLabel.Create(Self);
  Status.Parent := Self;
  Status.SetBounds(12, 8, 536, 60);
  Status.WordWrap := True;
  Status.Caption := 'Real LL hook + real engine. Each button focuses the memo, '
    + 'sends scripted real key events, and reports the produced order below. '
    + 'Expected output is shown on each button''s hint. Do NOT type into other '
    + 'apps while the sequence runs.';

  btnPrebaseEnter := TButton.Create(Self);
  btnPrebaseEnter.Parent := Self;
  btnPrebaseEnter.SetBounds(12, 72, 260, 28);
  btnPrebaseEnter.Caption := 'k + i (prebase) + Enter';
  btnPrebaseEnter.Hint := 'Expected: "KI" then a new line - the matra BEFORE the Enter';
  btnPrebaseEnter.ShowHint := True;
  btnPrebaseEnter.OnClick := DoPrebaseEnter;

  btnPrebaseShiftTab := TButton.Create(Self);
  btnPrebaseShiftTab.Parent := Self;
  btnPrebaseShiftTab.SetBounds(288, 72, 260, 28);
  btnPrebaseShiftTab.Caption := 'k + i (prebase) + Shift+Tab';
  btnPrebaseShiftTab.Hint := 'Expected: "KI" in the memo, focus moves BACKWARDS';
  btnPrebaseShiftTab.ShowHint := True;
  btnPrebaseShiftTab.OnClick := DoPrebaseShiftTab;

  btnPlainEnter := TButton.Create(Self);
  btnPlainEnter.Parent := Self;
  btnPlainEnter.SetBounds(12, 108, 260, 28);
  btnPlainEnter.Caption := 'plain Enter (nothing pending)';
  btnPlainEnter.Hint := 'Expected: a new line only - native pass-through, no duplicates';
  btnPlainEnter.ShowHint := True;
  btnPlainEnter.OnClick := DoPlainEnter;

  btnClear := TButton.Create(Self);
  btnClear.Parent := Self;
  btnClear.SetBounds(288, 108, 260, 28);
  btnClear.Caption := 'Clear output';
  btnClear.OnClick := DoClear;

  Memo := TMemo.Create(Self);
  Memo.Parent := Self;
  Memo.SetBounds(12, 144, 536, 224);
  Memo.ScrollBars := ssVertical;
  Memo.Font.Name := 'Consolas';
end;

destructor TFormOrderTest.Destroy;
begin
  RemoveKeyboardHook;
  SetKeyHandler(nil);
  SetActiveLayout(nil);
  inherited Destroy;
end;

function TFormOrderTest.EngineKey(const AChar: string): TInjectionOutcome;
begin
  Result := ProcessKeyChar(AChar);
end;

procedure TFormOrderTest.BuildLayoutAndWire;
var
  Layout: TKeyboardLayout;
  Prebase: TKeyMapping;
begin
  InitEngineState;
  SetEngineEnabled(True);

  // Minimal exercise layout: k -> K (consonant), i -> I (prebase matra).
  Layout := TKeyboardLayout.Create;
  Layout.LayoutID := 'hook_order_test';
  Layout.Name := 'Hook Order Test';
  Layout.Script := 'Devanagari';
  Layout.Encoding := 'unicode';
  Layout.LayoutType := 'typewriter';
  Layout.DirectMap.Add('k', 'K');
  Prebase := Default(TKeyMapping);
  Prebase.Key := 'i';
  Prebase.Glyph := 'I';
  Layout.PrebaseMap.Add('i', Prebase);

  SetActiveLayout(Layout);
  SetKeyHandler(EngineKey);

  // The scripted events are injected WITHOUT our tag: they are "foreign"
  // injected input, and the hook must translate them for this test to work.
  SetIgnoreInjectedInput(False);

  InstallKeyboardHook;
end;

procedure TFormOrderTest.SendVK(VK, Scan: Word; ADown: Boolean);
var
  Inp: TInput;
begin
  ZeroMemory(@Inp, SizeOf(Inp));
  Inp.Itype := INPUT_KEYBOARD;
  Inp.ki.wVk := VK;
  Inp.ki.wScan := Scan;
  if not ADown then
    Inp.ki.dwFlags := KEYEVENTF_KEYUP;
  // dwExtraInfo stays 0: NOT our tagged output, so the hook processes it.
  SendInput(1, Inp, SizeOf(Inp));
end;

procedure TFormOrderTest.FocusMemo;
begin
  Application.ProcessMessages;
  Memo.SetFocus;
  Application.ProcessMessages;
  Sleep(200);
end;

procedure TFormOrderTest.DoPrebaseEnter(Sender: TObject);
begin
  FocusMemo;
  SendVK(VK_K, US_SCAN_K, True);  SendVK(VK_K, US_SCAN_K, False);  Sleep(80);
  SendVK(VK_I, US_SCAN_I, True);  SendVK(VK_I, US_SCAN_I, False);  Sleep(80);
  SendVK(VK_RETURN, US_SCAN_ENTER, True); SendVK(VK_RETURN, US_SCAN_ENTER, False);
  Sleep(150);
  Status.Caption := 'Memo now: "' + Memo.Lines.Text + '"  - "I" must appear '
    + 'BEFORE the line break (re-injected Enter follows the flushed matra).';
end;

procedure TFormOrderTest.DoPrebaseShiftTab(Sender: TObject);
begin
  FocusMemo;
  SendVK(VK_K, US_SCAN_K, True);  SendVK(VK_K, US_SCAN_K, False);  Sleep(80);
  SendVK(VK_I, US_SCAN_I, True);  SendVK(VK_I, US_SCAN_I, False);  Sleep(80);
  SendVK(VK_SHIFT, 0, True);
  SendVK(VK_TAB, US_SCAN_TAB, True);  SendVK(VK_TAB, US_SCAN_TAB, False);
  SendVK(VK_SHIFT, 0, False);
  Sleep(150);
  Status.Caption := 'Expected: "KI" stayed in the memo AND focus moved '
    + 'backwards (to the first button) - the re-injected Tab kept Shift.';
end;

procedure TFormOrderTest.DoPlainEnter(Sender: TObject);
begin
  FocusMemo;
  SendVK(VK_RETURN, US_SCAN_ENTER, True); SendVK(VK_RETURN, US_SCAN_ENTER, False);
  Sleep(150);
  Status.Caption := 'Expected: exactly one new line, no duplicated Enter.';
end;

procedure TFormOrderTest.DoClear(Sender: TObject);
begin
  Memo.Clear;
  FocusMemo;
end;

begin
  try
    InitLogger(TPath.Combine(TPath.GetTempPath, 'vittix-hook-order-test.log'));
    EnableLogger(True);

    Application.Initialize;
    Application.MainFormOnTaskbar := True;
    Application.CreateForm(TFormOrderTest, FormOrderTest);
    FormOrderTest.BuildLayoutAndWire;
    Application.Run;
  except
    on E: Exception do
      MessageBox(0, PChar(E.ClassName + ': ' + E.Message),
        'HookOrderTest', MB_ICONERROR or MB_OK);
  end;
end.
