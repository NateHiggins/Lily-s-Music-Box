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
const Footprints := preload("res://scripts/building/orison_v2_space_footprints.gd")
const HOLDER := "MemoryArt"
const PICTURES := "res://assets/memory_art"
## Bare paper left round the picture, as a fraction of the mount.
const MARGIN := 0.07

var errors: Array[String] = []
## V1 piece id -> the piece.
var pieces: Dictionary = {}
var _finishes: Dictionary = {}
## Piece id -> the picture file it shows.
var pictures: Dictionary = {}


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
	if not errors.is_empty():
		return
	for spec: Dictionary in catalog.pieces:
		var id := str(spec.id)
		var place: Dictionary = places.get(id, {})
		var mounting := str(spec.get("placement", "wall"))
		var medium := str(spec.get("medium", "photo"))
		if place.is_empty():
			errors.append("no V2 place for %s" % id)
			continue
		var at: Array = place.position
		var pose := Transform3D(Basis(Vector3.UP, deg_to_rad(float(place.yaw_deg))), Vector3(at[0], at[1], at[2]))
		# The place must be in the main room of the resident V1 gave the piece to.
		var room: String = Footprints.room_at(layout, pose * Vector3(0.0, 0.05, 0.15))
		if OrisonV2RuntimeRoot.unit_of_room(room) != str(spec.unit) or not room.ends_with("_MAIN"):
			errors.append("%s is placed in '%s', not in %s's main room" % [id, room, spec.unit])
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
			if str(row.part).contains("Mount"):
				var picture := _picture(id, row.mesh as Mesh, row.pose as Transform3D)
				if not picture.is_empty():
					piece.stock.append(picture)
		piece.transform = pose
		add_child(piece)
		pieces[id] = piece
	# V1's own count check.
	var expected := int(catalog.get("expected_count", pieces.size()))
	if pieces.size() != expected:
		errors.append("character memory-art mismatch: expected %d, placed %d" % [expected, pieces.size()])
	print("[V2 MEMORY ART] %d memory-art frames hung, %d with pictures" % [pieces.size(), pictures.size()])


## The authored picture for a piece, when one exists (PICTURES/<id>.webp): period art drawn for V2, no lettering
## (work order w222c70ff408c). It lies a hair in front of the mount, inside a paper margin, on the mount's own paper
## finish, so it keeps the paper's roughness and relief and only the image differs. No file, no picture: the mount
## stays blank.
func _picture(id: String, mount: Mesh, pose: Transform3D) -> Dictionary:
	var path := PICTURES.path_join(id + ".webp")
	if mount == null or not ResourceLoader.exists(path):
		return {}
	var image := load(path) as Texture2D
	var paper := _finish("paper", Color.WHITE)
	if image == null or paper == null:
		return {}
	var box := mount.get_aabb()
	# The mount is a thin slab: its two long sides are the sheet, its short side the way it faces.
	var thin := box.size.min_axis_index()
	var wide := 0 if thin != 0 else 2
	var tall := 1 if thin != 1 else 2
	var room := Vector2(box.size[wide], box.size[tall]) * (1.0 - MARGIN * 2.0)
	var shape := Vector2(float(image.get_width()), float(image.get_height()))
	var size := room
	if room.x / room.y > shape.x / shape.y:
		size.x = room.y * shape.x / shape.y
	else:
		size.y = room.x * shape.y / shape.x
	var quad := QuadMesh.new()
	quad.size = size
	var finish := paper.duplicate() as StandardMaterial3D
	finish.albedo_texture = image
	finish.albedo_color = Color.WHITE
	# The catalogue paper repeats; a picture is shown once.
	finish.uv1_scale = Vector3.ONE
	finish.uv1_offset = Vector3.ZERO
	# A quad faces +Z. Turn it to the mount's own face and set it just proud of that face.
	var out := Vector3.ZERO
	out[thin] = 1.0
	var centre := box.get_center()
	centre[thin] = box.end[thin] + 0.0006
	var turn := Basis.IDENTITY
	if thin == 0:
		turn = Basis(Vector3.UP, PI * 0.5)
	elif thin == 1:
		turn = Basis(Vector3.RIGHT, -PI * 0.5)
	pictures[id] = path
	# One authored surface with its own UVs and tangents, like the frame stock it hangs in.
	var sheet := ArrayMesh.new()
	sheet.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, quad.get_mesh_arrays())
	return {"part": "Picture", "mesh": sheet, "pose": pose * Transform3D(turn, centre), "finish": finish}


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
