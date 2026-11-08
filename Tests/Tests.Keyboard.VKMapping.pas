unit Tests.Keyboard.VKMapping;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Winapi.Windows,
  KeyboardHook;

type
  // Item 5 regression coverage: the production VK-to-character conversion must
  // map through a FIXED US keyboard layout, so results do not change when the
  // user's default input language is Gujarati, Hindi, German, etc. This runs
  // the real Win32 conversion (ToUnicodeEx with a cached US HKL) — it never
  // injects input; it only reads layout tables (working rule #4).
  [TestFixture]
  TVKMappingTests = class
  public
    [Test]
    procedure Letters_MapThroughUSLayout;
    [Test]
    procedure ShiftAndDigits_MapThroughUSLayout;
    [Test]
    procedure Mapping_IndependentOfThreadInputLocale;
  end;

implementation

function NoShift: TKeyModifierState;
begin
  Result := Default(TKeyModifierState);
end;

function ShiftOnly: TKeyModifierState;
begin
  Result := Default(TKeyModifierState);
  Result.ShiftDown := True;
end;

procedure TVKMappingTests.Letters_MapThroughUSLayout;
var
  Scan: DWORD;
begin
  Scan := MapVirtualKey($41, MAPVK_VK_TO_VSC);
  Assert.AreEqual('a', ProductionVKToUnicode($41, Scan, NoShift),
    'the A key must map to the US-layout lowercase letter');
  Assert.AreEqual('A', ProductionVKToUnicode($41, Scan, ShiftOnly),
    'Shift + A must map to the US-layout uppercase letter');
end;

procedure TVKMappingTests.ShiftAndDigits_MapThroughUSLayout;
var
  Scan: DWORD;
begin
  Scan := MapVirtualKey($31, MAPVK_VK_TO_VSC);
  Assert.AreEqual('1', ProductionVKToUnicode($31, Scan, NoShift));
  Assert.AreEqual('!', ProductionVKToUnicode($31, Scan, ShiftOnly));
end;

// The actual bug: with a non-US input locale ACTIVE on the thread, the old
// implementation mapped through that locale (German QWERTZ swaps Y/Z). The
// fixed implementation always maps through the cached US layout.
procedure TVKMappingTests.Mapping_IndependentOfThreadInputLocale;
var
  Saved: HKL;
  German: HKL;
  ScanY, ScanZ: DWORD;
begin
  Saved := GetKeyboardLayout(0);
  // German ships as a base layout on every Windows installation.
  German := LoadKeyboardLayout('00000407', KLF_ACTIVATE);
  try
    if German = 0 then
    begin
      Assert.Pass('German layout is not available on this machine');
      Exit;
    end;

    ScanY := MapVirtualKey($59, MAPVK_VK_TO_VSC);
    ScanZ := MapVirtualKey($5A, MAPVK_VK_TO_VSC);
    Assert.AreEqual('y', ProductionVKToUnicode($59, ScanY, NoShift),
      'the Y key must map through the US layout even with a QWERTZ locale active');
    Assert.AreEqual('z', ProductionVKToUnicode($5A, ScanZ, NoShift),
      'the Z key must map through the US layout even with a QWERTZ locale active');
  finally
    ActivateKeyboardLayout(Saved, 0);
    if German <> 0 then
      UnloadKeyboardLayout(German);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TVKMappingTests);

end.
