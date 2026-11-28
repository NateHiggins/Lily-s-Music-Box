extends Node3D
## Appearance review only: the compact companion closed, door open and arm typing.
## No mechanical, input or campaign claim; the benches own those.
var rig: Node3D
var arm: Node3D
var register: Node3D
var camera: Camera3D
var failures := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	get_tree().create_timer(150).timeout.connect(func(): push_error("Compact review exceeded its time"); get_tree().quit(1))
	_run.call_deferred()

func _run() -> void:
	RealityState.persistence_enabled = false
	var civil := CampaignClock.new()
	civil.configure_date(1929, 5, 24, 21 * 60 + 14)
	rig = preload("res://scripts/device/companion_mechanism.gd").new(); add_child(rig)
	if not rig.build(): get_tree().quit(1); return
	rig.scale = Vector3.ONE * .42; rig.set_process(false)
	rig.device.set_radio_powered(true, false)
	arm = preload("res://scripts/device/companion_typing_arm.gd").new(); rig.typing_arm = arm; rig.add_child(arm)
	if not arm.configure(rig, null, func() -> bool: return true): get_tree().quit(1); return
	register = preload("res://scripts/device/companion_temporal_register.gd").new(); rig.add_child(register); rig.temporal_register = register
	if not register.configure(rig): get_tree().quit(1); return
	register.campaign_clock = civil
	register.refresh_campaign_date(0, true)
	var environment := WorldEnvironment.new(); var state := Environment.new()
	state.background_mode = Environment.BG_COLOR; state.background_color = Color(.16, .15, .14)
	state.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; state.ambient_light_color = Color(.9, .86, .8); state.ambient_light_energy = .55
	state.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = state; add_child(environment)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-35, -30, 0); key.light_energy = 1.1; key.light_color = Color(1, .93, .82); add_child(key)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-10, 140, 0); fill.light_energy = .35; add_child(fill)
	camera = Camera3D.new(); camera.fov = 24; camera.near = .01; add_child(camera); camera.make_current()
	camera.cull_mask = 0xFFFFF
	for frame in 30: rig._advance_mechanism(1.0 / 60)
	var sweep := AABB()
	var first := true
	for step in 41:
		register._set_opening(float(step) / 40)
		for draw: MeshInstance3D in register.native.find_children("*", "MeshInstance3D", true, false):
			var into_rig: Transform3D = rig.global_transform.affine_inverse() * draw.global_transform
			for vertex: Vector3 in draw.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				if first: sweep = AABB(into_rig * vertex, Vector3.ZERO); first = false
				else: sweep = sweep.expand(into_rig * vertex)
	register._set_opening(0)
	print("COMPACT REVIEW register sweep in rig ", sweep.position, " to ", sweep.end)
	await views("closed")
	var keys: Array[String] = ["H", "E", "L", "L", "O"]
	if not arm.begin(keys): push_error("arm refused"); failures += 1
	arm.set_process(false)
	var stage := 0
	for frame in 6000:
		rig._advance_mechanism(1.0 / 120); arm.advance(1.0 / 120)
		if stage == 0 and arm.phase == "waiting": stage = 1; await views("door_open")
		if stage == 1 and arm.phase == "deploy" and arm.elapsed > (arm.PREOPEN_END + arm.DEPLOY_END) * .5: stage = 2; await views("emerging")
		if stage == 2 and arm.phase == "press" and arm._stroke > .9: stage = 3; await views("typing")
		if not arm.active(): break
	for frame in 60: rig._advance_mechanism(1.0 / 60)
	await views("closed_again")
	print("COMPACT REVIEW stage=", stage, " failures=", failures)
	get_tree().quit(0 if failures == 0 and stage == 3 else 1)

func views(label: String) -> void:
	var focus := Vector3(0, -.006, .01)
	var set := {"front": Vector3(.10, .05, .40), "starboard": Vector3(.40, .04, .12), "port": Vector3(-.40, .04, .12),
		"rear": Vector3(.22, .08, -.36), "above": Vector3(.12, .36, .22), "below": Vector3(.16, -.30, .26)}
	for name: String in set:
		camera.position = set[name]; camera.look_at(focus)
		for frame in 3: await RenderingServer.frame_post_draw
		if get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(label + "_" + name + ".png")) != OK: failures += 1
