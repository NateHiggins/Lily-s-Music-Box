extends Node3D
## The residents' story boards (order wc623512ce56c; Lily's rulings v1r_story_plates_20261110 and
## story_boards_draft_20261116): each resident has pinned one period paper of their own in their main room,
## a grocery list, a rota, a set list, a provenance tag, beside the wall their memory art is measured for.
## The words are authored Label3D (data/orison_v2/story_boards.json); no lettering is baked into a texture.
## The paper and the pin wear catalogue finishes, as the corrected notices on the flat doors do.
const DATA := "res://data/orison_v2/story_boards.json"
const PLACES := "res://data/orison_v2/memory_art.json"
const SELF := "res://scripts/building/orison_v2_story_boards.gd"
const Footprints := preload("res://scripts/building/orison_v2_space_footprints.gd")
const TYPED := preload("res://assets/fonts/specialelite/SpecialElite-Regular.ttf")
const HAND := preload("res://assets/fonts/cedarvillecursive/Cedarville-Cursive.ttf")
const HOLDER := "StoryBoards"
const PAPER := 0.0012
## Off the wall face, so the paper never sits inside it.
const STANDOFF := 0.003

var errors: Array[String] = []
## Board id -> the board's node.
var boards: Dictionary = {}


static func mount(_root: Node3D, blockout: Node3D, layout: Dictionary, _adapter: Variant) -> Node:
	var node: Node3D = load(SELF).new()
	node.name = HOLDER
	if blockout == null or blockout.get_node_or_null(HOLDER) != null:
		node.errors.append("story boards need a blockout and mount once")
		return node
	blockout.add_child(node)
	node.compose(layout)
	return node


## The pose a board hangs at: its memory-art wall pose moved along the wall by the board's offset.
static func pose_for(board: Dictionary, places: Dictionary) -> Transform3D:
	var place: Dictionary = places.get(str(board.beside), {})
	if place.is_empty():
		return Transform3D()
	var at: Array = place.position
	var frame := Transform3D(Basis(Vector3.UP, deg_to_rad(float(place.yaw_deg))), Vector3(at[0], at[1], at[2]))
	var offset: Array = board.offset
	return frame * Transform3D(Basis(), Vector3(float(offset[0]), float(offset[1]), STANDOFF))


static func load_places() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACES))
	var places: Dictionary = {}
	if data is Dictionary:
		for place: Dictionary in data.places:
			places[str(place.id)] = place
	return places


func compose(layout: Dictionary) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not (data is Dictionary) or int(data.get("schema_version", 0)) != 1:
		errors.append("story boards data missing")
		return
	var places := load_places()
	for board: Dictionary in data.boards:
		var id := str(board.id)
		if not places.has(str(board.beside)):
			errors.append("%s: no measured wall beside %s" % [id, board.beside])
			continue
		var pose := pose_for(board, places)
		var room: String = Footprints.room_at(layout, pose * Vector3(0.0, 0.0, 0.15))
		if OrisonV2RuntimeRoot.unit_of_room(room) != str(board.unit) or not room.ends_with("_MAIN"):
			errors.append("%s hangs in '%s', not in %s's main room" % [id, room, board.unit])
			continue
		var node := _build(board)
		node.transform = pose
		add_child(node)
		boards[id] = node
	print("[V2 STORY BOARDS] %d boards pinned" % boards.size())


func _build(board: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = str(board.id)
	node.set_meta("resident", str(board.resident))
	var size: Array = board.size
	var w := float(size[0])
	var h := float(size[1])
	var tint: Array = board.tint
	var paper := BoxMesh.new()
	paper.size = Vector3(w, h, PAPER)
	paper.material = MatLib.get_mat("paper", Color(float(tint[0]), float(tint[1]), float(tint[2])))
	var page := MeshInstance3D.new()
	page.name = "Paper"
	page.mesh = paper
	page.position = Vector3(0.0, 0.0, PAPER * 0.5)
	node.add_child(page)
	var head := CylinderMesh.new()
	head.top_radius = 0.0045
	head.bottom_radius = 0.0045
	head.height = 0.003
	head.radial_segments = 10
	head.material = MatLib.get_mat("brass_dull", Color(0.80, 0.70, 0.50))
	var pin := MeshInstance3D.new()
	pin.name = "Pin"
	pin.mesh = head
	pin.rotation.x = PI * 0.5
	pin.position = Vector3(0.0, h * 0.5 - 0.012, PAPER + 0.0015)
	node.add_child(pin)
	var hand := str(board.get("hand", "typed")) == "hand"
	var lines: Array = board.lines
	var gap := minf(0.026, (h - 0.04) / maxf(1.0, float(lines.size())))
	var top := h * 0.5 - 0.03
	for index in lines.size():
		var label := Label3D.new()
		label.name = "Line%d" % index
		label.text = str(lines[index])
		label.font = HAND if hand else TYPED
		label.font_size = 48
		# Measured with its own font and shrunk if needed, so every line keeps a margin either side.
		var base := 0.00042 if hand else 0.00034
		var span: float = label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x
		label.pixel_size = minf(base, (w - 0.016) / maxf(1.0, span))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(0.13, 0.11, 0.10) if not (hand and index == 0) else Color(0.12, 0.13, 0.30)
		label.outline_size = 0
		label.double_sided = false
		label.position = Vector3(0.0, top - gap * index, PAPER + 0.0006)
		node.add_child(label)
	return node
