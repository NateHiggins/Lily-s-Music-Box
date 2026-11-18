extends Node3D
## The house dressed for the year's occasions: flags, bunting, a wreath, a
## table tree, poppies, a jack-o'-lantern, cut paper, lilies and crepe, put up
## in the public rooms for each of the calendar's holidays and taken down
## again. Every piece is Blender stock (art/blender/scripts/
## build_occasion_dressing.py) on duplicated catalogue finishes; every position
## is data in res://data/orison_v2/occasion_dressing.json, in the blockout's
## own plan coordinates or in the frame of the fitting it hangs on.
##
## mount() builds every placement hidden. dress(name) shows one occasion's
## placements and no others; dress("") undresses the house.
const PATH := "res://data/orison_v2/occasion_dressing.json"
const CANDLE_COLOR := Color(1.0, 0.62, 0.28)
const CANDLE_ENERGY := 0.55
const CANDLE_RANGE := 1.2

var errors: Array[String] = []
var _placed: Dictionary = {}    # placement id -> Node3D
var _sets: Dictionary = {}      # occasion name -> Array of placement nodes
var _dressed := ""


## Builds every placement, hidden, under the blockout and returns the dressing
## node. Read `errors` on the result: it is empty when everything was placed.
static func mount(root: Node3D, blockout: Node3D, layout: Dictionary, adapter: Variant) -> Node3D:
	var dressing: Node3D = new()
	dressing.name = "OccasionDressing"
	if root == null or blockout == null or adapter == null or not root.is_ancestor_of(blockout):
		dressing.errors.append("the blockout is not under the runtime root")
	else:
		blockout.add_child(dressing)
		dressing._build(layout, adapter)
	for line: String in dressing.errors:
		push_error("V2 occasion dressing: " + line)
	return dressing


## Shows exactly the named occasion's placements; "" (or a name the table does
## not hold) shows none. Does nothing when the occasion has not changed.
func dress(occasion: String) -> void:
	var next := occasion if _sets.has(occasion) else ""
	if next == _dressed:
		return
	var incoming: Array = _sets.get(next, [])
	for piece: Node3D in _sets.get(_dressed, []):
		if is_instance_valid(piece) and not incoming.has(piece):
			piece.visible = false
	for piece: Node3D in incoming:
		if is_instance_valid(piece):
			piece.visible = true
	_dressed = next


func dressed() -> String:
	return _dressed


## The occasions the table holds, in its own order.
func occasions() -> Array:
	return _sets.keys()


## The placement nodes of one occasion (shown or not).
func pieces_for(occasion: String) -> Array:
	return (_sets.get(occasion, []) as Array).duplicate()


## Every placement node, by placement id.
func placements() -> Dictionary:
	return _placed.duplicate()


func _build(layout: Dictionary, adapter: Variant) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is not Dictionary or int(data.get("schema_version", 0)) != 1:
		errors.append("the table is missing or of another schema")
		return
	var packed := load(str(data.asset)) as PackedScene
	if packed == null:
		errors.append("stock missing: " + str(data.asset))
		return
	var model := packed.instantiate()
	var finishes: Dictionary = {}
	var stock: Dictionary = {}
	for prop: Dictionary in data.props:
		var draws: Array[Dictionary] = []
		for part: Dictionary in prop.parts:
			var source := model.find_child(str(part.mesh), true, false) as MeshInstance3D
			var key := str(part.material)
			if source == null or source.mesh == null:
				errors.append("part missing from the stock: " + str(part.mesh))
				continue
			if not MatLib.SETS.has(key):
				errors.append("unregistered finish: " + key)
				continue
			var tint := Color(float(part.tint[0]), float(part.tint[1]), float(part.tint[2]))
			var finish_id := key + "|" + tint.to_html()
			if not finishes.has(finish_id):
				var finish := MatLib.get_mat(key).duplicate() as StandardMaterial3D
				finish.uv1_triplanar = false
				finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				finish.albedo_color = tint
				finishes[finish_id] = finish
			draws.append({"name": str(part.mesh), "mesh": source.mesh, "material": finishes[finish_id], "key": key})
		stock[str(prop.id)] = {"draws": draws, "shadow": bool(prop.shadow), "reach": float(prop.reach), "candle": prop.candle}
	model.free()

	var floors: Dictionary = {}
	for level: Dictionary in layout.get("levels", []):
		floors[str(level.id)] = float(level.y)
	for row: Dictionary in data.placements:
		var id := str(row.id)
		var kind: Dictionary = stock.get(str(row.prop), {})
		if kind.is_empty() or not floors.has(str(row.level)) or _placed.has(id):
			errors.append("placement %s names no prop, no level, or is given twice" % id)
			continue
		var at := Vector3(float(row.position[0]), float(row.position[1]), float(row.position[2]))
		var parent: Node3D = self
		if str(row.host) == "":
			at.y += float(floors[str(row.level)])
		else:
			# It hangs on a fitting and rides it: a door leaf carries its wreath.
			var host := adapter.resolve(str(row.host)) as Node3D
			parent = null if host == null else host.get_node_or_null(str(row.node)) as Node3D
			if parent == null:
				errors.append("placement %s: no fitting %s/%s" % [id, row.host, row.node])
				continue
		var piece := Node3D.new()
		piece.name = "OccasionPiece"
		piece.visible = false
		piece.set_meta("occasion_placement", id)
		piece.set_meta("occasion_prop", str(row.prop))
		piece.set_meta("occasion_space", str(row.space))
		piece.set_meta("occasion_level", str(row.level))
		piece.set_meta("occasion_rest", str(row.rest))
		parent.add_child(piece)
		piece.transform = Transform3D(Basis(Vector3.UP, float(row.yaw)), at)
		for draw: Dictionary in kind.draws:
			var node := MeshInstance3D.new()
			node.name = str(draw.name)
			node.mesh = draw.mesh
			node.material_override = draw.material
			node.visibility_range_end = float(kind.reach)
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.set_meta("material_key", str(draw.key))
			piece.add_child(node)
		var candle: Array = kind.candle
		if candle.size() == 3:
			var flame := OmniLight3D.new()
			flame.name = "CandleStub"
			flame.position = Vector3(float(candle[0]), float(candle[1]), float(candle[2]))
			flame.light_color = CANDLE_COLOR
			flame.light_energy = CANDLE_ENERGY
			flame.omni_range = CANDLE_RANGE
			flame.shadow_enabled = false
			flame.distance_fade_enabled = true
			flame.distance_fade_begin = float(kind.reach) * 0.7
			flame.distance_fade_length = float(kind.reach) * 0.3
			piece.add_child(flame)
		_placed[id] = piece

	for row: Dictionary in data.occasions:
		var pieces: Array[Node3D] = []
		for id: Variant in row.show:
			if _placed.has(str(id)):
				pieces.append(_placed[str(id)])
			else:
				errors.append("%s shows a placement that was not built: %s" % [row.id, id])
		_sets[str(row.id)] = pieces
