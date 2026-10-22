extends "res://tests/v2_deployable_hose_programme.gd"
## Opt-in uninstalled numerical candidate; every inherited physical guard stays.
class FollowGravity extends "res://tests/v2_fire_hose_gravity_programme.gd":
	func _make_dynamics() -> RefCounted:
		var dynamics:=preload("res://scripts/props/native_hose_dynamics.gd").new()
		dynamics.use_follow_projection=true
		return dynamics
func _make_gravity_programme() -> RefCounted:return FollowGravity.new()
