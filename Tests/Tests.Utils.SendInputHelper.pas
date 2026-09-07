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
  end;

implementation

var
  GLastRequested: Integer;
  GReturn: UINT;

function FakeSendInput(
  cInputs: UINT;
  pInputs: PInput;
  cbSize: Integer
): UINT; stdcall;
begin
  GLastRequested := Integer(cInputs);
  Result := GReturn;
end;

procedure TSendInputHelperTests.Setup;
begin
  GLastRequested := -1;
  GReturn := 0;
  ResetInjectionStatus;
  SetSendInputHook(FakeSendInput);
end;

procedure TSendInputHelperTests.TearDown;
begin
  SetSendInputHook(nil);
  ResetInjectionStatus;
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

initialization
  TDUnitX.RegisterTestFixture(TSendInputHelperTests);

end.