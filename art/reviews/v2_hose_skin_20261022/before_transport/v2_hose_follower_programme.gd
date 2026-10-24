extends "res://tests/v2_deployable_hose_programme.gd"
## Opt-in uninstalled numerical candidate; every inherited physical guard stays.
var tether:=preload("res://scripts/props/native_hose_tether.gd").new()
var resume_costs: Array[float]=[]
func _process(_delta: float) -> void:
	if held and tether.pending:
		if tether.resume_prepare() and tether.commit_endpoint():_sync()
		resume_costs.append(tether.last_ms)
func _release_hose_grip() -> void:
	super._release_hose_grip();tether.cancel_motion()
class FollowGravity extends "res://tests/v2_fire_hose_gravity_programme.gd":
	func _make_dynamics() -> RefCounted:
		var dynamics:=preload("res://scripts/props/native_hose_dynamics.gd").new()
		dynamics.use_follow_projection=true
		dynamics.pin_outlet_direction=true;dynamics.native_skin_bends=true
		return dynamics
	func _check_fixed_outlet(dynamics: RefCounted,initial: PackedVector3Array) -> void:
		var fixed:=true
		for i in range(initial.size()-3,initial.size()):
			fixed=fixed and dynamics.rig.strand.points[i]==initial[i] and dynamics.velocities[i]==Vector3.ZERO
		var frames: Array[Transform3D]=dynamics.rig.model_frames(dynamics.rig.strand.points)
		check(fixed and frames[-1].basis.is_equal_approx(dynamics.rig.original_frames[-1].basis) and frames[-2].basis.is_equal_approx(dynamics.rig.original_frames[-2].basis),"released and supported cloth retains the rigid native outlet neck and its frame")
func _make_gravity_programme() -> RefCounted:return FollowGravity.new()
func _move_hose_endpoint(value: Vector3) -> bool:
	if tether.rig==null and not tether.configure(rig,contact):return false
	var moved: bool=tether.move_endpoint(value)
	print("HOSE HELD FOLLOW: moved=",moved," ms=",tether.last_ms," responses=",tether.responses," error=",tether.error)
	return moved
func run(holder: PlayerController) -> bool:
	if not await super.run(holder):return false
	await _blocked_endpoint()
	await _prepared_endpoint()
	return failures.is_empty()
func _blocked_endpoint() -> void:
	var saved: Dictionary=rig.snapshot();var before: PackedVector3Array=rig.strand.points.duplicate()
	var obstacle:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
	box.size=Vector3(.006,.06,.06);shape.shape=box;obstacle.add_child(shape);add_child(obstacle)
	obstacle.position=before[0]+Vector3(.026,0,0)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not contact.intersects_pose(before),"held-end obstruction begins outside actual native cloth")
	if failures.is_empty():
		var moved: bool=tether.move_endpoint(before[0]+Vector3(.04,0,0))
		_sync()
		var blocked_now:=false;var clear:=true
		for attempt in 4:
			var partial: PackedVector3Array=rig.strand.points.duplicate()
			var accepted: bool=tether.move_endpoint(before[0]+Vector3(.04,0,0))
			clear=clear and rig.strand.points[0].x<=before[0].x+.023001 and not contact.intersects_pose(rig.strand.points)
			if not accepted:
				blocked_now=rig.strand.points==partial;break
		check(moved and clear and blocked_now and _pose_matches(),"held cloth can approach a real obstruction but cannot cross it or leave a half-applied solve")
	obstacle.free();await get_tree().physics_frame
	check(rig.restore(saved),"held obstruction diagnostic restores its original source pose")
	_sync()

func _prepared_endpoint() -> void:
	var saved: Dictionary=rig.snapshot();var before: PackedVector3Array=rig.strand.points.duplicate()
	var prepared: bool=tether.prepare_endpoint(before[0]+Vector3(-.001,0,0))
	check(prepared and tether.has_prepared_endpoint() and rig.strand.points==before and _pose_matches(),"preparing fitting transport changes neither cloth nor skin")
	tether.cancel_endpoint()
	check(not tether.has_prepared_endpoint() and not tether.commit_endpoint() and rig.strand.points==before,"cancelled fitting transport cannot be committed")
	prepared=tether.prepare_endpoint(before[0]+Vector3(-.001,0,0))
	await get_tree().physics_frame
	check(prepared and not tether.commit_endpoint() and rig.strand.points==before and _pose_matches(),"transport proposal cannot outlive its physical frame")
	prepared=tether.prepare_endpoint(before[0]+Vector3(-.001,0,0))
	check(prepared and tether.commit_endpoint() and rig.strand.points[0].distance_to(before[0]+Vector3(-.001,0,0))<.000002,"same-frame fitting transport commits only after authoritative native sweep")
	check(rig.restore(saved),"fitting transport diagnostic restores source pose");_sync()
