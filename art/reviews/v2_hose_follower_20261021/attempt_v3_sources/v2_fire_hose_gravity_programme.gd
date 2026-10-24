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
	for stem: String in ["stage27_mass9","stage27_mass10","native_rank","native_globalization"]:
		var relative: String="game/tests/fixtures/fire_hose_rank_case.json" if stem=="native_rank" else "art/reviews/v2_fire_hose_mass_20261019/cases/"+stem+"/kernel_case.json"
		if stem=="native_globalization":relative="game/tests/fixtures/fire_hose_globalization_case.json"
		var path: String=repository.path_join(relative)
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
		print("HOSE JOINT CASE: ",stem," backend=",joint.backend_name," ms=",float(Time.get_ticks_usec()-started)/1000.," iterations=",joint.iterations," qp_iterations=",joint.qp_iterations," error=",joint.error)
		if OS.get_environment("ORISON_HOSE_EXPECT_NATIVE")=="1":check(joint.backend_name=="native","compiled numerical backend actually selected")
		check(result.size()==seed.size(),"stored contact/bend case resolves without waived bounds "+stem)
		if result.is_empty() and not joint.last_iterate.is_empty():
			var directory: String=OS.get_environment("SHOT_DIR")
			if not directory.is_empty():
				DirAccess.make_dir_recursive_absolute(directory)
				var exported: Array=[]
				for point: Vector3 in joint.last_iterate:exported.append([point.x,point.y,point.z])
				var output:=FileAccess.open(directory.path_join(stem+"_failed_iterate.json"),FileAccess.WRITE)
				check(output!=null,"failed numerical iterate can be exported")
				if output!=null:output.store_string(JSON.stringify({"evidence_class":"INERT","error":joint.error,"points":exported}))
		if joint.backend_name=="native" and stem.begins_with("stage27_"):
			var reference:=preload("res://scripts/props/hose_contact_projection.gd").new();reference.force_reference=true
			reference.configure(PackedFloat64Array(value.lengths),PackedFloat64Array(value.bend_spans),weights)
			var baseline: PackedVector3Array=reference.project(seed,seed[-1],planes)
			var difference:=INF
			if baseline.size()==result.size() and not result.is_empty():
				difference=0.
				for i in result.size():difference=maxf(difference,result[i].distance_to(baseline[i]))
			check(difference<=.00002,"compiled positions agree with GDScript reference "+stem)
			if not result.is_empty():
				var speed:=PackedVector3Array()
				for i in seed.size():speed.append((Vector3(value.target[i][0],value.target[i][1],value.target[i][2])-seed[i])/(1./120.))
				var native_speed: PackedVector3Array=joint.project_velocity(result,speed,planes)
				var reference_speed: PackedVector3Array=reference.project_velocity(result,speed,planes)
				var speed_difference:=INF;var before_energy:=0.;var after_energy:=0.
				if native_speed.size()==speed.size() and reference_speed.size()==speed.size():
					speed_difference=0.
					for i in speed.size():
						speed_difference=maxf(speed_difference,native_speed[i].distance_to(reference_speed[i]))
						before_energy+=float(value.masses[i])*speed[i].length_squared()*.5
						after_energy+=float(value.masses[i])*native_speed[i].length_squared()*.5
				check(speed_difference<=.0001,"compiled velocities agree with GDScript reference "+stem)
				check(after_energy<=before_energy+maxf(.00000001,before_energy*.000001),"compiled velocity projection dissipates kinetic energy "+stem)
			var invalid: RefCounted=ClassDB.instantiate("OrisonHoseProjectionNative")
			check(bool(invalid.call("configure",PackedFloat64Array(value.lengths),PackedFloat64Array(value.bend_spans),weights)),"native validation control configures")
			var bad_weights:=weights.duplicate();bad_weights[0]=-1.
			check(not bool(invalid.call("configure",PackedFloat64Array(value.lengths),PackedFloat64Array(value.bend_spans),bad_weights)),"native negative inverse mass rejected")
			var bad_points:=seed.duplicate();bad_points[0]=Vector3(INF,0,0)
			var rejected: Dictionary=invalid.call("project",bad_points,seed[-1],planes)
			check(rejected.points.is_empty() and not str(rejected.error).is_empty(),"native nonfinite geometry rejected")
		if not result.is_empty():
			var maximum:=0.;var total:=0.;var bend:=0.;var support:=0.;var finite:=true
			for i in result.size():
				finite=finite and result[i].is_finite()
				if i<value.lengths.size():
					var residual: float=result[i].distance_to(result[i+1])-float(value.lengths[i])
					maximum=maxf(maximum,absf(residual));total+=residual
				if i<value.bend_spans.size():bend=maxf(bend,float(value.bend_spans[i])-result[i].distance_to(result[i+2]))
			for plane: Dictionary in value.planes:
				var normal:=Vector3(plane.normal[0],plane.normal[1],plane.normal[2])
				support=maxf(support,float(plane.offset)-normal.dot(result[int(plane.ring)]))
			check(finite and result[-1]==seed[-1] and maximum<=.00002 and absf(total)<=.00002 and bend<=.00002 and support<=.000001,"independent final joint residual check "+stem)
func _make_dynamics() -> RefCounted:return preload("res://scripts/props/native_hose_dynamics.gd").new()
func run(root: Node3D,rig: RefCounted,contact: RefCounted) -> bool:
	var saved: Dictionary=rig.snapshot()
	var initial: PackedVector3Array=rig.strand.points.duplicate()
	var dynamics: RefCounted=_make_dynamics()
	check(dynamics.configure(rig,contact),"native release solver binds actual length and shell owners")
	replay_cases()
	if not failures.is_empty():return false
	check(not dynamics.step(INF) and rig.strand.points==initial,"invalid dynamics time leaves cloth unchanged")
	var success:=true
	var exact_time:=true
	for step in 12:
		var before: PackedVector3Array=rig.strand.points.duplicate();var speed: PackedVector3Array=dynamics.velocities.duplicate()
		if not dynamics.step(dynamics.STEP_S):
			check(rig.strand.points==before and dynamics.velocities==speed and root.call("_pose_matches") and dynamics.advanced_time_s==0. and dynamics.accepted_substeps==0,"rejected free step preserves cloth, native skin, velocity and time atomically")
			success=false;break
		exact_time=exact_time and absf(dynamics.advanced_time_s-dynamics.STEP_S)<.0000000001
	print("HOSE GRAVITY FREE: error=",dynamics.error," mean_drop=",height(initial)-height(rig.strand.points))
	check(success and height(initial)-height(rig.strand.points)>.001,"released native cloth falls under gravity")
	check(exact_time,"successful free steps advance their entire requested time")
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
		var step_started: int=Time.get_ticks_usec()
		var before: PackedVector3Array=rig.strand.points.duplicate();var speed: PackedVector3Array=dynamics.velocities.duplicate()
		if not dynamics.step(dynamics.STEP_S):
			save_case(dynamics)
			check(rig.strand.points==before and dynamics.velocities==speed and root.call("_pose_matches") and dynamics.advanced_time_s==0. and dynamics.accepted_substeps==0,"rejected supported step preserves cloth, native skin, velocity and time atomically")
			success=false;print("HOSE GRAVITY STOP: step=",step," error=",dynamics.error)
			for plane: Dictionary in dynamics.last_contacts:
				print("HOSE GRAVITY LAST CONTACT: ",plane," center=",dynamics.last_proposed[plane.ring]," oldcenter=",rig.strand.points[plane.ring])
			break
		responses+=dynamics.contacts_resolved
		print("HOSE GRAVITY PROGRESS: step=",step," ms=",float(Time.get_ticks_usec()-step_started)/1000.," attempts=",dynamics.step_attempts," substeps=",dynamics.accepted_substeps," time_s=",dynamics.advanced_time_s," contact_energy_removed=",dynamics.last_contact_energy_removed)
		exact_time=exact_time and absf(dynamics.advanced_time_s-dynamics.STEP_S)<.0000000001
		history.append({"step":step,"energy":energy(rig,dynamics.velocities),"response_planes":dynamics.contacts_resolved,"response_iterations":dynamics.response_iterations,"projection_iterations":dynamics.kernel.iterations,"joint_accepted":dynamics.kernel.joint_accepted,"attempts":dynamics.step_attempts,"substeps":dynamics.accepted_substeps,"advanced_time_s":dynamics.advanced_time_s,"profile_usec":dynamics.profile_usec.duplicate(),"projection_calls":dynamics.projection_calls})
		if dynamics.use_follow_projection:
			history.back()["follow_successes"]=dynamics.follow_successes
			history.back()["follow_fallbacks"]=dynamics.follow_fallbacks
			history.back()["last_follow_error"]=dynamics.last_follow_error
			history.back()["internal_energy_removed"]=dynamics.last_internal_energy_removed
	print("HOSE GRAVITY SUPPORTED: ms=",float(Time.get_ticks_usec()-started)/1000.," response_planes=",responses)
	check(success and responses>0,"gravity reaches real floor and resolves native shell contacts")
	check(exact_time,"successful supported steps advance their entire requested time")
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
