[CmdletBinding()]
param(
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
$project = Join-Path $repoRoot "game"
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $repoRoot "build\windows"
}
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot "build"))
if (-not $OutputDir.StartsWith(
        $allowedRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputDir must resolve beneath the repository build directory."
}

$dirty = @(& git -C $repoRoot status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) {
    throw "Cannot inspect the source checkout."
}
if ($dirty.Count -ne 0) {
    throw "Friends exports require a clean checkout; found $($dirty.Count) dirty or untracked paths."
}
$commit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') {
    throw "Cannot resolve the exact source commit."
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$exe = Join-Path $OutputDir "PleaseRemainOnTheLine.exe"
$pck = Join-Path $OutputDir "PleaseRemainOnTheLine.pck"
$manifestPath = Join-Path $OutputDir ".orison_export.json"
$relativeExe = [IO.Path]::GetRelativePath($project, $exe).Replace('\', '/')
$log = Join-Path ([IO.Path]::GetTempPath()) "orison_export_$($commit.Substring(0, 8)).log"
$serial = Join-Path $PSScriptRoot "run_godot_serial.ps1"

& $serial -ProjectPath $project -TimeoutSeconds 60 -LogPath $log `
    -ExtraArgs @("--export-release", "Windows", $relativeExe)
$engineExit = $LASTEXITCODE
$filtered = @()
if (Test-Path -LiteralPath $log) {
    $filtered += Get-Content -LiteralPath $log |
        Where-Object { $_ -match 'export|ERROR|FAIL|parse error|SCRIPT ERROR|timeout' }
}
if (Test-Path -LiteralPath "$log.stderr") {
    $filtered += Get-Content -LiteralPath "$log.stderr" |
        Where-Object { $_ -match 'export|ERROR|FAIL|parse error|SCRIPT ERROR|timeout' }
}
foreach ($line in $filtered) { Write-Output $line }
if ($engineExit -ne 0) {
    throw "Windows export failed with exit $engineExit."
}
$postExportDirty = @(& git -C $repoRoot status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) {
    throw "Cannot verify the source checkout after export."
}
if ($postExportDirty.Count -ne 0) {
    throw "Godot changed $($postExportDirty.Count) tracked or untracked paths during export; no source manifest will be written."
}
foreach ($required in @($exe, $pck)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Windows export did not produce $required"
    }
}

$manifest = [ordered]@{
    schema_version = 1
    commit = $commit
    preset = "Windows"
    exported_utc = [DateTime]::UtcNow.ToString("o")
    exe_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $exe).Hash.ToLowerInvariant()
    pck_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $pck).Hash.ToLowerInvariant()
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
Write-Output "EXPORT PASS commit=$commit"
Write-Output "manifest=$manifestPath"
