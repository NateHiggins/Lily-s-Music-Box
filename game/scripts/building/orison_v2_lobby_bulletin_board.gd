extends "res://scripts/props/lobby_bulletin_board.gd"
## V2 presentation of the building's notice board. V1 keeps the layout (which
## notice hangs where, and how crooked), the inspection tap and card, and the
## wireless notice's printed text and dated reading. Here the frame, field,
## pins and every sheet are Blender stock on catalogue finishes, and each
## notice's words are authored Label3D instead of a lettered texture.
const Native := preload("res://scripts/building/orison_v2_native_lobby_set.gd")

var native: RefCounted
## The "bulletin" block of res://data/orison_v2/lobby_set_placements.json.
var plan: Dictionary = {}
var notice_sheets: Array[MeshInstance3D] = []
var wireless_sheet: MeshInstance3D
var pins: MultiMeshInstance3D


func _ready() -> void:
	name = "LobbyBulletinBoard"
	if native == null or plan.is_empty():
		push_error("V2 notice board: native stock or plan not supplied")
		return
	native.mount_static(self, "Bulletin")
	var legend: Dictionary = plan.legend
	var plate := Native.lettering(str(legend.text), str(legend.font), int(legend.font_size), float(legend.pixel_size),
			_ink(legend.ink), _at(legend.at))
	plate.name = "NoticesLegend"
	add_child(plate)
	var pin_at: Array[Transform3D] = []
	var order: Array = PINNED + SPILLED
	for i in order.size():
		var spec: Dictionary = order[i]
		var cell: Array = spec.cell
		var at: Vector2 = spec.at
		var index := int(cell[1]) * COLS + int(cell[0])
		var depth := float(plan.cork_depth if i < PINNED.size() else plan.wall_depth)
		var sheet: MeshInstance3D = native.draw("Bulletin__Notice%d_ON_paper" % index)
		sheet.name = "Notice_%s" % str(plan.notices[index].key)
		sheet.transform = Transform3D(Basis(Vector3.BACK, float(spec.tilt)), Vector3(at.x, at.y, depth))
		add_child(sheet)
		_letter(sheet, plan.notices[index])
		notice_sheets.append(sheet)
		pin_at.append(sheet.transform * Transform3D(Basis.IDENTITY, Vector3(0, NOTE_H * 0.5 - 0.014, 0)))
		if _inspection_sheet == null:
			_inspection_sheet = sheet
			_inspection_sheet_rest_z = depth
	_build_inspection_owner(Vector3(1.42, 0.78, 0.20))
	_build_wireless_notice()
	pin_at.append(wireless_sheet.transform * Transform3D(Basis.IDENTITY, Vector3(0, float(plan.wireless.pin_y), 0)))
	_drive_pins(pin_at)
	if not _civil_time_provider.is_valid():
		# V1's own read-only handle onto the durable campaign clock.
		_civil_time_provider = Callable(_clock_reader, "day_info")


## The tenant hand-copy beside the board: V1's printed text on a native sheet.
func _build_wireless_notice() -> void:
	var spec: Dictionary = plan.wireless
	var centre := Vector3(float(spec.at[0]), float(spec.at[1]), float(plan.wall_depth))
	wireless_sheet = native.draw("Bulletin__Wireless_ON_paper")
	wireless_sheet.name = "WirelessLicenseNotice"
	wireless_sheet.transform = Transform3D(Basis(Vector3.BACK, float(spec.tilt)), centre)
	add_child(wireless_sheet)
	var text := Native.lettering(_wireless_notice.printed_text(), str(spec.font), int(spec.font_size), float(spec.pixel_size),
			_ink(spec.ink), Vector3(0, 0, float(plan.text_lift)))
	text.name = "WirelessLicenseText"
	text.visibility_range_end = float(plan.label_range)
	wireless_sheet.add_child(text)
	var area := ControlArea.new()
	area.name = "WirelessNoticeInspection"
	area.configure("wireless_notice")
	# Kept proud of the board's broad inspection rectangle, as V1 has it, so
	# the printed notice owns its own ray.
	area.position = Vector3(centre.x, centre.y, float(spec.area_z))
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(float(spec.size[0]), float(spec.size[1]), float(spec.area_depth))
	shape_node.shape = shape
	area.add_child(shape_node)
	add_child(area)


## One notice's words: heading, ruled line, typed body and signature.
func _letter(sheet: MeshInstance3D, row: Dictionary) -> void:
	var lift := float(plan.text_lift)
	var reach := float(plan.label_range)
	var ink := _ink(plan.ink)
	var head: Dictionary = plan.head
	var head_size := minf(float(head.pixel_size), Native.fit(str(row.head), str(head.font), int(head.font_size), float(head.max_width)))
	var heading := Native.lettering(str(row.head), str(head.font), int(head.font_size), head_size, ink, Vector3(0, float(head.y), lift))
	heading.name = "Head"
	var body: Dictionary = plan.body
	var typed := Native.lettering("\n".join(wrap_words(str(row.body), int(body.wrap))), str(body.font), int(body.font_size),
			float(body.pixel_size), ink, Vector3(float(body.left), float(body.top), lift))
	typed.name = "Body"
	typed.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	typed.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	typed.line_spacing = float(body.line_spacing_px)
	var foot: Dictionary = plan.sign
	var signed := Native.lettering(str(row.sign), str(foot.font), int(foot.font_size), float(foot.pixel_size), ink,
			Vector3(float(foot.left), float(foot.y), lift))
	signed.name = "Sign"
	signed.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var rule: MeshInstance3D = native.draw("Bulletin__Rule_ON_paper")
	rule.name = "Rule"
	for node: GeometryInstance3D in [heading, typed, signed, rule]:
		node.visibility_range_end = reach
		sheet.add_child(node)
	sheet.set_meta("notice_key", str(row.key))


## Greedy word wrap at a column, as the V1 notice tool wraps its typed bodies.
static func wrap_words(words: String, column: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in words.split(" ", false):
		if line.is_empty():
			line = word
		elif line.length() + 1 + word.length() <= column:
			line += " " + word
		else:
			lines.append(line)
			line = word
	if not line.is_empty():
		lines.append(line)
	return lines


## The words a mounted notice shows, as one line each (for readers and tests).
func notice_words(key: String) -> Dictionary:
	for sheet in notice_sheets:
		if str(sheet.get_meta("notice_key", "")) == key:
			return {"head": (sheet.get_node("Head") as Label3D).text,
				"body": (sheet.get_node("Body") as Label3D).text.replace("\n", " "),
				"sign": (sheet.get_node("Sign") as Label3D).text}
	return {}


func _drive_pins(at: Array[Transform3D]) -> void:
	var part: Dictionary = native.parts["Bulletin__Pin_ON_brass"]
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = part.mesh
	many.instance_count = at.size()
	for i in at.size():
		many.set_instance_transform(i, at[i])
	pins = MultiMeshInstance3D.new()
	pins.name = "Bulletin__Pins"
	pins.multimesh = many
	pins.material_override = part.material
	pins.set_meta("native_lobby_set_part", "Bulletin__Pin_ON_brass")
	add_child(pins)


func _at(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _ink(values: Array) -> Color:
	return Color(float(values[0]), float(values[1]), float(values[2]))
