extends "res://tests/v2_deployable_hose_programme.gd"
## Opt-in uninstalled numerical candidate; every inherited physical guard stays.
var tether:=preload("res://scripts/props/native_hose_tether.gd").new()
class FollowGravity extends "res://tests/v2_fire_hose_gravity_programme.gd":
	func _make_dynamics() -> RefCounted:
		var dynamics:=preload("res://scripts/props/native_hose_dynamics.gd").new()
		dynamics.use_follow_projection=true
		return dynamics
func _make_gravity_programme() -> RefCounted:return FollowGravity.new()
func _move_hose_endpoint(value: Vector3) -> bool:
	if tether.rig==null and not tether.configure(rig,contact):return false
	var moved: bool=tether.move_endpoint(value)
	print("HOSE HELD FOLLOW: moved=",moved," ms=",tether.last_ms," responses=",tether.responses," error=",tether.error)
	return moved
