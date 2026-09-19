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
