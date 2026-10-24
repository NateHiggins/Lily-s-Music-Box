$env:ORISON_HOSE_EXPECT_NATIVE='1'
$hoseReview='C:/PleaseRemainOnTheLine/art/reviews/v2_hose_skin_20261022'
$hoseChecks=@(
 @{Name='kernel_final';Scene='HoseFollowKernelTest';Windowed=$false},
 @{Name='reticle_final';Scene='CalibratorHandBench';Windowed=$true},
 @{Name='sparse_control_final';Scene='V2DeployableHoseNativeTest';Windowed=$true},
 @{Name='dense_control_final';Scene='V2FireCapacityNativeTest';Windowed=$true},
 @{Name='settling_final';Scene='V2HoseSettlingTest';Windowed=$true}
)
$hoseResults=@()
foreach($hoseCheck in $hoseChecks) {
 & pwsh -File tools/run_godot_serial.ps1 -Scene "res://tests/$($hoseCheck.Scene).tscn" -Windowed:$($hoseCheck.Windowed) -TimeoutSeconds 180 -LogPath "$hoseReview/$($hoseCheck.Name).log" -ShotDir "$hoseReview/$($hoseCheck.Name)"
 $hoseResults+=@{name=$hoseCheck.Name;runner_exit=$LASTEXITCODE}
 if($LASTEXITCODE -eq 73) { break }
}
$hoseResults | ConvertTo-Json | Set-Content -LiteralPath "$hoseReview/final_batch_exits.json"
if(@($hoseResults | Where-Object { $_.runner_exit -ne 0 }).Count -gt 0) {exit 1}
