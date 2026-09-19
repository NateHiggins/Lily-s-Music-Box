# tools/lane.ps1
# The Godot lane broker: see who holds the lane, wait for it instead of
# failing, and run several scenes under one acquisition.
#
#   pwsh -File tools/lane.ps1 status
#   pwsh -File tools/lane.ps1 run -Scene res://tests/X.tscn -LogPath <log> [-Runner serial|long]
#        [-WaitMinutes 30] [-TimeoutSeconds N] [-ExtraArgs @(...)] [-Windowed] [-ShotDir <dir>]
#   pwsh -File tools/lane.ps1 batch -BatchFile <runs.json> [-WaitMinutes 30] [-ContinueOnFailure]
#
# The lane is and stays the Windows named mutex
# Global\OrisonGodotSingleInstance plus the Godot process census. This broker
# never bypasses either: it WAITS for both to be free, takes the mutex, and
# then calls the ordinary runners in its own thread. A Windows mutex is
# re-entrant for the thread that owns it, so the runner's own WaitOne(0)
# succeeds for this caller and fails for everyone else, and the lane is held
# across a whole batch instead of being released and raced for between
# scenes. Every run still goes through the runner, so every run still gets
# its log, its exit-code contract and its receipt.
#
# Waiting agents register a small record under %LOCALAPPDATA%\Orison\waiters
# so `status` can say who is queued. There is no priority and no pre-emption:
# the first waiter to find the lane free takes it.
#
# Batch file: a JSON array of objects
#   {"scene": "res://tests/X.tscn", "log": "C:/.../x.log",
#    "runner": "serial"|"long", "timeout": 120, "extra_args": ["--import"],
#    "windowed": false, "shot_dir": ""}
# "scene" may be empty for an import run.
#
# Exit codes: run returns the runner's exit code; batch returns 0 if every
# run exited 0, else the first non-zero exit; 73 if the lane was not free
# within -WaitMinutes; 64 usage error.
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet("status", "run", "batch")]
    [string]$Command,
    [string]$Scene = "",
    [string]$ProjectPath = "",
    [string]$LogPath = "",
    [ValidateSet("serial", "long")]
    [string]$Runner = "serial",
    [int]$TimeoutSeconds = 0,
    [string[]]$ExtraArgs = @(),
    [switch]$Windowed,
    [string]$ShotDir = "",
    [string]$BatchFile = "",
    [double]$WaitMinutes = 30,
    [switch]$ContinueOnFailure,
    [switch]$Json
)

. (Join-Path $PSScriptRoot "lane_common.ps1")
$MUTEX_NAME = "Global\OrisonGodotSingleInstance"
$EXIT_LANE_BUSY = 73
$EXIT_USAGE = 64

function Get-GodotProcesses {
    $procs = @(Get-Process -Name "Godot*" -ErrorAction SilentlyContinue)
    foreach ($p in $procs) {
        $cmd = $null
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId = $($p.Id)" -ErrorAction Stop).CommandLine
        } catch {}
        $started = $null
        try { $started = $p.StartTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") } catch {}
        [ordered]@{
            pid = $p.Id
            name = $p.ProcessName
            window = $p.MainWindowTitle
            started_utc = $started
            editor = [bool]($cmd -and ($cmd -match '(^|\s)(-e|--editor)(\s|$)' -or -not ($cmd -match '\.tscn|--import|--script')))
            command_line = $cmd
        }
    }
}

function Get-LaneRecord {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $record = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -DateKind String
        $alive = $null -ne (Get-Process -Id $record.pid -ErrorAction SilentlyContinue)
        $record | Add-Member -NotePropertyName alive -NotePropertyValue $alive -Force
        return $record
    }
    catch { return $null }
}

function Test-MutexFree {
    # Probe without holding: take it if free and release at once. An
    # abandoned mutex counts as free (its owner died); the probe clears it.
    $m = [System.Threading.Mutex]::new($false, $MUTEX_NAME)
    try {
        $owned = $false
        try { $owned = $m.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $owned = $true }
        if ($owned) { $m.ReleaseMutex() }
        return $owned
    }
    finally { $m.Dispose() }
}

function Get-LaneStatus {
    $dir = Get-OrisonLaneStateDir
    $waitDir = Join-Path $dir "waiters"
    $waiters = @()
    if (Test-Path -LiteralPath $waitDir) {
        foreach ($f in Get-ChildItem -LiteralPath $waitDir -Filter *.json) {
            $w = Get-LaneRecord -Path $f.FullName
            if ($w) { $waiters += $w }
        }
    }
    $holder = Get-LaneRecord -Path (Get-OrisonLaneHolderPath)
    $godot = @(Get-GodotProcesses)
    $mutexFree = Test-MutexFree
    [ordered]@{
        lane_free = ($mutexFree -and $godot.Count -eq 0)
        mutex_free = $mutexFree
        holder = $holder
        holder_note = if ($holder -and -not $holder.alive) { "stale record: that process is gone" }
                      elseif (-not $mutexFree -and -not $holder) { "mutex held by a process that predates holder records, or by another tool" }
                      else { $null }
        godot_processes = $godot
        waiters = $waiters
    }
}

function Write-LaneStatus {
    param($Status)
    if ($Json) { $Status | ConvertTo-Json -Depth 5; return }
    "lane: " + $(if ($Status.lane_free) { "FREE" } else { "BUSY" })
    "  mutex: " + $(if ($Status.mutex_free) { "free" } else { "held" })
    if ($Status.holder) {
        $h = $Status.holder
        "  holder: pid $($h.pid) ($($h.runner)) scene '$($h.scene)' since $($h.started_utc) from $($h.worktree)" +
            $(if (-not $h.alive) { " [STALE: process gone]" } else { "" })
    }
    if ($Status.holder_note) { "  note: $($Status.holder_note)" }
    foreach ($g in $Status.godot_processes) {
        "  godot: pid $($g.pid) $($g.name)" + $(if ($g.editor) { " [editor]" } else { "" }) +
            $(if ($g.window) { " '$($g.window)'" } else { "" }) + " since $($g.started_utc)"
        if ($g.command_line) { "         $($g.command_line)" }
    }
    foreach ($w in $Status.waiters) {
        "  waiting: pid $($w.pid) for '$($w.scene)' since $($w.since_utc)" + $(if (-not $w.alive) { " [STALE]" } else { "" })
    }
}

function Wait-ForLane {
    # Returns an owned Mutex, or $null if the deadline passed. Ownership
    # requires BOTH the mutex and an empty Godot census, exactly as the
    # runners require; the mutex is released again while Godot is still
    # running elsewhere so a waiting broker never blocks the lane itself.
    param([double]$Minutes, [string]$What)
    $deadline = (Get-Date).AddMinutes($Minutes)
    $waitDir = Join-Path (Get-OrisonLaneStateDir) "waiters"
    New-Item -ItemType Directory -Force -Path $waitDir | Out-Null
    $waitFile = Join-Path $waitDir "$PID.json"
    [ordered]@{ pid = $PID; scene = $What; worktree = (Split-Path $PSScriptRoot -Parent)
                since_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") } |
        ConvertTo-Json | Set-Content -LiteralPath $waitFile -Encoding utf8
    $announced = $false
    try {
        while ($true) {
            $m = [System.Threading.Mutex]::new($false, $MUTEX_NAME)
            $owned = $false
            $remaining = [int][math]::Max(0, ($deadline - (Get-Date)).TotalMilliseconds)
            try { $owned = $m.WaitOne([math]::Min($remaining, 15000)) }
            catch [System.Threading.AbandonedMutexException] { $owned = $true }
            if ($owned) {
                if (@(Get-Process -Name "Godot*" -ErrorAction SilentlyContinue).Count -eq 0) {
                    return $m
                }
                $m.ReleaseMutex()
            }
            $m.Dispose()
            if ((Get-Date) -ge $deadline) { return $null }
            if (-not $announced) {
                Write-Host "[LANE] busy; waiting up to $Minutes min for '$What'"
                Write-LaneStatus (Get-LaneStatus) | ForEach-Object { Write-Host $_ }
                $announced = $true
            }
            Start-Sleep -Seconds 5
        }
    }
    finally {
        Remove-Item -LiteralPath $waitFile -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-OneRun {
    param([hashtable]$Spec)
    $runnerName = if ($Spec.runner) { $Spec.runner } else { "serial" }
    $script = Join-Path $PSScriptRoot $(if ($runnerName -eq "long") { "run_godot_long_suite.ps1" } else { "run_godot_serial.ps1" })
    $project = if ($Spec.project) { $Spec.project } elseif ($ProjectPath) { $ProjectPath } else { Join-Path (Split-Path $PSScriptRoot -Parent) "game" }
    $params = @{ ProjectPath = $project; LogPath = $Spec.log }
    if ($Spec.scene) { $params.Scene = $Spec.scene }
    if ($Spec.timeout) { $params.TimeoutSeconds = [int]$Spec.timeout }
    if ($Spec.windowed) { $params.Windowed = $true }
    if ($Spec.shot_dir) { $params.ShotDir = $Spec.shot_dir }
    if ($runnerName -eq "serial") {
        if ($Spec.extra_args) { $params.ExtraArgs = [string[]]$Spec.extra_args }
    }
    elseif (-not $Spec.scene) {
        throw "the long runner needs a scene"
    }
    Write-OrisonLaneHolder -Runner "lane/$runnerName" -Scene $Spec.scene -Worktree (Split-Path $PSScriptRoot -Parent)
    & $script @params | Out-Host
    return $LASTEXITCODE
}

switch ($Command) {
    "status" {
        Write-LaneStatus (Get-LaneStatus)
        exit 0
    }
    "run" {
        if (-not $LogPath) { Write-Error "run needs -LogPath (receipts are written beside it)"; exit $EXIT_USAGE }
        $runs = @(@{ scene = $Scene; log = $LogPath; runner = $Runner; timeout = $TimeoutSeconds
                     extra_args = $ExtraArgs; windowed = [bool]$Windowed; shot_dir = $ShotDir })
    }
    "batch" {
        if (-not $BatchFile -or -not (Test-Path -LiteralPath $BatchFile)) {
            Write-Error "batch needs -BatchFile <runs.json>"; exit $EXIT_USAGE
        }
        $runs = @()
        foreach ($item in (Get-Content -LiteralPath $BatchFile -Raw | ConvertFrom-Json)) {
            $h = @{}
            foreach ($prop in $item.PSObject.Properties) { $h[$prop.Name] = $prop.Value }
            if (-not $h.log) { Write-Error "every batch entry needs a log"; exit $EXIT_USAGE }
            $runs += $h
        }
    }
}

$label = if ($runs.Count -eq 1) { $runs[0].scene } else { "$($runs.Count) runs" }
$mutex = Wait-ForLane -Minutes $WaitMinutes -What $label
if ($null -eq $mutex) {
    Write-Error "LANE BUSY: not free within $WaitMinutes min; nothing was started."
    Write-LaneStatus (Get-LaneStatus) | ForEach-Object { Write-Host $_ }
    exit $EXIT_LANE_BUSY
}
$final = 0
$results = @()
try {
    foreach ($spec in $runs) {
        $code = Invoke-OneRun -Spec $spec
        $results += [ordered]@{ scene = $spec.scene; log = $spec.log; exit = $code }
        Write-Host "[LANE] $($spec.scene) exit=$code"
        if ($code -ne 0 -and $final -eq 0) { $final = $code }
        if ($code -ne 0 -and -not $ContinueOnFailure) { break }
    }
}
finally {
    Clear-OrisonLaneHolder
    try { $mutex.ReleaseMutex() } catch {}
    $mutex.Dispose()
}
if ($Json) { $results | ConvertTo-Json -Depth 3 }
exit $final
