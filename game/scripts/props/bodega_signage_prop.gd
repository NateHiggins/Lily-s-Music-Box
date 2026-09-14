class_name BodegaSignageProp
extends FunctionalProp
## HALF BAKED, Deli & Grocery — the bodega dressed in the iconic NYC
## vocabulary, which is not neon: a BACKLIT YELLOW AWNING VALANCE (the
## old visibility expedient of every corner deli), dark red block
## letters read as silhouettes on the glowing vinyl, and a PROJECTING
## LIGHTBOX CABINET on the west corner — a double-faced acrylic blade on
## a steel bracket, hung perpendicular to the facade precisely so it
## reads straight-on from the Orison's windows and from down the street.
##
## The geometry pass already builds the canvas awning slab; this prop
## hangs the lit valance off its front edge and adds the cabinet. The
## bodega is the 3 a.m. chapel and never closes, so unlike the bar there
## is no state machine — only a tired fluorescent tube in the cabinet
## that drops out for a second every few minutes, exactly often enough
## to be believed.

const VINYL_YELLOW := Color(0.92, 0.74, 0.16)
const LETTER_RED := Color(0.55, 0.07, 0.06)
const ACRYLIC := Color(0.93, 0.91, 0.84)

var _cabinet_mats: Array[StandardMaterial3D] = []
var _time := 0.0
var _cabinet_dropped := false
var _audio_source_id: StringName = &""


## Bind audio identity independently of the scene node name. This lets the
## generic exterior renderer keep authored identities in data/metadata while
## teardown releases the exact public AudioPolicy source it mounted.
func bind_audio_source(source_id: StringName) -> bool:
	if String(source_id).is_empty():
		return false
	if _audio_source_id != &"" and _audio_source_id != source_id:
		return false
	_audio_source_id = source_id
	return true


func _build_visual() -> void:
	# -- the lit valance, hanging from the awning's front edge
	var valance := make_box(Vector3(4.35, 0.55, 0.05),
			Vector3(0, -0.32, 1.05), VINYL_YELLOW)
	var vm := _pmat(VINYL_YELLOW, 0.7)
	vm.emission_enabled = true
	vm.emission = Color(1.0, 0.80, 0.20)
	vm.emission_energy_multiplier = 1.1
	valance.material_override = vm
	for sx in [-2.175, 2.175]:
		var side := make_box(Vector3(0.05, 0.55, 1.02),
				Vector3(sx, -0.32, 0.53), VINYL_YELLOW)
		side.material_override = vm
	var main := Label3D.new()
	main.text = "HALF BAKED"
	main.font_size = 92
	main.pixel_size = 0.0033
	main.modulate = LETTER_RED
	main.outline_size = 4
	main.outline_modulate = Color(0.30, 0.04, 0.03)
	main.position = Vector3(0, -0.22, 1.085)
	add_child(main)
	var sub := Label3D.new()
	sub.text = "DELI  ·  GROCERY  ·  OPEN 24 HOURS"
	sub.font_size = 34
	sub.pixel_size = 0.0028
	sub.modulate = LETTER_RED
	sub.position = Vector3(0, -0.50, 1.085)
	add_child(sub)
	# -- sidewalk pool under the valance: the light every bodega spills
	var wash := OmniLight3D.new()
	wash.position = Vector3(0, -0.55, 0.65)
	wash.light_color = Color(1.0, 0.88, 0.58)
	wash.light_energy = 0.85
	wash.omni_range = 3.4
	wash.shadow_enabled = false
	add_child(wash)
	# -- the projecting blade cabinet at the west corner
	make_box(Vector3(0.05, 0.10, 0.60), Vector3(-2.05, 0.88, 0.30),
			Color(0.14, 0.14, 0.15))
	make_box(Vector3(0.15, 1.50, 0.60), Vector3(-2.05, 0.42, 0.62),
			Color(0.12, 0.12, 0.13))
	for face_sign in [-1.0, 1.0]:
		var panel := make_box(Vector3(0.02, 1.38, 0.50),
				Vector3(-2.05 + face_sign * 0.085, 0.42, 0.62), ACRYLIC)
		var pm := _pmat(ACRYLIC, 0.6)
		pm.emission_enabled = true
		pm.emission = Color(0.95, 0.93, 0.86)
		pm.emission_energy_multiplier = 1.05
		panel.material_override = pm
		_cabinet_mats.append(pm)
		var text := Label3D.new()
		text.text = "DELI\nGROCERY\nOPEN\n24 HRS"
		text.font_size = 52
		text.pixel_size = 0.0030
		text.modulate = LETTER_RED
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.position = Vector3(-2.05 + face_sign * 0.10, 0.42, 0.62)
		text.rotation.y = face_sign * PI * 0.5
		add_child(text)
	var glow := OmniLight3D.new()
	glow.position = Vector3(-2.05, 0.42, 0.95)
	glow.light_color = Color(0.98, 0.96, 0.88)
	glow.light_energy = 0.45
	glow.omni_range = 2.2
	glow.shadow_enabled = false
	add_child(glow)


## One complete fascia, one owner.  The broad valance is the readable thing
## from the sidewalk; the projecting cabinet and every line of type remain
## child geometry, never independent E targets.
func _build_primary_interaction() -> void:
	var area := Area3D.new()
	area.name = "BodegaSignInspection"
	area.collision_layer = 1
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.add_to_group("functional_interaction_areas")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.45, 0.64, 0.24)
	collision.shape = shape
	# Slightly proud of the canvas valance so its imported awning cannot eat E.
	collision.position = Vector3(0.0, -0.32, 1.19)
	area.add_child(collision)
	add_child(area)


func interact_prompt() -> String:
	return "[E]  Inspect HALF BAKED shop sign"


func interact(_player: Node) -> Dictionary:
	var source_id := _audio_source_id \
			if _audio_source_id != &"" else StringName(name)
	AudioPolicy.present_3d(&"interaction.inspection_read", global_position, 1.0,
			source_id)
	return service_wire_card()


func service_wire_card() -> Dictionary:
	return PropServiceWire.card("shop_sign", {
		"face_state": "HALF BAKED / BACKLIT VINYL AND PROJECTING ACRYLIC",
		"light_state": "CABINET DROPOUT" if _cabinet_dropped \
				else "VALANCE AND CABINET LIT",
		"hours_state": "OPEN 24 HOURS",
	})


func _process(delta: float) -> void:
	_time += delta
	# The cabinet's tired tube: a dropout gate that fires for a beat
	# every few minutes, dimming the acrylic to a quarter, then recovers.
	var gate := pow(maxf(0.0, sin(_time * 0.031 + 1.3)), 60.0)
	var chatter := 0.25 if gate > 0.5 and sin(_time * 31.0) > -0.2 else 1.0
	_cabinet_dropped = chatter < 1.0
	for pm in _cabinet_mats:
		pm.emission_energy_multiplier = 1.05 * chatter
