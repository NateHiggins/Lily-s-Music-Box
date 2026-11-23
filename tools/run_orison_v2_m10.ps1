[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("K2", "K3")]
    [string]$Gate,
    [ValidateRange(1, 11)]
    [int]$Boundary = 1,
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$')]
    [string]$Attempt,
    [string]$GodotPath = "",
    [string]$EvidenceRoot = "",
    [switch]$Fresh,
    [switch]$PrepareOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$projectPath = Join-Path $repoRoot 'game'
if (-not $EvidenceRoot) {
    $EvidenceRoot = Join-Path $repoRoot 'art/renders/orison_v2/m10_golden_shift_v2_01'
}
$privateRoot = Join-Path ([IO.Path]::GetFullPath($EvidenceRoot)) '_private'

. (Join-Path $PSScriptRoot 'lane_common.ps1')
$enginePath = Resolve-OrisonGodot
$engineHash = (Get-FileHash -LiteralPath $enginePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($GodotPath) {
    $explicitHash = (Get-FileHash -LiteralPath $GodotPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($explicitHash -ne $engineHash) { throw '-GodotPath must match the Godot executable selected by the lane.' }
}

$commit = git -C $repoRoot rev-parse --verify HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot identify the build commit.' }
$tree = git -C $repoRoot rev-parse 'HEAD^{tree}'
if ($LASTEXITCODE -ne 0) { throw 'Cannot identify the build tree.' }
$changes = @(git -C $repoRoot status --porcelain)
if ($LASTEXITCODE -ne 0 -or $changes.Count) { throw 'Use a clean checkout for a playtest receipt.' }

$selectorSource = Get-Content -LiteralPath (Join-Path $projectPath 'scripts/building/building_root_selector.gd') -Raw
$selectorDefault = [regex]::Match($selectorSource, 'const DEFAULT_ID\s*:?=\s*"(\w+)"').Groups[1].Value
$saveSource = Get-Content -LiteralPath (Join-Path $projectPath 'scripts/game/reality_game_state.gd') -Raw
$saveVersion = [regex]::Match($saveSource, 'const SAVE_VERSION\s*:?=\s*(\d+)').Groups[1].Value
if ($selectorDefault -ne 'v2' -or -not $saveVersion) { throw 'Cannot identify the V2 selector and save version.' }

$boundaryName = if ($Gate -eq 'K2') { 'k2' } else { 'k3_{0:d2}' -f $Boundary }
$runId = ([guid]::NewGuid()).ToString('N')
if ($Fresh -and -not $Attempt) { $Attempt = $runId }
$profileName = if ($Attempt) { "$boundaryName-$Attempt" } else { $boundaryName }
$profileDir = Join-Path $privateRoot "profiles/$profileName"
$runDir = Join-Path $privateRoot "runs/$runId"
if ($Fresh -and (Test-Path -LiteralPath $profileDir)) {
    throw "The profile already exists. Omit -Attempt with -Fresh to generate a new one: $profileDir"
}

if ($Attempt -and -not $Fresh -and -not (Test-Path -LiteralPath $profileDir -PathType Container)) {
    throw "No saved profile matches attempt $Attempt for $boundaryName. Use -Fresh to start it."
}
New-Item -ItemType Directory -Force -Path (Split-Path $profileDir -Parent) | Out-Null
if ($Fresh) {
    New-Item -ItemType Directory -Path $profileDir | Out-Null
} else {
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
}
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

$logPath = Join-Path $runDir 'game.log'
$recipePath = Join-Path $runDir 'lane.json'
$receipt = [ordered]@{
    gate = $Gate
    boundary = if ($Gate -eq 'K3') { $Boundary } else { $null }
    attempt = $Attempt
    fresh_profile = [bool]$Fresh
    git_commit = $commit
    git_tree = $tree
    project_sha256 = (Get-FileHash -LiteralPath (Join-Path $projectPath 'project.godot') -Algorithm SHA256).Hash.ToLowerInvariant()
    engine_sha256 = $engineHash
    selector_environment = 'ORISON_BUILDING_ROOT=v2'
    selected_scene = 'res://scenes/building/orison_v2_runtime.tscn'
    committed_default = $selectorDefault
    save_version = [int]$saveVersion
    isolated_profile = $profileDir
    run_receipt = "$logPath.receipt.json"
    prepared_at_utc = [DateTime]::UtcNow.ToString('o')
}
$receipt | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDir 'playtest_setup.json') -Encoding utf8

$recipe = [ordered]@{
    project = $projectPath
    log = $logPath
    runner = 'long'
    timeout = 1500
    windowed = $true
    environment = [ordered]@{
        APPDATA = $profileDir
        ORISON_BUILDING_ROOT = 'v2'
        ORISON_VISIBLE_GODOT = '1'
    }
}
ConvertTo-Json -InputObject @($recipe) -Depth 4 | Set-Content -LiteralPath $recipePath -Encoding utf8
Write-Output "Playtest setup: $runDir"
Write-Output "Isolated save profile: $profileDir"
if ($Attempt) { Write-Output "To return to this profile, repeat -Gate and -Boundary with -Attempt $Attempt and omit -Fresh." }
if ($PrepareOnly) { return }

& (Join-Path $PSScriptRoot 'lane.ps1') batch -BatchFile $recipePath -WaitMinutes 30
exit $LASTEXITCODE
