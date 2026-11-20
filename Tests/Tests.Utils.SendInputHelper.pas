unit Tests.Utils.SendInputHelper;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Winapi.Windows,
  SendInputHelper;

type
  // M1.2 regression coverage for the SendInput boundary. A fake hook simulates
  // the Win32 SendInput return count so tests can verify exact-count success and
  // that zero/partial acceptance is treated as failure — without ever sending
  // real keystrokes (working rule #4).
  [TestFixture]
  TSendInputHelperTests = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure SendUnicodeText_FullSuccess_KeepsOk;
    [Test]
    procedure SendUnicodeText_ZeroResult_Fails;
    [Test]
    procedure SendUnicodeText_PartialResult_Fails;
    [Test]
    procedure SendUnicodeChar_SubmitsDownUpPair_ExactCountRequired;
    [Test]
    procedure SendUnicodeChar_LoneKeyDown_IsFailure;
    [Test]
    procedure SendVirtualKey_SubmitsDownUpPair_ExactCountRequired;
    [Test]
    procedure SendBackspace_CountTwo_RequiresExactCount;
    [Test]
    procedure SendBackspace_CountTwo_Partial_Fails;
    [Test]
    procedure LaterSuccess_DoesNotReArmAfterFailure;
    [Test]
    procedure ExplicitReset_RestoresInjection;
    [Test]
    procedure AllEvents_CarryTheOwnInjectionTag;
    [Test]
    procedure StatusCallback_FiresOncePerLatchTrip;
    [Test]
    procedure StatusCallback_ResetFromTrippedFiresHealthy_ResetWhileHealthyIsSilent;
    [Test]
    procedure SendVirtualKeyWithShift_BatchShape;
  end;

implementation

uses
  System.Classes;

type
  TInputArray = array[0..1023] of TInput;
  PInputArray = ^TInputArray;

var
  GLastRequested: Integer;
  GReturn: UINT;
  GAllTagged: Boolean;
  // Item (injection latch): the recorded status transitions, '0'/'1' in order.
  GStatusEvents: TStringList = nil;

function FakeSendInput(
  cInputs: UINT;
  pInputs: PInput;
  cbSize: Integer
): UINT; stdcall;
var
  I: Integer;
begin
  GLastRequested := Integer(cInputs);
  for I := 0 to Integer(cInputs) - 1 do
    if PInputArray(pInputs)^[I].ki.dwExtraInfo <> VITTIX_SENDINPUT_TAG then
      GAllTagged := False;
  Result := GReturn;
end;

// Item (injection latch): records every status transition so tests can assert
// the exact rate limiting (one trip notify per latch episode, one re-arm
// notify per explicit reset from a tripped state).
procedure FakeStatusCallback(AHealthy: Boolean);
begin
  if AHealthy then
    GStatusEvents.Add('1')
  else
    GStatusEvents.Add('0');
end;

procedure TSendInputHelperTests.Setup;
begin
  GLastRequested := -1;
  GReturn := 0;
  GAllTagged := True;
  GStatusEvents := TStringList.Create;
  ResetInjectionStatus;
  SetSendInputHook(FakeSendInput);
  SetInjectionStatusCallback(FakeStatusCallback);
end;

procedure TSendInputHelperTests.TearDown;
begin
  SetInjectionStatusCallback(nil);
  SetSendInputHook(nil);
  ResetInjectionStatus;
  FreeAndNil(GStatusEvents);
end;

procedure TSendInputHelperTests.SendUnicodeText_FullSuccess_KeepsOk;
begin
  GReturn := 4;
  SendUnicodeText('AB');          // 2 code units → 4 INPUT records
  Assert.IsTrue(InjectionOK);
  Assert.AreEqual(4, GLastRequested, 'requested count must be 4 records');
end;

procedure TSendInputHelperTests.SendUnicodeText_ZeroResult_Fails;
begin
  GReturn := 0;
  SendUnicodeText('A');           // 2 records
  Assert.IsFalse(InjectionOK, 'zero accepted records must be a failure');
  Assert.AreEqual(2, GLastRequested);
end;

procedure TSendInputHelperTests.SendUnicodeText_PartialResult_Fails;
begin
  GReturn := 3;                    // requested 4, returned 3
  SendUnicodeText('AB');
  Assert.IsFalse(InjectionOK, 'partial count (3 of 4) must be a failure');
  Assert.AreEqual(4, GLastRequested);
end;

procedure TSendInputHelperTests.SendUnicodeChar_SubmitsDownUpPair_ExactCountRequired;
begin
  GReturn := 2;                    // down + up both accepted
  SendUnicodeChar('A');
  Assert.IsTrue(InjectionOK);
  Assert.AreEqual(2, GLastRequested, 'a single character must submit 2 records');
end;

procedure TSendInputHelperTests.SendUnicodeChar_LoneKeyDown_IsFailure;
begin
  GReturn := 1;                    // only the key-down accepted, key-up dropped
  SendUnicodeChar('A');
  Assert.IsFalse(InjectionOK, 'a lone key-down (1 of 2) must be a failure');
  Assert.AreEqual(2, GLastRequested);
end;

procedure TSendInputHelperTests.SendVirtualKey_SubmitsDownUpPair_ExactCountRequired;
begin
  GReturn := 2;
  SendVirtualKey(VK_TAB);
  Assert.IsTrue(InjectionOK);
  Assert.AreEqual(2, GLastRequested);
end;

procedure TSendInputHelperTests.SendBackspace_CountTwo_RequiresExactCount;
begin
  GReturn := 4;                    // 2 backspaces → 4 records
  SendBackspace(2);
  Assert.IsTrue(InjectionOK);
  Assert.AreEqual(4, GLastRequested);
end;

procedure TSendInputHelperTests.SendBackspace_CountTwo_Partial_Fails;
begin
  GReturn := 3;                    // requested 4, returned 3
  SendBackspace(2);
  Assert.IsFalse(InjectionOK, 'partial backspace count (3 of 4) must be a failure');
  Assert.AreEqual(4, GLastRequested);
end;

procedure TSendInputHelperTests.LaterSuccess_DoesNotReArmAfterFailure;
begin
  GReturn := 0;
  SendUnicodeText('A');            // fails
  Assert.IsFalse(InjectionOK);

  GReturn := 2;
  SendUnicodeText('A');            // succeeds, but must NOT re-arm injection
  Assert.IsFalse(InjectionOK,
    'a later successful call must not conceal an earlier failed injection');
end;

procedure TSendInputHelperTests.ExplicitReset_RestoresInjection;
begin
  GReturn := 0;
  SendUnicodeText('A');            // fails
  Assert.IsFalse(InjectionOK);

  ResetInjectionStatus;
  Assert.IsTrue(InjectionOK, 'only an explicit reset re-arms injection');
end;

// Item 7: every INPUT record this helper submits must carry the magic
// dwExtraInfo tag so the keyboard hook can tell our own injections apart from
// foreign injected input and never reprocess them.
procedure TSendInputHelperTests.AllEvents_CarryTheOwnInjectionTag;
begin
  GReturn := 6;
  SendUnicodeText('ABC');   // 6 records
  SendVirtualKey(VK_TAB);   // 2 records
  SendBackspace(2);         // 4 records
  Assert.IsTrue(GAllTagged, 'every submitted INPUT record must carry the tag');
end;

// Item (injection latch): the trip notification is rate-limited to ONCE per
// latch episode. Repeated failing SendInput calls must not repeat it.
procedure TSendInputHelperTests.StatusCallback_FiresOncePerLatchTrip;
begin
  GReturn := 0;
  SendUnicodeText('A');            // trips the latch
  SendUnicodeText('A');            // still failing
  SendBackspace(2);                // still failing
  Assert.AreEqual(1, GStatusEvents.Count,
    'one latch trip must notify exactly once, whatever keeps failing');
  Assert.AreEqual('0', GStatusEvents[0], 'the trip notify reports unhealthy');
end;

procedure TSendInputHelperTests.StatusCallback_ResetFromTrippedFiresHealthy_ResetWhileHealthyIsSilent;
begin
  // Resetting while healthy: no notification at all.
  ResetInjectionStatus;
  Assert.AreEqual(0, GStatusEvents.Count,
    'a reset while healthy must not notify');

  // Trip, then explicit re-arm: the listener learns the latch cleared.
  GReturn := 0;
  SendUnicodeText('A');
  ResetInjectionStatus;
  Assert.AreEqual(2, GStatusEvents.Count);
  Assert.AreEqual('0', GStatusEvents[0], 'trip notify');
  Assert.AreEqual('1', GStatusEvents[1], 're-arm notify');

  // Resetting again while healthy: silent.
  ResetInjectionStatus;
  Assert.AreEqual(2, GStatusEvents.Count,
    'a re-arm notify must fire only when the latch was actually tripped');
end;

// Item (Tab/Enter ordering): the Shift-preserving variant submits the whole
// [Shift down][VK down][VK up][Shift up] sequence as ONE batch; without Shift
// it degenerates to the plain down/up pair. Full record-order coverage lives
// in Tests.Keyboard.ControlKeyOrdering.
procedure TSendInputHelperTests.SendVirtualKeyWithShift_BatchShape;
begin
  GReturn := 4;
  SendVirtualKeyWithShift(VK_TAB, True);
  Assert.IsTrue(InjectionOK);
  Assert.AreEqual(4, GLastRequested,
    'with Shift: Shift down + Tab down/up + Shift up = 4 records');

  SendVirtualKeyWithShift(VK_RETURN, False);
  Assert.AreEqual(2, GLastRequested,
    'without Shift: a plain down/up pair = 2 records');
end;

initialization
  TDUnitX.RegisterTestFixture(TSendInputHelperTests);

end.