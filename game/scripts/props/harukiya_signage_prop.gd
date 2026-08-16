class_name HarukiyaSignageProp
extends FunctionalProp
## The bar finally says its name — and says it the way a basement izakaya
## would, which is everything the Orison's neon is not.
##
## Three sign technologies, none of them tube neon:
##   - a weathered timber BOARD on the fascia carrying 春木屋 in worn
##     painted strokes (the canonical Akira sign is the kanji), romaji
##     subline for the trade; lit from OUTSIDE by two gooseneck
##     incandescent trough lights, the pre-neon shopfront convention
##   - a red CHOCHIN paper lantern on a bracket arm — the izakaya's own
##     "we are open" signal (the lantern is lit when the bar is, and
##     taken in when it closes for the day), red against the teal
##     stairwell per Otomo's own staircase composition
##   - a battered marquee BULB ARROW pointing down the stair, two bulbs
##     dead, because the bar is below grade and the sign's whole job is
##     the word "down"
##
## No CJK font ships with the project, so the kanji are stroke-built
## geometry — painted slats, not glyphs — which also reads correctly as
## a hand-painted board. Facing: local +Z is the street side; the marker
## yaw points it at the Orison across the right-of-way.
##
## HarukiyaStateDirector drives set_bar_state(): OPEN lights everything,
## AFTER-HOURS leaves the lantern hanging dark, CLOSED takes it in.

const TIMBER := Color(0.15, 0.115, 0.085)
const PAINT := Color(0.85, 0.82, 0.72)
const CREAM := Color(0.88, 0.84, 0.72)
const LAMP_WARM := Color(1.0, 0.78, 0.52)

## Stroke tables per kanji, unit square, y up: [x0, y0, x1, y1].
const KANJI := {
	"haru": [
		[0.15, 0.80, 0.85, 0.80], [0.10, 0.66, 0.90, 0.66],
		[0.04, 0.52, 0.96, 0.52], [0.50, 0.70, 0.06, 0.24],
		[0.50, 0.70, 0.94, 0.24], [0.30, 0.34, 0.70, 0.34],
		[0.30, 0.34, 0.30, 0.05], [0.70, 0.34, 0.70, 0.05],
		[0.30, 0.05, 0.70, 0.05], [0.30, 0.19, 0.70, 0.19],
	],
	"ki": [
		[0.50, 0.88, 0.50, 0.04], [0.06, 0.60, 0.94, 0.60],
		[0.48, 0.58, 0.10, 0.14], [0.52, 0.58, 0.90, 0.14],
	],
	"ya": [
		[0.10, 0.88, 0.90, 0.88], [0.90, 0.88, 0.90, 0.64],
		[0.10, 0.64, 0.90, 0.64], [0.10, 0.88, 0.10, 0.26],
		[0.10, 0.26, 0.26, 0.06], [0.28, 0.50, 0.80, 0.50],
		[0.36, 0.38, 0.74, 0.38], [0.55, 0.50, 0.55, 0.08],
		[0.24, 0.08, 0.86, 0.08],
	],
}

var _lantern_pivot: Node3D
var _lantern_mat: StandardMaterial3D
var _lantern_light: OmniLight3D
var _spots: Array[SpotLight3D] = []
var _gooseneck_mats: Array[StandardMaterial3D] = []
var _arrow_mats: Array[StandardMaterial3D] = []
var _time := 0.0
var _bar_state := 0
var _inspection_tap: AudioStreamPlayer3D


func _build_visual() -> void:
	# -- the board, on the fascia over the stair slot
	make_box(Vector3(2.35, 0.55, 0.05), Vector3(0, 0, 0), TIMBER)
	var cells := ["haru", "ki", "ya"]
	for i in cells.size():
		var cx := -0.52 + 0.52 * i
		for s in KANJI[cells[i]]:
			_paint_stroke(cx, s)
	var romaji := Label3D.new()
	romaji.text = "HARUKIYA  ·  BAR  ·  KARAOKE"
	romaji.font_size = 40
	romaji.pixel_size = 0.0026
	romaji.modulate = CREAM
	romaji.position = Vector3(0, -0.20, 0.035)
	add_child(romaji)
	# -- gooseneck trough lights washing the board from above
	for gx in [-1.02, 1.02]:
		make_cyl(0.014, 0.014, 0.12, Vector3(gx, 0.36, 0.015),
				Color(0.12, 0.12, 0.13), 0.4, 0.6)
		var arm := make_cyl(0.012, 0.012, 0.36,
				Vector3(gx, 0.43, 0.19), Color(0.12, 0.12, 0.13), 0.4, 0.6)
		arm.rotation.x = PI * 0.5
		make_cyl(0.022, 0.095, 0.10, Vector3(gx, 0.41, 0.36),
				Color(0.10, 0.11, 0.12), 0.35, 0.55)
		var bulb := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.022
		bs.height = 0.044
		bulb.mesh = bs
		bulb.position = Vector3(gx, 0.365, 0.36)
		var bm := _pmat(Color(0.95, 0.85, 0.62))
		bm.emission_enabled = true
		bm.emission = LAMP_WARM
		bm.emission_energy_multiplier = 1.4
		bulb.material_override = bm
		add_child(bulb)
		_gooseneck_mats.append(bm)
		var spot := SpotLight3D.new()
		spot.position = Vector3(gx, 0.38, 0.35)
		spot.rotation.x = -PI * 0.70   # down and back onto the board
		spot.light_color = LAMP_WARM
		spot.light_energy = 1.5
		spot.spot_range = 2.4
		spot.spot_angle = 55.0
		spot.shadow_enabled = false
		add_child(spot)
		_spots.append(spot)
	# -- the chochin, on a bracket arm clear of the stair slot
	var arm2 := make_cyl(0.013, 0.013, 0.42, Vector3(1.42, 0.32, 0.13),
			Color(0.13, 0.12, 0.11), 0.5, 0.5)
	arm2.rotation.x = PI * 0.5
	_lantern_pivot = Node3D.new()
	_lantern_pivot.position = Vector3(1.42, 0.32, 0.32)
	add_child(_lantern_pivot)
	make_cyl(0.008, 0.008, 0.18, Vector3(0, -0.09, 0),
			Color(0.1, 0.09, 0.08), 0.8, 0.0, _lantern_pivot)
	make_cyl(0.09, 0.09, 0.05, Vector3(0, -0.20, 0),
			Color(0.08, 0.07, 0.06), 0.7, 0.0, _lantern_pivot)
	var lantern := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.20
	cap.height = 0.60
	lantern.mesh = cap
	lantern.position = Vector3(0, -0.53, 0)
	_lantern_mat = _pmat(Color(0.72, 0.14, 0.08), 0.85)
	_lantern_mat.emission_enabled = true
	_lantern_mat.emission = Color(1.0, 0.30, 0.10)
	_lantern_mat.emission_energy_multiplier = 1.7
	lantern.material_override = _lantern_mat
	_lantern_pivot.add_child(lantern)
	make_cyl(0.09, 0.09, 0.05, Vector3(0, -0.86, 0),
			Color(0.08, 0.07, 0.06), 0.7, 0.0, _lantern_pivot)
	_lantern_light = OmniLight3D.new()
	_lantern_light.position = Vector3(0, -0.53, 0)
	_lantern_light.light_color = Color(1.0, 0.45, 0.18)
	_lantern_light.light_energy = 1.15
	_lantern_light.omni_range = 3.0
	_lantern_light.shadow_enabled = false
	_lantern_pivot.add_child(_lantern_light)
	# -- the bulb arrow on the east jamb: DOWN, it says, two bulbs gone
	make_box(Vector3(0.30, 0.85, 0.03), Vector3(-0.95, -0.62, 0.02),
			Color(0.10, 0.10, 0.11))
	var drops := [Vector2(0, 0.30), Vector2(0, 0.14), Vector2(0, -0.02),
			Vector2(0, -0.18), Vector2(-0.09, -0.10), Vector2(0.09, -0.10),
			Vector2(0, -0.30)]
	for i in drops.size():
		var b := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.026
		sph.height = 0.052
		b.mesh = sph
		b.position = Vector3(-0.95 + drops[i].x, -0.62 + drops[i].y, 0.045)
		if i in [1, 5]:     # the dead ones
			b.material_override = _pmat(Color(0.35, 0.33, 0.30), 0.4)
		else:
			var lm := _pmat(Color(0.95, 0.80, 0.55))
			lm.emission_enabled = true
			lm.emission = Color(1.0, 0.70, 0.32)
			lm.emission_energy_multiplier = 2.2
			b.material_override = lm
			_arrow_mats.append(lm)
		add_child(b)
	var bar_label := Label3D.new()
	bar_label.text = "BAR"
	bar_label.font_size = 34
	bar_label.pixel_size = 0.0028
	bar_label.modulate = CREAM
	bar_label.position = Vector3(-0.95, -1.13, 0.03)
	add_child(bar_label)
	_inspection_tap = make_emitter("creak", -23.0)
	_inspection_tap.pitch_scale = 1.18


## The low arrow is the hand-height service/read point for the complete
## frontage assembly.  Kanji strokes, bulbs, board lamps and the lantern stay
## child geometry of this one owner.
func _build_primary_interaction() -> void:
	var area := Area3D.new()
	area.name = "HarukiyaSignInspection"
	area.collision_layer = 1
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.add_to_group("functional_interaction_areas")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.44, 1.18, 0.30)
	collision.shape = shape
	collision.position = Vector3(-0.95, -0.72, 0.17)
	area.add_child(collision)
	add_child(area)


func interact_prompt() -> String:
	return "[E]  Inspect Harukiya frontage sign"


func interact(_player: Node) -> Dictionary:
	if _inspection_tap:
		_inspection_tap.play()
	return service_wire_card()


func service_wire_card() -> Dictionary:
	var hours: String = ["OPEN", "AFTER HOURS", "CLOSED"][_bar_state]
	var light: String = "BOARD LAMPS AND LANTERN LIT / TWO ARROW BULBS DEAD"
	if _bar_state == 1:
		light = "DARK / LANTERN HANGING DARK"
	elif _bar_state == 2:
		light = "DARK / LANTERN TAKEN IN"
	return PropServiceWire.card("shop_sign", {
		"face_state": "HARUKIYA / PAINTED TIMBER / DOWN ARROW",
		"light_state": light,
		"hours_state": hours,
	})


func _paint_stroke(cell_x: float, s: Array) -> void:
	var a := Vector2(cell_x - 0.21 + float(s[0]) * 0.42,
			-0.12 + float(s[1]) * 0.40)
	var b := Vector2(cell_x - 0.21 + float(s[2]) * 0.42,
			-0.12 + float(s[3]) * 0.40)
	var mid := (a + b) * 0.5
	var stroke := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(a.distance_to(b) + 0.030, 0.045, 0.012)
	stroke.mesh = box
	stroke.position = Vector3(mid.x, mid.y, 0.032)
	stroke.rotation.z = atan2(b.y - a.y, b.x - a.x)
	stroke.material_override = _pmat(PAINT, 0.85)
	add_child(stroke)


## 0 = OPEN, 1 = AFTER_HOURS (lantern hangs dark), 2 = CLOSED (taken in).
func set_bar_state(bar_state: int) -> void:
	_bar_state = clampi(bar_state, 0, 2)
	var open := bar_state == 0
	_lantern_pivot.visible = bar_state != 2
	_lantern_mat.emission_energy_multiplier = 1.7 if open else 0.0
	_lantern_light.visible = open
	for spot in _spots:
		spot.visible = open
	for gm in _gooseneck_mats:
		gm.emission_energy_multiplier = 1.4 if open else 0.0
	for am in _arrow_mats:
		am.emission_energy_multiplier = 2.2 if open else 0.0


func _process(delta: float) -> void:
	_time += delta
	if _lantern_pivot and _lantern_pivot.visible:
		_lantern_pivot.rotation.z = sin(_time * 0.9) * 0.040 \
				+ sin(_time * 0.53) * 0.020
