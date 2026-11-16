# Vittix Indic Keyboard

Vittix Indic Keyboard is a Windows typing tool with a global keyboard hook,
fail-open text injection, JSON layouts, and a companion Layout Editor. When
translation cannot be completed, the keyboard passes the native keystroke
through instead of silently consuming it.

## Shipped layouts

The repository currently ships ten layouts. The `script` values represented
by those files are Devanagari and Gujarati; this is the supported shipped
layout inventory, not a claim of general support for every Indic script.

| File | Layout |
|---|---|
| `layouts/devnagari/krutidev_010.json` | KrutiDev Devanagari 010 |
| `layouts/devnagari/shreelipi_0708.json` | ShreeLipi Devanagari 0708 |
| `layouts/devnagari/shree_dev_1076.json` | ShreeLipi Devanagari 1076 |
| `layouts/custom/press_custom_1.json` | Press Custom 1 (Devanagari) |
| `layouts/hindi/hindi_phonetic.json` | Hindi Phonetic Example (Devanagari) |
| `layouts/hindi/hindi_inscript.json` | Hindi InScript (Devanagari) |
| `layouts/gujarati/remington.json` | Gujarati Remington |
| `layouts/gujarati/gujarati_remington_unicode.json` | Gujarati Remington Unicode |
| `layouts/gujarati/gujarati_phonetic.json` | Gujarati Phonetic Example |
| `layouts/gujarati/gujarati_inscript.json` | Gujarati InScript |

The InScript files are positional examples, not verified official government
standards.

## Runtime behavior

Layouts can define direct mappings, prebase mappings, postbase mappings, and
the executable `reph` and `halant` modifier rules. General multi-key
`sequences` are retained in legacy layout data but are not executed by the
current runtime. Other modifier definitions are likewise compatibility data,
not executable typing rules.

See [the layout file guide](docs/UserGuide_EN.md) for the authoring and
validation contract.

## Build and verification

The supported developer entry point is:

```bat
verify.bat
```

It builds the DUnitX tests, `VittixIndicKeyboard`, and `VittixIndicEditor`,
validates the shipped layouts, builds the installer when Inno Setup is
available, and runs `git diff --check`.

The projects require Embarcadero Delphi Studio 23.0 for Win32. For a local
test-only build, use `Tests\build_tests_local.bat`, then run
`build\Win32\VittixIndicTests.exe`.

## Installation and configuration

The Inno Setup package installs the keyboard application, Layout Editor,
layouts, documentation, README, and license. It adds Start Menu shortcuts for
the keyboard and editor, with an optional desktop shortcut for the keyboard.

Application settings are stored in `%APPDATA%\Vittix\settings.ini`; logs are
stored under `%LOCALAPPDATA%\Vittix\Logs\`. Target applications are controlled
through the application whitelist.

### Layouts folder resolution

The layouts folder is resolved in this order at startup and whenever settings
are applied:

1. The configured path (`[Layouts] Path` in `settings.ini`), when it exists
   and is writable.
2. `%APPDATA%\Vittix\layouts` — created on demand. When it is first created,
   the installed default layouts are copied into it from the application
   folder's `layouts` directory, so the copy is complete and up to date.
3. The application folder's `layouts` directory, as a read-only last resort.

When Vittix is installed under Program Files, the exe-relative layouts folder
is not writable, so the engine loads (and the Layout Editor saves) from the
per-user copy in `%APPDATA%\Vittix\layouts`. Edits made in the Layout Editor
therefore survive application updates and do not require administrative
rights. The resolved path is persisted in `settings.ini`, so later runs find
it directly.

## Limitations

Elevated target applications may reject injection from a standard-user
keyboard process. In that case Vittix fails open and lets the native keystroke
through. Rendering also depends on the fonts available in the target
application.

## Release packaging

`installer/InnoSetup.iss` packages the verified Win32 binaries and the files
listed above into `build\VittixIndicKeyboardSetup.exe`.
