[CmdletBinding()]
param(
    [string]$Scene = "",
    [string]$ProjectPath = "",
    [string]$ShotDir = "",
    [string]$LogPath = "",
    [switch]$Windowed,
    [ValidateRange(1, 60)]
    [int]$TimeoutSeconds = 60,
    [string[]]$ExtraArgs = @()
)

# Every Orison worktree shares this Windows named mutex. A second agent fails
# closed before spawning Godot, and Windows releases ownership if the runner is
# interrupted or crashes. The process census also protects against an editor or
# an older command that did not enter through this runner.
$mutex = [System.Threading.Mutex]::new($false, "Global\OrisonGodotSingleInstance")
$ownsMutex = $false
$exitCode = 1
$process = $null
$previousShotDir = $env:SHOT_DIR

try {
    try {
        $ownsMutex = $mutex.WaitOne(0)
    }
    catch [System.Threading.AbandonedMutexException] {
        $ownsMutex = $true
    }
    if (-not $ownsMutex) {
        throw "Godot lane is owned by another Orison agent; no process was started."
    }

    $active = Get-Process -Name "Godot*" -ErrorAction SilentlyContinue
    if ($active) {
        $summary = ($active | ForEach-Object { "$($_.ProcessName):$($_.Id)" }) -join ", "
        throw "Godot is already active ($summary); no process was started."
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
        throw "Godot exceeded the $TimeoutSeconds-second ceiling and was terminated."
    }
    $exitCode = $process.ExitCode
    if ($null -eq $exitCode) {
        throw "Godot's exit code was unavailable; refusing to report success."
    }
}
catch {
    Write-Error $_
    $exitCode = 73
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
