extends BakedFurnitureInteraction
## The lounge cabinet keeps the original record motor, music catalogue and coin state.
const MODEL := "res://assets/props/harukiya_jukebox.glb"
const GripArea := preload("res://scripts/props/manipulation_area.gd")
const PART_KEYS := {"Selector": "bakelite", "CoinReturn": "brass_bright", "glassish": "glass_reeded"}
var ready_for_play := false
var _held: MeshInstance3D
var _travel := 0.0
var _actuated := false
var _title_strip: Label3D

func _build_jukebox_control() -> void:
	var packed := load(MODEL) as PackedScene
	if packed == null: return
	var cabinet := packed.instantiate() as Node3D
	if cabinet == null: return
	add_child(cabinet)
	var selector: MeshInstance3D
	var coin_return: MeshInstance3D
	for mesh: MeshInstance3D in cabinet.find_children("*", "MeshInstance3D", true, false):
		var part := str(mesh.name)
		var key := str(PART_KEYS.get(part, part))
		if not MatLib.SETS.has(key) or mesh.mesh.get_surface_count() != 1: return
		var finish := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		finish.uv1_triplanar = false
		finish.uv1_scale = Vector3.ONE / float(MatLib.SETS[key][3])
		mesh.mesh = mesh.mesh.duplicate() as ArrayMesh
		mesh.mesh.surface_set_material(0, finish)
		mesh.set_meta("material_key", key)
		match part:
			"Selector": selector = mesh
			"CoinReturn": coin_return = mesh
			"milk_glass":
				_jukebox_sign_material = finish
				finish.emission = Color(.98, .51, .18)
				finish.emission_energy_multiplier = .85
				var glass := mesh.get_aabb()
				_title_strip = Label3D.new()
				_title_strip.name = "RecordTitle"
				_title_strip.font_size = 48
				_title_strip.pixel_size = .00115
				_title_strip.outline_size = 0
				_title_strip.double_sided = false
				_title_strip.modulate = Color(.10, .054, .027)
				_title_strip.position = Vector3(glass.get_center().x, glass.get_center().y, glass.end.z + .002)
				mesh.add_child(_title_strip)
	if selector == null or coin_return == null or _jukebox_sign_material == null: return
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.92, 1.585, .62)
	collision.shape = shape
	collision.position.y = shape.size.y * .5
	add_child(collision)
	GripArea.install(selector, _grip.bind(selector, false))
	GripArea.install(coin_return, _grip.bind(coin_return, true))
	_build_jukebox_audio()
	ready_for_play = true

func _refresh_jukebox_title() -> void:
	super._refresh_jukebox_title()
	_title_strip.text = _jukebox_title

func _grip(part: MeshInstance3D, is_return: bool) -> Dictionary:
	var stroke := .040 if is_return else .018
	var axis := Vector3.BACK if is_return else Vector3.FORWARD
	return {"owner": self, "part": part, "frame": self, "kind": "slide", "axis": axis,
		"minimum": 0.0, "maximum": stroke, "gesture_travel_px": 28.0,
		"gesture_screen_axis": Vector2.DOWN if is_return else Vector2.UP,
		"read": func(): return _travel,
		"begin": func():
			if _held != null: return false
			_held = part
			_actuated = false
			return true,
		"owns": func(): return _held == part,
		"write": func(value: float):
			if _held != part: return
			_travel = clampf(value, 0, stroke)
			part.position = axis * _travel
			if not _actuated and _travel >= stroke * .85:
				_actuated = true
				if is_return: _return_jukebox_coin()
				else: _start_jukebox_record(),
		"end": func():
			part.position = Vector3.ZERO
			_travel = 0.0
			_held = null}

# The case wall and moving controls share a record id. Only the two visible
# moving parts accept player input on this cabinet.
func interact_prompt() -> String: return ""
func interact(_player: Node = null) -> Dictionary: return {}
func interact_control(_id: String, _player: Node = null) -> Dictionary: return {}

func _exit_tree() -> void:
	if _jukebox_player != null:
		_jukebox_player.stop()
		_jukebox_player.stream = null
	if _control_click != null:
		var click := _control_click.stream
		_control_click.stop()
		_control_click.stream = null
		if click != null: PropAudio.release_stream("tick", click)
