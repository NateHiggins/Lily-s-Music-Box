<#
.SYNOPSIS
    Runs one Godot scene, one process at a time, and reports honestly.

.DESCRIPTION
    EXIT CODES. Every one of these used to be 73, which made a suite that
    merely needed more time indistinguishable from a scheduling conflict:
    the honest reading of a red 73 was "wait and retry", and for a slow
    suite that retry could never succeed.

      0        the suite ran to completion and passed
      <n>      the suite ran to completion and reported n failures
      73       LANE BUSY - refused before starting anything. Either the
               shared mutex is held by another Orison agent, or the
               process census found a Godot already running (an editor or
               Project Manager window counts). Nothing was launched, no
               log was written. Waiting and retrying is the correct
               response. Unchanged, because tools/run_godot_capture.ps1
               already exits 73 from its own preflight lane check.
      124      TIMEOUT KILL - the scene was launched and was still alive
               at -TimeoutSeconds, so the runner terminated it. Retrying
               unchanged will produce the same result: either raise the
               ceiling for a suite that is legitimately this expensive,
               or diagnose a hang. 124 is the GNU `timeout` convention.
               A partial log survives at -LogPath.
      78       CANNOT RUN - the runner could not start the suite at all
               (Godot executable not on PATH, unresolvable project path,
               or an exit code Windows would not surrender). This is a
               broken environment, not a busy one; retrying will not fix
               it. 78 is sysexits EX_CONFIG.

    -TimeoutSeconds accepts 1..180 and still DEFAULTS to 60, so a caller
    that needs longer has to say so deliberately. The old 60-second
    ceiling could not express two committed suites:
    orison_v2_two_root_matrix builds both building roots plus eight
    CampaignShell reconstructions (measured 76.3s), and
    orison_v2_m08e_spatial walks a ~100-waypoint collision route
    (measured 80.5s). Both were killed at 60 and reported as lane
    conflicts. 180 is 2.2x the slowest of the fourteen committed v2 and
    Open Shift suites, which leaves room for a cold cache or a loaded
    machine while still capping a genuine hang at three minutes; the
    full timing table is in
    design/ORISON_RUNNER_EXIT_TRUTH_2026-08-29.md. Raising this bound
    again should come with new measurements, not with taste. The ceiling
    still kills: this change makes the report truthful, not the patience
    infinite.

    Always pass -LogPath. Without it the child inherits the console and a
    calling script's redirection captures nothing; stderr lands beside it
    at <LogPath>.stderr.
#>
[CmdletBinding()]
param(
    [string]$Scene = "",
    [string]$ProjectPath = "",
    [string]$ShotDir = "",
    [string]$LogPath = "",
    [switch]$Windowed,
    [ValidateRange(1, 180)]
    [int]$TimeoutSeconds = 60,
    [string[]]$ExtraArgs = @()
)

# Exit codes that describe the RUNNER's own refusal, never the suite's
# verdict. Kept as named constants so the catch block cannot quietly
# collapse them back into one number.
$EXIT_LANE_BUSY = 73
$EXIT_TIMEOUT = 124
$EXIT_CANNOT_RUN = 78

# Every Orison worktree shares this Windows named mutex. A second agent fails
# closed before spawning Godot, and Windows releases ownership if the runner is
# interrupted or crashes. The process census also protects against an editor or
# an older command that did not enter through this runner.
$mutex = [System.Threading.Mutex]::new($false, "Global\OrisonGodotSingleInstance")
$ownsMutex = $false
$exitCode = 1
$process = $null
$previousShotDir = $env:SHOT_DIR
# Which refusal the catch block is reporting. Every throw below sets this
# first; anything that throws without setting it is by definition an
# environment the runner could not run in.
$refusalCode = $EXIT_CANNOT_RUN

try {
    try {
        $ownsMutex = $mutex.WaitOne(0)
    }
    catch [System.Threading.AbandonedMutexException] {
        $ownsMutex = $true
    }
    if (-not $ownsMutex) {
        $refusalCode = $EXIT_LANE_BUSY
        throw "LANE BUSY: the Godot lane is owned by another Orison agent (shared mutex held); no process was started. Wait and retry."
    }

    $active = Get-Process -Name "Godot*" -ErrorAction SilentlyContinue
    if ($active) {
        $summary = ($active | ForEach-Object { "$($_.ProcessName):$($_.Id)$(if ($_.MainWindowTitle) { " '$($_.MainWindowTitle)'" })" }) -join ", "
        $refusalCode = $EXIT_LANE_BUSY
        throw "LANE BUSY: Godot is already active ($summary); no process was started. Wait and retry, or close that window if it is an idle editor."
    }

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        $ProjectPath = Join-Path (Split-Path $PSScriptRoot -Parent) "game"
    }
    $ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
    $godot = (Get-Command Godot_v4.7.1-stable_win64_console.exe -ErrorAction Stop).Source
    $arguments = @()
    if (-not $Windowed) {
        $arguments += "--headless"
    }
    $arguments += @("--path", $ProjectPath)
    $arguments += $ExtraArgs
    if (-not [string]::IsNullOrWhiteSpace($Scene)) {
        $arguments += $Scene
    }

    if (-not [string]::IsNullOrWhiteSpace($ShotDir)) {
        $env:SHOT_DIR = $ShotDir
    }
    $start = @{
        FilePath = $godot
        ArgumentList = $arguments
        NoNewWindow = $true
        PassThru = $true
    }
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        $logParent = Split-Path -Parent $LogPath
        if (-not [string]::IsNullOrWhiteSpace($logParent)) {
            New-Item -ItemType Directory -Force -Path $logParent | Out-Null
        }
        # Start-Process requires distinct files. The caller can filter both;
        # keeping stderr separate also preserves which channel diagnosed a
        # parse failure or timeout.
        $start.RedirectStandardOutput = $LogPath
        $start.RedirectStandardError = "$LogPath.stderr"
    }
    $process = Start-Process @start
    # Windows PowerShell 5.1 never populates ExitCode on a -PassThru process
    # unless its handle was touched before the wait; `exit $null` then reports
    # success for every failing suite. Cache the handle first.
    $null = $process.Handle
    $env:SHOT_DIR = $previousShotDir

    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        $sceneLabel = if ([string]::IsNullOrWhiteSpace($Scene)) {
            "the project's main scene"
        } else { $Scene }
        $refusalCode = $EXIT_TIMEOUT
        # Name the scene, the ceiling, and who ended the run. The suite did
        # not fail and did not report anything: the runner stopped it.
        throw ("TIMEOUT: '$sceneLabel' was still running at the " +
               "$TimeoutSeconds-second ceiling and was terminated by the " +
               "runner. The ceiling ended this run, not the suite - it " +
               "reported no verdict. Re-run with a higher " +
               "-TimeoutSeconds if the suite is legitimately this " +
               "expensive, or diagnose a hang." +
               $(if ([string]::IsNullOrWhiteSpace($LogPath)) {
                   " No -LogPath was given, so no partial log survives."
               } else { " Partial log: $LogPath" }))
    }
    $exitCode = $process.ExitCode
    if ($null -eq $exitCode) {
        $refusalCode = $EXIT_CANNOT_RUN
        throw "CANNOT RUN: Godot's exit code was unavailable; refusing to report success."
    }
}
catch {
    Write-Error $_
    $exitCode = $refusalCode
}
finally {
    $env:SHOT_DIR = $previousShotDir
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
    if ($ownsMutex) {
        $mutex.ReleaseMutex()
    }
    $mutex.Dispose()
}

exit $exitCode
