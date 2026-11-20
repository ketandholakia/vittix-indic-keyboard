# Release process

## 1. Verify

```bat
verify.bat
```

Builds the DUnitX test suite, runs it, builds `VittixIndicKeyboard.exe` and
`VittixIndicEditor.exe`, optionally signs them (below), validates the shipped
layouts, and builds the installer when Inno Setup 6 or 7 is installed. Every gate
must be green before a release is cut.

## 2. Code-sign the exes (optional, env-var gated)

Unsigned exes trigger SmartScreen and "unknown publisher" warnings. Signing
is wired into `verify.ps1` but only runs when the following environment
variables are set, so everyday development needs no certificate:

| Variable | Meaning |
|---|---|
| `SIGNTOOL_PATH` | Full path to `signtool.exe` (ships with the Windows SDK, e.g. `C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe`). |
| `SIGN_PFX_PATH` | Path to the code-signing certificate (`*.pfx`). |
| `SIGN_PFX_PASSWORD` | The PFX password. Read by signtool only, never logged. |

```bat
set SIGNTOOL_PATH=C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe
set SIGN_PFX_PATH=C:\certs\vittix-codesign.pfx
set SIGN_PFX_PASSWORD=****
verify.bat
```

The step signs both exes with SHA-256 and an RFC 3161 timestamp
(`http://timestamp.digicert.com`), so the signatures outlive the certificate.
A signing failure fails the pipeline (exit code propagated). To sign manually:

```bat
signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 ^
  /f vittix-codesign.pfx /p **** build\Win32\VittixIndicKeyboard.exe
```

Verify signatures with `signtool verify /pa /v build\Win32\VittixIndicKeyboard.exe`.

## 3. Installer

`installer/InnoSetup.iss` reads `AppVersion` from the built exe's version
resource (`Keyboard/VittixIndicKeyboard.dproj` is the single version source),
so the binaries must be built before compiling the installer. It refuses to
run while the keyboard app is running (`AppMutex` matches the app's
per-session single-instance mutex, `Local\VittixIndicKeyboardInstance`), and
declares `PrivilegesRequired=admin` (machine install into Program Files).

Build it via the pipeline (automatic when ISCC.exe is on PATH or Inno Setup
6/7 is in a standard installation folder) or directly:

```bat
"C:\Program Files\Inno Setup 7\ISCC.exe" installer\InnoSetup.iss
```

For a custom compiler location, set `ISCC_PATH` to the full path to
`ISCC.exe` before running `verify.bat`. An invalid override fails verification.

Output: `build\VittixIndicKeyboardSetup.exe`. Sign the installer with the
same signtool command if a certificate is available.

## 4. Manual real-hardware pass

Run the checklist in `docs/MANUAL_VERIFICATION.md` (Tab/Enter ordering,
injection latch, watchdog, layout loading) on physical hardware before
publishing a release.
