extends Node3D
## Building-front dressing on the near city (Lily's ruling city_next_batch_20261117): striped shop awnings and lettered
## signboards over wide ground-floor windows on street-facing sides, painted wall adverts on windowless street-facing
## walls, a rooftop billboard, fire escapes on walk-up street fronts and roof tanks (copies of an existing tank stand)
## where the near city lacked them. Placed by art/blender/scripts/place_city_fronts.py from the elevations record and
## accepted spot by spot in the running world (game/tests/v2_city_fronts_probe.gd). Additive: no installed owner,
## lamp, route, shop or save authority; overhead pieces carry no collision. Lettering is Label3D (RUL-008), authored
## first-draft copy; shop signs read lit after dark from the campaign clock, with no new lights.
const DATA := "res://data/orison_v2/exterior/city_fronts.json"
const ASSET := "res://assets/props/city_fronts.glb"
const TANKS := "res://assets/props/city_tanks.glb"
const FONT := preload("res://assets/fonts/eb_garamond/EBGaramond[wght].ttf")
const FINISHES := ["fabric_warm", "linen", "iron_blackened", "door_paint", "wood_dark", "limewash_plaster", "site_softwood",
	"galvanized_roof", "tank_staves", "iron_neutral", "cast_iron"]
const VISIBLE_M := 260.0
const LETTER_RANGE_M := 120.0

var data: Dictionary = {}
var _materials: Dictionary = {}
var _shop_letters: Array[Label3D] = []
var _clock := CampaignClock.new()
var _check := 0.0
var _lit := false


static func mount(parent: Node3D) -> Node3D:
	if not FileAccess.file_exists(DATA):
		return null
	var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if loaded is not Dictionary or int(loaded.get("schema", 0)) != 1 or str(loaded.get("frame", "")) != "WORLD":
		push_error("city fronts: unexpected schema or frame in " + DATA)
		return null
	var owner_node := new()
	owner_node.name = "CityFronts"
	owner_node.data = loaded
	parent.add_child(owner_node)
	owner_node._build()
	return owner_node


func _build() -> void:
	var scene := (load(ASSET) as PackedScene).instantiate()
	for draw: MeshInstance3D in scene.find_children("fronts_*", "MeshInstance3D", true, false):
		var copy := MeshInstance3D.new()
		copy.name = str(draw.name)
		copy.mesh = draw.mesh
		copy.transform = draw.transform
		copy.material_override = _finish(str(draw.name).get_slice("__", 1), str(draw.name).get_slice("__", 0))
		copy.visibility_range_end = VISIBLE_M
		add_child(copy)
	scene.free()
	_build_tanks()
	for sign: Dictionary in data.get("signs", []):
		_letters(sign, [str(sign.lines[0])], 0.045, Vector2(0.0, 0.0), Color(0.93, 0.82, 0.48), true)
	for advert: Dictionary in data.get("wall_adverts", []):
		_letters(advert, advert.lines, 0.02, Vector2(0.0, 0.0), Color(0.92, 0.88, 0.76), false)
	for board: Dictionary in data.get("billboards", []):
		_letters(board, board.lines, -0.335, Vector2(0.0, 2.0 + float(board.height) * 0.5), Color(0.14, 0.12, 0.10), false)
	_apply_light(_is_night())


## Copies of one existing tank assembly on its stand, moved so its post base stands on each accepted roof point.
func _build_tanks() -> void:
	var stock: Dictionary = data.get("tank_stock", {})
	if stock.is_empty() or (data.get("roof_tanks", []) as Array).is_empty():
		return
	var base_list: Array = stock.base
	var base := Vector3(float(base_list[0]), float(base_list[1]), float(base_list[2]))
	var model := (load(TANKS) as PackedScene).instantiate()
	var parts: Array[MeshInstance3D] = []
	for draw: MeshInstance3D in model.find_children(str(stock.assembly) + "__*", "MeshInstance3D", true, false):
		parts.append(draw)
	for target: Array in data.roof_tanks:
		var shift := Vector3(float(target[0]), float(target[1]), float(target[2])) - base
		for draw: MeshInstance3D in parts:
			var copy := MeshInstance3D.new()
			copy.name = "RoofTank_" + str(draw.name)
			copy.mesh = draw.mesh
			copy.transform = Transform3D(draw.transform.basis, draw.transform.origin + shift)
			copy.material_override = _finish(str(draw.name).get_slice("__", str(draw.name).get_slice_count("__") - 1))
			copy.visibility_range_end = VISIBLE_M
			add_child(copy)
	model.free()


## Lines of lettering on an item's face: the first large, the rest smaller beneath, each sized to the item's width.
func _letters(item: Dictionary, lines: Array, depth: float, lift: Vector2, color: Color, shop: bool) -> void:
	var at := Vector3(float(item.at[0]), float(item.at[1]), float(item.at[2]))
	var yaw := float(item.yaw)
	var out := Vector3(sin(yaw), 0.0, cos(yaw))
	var width := float(item.width) * 0.86
	var holder := Node3D.new()
	holder.position = at + out * depth + Vector3.UP * lift.y
	holder.rotation.y = yaw
	add_child(holder)
	var count := lines.size()
	for i in count:
		var text := str(lines[i])
		if text.is_empty():
			continue
		var label := Label3D.new()
		label.text = text
		label.font = FONT
		label.font_size = 64
		# Fit the line to the face: about 0.55 em a character in this face.
		var scale := (width if i == 0 else width * 0.8) / maxf(1.0, text.length() * 64.0 * 0.55)
		label.pixel_size = minf(scale, 0.012 if shop else 0.03)
		if shop:
			var measured := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size)
			label.pixel_size = minf(width / measured.x, float(item.height) * 0.94 / measured.y)
		label.modulate = color
		label.outline_size = 0
		label.double_sided = false
		label.shaded = true
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.visibility_range_end = LETTER_RANGE_M
		var line_h := 64.0 * label.pixel_size * 1.25
		label.position = Vector3(0.0, (float(count - 1) * 0.5 - float(i)) * line_h, 0.0)
		holder.add_child(label)
		if shop:
			_shop_letters.append(label)


func _is_night() -> bool:
	var info: Dictionary = _clock.day_info()
	if not bool(info.get("valid", false)):
		return false
	var minute := float(info.get("minute_of_day", 720.0))
	return minute < 6.0 * 60.0 or minute > 18.0 * 60.0


func _process(delta: float) -> void:
	_check += delta
	if _check < 5.0:
		return
	_check = 0.0
	var night := _is_night()
	if night != _lit:
		_apply_light(night)


## After dark the shop signs' lettering stops taking scene light and warms, reading as lit; no light is added.
func _apply_light(night: bool) -> void:
	_lit = night
	for label: Label3D in _shop_letters:
		label.shaded = not night
		label.modulate = Color(1.0, 0.86, 0.52) if night else Color(0.93, 0.82, 0.48)


## Per-group dressing of a catalogue finish: the catalogue's door paint is near white, so the signboards take a deep
## green and the advert grounds a faded blue; awning canvas is seen from above and below, so it draws both faces.
const TINTS := {"fronts_sign|door_paint": Color(0.10, 0.18, 0.12), "fronts_wallad|door_paint": Color(0.20, 0.27, 0.42)}
const BOTH_FACES := ["fronts_awning|fabric_warm", "fronts_awning|linen"]


func _finish(key: String, group := "") -> Material:
	var id := group + "|" + key
	if not _materials.has(id):
		assert(key in FINISHES, "unmapped city-fronts finish " + key)
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if TINTS.has(id):
			material.albedo_color = TINTS[id]
		if id in BOTH_FACES:
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[id] = material
	return _materials[id]
