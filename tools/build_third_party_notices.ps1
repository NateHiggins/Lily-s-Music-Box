[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
$oflPath = Join-Path $repoRoot "game\assets\fonts\courier_prime\OFL.txt"
$soundPath = Join-Path $repoRoot "game\assets\audio\freesound\ATTRIBUTION.md"
foreach ($required in @($oflPath, $soundPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required third-party notice source is absent: $required"
    }
}

$utf8 = [Text.UTF8Encoding]::new($false)
$ofl = [IO.File]::ReadAllText($oflPath, $utf8)
$sound = [IO.File]::ReadAllText($soundPath, $utf8)
if ($ofl -notmatch "SIL OPEN FONT LICENSE Version 1.1" -or
        $ofl -notmatch "Copyright 2015 The Courier Prime Project Authors") {
    throw "Courier Prime notice source does not contain its expected copyright and OFL text."
}
if ($sound -notmatch "CC BY 4.0" -or $sound -notmatch "CC0") {
    throw "Freesound attribution source does not contain both expected licence families."
}

$parent = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}

$sections = @(
    @"
PLEASE REMAIN ON THE LINE - THIRD-PARTY NOTICES

These notices cover third-party components distributed with the game. They do
not state or change the licence for the game's original work.

==========================================================================
GODOT ENGINE
==========================================================================

Godot Engine is distributed under the MIT License.
Copyright (c) 2007-present Juan Linietsky, Ariel Manzur, Godot Engine contributors.
Official licence and bundled-component notices: https://godotengine.org/license/
"@.TrimEnd(),
    @"
==========================================================================
COURIER PRIME
==========================================================================

$($ofl.TrimEnd())
"@.TrimEnd(),
    @"
==========================================================================
FREESOUND SOURCES
==========================================================================

$($sound.TrimEnd())
"@.TrimEnd()
)

$text = ($sections -join ([Environment]::NewLine + [Environment]::NewLine)) +
    [Environment]::NewLine
[IO.File]::WriteAllText($OutputPath, $text, $utf8)

$written = Get-Content -LiteralPath $OutputPath -Raw
foreach ($requiredText in @(
        "https://godotengine.org/license/",
        "Copyright 2015 The Courier Prime Project Authors",
        "SIL OPEN FONT LICENSE Version 1.1",
        "CC BY 4.0",
        "CC0")) {
    if (-not $written.Contains($requiredText)) {
        throw "Generated notices lost required text: $requiredText"
    }
}

Write-Output "THIRD-PARTY NOTICES PASS"
Write-Output "output=$OutputPath"
