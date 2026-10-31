# tools/lane_common.ps1
# Shared by tools/run_godot_serial.ps1, tools/run_godot_long_suite.ps1 and
# tools/lane.ps1. Dot-source it; it defines functions and changes nothing.
#
# Two things live here:
#
# 1. The lane holder record. The Godot lane is the Windows named mutex
#    Global\OrisonGodotSingleInstance. A mutex says THAT it is held, never
#    by whom, so a refused agent used to see only "73" and wait blind. The
#    runner that owns the mutex now also writes a small JSON record (pid,
#    runner, scene, worktree, start time) under %LOCALAPPDATA%\Orison, and
#    removes it when it releases. The record is advisory: the mutex stays the
#    only authority, and a record whose pid is gone is reported as stale,
#    never trusted.
#
# 2. The run receipt call. After a launched run with -LogPath, the runner
#    asks tools/run_receipt.py to write <LogPath>.receipt.json. A receipt
#    failure is reported and never changes the runner's exit code.

function Get-OrisonLaneStateDir {
    $base = $env:LOCALAPPDATA
    if ([string]::IsNullOrWhiteSpace($base)) { $base = $env:TEMP }
    $dir = Join-Path $base "Orison"
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    return $dir
}

# The queue. A broker registers a record under <state>/waiters when it starts
# waiting and only the oldest live record may take the lane, so the lane is
# first come, first served. A record is live only if its process exists and was
# already running when the record was stamped, so a dead broker or a reused pid
# can never block the queue. Ties within a second go to the lower pid.
function Get-OrisonLaneQueue {
    $waitDir = Join-Path (Get-OrisonLaneStateDir) "waiters"
    if (-not (Test-Path -LiteralPath $waitDir)) { return @() }
    $live = foreach ($file in Get-ChildItem -LiteralPath $waitDir -Filter "*.json" -ErrorAction SilentlyContinue) {
        try {
            # A departing broker may remove its record after enumeration.
            # Make that read error terminating so the existing catch skips it.
            $record = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -DateKind String
            $since = [datetime]::Parse($record.since_utc, [cultureinfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
            $process = Get-Process -Id $record.pid -ErrorAction SilentlyContinue
            if ($process -and $process.StartTime.ToUniversalTime() -le $since.AddSeconds(5)) {
                [pscustomobject]@{ pid = [int]$record.pid; since = $since; scene = $record.scene; worktree = $record.worktree }
            }
        }
        catch {}
    }
    return @($live | Sort-Object since, pid)
}

# True when someone is queued and this process is not the broker they queued
# behind. A runner started directly must not walk past the queue.
function Test-OrisonLaneQueueAhead {
    if ($env:ORISON_LANE_BROKER -eq "$PID") { return $false }
    return @(Get-OrisonLaneQueue).Count -gt 0
}

function Get-OrisonLaneHolderPath {
    return (Join-Path (Get-OrisonLaneStateDir) "lane_holder.json")
}

function Write-OrisonLaneHolder {
    param([string]$Runner, [string]$Scene, [string]$Worktree)
    try {
        $record = [ordered]@{
            pid = $PID
            runner = $Runner
            scene = $Scene
            worktree = $Worktree
            started_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        $record | ConvertTo-Json | Set-Content -LiteralPath (Get-OrisonLaneHolderPath) -Encoding utf8
    }
    catch {
        Write-Warning "lane holder record not written: $_"
    }
}

function Clear-OrisonLaneHolder {
    # Only the process that wrote the record removes it; a nested runner
    # inside tools/lane.ps1 shares the pid and simply rewrites it.
    try {
        $path = Get-OrisonLaneHolderPath
        if (Test-Path -LiteralPath $path) {
            $record = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            if ($record.pid -eq $PID) {
                Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {}
}

function Resolve-OrisonGodot {
    # A local, hash-pinned backport may repair renderer defects without replacing
    # the machine's official installation or changing another checkout's engine.
    if ($env:ORISON_GODOT_EXE) {
        return (Get-Item -LiteralPath $env:ORISON_GODOT_EXE -ErrorAction Stop).FullName
    }
    $manifestPath = Join-Path (Split-Path $PSScriptRoot -Parent) '.godot-engine.json'
    if (Test-Path -LiteralPath $manifestPath) {
        $engine = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $binary = Get-Item -LiteralPath $engine.path -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $binary.FullName -Algorithm SHA256).Hash -ne $engine.sha256) {
            throw 'Configured Godot engine hash mismatch; rebuild or restore the pinned engine.'
        }
        foreach ($entry in $engine.binaries.PSObject.Properties) {
            if ((Get-FileHash -LiteralPath $entry.Name -Algorithm SHA256).Hash -ne $entry.Value) {
                throw "Configured Godot companion binary hash mismatch: $($entry.Name)"
            }
        }
        return $binary.FullName
    }
    return (Get-Command Godot_v4.7.1-stable_win64_console.exe -ErrorAction Stop).Source
}

function Write-OrisonRunReceipt {
    param(
        [string]$LogPath,
        [string]$Scene,
        [string]$Runner,
        [string]$ProjectPath,
        $ExitCode,
        [bool]$TimedOut,
        [datetime]$StartedUtc,
        [bool]$Windowed,
        [string]$ShotDir
    )
    if ([string]::IsNullOrWhiteSpace($LogPath)) { return }
    try {
        $elapsed = [math]::Round(((Get-Date).ToUniversalTime() - $StartedUtc).TotalSeconds, 2)
        $arguments = @(
            (Join-Path $PSScriptRoot "run_receipt.py"), "write",
            "--log", $LogPath, "--scene", $Scene, "--runner", $Runner,
            "--exit", $(if ($null -eq $ExitCode) { "" } else { "$ExitCode" }),
            "--elapsed", "$elapsed",
            "--started", $StartedUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
        )
        if (-not [string]::IsNullOrWhiteSpace($ProjectPath)) { $arguments += @("--project", $ProjectPath) }
        if ($TimedOut) { $arguments += "--timed-out" }
        if ($Windowed) { $arguments += "--windowed" }
        if (-not [string]::IsNullOrWhiteSpace($ShotDir)) { $arguments += @("--shot-dir", $ShotDir) }
        & python @arguments
        if ($LASTEXITCODE -ne 0) { Write-Warning "run receipt writer exited $LASTEXITCODE" }
    }
    catch {
        Write-Warning "run receipt not written: $_"
    }
}
