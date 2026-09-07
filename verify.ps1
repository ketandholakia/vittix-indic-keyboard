$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

Write-Information "--- Vittix Indic Keyboard Verification Pipeline ---"

# Determine repository root based on script location and switch to it
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

# Resolve MSBuild path (Delphi projects compile via msbuild.exe)
$msbuild = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\msbuild.exe"
if (-not (Test-Path $msbuild)) {
    $msbuild = "msbuild.exe"
}

function Build-Project {
    param([string]$ProjectFile)
    Write-Information "`n[Build] Building $ProjectFile..."
    $process = Start-Process -FilePath $msbuild -ArgumentList "$ProjectFile", "/p:Config=Debug", "/p:Platform=Win32", "/v:minimal" -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Error "Build failed for $ProjectFile with exit code $($process.ExitCode)"
        exit $process.ExitCode
    }
}

# 1. Build DUnitX test project
Build-Project "Tests\VittixIndicTests.dproj"

# 2. Run Tests
Write-Information "`n[Test] Running Tests..."
$testExe = "build\Win32\VittixIndicTests.exe"
if (-not (Test-Path $testExe)) {
    Write-Error "Test executable not found: $testExe"
    exit 1
}
$process = Start-Process -FilePath $testExe -NoNewWindow -Wait -PassThru
if ($process.ExitCode -ne 0) {
    Write-Error "Tests failed with exit code $($process.ExitCode)"
    exit $process.ExitCode
}

# 3. Build Keyboard application
Build-Project "Keyboard\VittixIndicKeyboard.dproj"

# 4. Build Layout Editor
Build-Project "LayoutEditor\VittixIndicEditor.dproj"

# 5. Static Checks
Write-Information "`n[Static Analysis] Validating Layouts, Documentation, and Repository hygiene..."

# 5.1 Required documentation check
$requiredDocs = @("README.md", "LICENSE.txt")
foreach ($doc in $requiredDocs) {
    if (-not (Test-Path $doc)) {
        Write-Error "Required document missing: $doc"
        exit 1
    }
    $content = Get-Content $doc -Raw
    if ([string]::IsNullOrWhiteSpace($content)) {
        Write-Error "Required document is empty: $doc"
        exit 1
    }
}

# 5.2 Layout JSON validation
$layoutFiles = Get-ChildItem -Path "layouts" -Filter "*.json" -Recurse -File
$layoutIds = @{}
Add-Type -AssemblyName System.Web.Extensions
$js = New-Object System.Web.Script.Serialization.JavaScriptSerializer
foreach ($file in $layoutFiles) {
    try {
        $raw = Get-Content $file.FullName -Raw
        $json = $js.DeserializeObject($raw)
    } catch {
        Write-Error "Failed to parse JSON in $($file.FullName): $($_.Exception.Message)"
        exit 1
    }
    if (-not $json.ContainsKey("layout_id")) {
        Write-Error "Layout missing layout_id property: $($file.FullName)"
        exit 1
    }
    $id = $json["layout_id"]
    if ([string]::IsNullOrWhiteSpace($id)) {
        Write-Error "layout_id is empty in $($file.FullName)"
        exit 1
    }
    if ($layoutIds.ContainsKey($id)) {
        Write-Error "Duplicate layout_id '$id' found in $($file.FullName) (already seen in $($layoutIds[$id]))"
        exit 1
    }
    $layoutIds[$id] = $file.FullName
}
Write-Information "Found $($layoutFiles.Count) valid unique layouts."

# 5.3 Installer validation
$installerScript = "installer\InnoSetup.iss"
if (-not (Test-Path $installerScript)) {
    Write-Error "Installer script missing: $installerScript"
    exit 1
}
Write-Information "Installer script found."
$iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (Test-Path $iscc) {
    Write-Information "`n[Build] Building Installer..."
    $process = Start-Process -FilePath $iscc -ArgumentList "`"$installerScript`"" -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Error "Installer build failed with exit code $($process.ExitCode)"
        exit $process.ExitCode
    }
} else {
    Write-Information "Inno Setup compiler (ISCC.exe) not found; installer build skipped."
}

# 5.4 Repository hygiene – whitespace check
Write-Information "`n[Git] Running whitespace check..."
git diff --check
if ($LASTEXITCODE -ne 0) {
    Write-Error "git diff --check reported whitespace errors"
    exit $LASTEXITCODE
}

Write-Information "`n[Success] Verification pipeline completed successfully!"
exit 0
