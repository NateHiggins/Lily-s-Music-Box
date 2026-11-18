extends "res://tests/orison_v2_connected_exterior_route_test.gd"

const StreetPlay := preload("res://scripts/game/street_rock_play.gd")


func _init() -> void:
	route_label = "STREET STONE EXTERIOR"


func _prepare_player_start() -> void:
	# Begin on the public pavement so this check does not depend on entry
	# door fixtures or whether a resident happens to be opening one.
	player.global_position = Vector3(0.0, 0.03, 3.2)
	player.velocity = Vector3.ZERO


func _route() -> void:
	var play := world.get_node_or_null("StreetRockPlay") as StreetPlay
	if not _require(play != null, "the normal V2 exterior owns street play"):
		return
	if not _require(play._stones.size() == StreetPlay.SITES.size(), "every outdoor site has physical support"):
		return
	var stone := play._stones[2]
	for placed in play._stones:
		print("STREET PLACEMENT: ", placed.name, " ", placed.global_position)
	var draw := stone.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var surface := draw.material_override as ShaderMaterial
	var mesh := draw.mesh as ArrayMesh
	_require(surface != null and mesh != null and (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV) != 0,
			"stone render uses authored UVs and the shared PBR shader")
	for map_name in ["albedo_tex", "normal_tex", "rough_tex"]:
		var texture := surface.get_shader_parameter(map_name) as Texture2D
		_require(texture != null and texture.get_image().has_mipmaps(), "loaded mipmaps for " + map_name)
	if not await _walk_world(Vector3(0.8, 0.0, 3.2)):
		return
	player.face_world_point(stone.global_position)
	await get_tree().create_timer(0.2).timeout
	if not _require(play._target == stone, "a real outdoor stance presents the kick prompt"):
		return
	if DisplayServer.get_name() != "headless":
		await _capture_interaction("street_stone_prompt")
	var before := stone.global_position
	var kick := InputEventKey.new()
	kick.physical_keycode = KEY_G
	kick.pressed = true
	Input.parse_input_event(kick)
	await get_tree().create_timer(0.27).timeout
	kick = InputEventKey.new()
	kick.physical_keycode = KEY_G
	Input.parse_input_event(kick)
	_require(play.links > 0 and stone.global_position.distance_to(before) > 0.2,
			"the outdoor kick starts a combo and moves its rock")
	if DisplayServer.get_name() != "headless":
		await _capture_interaction("street_stone_combo")
