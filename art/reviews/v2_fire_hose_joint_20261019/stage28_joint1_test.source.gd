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
func energy(rig: RefCounted,velocities: PackedVector3Array) -> float:
	# Unit line density; authored material-length weights, not one equal mass
	# per ring (the original curved samples are more densely spaced).
	var result:=0.
	for i in rig.strand.points.size():
		var mass:=0.
		if i>0:mass+=rig.strand.lengths[i-1]*.5
		if i<rig.strand.lengths.size():mass+=rig.strand.lengths[i]*.5
		var point: Vector3=rig.model.to_global(rig.strand.points[i])
		var speed: Vector3=rig.model.global_basis*velocities[i]
		result+=mass*(speed.length_squared()*.5+9.81*point.y)
	return result
func capture(root: Node3D,name: String) -> void:
	for frame in 6:await root.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory: String=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():root.get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))
func save_case(dynamics: RefCounted) -> void:
	var directory: String=OS.get_environment("SHOT_DIR")
	if directory.is_empty():return
	var kernel: RefCounted=dynamics.kernel
	var target: Array=[];var result: Array=[];var planes: Array=[]
	for point: Vector3 in kernel.last_input:target.append([point.x,point.y,point.z])
	for point: Vector3 in kernel.last_result:result.append([point.x,point.y,point.z])
	for ring: int in kernel.last_planes:
		for plane: Dictionary in kernel.last_planes[ring]:planes.append({"ring":ring,"normal":[plane.normal.x,plane.normal.y,plane.normal.z],"offset":plane.offset})
	FileAccess.open(directory.path_join("kernel_case.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","error":dynamics.error,"target":target,"result":result,"planes":planes,"lengths":Array(kernel.lengths),"masses":Array(kernel.masses),"bend_spans":Array(kernel.bend_spans)},"\t"))
func replay_cases() -> void:
	# Numerical regression only; these historical inputs grant no runtime proof.
	var repository: String=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	for stem: String in ["stage27_mass9","stage27_mass10"]:
		var path: String=repository.path_join("art/reviews/v2_fire_hose_mass_20261019/cases/"+stem+"/kernel_case.json")
		var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		check(value is Dictionary,"stored joint input loads "+stem)
		if value is not Dictionary:continue
		var weights:=PackedFloat64Array()
		for mass: float in value.masses:weights.append(1./mass)
		weights[-1]=0.
		var joint:=preload("res://scripts/props/hose_contact_projection.gd").new()
		joint.configure(PackedFloat64Array(value.lengths),PackedFloat64Array(value.bend_spans),weights)
		var seed:=PackedVector3Array();var planes: Dictionary={}
		for point: Array in value.result:seed.append(Vector3(point[0],point[1],point[2]))
		for plane: Dictionary in value.planes:
			var ring: int=int(plane.ring)
			if not planes.has(ring):planes[ring]=[]
			planes[ring].append({"normal":Vector3(plane.normal[0],plane.normal[1],plane.normal[2]),"offset":plane.offset})
		var started: int=Time.get_ticks_usec()
		var result: PackedVector3Array=joint.project(seed,seed[-1],planes)
		print("HOSE JOINT CASE: ",stem," ms=",float(Time.get_ticks_usec()-started)/1000.," iterations=",joint.iterations," qp_iterations=",joint.qp_iterations," error=",joint.error)
		check(result.size()==seed.size(),"stored contact/bend case resolves without waived bounds "+stem)
		if not result.is_empty():check(joint._acceptable(joint._metrics(joint._rows(result,planes))),"independent final joint residual check "+stem)
func run(root: Node3D,rig: RefCounted,contact: RefCounted) -> bool:
	var saved: Dictionary=rig.snapshot()
	var initial: PackedVector3Array=rig.strand.points.duplicate()
	var dynamics:=preload("res://scripts/props/native_hose_dynamics.gd").new()
	check(dynamics.configure(rig,contact),"native release solver binds actual length and shell owners")
	replay_cases()
	if not failures.is_empty():return false
	check(not dynamics.step(INF) and rig.strand.points==initial,"invalid dynamics time leaves cloth unchanged")
	var success:=true
	for step in 12:
		var before: PackedVector3Array=rig.strand.points.duplicate();var speed: PackedVector3Array=dynamics.velocities.duplicate()
		if not dynamics.step(dynamics.STEP_S):
			check(rig.strand.points==before and dynamics.velocities==speed and root.call("_pose_matches"),"rejected free step preserves cloth, native skin and velocity atomically")
			success=false;break
	print("HOSE GRAVITY FREE: error=",dynamics.error," mean_drop=",height(initial)-height(rig.strand.points))
	check(success and height(initial)-height(rig.strand.points)>.001,"released native cloth falls under gravity")
	check(rig.strand._valid_positions(rig.strand.points) and rig.strand.points[-1]==initial[-1],"fall preserves every length and fixed outlet")
	check(dynamics.kernel._bend_error(rig.strand.points)<=dynamics.kernel.ACCEPT_ERROR_M,"free cloth retains finite native bend radius")
	await capture(root,"gravity_free")
	check(rig.restore(saved),"release diagnostic restores original native pose")
	dynamics.reset_velocity()
	var initial_energy: float=energy(rig,dynamics.velocities)
	var history: Array=[]
	var frames: Array[Transform3D]=rig.model_frames(initial);var lowest:=INF
	for i in initial.size():
		for p: Vector3 in contact.sections[i].outer:lowest=minf(lowest,(frames[i]*p).y)
	var floor:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
	box.size=Vector3(4.,.04,4.);shape.shape=box;floor.add_child(shape);root.add_child(floor)
	floor.global_transform=rig.model.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,lowest-.025,.1))
	await root.get_tree().physics_frame;await root.get_tree().physics_frame
	check(not contact.intersects_pose(initial),"release floor starts5mm below actual native shell")
	var responses:=0;var started: int=Time.get_ticks_usec()
	success=true
	for step in 24:
		var before: PackedVector3Array=rig.strand.points.duplicate();var speed: PackedVector3Array=dynamics.velocities.duplicate()
		if not dynamics.step(dynamics.STEP_S):
			save_case(dynamics)
			check(rig.strand.points==before and dynamics.velocities==speed and root.call("_pose_matches"),"rejected supported step preserves cloth, native skin and velocity atomically")
			success=false;print("HOSE GRAVITY STOP: step=",step," error=",dynamics.error)
			for plane: Dictionary in dynamics.last_contacts:
				print("HOSE GRAVITY LAST CONTACT: ",plane," center=",dynamics.last_proposed[plane.ring]," oldcenter=",rig.strand.points[plane.ring])
			break
		responses+=dynamics.contacts_resolved
		history.append({"step":step,"energy":energy(rig,dynamics.velocities),"response_planes":dynamics.contacts_resolved,"response_iterations":dynamics.response_iterations,"projection_iterations":dynamics.kernel.iterations,"joint_accepted":dynamics.kernel.joint_accepted})
	print("HOSE GRAVITY SUPPORTED: ms=",float(Time.get_ticks_usec()-started)/1000.," response_planes=",responses)
	check(success and responses>0,"gravity reaches real floor and resolves native shell contacts")
	check(not contact.intersects_pose(rig.strand.points) and rig.strand._valid_positions(rig.strand.points),"supported cloth remains outside floor without length gain")
	check(dynamics.kernel._bend_error(rig.strand.points)<=dynamics.kernel.ACCEPT_ERROR_M,"supported cloth retains finite native bend radius")
	var final_energy: float=energy(rig,dynamics.velocities)
	print("HOSE GRAVITY ENERGY: initial=",initial_energy," final=",final_energy)
	check(final_energy<=initial_energy*1.001,"stationary floor response does not inject mechanical energy")
	var directory: String=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		FileAccess.open(directory.path_join("gravity_trace.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","initial_energy":initial_energy,"final_energy":final_energy,"steps":history,"pose":rig.snapshot(),"scope":"Candidate diagnostic. No self-contact, bending stiffness or fitted nozzle. Not completed physical release."},"\t"))
	await capture(root,"gravity_supported")
	floor.free();await root.get_tree().physics_frame
	check(rig.restore(saved),"supported release diagnostic restores original pose")
	return failures.is_empty()
