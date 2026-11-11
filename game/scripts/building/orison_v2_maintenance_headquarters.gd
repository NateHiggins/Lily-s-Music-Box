extends "res://scripts/building/maintenance_headquarters.gd"
## The maintenance headquarters in V2's house office (Lily, v1r_maintenance_hq).
##
## V1's script keeps every authority: the six tools and their thresholds, the
## count derived from resolved cases, the status words, the inspection card.
## This script replaces only what V1 drew with boxes: the workbench, the tool
## board, the plaque and the wall of residue tokens are Blender bodies bound
## to catalogue finishes, and V1's own refresh shows and hides them.
##
## The wall of tokens is the trophy wall: one socket per resident case. It is
## not the evidence wall in 4B.
const BRASS_LETTER := Color(0.80, 0.68, 0.40)
const STATUS_INK := Color(0.72, 0.77, 0.70)

var stock: RefCounted
## Where the bench, the plaque and the trophy wall stand, in this node's frame.
var places: Dictionary = {}
var bench: Node3D
var plaque: Node3D
var trophy_wall: Node3D
var gear_cards: Array[Label3D] = []


func _build_workbench() -> void:
	bench = _stand("hq_bench", "bench", "HeadquartersBench")
	plaque = _stand("plaque", "plaque", "HeadquartersPlaque")
	# V1's plaque was a picture of these words; lettering is Label3D (RUL-008).
	var title: Label3D = stock.words("REALITY MAINTENANCE", stock.plaque_width, 0.062, BRASS_LETTER)
	title.position = stock.plaque_words
	plaque.add_child(title)


func _build_gear_wall() -> void:
	for index in GEAR.size():
		var spec: Dictionary = GEAR[index]
		var holder: Node3D = stock.part_node("hq_bench", "Gear_" + str(spec.kind))
		holder.name = "Gear_" + str(spec.name).to_snake_case()
		bench.add_child(holder)
		_gear_visuals.append(holder)
		var card: Label3D = stock.words(str(spec.name), 0.29, 0.02)
		card.position = stock.cards[index]
		bench.add_child(card)
		gear_cards.append(card)


func _build_case_wall() -> void:
	trophy_wall = _stand("trophy_wall", "trophy_wall", "TrophyWall")
	var ids := RealityCases.definitions.keys()
	ids.sort()
	var sockets: int = stock.trophy_columns * stock.trophy_rows
	if ids.size() > sockets:
		push_error("trophy wall has %d sockets for %d cases" % [sockets, ids.size()])
	for index in mini(ids.size(), sockets):
		var case_id: String = ids[index]
		# V1's own hue for the case's token.
		var hue := fmod(float(index) * 0.137, 1.0)
		var token: Node3D = stock.part_node("trophy_wall", "Token", Color.from_hsv(hue, 0.38, 0.78))
		token.name = "Trophy_" + case_id
		token.position += Vector3(float(index % stock.trophy_columns) * stock.trophy_pitch.x,
				float(index / stock.trophy_columns) * stock.trophy_pitch.y, 0.0)
		trophy_wall.add_child(token)
		_trophies[case_id] = token
	_status = stock.words("CASE RESIDUE  00/%02d" % ids.size(), 2.0, 0.05, STATUS_INK)
	_status.position = stock.trophy_status
	trophy_wall.add_child(_status)


## V1 builds the one inspection target and its tap; here they move to the
## trophy wall.
func _build_case_wall_interaction() -> void:
	super._build_case_wall_interaction()
	var area := get_node("CaseWallInspection") as Area3D
	area.name = "TrophyWallInspection"
	area.transform = trophy_wall.transform * Transform3D(Basis(), Vector3(0.0, 1.45, 0.06))
	var shape := (area.get_child(0) as CollisionShape3D).shape as BoxShape3D
	shape.size = Vector3(2.3, 1.3, 0.12)
	_inspection_tap.position = area.position


func _stand(assembly: String, place: String, title: String) -> Node3D:
	var body: Node3D = stock.part_node(assembly, "Body")
	body.name = title
	var at: Transform3D = places.get(place, Transform3D())
	body.transform = at
	add_child(body)
	return body
