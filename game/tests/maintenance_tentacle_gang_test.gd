extends Node3D
const Gang = preload("res://scripts/dream/entity/maintenance_tentacle_gang.gd")
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
var failures: Array[String] = []
var checks := 0
var player: PlayerController
var gang: Node3D
var directory := ""
var started := 0
var times: Array[float] = []
var phase_times: Dictionary = {}
var optical_measurements: Dictionary = {}
var review_pose := Transform3D.IDENTITY
var lamp_driver: Node

func _process(delta: float) -> void:
	# The fixture disables player look/bob but advances its real lamp owner.
	if is_instance_valid(lamp_driver): lamp_driver.advance_frame(delta)

func _ready() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("GANG: ",label," = ",ok)

func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	player._unhandled_input(event)

func capture(label: String) -> void:
	player.camera.global_transform = review_pose
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(directory.path_join(label+".png"))
	var centre := player.camera.unproject_position(gang.global_position+Vector3.UP*.35)
	var total := 0.0
	var samples := 0
	for y in range(maxi(0,int(centre.y)-90),mini(image.get_height(),int(centre.y)+90),4):
		for x in range(maxi(0,int(centre.x)-90),mini(image.get_width(),int(centre.x)+90),4):
			var color := image.get_pixel(x,y)
			total += color.r*.2126+color.g*.7152+color.b*.0722
			samples += 1
	optical_measurements[label] = total/maxi(samples,1)

func wait_seconds(seconds: float) -> void:
	var until := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		var before := Time.get_ticks_usec()
		await get_tree().process_frame
		var measured := (Time.get_ticks_usec()-before)/1000.0
		times.append(measured)
		var label := str(gang.phase) if is_instance_valid(gang) else "baseline"
		if not phase_times.has(label): phase_times[label] = []
		phase_times[label].append(measured)

func aim_lamp(at: Vector3) -> void:
	player.flashlight.global_position = at
	player.flashlight.look_at(Vector3(0,.35,0))
	await wait_seconds(.25)

func wait_phase(wanted: int, timeout: float) -> void:
	var until := Time.get_ticks_msec()+int(timeout*1000)
	while gang.phase != wanted and Time.get_ticks_msec()<until:
		await get_tree().process_frame

func operate_supply(radiator: RadiatorProp, value: float) -> bool:
	var pose := player.camera.global_transform
	var hand := preload("res://tests/maintenance_tentacle_test_hand.gd").new()
	add_child(hand)
	hand.player = player
	var point: Vector3 = radiator._wheel.global_position+radiator.global_basis*Vector3(0,0,-.045)
	var moved: bool = await hand.operate(point,value*TAU*3.5,radiator)
	hand.queue_free()
	player.camera.global_transform = pose
	return moved and absf(radiator.supply_position-value)<.00001

func capture_clearances() -> void:
	var lines := ImmediateMesh.new()
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(.2,1,.45)
	ink.no_depth_test = true
	ink.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	lines.surface_begin(Mesh.PRIMITIVE_LINES,ink)
	for i in 32:
		var a := TAU*float(i)/32
		var b := TAU*float(i+1)/32
		for y in [.015,.865]:
			lines.surface_add_vertex(gang.to_global(Vector3(cos(a)*.3,y,sin(a)*.3)))
			lines.surface_add_vertex(gang.to_global(Vector3(cos(b)*.3,y,sin(b)*.3)))
		if i%4==0:
			lines.surface_add_vertex(gang.to_global(Vector3(cos(a)*.3,.015,sin(a)*.3)))
			lines.surface_add_vertex(gang.to_global(Vector3(cos(a)*.3,.865,sin(a)*.3)))
	for area in gang.contacts:
		for shape: CollisionShape3D in area.get_children():
			var half: Vector3 = shape.shape.size*.5
			for axis in 3:
				for a in [-1,1]:
					for b in [-1,1]:
						var from := Vector3.ZERO
						from[axis] = -half[axis]
						from[(axis+1)%3] = half[(axis+1)%3]*a
						from[(axis+2)%3] = half[(axis+2)%3]*b
						var to := from
						to[axis] = half[axis]
						lines.surface_add_vertex(shape.to_global(from))
						lines.surface_add_vertex(shape.to_global(to))
	lines.surface_end()
	var draw := MeshInstance3D.new()
	draw.mesh = lines
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(draw)
	await capture("02a_contact_and_anchor_clearance")
	draw.queue_free()
	await get_tree().physics_frame

func _run() -> void:
	started = Time.get_ticks_msec()
	var logger := ErrorCapture.new()
	OS.add_logger(logger)
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty(): directory = "user://tentacle_gang"
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled = false
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(.025,.03,.035)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(.15,.16,.2)
	settings.ambient_light_energy = .12
	environment.environment = settings
	add_child(environment)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6,.1,6)
	collision.shape = shape
	floor_body.add_child(collision)
	floor_body.position.y = -.05
	add_child(floor_body)
	var floor_draw := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	floor_draw.mesh = box
	floor_body.add_child(floor_draw)
	var radiator := RadiatorProp.new()
	radiator.use_native_v2 = true
	radiator.position = Vector3(.35,0,.6)
	preload("res://scripts/building/orison_v2_heating.gd").new()._add_collision(radiator)
	add_child(radiator)
	player = PlayerController.new()
	add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	player.position = Vector3(0,0,-1.3)
	player.camera.position.y = 1.0
	player.camera.fov = 45
	player.camera.look_at(Vector3(.25,.35,.15))
	player.camera.make_current()
	review_pose = player.camera.global_transform
	player.mouse_released = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for canvas in player.find_children("*","CanvasLayer",true,false): canvas.visible = false
	var atmosphere := preload("res://scripts/building/orison_v2_lamp_atmosphere.gd").new()
	atmosphere.name = "LampAtmosphere"
	add_child(atmosphere)
	check(atmosphere.setup(player,settings),"shared production lamp atmosphere starts")
	lamp_driver = atmosphere.driver
	player.set_lamp_enabled(true)
	for i in 240: atmosphere.driver.advance_frame(1.0/120.0)
	await get_tree().physics_frame
	var orders := WorkOrders.new()
	add_child(orders)
	orders.bind_job_library(MaintenanceJobLibrary.load_default())
	var observer := preload("res://scripts/dream/entity/maintenance_tentacle_observer.gd").new()
	add_child(observer)
	observer.setup(self,player,orders)
	observer.set_physics_process(false)
	var prepared_ids := {}
	var prepared_resources: Array[WeakRef] = []
	for draw: MeshInstance3D in observer.preparation.root.find_children("*","MeshInstance3D",true,false):
		prepared_ids[draw.mesh.get_instance_id()] = true
		prepared_resources.append(weakref(draw.mesh))
	for material in observer.preparation.materials:
		for channel in ["albedo","normal","roughness"]:
			var texture: Texture2D = material.get_shader_parameter(channel+"_map")
			prepared_ids[texture.get_instance_id()] = true
			prepared_resources.append(weakref(texture))
	check(observer.preparation.contacts.is_empty() and observer.preparation.sounds.is_empty() and not observer.preparation.visible,"loading preparation has no contacts sounds or visible encounter")
	for frame in 3: await RenderingServer.frame_post_draw
	observer.frequency_divisor = 1
	var prior_jobs: Dictionary = RealityState.data.get("maintenance_jobs",{}).duplicate(true)
	RealityState.data.maintenance_jobs = {}
	observer._physics_process(1.0)
	check(observer.encounter==null,"no active task creates no encounter")
	var job_id := "lena_radiator_round_2b"
	radiator.name = str(orders.job_library.job(job_id).repair_target_id)
	RealityState.data.maintenance_jobs = {job_id:{"stage":"repairable"}}
	var anchor_a: Dictionary = observer.choose_anchor(radiator,34)
	var anchor_b: Dictionary = observer.choose_anchor(radiator,34)
	check(anchor_a==anchor_b,"same seed and geometry select same anchor")
	check(not anchor_a.is_empty(),"working stance has a clear reachable anchor")
	observer._physics_process(1.0)
	check(observer.encounter!=null,"eligible real maintenance target spawns")
	check(orders.job_stage(job_id)=="repairable","spawn cannot advance task stage")
	RealityState.data.maintenance_jobs[job_id].stage = "repaired"
	observer._physics_process(1.0)
	check(observer.encounter!=null and observer.encounter.contact_count==0,"task completion cannot invent physical contact")
	RealityState.data.maintenance_jobs = {}
	observer._physics_process(1.0)
	check(observer.encounter==null,"task removal cleans encounter immediately")
	RealityState.data.maintenance_jobs = prior_jobs
	await get_tree().physics_frame
	check(await operate_supply(radiator,.97),"real maintenance valve operates before encounter")
	var saved := JSON.stringify(RealityState.data)
	var mechanism := radiator.supply_position
	var original_bindings: int = atmosphere.field._materials.size() if atmosphere.field != null else 0
	await wait_seconds(.75)
	gang = Gang.new()
	add_child(gang)
	check(gang.get_child_count()==0 and gang.materials.is_empty(),"dormant owns no visuals or receivers")
	check(gang.start(radiator,player,Transform3D(Basis.IDENTITY,Vector3(.25,0,.15)),34,atmosphere.field),"bounded three-to-seven-limb gang starts")
	check(gang.limbs.size()>=3 and gang.limbs.size()<=7,"bounded limb count")
	check(gang.materials.size()<=3+9*gang.limbs.size(),"identical anatomy stock shares one material per limb")
	var retained: Array[WeakRef] = [weakref(gang.root)]
	for material in gang.materials:
		retained.append(weakref(material))
		for channel in ["albedo","normal","roughness"]:
			var texture: Texture2D = material.get_shader_parameter(channel+"_map")
			if not prepared_ids.has(texture.get_instance_id()): retained.append(weakref(texture))
	for draw: MeshInstance3D in gang.root.find_children("*","MeshInstance3D",true,false):
		if not prepared_ids.has(draw.mesh.get_instance_id()): retained.append(weakref(draw.mesh))
	await wait_seconds(1.0)
	await capture("01_emergence")
	await wait_phase(Gang.Phase.INTERFERING,10.0)
	check(gang.phase==Gang.Phase.INTERFERING,"emergence progresses to interference")
	await wait_seconds(3.0)
	check(gang.apparatus_contact_events>0,"manipulator pads reach actual apparatus surfaces")
	check(await operate_supply(radiator,.93),"real maintenance valve operates during encounter")
	check(await operate_supply(radiator,mechanism),"player restores valve while gang remains")
	await aim_lamp(player.camera.global_position)
	await capture("02_front")
	await capture_clearances()
	await aim_lamp(Vector3(-1,.55,0))
	await capture("02b_side")
	await aim_lamp(Vector3(0,.55,1))
	await capture("02c_back")
	await aim_lamp(player.camera.global_position)
	await capture("02d_stable")
	atmosphere.driver.state.steady_supply = false
	atmosphere.driver.state.apply_mechanical_shock(.9)
	await wait_seconds(.1)
	await capture("02e_unstable")
	atmosphere.driver.state.steady_supply = true
	for i in 240: atmosphere.driver.advance_frame(1.0/120.0)
	var blocker := MeshInstance3D.new()
	var blocker_box := BoxMesh.new()
	blocker_box.size = Vector3(.06,.8,.55)
	blocker.mesh = blocker_box
	blocker.position = Vector3(-.5,.45,0)
	await aim_lamp(Vector3(-1,.55,0))
	add_child(blocker)
	await wait_seconds(.25)
	await capture("02f_occluder")
	check(float(optical_measurements["02f_occluder"]) < float(optical_measurements["02b_side"])*.5,"side blocker attenuates visible organism without covering camera")
	blocker.queue_free()
	await get_tree().physics_frame
	for material in gang.materials:
		for channel in ["albedo","normal","roughness"]:
			var texture: Texture2D = material.get_shader_parameter(channel+"_map")
			check(texture!=null and texture.get_image().has_mipmaps(),"loaded "+channel+" mip chain")
	player.set_lamp_enabled(false)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not atmosphere.field.enabled,"logical lamp off immediately disables shared optical field")
	await wait_seconds(2.0) # Native filament cooling remains owned by the lamp driver.
	await capture("03_lamp_off")
	check(float(optical_measurements["03_lamp_off"]) < float(optical_measurements["02_front"])*.2,"lamp off removes rendered response after native filament cooling")
	check(gang.phase==Gang.Phase.INTERFERING,"lamp switch cannot trigger retreat")
	player.set_lamp_enabled(true)
	await aim_lamp(player.camera.global_position)
	var pad := gang.contacts[0].get_child(0) as CollisionShape3D
	player.camera.look_at(pad.global_position)
	await get_tree().physics_frame
	check(player._grab.find_target().get("owner")==gang,"real ray selects represented contact pad")
	check(gang.contact_count==0,"ray and proximity do not touch")
	click()
	check(player._grab.active(),"actual primary click grabs pad")
	check(gang.contact_count==0,"grab without compression does not alarm")
	for i in 12:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(0,12)
		player._unhandled_input(motion)
		await get_tree().physics_frame
		if gang.contact_count>0: break
	check(gang.contact_count==1,"actual mouse compression latches physical contact once")
	await capture("04_contact")
	click()
	check(not player._grab.active(),"second click releases pad")
	await wait_seconds(.18)
	await capture("04b_alarm")
	await wait_phase(Gang.Phase.COORDINATED_RETREAT,2.0)
	await wait_seconds(.9)
	await capture("05_retreat")
	check(gang.phase==Gang.Phase.COORDINATED_RETREAT,"alarm leads to coordinated retreat")
	await wait_seconds(1.15)
	await capture("06_root_withdrawal")
	await wait_phase(Gang.Phase.PURPLE_HAZE,2.0)
	await wait_seconds(.15)
	check(gang.phase==Gang.Phase.PURPLE_HAZE,"body releases into bounded haze")
	await capture("07_haze")
	gang.haze.visible = false
	await wait_seconds(.2)
	await capture("07b_hidden_haze_control")
	check(absf(float(optical_measurements["07_haze"])-float(optical_measurements["07b_hidden_haze_control"]))>.001,"haze makes a measurable rendered contribution")
	gang.haze.visible = true
	player.set_lamp_enabled(false)
	await wait_seconds(.2)
	await capture("07c_haze_lamp_off")
	player.set_lamp_enabled(true)
	await wait_seconds(2.0)
	await capture("08_haze_late")
	await wait_phase(Gang.Phase.CLEARED,10.0)
	check(gang.phase==Gang.Phase.CLEARED,"haze ends")
	check(gang.get_child_count()==0 and gang.materials.is_empty() and gang.haze_material==null,"body and haze references released")
	for reference in retained: check(reference.get_ref()==null,"new body/material allocation released")
	if atmosphere.field != null: check(atmosphere.field._materials.size()==original_bindings,"shared optical receiver census restored")
	check(gang.contact_count==1,"retreat remains latched")
	check(JSON.stringify(RealityState.data)==saved,"no maintenance inventory save or case mutation")
	check(is_equal_approx(radiator.supply_position,mechanism),"mechanism authority untouched")
	check(await operate_supply(radiator,.95),"real maintenance valve operates after cleanup")
	check(await operate_supply(radiator,mechanism),"player restores valve after cleanup")
	await capture("09_clean")
	await wait_seconds(.75)
	var cancelled := Gang.new()
	add_child(cancelled)
	cancelled.start(radiator,player,Transform3D.IDENTITY,34,atmosphere.field)
	cancelled.cleanup()
	check(cancelled.get_child_count()==0 and cancelled.phase==Gang.Phase.CLEARED,"abort releases immediately")
	cancelled.queue_free()
	observer.free()
	for frame in 3: await RenderingServer.frame_post_draw
	for reference in prepared_resources: check(reference.get_ref()==null,"world preparation releases shared asset allocation")
	check(logger.errors.is_empty(),"no engine script or shader errors")
	times.sort()
	var performance := {}
	for label in phase_times:
		var samples: Array = phase_times[label]
		samples.sort()
		performance[label] = {"frames":samples.size(),"median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*.95)],"max_ms":samples[-1]}
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2",
		"production_runtime":false,"scope":"Isolated production gang, native radiator, shared lamp and actual grab/motion/release. Does not prove composed-world eligibility or visual acceptance.",
		"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},"build_profile":gang.build_profile,
		"source":{"test_path":"game/tests/maintenance_tentacle_gang_test.gd","test_sha256":get_script().source_code.replace("\r\n","\n").sha256_text()},
		"contracts":{"lifecycle":{"executed":true,"status":"PASS" if failures.is_empty() else "FAIL"}},
		"checks":checks,"failures":failures,"engine_errors":logger.errors,"history":gang.history,"apparatus_contact_events":gang.apparatus_contact_events,"contact_diagnostics":gang.contact_diagnostics,"performance_by_phase":performance,"optical_roi_luminance":optical_measurements,"frame_ms_p95":times[int(times.size()*.95)] if not times.is_empty() else 0}
	FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	OS.remove_logger(logger)
	get_tree().quit(0 if failures.is_empty() else 1)
