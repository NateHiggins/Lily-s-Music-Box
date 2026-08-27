[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReceiptPath,
    [string[]]$Station = @(),
    [switch]$AllowDirty,
    [ValidatePattern('^\d+x\d+$')]
    [string]$Resolution = "2560x1440",
    [ValidateRange(1, 60)]
    [int]$TimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
$probePath = Join-Path $repoRoot "game\tests\perf_probe.gd"
$runnerPath = Join-Path $PSScriptRoot "run_godot_serial.ps1"
$projectPath = Join-Path $repoRoot "game"

if (-not (Test-Path -LiteralPath $probePath -PathType Leaf)) {
    throw "Performance owner is missing: $probePath"
}
if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
    throw "Serialized Godot runner is missing: $runnerPath"
}

# Discover names and class from the canonical GDScript table. Copying the
# station list here would let the second-machine receipt silently omit a newly
# added release camera.
$probe = Get-Content -LiteralPath $probePath -Raw
$stationBlock = [regex]::Match($probe,
    '(?s)const STATIONS := \[(.*?)\]\r?\n\r?\n##').Groups[1].Value
if ([string]::IsNullOrWhiteSpace($stationBlock)) {
    throw "Could not read STATIONS from $probePath"
}
$stations = @()
foreach ($record in [regex]::Matches($stationBlock, '(?s)\{(.*?)\}')) {
    $nameMatch = [regex]::Match($record.Groups[1].Value, '"name"\s*:\s*"([^"]+)"')
    if (-not $nameMatch.Success) { continue }
    $name = $nameMatch.Groups[1].Value
    $stations += [pscustomobject]@{
        name = $name
        class = if ($record.Groups[1].Value -match
            '"player_at_lens"\s*:\s*false') { "composition" } else { "playable" }
    }
}
if ($stations.Count -lt 1) {
    throw "No performance stations were discovered"
}
if ($Station.Count -gt 0) {
    $unknown = @($Station | Where-Object { $_ -notin $stations.name })
    if ($unknown.Count -gt 0) {
        throw "Unknown station(s): $($unknown -join ', ')"
    }
    $stations = @($stations | Where-Object { $_.name -in $Station })
}

$receiptParent = Split-Path -Parent $ReceiptPath
if (-not [string]::IsNullOrWhiteSpace($receiptParent)) {
    New-Item -ItemType Directory -Force -Path $receiptParent | Out-Null
}
$receiptPathAbsolute = [System.IO.Path]::GetFullPath($ReceiptPath)
$sha = (& git -C $repoRoot rev-parse HEAD).Trim()
$dirty = -not [string]::IsNullOrWhiteSpace(
    ((& git -C $repoRoot status --porcelain=v1) -join "`n"))
if ($dirty -and -not $AllowDirty) {
    throw "Release performance evidence requires a clean checkout. " +
        "Use -AllowDirty only for a development smoke run; its receipt is inadmissible."
}
$gpu = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
    ForEach-Object { $_.Name })
$cpu = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty Name)
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$width, $height = $Resolution.Split('x')
$results = @()
$failed = 0

Write-Output "PERF MATRIX process=serialized stations=$($stations.Count) resolution=$Resolution"
foreach ($spec in $stations) {
    $safe = $spec.name -replace '[^a-zA-Z0-9]', '_'
    $log = Join-Path ([System.IO.Path]::GetTempPath()) "orison_perf_matrix_$safe.log"
    $oldStation = $env:PERF_STATION
    try {
        $env:PERF_STATION = $spec.name
        & $runnerPath -Windowed -Scene "res://tests/Perf.tscn" `
            -ProjectPath $projectPath -LogPath $log `
            -TimeoutSeconds $TimeoutSeconds `
            -ExtraArgs @('--resolution', $Resolution, '--position', '-32000,-32000')
        $exitCode = $LASTEXITCODE
    }
    finally {
        $env:PERF_STATION = $oldStation
    }
    $stdout = if (Test-Path -LiteralPath $log) {
        Get-Content -LiteralPath $log
    } else { @() }
    $stderrPath = "$log.stderr"
    $stderr = if (Test-Path -LiteralPath $stderrPath) {
        Get-Content -LiteralPath $stderrPath
    } else { @() }
    $row = @($stdout | Where-Object {
        $_ -match ('^' + [regex]::Escape($spec.name) + '\s+\d+')
    } | Select-Object -Last 1)
    $verdict = @($stdout | Where-Object { $_ -match '^PERF RESULT:' } |
        Select-Object -Last 1)
    $errors = @(($stdout + $stderr) | Where-Object {
        $_ -match '(?i)parse error|script error|timeout|exceeded'
    })
    $valid = $row.Count -eq 1 -and $verdict.Count -eq 1 -and $errors.Count -eq 0
    $passed = $exitCode -eq 0 -and $valid
    if (-not $passed) { $failed += 1 }
    Write-Output ("PERF MATRIX {0} class={1} exit={2} valid={3}" -f
        $spec.name, $spec.class, $exitCode, $valid)
    if ($row.Count -eq 1) { Write-Output $row[0] }
    if ($verdict.Count -eq 1) { Write-Output $verdict[0] }
    foreach ($errorLine in $errors) { Write-Output "PERF MATRIX ERROR $errorLine" }
    $results += [pscustomobject]@{
        station = $spec.name
        class = $spec.class
        exit_code = $exitCode
        valid = $valid
        passed = $passed
        measurement = if ($row.Count -eq 1) { $row[0] } else { $null }
        verdict = if ($verdict.Count -eq 1) { $verdict[0] } else { $null }
        errors = $errors
    }
    Remove-Item -LiteralPath $log, $stderrPath -ErrorAction SilentlyContinue
}

$receipt = [ordered]@{
    schema = "orison.release-performance-matrix.v1"
    captured_utc = [DateTime]::UtcNow.ToString("o")
    commit = $sha
    dirty_worktree = $dirty
    evidence_admissible = (-not $dirty -and $failed -eq 0)
    resolution = $Resolution
    timeout_seconds_per_station = $TimeoutSeconds
    machine = [ordered]@{
        computer_name = $env:COMPUTERNAME
        operating_system = if ($os) { $os.Caption } else { $null }
        os_version = if ($os) { $os.Version } else { $null }
        cpu = $cpu
        gpu = $gpu
        memory_bytes = if ($os) { [int64]$os.TotalVisibleMemorySize * 1KB } else { $null }
    }
    result = if ($failed -eq 0) { "PASS" } else { "FAIL" }
    failed_stations = $failed
    stations = $results
}
$receipt | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $receiptPathAbsolute `
    -Encoding UTF8
Write-Output "PERF MATRIX RESULT $($receipt.result) $($stations.Count - $failed)/$($stations.Count)"
Write-Output "PERF MATRIX RECEIPT $receiptPathAbsolute"
exit $(if ($failed -eq 0) { 0 } else { 1 })
