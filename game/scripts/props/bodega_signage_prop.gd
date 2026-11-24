class_name BodegaSignageProp
extends FunctionalProp
## HALF BAKED · GROCERY, as a 1928 corner grocery would letter it: a painted
## dark-green timber signboard hung from the awning's front rail, gilt
## letters, and a projecting painted blade on its iron bracket at the west
## corner so it reads from the Orison's windows and from down the street.
## Two shaded gooseneck lamps light the board from in front. They burn
## steady: no tube, no dropout, no per-frame work.
##
## Lily's ruling bodega_sign_period_20261124 (2026-11-24) replaced the
## earlier backlit vinyl valance and acrylic lightbox. The shop stays open
## all night. The palette is her November 1 dark green.
##
## The geometry pass already builds the canvas awning slab. The native
## signage fit keeps these primitive indices: 0-2 the board and its two
## returns, 3-4 the blade bracket and frame, 5-6 the blade's painted faces.

const BOARD_GREEN := Color(0.10, 0.22, 0.15)
const GILT := Color(0.86, 0.68, 0.30)
const GILT_SHADOW := Color(0.18, 0.11, 0.03)
const LAMP_IRON := Color(0.16, 0.16, 0.17)
const SHADE_ENAMEL := Color(0.12, 0.26, 0.18)
const LAMP_WARM := Color(1.0, 0.82, 0.56)
## Board-local lamp stations: each arm leaves the board's top edge and
## reaches forward so the shade looks back down at the lettering. The east
## lamp sits on the existing branch termination at the board's top edge.
const LAMP_X := [-1.6875, 1.6875]
const MetreUV := preload("res://scripts/building/v2_metre_box_uv.gd")

## The blade's two painted faces. Kept as the former cabinet list so the
## native fit and the optics review still find two separate face owners.
var _cabinet_mats: Array[StandardMaterial3D] = []
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


func _charted_box(size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var draw := make_box(size, offset, color)
	var box := draw.mesh as BoxMesh
	draw.mesh = MetreUV.chart(box)
	return draw


func _gilt(text: String, size: int, pixel: float, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = pixel
	label.modulate = GILT
	label.outline_size = 4
	label.outline_modulate = GILT_SHADOW
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = at
	add_child(label)
	return label


func _build_visual() -> void:
	# -- the painted board, hanging from the awning's front rail
	var board := make_box(Vector3(4.35, 0.55, 0.05),
			Vector3(0, -0.32, 1.05), BOARD_GREEN)
	var paint := _pmat(BOARD_GREEN, 0.72)
	board.material_override = paint
	for sx in [-2.175, 2.175]:
		var side := make_box(Vector3(0.05, 0.55, 1.02),
				Vector3(sx, -0.32, 0.53), BOARD_GREEN)
		side.material_override = paint
	_gilt("HALF BAKED  ·  GROCERY", 80, 0.0030, Vector3(0, -0.32, 1.085))
	# -- the projecting blade at the west corner, on its iron bracket
	make_box(Vector3(0.05, 0.10, 0.60), Vector3(-2.05, 0.88, 0.30),
			Color(0.14, 0.14, 0.15))
	make_box(Vector3(0.15, 1.50, 0.60), Vector3(-2.05, 0.42, 0.62),
			Color(0.12, 0.12, 0.13))
	for face_sign in [-1.0, 1.0]:
		var panel := _charted_box(Vector3(0.02, 1.38, 0.50),
				Vector3(-2.05 + face_sign * 0.085, 0.42, 0.62), BOARD_GREEN)
		var pm := _pmat(BOARD_GREEN, 0.72)
		panel.material_override = pm
		_cabinet_mats.append(pm)
		var text := _gilt("HALF
BAKED

GROCERY", 46, 0.0030,
				Vector3(-2.05 + face_sign * 0.10, 0.42, 0.62))
		text.rotation.y = face_sign * PI * 0.5
	# -- two shaded gooseneck lamps over the board, steady incandescent
	for x: float in LAMP_X:
		# The arm leaves the board face below its top edge, clear of the
		# awning canvas above, and reaches 0.34 m toward the street.
		_charted_box(Vector3(0.03, 0.03, 0.34), Vector3(x, -0.075, 1.245),
				LAMP_IRON)
		var drop := _charted_box(Vector3(0.03, 0.06, 0.03),
				Vector3(x, -0.105, 1.40), LAMP_IRON)
		drop.name = "LampDrop"
		var shade := make_cyl(0.035, 0.10, 0.11, Vector3.ZERO, SHADE_ENAMEL,
				0.45)
		shade.position = Vector3(x, -0.15, 1.42)
		# Tip the shade's open mouth back toward the board and down.
		shade.rotation = Vector3(deg_to_rad(35.0), 0, 0)
		var lamp := SpotLight3D.new()
		lamp.name = "GooseneckLamp"
		var at := Vector3(x, -0.17, 1.40)
		var aim := Vector3(x * 0.55, -0.40, 1.075)
		lamp.transform = Transform3D(Basis.looking_at(aim - at, Vector3.UP), at)
		lamp.light_color = LAMP_WARM
		lamp.light_energy = 1.6
		lamp.spot_range = 2.6
		lamp.spot_angle = 52.0
		lamp.shadow_enabled = false
		add_child(lamp)


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
		"face_state": "HALF BAKED / PAINTED BOARD AND BLADE, GILT LETTERS",
		"light_state": "TWO SHADED LAMPS LIT",
		"hours_state": "OPEN ALL NIGHT",
	})
