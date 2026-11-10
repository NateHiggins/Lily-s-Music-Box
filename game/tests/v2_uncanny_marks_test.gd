extends Node
## The rare uncanny marks on V2 wear (v1r_uncanny_marks_20261109): six fixed
## traces, one to a storey, each projected onto a clear stretch of real hall
## wall, from textures with full mip chains, and far outnumbered by the
## ordinary wear around them. With SHOT_DIR set in a windowed run it also
## writes one review capture of each mark.

const TEXTURES := ["uncanny_condensation", "uncanny_pressure", "uncanny_crack", "uncanny_streak"]
const STOREYS := ["B1", "F02", "F03", "F04", "F05", "F06"]

var _fails := 0
var _checks := 0
var _feet := Vector3.ZERO
var _look := Vector3.ZERO
var _pinned := false
var _world: Node3D


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _process(_delta: float) -> void:
	# The opening moves the player after startup; hold the stance every frame.
	if not _pinned or _world == null or not is_instance_valid(_world.player):
		return
	_world.player.global_position = _feet
	_world.player.camera.look_at(_look)
	var companion: Variant = _world.get("service_set_carrier")
	if companion is Node3D:
		(companion as Node3D).visible = false


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(_world)
	while not _world.startup_failed and _world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not _world.startup_failed, "the V2 world starts")
	var wear: Node3D = null
	for node in _world.find_children("PositionalWear", "Node3D", true, false):
		wear = node
	_check(wear != null, "V2 mounts its positional wear")
	if wear == null:
		_finish()
		return
	var blockout := wear.get_parent() as Node3D
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/positional_wear.json"))
	var into_of: Dictionary = {}
	for row: Dictionary in source.decals:
		into_of[str(row.id)] = Vector3(float(row.into[0]), float(row.into[1]), float(row.into[2]))
	var marks: Array[Decal] = []
	var ordinary := 0
	for decal: Decal in wear.find_children("*", "Decal", false, false):
		if str(decal.get_meta("wear_kind", "")) == "uncanny":
			marks.append(decal)
		else:
			ordinary += 1
	_check(marks.size() == 6, "six uncanny marks in the whole building (%d)" % marks.size())
	_check(ordinary >= marks.size() * 4, "ordinary wear outnumbers them at least four to one (%d to %d)" % [ordinary, marks.size()])
	var storeys: Dictionary = {}
	for mark in marks:
		storeys[str(mark.get_meta("room_id", "")).get_slice("_", 0)] = true
	var one_each := storeys.size() == STOREYS.size()
	for storey: String in STOREYS:
		one_each = one_each and storeys.has(storey)
	_check(one_each, "one to a storey, basement to the sixth floor (%s)" % [storeys.keys()])
	for i in 4:
		await get_tree().physics_frame
	var space := _world.get_world_3d().direct_space_state
	for mark in marks:
		var label := str(mark.name)
		var texture := mark.texture_albedo
		var key := texture.resource_path.get_file().get_basename() if texture != null else ""
		_check(key in TEXTURES, "%s carries one of V1's four traces (%s)" % [label, key])
		_check(_has_mips(texture), "%s's map has a full mip chain" % label)
		_check(mark.modulate.a <= 0.6 and mark.distance_fade_enabled, "%s is faint enough to doubt (%.2f)" % [label, mark.modulate.a])
		# The mark lies on real wall: its centre and its four corners all meet
		# one flat face within the projection box.
		var into: Vector3 = (blockout.global_basis * (into_of[label] as Vector3)).normalized()
		var across := into.cross(Vector3.UP).normalized()
		var flat := 0
		var depths: Array[float] = []
		for corner: Vector2 in [Vector2.ZERO, Vector2(-0.2, -0.24), Vector2(0.2, -0.24), Vector2(-0.2, 0.24), Vector2(0.2, 0.24)]:
			var at := mark.global_position + across * corner.x + Vector3.UP * corner.y
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at - into * 0.3, at + into * 0.3))
			if hit.is_empty():
				continue
			var where: Vector3 = hit.position
			var facing: Vector3 = hit.normal
			var depth := (where - at).dot(into)
			depths.append(depth)
			if absf(depth) <= 0.03 and facing.dot(-into) > 0.98:
				flat += 1
		_check(flat == 5, "%s is projected onto a clear, flat wall (%d of 5 rays; depths %s)" % [label, flat, depths])
	await _capture(marks, blockout, into_of)
	_finish()


## The loaded image answers where there is a renderer to hold one. A headless
## run has none, so there the import policy the image was built under answers.
func _has_mips(texture: Texture2D) -> bool:
	if texture == null:
		return false
	if DisplayServer.get_name() != "headless":
		var image := texture.get_image()
		return image != null and image.has_mipmaps()
	var sidecar := ConfigFile.new()
	return sidecar.load(texture.resource_path + ".import") == OK \
			and bool(sidecar.get_value("params", "mipmaps/generate", false))


## One capture per mark from where a tenant would stand, when asked for: the
## player is stood in the hall so the building lights it as it would in play.
func _capture(marks: Array[Decal], blockout: Node3D, into_of: Dictionary) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var rects: Dictionary = {}
	for space: Dictionary in _world.layout.spaces:
		rects[str(space.id)] = space.rect
	process_priority = 1000
	_world.player.set_physics_process(false)
	_world.player.set_lamp_enabled(false)
	for canvas: CanvasLayer in _world.find_children("*", "CanvasLayer", true, false):
		canvas.hide()
	_world.player.camera.make_current()
	for mark in marks:
		var into := into_of[str(mark.name)] as Vector3
		var across := into.cross(Vector3.UP).normalized()
		var rect: Array = rects[str(mark.get_meta("room_id", ""))]
		var floor_y := mark.position.y - fposmod(mark.position.y, 3.2)
		for view: Array in [["front", -into * 1.3], ["passing", -into * 0.9 + across * 1.7]]:
			var stand := mark.position + (view[1] as Vector3)
			stand.x = clampf(stand.x, float(rect[0]) + 0.32, float(rect[2]) - 0.32)
			stand.z = clampf(stand.z, float(rect[1]) + 0.32, float(rect[3]) - 0.32)
			stand.y = floor_y
			_feet = blockout.to_global(stand)
			_look = mark.global_position
			_pinned = true
			for i in 90:
				await get_tree().process_frame
			for i in 10:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory.path_join("%s_%s.png" % [mark.name, view[0]]))
			print("[V2 UNCANNY MARKS] captured ", mark.name, " ", view[0])
	_pinned = false
	await get_tree().process_frame


func _finish() -> void:
	var ok := _fails == 0
	print("[V2 UNCANNY MARKS] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	if _world.has_method("shutdown_for_tests"):
		_world.shutdown_for_tests()
	remove_child(_world)
	_world.free()
	get_tree().quit(0 if ok else 1)
