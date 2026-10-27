extends Node3D
## One production batch specimen, accepted carried lamp and shared receiver field.
class ErrorCapture:
	extends Logger
	var errors: Array[String] = []
	var guard := Mutex.new()
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING: return
		guard.lock()
		errors.append("%s:%d %s %s" % [file,line,code,rationale])
		guard.unlock()
	func snapshot() -> Array[String]:
		guard.lock()
		var result := errors.duplicate()
		guard.unlock()
		return result
var logger: ErrorCapture
var controller: DreamCritterController
var player: PlayerController
var driver: Node
var bridge: Node3D
var camera: Camera3D
var target := Vector3.ZERO
var directory: String
var failures: Array[String] = []
var measurements := {}
var blocker: MeshInstance3D
var checks := 0
var started_ms := 0

class CompanionWorld:
	extends Node3D
	var work_orders: WorkOrders
	var vantry_points = null

func _ready() -> void: call_deferred("_run")

func _run() -> void:
	started_ms = Time.get_ticks_msec()
	logger = ErrorCapture.new()
	OS.add_logger(logger)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty(): directory = "user://tardigrade_review"
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled = false
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color.BLACK
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	controller = DreamCritterController.new()
	add_child(controller)
	controller.setup(null, 240304)
	controller.set_physics_process(false)
	controller.mesh_instance.layers = 1 << 14
	_check(controller.enable_blender_visuals(), "production Blender provider")
	if controller.blender_visuals == null:
		push_error(controller.blender_error)
		get_tree().quit(1)
		return
	var specimen := controller.debug_spawn_specimen(3,240304,Vector3.ZERO,Vector3.UP)
	target = specimen.pos
	specimen.fwd = Vector3.FORWARD
	controller.set_blender_inspection_kind(3)
	controller._push()
	player = PlayerController.new()
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	for canvas in player.find_children("*","CanvasLayer",true,false): canvas.visible = false
	player.position = Vector3(0,-20,0)
	if is_instance_valid(player.carried_device): player.carried_device.visible = false
	driver = preload("res://scripts/lamp/carried_lamp_optical_driver.gd").new()
	player.add_child(driver)
	_check(driver.setup(player), "accepted carried lamp driver")
	player.set_lamp_enabled(true)
	for i in 240: driver.advance_frame(1.0/120.0)
	bridge = preload("res://scripts/lamp/lamp_optical_material_bridge.gd").new()
	add_child(bridge)
	bridge.setup(player)
	bridge.field.profiling = true
	bridge.set_materials(controller.blender_visuals.micro_materials)
	camera = Camera3D.new()
	camera.position = target+Vector3(.7,.38,-.75)
	add_child(camera)
	camera.look_at(target)
	camera.fov = 40
	camera.make_current()
	for material in controller.blender_visuals.micro_materials:
		material.set_shader_parameter("micro_pc_only",true)
		material.set_shader_parameter("micro_pc_eye",camera.global_position)
	blocker = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(.65,.65,.07)
	blocker.mesh = box
	blocker.visible = false
	add_child(blocker)
	await _aim(camera.position-target)
	_check_surface_maps()
	_check_surface_maps(7)
	await _capture("01_front")
	await _aim(Vector3(-.9,.2,-.1))
	await _capture("02_side")
	await _aim(target-camera.position)
	await _capture("03_back")
	await _aim(Vector3(-.9,.2,-.1))
	await _capture("04_stable")
	driver.state.steady_supply = false
	driver.state.apply_mechanical_shock(.9)
	for i in 3:
		for step in 8: driver.advance_frame(1.0/120.0)
		await _capture("05_unstable_%d" % i)
	_check(measurements["05_unstable_0"].stability < measurements["04_stable"].stability,"unstable state comes from accepted lamp dynamics")
	player.set_lamp_enabled(false)
	driver.apply_output()
	await _capture("06_off")
	_check(not bridge.field.enabled, "logical off disables optical field")
	_check(measurements["06_off"].center_luminance < measurements["02_side"].center_luminance*.25,"off removes rendered optical response")
	settings.background_color = Color(.25,.25,.25)
	await _capture("20_off_on_visible_background")
	var visible_off := get_viewport().get_texture().get_image()
	controller.visible = false
	for i in 4: await RenderingServer.frame_post_draw
	var background_only := get_viewport().get_texture().get_image()
	var largest_difference := 0.0
	for y in range(0,visible_off.get_height(),8):
		for x in range(0,visible_off.get_width(),8):
			var a := visible_off.get_pixel(x,y)
			var b := background_only.get_pixel(x,y)
			largest_difference = maxf(largest_difference,absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))
	_check(largest_difference < .01,"off leaves no opaque organ silhouette on visible background")
	controller.visible = true
	settings.background_color = Color.BLACK
	player.set_lamp_enabled(true)
	driver.state.steady_supply = true
	for i in 240: driver.advance_frame(1.0/120.0)
	await _aim(Vector3(-.9,.2,-.1))
	blocker.position = target+(player.flashlight.global_position-target)*.5
	blocker.look_at(target)
	blocker.visible = true
	await _capture("07_blocked")
	_check(measurements["07_blocked"].center_luminance < measurements["02_side"].center_luminance*.35,"opaque blocker removes lamp response from visible specimen")
	blocker.visible = false
	player.flashlight.rotate_y(PI)
	await _capture("07b_outside_cone")
	_check(measurements["07b_outside_cone"].center_luminance < measurements["02_side"].center_luminance*.35,"outside cone rejects direct optical response")
	await _aim(Vector3(-.9,.2,-.1))
	for mode in [1,2,3,4,5,6]:
		_set_diagnostic(mode)
		await _capture(["", "08_exterior", "09_interior", "10_gold_cilia", "11_field_depth", "12_neutral_geometry", "13_transport_depth"][mode])
	await _aim(camera.position-target)
	_set_diagnostic(8)
	await _capture("18_surface_response")
	_set_diagnostic(9)
	await _capture("19_incident_radiance")
	await _aim(Vector3(-.9,.2,-.1))
	_set_diagnostic(0)
	# A fixed reference stage makes actual transmission visible; black alone
	# cannot distinguish a clear leg from an opaque black leg. Same camera,
	# lamp output and exposure for all three directions, no creature relighting.
	var grid := MeshInstance3D.new()
	grid.name = "OpticalBenchGrid"
	var grid_mesh := QuadMesh.new()
	grid_mesh.size = Vector2(3,3)
	grid.mesh = grid_mesh
	grid.layers = 1 << 14
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var grid_material := ShaderMaterial.new()
	grid_material.shader = Shader.new()
	grid_material.shader.code = "shader_type spatial; render_mode unshaded,cull_disabled; void fragment(){vec2 g=fract(UV*30.0);float line=max(step(.95,g.x),step(.95,g.y));ALBEDO=mix(vec3(.12),vec3(.055),line);}"
	grid.material_override = grid_material
	add_child(grid)
	grid.position = target+(target-camera.position).normalized()*.8
	grid.look_at(camera.position)
	await _aim(camera.position-target)
	await _capture("21_stage_front")
	await _aim(Vector3(-.9,.2,-.1))
	await _capture("22_stage_side")
	await _aim(target-camera.position)
	await _capture("23_stage_backlight")
	grid.queue_free()
	await _aim(Vector3(-.9,.2,-.1))
	await _check_companion(specimen)
	await _check_lunch(specimen)
	if OS.get_environment("MICRO_REVIEW_INTERACTIVE") == "1":
		print("MICRO REVIEW: 1 front, 2 side, 3 back, B blocker, L lamp, S shock, T stable; Escape exits")
		return
	measurements["bound"] = await _profile()
	controller.blender_visuals.micro_instances[1].visible = false
	controller.blender_visuals.micro_instances[2].visible = false
	measurements["opaque_only"] = await _profile()
	controller.blender_visuals.micro_instances[1].visible = true
	controller.blender_visuals.micro_instances[2].visible = true
	var no_materials: Array[ShaderMaterial] = []
	bridge.set_materials(no_materials)
	measurements["unbound"] = await _profile()
	measurements["field"] = {"uploads":bridge.field.uploads,"readbacks":bridge.field.readbacks,"texture_bindings":bridge.field.texture_bindings,"resource_allocations":bridge.field.resource_allocations,"dimensions":str(bridge.field.dimensions),"gpu_us":_distribution(bridge.field.gpu_samples_us),"construction_us":_distribution(bridge.field.construction_us),"submission_us":_distribution(bridge.field.submission_us)}
	if bridge.field.near_cascade != null:
		measurements["field"]["near_cascade"] = _near_profile(bridge.field.near_cascade)
	_check(bridge.field._materials.is_empty(),"all microscopic materials unregistered")
	bridge.field.dispose()
	for i in 4: await RenderingServer.frame_post_draw
	measurements["field_vram_released_bytes"] = measurements["bound"].video_memory-Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	measurements["paired_gpu_delta_ms"] = {"bound_minus_unbound":measurements["bound"].gpu_ms.median-measurements["unbound"].gpu_ms.median,"transparent_passes":measurements["bound"].gpu_ms.median-measurements["opaque_only"].gpu_ms.median}
	_check(not bridge.field._radiance_rid.is_valid() and not bridge.field._optics_rid.is_valid() and not bridge.field._buffer.is_valid() and not bridge.field._shader.is_valid() and not bridge.field._pipeline.is_valid() and not bridge.field._set.is_valid(),"all six field-owned RIDs released")
	_check(_near_rids_released(bridge.field.near_cascade),"all near-cascade owned RIDs released")
	var retained: Array = [weakref(bridge.field),weakref(controller.blender_visuals)]
	if bridge.field.near_cascade != null: retained.append(weakref(bridge.field.near_cascade))
	var retired_materials: Array[WeakRef] = []
	var retired_meshes: Array[WeakRef] = []
	for receiver in controller.blender_visuals.micro_instances:
		retired_materials.append(weakref(receiver.material_override))
		if receiver.mesh != null: retired_meshes.append(weakref(receiver.mesh))
	bridge.queue_free()
	controller.queue_free()
	bridge = null
	controller = null
	for i in 12: await RenderingServer.frame_post_draw
	_check(retained[0].get_ref()==null and retained[1].get_ref()==null,"field and visual owner released")
	if retained.size()>2: _check(retained[2].get_ref()==null,"near-cascade owner released")
	for reference in retired_materials: _check(reference.get_ref()==null,"retired microscopic material released")
	for reference in retired_meshes: _check(reference.get_ref()==null,"retired compiled microscopic mesh released")
	measurements["engine_errors"] = logger.snapshot()
	_check(measurements["engine_errors"].is_empty(),"no engine, script or shader errors")
	measurements["failures"] = failures
	FileAccess.open(directory.path_join("measurements.json"),FileAccess.WRITE).store_string(JSON.stringify(measurements,"\t"))
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Isolated production tardigrade batch, carried-lamp observation and shared material receiver; loaded maps, logical off and scoped field retirement. Not composed-world qualification, save reconstruction or visual acceptance.",
		"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started_ms)/1000.0},
		"source":{"test_path":"game/tests/tardigrade_microscopy_review.gd","test_sha256":get_script().source_code.replace("\r\n","\n").sha256_text()},
		"contracts":{"shared_receiver":{"executed":true,"status":"PASS" if failures.is_empty() else "FAIL"}},"checks":checks,"failures":failures,"observations":measurements}
	FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	print("TARDIGRADE REVIEW: ", failures)
	OS.remove_logger(logger)
	get_tree().quit(0 if failures.is_empty() else 1)

func _aim(offset: Vector3) -> void:
	player.flashlight.global_position = target+offset.normalized()*1.1
	player.flashlight.look_at(target)
	for i in 8: await RenderingServer.frame_post_draw

func _check_companion(specimen: Dictionary) -> void:
	var saved := RealityState.data.duplicate(true)
	var original := specimen.duplicate(true)
	var world := CompanionWorld.new()
	add_child(world)
	world.work_orders = WorkOrders.new()
	world.add_child(world.work_orders)
	world.work_orders.bind_job_library(MaintenanceJobLibrary.load_default())
	var repair := Node3D.new()
	repair.name = str(world.work_orders.job_library.job("lena_radiator_round_2b").repair_target_id)
	world.add_child(repair)
	repair.position = target + Vector3(1,0,0)
	RealityState.data.maintenance_jobs = {"lena_radiator_round_2b":{"stage":"repairable"}}
	RealityState.data.first_shift = {}
	var observer := Node3D.new()
	world.add_child(observer)
	observer.position = target + Vector3(0,0,-1)
	controller.bind_companion(world, observer)
	var companion = controller.companion
	companion.lunch.enabled = false # isolate the existing hint/startle contract
	companion.specimen_id = int(specimen.id)
	companion.refresh(1.0)
	_check(companion.target_id == str(repair.name), "companion reads live authored repair target")
	var durable := JSON.stringify(RealityState.data)
	specimen.tun = 0.0
	specimen.age = 1.0
	companion.steer(specimen,controller,.1)
	_check(companion.state == "point" and specimen.moving, "curious short lead toward fault")
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(8,.1,8)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -.05
	world.add_child(floor_body)
	await get_tree().physics_frame
	var before: Vector3 = specimen.pos
	for i in 30: controller._walk(1.0/60.0)
	_check((specimen.pos as Vector3).distance_to(before) > .005, "companion uses real surface movement")
	_check(absf(float(specimen.pos.y)-float(specimen.morph.tall)*.5)<.01, "companion stays seated on collision surface")
	specimen.age = 4.0
	companion.steer(specimen,controller,.1)
	_check(companion.state == "check_player" and not specimen.moving, "wait and look back for player")
	controller._push()
	await _capture("15_curious_lookback")
	var resident := Node3D.new()
	world.add_child(resident)
	resident.add_to_group("resident_placeholders")
	resident.position = target + Vector3(.4,0,0)
	companion.refresh(1.0)
	for i in 20: companion.steer(specimen,controller,.05)
	_check(companion.state == "retreat" and float(specimen.tun) > .5, "near resident causes protective contraction")
	controller._advance_crab_gait(specimen,.05)
	controller._push()
	await _capture("16_shy_contraction")
	resident.position += Vector3.RIGHT * 10.0
	companion.steer(specimen,controller,.05)
	_check(companion.state == "peek", "reopens cautiously after resident leaves")
	var animation_dir := directory.path_join("behavior_frames")
	DirAccess.make_dir_recursive_absolute(animation_dir)
	specimen.tun = 0.0
	var animation_states: Array = []
	for frame in 64:
		resident.position = (specimen.pos as Vector3) + Vector3.RIGHT * (.4 if frame>=16 and frame<32 else 10.0)
		for tick in 8: controller._walk(.125 / 8.0)
		controller._push()
		var gpu_law: PackedVector4Array = controller.blender_visuals.micro_materials[0].get_shader_parameter("critter_law")
		animation_states.append({"frame":frame,"state":companion.state,"tun":specimen.tun,"gpu_tun":gpu_law[0].z,"moving":specimen.moving})
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(animation_dir.path_join("frame_%03d.png" % frame))
	measurements["animation_states"] = animation_states
	_check(float(animation_states[24].tun)>.5 and float(animation_states[56].tun)<.1,"startle contracts then reopens during animation")
	_check(absf(float(animation_states[24].gpu_tun)-float(animation_states[24].tun))<.001 and absf(float(animation_states[56].gpu_tun)-float(animation_states[56].tun))<.001,"rendered tissue follows changing companion contraction")
	_check(JSON.stringify(RealityState.data) == durable, "hint behavior cannot change durable work or case state")
	RealityState.data.maintenance_jobs.lena_radiator_round_2b.stage = "repaired"
	companion.refresh(1.0)
	_check(companion.target == Vector3.INF, "repaired target stops attracting companion")
	for material in controller.blender_visuals.micro_materials:
		material.set_shader_parameter("micro_pc_only",true)
		material.set_shader_parameter("micro_pc_eye",camera.global_position+Vector3.RIGHT*2.0)
	await _capture("17_other_observer")
	_check(measurements["17_other_observer"].center_luminance < .0001, "non-player view cannot see creature")
	for material in controller.blender_visuals.micro_materials:
		material.set_shader_parameter("micro_pc_eye",camera.global_position)
	controller.companion = null
	specimen.clear()
	specimen.merge(original)
	controller._push()
	RealityState.data = saved
	world.queue_free()

func _check_lunch(t: Dictionary) -> void:
	var saved := RealityState.data.duplicate(true)
	var original := t.duplicate(true)
	var world := CompanionWorld.new()
	add_child(world)
	world.work_orders = WorkOrders.new()
	world.add_child(world.work_orders)
	world.work_orders.bind_job_library(MaintenanceJobLibrary.load_default())
	var repair := Node3D.new()
	repair.name = str(world.work_orders.job_library.job("lena_radiator_round_2b").repair_target_id)
	world.add_child(repair)
	repair.position = Vector3.LEFT*2.0
	RealityState.data.maintenance_jobs = {"lena_radiator_round_2b":{"stage":"repairable"}}
	var durable := JSON.stringify(RealityState.data)
	var observer := Node3D.new()
	world.add_child(observer)
	observer.position = Vector3(0,0,-1)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(12,.1,12)
	shape.shape=box
	floor_body.add_child(shape)
	floor_body.position.y=-.05
	world.add_child(floor_body)
	await get_tree().physics_frame
	t.pos=Vector3.UP*float(t.morph.tall)*.5
	t.fwd=Vector3.FORWARD
	t.tun=0.0
	t.leg_state=[]
	controller.bind_companion(world,observer)
	var companion=controller.companion
	companion.specimen_id=int(t.id)
	companion.refresh(1.0)
	var lunch=companion.lunch
	lunch.cooldown=0.0
	controller._walk(1.0/60.0)
	_check(lunch.prey_id>=0,"Euplotes prey spawns on a real support surface")
	_check(companion.state=="stalk" and t.companion_target=="lunch:euplotes","lunch interrupts an active repair hint")
	var p: Dictionary=lunch.specimen(controller,lunch.prey_id)
	if p.is_empty():
		controller.companion=null
		world.queue_free()
		RealityState.data=saved
		return
	_check(int(p.morph.kind)==7,"prey retains existing Euplotes identity")
	controller.set_blender_inspection_kind(7)
	controller._push()
	camera.position=(p.pos as Vector3)+Vector3(.2,.3,-.4)
	camera.look_at(p.pos)
	player.flashlight.global_position=(p.pos as Vector3)+Vector3(-.2,.4,-.3)
	player.flashlight.look_at(p.pos)
	for material in controller.blender_visuals.micro_materials:
		material.set_shader_parameter("micro_pc_eye",camera.global_position)
	for i in 12: await RenderingServer.frame_post_draw
	await _capture("24_euplotes_microscopy")
	controller.set_blender_inspection_kind(3)
	var prey_start: Vector3=p.pos
	var frames:=directory.path_join("lunch_frames")
	DirAccess.make_dir_recursive_absolute(frames)
	var seen: Dictionary={}
	var timeline: Array=[]
	var maximum_reach := 0.0
	for frame in 288:
		for tick in 8: controller._walk(.125/8.0)
		maximum_reach=maxf(maximum_reach,float(t.get("leg_root_gap_max",0.0)))
		controller._push()
		var center: Vector3=t.pos
		var live: Dictionary=lunch.specimen(controller,lunch.prey_id)
		if not live.is_empty(): center=(center+(live.pos as Vector3))*.5
		camera.position=center+Vector3(1.1,1.4,-1.7)
		camera.look_at(center)
		player.flashlight.global_position=center+Vector3(-.3,1.0,-.6)
		player.flashlight.look_at(center)
		for material in controller.blender_visuals.micro_materials:
			material.set_shader_parameter("micro_pc_eye",camera.global_position)
		await RenderingServer.frame_post_draw
		var pic:=get_viewport().get_texture().get_image()
		pic.save_png(frames.path_join("frame_%03d.png"%frame))
		if not seen.has(lunch.state):
			seen[lunch.state]=frame
			pic.save_png(directory.path_join("lunch_"+lunch.state+".png"))
		timeline.append({"frame":frame,"state":lunch.state,"attempts":lunch.attempts,"mouth":lunch.mouth(t),"prey":live.get("pos",Vector3.INF),"meal":t.get("meal",Vector4.ZERO)})
		if lunch.meals>0 and lunch.state=="sated": break
	measurements.lunch={"timeline":timeline,"events":lunch.events.duplicate(),"meals":lunch.meals,"misses":lunch.misses,"escapes":lunch.escapes,"maximum_leg_reach_m":maximum_reach}
	_check(maximum_reach<float(t.morph.length)*.8,"chase stride keeps planted legs within body-scale reach")
	_check(lunch.misses>0,"prey sidestep produces a real missed lunge")
	_check(lunch.meals==1 and lunch.prey_id==-1,"actual contact feeding consumes exactly one prey")
	_check(seen.has("feed") and seen.has("groom"),"feeding and grooming are rendered phases")
	_check(controller.critters.size()==1,"consumed prey leaves no live specimen or duplicate")
	_check((t.pos as Vector3).distance_to(prey_start)>.05,"hunt uses physical surface locomotion")
	companion.steer(t,controller,.016)
	_check(t.companion_target==str(repair.name),"sated Tardi resumes live repair guidance")
	_check(JSON.stringify(RealityState.data)==durable,"chase and meal cannot mutate durable repair state")
	# A wall must invalidate feeding contact regardless of the phase timer.
	var barrier:=StaticBody3D.new()
	var barrier_shape:=CollisionShape3D.new()
	var barrier_box:=BoxShape3D.new()
	barrier_box.size=Vector3(.1,1,1)
	barrier_shape.shape=barrier_box
	barrier.add_child(barrier_shape)
	world.add_child(barrier)
	barrier.position=Vector3(3,.5,0)
	await get_tree().physics_frame
	_check(not lunch._clear_contact(controller,Vector3(2.8,.5,0),Vector3(3.2,.5,0)),"mouth contact cannot cross a wall")
	var resident:=Node3D.new()
	world.add_child(resident)
	resident.add_to_group("resident_placeholders")
	resident.position=t.pos
	companion.refresh(1.0)
	lunch.cooldown=0.0
	controller._walk(.016)
	_check(companion.state=="retreat" and lunch.prey_id==-1,"resident fear overrides hunger and prevents nearby prey spawning")
	if lunch.prey_id>=0: lunch._clear(controller,false)
	controller.companion=null
	t.clear()
	t.merge(original)
	controller._push()
	RealityState.data=saved
	world.queue_free()

func _near_rids_released(field: RefCounted) -> bool:
	return field == null or (not field._radiance_rid.is_valid() and not field._optics_rid.is_valid() and not field._buffer.is_valid() and not field._shader.is_valid() and not field._pipeline.is_valid() and not field._set.is_valid())

func _near_profile(field: RefCounted) -> Dictionary:
	return {"dimensions":str(field.dimensions),"gpu_us":_distribution(field.gpu_samples_us),"construction_us":_distribution(field.construction_us),"submission_us":_distribution(field.submission_us),"readbacks":field.readbacks,"resource_allocations":field.resource_allocations}

func _set_diagnostic(mode: int) -> void:
	for material in controller.blender_visuals.micro_materials:
		material.set_shader_parameter("micro_diagnostic",mode)

func _capture(label: String) -> void:
	for i in 12: await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	_check(frame.save_png(directory.path_join(label+".png"))==OK,label)
	var center := camera.unproject_position(target)
	var total := 0.0
	for x in range(-20,21):
		for y in range(-20,21):
			var pixel := frame.get_pixel(clampi(int(center.x)+x,0,frame.get_width()-1),clampi(int(center.y)+y,0,frame.get_height()-1))
			total += pixel.r*.2126+pixel.g*.7152+pixel.b*.0722
	measurements[label] = {"center_luminance":total/1681.0,"energy":player.flashlight.light_energy,"stability":driver.output.temporal_stability,"pose":str(player.flashlight.global_transform)}

func _profile() -> Dictionary:
	var samples: Array[float] = []
	var gpu: Array[float] = []
	var updates: Array[float] = []
	for i in 30: await RenderingServer.frame_post_draw
	for i in 120:
		var start := Time.get_ticks_usec()
		controller._push()
		updates.append(float(Time.get_ticks_usec()-start))
		await RenderingServer.frame_post_draw
		samples.append(float(Time.get_ticks_usec()-start)/1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	samples.sort()
	return {"median_ms":samples[60],"p95_ms":samples[114],"max_ms":samples[-1],
		"gpu_ms":_distribution(gpu),
		"controller_update_us":_distribution(updates),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"scope":"wall frame interval plus measured viewport GPU time; includes field and rendering"}

func _distribution(values: Array) -> Dictionary:
	if values.is_empty(): return {"available":false}
	var sorted := values.duplicate()
	sorted.sort()
	return {"available":true,"median":sorted[int(sorted.size()/2)],"p95":sorted[mini(sorted.size()-1,int(sorted.size()*.95))],"max":sorted[-1],"count":sorted.size()}

func _check_surface_maps(kind: int = 3) -> void:
	var template: Dictionary = controller.blender_visuals.assets.templates[kind][0]
	var nominal := Vector3(.32,.30,.635) if kind==3 else Vector3(.16,.048,.23)
	var invalid_uv := 0
	var maximum_scale_error := 0.0
	var points: PackedVector3Array = template.positions
	var uvs: PackedVector2Array = template.uvs
	var indices: PackedInt32Array = template.indices
	for i in range(0,indices.size(),3):
		var a := indices[i]
		var b := indices[i+1]
		var c := indices[i+2]
		var area := ((points[b]-points[a])*nominal).cross((points[c]-points[a])*nominal).length()
		var uv_area := absf((uvs[b]-uvs[a]).cross(uvs[c]-uvs[a]))
		if not is_finite(uv_area) or uv_area<=0.0000000001:
			invalid_uv += 1
		else:
			maximum_scale_error=maxf(maximum_scale_error,absf(uv_area*.04*.04/maxf(area,.000000000001)-1.0))
	_check(invalid_uv==0,"all imported physical triangles have finite nonzero UV area")
	_check(maximum_scale_error<.08,"imported nominal physical chart scale within eight percent")
	var key := "uv" if kind==3 else "euplotes_uv"
	measurements[key]={"triangles":indices.size()/3,"invalid":invalid_uv,"max_relative_scale_error":maximum_scale_error}
	print("MICRO UV: ", measurements[key])
	if kind==7: return # the two species share the same nine mapped stocks
	var maps := {}
	for material in controller.blender_visuals.micro_materials:
		for substance in ["membrane","organ","mineral"]:
			for channel in ["albedo","roughness","normal"]:
				var texture: Texture2D = material.get_shader_parameter("micro_"+substance+"_"+channel)
				_check(texture!=null and texture.get_image().has_mipmaps(),"loaded mip chain "+substance+" "+channel)
				if texture!=null: maps[texture.get_instance_id()] = true
	_check(maps.size()==9,"nine shared PBR maps, no per-organ copies")
	measurements["material_instances"] = controller.blender_visuals.micro_materials.size()
	measurements["unique_pbr_textures"] = maps.size()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _unhandled_key_input(event: InputEvent) -> void:
	if OS.get_environment("MICRO_REVIEW_INTERACTIVE") != "1" or player == null: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_1: _aim(camera.position-target)
		KEY_2: _aim(Vector3(-.9,.2,-.1))
		KEY_3: _aim(target-camera.position)
		KEY_B:
			blocker.position = target+(player.flashlight.global_position-target)*.5
			blocker.look_at(target)
			blocker.visible = not blocker.visible
		KEY_L:
			player.set_lamp_enabled(not player.lamp_is_enabled())
			driver.apply_output()
		KEY_S:
			driver.state.steady_supply = false
			driver.state.apply_mechanical_shock(.9)
			driver.advance_frame(1.0/60.0)
		KEY_T:
			driver.state.steady_supply = true
			for i in 240: driver.advance_frame(1.0/120.0)
		KEY_ESCAPE: get_tree().quit()
