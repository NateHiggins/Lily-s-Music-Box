extends Node3D
## Adela's window: the only window in the Arcade that changes by the date. Each card is up for
## its authored days, in the hand of whoever keeps the shop. The Wills card stays where she left
## it until Nadia takes the window over. Reading a card that a thread waits on grants its flag.
## A card's `at` runs across the glass and up from the window's middle. All are PROPOSED, from
## the treatment's newspaper table.

const DATA := "res://data/photo_window.json"
const HANDS := {
	"adela": preload("res://assets/fonts/jost/Jost[wght].ttf"),
	"nadia": preload("res://assets/fonts/librebodoni/LibreBodoni[wght].ttf"),
	"night": preload("res://assets/fonts/specialelite/SpecialElite-Regular.ttf"),
}
const READ_RANGE := 3.5
const READ_FACING := 0.8

var cards: Array = []
var _clock := CampaignClock.new()
var _left := 0.0
var _shown_today := ""


func configure() -> bool:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if decoded is not Dictionary or int(decoded.get("schema_version", 0)) != 1 or decoded.get("cards") is not Array:
		return false
	for row: Dictionary in decoded.cards:
		var card := Node3D.new()
		card.name = str(row.id)
		var at: Array = row.at
		card.position = Vector3(float(at[0]), float(at[1]), 0.0)
		card.rotation.z = deg_to_rad(float(row.get("tilt", 0.0)))
		add_child(card)
		var size: Array = row.size
		var paper := MeshInstance3D.new()
		paper.name = "Paper"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(float(size[0]), float(size[1]), 0.002)
		paper.mesh = mesh
		paper.material_override = MatLib.get_mat("paper")
		card.add_child(paper)
		var label := Label3D.new()
		label.name = "Lettering"
		label.text = str(row.text)
		label.font = HANDS[str(row.hand)]
		label.font_size = 48
		label.pixel_size = float(row.get("letter", 0.018)) / 48.0
		label.width = float(size[0]) * 0.94 / label.pixel_size
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.position = Vector3(0.0, 0.0, 0.003)
		label.modulate = Color(str(row.get("colour", "#1c1712")))
		label.double_sided = false
		label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		card.add_child(label)
		cards.append({"row": row, "node": card})
	refresh()
	return true


func _today() -> String:
	if not _clock.bind_state():
		return ""
	var local := _clock.local_datetime()
	return "" if local.is_empty() else "%04d-%02d-%02d" % [int(local.year), int(local.month), int(local.day)]


func refresh() -> void:
	var today := _today()
	_shown_today = today
	for card: Dictionary in cards:
		(card.node as Node3D).visible = today != "" and today >= str(card.row.from) and today <= str(card.row.until)


## What's up now, for the reader and the test.
func showing() -> Array:
	var out: Array = []
	for card: Dictionary in cards:
		if (card.node as Node3D).visible:
			out.append(str(card.row.id))
	return out


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	_left = 0.5
	if _today() != _shown_today:
		refresh()
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for card: Dictionary in cards:
		var flag := str(card.row.get("flag", ""))
		var node: Node3D = card.node
		if flag == "" or not node.visible or RealityState.has_knowledge(flag):
			continue
		var to_card := node.global_position - camera.global_position
		if to_card.length() <= READ_RANGE and (-camera.global_basis.z).dot(to_card.normalized()) >= READ_FACING:
			RealityState.grant_knowledge(flag)
			RealityState.commit()
