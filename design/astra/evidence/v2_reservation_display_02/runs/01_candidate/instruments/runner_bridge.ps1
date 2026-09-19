[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$InvocationPath)

$ErrorActionPreference = 'Stop'
$invocation = Get-Content -LiteralPath $InvocationPath -Raw | ConvertFrom-Json -AsHashtable
$runnerPath = [string]$invocation.runner
if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
    throw "The requested runner script does not exist: $runnerPath"
}
$parameters = $invocation.parameters
if ($parameters -isnot [System.Collections.IDictionary]) {
    throw 'Runner parameters must be a structured dictionary.'
}
# ExtraArgs remains a real array, including strings beginning with a dash.
# Continue is narrowly scoped to the unchanged runner's own error/exit contract.
$ErrorActionPreference = 'Continue'
& $runnerPath @parameters
$observedExit = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($null -eq $observedExit) {
    throw 'The runner supplied no process exit code.'
}
exit [int]$observedExit
