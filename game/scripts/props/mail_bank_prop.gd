class_name MailBankProp
extends FunctionalProp
## The lobby mail bank, Cutler-descended: a Couch-pattern cast-brass grid
## of tenant boxes in a wood surround, built prop-side so the player's own
## box can actually open. Twenty-four doors, one per unit; typed name cards from the
## resident roster; the 4B door is real — hinged, keyed to the player, and
## the channel every package, work order and upgrade arrives through.
##
## Deliveries are data (res://data/mail_catalog.json). Each entry carries a
## `when` gate evaluated lazily against the campaign, so mail "arrives"
## the moment its condition becomes true and waits until collected. Taken
## ids and granted upgrades persist in RealityState.data.

const CATALOG_PATH := "res://data/mail_catalog.json"
const TEX_DIR := "res://assets/building/textures/mailbank/"
## THE BANK IS AN ELEVATION OF THE BUILDING. Four stacks across, six
## floors down, floor six at the top — so finding 5C means looking where
## 5C actually is, two below the top and third from the left, and the
## grid teaches the building to anyone who reads it.
##
## It used to be six across and four down, filled 1A..6D left to right,
## which put "2C 2D 3A 3B 3C 3D" on one row. That is a list, not a
## building: every lookup was a scan, and the wall told you nothing.
const COLS := 4                  # stacks A B C D
const ROWS := 6                  # floors, 6 at the top
const STACKS := ["A", "B", "C", "D"]
## The name-card sheet is UNCHANGED — one wide slip per unit, 6 x 4, in
## its own order. Cards are picked by a unit's index in CARD_ORDER and
## placed by what its NAME says, so re-sorting the wall never re-cuts
## the atlas.
const CARD_COLS := 6
const CARD_ROWS := 4
const CARD_ORDER := ["1A", "1B", "1C", "1D", "2A", "2B",
		"2C", "2D", "3A", "3B", "3C", "3D",
		"4A", "4B", "4C", "4D", "5A", "5B",
		"5C", "5D", "6A", "6B", "6C", "6D"]
const UNITS := CARD_ORDER
const DOOR_W := 0.31
const DOOR_H := 0.14
const PLAYER_UNIT := "4B"
const ARRAY_BASE := 0.92
## No resident profile means no tenant card. These are literal dark gaps in
## the elevation rather than six invented households: two empty first-floor
## flats, the sealed 2D, vacant 3C/5D and the sixth-floor store room.
const EMPTY_UNITS := ["1B", "1C", "2D", "3C", "5D", "6D"]

var deliveries: Array = []
var door_open := false
var _hinge: Node3D
var _panel: CaseDialoguePanel
var _contents: Node3D
var _brass: StandardMaterial3D
var _brass_dark: StandardMaterial3D
var _fixed: Node3D


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


## This is architectural hardware rather than a layout-marker family, but it
## still belongs in the warehouse. Its geometry is all built behind its wall
## datum; the warehouse reads that fact rather than carrying a mail-bank rule.
func warehouse_rotation_y() -> float:
	return PI


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
const LEAF_W := DOOR_W - 0.036
const LEAF_H := DOOR_H - 0.036


func _build() -> void:
	var width := COLS * DOOR_W
	var height := ROWS * DOOR_H
	_fixed = Node3D.new()
	_fixed.name = "FixedBank"
	add_child(_fixed)
	# The old padding belonged to a 1.20 m-tall array and pushed the header
	# above two metres. Re-derived from the 0.84 m Couch grid: enough timber
	# below for the outgoing slot and a narrow crown above the house plate.
	_part_box(Vector3(0, 1.235, Z_SURROUND),
			Vector3(width + 0.12, 1.39, 0.05),
			_flat(Color(0.47, 0.325, 0.185), 0.6), _fixed)
	# Header plate: THE ORISON / U.S. MAIL, incised brass. The lettering is
	# a quad — BoxMesh atlas-crops its faces and would show three letters.
	_part_box(Vector3(0, ARRAY_BASE + height + 0.085, Z_SURROUND - 0.028),
			Vector3(width - 0.06, 0.13, 0.010), _brass_dark, _fixed)
	var header := MeshInstance3D.new()
	var header_quad := QuadMesh.new()
	header_quad.size = Vector2(width - 0.06, 0.13)
	header.mesh = header_quad
	var header_mat := StandardMaterial3D.new()
	header_mat.albedo_texture = load(TEX_DIR + "T_mailbank_header.png")
	header_mat.roughness = 0.5
	header_mat.metallic = 0.45
	header.material_override = header_mat
	header.position = Vector3(0, ARRAY_BASE + height + 0.085,
			Z_SURROUND - 0.034)
	header.rotation.y = PI
	_fixed.add_child(header)
	var cards: Texture2D = load(TEX_DIR + "T_mailbank_cards.png")
	var fixed_cards := SurfaceTool.new()
	fixed_cards.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in CARD_ORDER.size():
		var unit: String = CARD_ORDER[i]
		# Placed by what the unit IS, not by where it sits in the atlas.
		var floor_no := int(unit.substr(0, 1))
		var col: int = maxi(0, STACKS.find(unit.substr(1, 1)))
		var row: int = ROWS - floor_no          # floor 6 -> row 0
		var x := (col - (COLS - 1) * 0.5) * DOOR_W
		var y := ARRAY_BASE + height - (row + 0.5) * DOOR_H
		if unit in EMPTY_UNITS:
			_build_empty_slot(Vector3(x, y, 0))
		elif unit == PLAYER_UNIT:
			_build_player_door(Vector3(x, y, 0), cards, i)
		else:
			_build_door(Vector3(x, y, 0), i)
			_append_card(fixed_cards, Vector3(x, y + 0.012, Z_CARD), i)
	# Twenty-three atlas regions become vertex UVs under one material. Keeping
	# the crop in twenty-three material offsets would either cost twenty-three
	# draws or make merge_static stamp the first tenant's name on every box.
	var cards_mesh := MeshInstance3D.new()
	cards_mesh.name = "FixedNameCards"
	cards_mesh.mesh = fixed_cards.commit()
	cards_mesh.material_override = _card_material(cards)
	_fixed.add_child(cards_mesh)
	# Outgoing mail: brass slot plate on the surround, flap held shut.
	_part_box(Vector3(width * 0.5 - 0.24, 0.60, Z_SURROUND - 0.028),
			Vector3(0.30, 0.10, 0.012), _brass_dark, _fixed)
	_part_box(Vector3(width * 0.5 - 0.24, 0.615, Z_SURROUND - 0.036),
			Vector3(0.20, 0.016, 0.006),
			_flat(Color(0.06, 0.05, 0.04), 0.9), _fixed)
	var flap := _part_box(Vector3(width * 0.5 - 0.24, 0.594,
			Z_SURROUND - 0.035), Vector3(0.21, 0.030, 0.006), _brass, _fixed)
	flap.rotation.x = -0.14
	# The fixed architecture is five material draws instead of roughly 140
	# little meshes. The only unmerged door is 4B, because it really opens.
	merge_static(_fixed, [cards_mesh])


## A unit without a household does not get a plausible-looking fake name.
## The compartment remains in the building's 4 x 6 address grid, but its
## missing leaf exposes the black inclined pocket behind the faceplate.
func _build_empty_slot(at: Vector3) -> void:
	_part_box(at + Vector3(0, 0, Z_BODY),
			Vector3(DOOR_W - 0.042, DOOR_H - 0.050, 0.018),
			_flat(Color(0.045, 0.038, 0.030), 0.92), _fixed)
	_part_box(at + Vector3(0, 0, Z_BEVEL),
			Vector3(DOOR_W - 0.028, DOOR_H - 0.038, 0.008),
			_brass_dark, _fixed)


## One tenant's box: brass body proud of the wood, beveled frame, door
## leaf, typed card behind glass, cylinder lock. `atlas_index` picks the
## card and staggers which doors read polished versus patinated.
func _build_door(at: Vector3, atlas_index: int) -> void:
	_part_box(at + Vector3(0, 0, Z_BODY),
			Vector3(DOOR_W - 0.018, DOOR_H - 0.026, 0.055),
			_brass_dark, _fixed)
	_part_box(at + Vector3(0, 0, Z_BEVEL),
			Vector3(DOOR_W - 0.028, DOOR_H - 0.038, 0.008),
			_brass_dark if atlas_index % 3 != 1 else _brass, _fixed)
	_part_box(at + Vector3(0, -0.008, Z_LEAF),
			Vector3(LEAF_W, LEAF_H, 0.008),
			_brass if atlas_index % 3 != 1 else _brass_dark, _fixed)
	# Couch's carrier flap belongs to the shared faceplate, not the little
	# tenant leaf. It gets one job and leaves enough brass for card and lock.
	_part_box(at + Vector3(0, 0.052, Z_CARD_FRAME),
			Vector3(LEAF_W - 0.018, 0.018, 0.005), _brass_dark, _fixed)
	_part_box(at + Vector3(0, 0.049, Z_CARD),
			Vector3(LEAF_W - 0.050, 0.006, 0.004), _brass, _fixed)
	_card_frame(at + Vector3(-0.025, 0.012, 0), _fixed)
	_lock(at + Vector3(0.105, -0.039, Z_LOCK), _fixed)


## The player's door is the same door on a working hinge, with a body
## that actually holds things.
func _build_player_door(at: Vector3, cards: Texture2D, index: int) -> void:
	# The box body, near-black inside-looking front so the open door reads
	# as a cavity, with the waiting mail proud of it.
	_part_box(at + Vector3(0, 0, Z_BODY),
			Vector3(DOOR_W - 0.018, DOOR_H - 0.026, 0.055),
			_flat(Color(0.09, 0.075, 0.055), 0.85))
	# The carrier can feed 4B while its tenant door stays locked; this flap is
	# fixed to the faceplate just like the other twenty-three.
	_part_box(at + Vector3(0, 0.052, Z_CARD_FRAME),
			Vector3(LEAF_W - 0.018, 0.018, 0.005), _brass_dark, _fixed)
	_part_box(at + Vector3(0, 0.049, Z_CARD),
			Vector3(LEAF_W - 0.050, 0.006, 0.004), _brass, _fixed)
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
	leaf.position = Vector3(LEAF_W * 0.5, -0.008, 0)
	_hinge.add_child(leaf)
	_card(cards, index, Vector3(LEAF_W * 0.5 - 0.025, 0.012, 0), _hinge)
	_lock(Vector3(LEAF_W * 0.5 + 0.105, -0.039,
			Z_LOCK - Z_LEAF), _hinge)
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
	_card_frame(local_at, parent)
	var card := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.142, 0.038)
	card.mesh = quad
	card.material_override = _card_material(cards, atlas_index)
	card.position = local_at + Vector3(0, 0, Z_CARD - Z_LEAF)
	card.rotation.y = PI
	parent.add_child(card)


func _card_frame(local_at: Vector3, parent: Node3D) -> void:
	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(0.155, 0.048, 0.004)
	frame.mesh = frame_mesh
	frame.material_override = _brass_dark
	frame.position = local_at + Vector3(0, 0,
			Z_CARD_FRAME - Z_LEAF if parent == _hinge else Z_CARD_FRAME)
	parent.add_child(frame)


func _card_material(cards: Texture2D, atlas_index := -1) -> StandardMaterial3D:
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
	if atlas_index >= 0:
		card_mat.uv1_scale = Vector3(1.0 / CARD_COLS, 1.0 / CARD_ROWS, 1.0)
		card_mat.uv1_offset = Vector3(
				float(atlas_index % CARD_COLS) / CARD_COLS,
				float(atlas_index / CARD_COLS) / CARD_ROWS, 0.0)
	card_mat.roughness = 0.42  # glass front
	card_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return card_mat


func _append_card(st: SurfaceTool, at: Vector3, atlas_index: int) -> void:
	var hw := 0.071
	var hh := 0.019
	var u0 := float(atlas_index % CARD_COLS) / CARD_COLS
	var v0 := float(atlas_index / CARD_COLS) / CARD_ROWS
	var u1 := u0 + 1.0 / CARD_COLS
	var v1 := v0 + 1.0 / CARD_ROWS
	var vertices := [
		# This batch is authored directly on the -Z face, so the player sees
		# the triangle's back. Reverse U here; the independent 4B QuadMesh is
		# rotated physically and keeps the ordinary atlas transform.
		[Vector3(at.x - hw, at.y + hh, at.z), Vector2(u1, v0)],
		[Vector3(at.x + hw, at.y - hh, at.z), Vector2(u0, v1)],
		[Vector3(at.x + hw, at.y + hh, at.z), Vector2(u0, v0)],
		[Vector3(at.x - hw, at.y + hh, at.z), Vector2(u1, v0)],
		[Vector3(at.x - hw, at.y - hh, at.z), Vector2(u1, v1)],
		[Vector3(at.x + hw, at.y - hh, at.z), Vector2(u0, v1)],
	]
	for vertex in vertices:
		st.set_normal(Vector3(0, 0, -1))
		st.set_uv(vertex[1])
		st.add_vertex(vertex[0])


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


func _part_box(at: Vector3, size: Vector3,
		material: StandardMaterial3D, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	if material:
		node.material_override = material
	node.position = at
	(parent if parent != null else self).add_child(node)
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
			deg_to_rad(95.0) if open else 0.0, 0.4) \
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


## A small, stable inspection surface for audits. Closed mesh count protects
## the lobby draw budget; the sweep AABB protects the extra 70 mm of new leaf.
func inspection_state() -> Dictionary:
	return {
		"address_count": CARD_ORDER.size(),
		"card_count": CARD_ORDER.size() - EMPTY_UNITS.size(),
		"fixed_door_count": CARD_ORDER.size() - EMPTY_UNITS.size() - 1,
		"empty_slot_count": EMPTY_UNITS.size(),
		"carrier_flap_count": CARD_ORDER.size() - EMPTY_UNITS.size(),
		"door_width": DOOR_W,
		"door_height": DOOR_H,
		"player_center_y": ARRAY_BASE + (4.0 - 0.5) * DOOR_H,
		"mesh_count": _mesh_count(self),
		"open_angle_deg": 95.0,
		"open_sweep": AABB(Vector3(-0.20, 1.32, -0.40),
				Vector3(0.40, 0.18, 0.42)),
	}


func _mesh_count(node: Node) -> int:
	var count := 1 if node is VisualInstance3D else 0
	for child in node.get_children():
		count += _mesh_count(child)
	return count
