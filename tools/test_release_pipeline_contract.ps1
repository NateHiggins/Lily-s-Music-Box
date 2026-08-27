[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
$failures = 0
$checks = 0

function Assert-Contract {
    param([bool]$Condition, [string]$Label)
    $script:checks += 1
    if ($Condition) {
        Write-Output "RELEASE CONTRACT PASS $Label"
    }
    else {
        $script:failures += 1
        Write-Output "RELEASE CONTRACT FAIL $Label"
    }
}

$scripts = @(
    "run_godot_serial.ps1",
    "warm_release_checkout.ps1",
    "export_friends_build.ps1",
    "package_friends_build.ps1",
    "build_third_party_notices.ps1"
)
foreach ($name in $scripts) {
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $PSScriptRoot $name), [ref]$null, [ref]$errors) | Out-Null
    Assert-Contract ($errors.Count -eq 0) "$name parses in Windows PowerShell"
}

$projectText = Get-Content -LiteralPath (Join-Path $repoRoot "game\project.godot") -Raw
$version = [regex]::Match($projectText,
    '(?m)^config/version="([^"]+)"\r?$')
Assert-Contract ($version.Success -and $version.Groups[1].Value -eq "0.1.0") `
    "project version survives the real checkout newline convention"

$uidPattern = '^game/.+\.(gd|gdshader|gdshaderinc)\.uid$'
foreach ($allowed in @(
    "game/scripts/example.gd.uid",
    "game/shaders/example.gdshader.uid",
    "game/shaders/example.gdshaderinc.uid"
)) {
    Assert-Contract ($allowed -match $uidPattern) "UID seal admits $allowed"
}
foreach ($refused in @(
    "game/scripts/example.uid",
    "game/scenes/example.tscn.uid",
    "game/assets/example.png.uid",
    "design/example.gd.uid",
    "game/scripts/example.gd"
)) {
    Assert-Contract ($refused -notmatch $uidPattern) "UID seal refuses $refused"
}

$preset = Get-Content -LiteralPath (Join-Path $repoRoot "game\export_presets.cfg") -Raw
Assert-Contract ($preset.Contains('name="Windows"') -and
    $preset.Contains('platform="Windows Desktop"') -and
    $preset.Contains('binary_format/architecture="x86_64"')) `
    "tracked Windows x86-64 export preset exists"
Assert-Contract ($preset.Contains('binary_format/embed_pck=false')) `
    "packager-required paired EXE/PCK export is explicit"

$readme = Get-Content -LiteralPath (Join-Path $repoRoot `
    "distribution\README_TESTER.txt") -Raw
foreach ($token in @("{{BUILD_NUMBER}}", "{{SHORT_SHA}}", "{{VERSION}}")) {
    Assert-Contract ($readme.Contains($token)) "tester readme carries $token"
}

$packageSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot `
    "package_friends_build.ps1") -Raw
foreach ($audit in @(
    "audit_music_catalog.py", "audit_period_dates.py", "audit_audio_emitters.py"
)) {
    Assert-Contract ($packageSource.Contains($audit)) `
        "friends packaging runs $audit"
}
$sixFiles = @(
    "BUILD_ID.txt",
    "LICENSE.txt",
    "PleaseRemainOnTheLine.exe",
    "PleaseRemainOnTheLine.pck",
    "README_TESTER.txt",
    "THIRD_PARTY_NOTICES.txt"
)
foreach ($name in $sixFiles) {
    Assert-Contract ($packageSource.Contains('"' + $name + '"')) `
        "six-file payload names $name"
}
Assert-Contract ($packageSource.Contains('[Parameter(Mandatory = $true)]') -and
    $packageSource.Contains('[string]$LicensePath')) `
    "shipping licence remains an explicit mandatory input"
Assert-Contract ($packageSource.Contains('.orison_export.json') -and
    $packageSource.Contains('manifest.commit -ne $commit') -and
    $packageSource.Contains('manifest.exe_sha256') -and
    $packageSource.Contains('manifest.pck_sha256')) `
    "package refuses stale or changed export components"

Write-Output "RELEASE CONTRACT RESULT $(if ($failures -eq 0) { 'PASS' } else { 'FAIL' }) $($checks - $failures)/$checks"
exit $(if ($failures -eq 0) { 0 } else { 1 })
