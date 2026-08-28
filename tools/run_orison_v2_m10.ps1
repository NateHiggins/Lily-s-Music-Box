[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("K2", "K3")]
    [string]$Gate,
    [ValidateRange(1, 11)]
    [int]$Boundary = 1,
    [string]$GodotPath = "",
    [switch]$Fresh
)

$repoRoot = Split-Path $PSScriptRoot -Parent
$projectPath = Join-Path $repoRoot "game"
$evidenceRoot = Join-Path $repoRoot "art/renders/orison_v2/m10_golden_shift_v2_01"
$profileName = if ($Gate -eq "K2") { "k2" } else { "k3_{0:d2}" -f $Boundary }
$profileRoot = Join-Path $evidenceRoot "_private/profiles/$profileName"
$runtimeReceipt = Join-Path $profileRoot "launch_receipt.json"

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $command = Get-Command Godot_v4.7.1-stable_win64_console.exe -ErrorAction SilentlyContinue
    if (-not $command) { throw "Pass -GodotPath with the Godot 4.7.1 console executable." }
    $GodotPath = $command.Source
}
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path

if ($Fresh -and (Test-Path -LiteralPath $profileRoot)) {
    $resolvedEvidence = [IO.Path]::GetFullPath($evidenceRoot)
    $resolvedProfile = [IO.Path]::GetFullPath($profileRoot)
    if (-not $resolvedProfile.StartsWith($resolvedEvidence, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clear a profile outside the M10 evidence root."
    }
    Remove-Item -LiteralPath $resolvedProfile -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $profileRoot | Out-Null

$gitCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$gitTree = (& git -C $repoRoot rev-parse 'HEAD^{tree}').Trim()
$projectHash = (Get-FileHash (Join-Path $projectPath "project.godot") -Algorithm SHA256).Hash.ToLowerInvariant()
$receipt = [ordered]@{
    gate = $Gate
    boundary = if ($Gate -eq "K3") { $Boundary } else { $null }
    git_commit = $gitCommit
    git_tree = $gitTree
    project_sha256 = $projectHash
    selector_environment = "ORISON_BUILDING_ROOT=v2"
    selected_scene = "res://scenes/building/orison_v2_runtime.tscn"
    committed_default = "v1"
    save_version = 4
    isolated_profile = "_private/profiles/$profileName"
    launched_at_utc = [DateTime]::UtcNow.ToString("o")
}
$receipt | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $runtimeReceipt -Encoding utf8

$previousSelector = $env:ORISON_BUILDING_ROOT
$previousAppData = $env:APPDATA
try {
    $env:ORISON_BUILDING_ROOT = "v2"
    $env:APPDATA = $profileRoot
    & $GodotPath --path $projectPath
    exit $LASTEXITCODE
}
finally {
    $env:ORISON_BUILDING_ROOT = $previousSelector
    $env:APPDATA = $previousAppData
}
