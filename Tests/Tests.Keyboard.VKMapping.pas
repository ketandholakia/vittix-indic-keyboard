unit Tests.Keyboard.VKMapping;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Winapi.Windows,
  KeyboardHook,
  SendInputHelper;

type
  // Item 5 regression coverage: the production VK-to-character conversion must
  // map through a FIXED US keyboard layout, so results do not change when the
  // user's default input language is Gujarati, Hindi, German, etc. This runs
  // the real Win32 conversion (ToUnicodeEx with a cached US HKL) — it never
  // injects input; it only reads layout tables (working rule #4).
  //
  // Item 9.2 adds the positional scan-code seam: the production path must
  // re-derive the VK from the scan code through the US layout (and fall back
  // to the incoming VK when that fails), which the injected-scan tests pin.
  [TestFixture]
  TVKMappingTests = class
  public
    [Test]
    procedure Letters_MapThroughUSLayout;
    [Test]
    procedure ShiftAndDigits_MapThroughUSLayout;
    [Test]
    procedure Mapping_IndependentOfThreadInputLocale;
    [Test]
    procedure ScanToVK_Production_MapsThroughUSLayout;
    [Test]
    procedure ScanToVK_FallbackToIncomingVK_WhenMappingFails;
    [Test]
    procedure ProductionVKToUnicode_UsesScanCodeNotIncomingVK;
  end;

implementation

var
  // Test-only fake for the 9.2 seam: maps scan $15 (the Y/Z positional key)
  // to the US-layout VK $59, proving the production path drives the
  // conversion from the scan code instead of the layout-dependent VK.
  GFakeScanToVKScan: DWORD = 0;
  GFakeScanToVKVK: DWORD = 0;

function FakeScanToVK(ScanCode: DWORD; FallbackVK: DWORD): DWORD;
begin
  if ScanCode = GFakeScanToVKScan then
    Result := GFakeScanToVKVK
  else
    Result := FallbackVK;
end;

function FakeScanToVKAlwaysZero(ScanCode: DWORD; FallbackVK: DWORD): DWORD;
begin
  Result := 0;   // forces the fallback path in ProductionVKToUnicode
end;

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
//
// The scan codes are FIXED hardware positions, not derived via MapVirtualKey:
// under an active German layout MapVirtualKey(VK $59) returns $2C, which
// would feed the very mapping this test is trying to expose. Hardware truth:
// scan $15 is the physical Y position (QWERTZ labels it Z and reports
// VK $5A for it), scan $2C is the physical Z position (QWERTZ labels it Y
// and reports VK $59).
procedure TVKMappingTests.Mapping_IndependentOfThreadInputLocale;
var
  Saved: HKL;
  German: HKL;
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

    Assert.AreEqual('y', ProductionVKToUnicode($5A, $15, NoShift),
      'scan $15 (Y position, German VK_Z) must map to ''y'' through the US layout');
    Assert.AreEqual('z', ProductionVKToUnicode($59, $2C, NoShift),
      'scan $2C (Z position, German VK_Y) must map to ''z'' through the US layout');
  finally
    ActivateKeyboardLayout(Saved, 0);
    if German <> 0 then
      UnloadKeyboardLayout(German);
  end;
end;

// Item 9.2, real Win32: MapVirtualKeyEx with MAPVK_VSC_TO_VK_EX through the
// US layout maps scan codes to the POSITIONAL key, independent of the VK the
// focused application computed with its own layout. Extended scans carry the
// $E0 prefix (as HandleKeyEvent embeds it).
procedure TVKMappingTests.ScanToVK_Production_MapsThroughUSLayout;
begin
  Assert.AreEqual(DWORD($41), ProductionScanToVK($1E, 0),
    'scan $1E (Y/Z positional key on QWERTZ) must map to VK_A through the US layout');
  Assert.AreEqual(DWORD($5A), ProductionScanToVK($2C, 0),
    'scan $2C must map to VK_Z through the US layout');
  Assert.AreEqual(DWORD(VK_UP), ProductionScanToVK($E048, 0),
    'an extended scan with the $E0 prefix must map to its extended VK');
  // Zero mapping falls back to the incoming VK (fail-open).
  Assert.AreEqual(DWORD($3C), ProductionScanToVK($FFFF, $3C),
    'an unmappable scan must fall back to the incoming VK');
end;

procedure TVKMappingTests.ScanToVK_FallbackToIncomingVK_WhenMappingFails;
var
  Deps: THookPolicyDependencies;
begin
  // A seam that always fails forces the fallback path in ProductionVKToUnicode.
  Deps := Default(THookPolicyDependencies);
  Deps.ScanToVK := FakeScanToVKAlwaysZero;
  SetHookPolicyDependencies(Deps);
  try
    Assert.AreEqual('a', ProductionVKToUnicode($41, $1E, NoShift),
      'when scan-to-VK fails the incoming VK must be used');
  finally
    SetHookPolicyDependencies(Default(THookPolicyDependencies));
  end;
end;

// Item 9.2, seam-level proof: the production path drives the conversion from
// the SCAN CODE. Scan $15 is the Y/Z positional key: a German system computes
// VK_Z ($5A) for it, but the US-layout positional reading is VK_Y ($59). With
// the injected seam providing the US mapping, the conversion must yield 'y'
// even though the incoming VK says 'z'.
procedure TVKMappingTests.ProductionVKToUnicode_UsesScanCodeNotIncomingVK;
var
  Deps: THookPolicyDependencies;
begin
  GFakeScanToVKScan := $15;
  GFakeScanToVKVK := $59;
  Deps := Default(THookPolicyDependencies);
  Deps.ScanToVK := FakeScanToVK;
  SetHookPolicyDependencies(Deps);
  try
    Assert.AreEqual('y', ProductionVKToUnicode($5A, $15, NoShift),
      'the scan code must drive the conversion (positional Y key), not the incoming VK');
    Assert.AreEqual('Y', ProductionVKToUnicode($5A, $15, ShiftOnly),
      'shift still applies on top of the scan-derived VK');
  finally
    SetHookPolicyDependencies(Default(THookPolicyDependencies));
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TVKMappingTests);

end.
