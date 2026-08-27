[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 999)]
    [int]$BuildNumber,
    [string]$SourceDir = "",
    [string]$OutputDir = "",
    [string]$ReadmePath = "",
    [Parameter(Mandatory = $true)]
    [string]$LicensePath
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
foreach ($audit in @(
    @{ Script = "audit_music_catalog.py"; Args = @((Join-Path $repoRoot "game/data/music_catalog.json")) },
    @{ Script = "audit_period_dates.py"; Args = @($repoRoot) }
)) {
    $auditPath = Join-Path $PSScriptRoot $audit.Script
    & python $auditPath @($audit.Args)
    if ($LASTEXITCODE -ne 0) {
        throw "Friends packaging refused by $($audit.Script)."
    }
}

if ([string]::IsNullOrWhiteSpace($SourceDir)) {
    $SourceDir = Join-Path $repoRoot "build\windows"
}
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $repoRoot "build\packages"
}
if ([string]::IsNullOrWhiteSpace($ReadmePath)) {
    $ReadmePath = Join-Path $repoRoot "distribution\README_TESTER.txt"
}

$source = (Resolve-Path -LiteralPath $SourceDir).Path
$readme = (Resolve-Path -LiteralPath $ReadmePath).Path
$license = (Resolve-Path -LiteralPath $LicensePath).Path
$exe = Join-Path $source "PleaseRemainOnTheLine.exe"
$pck = Join-Path $source "PleaseRemainOnTheLine.pck"
$exportManifest = Join-Path $source ".orison_export.json"
foreach ($required in @($exe, $pck)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required paired export artifact is absent: $required"
    }
}

$commit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') {
    throw "Cannot resolve the exact source commit."
}
$manifest = Get-Content -LiteralPath $exportManifest -Raw -ErrorAction Stop |
    ConvertFrom-Json
if ($manifest.commit -ne $commit -or $manifest.preset -ne "Windows") {
    throw "Export manifest does not match HEAD and the Windows preset. Export again from a clean checkout."
}
$sourceExeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $exe).Hash.ToLowerInvariant()
$sourcePckHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $pck).Hash.ToLowerInvariant()
if ($manifest.exe_sha256 -ne $sourceExeHash -or $manifest.pck_sha256 -ne $sourcePckHash) {
    throw "Export artifacts no longer match their source manifest. Export again."
}
$shortSha = $commit.Substring(0, 8)
$projectText = Get-Content -LiteralPath (Join-Path $repoRoot "game\project.godot") -Raw
$versionMatch = [regex]::Match($projectText, '(?m)^config/version="([^"]+)"\r?$')
if (-not $versionMatch.Success) {
    throw "application/config/version is absent from game/project.godot."
}
$version = $versionMatch.Groups[1].Value
$number = $BuildNumber.ToString('000')
$artifact = "PleaseRemainOnTheLine_friends-${number}_win64_${shortSha}"

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$output = (Resolve-Path -LiteralPath $OutputDir).Path
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot "build"))
if (-not ([IO.Path]::GetFullPath($output).StartsWith(
        $allowedRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase))) {
    throw "OutputDir must resolve beneath the repository build directory."
}

$stage = Join-Path $output $artifact
$zip = Join-Path $output ($artifact + ".zip")
$sidecar = $zip + ".sha256"
foreach ($target in @($stage, $zip, $sidecar)) {
    if (Test-Path -LiteralPath $target) {
        throw "Refusing to overwrite an existing numbered artifact: $target"
    }
}

New-Item -ItemType Directory -Path $stage | Out-Null
Copy-Item -LiteralPath $exe -Destination (Join-Path $stage "PleaseRemainOnTheLine.exe")
Copy-Item -LiteralPath $pck -Destination (Join-Path $stage "PleaseRemainOnTheLine.pck")
Copy-Item -LiteralPath $license -Destination (Join-Path $stage "LICENSE.txt")
$noticeBuilder = Join-Path $PSScriptRoot "build_third_party_notices.ps1"
& $noticeBuilder -OutputPath (Join-Path $stage "THIRD_PARTY_NOTICES.txt")
if ($LASTEXITCODE -ne 0) {
    throw "Third-party notice generation failed."
}

$readmeText = Get-Content -LiteralPath $readme -Raw
$readmeText = $readmeText.Replace('{{BUILD_NUMBER}}', $number)
$readmeText = $readmeText.Replace('{{SHORT_SHA}}', $shortSha)
$readmeText = $readmeText.Replace('{{VERSION}}', $version)
Set-Content -LiteralPath (Join-Path $stage "README_TESTER.txt") `
    -Value $readmeText -Encoding utf8NoBOM

$exeHash = $sourceExeHash
$pckHash = $sourcePckHash
$built = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$identity = @(
    "build      friends-$number"
    "version    $version"
    "commit     $commit"
    "built      $built"
    "preset     Windows"
    "engine     Godot 4.7.1"
    "exe_sha256 $exeHash"
    "pck_sha256 $pckHash"
) -join [Environment]::NewLine
Set-Content -LiteralPath (Join-Path $stage "BUILD_ID.txt") `
    -Value $identity -Encoding ascii

$actual = @(Get-ChildItem -LiteralPath $stage -File | Select-Object -ExpandProperty Name | Sort-Object)
$expected = @("BUILD_ID.txt", "LICENSE.txt", "PleaseRemainOnTheLine.exe",
    "PleaseRemainOnTheLine.pck", "README_TESTER.txt",
    "THIRD_PARTY_NOTICES.txt") | Sort-Object
if ((Compare-Object $actual $expected).Count -ne 0) {
    throw "Staging directory violates the six-file artifact contract."
}

Compress-Archive -LiteralPath $stage -DestinationPath $zip -CompressionLevel Optimal
$zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
Set-Content -LiteralPath $sidecar -Value "$zipHash  $([IO.Path]::GetFileName($zip))" `
    -Encoding ascii

Write-Output "PACKAGE PASS"
Write-Output "directory=$stage"
Write-Output "archive=$zip"
Write-Output "sha256=$zipHash"
