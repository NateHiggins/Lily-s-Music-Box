[CmdletBinding()]
param([string]$EvidenceName = "current")
$ErrorActionPreference = "Stop"
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if ($EvidenceName -notmatch '^[a-zA-Z0-9_-]+$') { throw "EvidenceName must be a simple folder name" }
$output = Join-Path $project ("evidence/" + $EvidenceName)
$log = $output + ".log"
$manifest = [ordered]@{}
Get-ChildItem -LiteralPath $project -File -Recurse | Where-Object {
    $_.FullName -notmatch '[\/]\.godot[\/]|[\/]evidence[\/]' -and
    ($_.Extension -in '.gd', '.gdshader', '.gdshaderinc', '.compute', '.tscn', '.ps1' -or $_.Name -eq 'project.godot')
} | Sort-Object FullName | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath($project, $_.FullName).Replace('\','/')
    $manifest[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
}
& (Join-Path $PSScriptRoot "run_godot_serial.ps1") -ProjectPath $project -Windowed -ShotDir $output -LogPath $log -TimeoutSeconds 60
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ((Get-Item -LiteralPath ($log + '.stderr')).Length -ne 0) { throw "Engine stderr is not empty; run is invalid" }
$receipt = Get-Content -LiteralPath (Join-Path $output 'receipt.json') -Raw | ConvertFrom-Json
if ($receipt.failures -ne 0 -or $receipt.checks.Count -lt 103) { throw "Optical proof is incomplete or failed" }
foreach ($entry in $manifest.GetEnumerator()) {
    $actual = (Get-FileHash -LiteralPath (Join-Path $project $entry.Key) -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $entry.Value) { throw "Source changed during native proof: $($entry.Key)" }
}
[ordered]@{
    format = 1
    timestamp_utc = [DateTime]::UtcNow.ToString('o')
    engine = 'Godot 4.7.1-stable; Vulkan Forward+'
    viewport = '960x640; VSync off; 30 warm-up + 120 measured frames per configuration'
    controller_step_s = 1.0 / 120.0
    renderer_gpu = $receipt.gpu
    gpu_field_units = 'Vulkan timestamp nanoseconds divided by 1000 => microseconds'
    gpu_material_units = 'engine viewport milliseconds; matched sampling-bypass difference, signed'
    synchronization = 'No explicit sync/readback calls in measured loops; driver-internal stalls are not separately attributed'
    sources_sha256 = $manifest
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'run_manifest.json') -Encoding utf8NoBOM
Write-Output ("Validated {0} checks; zero failures; empty stderr. Evidence: {1}" -f $receipt.checks.Count, $output)
