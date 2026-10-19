extends Node
## Saved mathematical regressions only; no world/skin/deployment acceptance.
func _warm_cases(programme: RefCounted) -> void:
	var repository: String=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var paths: Array[String]=["art/reviews/v2_fire_hose_mass_20261019/cases/stage27_mass9/kernel_case.json","art/reviews/v2_fire_hose_mass_20261019/cases/stage27_mass10/kernel_case.json","game/tests/fixtures/fire_hose_rank_case.json","game/tests/fixtures/fire_hose_globalization_case.json"]
	for path: String in paths:
		var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(repository.path_join(path)))
		programme.check(value is Dictionary,"warm fixture loads "+path)
		if value is not Dictionary:continue
		var target:=PackedVector3Array();var rest:=PackedVector3Array();var planes: Dictionary={}
		for point: Array in value.target:target.append(Vector3(point[0],point[1],point[2]))
		for point: Array in value.result:rest.append(Vector3(point[0],point[1],point[2]))
		for plane: Dictionary in value.planes:
			var ring: int=int(plane.ring)
			if not planes.has(ring):planes[ring]=[]
			planes[ring].append({"normal":Vector3(plane.normal[0],plane.normal[1],plane.normal[2]),"offset":plane.offset})
		var kernel:=preload("res://scripts/props/hose_mass_constraints.gd").new()
		programme.check(kernel.configure(PackedFloat64Array(value.lengths),rest),"warm material configures")
		if OS.get_environment("ORISON_HOSE_EXPECT_NATIVE")=="1":programme.check(kernel.coupled.backend_name=="native","compiled warm backend selected")
		var started: int=Time.get_ticks_usec()
		var native: Dictionary=kernel.warm_start(target,target[-1],planes)
		var native_ms: float=float(Time.get_ticks_usec()-started)/1000.
		started=Time.get_ticks_usec()
		var reference: Dictionary=kernel._warm_start_gd(target,target[-1],planes)
		var reference_ms: float=float(Time.get_ticks_usec()-started)/1000.
		var difference:=INF
		if native.points.size()==reference.points.size() and not native.points.is_empty():
			difference=0.
			for i in native.points.size():difference=maxf(difference,native.points[i].distance_to(reference.points[i]))
		print("HOSE WARM PARITY: ",path," native_ms=",native_ms," reference_ms=",reference_ms," max_difference_m=",difference," iterations=",native.iterations,"/",reference.iterations," accepted=",native.accepted,"/",reference.accepted)
		programme.check(native.error==reference.error and native.accepted==reference.accepted and native.iterations==reference.iterations and difference<=.0000001,"native warm start preserves reference trajectory within0.1micrometre")
func _ready() -> void:
	var programme:=preload("res://tests/v2_fire_hose_gravity_programme.gd").new()
	programme.replay_cases()
	_warm_cases(programme)
	var kernel:=preload("res://scripts/props/hose_mass_constraints.gd").new()
	var points:=PackedVector3Array([Vector3.ZERO,Vector3(0,.1,0),Vector3(0,.2,0)])
	programme.check(kernel.configure(PackedFloat64Array([.1,.1]),points),"material validation control configures")
	var invalid:=points.duplicate();invalid[0]=Vector3(NAN,0,0)
	programme.check(kernel.project(invalid,points[-1],{}).is_empty() and kernel.error=="nonfinite material position","material warm start rejects nonfinite points before numerical work")
	programme.check(kernel.project(points,Vector3(INF,0,0),{}).is_empty() and kernel.error=="nonfinite material anchor","material warm start rejects nonfinite fixed anchor")
	if kernel.coupled.backend_name=="native":
		var rejected: Dictionary=kernel.coupled.warm_start(invalid,points[-1],{},kernel.bend_hints)
		programme.check(rejected.points.is_empty() and not rejected.error.is_empty(),"native warm entry rejects nonfinite geometry")
		rejected=kernel.coupled.warm_start(points,points[-1],{},PackedVector3Array())
		programme.check(rejected.points.is_empty() and not rejected.error.is_empty(),"native warm entry rejects wrong hint count")
		var bad_hints:=kernel.bend_hints.duplicate();bad_hints[0]=Vector3(INF,0,0)
		rejected=kernel.coupled.warm_start(points,points[-1],{},bad_hints)
		programme.check(rejected.points.is_empty() and not rejected.error.is_empty(),"native warm entry rejects nonfinite hint")
	print("HOSE PROJECTION REGRESSION: ","PASS" if programme.failures.is_empty() else "FAIL"," failures=",programme.failures.size())
	get_tree().quit(programme.failures.size())
