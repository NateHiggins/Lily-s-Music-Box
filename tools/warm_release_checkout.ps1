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
    param([switch]$AllowGeneratedUids)
    $changes = @()
    # Native stderr can enter PowerShell's captured success stream. Git's
    # "LF will be replaced by CRLF" advisory was consequently counted as a
    # dirty filename after a cold Windows import even when the comparison
    # below proved every sidecar byte-equivalent modulo CRLF. Disable only
    # that advisory; the diff/index/untracked checks remain fail-closed.
    $changes += @(& git -c core.safecrlf=false -C $repoRoot diff --name-only --ignore-cr-at-eol)
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect unstaged source changes." }
    $changes += @(& git -c core.safecrlf=false -C $repoRoot diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect staged source changes." }
    $untracked = @(& git -c core.safecrlf=false -C $repoRoot ls-files --others --exclude-standard)
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect untracked source paths." }
    if ($AllowGeneratedUids) {
        $untracked = @($untracked | Where-Object { $_ -notmatch '^game/.+\.gd\.uid$' })
    }
    $changes += $untracked
    return @($changes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique)
}

$startedMarker = Join-Path $project ".godot\.orison_import_started"
$resumeStartedImport = (Test-Path -LiteralPath $startedMarker -PathType Leaf) -and
    ((Get-Content -LiteralPath $startedMarker -Raw).Trim() -eq $commit)
$dirty = @(Get-SourceChanges -AllowGeneratedUids:$resumeStartedImport)
if ($dirty.Count -ne 0) {
    throw "Release import requires a clean checkout; found $($dirty.Count) source changes."
}
if (-not $resumeStartedImport) {
    New-Item -ItemType Directory -Force -Path (Split-Path $startedMarker -Parent) | Out-Null
    Set-Content -LiteralPath $startedMarker -Value $commit -Encoding ascii
}
$log = Join-Path ([IO.Path]::GetTempPath()) "orison_import_$($commit.Substring(0, 8)).log"
$serial = Join-Path $PSScriptRoot "run_godot_serial.ps1"
& $serial -ProjectPath $project -TimeoutSeconds 60 -LogPath $log `
    -ExtraArgs @("--editor", "--quit")
$engineExit = $LASTEXITCODE
if ($engineExit -ne 0) {
    throw "Import did not finish inside this lane (exit $engineExit). Run this command again manually; it never retries itself."
}
$after = @(Get-SourceChanges -AllowGeneratedUids)
if ($after.Count -ne 0) {
    throw "Import changed $($after.Count) source paths; readiness marker withheld."
}
$marker = Join-Path $project ".godot\.orison_import_ready"
Set-Content -LiteralPath $marker -Value $commit -Encoding ascii
$uidManifest = Join-Path $project ".godot\.orison_import_uids.json"
$uidRecords = @(& git -c core.safecrlf=false -C $repoRoot `
        ls-files --others --exclude-standard | Where-Object { $_ -match '^game/.+\.gd\.uid$' } |
    Sort-Object | ForEach-Object {
        [ordered]@{
            path = $_
            sha256 = (Get-FileHash -Algorithm SHA256 `
                -LiteralPath (Join-Path $repoRoot $_)).Hash.ToLowerInvariant()
        }
    })
@($uidRecords) | ConvertTo-Json | Set-Content -LiteralPath $uidManifest -Encoding utf8NoBOM
Write-Output "IMPORT PASS commit=$commit"
Write-Output "marker=$marker"
Write-Output "generated_uids=$($uidRecords.Count)"
