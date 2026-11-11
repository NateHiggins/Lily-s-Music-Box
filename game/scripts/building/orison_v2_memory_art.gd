extends Node3D
## The residents' memory art in V2 (Lily, v1r_found_art_20261109: "the
## residents' memory art only").
##
## V1 hung twenty pieces (data/character_memory_art.json): one or two in each
## resident's main room, eighteen on a wall and two standing on furniture.
## That catalogue is still the list: which pieces, whose, what medium, hung or
## standing. Each picture was a quadrant of one of five generated image
## atlases; those images are not carried into V2 (RUL-007, RUL-008), so every
## frame holds a blank mount until authored pictures exist.
##
## V1 chose each hook by its wall-art law on V1's rooms. V2 has its own rooms,
## so each place is data (data/orison_v2/memory_art.json, in the blockout's own
## metres), measured in the running V2 world: the resident's main room, V1's
## wall where it is free, a flat stretch clear of doors, windows, fittings and
## what already hangs there; the standing pieces on the nearest clear furniture
## top to where V1 stood them.
const CATALOG := "res://data/character_memory_art.json"
const DATA := "res://data/orison_v2/memory_art.json"
const SELF := "res://scripts/building/orison_v2_memory_art.gd"
const Piece := preload("res://scripts/building/orison_v2_memory_art_piece.gd")
const HOLDER := "MemoryArt"

var errors: Array[String] = []
## V1 piece id -> the piece.
var pieces: Dictionary = {}
var _finishes: Dictionary = {}


static func mount(_root: Node3D, blockout: Node3D, layout: Dictionary, _adapter: Variant) -> Node:
	var node: Node3D = load(SELF).new()
	node.name = HOLDER
	if blockout == null or blockout.get_node_or_null(HOLDER) != null:
		node.errors.append("memory art needs a blockout and mounts once")
		return node
	blockout.add_child(node)
	node.compose(layout)
	return node


func compose(layout: Dictionary) -> void:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not (catalog is Dictionary) or not (data is Dictionary) or int(data.schema_version) != 1:
		errors.append("memory art catalogue or placements missing")
		return
	var packed := load(str(data.asset)) as PackedScene
	if packed == null:
		errors.append("memory art frame stock missing")
		return
	var media: Dictionary = {}
	for row: Dictionary in data.media:
		media[str(row.id)] = _finish(str(row.finish), Color.from_string(str(row.tint), Color.WHITE))
	var model := packed.instantiate()
	var mountings: Dictionary = {}
	for mounting: Dictionary in data.mountings:
		var rows: Array = []
		for row: Dictionary in mounting.parts:
			var draw := model.find_child(str(row.mesh), true, false) as MeshInstance3D
			if draw == null or draw.mesh == null:
				errors.append("memory art frame part missing: " + str(row.mesh))
				continue
			rows.append({"part": str(row.mesh), "finish": str(row.finish), "mesh": draw.mesh, "pose": draw.transform})
		mountings[str(mounting.id)] = rows
	model.free()
	var places: Dictionary = {}
	for place: Dictionary in data.places:
		places[str(place.id)] = place
	var spaces: Dictionary = {}
	for space: Dictionary in layout.get("spaces", []):
		spaces[str(space.id)] = true
	if not errors.is_empty():
		return
	for spec: Dictionary in catalog.pieces:
		var id := str(spec.id)
		var place: Dictionary = places.get(id, {})
		var mounting := str(spec.get("placement", "wall"))
		var medium := str(spec.get("medium", "photo"))
		if place.is_empty() or not spaces.has(str(place.space)) \
				or OrisonV2RuntimeRoot.unit_of_room(str(place.space)) != str(spec.unit):
			errors.append("no V2 place in flat %s for %s" % [spec.unit, id])
			continue
		if not mountings.has(mounting) or media.get(medium) == null:
			errors.append("no frame for %s (%s, %s)" % [id, mounting, medium])
			continue
		var piece := Piece.new()
		piece.setup(spec)
		piece.reach = float(data.visibility_range_m)
		for row: Dictionary in mountings[mounting]:
			var finish: Material = media[medium] if str(row.finish) == "medium" else _finish(str(row.finish), Color.WHITE)
			piece.stock.append({"part": row.part, "mesh": row.mesh, "pose": row.pose, "finish": finish})
		var at: Array = place.position
		piece.position = Vector3(at[0], at[1], at[2])
		piece.rotation.y = deg_to_rad(float(place.yaw_deg))
		add_child(piece)
		pieces[id] = piece
	# V1's own count check.
	var expected := int(catalog.get("expected_count", pieces.size()))
	if pieces.size() != expected:
		errors.append("character memory-art mismatch: expected %d, placed %d" % [expected, pieces.size()])
	print("[V2 MEMORY ART] %d memory-art frames hung, empty" % pieces.size())


## One finish per catalogue key and tint, shared by every frame that wears it.
func _finish(key: String, tint: Color) -> StandardMaterial3D:
	var id := key + "|" + tint.to_html()
	if _finishes.has(id):
		return _finishes[id]
	if not MatLib.SETS.has(key):
		errors.append("unregistered memory art finish: " + key)
		return null
	var mat := MatLib.get_mat(key).duplicate() as StandardMaterial3D
	mat.uv1_triplanar = false
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.albedo_color = tint
	_finishes[id] = mat
	return mat
