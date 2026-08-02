class_name OrisonDetailPass
extends Node
## Low-overhead lived-in pass. Primitive clutter and infrastructure are
## batched into two MultiMeshes per floor; narrative paper uses one quad per
## apartment with four shared cached textures.

const STORY_ATLAS := \
	"res://assets/building/textures/story_details/resident_ephemera_atlas.png"
const INFRA_ATLAS := \
	"res://assets/building/textures/story_details/orison_infrastructure_atlas.png"
const PROFILE_PATH := "res://data/resident_story_details.json"

var detail_count := 0
var decal_count := 0


func build(layout: Dictionary, floor_nodes: Dictionary) -> Dictionary:
	name = "OrisonDetailPass"
	var batches := {}
	for floor_id in floor_nodes:
		batches[floor_id] = {"boxes": [], "cylinders": []}
	_build_infrastructure(layout, floor_nodes, batches)
	_build_resident_details(layout, floor_nodes, batches)
	for floor_id in batches:
		var parent: Node3D = floor_nodes[floor_id]
		_emit_batch(parent, batches[floor_id].boxes, BoxMesh.new(), "trim")
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.5
		cylinder.bottom_radius = 0.5
		cylinder.height = 1.0
		cylinder.radial_segments = 10
		_emit_batch(parent, batches[floor_id].cylinders, cylinder, "metal")
	return {"details": detail_count, "decals": decal_count}


func _build_infrastructure(layout: Dictionary, floor_nodes: Dictionary,
		batches: Dictionary) -> void:
	for floor in layout.floors:
		var floor_id: String = floor.id
		if not batches.has(floor_id):
			continue
		var z := float(floor.z)
		# Continuous red standpipe, brass couplings, electrical access panel,
		# extinguisher cabinet and pipe brackets beside the stair core.
		_cylinder(batches[floor_id], [3.02, -3.02, z + 1.55],
				[0.055, 3.10, 0.055], Color(0.42, 0.055, 0.035))
		for h in [0.18, 1.55, 2.92]:
			_cylinder(batches[floor_id], [3.02, -3.02, z + h],
					[0.078, 0.045, 0.078], Color(0.52, 0.36, 0.16))
		_box(batches[floor_id], [2.73, -3.10, z + 1.30],
				[0.42, 0.08, 0.58], Color(0.30, 0.31, 0.28))
		_box(batches[floor_id], [-2.76, -3.10, z + 1.05],
				[0.34, 0.08, 0.70], Color(0.45, 0.09, 0.055))
		for h in [0.42, 1.18, 1.94, 2.70]:
			_box(batches[floor_id], [2.15, -3.12, z + h],
					[0.035, 0.045, 0.34], Color(0.36, 0.35, 0.31))
		# Floor-specific institutional decal.
		var panel := 0
		if floor_id == "B1":
			panel = 0
		elif floor_id in ["F01", "F03", "F05"]:
			panel = 1
		elif floor_id in ["F02", "F04", "F06"]:
			panel = 2
		else:
			panel = 3
		_add_decal(floor_nodes[floor_id], INFRA_ATLAS,
				panel % 2, panel / 2,
				[2.36, -3.19, z + 1.56], 0.0, Vector2(0.48, 0.48))
	# Lobby mail corner: the functional Cutler-style bank replaces the old
	# 24 flat placeholder boxes (which were stamped straight across a
	# window). It stands on the east partition — the one clear lobby wall —
	# facing the generated wood bank across the corner. A real prop: the
	# player's 4B door opens, and mail_catalog.json arrives through it.
	if floor_nodes.has("F01"):
		var bank := MailBankProp.new()
		bank.name = "LobbyMailBank"
		bank.position = GameBoot.b2g([5.24, -8.85, 0.0])
		bank.rotation.y = PI * 0.5
		floor_nodes["F01"].add_child(bank)


func _build_resident_details(layout: Dictionary, floor_nodes: Dictionary,
		batches: Dictionary) -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		push_warning("resident story-detail catalog missing")
		return
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	for profile in catalog.residents:
		var unit: String = profile.unit
		var floor_id := "F0" + unit.left(1)
		if not floor_nodes.has(floor_id):
			continue
		var floor: Dictionary = {}
		for candidate in layout.floors:
			if candidate.id == floor_id:
				floor = candidate
				break
		var room := _living_room(floor, unit)
		if room.is_empty():
			continue
		var rect: Array = room.rect
		var seed := absi(str(profile.resident).hash())
		var slot := float(profile.get("slot", 0))
		var u := clampf(0.20 + float(seed % 17) * 0.012 + slot * 0.10,
				0.14, 0.42)
		var v := clampf(0.22 + float((seed >> 5) % 19) * 0.010,
				0.18, 0.42)
		var x := lerpf(float(rect[0]), float(rect[2]), u)
		var y := lerpf(float(rect[1]), float(rect[3]), v)
		var z := float(floor.z)
		var color_data: Array = profile.accent
		var accent := Color(float(color_data[0]), float(color_data[1]),
				float(color_data[2]))
		# A tiny authored still life: document/archive box, vessel, and paper
		# stack. Transform and color vary per resident while meshes are shared.
		_box(batches[floor_id], [x, y, z + 0.13],
				[0.42, 0.32, 0.24], accent)
		_box(batches[floor_id], [x + 0.28, y + 0.08, z + 0.055],
				[0.30, 0.22, 0.075], Color(0.68, 0.61, 0.47))
		_cylinder(batches[floor_id], [x - 0.27, y + 0.04, z + 0.16],
				[0.09, 0.30, 0.09], accent.lightened(0.18))
		var panel := int(profile.panel)
		var wall_west := seed % 2 == 0
		var wall_x := float(rect[0]) + 0.105 if wall_west \
				else float(rect[2]) - 0.105
		var wall_y := lerpf(float(rect[1]), float(rect[3]),
				clampf(0.30 + slot * 0.16, 0.18, 0.78))
		_add_decal(floor_nodes[floor_id], STORY_ATLAS,
				panel % 2, panel / 2,
				[wall_x, wall_y, z + 1.34],
				PI * 0.5 if wall_west else -PI * 0.5,
				Vector2(0.54, 0.54))


func _living_room(floor: Dictionary, unit: String) -> Dictionary:
	for room in floor.get("rooms", []):
		if room.get("unit", "") == unit \
				and room.get("kind", "") == "living":
			return room
	for room in floor.get("rooms", []):
		if room.get("unit", "") == unit:
			return room
	return {}


func _box(batch: Dictionary, position_b: Array, size_b: Array,
		color: Color) -> void:
	batch.boxes.append({
		"transform": Transform3D(
			Basis.IDENTITY.scaled(Vector3(size_b[0], size_b[2], size_b[1])),
			GameBoot.b2g(position_b)),
		"color": color,
	})
	detail_count += 1


func _cylinder(batch: Dictionary, position_b: Array, size_b: Array,
		color: Color) -> void:
	batch.cylinders.append({
		"transform": Transform3D(
			Basis.IDENTITY.scaled(Vector3(size_b[0] * 2.0, size_b[1],
					size_b[2] * 2.0)),
			GameBoot.b2g(position_b)),
		"color": color,
	})
	detail_count += 1


func _emit_batch(parent: Node3D, entries: Array, mesh: PrimitiveMesh,
		material_key: String) -> void:
	if entries.is_empty():
		return
	var material := MatLib.get_mat(material_key).duplicate()
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = entries.size()
	for index in entries.size():
		multimesh.set_instance_transform(index, entries[index].transform)
		multimesh.set_instance_color(index, entries[index].color)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)


func _add_decal(parent: Node3D, atlas: String, col: int, row: int,
		position_b: Array, yaw: float, size: Vector2) -> void:
	var decal := StoryDecal.new()
	decal.setup(atlas, col, row, size)
	decal.position = GameBoot.b2g(position_b)
	decal.rotation.y = yaw
	parent.add_child(decal)
	decal_count += 1
