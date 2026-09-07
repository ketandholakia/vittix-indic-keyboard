unit Tests.Keyboard.Hotkeys;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Winapi.Windows,
  AppSettings;

type
  [TestFixture]
  [Category('Hotkey')]
  THotkeyTests = class
  strict private
    FSettings: TAppSettings;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ParseHotkey_ValidModifiersAndKey_Accepts;
    
    [Test]
    procedure ParseHotkey_WinModifier_Supported;

    [Test]
    procedure ParseHotkey_SpaceKey_Supported;
    
    [Test]
    procedure ParseHotkey_FunctionKeys_Supported;
    
    [Test]
    procedure ParseHotkey_InvalidFunctionKey_Rejected;
    
    [Test]
    procedure ParseHotkey_UnmodifiedKey_Rejected;
    
    [Test]
    procedure ParseHotkey_EmptyOrMalformed_Rejected;
  end;

implementation

procedure THotkeyTests.Setup;
begin
  // We don't need a real INI file to test ParseHotkey
  FSettings := TAppSettings.Create('');
end;

procedure THotkeyTests.TearDown;
begin
  FSettings.Free;
end;

procedure THotkeyTests.ParseHotkey_ValidModifiersAndKey_Accepts;
var
  Modifiers, VirtualKey: UINT;
begin
  Assert.IsTrue(FSettings.ParseHotkey('Ctrl+Alt+K', Modifiers, VirtualKey));
  Assert.AreEqual(UINT(MOD_CONTROL or MOD_ALT), Modifiers);
  Assert.AreEqual(UINT(Ord('K')), VirtualKey);

  Assert.IsTrue(FSettings.ParseHotkey('Shift+A', Modifiers, VirtualKey));
  Assert.AreEqual(UINT(MOD_SHIFT), Modifiers);
  Assert.AreEqual(UINT(Ord('A')), VirtualKey);
end;

procedure THotkeyTests.ParseHotkey_WinModifier_Supported;
var
  Modifiers, VirtualKey: UINT;
begin
  Assert.IsTrue(FSettings.ParseHotkey('Win+X', Modifiers, VirtualKey));
  Assert.AreEqual(UINT(MOD_WIN), Modifiers);
  Assert.AreEqual(UINT(Ord('X')), VirtualKey);
  
  Assert.IsTrue(FSettings.ParseHotkey('Windows+X', Modifiers, VirtualKey));
  Assert.AreEqual(UINT(MOD_WIN), Modifiers);
end;

procedure THotkeyTests.ParseHotkey_SpaceKey_Supported;
var
  Modifiers, VirtualKey: UINT;
begin
  Assert.IsTrue(FSettings.ParseHotkey('Ctrl+Space', Modifiers, VirtualKey));
  Assert.AreEqual(UINT(MOD_CONTROL), Modifiers);
  Assert.AreEqual(UINT(VK_SPACE), VirtualKey);
end;

procedure THotkeyTests.ParseHotkey_FunctionKeys_Supported;
var
  Modifiers, VirtualKey: UINT;
begin
  Assert.IsTrue(FSettings.ParseHotkey('Ctrl+F1', Modifiers, VirtualKey));
  Assert.AreEqual(UINT(MOD_CONTROL), Modifiers);
  Assert.AreEqual(UINT(VK_F1), VirtualKey);
  
  Assert.IsTrue(FSettings.ParseHotkey('Alt+F12', Modifiers, VirtualKey));
  Assert.AreEqual(UINT(MOD_ALT), Modifiers);
  Assert.AreEqual(UINT(VK_F12), VirtualKey);
end;

procedure THotkeyTests.ParseHotkey_InvalidFunctionKey_Rejected;
var
  Modifiers, VirtualKey: UINT;
begin
  Assert.IsFalse(FSettings.ParseHotkey('Ctrl+F0', Modifiers, VirtualKey));
  Assert.IsFalse(FSettings.ParseHotkey('Ctrl+F25', Modifiers, VirtualKey));
  Assert.IsFalse(FSettings.ParseHotkey('Ctrl+Foo', Modifiers, VirtualKey));
end;

procedure THotkeyTests.ParseHotkey_UnmodifiedKey_Rejected;
var
  Modifiers, VirtualKey: UINT;
begin
  Assert.IsFalse(FSettings.ParseHotkey('K', Modifiers, VirtualKey), 'Unmodified key should be rejected');
  Assert.IsFalse(FSettings.ParseHotkey('F12', Modifiers, VirtualKey), 'Unmodified F12 should be rejected');
end;

procedure THotkeyTests.ParseHotkey_EmptyOrMalformed_Rejected;
var
  Modifiers, VirtualKey: UINT;
begin
  Assert.IsFalse(FSettings.ParseHotkey('', Modifiers, VirtualKey));
  Assert.IsFalse(FSettings.ParseHotkey('Ctrl+', Modifiers, VirtualKey));
  Assert.IsFalse(FSettings.ParseHotkey('Ctrl+Alt', Modifiers, VirtualKey));
  Assert.IsFalse(FSettings.ParseHotkey('NotAModifier+A', Modifiers, VirtualKey));
end;

initialization
  TDUnitX.RegisterTestFixture(THotkeyTests);

end.
