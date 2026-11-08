$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath 'C:/PleaseRemainOnTheLine'
& 'C:/Users/nate_/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe' -NoProfile -File tools/lane.ps1 batch -BatchFile 'C:/ov/reports/native_intake_20261102/qualification_debt_trace_01/runtime_14/batch.json' -WaitMinutes 240
exit $LASTEXITCODE
