@echo off
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\msbuild.exe" Tests\VittixIndicTests.dproj /p:Config=Debug /p:Platform=Win32 /v:minimal