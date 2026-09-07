# Vittix Indic Keyboard

Vittix Indic Keyboard is a fast, reliable, and fail-open Indic language typing tool for Windows. It provides comprehensive layout support for various Indic scripts (such as Devanagari, Gujarati, Marathi, Tamil, etc.) and integrates deeply with Win32 applications via a global keyboard hook to intercept and translate keystrokes dynamically.

## Features
- **Broad Language Support:** Extensible JSON-based layout configuration.
- **Fail-Open Injection:** Safe handling of Win32 `SendInput` results, falling back seamlessly if translation fails.
- **Customizable:** Settings stored locally (`%APPDATA%`), whitelist target applications, and bounded logging (`%LOCALAPPDATA%`).
- **Layout Editor:** A companion GUI layout editor to modify and validate custom layout sequences and mappings.

## Supported Versions
- **OS:** Windows 10, Windows 11 (Standard user installation supported)
- **Toolchain:** Embarcadero Delphi Studio 23.0 for Win32

## Building from Source

To compile the keyboard, editor, and run tests, you can use the provided batch scripts:
```bat
# 1. Build tests
.\build_tests.bat

# 2. Run tests
.\build\Win32\VittixIndicTests.exe

# 3. Build main keyboard application
.\build_test.bat

# 4. Build Layout Editor
.\build_editor.bat
```

## Installation & Configuration
Install the software using the provided Inno Setup executable. The configuration files are stored safely in:
- Config: `%APPDATA%\Vittix\settings.ini`
- Logs: `%LOCALAPPDATA%\Vittix\Logs\`

Target applications are filtered via an internal whitelist, which can be modified dynamically via the tray icon menu.

## Layout Overview
Layouts dictate the behavior of keys and sequence mappings.
**Note on Sequences**: Multi-key sequences (e.g., legacy combinations) are currently deprecated and retained only for backward compatibility. Users are encouraged to utilize halant-based conjunct entry, which the runtime explicitly supports.

## Example Unicode Layouts

### Gujarati
- Gujarati Phonetic Example: An English-key phonetic typing layout for users who are familiar with Latin keys. Output uses real Unicode characters. Example mappings: `a -> અ`, `k -> ક`.
- Gujarati InScript: A positional standard layout producing real Unicode Gujarati characters.

### Hindi
- Hindi Phonetic Example: An English-key-to-Devanagari phonetic layout, using real Devanagari Unicode characters. Example mappings: `a -> अ`, `k -> क`.
- Hindi InScript: A positional layout producing Unicode Devanagari characters.

*Note: The InScript layouts are examples of positional mappings and should not be considered verified official government standards.*

## Known Limitations
- Elevated targets (Run As Administrator) might reject keyboard injection if the keyboard is running as a standard user. In these cases, the engine correctly fails open and passes native keystrokes through.
- Multi-key sequences are not executed by the runtime.
- Some edge-case rendering might depend on the active font within the target application.

## Contribution & Release
Before proposing changes, ensure you test thoroughly without adding destructive hooks. Always run `build\Win32\VittixIndicTests.exe` to guarantee the engine's core input lifecycle remains isolated and correct.
For release, compile the Inno Setup script (`installer/InnoSetup.iss`) to package the application.
