extends "res://tests/v2_fire_capacity_native_test.gd"
## Uninstalled sparse native cloth candidate, not deployed installed acceptance.
func _asset_path() -> String:return "res://tests/fixtures/v2_deployable_hose_candidate.glb"
func _make_programme() -> Node:return preload("res://tests/v2_deployable_hose_programme.gd").new()
