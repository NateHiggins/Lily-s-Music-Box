[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
$project = Join-Path $repoRoot "game"
$commit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') {
    throw "Cannot resolve the exact source commit."
}

function Get-SourceChanges {
    $changes = @()
    $changes += @(& git -C $repoRoot diff --name-only --ignore-cr-at-eol)
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect unstaged source changes." }
    $changes += @(& git -C $repoRoot diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect staged source changes." }
    $changes += @(& git -C $repoRoot ls-files --others --exclude-standard)
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect untracked source paths." }
    return @($changes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique)
}

$dirty = @(Get-SourceChanges)
if ($dirty.Count -ne 0) {
    throw "Release import requires a clean checkout; found $($dirty.Count) source changes."
}
$log = Join-Path ([IO.Path]::GetTempPath()) "orison_import_$($commit.Substring(0, 8)).log"
$serial = Join-Path $PSScriptRoot "run_godot_serial.ps1"
& $serial -ProjectPath $project -TimeoutSeconds 60 -LogPath $log `
    -ExtraArgs @("--editor", "--quit")
$engineExit = $LASTEXITCODE
if ($engineExit -ne 0) {
    throw "Import did not finish inside this lane (exit $engineExit). Run this command again manually; it never retries itself."
}
$after = @(Get-SourceChanges)
if ($after.Count -ne 0) {
    throw "Import changed $($after.Count) source paths; readiness marker withheld."
}
$marker = Join-Path $project ".godot\.orison_import_ready"
Set-Content -LiteralPath $marker -Value $commit -Encoding ascii
Write-Output "IMPORT PASS commit=$commit"
Write-Output "marker=$marker"
