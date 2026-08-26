[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Scene,
    [Parameter(Mandatory = $true)]
    [string]$ShotRoot,
    [Parameter(Mandatory = $true)]
    [string]$RunName,
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 200)]
    [int]$ExpectedFrames,
    [string]$ProjectPath = "",
    [ValidateRange(1, 60)]
    [int]$TimeoutSeconds = 60,
    [ValidatePattern('^\d+x\d+$')]
    [string]$Resolution = "1280x720",
    [string[]]$ExtraArgs = @(),
    [switch]$PreflightOnly
)

$ErrorActionPreference = "Stop"
$started = [DateTime]::UtcNow
$clock = [System.Diagnostics.Stopwatch]::StartNew()
$repoRoot = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = Join-Path $repoRoot "game"
}
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
$sceneRelative = $Scene
if ($sceneRelative.StartsWith("res://")) {
    $sceneRelative = $sceneRelative.Substring(6)
}
$scenePath = Join-Path $ProjectPath $sceneRelative
if (-not (Test-Path -LiteralPath $scenePath -PathType Leaf)) {
    throw "Capture scene does not exist: $scenePath"
}

if (-not [System.IO.Path]::IsPathRooted($ShotRoot)) {
    throw "ShotRoot must be absolute; relative output makes worktree evidence ambiguous."
}
$ShotRoot = [System.IO.Path]::GetFullPath($ShotRoot)
$runDir = Join-Path $ShotRoot $RunName
if (Test-Path -LiteralPath $runDir) {
    $existing = @(Get-ChildItem -LiteralPath $runDir -Force -ErrorAction Stop)
    if ($existing.Count -gt 0) {
        throw "Capture directory is not empty; refusing to overwrite evidence: $runDir"
    }
}
else {
    if (-not $PreflightOnly) {
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
    }
}

if ($PreflightOnly) {
    $active = @(Get-Process -Name "Godot*" -ErrorAction SilentlyContinue)
    $lane = if ($active.Count -eq 0) { "FREE" } else { "BUSY" }
    Write-Output "[CAPTURE PREFLIGHT] scene=$Scene expected=$ExpectedFrames resolution=$Resolution timeout=${TimeoutSeconds}s"
    Write-Output "[CAPTURE PREFLIGHT] output=$runDir overwrite=clear lane=$lane"
    if ($active.Count -gt 0) {
        Write-Output "[CAPTURE PREFLIGHT] active=$($active.ProcessName -join ',') ids=$($active.Id -join ',')"
        exit 73
    }
    exit 0
}

$safeName = $RunName -replace '[^A-Za-z0-9_.-]', '_'
$stamp = $started.ToString("yyyyMMddTHHmmssfffZ")
$logPath = Join-Path ([System.IO.Path]::GetTempPath()) "orison_capture_${safeName}_${stamp}.log"
$serial = Join-Path $PSScriptRoot "run_godot_serial.ps1"
$engineArgs = @("--audio-driver", "Dummy", "--resolution", $Resolution)
$engineArgs += $ExtraArgs

# There is deliberately no retry loop. Exit 73 means the lane is occupied or
# the ceiling fired. Retrying in a shell hides contention and can starve the
# other owner for minutes.
$runnerArgs = @{
    Scene = $Scene
    ProjectPath = $ProjectPath
    ShotDir = $runDir
    LogPath = $logPath
    Windowed = $true
    TimeoutSeconds = $TimeoutSeconds
    ExtraArgs = $engineArgs
}
$previousErrorPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$runnerOutput = @(& $serial @runnerArgs 2>&1 | ForEach-Object { "$_" })
$engineExit = $LASTEXITCODE
$ErrorActionPreference = $previousErrorPreference
$clock.Stop()

$stdout = @()
$stderr = @()
if (Test-Path -LiteralPath $logPath) {
    $stdout = @(Get-Content -LiteralPath $logPath)
}
if (Test-Path -LiteralPath "$logPath.stderr") {
    $stderr = @(Get-Content -LiteralPath "$logPath.stderr")
}
$filter = 'RESULT:|PASS|FAIL|capture|captured|parse error|SCRIPT ERROR|timeout|exceeded|lane is owned|already active'
$filtered = @($runnerOutput + $stdout + $stderr | Where-Object { $_ -match $filter })
$pngs = @(Get-ChildItem -LiteralPath $runDir -Filter *.png -File -ErrorAction SilentlyContinue | Sort-Object Name)
$files = @($pngs | ForEach-Object {
    [ordered]@{
        name = $_.Name
        bytes = $_.Length
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
})
$zeroByte = @($pngs | Where-Object { $_.Length -eq 0 }).Count
$pass = $engineExit -eq 0 -and $pngs.Count -eq $ExpectedFrames -and $zeroByte -eq 0
$status = if ($engineExit -eq 73) { "BUSY_OR_TIMEOUT" } elseif ($pass) { "PASS" } else { "FAIL" }
$receipt = [ordered]@{
    schema_version = 1
    status = $status
    scene = $Scene
    project_path = $ProjectPath
    run_directory = $runDir
    started_utc = $started.ToString("o")
    elapsed_seconds = [Math]::Round($clock.Elapsed.TotalSeconds, 3)
    timeout_seconds = $TimeoutSeconds
    resolution = $Resolution
    engine_exit = $engineExit
    expected_frames = $ExpectedFrames
    actual_frames = $pngs.Count
    zero_byte_frames = $zeroByte
    temp_log = $logPath
    filtered_process_output = $filtered
    files = $files
}
$receiptPath = Join-Path $runDir "capture_receipt.json"
$receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $receiptPath -Encoding utf8

Write-Output "[CAPTURE PROCESS] status=$status exit=$engineExit elapsed=$($receipt.elapsed_seconds)s frames=$($pngs.Count)/$ExpectedFrames"
foreach ($line in $filtered) {
    Write-Output $line
}
Write-Output "[CAPTURE RECEIPT] $receiptPath"
if (-not $pass) {
    exit $(if ($engineExit -ne 0) { $engineExit } else { 2 })
}
exit 0
