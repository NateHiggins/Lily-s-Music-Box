$ErrorActionPreference = 'Stop'
& 'C:\PleaseRemainOnTheLine-astra\tools\run_godot_serial.ps1' -ProjectPath 'C:\PleaseRemainOnTheLine-astra\game' -Scene 'res://tests/ApartmentMaterialBindingTest.tscn' -LogPath 'C:\PleaseRemainOnTheLine-astra\design\astra\evidence\apartment_material_binding\original_01\godot.stdout.log' -TimeoutSeconds 45 -ExtraArgs @('--verbose')
exit $LASTEXITCODE
