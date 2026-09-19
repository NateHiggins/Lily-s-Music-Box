[CmdletBinding()]
param(
    [string]$ProjectPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'game'),
    [int]$TimeoutSeconds = 1500
)
# Uses the shared lane; closing the native window ends the inspection run.
$ErrorActionPreference = 'Stop'
$logRoot = Join-Path $env:LOCALAPPDATA ('Orison/ecology-debug/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$runs = @(
    @{scene=''; project=$ProjectPath; log=(Join-Path $logRoot 'import1.log'); runner='serial'; timeout=180; extra_args=@('--import')},
    @{scene=''; project=$ProjectPath; log=(Join-Path $logRoot 'import2.log'); runner='serial'; timeout=180; extra_args=@('--import')},
    @{scene='res://scenes/debug/DreamEcologyWarehouseDebug.tscn'; project=$ProjectPath; log=(Join-Path $logRoot 'inspection.log'); runner='long'; timeout=$TimeoutSeconds; windowed=$true}
)
$batchPath = Join-Path $logRoot 'batch.json'
$runs | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $batchPath -Encoding utf8
Write-Output "Dream ecology inspection: close the window or press Escape to finish. Logs: $logRoot"
& (Join-Path $PSScriptRoot 'lane.ps1') batch -BatchFile $batchPath -WaitMinutes 30
exit $LASTEXITCODE
