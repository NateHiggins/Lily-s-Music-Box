extends "res://tests/door_passage_policy_test.gd"
## Existing lock/save/occupied-motion programme with real opaque native infill.
const Door := preload("res://scripts/building/orison_v2_arcade_shop_door.gd")
const Curtain := preload("res://scripts/building/orison_v2_arcade_darkroom_curtain.gd")
var original_fabric_tint: Color

func make_door() -> DoorProp:
	original_fabric_tint = MatLib.get_mat("fabric_warm").albedo_color
	var frames: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/arcade_door_frames.json"))
	var selected: Dictionary
	for row: Dictionary in frames.frames:
		if row.id == "ARCADE_STOCK_DOOR_PHOTO_SUPPLIES": selected = row
	var door := Door.from_frame(selected)
	# Nearby policy fixture owns the physical world frame; the same stock
	# identity/variant selection is used by the actual fitted-frame programme.
	door.transform = Transform3D.IDENTITY
	door.unit = DoorKeyring.player_unit()
	return door

func additional_checks(door: DoorProp, _carrier: Carrier) -> void:
	_check(not door.get("paired") and door.get("curtained") and door.width == 1., "Photo stock frame selects one opaque curtained leaf")
	_check(door.mechanism_snapshot().keys() == ["angle"], "original one-angle save authority retained")
	_check(door._body.find_child("LeftGlass", true, false) == null, "clear upper glass replaced by opaque cloth")
	var draw := door._body.get_node_or_null("LeftDarkroomCurtain") as MeshInstance3D
	if not _require_cloth(draw): return
	_check(draw.get_parent() == door._body and draw.find_children("*", "CollisionShape3D", true, false).is_empty(), "cloth belongs to existing physical leaf without extra collision/authority")
	var bounds := draw.mesh.get_aabb()
	_check(bounds.position.x >= .13-.000001 and bounds.end.x <= .87+.000001 and bounds.position.y >= .85-.000001 and bounds.end.y <= 2.18+.000001 and bounds.position.z >= -.022 and bounds.end.z <= .022, "actual imported cloth inside unchanged moving wood envelope")
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	metrics._check_cap_mapping(draw.mesh, true)
	_check(metrics.failures.is_empty(), "strict loaded cloth UV/normals/tangent derivatives " + str(metrics.failures))
	metrics.free()
	var material := draw.material_override as ShaderMaterial
	_check(material != null and int(material.get_shader_parameter("uv_mode")) == 0 and material.get_meta("v2_owner_finish") == "shop/fabric_warm", "registered dark original cloth uses authored UV and shop finish")
	for key: String in ["albedo_tex", "rough_tex", "normal_tex"]:
		var texture := material.get_shader_parameter(key) as Texture2D
		_check(texture != null and texture.get_image().has_mipmaps(), "loaded custom curtain map mip chain " + key)
	_check(MatLib.get_mat("fabric_warm").albedo_color == original_fabric_tint, "shared fabric catalogue resource untouched")
	for angle: float in [0., .45, PI * .5]:
		door.restore_mechanism({"angle":angle})
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(is_equal_approx(door._body.rotation.y, angle) and draw.global_transform.is_equal_approx(door._body.global_transform * draw.transform), "cloth follows actual saved-angle leaf " + str(angle))
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Curtain.DATA))
	for kind: String in ["schema", "asset", "source", "import"]:
		var bad := spec.duplicate(true)
		match kind:
			"schema": bad.schema = "wrong"
			"asset": bad.asset_sha256 = "wrong"
			"source": bad.source_sha256_lf = "wrong"
			"import": bad.import_sha256_lf = "wrong"
		var refused := Curtain.new()
		var result := refused.prepare(bad)
		_check(result == null and not refused.errors.is_empty(), "curtain intake refuses " + kind)
		if result != null: result.free()
	await _render(door)

func _require_cloth(draw: MeshInstance3D) -> bool:
	_check(draw != null, "native curtain draw loaded")
	return draw != null

func _render(door: DoorProp) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.06,.07,.08)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .65
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-35,0)
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.65
	for shot: Dictionary in [
		{"angle":0., "eye":Vector3(2.8,1.8,-3.5), "name":"curtain_0.png"},
		{"angle":0., "eye":Vector3(-2.8,1.8,3.5), "name":"curtain_back.png"},
		{"angle":PI*.5, "eye":Vector3(2.8,1.8,-3.5), "name":"curtain_90.png"}]:
		var angle := float(shot.angle)
		door.restore_mechanism({"angle":angle})
		var eye := door.to_global(shot.eye)
		var target := door.to_global(Vector3(.4,1.2,.1))
		camera.look_at_from_position(eye, target)
		# Neutral front lighting for judging the actual black cloth. The first
		# diagnostic lit its reverse and framed the leaf too far away.
		light.look_at_from_position(eye, target)
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_check(get_viewport().get_texture().get_image().save_png(directory.path_join(str(shot.name))) == OK, "rendered actual curtain leaf " + str(shot.name))

func _inputs() -> Dictionary:
	var result: Dictionary = super._inputs()
	for path: String in ["res://tests/arcade_darkroom_door_policy_test.gd", "res://tests/ArcadeDarkroomDoorPolicyTest.tscn", "res://scripts/building/orison_v2_arcade_shop_door.gd", "res://scripts/building/orison_v2_arcade_darkroom_curtain.gd", Curtain.DATA, Curtain.SOURCE, "res://data/orison_v2/arcade_door_leaves.json", "res://tests/fixtures/arcade_door_frames.json"]:
		result[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	for path: String in ["res://assets/props/arcade_darkroom_curtain.glb", "res://assets/props/arcade_door_leaves.glb"]:
		result[path] = FileAccess.get_sha256(path)
		result[path + ".import"] = FileAccess.get_file_as_string(path + ".import").replace("\r\n", "\n").sha256_text()
	return result
