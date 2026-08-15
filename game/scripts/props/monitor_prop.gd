class_name MonitorProp
extends FunctionalProp
## A Vantry domestic picture receiver: signal technology forty years early,
## built into ordinary second-hand stands and cases. Mina and Juno own one;
## Sacha's editing wall owns three. These are displays, not copies of 4B's
## maintenance terminal, and never expose its isolate/capture/route controls.

var _screen_mat: StandardMaterial3D
var _tuning_knob: Node3D
var _tuning_click: AudioStreamPlayer3D
var _tuning_tween: Tween
var _narrow_tuning := false
const FOUND_SCREEN_ATLASES := [
	"res://assets/building/textures/found_art/screens_01.webp",
	"res://assets/building/textures/found_art/screens_02.webp",
]


func _build_visual() -> void:
	var fixed := Node3D.new()
	fixed.name = "ReceiverCase"
	add_child(fixed)
	var black := smat("bakelite_black", Color(0.46, 0.44, 0.40), 0.46)
	var brass := smat("brass_dull", Color(0.55, 0.50, 0.38), 0.58)
	# A single 13-inch portrait plate fits every authored marker. The old class
	# built two panels per marker, which made Sacha's three owners become six
	# screens before H18 briefly made them three complete maintenance desks.
	_box(fixed, Vector3(0.10, 0.36, 0.52), Vector3.ZERO, black)
	_box(fixed, Vector3(0.018, 0.30, 0.46), Vector3(0.058, 0.015, 0), brass)
	_box(fixed, Vector3(0.12, 0.055, 0.24), Vector3(-0.01, -0.205, 0), black)
	var power := make_cyl(0.024, 0.024, 0.025,
			Vector3(0.066, -0.135, -0.17), Color.WHITE, 0.44, 0.0, fixed)
	power.rotation_degrees = Vector3(0, 0, 90)
	power.material_override = black
	_tuning_knob = Node3D.new()
	_tuning_knob.name = "TuningKnob"
	_tuning_knob.position = Vector3(0.066, -0.135, 0.17)
	fixed.add_child(_tuning_knob)
	var tuning := make_cyl(0.024, 0.024, 0.025,
			Vector3.ZERO, Color.WHITE, 0.44, 0.0, _tuning_knob)
	tuning.rotation_degrees = Vector3(0, 0, 90)
	tuning.material_override = black
	merge_static(fixed, [_tuning_knob])
	_build_screen()
	var pool := OmniLight3D.new()
	pool.name = "ReceiverPool"
	pool.light_color = Color(0.46, 0.60, 0.55)
	pool.light_energy = 0.13
	pool.omni_range = 1.35
	pool.omni_attenuation = 2.2
	pool.shadow_enabled = false
	pool.position = Vector3(0.16, 0.04, 0)
	add_child(pool)
	_tuning_click = make_emitter("tick", -21.0)


func _box(parent: Node3D, size: Vector3, at: Vector3,
		mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh := make_box(size, at, Color.WHITE)
	mesh.material_override = mat
	mesh.reparent(parent)
	return mesh


func _build_screen() -> void:
	_screen_mat = StandardMaterial3D.new()
	_screen_mat.albedo_color = Color(0.025, 0.035, 0.032)
	_screen_mat.roughness = 0.30
	var screen_texture := _found_screen_texture()
	if screen_texture:
		_screen_mat.albedo_texture = screen_texture
		_screen_mat.emission_texture = screen_texture
	_screen_mat.emission_enabled = true
	_screen_mat.emission = Color(0.38, 0.62, 0.52)
	_screen_mat.emission_energy_multiplier = 0.55
	var screen := make_box(Vector3(0.008, 0.25, 0.39),
			Vector3(0.071, 0.035, 0), Color.BLACK)
	screen.name = "PicturePlate"
	screen.material_override = _screen_mat


func _found_screen_texture() -> Texture2D:
	var variation := absi(hash(name)) % 8
	var atlas := load(FOUND_SCREEN_ATLASES[variation / 4]) as Texture2D
	if atlas == null:
		return null
	var image := atlas.get_image()
	if image == null or image.is_empty():
		return atlas
	var half := Vector2i(image.get_width() / 2, image.get_height() / 2)
	var col := variation % 2
	var row := (variation % 4) / 2
	var inset := maxi(5, mini(half.x, half.y) / 96)
	var tile := image.get_region(Rect2i(
			Vector2i(col * half.x + inset, row * half.y + inset),
			half - Vector2i(inset * 2, inset * 2)))
	tile.generate_mipmaps()
	return ImageTexture.create_from_image(tile)


func _start_normal_function() -> void:
	state = PState.OPERATING


func interact_prompt() -> String:
	return "[E] Widen receiver tuning" if _narrow_tuning \
			else "[E] Narrow receiver tuning"


## The line-fed picture remains live for case propagation.  E operates the
## receiver's local tuning control instead of becoming a universal evidence-
## erasing power button.
func interact(_player: Node = null) -> Dictionary:
	_narrow_tuning = not _narrow_tuning
	_tuning_click.pitch_scale = 1.06 if _narrow_tuning else 0.95
	_tuning_click.play()
	if _tuning_tween and _tuning_tween.is_valid():
		_tuning_tween.kill()
	_tuning_tween = create_tween()
	_tuning_tween.tween_property(_tuning_knob, "rotation:x",
			deg_to_rad(38.0 if _narrow_tuning else 0.0), 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Immediate local trim, so a later conductor flash owns the material with
	# no competing tween still writing into the case response.
	_screen_mat.emission_energy_multiplier = _picture_energy()
	return service_wire_card()


func service_wire_card() -> Dictionary:
	return PropServiceWire.card("television", {
		"power_state": "LINE LIVE",
		"tuning_state": "NARROW" if _narrow_tuning else "WIDE",
		"picture_state": "SYNCHRONIZED",
	})


func _picture_energy() -> float:
	return 0.42 if _narrow_tuning else 0.55


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_screen_mat.emission_energy_multiplier = _picture_energy() + accent * 0.85
	if Conductor.infection > 0.7:
		_screen_mat.emission = Color(0.30, 0.82, 0.68)
	create_tween().tween_property(_screen_mat,
			"emission_energy_multiplier", _picture_energy(), 0.22)
