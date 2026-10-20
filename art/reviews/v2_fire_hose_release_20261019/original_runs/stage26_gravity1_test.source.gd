extends RefCounted
## Candidate release/contact response diagnostic, not full deployment acceptance.
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	print("HOSE GRAVITY CHECK: ",label," = ",ok)
	if not ok:failures.append(label)
func height(points: PackedVector3Array) -> float:
	var sum:=0.
	for p: Vector3 in points:sum+=p.y
	return sum/points.size()
func capture(root: Node3D,name: String) -> void:
	for frame in 6:await root.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory: String=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():root.get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))
func run(root: Node3D,rig: RefCounted,contact: RefCounted) -> bool:
	var saved: Dictionary=rig.snapshot()
	var initial: PackedVector3Array=rig.strand.points.duplicate()
	var dynamics:=preload("res://scripts/props/native_hose_dynamics.gd").new()
	check(dynamics.configure(rig,contact),"native release solver binds actual length and shell owners")
	check(not dynamics.step(INF) and rig.strand.points==initial,"invalid dynamics time leaves cloth unchanged")
	var success:=true
	for step in 12:
		if not dynamics.step(dynamics.STEP_S):success=false;break
	print("HOSE GRAVITY FREE: error=",dynamics.error," mean_drop=",height(initial)-height(rig.strand.points))
	check(success and height(initial)-height(rig.strand.points)>.001,"released native cloth falls under gravity")
	check(rig.strand._valid_positions(rig.strand.points) and rig.strand.points[-1]==initial[-1],"fall preserves every length and fixed outlet")
	await capture(root,"gravity_free")
	check(rig.restore(saved),"release diagnostic restores original native pose")
	dynamics.reset_velocity()
	var frames: Array[Transform3D]=rig.model_frames(initial);var lowest:=INF
	for i in initial.size():
		for p: Vector3 in contact.sections[i].outer:lowest=minf(lowest,(frames[i]*p).y)
	var floor:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
	box.size=Vector3(4.,.04,4.);shape.shape=box;floor.add_child(shape);root.add_child(floor)
	floor.global_transform=rig.model.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,lowest-.025,.1))
	await root.get_tree().physics_frame;await root.get_tree().physics_frame
	check(not contact.intersects_pose(initial),"release floor starts5mm below actual native shell")
	var responses:=0;var started: int=Time.get_ticks_usec()
	for step in 24:
		if not dynamics.step(dynamics.STEP_S):success=false;print("HOSE GRAVITY STOP: step=",step," error=",dynamics.error);break
		responses+=dynamics.contacts_resolved
	print("HOSE GRAVITY SUPPORTED: ms=",float(Time.get_ticks_usec()-started)/1000.," response_planes=",responses)
	check(success and responses>0,"gravity reaches real floor and resolves native shell contacts")
	check(not contact.intersects_pose(rig.strand.points) and rig.strand._valid_positions(rig.strand.points),"supported cloth remains outside floor without length gain")
	await capture(root,"gravity_supported")
	floor.free();await root.get_tree().physics_frame
	check(rig.restore(saved),"supported release diagnostic restores original pose")
	return failures.is_empty()
