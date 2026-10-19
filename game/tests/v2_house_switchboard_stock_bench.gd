extends Node3D
## Imported metric charts/bases, separate from played room or custody proof.
const Metrics=preload("res://tests/orison_v2_domestic_native_test.gd")
var failures: int=0

func _ready() -> void:_run.call_deferred()

func _run() -> void:
	RealityState.persistence_enabled=false
	var line: HouseTelephoneNetwork=HouseTelephoneNetwork.new();add_child(line)
	line.register_endpoint({"id":"F02_A_TELEPHONE","extension":"2A"})
	var board: HouseSwitchboardProp=HouseSwitchboardProp.new();board.set_meta("v2_house_switchboard",true);board.bind_line(line);add_child(board)
	await get_tree().physics_frame;await get_tree().physics_frame
	if not board.native_switchboard_ready():
		push_error("Native switchboard refused");get_tree().quit(1);return
	var metrics: Node=Metrics.new()
	for identity: String in board._native_stock.meshes:
		print("SWITCHBOARD IMPORTED STOCK: ",identity)
		metrics._check_cap_mapping(board._native_stock.meshes[identity],true)
	failures=metrics.failures.size()
	var camera: Camera3D=Camera3D.new();add_child(camera);camera.fov=45.;camera.position=Vector3(0,.15,-1.5);camera.look_at(Vector3(0,.15,0));camera.make_current()
	var light: DirectionalLight3D=DirectionalLight3D.new();add_child(light);light.rotation_degrees=Vector3(-35,145,0);light.light_energy=1.2
	var environment: WorldEnvironment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.12,.12,.12);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.5;add_child(environment)
	var directory: String=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		await _capture(directory,"loaded_native_stock")
		# Disposable optical controls distinguish a geometry/normal problem
		# from layered shading. Production maps/materials are restored below.
		var field: MeshInstance3D=board.find_child("JackField",true,false) as MeshInstance3D
		var original: Material=field.material_override
		if original is ShaderMaterial:
			var quiet: ShaderMaterial=original.duplicate() as ShaderMaterial;quiet.set_shader_parameter("normal_scale",0.);field.material_override=quiet
			await _capture(directory,"diagnostic_zero_normal")
		var plain: StandardMaterial3D=MatLib.get_mat("bakelite_black").duplicate() as StandardMaterial3D
		plain.uv1_triplanar=false;plain.uv1_scale=Vector3.ONE/float(MatLib.SETS["bakelite_black"][3]);plain.albedo_color=Color(.18,.17,.16);plain.normal_scale=.015;plain.roughness=.30
		field.material_override=plain;await _capture(directory,"diagnostic_standard_material")
		field.material_override=original
	metrics.free();board.free();line.free();camera.free();light.free();environment.free()
	print("V2 SWITCHBOARD IMPORTED STOCK: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)

func _capture(directory: String,label: String) -> void:
	await get_tree().create_timer(.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
