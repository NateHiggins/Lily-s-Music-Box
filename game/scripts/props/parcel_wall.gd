extends Node3D
## The parcel wall's tags and handholds. The parcels themselves are the shop's own fitted meshes:
## a click takes hold of one, motion draws it out of the shelf, and it comes off only if it's the
## ticketed one, drawn the whole way. Any other slides back. ParcelErrands owns the book.

const MaterialSets := preload("res://scripts/generated/material_sets.gd")
const TAG_KEY := "paper"
const CELL := "shop_model_laundry"
const FITTINGS := "LaundryFittings"
const DRAW_PREFIX := "F01_retail_laundry_storm_shop_model_laundry_parcel"
const TRAVEL := 0.34
const TAKEN_AT := 0.85
const DRAG_PIXELS := 200.0
const SETTLE_SPEED := 0.8
const TAG_LIFT := 0.002
const LABEL_LIFT := 0.0045
const TAG_TINT := Color(0.8, 0.72, 0.56)
const LABEL_RANGE := 4.0
const CHECK_SECONDS := 1.0

var passage: Node3D
var tags: MultiMesh
var slots := {}
var held := ""
var _fittings_id := 0
var _today := LaundrySales.UNSET
var _since_check := 0.0


## Each row is the layout's record of one parcel, keyed by its ParcelErrands id.
func configure(region: Node3D, rows: Dictionary) -> bool:
	passage = region
	var scene := load("res://assets/props/parcel_tag.glb") as PackedScene
	if scene == null or not MaterialSets.SETS.has(TAG_KEY):
		return false
	var model := scene.instantiate() as Node3D
	var card := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var material := MatLib.get_mat(TAG_KEY).duplicate() as StandardMaterial3D
	material.uv1_triplanar = false
	material.uv1_scale = Vector3.ONE / float(MaterialSets.SETS[TAG_KEY][3])
	material.albedo_color = TAG_TINT
	tags = MultiMesh.new()
	tags.transform_format = MultiMesh.TRANSFORM_3D
	tags.mesh = card.mesh
	tags.instance_count = rows.size()
	var tag_draw := MultiMeshInstance3D.new()
	tag_draw.name = "ParcelTags"
	tag_draw.multimesh = tags
	tag_draw.material_override = material
	tag_draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tag_draw)
	model.free()
	var index := 0
	for parcel: String in rows:
		var row: Dictionary = rows[parcel]
		var rect: Array = row.rect
		var bottom := float(row.z0)
		var top := bottom + float(row.h)
		var size := Vector3(float(rect[2]) - float(rect[0]), top - bottom, float(rect[3]) - float(rect[1]))
		var centre := GameBoot.b2g([(float(rect[0]) + float(rect[2])) * 0.5, (float(rect[1]) + float(rect[3])) * 0.5, (bottom + top) * 0.5])
		var slot := {"index": index, "rest": centre, "half_depth": size.x * 0.5, "along": 0.0, "draws": [], "rests": []}
		var words := Label3D.new()
		words.name = "Tag_" + parcel
		words.text = str(ParcelErrands.ticket(parcel))
		words.font_size = 48
		words.pixel_size = 0.0005
		words.modulate = Color(0.07, 0.06, 0.05)
		words.outline_size = 0
		words.double_sided = false
		words.rotation.y = PI * 0.5
		words.visibility_range_end = LABEL_RANGE
		add_child(words)
		slot.words = words
		slots[parcel] = slot
		if int(parcel.get_slice("_", 0)) in range(ParcelErrands.FIRST_TICKET_ROW, ParcelErrands.UNCLAIMED_ROW):
			var part := Node3D.new()
			part.name = "Parcel_" + parcel
			part.position = centre
			add_child(part)
			var area: Area3D = preload("res://scripts/props/manipulation_area.gd").install(part, _grip.bind(parcel))
			var shape := BoxShape3D.new()
			shape.size = size + Vector3.RIGHT * 0.01
			var collision := CollisionShape3D.new()
			collision.shape = shape
			area.add_child(collision)
			slot.part = part
		index += 1
	RealityState.state_changed.connect(refresh)
	refresh()
	return true


## Residency can refit the shop, so the meshes are looked up again whenever they've been replaced.
func _bind() -> void:
	var cell: Node3D = passage.cell_nodes.get(CELL)
	var fittings: Node = cell.get_node_or_null(FITTINGS) if cell != null else null
	var identity := fittings.get_instance_id() if fittings != null else 0
	if identity == _fittings_id:
		return
	_fittings_id = identity
	for parcel: String in slots:
		slots[parcel].draws = []
		slots[parcel].rests = []
	if fittings == null:
		return
	for draw: MeshInstance3D in fittings.find_children(DRAW_PREFIX + "*", "MeshInstance3D", true, false):
		var slot: Variant = slots.get(str(draw.name).trim_prefix(DRAW_PREFIX).get_slice("__", 0))
		if slot != null:
			slot.draws.append(draw)
			slot.rests.append(draw.position)


func refresh() -> void:
	_bind()
	_today = LaundrySales.day()
	for parcel: String in slots:
		_show(parcel)


func _show(parcel: String) -> void:
	var slot: Dictionary = slots[parcel]
	var there := parcel == held or ParcelErrands.on_wall(parcel, _today)
	for draw: MeshInstance3D in slot.draws:
		draw.visible = there
	slot.words.visible = there
	_pose(parcel)
	if not there:
		tags.set_instance_transform(int(slot.index), Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))


func _pose(parcel: String) -> void:
	var slot: Dictionary = slots[parcel]
	var out := Vector3.RIGHT * float(slot.along)
	var face: Vector3 = slot.rest + out + Vector3.RIGHT * float(slot.half_depth)
	tags.set_instance_transform(int(slot.index), Transform3D(Basis(), face + Vector3.RIGHT * TAG_LIFT))
	slot.words.position = face + Vector3.RIGHT * LABEL_LIFT
	if slot.has("part"):
		slot.part.position = slot.rest + out
	for i in slot.draws.size():
		var draw: MeshInstance3D = slot.draws[i]
		if is_instance_valid(draw):
			draw.position = slot.rests[i] + draw.get_parent().global_basis.inverse() * global_basis.x * float(slot.along)


func _grip(parcel: String) -> Dictionary:
	if not ParcelErrands.on_wall(parcel, _today) or (held != "" and held != parcel):
		return {}
	var slot: Dictionary = slots[parcel]
	return {"owner": self, "part": slot.part, "frame": self, "kind": "slide", "axis": Vector3.RIGHT,
		"minimum": 0.0, "maximum": TRAVEL, "gesture_travel_px": DRAG_PIXELS,
		"gesture_screen_axis": Vector2.DOWN,
		"reach_point": func(): return to_global(slot.rest),
		"unobstructed_hold": true,
		"read": func(): return slot.along,
		"write": func(value: float):
			if held == parcel:
				slot.along = value
				_pose(parcel),
		"owns": func(): return held == parcel,
		"begin": func():
			if held != "":
				return false
			_bind()
			held = parcel
			return true,
		"end": _release}


func _release() -> void:
	var parcel := held
	held = ""
	if parcel == "":
		return
	var slot: Dictionary = slots[parcel]
	if float(slot.along) >= TRAVEL * TAKEN_AT and ParcelErrands.take(parcel):
		slot.along = 0.0
	refresh()


func _process(delta: float) -> void:
	_since_check += delta
	if _since_check >= CHECK_SECONDS:
		_since_check = 0.0
		_bind()
		if LaundrySales.day() != _today:
			refresh()
	for parcel: String in slots:
		var slot: Dictionary = slots[parcel]
		if parcel != held and float(slot.along) > 0.0:
			slot.along = move_toward(float(slot.along), 0.0, SETTLE_SPEED * delta)
			_pose(parcel)
