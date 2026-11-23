extends Node
## Presentation only. The street's shadowed lamps, the bodega's practicals and
## the entry vestibule's gas lights each re-render a cube shadow every frame,
## and from an upper floor or down the block nobody can see what those shadows
## fall on: the light itself still reaches the street and the facade. A light
## here keeps its shadow only while an eye (the camera or the mirror's camera)
## is within REACH_M of it, and, for a light indoors, on its own storey; the
## native shadow fade takes the last FADE_M so the shadow thins out rather than
## snapping off. Never changes a light's colour, energy, range or visibility,
## and switching it off gives every shadow back as authored.
const REACH_M := 16.0
const FADE_M := 4.0
const LIGHT_FADE_BEGIN_M := 1000.0

var world: Node3D
var rows: Array[Dictionary] = []
var enabled := false
var _due := 0.0


func setup(owner_world: Node3D) -> bool:
	if world != null:
		return false
	world = owner_world
	process_priority = 111
	set_process(false)
	if is_instance_valid(world.get("exterior_cell")):
		_collect(world.exterior_cell, false)
	var vestibule: Node = world.adapter.root.get_node_or_null("EntryVestibule")
	if vestibule != null:
		_collect(vestibule, true)
	return not rows.is_empty()


func _collect(parent: Node, indoors: bool) -> void:
	for node: Node in parent.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light is DirectionalLight3D or not light.shadow_enabled:
			continue
		rows.append({"light": light, "indoors": indoors, "shadow": true,
			"fade": light.distance_fade_enabled, "begin": light.distance_fade_begin,
			"length": light.distance_fade_length, "shadow_distance": light.distance_fade_shadow,
			"level": _level_at(light.global_position)})


func _level_at(point: Vector3) -> String:
	var pitch: float = float(world.layout.dimensions.floor_to_floor)
	var index: int = int(floor(point.y / pitch))
	return "B%d" % (-index) if index < 0 else "F%02d" % (index + 1)


func set_enabled(value: bool) -> void:
	enabled = value
	set_process(value)
	for row: Dictionary in rows:
		var light: Light3D = row.light
		if not is_instance_valid(light):
			continue
		if value:
			if not row.fade:
				light.distance_fade_enabled = true
				light.distance_fade_begin = LIGHT_FADE_BEGIN_M
				light.distance_fade_length = FADE_M
			light.distance_fade_shadow = REACH_M - light.distance_fade_length
		else:
			light.distance_fade_enabled = row.fade
			light.distance_fade_begin = row.begin
			light.distance_fade_length = row.length
			light.distance_fade_shadow = row.shadow_distance
			light.shadow_enabled = row.shadow
	if value:
		tick()


func _process(delta: float) -> void:
	_due -= delta
	if _due <= 0.0:
		_due = 0.1
		tick()


func eyes() -> Array[Vector3]:
	var found: Array[Vector3] = []
	var camera: Camera3D = world.get_viewport().get_camera_3d()
	if camera == null and is_instance_valid(world.get("player")):
		camera = world.player.camera
	if camera != null:
		found.append(camera.global_position)
	var mirror: Variant = world.get("mirror_renderer")
	if is_instance_valid(mirror):
		var reflected: Camera3D = mirror.active_camera()
		if reflected != null:
			found.append(reflected.global_position)
	return found


func tick() -> void:
	var seen := eyes()
	for row: Dictionary in rows:
		var light: Light3D = row.light
		if not is_instance_valid(light):
			continue
		var wanted := false
		for eye: Vector3 in seen:
			if eye.distance_squared_to(light.global_position) >= REACH_M * REACH_M:
				continue
			if row.indoors and _level_at(eye) != str(row.level):
				continue
			wanted = true
			break
		if light.shadow_enabled != wanted:
			light.shadow_enabled = wanted


func _exit_tree() -> void:
	set_enabled(false)
