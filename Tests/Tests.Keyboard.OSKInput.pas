unit Tests.Keyboard.OSKInput;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  LayoutModel,
  LayoutJson,
  OSKInput,
  Tests.Layouts.RealLayouts;

type
  [TestFixture]
  [Category('OSKInput')]
  TOSKInputTests = class
  public
    // The on-screen keyboard view always reports UPPERCASE letter names
    // (its rows are 'QWERTY...'), while the direct maps distinguish 'k'
    // from 'K'. QW2: clicking a key must type through the engine.
    [Test]
    procedure UnshiftedLetter_MapsToLowercase;
    [Test]
    procedure ShiftedLetter_KeptUppercase;
    [Test]
    procedure DigitsAndSymbols_PassThrough;
    [Test]
    procedure ShiftedSymbols_PassThrough;
    [Test]
    procedure SpecialKeyNames_AreUnhandled;
    // Engine integration through the established seams (no real keystrokes):
    // the mapped name must type the direct-map glyph.
    [Test]
    procedure MappedLetter_TypesDirectGlyph_Remington;
  end;

implementation

procedure TOSKInputTests.UnshiftedLetter_MapsToLowercase;
begin
  Assert.AreEqual('q', OSKKeyNameToEngineKey('Q', False), 'unshifted Q must type q');
  Assert.AreEqual('a', OSKKeyNameToEngineKey('A', False), 'unshifted A must type a');
  Assert.AreEqual('k', OSKKeyNameToEngineKey('K', False), 'unshifted K must type k');
end;

procedure TOSKInputTests.ShiftedLetter_KeptUppercase;
begin
  Assert.AreEqual('Q', OSKKeyNameToEngineKey('Q', True), 'shifted Q must type Q');
  Assert.AreEqual('A', OSKKeyNameToEngineKey('A', True), 'shifted A must type A');
end;

procedure TOSKInputTests.DigitsAndSymbols_PassThrough;
begin
  Assert.AreEqual('1', OSKKeyNameToEngineKey('1', False));
  Assert.AreEqual(';', OSKKeyNameToEngineKey(';', False));
  Assert.AreEqual('[', OSKKeyNameToEngineKey('[', False));
  Assert.AreEqual('/', OSKKeyNameToEngineKey('/', False));
end;

procedure TOSKInputTests.ShiftedSymbols_PassThrough;
begin
  // The view rebuilds its rows in shifted state, so the reported name is
  // already the shifted symbol.
  Assert.AreEqual('!', OSKKeyNameToEngineKey('!', True));
  Assert.AreEqual(':', OSKKeyNameToEngineKey(':', True));
  Assert.AreEqual('?', OSKKeyNameToEngineKey('?', True));
end;

procedure TOSKInputTests.SpecialKeyNames_AreUnhandled;
begin
  // Special keys (Space, Backspace, Shift, ...) never fire OnKeySelect;
  // multi-char names must map to '' so a future firing cannot type garbage.
  Assert.AreEqual('', OSKKeyNameToEngineKey('Space', False));
  Assert.AreEqual('', OSKKeyNameToEngineKey('Backspace', False));
  Assert.AreEqual('', OSKKeyNameToEngineKey('Shift', True));
  Assert.AreEqual('', OSKKeyNameToEngineKey('', False));
end;

procedure TOSKInputTests.MappedLetter_TypesDirectGlyph_Remington;
var
  Layout: TKeyboardLayout;
begin
  Layout := LayoutJson.LoadLayoutFromFile('layouts\gujarati\remington.json');
  try
    // An unshifted click on K maps to 'k', whose direct glyph is the decoded
    // Gujarati KA; typing the raw name would produce KHA (direct['K']).
    Assert.AreEqual('ક', TypeSequence(Layout, OSKKeyNameToEngineKey('K', False)),
      'an unshifted OSK click on K must type the k glyph, not the K glyph');
  finally
    Layout.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TOSKInputTests);

end.
