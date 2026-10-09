$ErrorActionPreference = 'Continue'
$lane = 'C:/ov/envdossier/tools/lane.ps1'
$proj = 'C:/ov/envdossier/game'
$out = 'C:/ov/envdossier_out'
$scene = 'res://tests/OrisonV2EnvironmentDossierSweep.tscn'
$env:DOSSIER_SPACES = 'F01_WATCH,F02_A_BED,F02_D_RESTRICTED'
$env:DOSSIER_DETAILS = '3'
pwsh -File $lane run -Scene $scene -ProjectPath $proj -LogPath "$out/smoke3/sweep.log" -TimeoutSeconds 180 -WaitMinutes 120 -Windowed -ShotDir "$out/smoke3/shots"
$smoke = $LASTEXITCODE
"SMOKE3 exit $smoke"
Remove-Item Env:DOSSIER_SPACES -ErrorAction SilentlyContinue
if ($smoke -ne 0 -or -not (Test-Path "$out/smoke3/shots/F02_A_BED_OV.png")) { "SMOKE3 FAILED; not starting long runs"; exit 1 }
$env:DOSSIER_LEVELS = 'B1,F01,F02,F03'
pwsh -File $lane run -Scene $scene -ProjectPath $proj -LogPath "$out/run1/sweep.log" -Runner long -TimeoutSeconds 1500 -WaitMinutes 120 -Windowed -ShotDir "$out/run1/shots"
"RUN1 exit $LASTEXITCODE"
$env:DOSSIER_LEVELS = 'F04,F05,F06,ROOF'
$env:DOSSIER_CITY = '1'
pwsh -File $lane run -Scene $scene -ProjectPath $proj -LogPath "$out/run2/sweep.log" -Runner long -TimeoutSeconds 1500 -WaitMinutes 120 -Windowed -ShotDir "$out/run2/shots"
"RUN2 exit $LASTEXITCODE"
Remove-Item Env:DOSSIER_LEVELS, Env:DOSSIER_CITY, Env:DOSSIER_DETAILS -ErrorAction SilentlyContinue
