extends Node
## Saved mathematical regressions only; no world/skin/deployment acceptance.
func _ready() -> void:
	var programme:=preload("res://tests/v2_fire_hose_gravity_programme.gd").new()
	programme.replay_cases()
	var kernel:=preload("res://scripts/props/hose_mass_constraints.gd").new()
	var points:=PackedVector3Array([Vector3.ZERO,Vector3(0,.1,0),Vector3(0,.2,0)])
	programme.check(kernel.configure(PackedFloat64Array([.1,.1]),points),"material validation control configures")
	var invalid:=points.duplicate();invalid[0]=Vector3(NAN,0,0)
	programme.check(kernel.project(invalid,points[-1],{}).is_empty() and kernel.error=="nonfinite material position","material warm start rejects nonfinite points before numerical work")
	programme.check(kernel.project(points,Vector3(INF,0,0),{}).is_empty() and kernel.error=="nonfinite material anchor","material warm start rejects nonfinite fixed anchor")
	print("HOSE PROJECTION REGRESSION: ","PASS" if programme.failures.is_empty() else "FAIL"," failures=",programme.failures.size())
	get_tree().quit(programme.failures.size())
