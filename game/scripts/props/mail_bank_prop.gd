class_name MailBankProp
extends Node3D
## The lobby mail bank, Cutler-style: a cast-brass grid of tenant boxes in
## a wood surround, built prop-side so the player's own box can actually
## open. Twenty-four doors, one per unit; typed name cards from the
## resident roster; the 4B door is real — hinged, keyed to the player, and
## the channel every package, work order and upgrade arrives through.
##
## Deliveries are data (res://data/mail_catalog.json). Each entry carries a
## `when` gate evaluated lazily against the campaign, so mail "arrives"
## the moment its condition becomes true and waits until collected. Taken
## ids and granted upgrades persist in RealityState.data.

const CATALOG_PATH := "res://data/mail_catalog.json"
const TEX_DIR := "res://assets/building/textures/mailbank/"
const COLS := 6
## The name-card sheet: one wide slip per unit, 6 x 4.
const CARD_COLS := 6
const CARD_ROWS := 4
const ROWS := 4
const DOOR_W := 0.24
const DOOR_H := 0.20
const PLAYER_UNIT := "4B"
## Grid order, left-right top-bottom — must match the card atlas.
const UNITS := ["1A", "1B", "1C", "1D", "2A", "2B",
		"2C", "2D", "3A", "3B", "3C", "3D",
		"4A", "4B", "4C", "4D", "5A", "5B",
		"5C", "5D", "6A", "6B", "6C", "6D"]

var deliveries: Array = []
var door_open := false
var _hinge: Node3D
var _panel: CaseDialoguePanel
var _contents: Node3D
var _brass: StandardMaterial3D
var _brass_dark: StandardMaterial3D


func _ready() -> void:
	add_to_group("mail_bank")
	var catalog: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(CATALOG_PATH))
	deliveries = catalog.get("deliveries", [])
	_brass = _brass_material(1.0)
	_brass_dark = _brass_material(0.72)
	_build()
	_panel = CaseDialoguePanel.new()
	add_child(_panel)


func _brass_material(tint: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(tint, tint, tint)
	material.albedo_texture = load(TEX_DIR + "T_mailbank_brass_albedo.png")
	material.roughness_texture = load(TEX_DIR + "T_mailbank_brass_rough.png")
	material.metallic = 0.55
	material.metallic_specular = 0.6
	return material


## Depth stack, local z, front faces -Z. The prop's origin sits ON the
## wall face, so everything visible must be at negative z: wood surround
## proud of the wall, brass box bodies proud of the wood, door furniture
## proud of the bodies — the way a surface-mounted Cutler bank actually
## stands off its lobby wall.
const Z_SURROUND := -0.025   # center of the 0.05-deep wood slab
const Z_BODY := -0.078       # center of each 0.055-deep box body
const Z_BEVEL := -0.108
const Z_LEAF := -0.112
const Z_CARD_FRAME := -0.118
const Z_CARD := -0.1205
const Z_LOCK := -0.119
const LEAF_W := DOOR_W - 0.044
const LEAF_H := DOOR_H - 0.052


func _build() -> void:
	var width := COLS * DOOR_W
	var height := ROWS * DOOR_H
	# Wood surround, matched to the generated bank standing beside this one.
	_box(Vector3(0, height * 0.5 + 0.72, Z_SURROUND),
			Vector3(width + 0.14, height + 0.34, 0.05),
			_flat(Color(0.47, 0.325, 0.185), 0.6))
	# Header plate: THE ORISON / U.S. MAIL, incised brass. The lettering is
	# a quad — BoxMesh atlas-crops its faces and would show three letters.
	_box(Vector3(0, height + 0.72 + 0.085, Z_SURROUND - 0.028),
			Vector3(width - 0.06, 0.13, 0.010), _brass_dark)
	var header := MeshInstance3D.new()
	var header_quad := QuadMesh.new()
	header_quad.size = Vector2(width - 0.06, 0.13)
	header.mesh = header_quad
	var header_mat := StandardMaterial3D.new()
	header_mat.albedo_texture = load(TEX_DIR + "T_mailbank_header.png")
	header_mat.roughness = 0.5
	header_mat.metallic = 0.45
	header.material_override = header_mat
	header.position = Vector3(0, height + 0.72 + 0.085, Z_SURROUND - 0.034)
	header.rotation.y = PI
	add_child(header)
	var cards: Texture2D = load(TEX_DIR + "T_mailbank_cards.png")
	for i in UNITS.size():
		var col := i % COLS
		var row := i / COLS
		var x := (col - (COLS - 1) * 0.5) * DOOR_W
		var y := 0.72 + height - (row + 0.5) * DOOR_H
		if UNITS[i] == PLAYER_UNIT:
			_build_player_door(Vector3(x, y, 0), cards, i)
		else:
			_build_door(Vector3(x, y, 0), cards, i)
	# Outgoing mail: brass slot plate on the surround, flap held shut.
	_box(Vector3(width * 0.5 - 0.24, 0.60, Z_SURROUND - 0.028),
			Vector3(0.30, 0.10, 0.012), _brass_dark)
	_box(Vector3(width * 0.5 - 0.24, 0.615, Z_SURROUND - 0.036),
			Vector3(0.20, 0.016, 0.006), _flat(Color(0.06, 0.05, 0.04), 0.9))
	var flap := _box(Vector3(width * 0.5 - 0.24, 0.594, Z_SURROUND - 0.035),
			Vector3(0.21, 0.030, 0.006), _brass)
	flap.rotation.x = -0.14


## One tenant's box: brass body proud of the wood, beveled frame, door
## leaf, typed card behind glass, cylinder lock. `atlas_index` picks the
## card and staggers which doors read polished versus patinated.
func _build_door(at: Vector3, cards: Texture2D, atlas_index: int) -> void:
	_box(at + Vector3(0, 0, Z_BODY),
			Vector3(DOOR_W - 0.018, DOOR_H - 0.026, 0.055), _brass_dark)
	_box(at + Vector3(0, 0, Z_BEVEL),
			Vector3(DOOR_W - 0.028, DOOR_H - 0.038, 0.008),
			_brass_dark if atlas_index % 3 != 1 else _brass)
	_box(at + Vector3(0, 0, Z_LEAF), Vector3(LEAF_W, LEAF_H, 0.008),
			_brass if atlas_index % 3 != 1 else _brass_dark)
	_card(cards, atlas_index, at + Vector3(0, 0.022, 0), self)
	_lock(at + Vector3(0.062, -0.048, Z_LOCK), self)


## The player's door is the same door on a working hinge, with a body
## that actually holds things.
func _build_player_door(at: Vector3, cards: Texture2D, index: int) -> void:
	# The box body, near-black inside-looking front so the open door reads
	# as a cavity, with the waiting mail proud of it.
	_box(at + Vector3(0, 0, Z_BODY),
			Vector3(DOOR_W - 0.018, DOOR_H - 0.026, 0.055),
			_flat(Color(0.09, 0.075, 0.055), 0.85))
	_contents = Node3D.new()
	_contents.position = at + Vector3(0, -0.03, Z_BODY - 0.02)
	add_child(_contents)
	_hinge = Node3D.new()
	_hinge.position = at + Vector3(-LEAF_W * 0.5, 0, Z_LEAF)
	add_child(_hinge)
	var leaf := MeshInstance3D.new()
	var leaf_mesh := BoxMesh.new()
	leaf_mesh.size = Vector3(LEAF_W, LEAF_H, 0.008)
	leaf.mesh = leaf_mesh
	leaf.material_override = _brass
	leaf.position = Vector3(LEAF_W * 0.5, 0, 0)
	_hinge.add_child(leaf)
	_card(cards, index, Vector3(LEAF_W * 0.5, 0.022, 0), _hinge)
	_lock(Vector3(LEAF_W * 0.5 + 0.062, -0.048, Z_LOCK - Z_LEAF), _hinge)
	# The interaction body covers just this door.
	var body := StaticBody3D.new()
	body.name = "PlayerBox"
	body.set_script(preload("res://scripts/props/mail_box_zone.gd"))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(DOOR_W, DOOR_H, 0.20)
	shape.shape = box
	body.add_child(shape)
	body.position = at + Vector3(0, 0, Z_BODY)
	add_child(body)


## A typed name card behind a thin brass frame. `local_at` is the card
## centre in `parent` space; the stack offsets are applied here so the
## hinged door and the fixed doors share one builder.
func _card(cards: Texture2D, atlas_index: int, local_at: Vector3,
		parent: Node3D) -> void:
	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(0.128, 0.062, 0.004)
	frame.mesh = frame_mesh
	frame.material_override = _brass_dark
	frame.position = local_at + Vector3(0, 0, Z_CARD_FRAME if parent == self \
			else Z_CARD_FRAME - Z_LEAF)
	parent.add_child(frame)
	var card := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.115, 0.052)
	card.mesh = quad
	# Crop with UV scale/offset, not AtlasTexture: on a 3D material the
	# region is ignored and the mesh's own UVs still address the whole
	# sheet, so every box wore all twenty-four cards at once.
	#
	# Straight window, no mirroring. The quad's 180-degree turn does not
	# flip U - the header plate above proves it, reading forwards through
	# the same rotation - so negating the scale to "correct" for it was
	# what printed every tenant's name backwards.
	var card_mat := StandardMaterial3D.new()
	card_mat.albedo_texture = cards
	card_mat.uv1_scale = Vector3(1.0 / CARD_COLS, 1.0 / CARD_ROWS, 1.0)
	card_mat.uv1_offset = Vector3(
			float(atlas_index % CARD_COLS) / CARD_COLS,
			float(atlas_index / CARD_COLS) / CARD_ROWS, 0.0)
	card_mat.roughness = 0.42  # glass front
	card.material_override = card_mat
	card.position = local_at + Vector3(0, 0, Z_CARD if parent == self \
			else Z_CARD - Z_LEAF)
	card.rotation.y = PI
	parent.add_child(card)


## Cylinder lock, low right — the one part of every door fingers polish.
func _lock(local_at: Vector3, parent: Node3D) -> void:
	var lock := MeshInstance3D.new()
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.011
	barrel.bottom_radius = 0.011
	barrel.height = 0.012
	lock.mesh = barrel
	lock.rotation.x = PI * 0.5
	lock.material_override = _flat(Color(0.62, 0.58, 0.50), 0.25)
	lock.position = local_at
	parent.add_child(lock)


func _box(at: Vector3, size: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	if material:
		node.material_override = material
	node.position = at
	add_child(node)
	return node


func _flat(color: Color, rough: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	return material


# ---------------------------------------------------------------- mail

## Deliveries whose gate is open and which have not been collected.
func pending() -> Array:
	var taken: Array = RealityState.data.get("mail_taken", [])
	var due: Array = []
	for item in deliveries:
		if str(item.id) in taken:
			continue
		if _due(item.get("when", {})):
			due.append(item)
	return due


func _due(when: Dictionary) -> bool:
	if when.get("always", false):
		return true
	var case_id := str(when.get("case", ""))
	if case_id == "":
		return false
	var state := RealityState.case_state(case_id)
	if state.is_empty():
		return false
	if int(state.get("repair_count", 0)) < int(when.get("min_repairs", 0)):
		return false
	if when.get("resolved", false) and not bool(state.get("resolved", false)):
		return false
	return true


func interact_prompt() -> String:
	var count := pending().size()
	if not door_open:
		return "Check box 4B — %d waiting" % count if count > 0 \
				else "Open box 4B"
	return "Take your mail" if count > 0 else "Close box 4B"


func interact(_player: Node) -> void:
	if not door_open:
		_set_door(true)
		if not pending().is_empty():
			_offer_next()
		return
	if pending().is_empty():
		_set_door(false)
		return
	_offer_next()


func _offer_next() -> void:
	var due := pending()
	if due.is_empty():
		return
	var item: Dictionary = due[0]
	var tag := str(item.get("kind", "letter")).to_upper()
	_panel.present("BOX 4B — %s" % tag,
			str(item.get("title", "")) + "\n" + str(item.get("body", "")), [
				{"text": "[Take it.]", "action": func(): _take(item)},
				{"text": "[Leave it for now.]", "action": Callable()},
			])


func _take(item: Dictionary) -> void:
	var taken: Array = RealityState.data.get("mail_taken", [])
	taken.append(str(item.id))
	RealityState.data["mail_taken"] = taken
	var upgrade := str(item.get("upgrade", ""))
	if upgrade != "":
		var upgrades: Array = RealityState.data.get("upgrades", [])
		if upgrade not in upgrades:
			upgrades.append(upgrade)
		RealityState.data["upgrades"] = upgrades
		print("[MAIL] upgrade acquired: %s" % upgrade)
	RealityState.commit()
	_refresh_contents()
	if pending().is_empty():
		_set_door(false)
	else:
		_offer_next()


func _set_door(open: bool) -> void:
	door_open = open
	create_tween().tween_property(_hinge, "rotation:y",
			-1.92 if open else 0.0, 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_refresh_contents()


## The cavity shows what is waiting: envelopes lie flat, a work order
## stands against the side, a package fills the back.
func _refresh_contents() -> void:
	if _contents == null:
		return
	for old in _contents.get_children():
		old.queue_free()
	var slot := 0
	for item in pending():
		match str(item.get("kind", "letter")):
			"package":
				_content_box(Vector3(0.01, 0.045, 0.014),
						Vector3(0.13, 0.085, 0.055),
						Color(0.62, 0.48, 0.30))
				_content_box(Vector3(0.01, 0.045, -0.015),
						Vector3(0.132, 0.012, 0.058),
						Color(0.32, 0.24, 0.15))
			"work_order":
				_content_box(Vector3(-0.055, 0.05, 0.0),
						Vector3(0.012, 0.10, 0.062),
						Color(0.78, 0.68, 0.44))
			_:
				_content_box(Vector3(0.02, 0.006 + slot * 0.012, 0.0),
						Vector3(0.125, 0.010, 0.085),
						Color(0.88, 0.85, 0.76))
				slot += 1


func _content_box(at: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _flat(color, 0.75)
	node.position = at
	_contents.add_child(node)
