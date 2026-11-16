[CmdletBinding()]
param(
    [string]$OutputDir = "",
    [ValidateRange(0, 720)]
    [double]$WaitMinutes = 30,
    [ValidateRange(1, 1500)]
    [int]$ExportTimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
$project = Join-Path $repoRoot "game"

function Get-SourceChanges {
    $changes = @()
    # Keep Git's Windows line-ending advisory out of captured filename output.
    # This changes no comparison: unstaged content is still checked with
    # --ignore-cr-at-eol, and staged/untracked source remains fatal.
    $changes += @(& git -c core.safecrlf=false -C $repoRoot diff --name-only --ignore-cr-at-eol)
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect unstaged source changes." }
    $changes += @(& git -c core.safecrlf=false -C $repoRoot diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect staged source changes." }
    $untracked = @(& git -c core.safecrlf=false -C $repoRoot ls-files --others --exclude-standard)
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect untracked source paths." }
    $changes += @($untracked | Where-Object {
        $_ -notmatch '^game/.+\.(gd|gdshader|gdshaderinc|gdextension)\.uid$'
    })
    return @($changes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique)
}

function Assert-GeneratedUidSeal {
    $manifestPath = Join-Path $project ".godot\.orison_import_uids.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Generated UID seal is absent; warm this release checkout again."
    }
    $expected = @(Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json)
    $actualPaths = @(& git -c core.safecrlf=false -C $repoRoot `
            ls-files --others --exclude-standard |
        Where-Object { $_ -match '^game/.+\.(gd|gdshader|gdshaderinc|gdextension)\.uid$' } |
        Sort-Object)
    $expectedPaths = @($expected | ForEach-Object { $_.path } | Sort-Object)
    if ((Compare-Object $actualPaths $expectedPaths).Count -ne 0) {
        throw "Generated UID set differs from the sealed cold import."
    }
    foreach ($record in $expected) {
        $actualHash = (Get-FileHash -Algorithm SHA256 `
            -LiteralPath (Join-Path $repoRoot $record.path)).Hash.ToLowerInvariant()
        if ($actualHash -ne $record.sha256) {
            throw "Generated UID changed after cold import: $($record.path)"
        }
    }
}
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

$dirty = @(Get-SourceChanges)
if ($dirty.Count -ne 0) {
    throw "Friends exports require a clean checkout; found $($dirty.Count) dirty or untracked paths."
}
$templateChecker = Join-Path $PSScriptRoot "build_godot_reflection_fix.py"
& python -B $templateChecker --check-template
if ($LASTEXITCODE -ne 0) {
    throw "Friends exports require the hash-bound patched Windows release template."
}
$templateManifestPath = Join-Path $project ".godot\orison_templates\manifest.json"
$templateManifestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $templateManifestPath).Hash
$templateManifest = Get-Content -LiteralPath $templateManifestPath -Raw | ConvertFrom-Json
Assert-GeneratedUidSeal
$commit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') {
    throw "Cannot resolve the exact source commit."
}
$importMarker = Join-Path $project ".godot\.orison_import_ready"
if (-not (Test-Path -LiteralPath $importMarker -PathType Leaf) -or
        (Get-Content -LiteralPath $importMarker -Raw).Trim() -ne $commit) {
    throw "Release checkout is not warmed for $commit; run tools/warm_release_checkout.ps1 first."
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$exe = Join-Path $OutputDir "PleaseRemainOnTheLine.exe"
$pck = Join-Path $OutputDir "PleaseRemainOnTheLine.pck"
$manifestPath = Join-Path $OutputDir ".orison_export.json"
$relativeExe = [IO.Path]::GetRelativePath($project, $exe).Replace('\', '/')
$attempt = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmss") + "_" + [Guid]::NewGuid().ToString("N").Substring(0, 8)
$log = Join-Path $OutputDir "export_$($commit.Substring(0, 8))_$attempt.log"
$lane = Join-Path $PSScriptRoot "lane.ps1"

# Imported glTF/GDScript sources are stripped in templates. Validate their
# reviewed bindings here; runtime checks the compiled profile JSON seal.
& python -B (Join-Path $PSScriptRoot "audit_staff_standing_columns.py") --root $repoRoot --check
if ($LASTEXITCODE -ne 0) {
    throw "Staff standing-column source/profile binding is stale; export refused."
}

& $lane run -ProjectPath $project -Runner long -WaitMinutes $WaitMinutes -TimeoutSeconds $ExportTimeoutSeconds -LogPath $log `
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
$postExportDirty = @(Get-SourceChanges)
if ($postExportDirty.Count -ne 0) {
    throw "Godot changed $($postExportDirty.Count) tracked or untracked paths during export; no source manifest will be written."
}
Assert-GeneratedUidSeal
& python -B $templateChecker --check-template
if ($LASTEXITCODE -ne 0 -or
        (Get-FileHash -Algorithm SHA256 -LiteralPath $templateManifestPath).Hash -ne $templateManifestHash) {
    throw "Patched runtime template changed during export; no source manifest will be written."
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
    template = [ordered]@{
        base = $templateManifest.base
        target = $templateManifest.target
        runtime_sha256 = $templateManifest.binaries.runtime
        console_sha256 = $templateManifest.binaries.console
        source_archives = $templateManifest.source_archives
        local_patches = $templateManifest.local_patches
        release_options = $templateManifest.release_options
    }
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
Write-Output "EXPORT PASS commit=$commit"
Write-Output "manifest=$manifestPath"
