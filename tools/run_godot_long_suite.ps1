# tools/run_godot_long_suite.ps1
# Committed launcher for the ONE suite that legitimately exceeds
# tools/run_godot_serial.ps1's 180-second ceiling: the M11C2 production matrix
# (four complete production cycles, four CampaignShell reconstructions and two
# collision-bearing routes; about 15 minutes). It reproduces the serial
# runner's lane contract exactly - the same Global\OrisonGodotSingleInstance
# mutex, the same Godot process census, headless launch, separate
# stdout/stderr logs, exit 73 lane busy / 124 timeout kill / suite exit code
# otherwise - with a 1,500-second default ceiling. Used for the M11C2 close on
# 2026-09-13:
#   pwsh -File tools/run_godot_long_suite.ps1 `
#        -Scene res://tests/orison_v2_m11c2_production_matrix.tscn `
#        -ProjectPath game `
#        -LogPath art/renders/orison_v2/m11c2_floor01_production_cut_01/runtime/m11c2_production_matrix_stdout.log
# with M11C2_MATRIX_RECEIPT set to the packet's runtime receipt path.
# Do not use it to stretch a suite that the serial runner can already run.
# Writes <LogPath>.receipt.json after a launched run (tools/run_receipt.py)
# and the advisory lane holder record (tools/lane_common.ps1).
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Scene,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [Parameter(Mandatory = $true)][string]$LogPath,
    [int]$TimeoutSeconds = 1500
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lane_common.ps1")
$mutex = [System.Threading.Mutex]::new($false, "Global\OrisonGodotSingleInstance")
$owns = $false
$exitCode = 1
$process = $null
$timedOut = $false
$launchedExit = $null
$startedUtc = $null
try {
    try { $owns = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $owns = $true }
    if (-not $owns) { throw [System.InvalidOperationException]::new("LANE BUSY (mutex)") }
    $active = Get-Process -Name "Godot*" -ErrorAction SilentlyContinue
    if ($active) {
        $summary = ($active | ForEach-Object { "$($_.ProcessName):$($_.Id)" }) -join ", "
        throw [System.InvalidOperationException]::new("LANE BUSY: Godot already active ($summary)")
    }
    Write-OrisonLaneHolder -Runner "long" -Scene $Scene -Worktree (Split-Path $PSScriptRoot -Parent)
    $ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
    $godot = (Get-Command Godot_v4.7.1-stable_win64_console.exe -ErrorAction Stop).Source
    $logParent = Split-Path -Parent $LogPath
    if ($logParent) { New-Item -ItemType Directory -Force -Path $logParent | Out-Null }
    Remove-Item -LiteralPath "$LogPath.receipt.json" -Force -ErrorAction SilentlyContinue
    $started = Get-Date
    $startedUtc = $started.ToUniversalTime()
    $process = Start-Process -FilePath $godot -ArgumentList @("--headless", "--path", $ProjectPath, $Scene) `
        -NoNewWindow -PassThru -RedirectStandardOutput $LogPath -RedirectStandardError "$LogPath.stderr"
    $null = $process.Handle
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try { $process.Kill($true) } catch {}
        $timedOut = $true
        Write-Error "TIMEOUT KILL after $TimeoutSeconds s" -ErrorAction Continue
        $exitCode = 124
    }
    else {
        $process.WaitForExit()
        $exitCode = $process.ExitCode
        $launchedExit = $exitCode
        $elapsed = [int]((Get-Date) - $started).TotalSeconds
        Write-Output "[LONG RUNNER] scene=$Scene exit=$exitCode elapsed_s=$elapsed ceiling_s=$TimeoutSeconds"
    }
}
catch [System.InvalidOperationException] {
    Write-Error $_.Exception.Message -ErrorAction Continue
    $exitCode = 73
}
finally {
    if ($process -and $startedUtc) {
        Write-OrisonRunReceipt -LogPath $LogPath -Scene $Scene -Runner "long" `
            -ProjectPath $ProjectPath -ExitCode $launchedExit -TimedOut $timedOut `
            -StartedUtc $startedUtc -Windowed $false -ShotDir ""
    }
    if ($owns) {
        Clear-OrisonLaneHolder
        try { $mutex.ReleaseMutex() } catch {}
    }
    $mutex.Dispose()
}
exit $exitCode
