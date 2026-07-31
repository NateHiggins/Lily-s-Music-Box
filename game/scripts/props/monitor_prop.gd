class_name MonitorProp
extends FunctionalProp
## The 4B workstation's two monitors. Normal: steady pale glow. Synced:
## brightness flickers tracing the motif; at high infection the color
## temperature slides toward the interface teal.

var _screen_mats: Array[StandardMaterial3D] = []
var _incoming_label: Label3D
const FOUND_SCREEN_ATLASES := [
	"res://assets/building/textures/found_art/screens_01.webp",
	"res://assets/building/textures/found_art/screens_02.webp",
]


func _build_visual() -> void:
	for i in 2:
		var off := Vector3(0, 0.24, -0.19 + i * 0.38)
		make_box(Vector3(0.03, 0.34, 0.55), off, Color(0.1, 0.1, 0.11))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.05, 0.06, 0.07)
		var screen_texture := _found_screen_texture(i)
		if screen_texture != null:
			mat.albedo_texture = screen_texture
		mat.emission_enabled = true
		mat.emission = Color(0.55, 0.62, 0.66)
		if screen_texture != null:
			mat.emission_texture = screen_texture
		mat.emission_energy_multiplier = 0.7
		var screen := make_box(Vector3(0.005, 0.30, 0.51),
				off + Vector3(0.018, 0, 0), Color.BLACK)
		screen.material_override = mat
		_screen_mats.append(mat)
		# fork stand, cable drop and a power pip: desk hardware, not a slab
		make_cyl(0.022, 0.030, 0.055, off + Vector3(0, -0.265, 0),
				Color(0.14, 0.14, 0.15), 0.4, 0.3)
		make_box(Vector3(0.05, 0.16, 0.035),
				off + Vector3(-0.005, -0.16, 0), Color(0.12, 0.12, 0.13))
		make_cyl(0.004, 0.004, 0.20, off + Vector3(-0.04, -0.20, 0.10),
				Color(0.08, 0.08, 0.08), 0.5)
		make_box(Vector3(0.006, 0.008, 0.008),
				off + Vector3(0.017, -0.145, 0.22), Color(0.3, 0.9, 0.5))
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.68, 0.72)
	light.light_energy = 0.5
	light.omni_range = 2.2
	light.position = Vector3(0.3, 0.3, 0)
	add_child(light)


func _found_screen_texture(screen_index: int) -> Texture2D:
	var variation := absi(hash(name) + screen_index * 5) % 8
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


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	for mat in _screen_mats:
		mat.emission_energy_multiplier = 0.7 + accent * 1.1
		if Conductor.infection > 0.7:
			mat.emission = Color(0.34, 0.9, 0.83)  # the interface teal
		create_tween().tween_property(mat, "emission_energy_multiplier",
				0.7, 0.2)


func show_incoming_call() -> void:
	for mat in _screen_mats:
		mat.emission = Color(0.12, 0.95, 0.78)
		mat.emission_energy_multiplier = 1.6
	if _incoming_label == null:
		_incoming_label = Label3D.new()
		_incoming_label.name = "IncomingCallAlert"
		_incoming_label.text = "INCOMING CALL\nM. CHEN"
		_incoming_label.font_size = 42
		_incoming_label.pixel_size = 0.00145
		_incoming_label.modulate = Color(0.78, 1.0, 0.92)
		_incoming_label.outline_modulate = Color(0.01, 0.04, 0.035)
		_incoming_label.outline_size = 8
		_incoming_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_incoming_label.position = Vector3(0.027, 0.24, 0.0)
		_incoming_label.rotation.y = -PI / 2.0
		_incoming_label.double_sided = true
		add_child(_incoming_label)
	_incoming_label.visible = true
