class_name DreamOrisonInterior
extends Node3D
## THE ORISON'S ARCHITECTURAL MEMORY.
##
## The room builder already uses exact waking-room footprints, but a footprint
## surrounded by plain boxes reads as a procedural corridor.  This pass gives
## every remembered room the construction grammar visible in the real Orison:
## high skirting, a 1.32 m dado, framed lower panels, picture rail, stepped
## cornice, cased 0.91 m openings and a pressed ceiling medallion.  It is all
## shallow visual relief.  The wall boxes remain the collision authority and
## the doorway apertures remain exactly the ones DreamRoomBuilder ruled.
##
## Every little length of moulding is a transform of one unit box.  Two
## MultiMeshes therefore submit the whole room in two draws instead of making
## a node and draw call for every rail, stile and crown step.

const DADO_TOP_M := 1.32
const PICTURE_RAIL_M := 2.18
const PANEL_BOTTOM_M := 0.15
const PANEL_TOP_M := 1.27
const BASEBOARD_H_M := 0.14
const RELIEF_M := 0.032
const DOOR_CASING_W_M := 0.105
const DOOR_CASING_PAD_M := 0.13
const PANEL_TARGET_W_M := 0.72
const MEDALLION_SEGMENTS := 24

const WAINSCOT_SOURCES := [
	"D00_4B_THRESHOLD",
	"D01_F04_LONG_HALL",
	"D03_LIFT_VOID",
	"D05_SERVICE_RISER",
	"D09_RETURN_HALL",
]


func configure(room: Dictionary, clear_ceiling: float) -> void:
	name = "OrisonInterior"
	add_to_group("dream_orison_interior")
	set_meta("room_key", str(room.get("key", "")))
	set_meta("source_module", str(room.get("source", "")))
	set_meta("visual_only", true)
	set_meta("collision_owner", "DreamRoomBuilder walls")
	if bool(room.get("blank", false)):
		# BLANKING is a spatial fault, not an interior-design variation.  A
		# room which forgot its contents and door frames must also forget the
		# architectural detail that would otherwise describe those frames.
		set_meta("millwork_instances", 0)
		set_meta("wainscot_instances", 0)
		return
	var rect: Array = room.get("rect", [])
	if rect.size() < 4:
		return

	var millwork: Array[Transform3D] = []
	var panels: Array[Transform3D] = []
	var walls := _wall_records(rect, room.get("doors", []))
	var has_wainscot := str(room.get("source", "")) in WAINSCOT_SOURCES
	for wall in walls:
		_build_wall_detail(millwork, panels, wall, has_wainscot,
				clear_ceiling)
	for door_value in room.get("doors", []):
		var door: Dictionary = door_value
		if not bool(door.get("sealed", false)):
			_build_door_casing(millwork, door, rect)
	_build_ceiling_medallion(millwork, rect, clear_ceiling)

	# Use the same analytic service-lamp response as the wall behind the
	# relief.  Ordinary StandardMaterial millwork was physically present but
	# black under the intentionally weak shadow-casting SpotLight3D; the dream
	# shader is what turns the tool pose into visible surface throughout this
	# passage.  Timber is still timber underneath that filter.
	var millwork_material := DreamMazeBuilder._material(Color("6b513c"),
			0.62, DreamMazeBuilder.MOTIF_TRIANGLE)
	var panel_material := DreamMazeBuilder._material(Color("425343"),
			0.76, DreamMazeBuilder.MOTIF_SPIRAL)
	if millwork_material is ShaderMaterial:
		(millwork_material as ShaderMaterial).set_shader_parameter(
				"consumed", 0.30)
		(millwork_material as ShaderMaterial).set_shader_parameter(
				"ground_dark", 0.38)
		DreamRoomBuilder.configure_architecture_material(millwork_material,
				rect, 4, 0.19, 0.010, 0.036, clear_ceiling)
	if panel_material is ShaderMaterial:
		(panel_material as ShaderMaterial).set_shader_parameter("consumed", 0.24)
		(panel_material as ShaderMaterial).set_shader_parameter("ground_dark", 0.34)
		DreamRoomBuilder.configure_architecture_material(panel_material,
				rect, 5, 0.16, 0.010, 0.032, clear_ceiling)
	_emit_multimesh("HistoricMillwork", millwork, millwork_material)
	_emit_multimesh("WainscotPanels", panels, panel_material)
	set_meta("millwork_instances", millwork.size())
	set_meta("wainscot_instances", panels.size())
	set_meta("door_casings", _open_door_count(room.get("doors", [])))
	set_meta("dado_height_m", DADO_TOP_M)
	set_meta("max_relief_m", RELIEF_M + 0.020)
	set_meta("shader_relief_layers", PackedStringArray([
			"tessera_faces", "recessed_grout", "cracked_medallions"]))
	set_meta("transition_anchors", PackedStringArray([
			"floor_wall_joints", "room_corners", "skirting", "dado",
			"picture_rail", "cornice", "door_casings", "ceiling_rose"]))
	set_meta("shader_relief_max_m", 0.042)


func _wall_records(rect: Array, doors: Array) -> Array[Dictionary]:
	var x0 := float(rect[0])
	var z0 := float(rect[1])
	var x1 := float(rect[2])
	var z1 := float(rect[3])
	var records: Array[Dictionary] = [
		{"side": "west", "along0": z0, "along1": z1,
				"fixed": x0, "axis": "z", "inward": 1.0, "cuts": []},
		{"side": "east", "along0": z0, "along1": z1,
				"fixed": x1, "axis": "z", "inward": -1.0, "cuts": []},
		{"side": "north", "along0": x0, "along1": x1,
				"fixed": z0, "axis": "x", "inward": 1.0, "cuts": []},
		{"side": "south", "along0": x0, "along1": x1,
				"fixed": z1, "axis": "x", "inward": -1.0, "cuts": []},
	]
	for door_value in doors:
		var door: Dictionary = door_value
		if bool(door.get("sealed", false)):
			continue
		var aperture: Array = door.get("aperture", [])
		if aperture.size() < 4:
			continue
		var side := _door_side(aperture, rect)
		for wall in records:
			if str(wall.side) != side:
				continue
			var cut: Array = []
			if str(wall.axis) == "x":
				cut = [float(aperture[0]) - DOOR_CASING_PAD_M,
						float(aperture[2]) + DOOR_CASING_PAD_M]
			else:
				cut = [float(aperture[1]) - DOOR_CASING_PAD_M,
						float(aperture[3]) + DOOR_CASING_PAD_M]
			wall.cuts.append(cut)
	return records


func _build_wall_detail(millwork: Array[Transform3D],
		panels: Array[Transform3D], wall: Dictionary, has_wainscot: bool,
		clear_ceiling: float) -> void:
	var whole := [[float(wall.along0), float(wall.along1)]]
	var clear_segments := whole
	for cut_value in wall.cuts:
		var cut: Array = cut_value
		var next: Array = []
		for segment_value in clear_segments:
			var segment: Array = segment_value
			if float(cut[1]) <= float(segment[0]) \
					or float(cut[0]) >= float(segment[1]):
				next.append(segment)
				continue
			if float(cut[0]) > float(segment[0]):
				next.append([float(segment[0]), float(cut[0])])
			if float(cut[1]) < float(segment[1]):
				next.append([float(cut[1]), float(segment[1])])
		clear_segments = next

	# Crown belongs to the ceiling, so it spans the lintels without the
	# door-width holes which once made the waking Orison look modular.
	_add_wall_run(millwork, wall, float(wall.along0), float(wall.along1),
			clear_ceiling - 0.055, 0.070, RELIEF_M)
	_add_wall_run(millwork, wall, float(wall.along0), float(wall.along1),
			clear_ceiling - 0.115, 0.045, RELIEF_M + 0.014)
	_add_wall_run(millwork, wall, float(wall.along0), float(wall.along1),
			clear_ceiling - 0.155, 0.025, RELIEF_M + 0.022)
	_add_wall_run(millwork, wall, float(wall.along0), float(wall.along1),
			PICTURE_RAIL_M, 0.042, RELIEF_M + 0.010)

	for segment_value in clear_segments:
		var segment: Array = segment_value
		var a := maxf(float(segment[0]), float(wall.along0))
		var b := minf(float(segment[1]), float(wall.along1))
		if b - a < 0.05:
			continue
		_add_wall_run(millwork, wall, a, b, BASEBOARD_H_M * 0.5,
				BASEBOARD_H_M, RELIEF_M + 0.010)
		if not has_wainscot:
			continue
		_add_wall_run(panels, wall, a, b,
				(PANEL_BOTTOM_M + PANEL_TOP_M) * 0.5,
				PANEL_TOP_M - PANEL_BOTTOM_M, RELIEF_M * 0.58)
		_add_wall_run(millwork, wall, a, b, DADO_TOP_M,
				0.052, RELIEF_M + 0.018)
		_add_wall_run(millwork, wall, a, b, 0.62, 0.035,
				RELIEF_M + 0.022)
		var count := maxi(1, int(round((b - a) / PANEL_TARGET_W_M)))
		for index in count + 1:
			var at := lerpf(a, b, float(index) / float(count))
			_add_wall_stile(millwork, wall, at, 0.20,
					PANEL_TOP_M - 0.07, 0.038, RELIEF_M + 0.024)


func _build_door_casing(records: Array[Transform3D], door: Dictionary,
		rect: Array) -> void:
	var aperture: Array = door.get("aperture", [])
	if aperture.size() < 4:
		return
	var side := _door_side(aperture, rect)
	var wall := _wall_for_side(side, rect)
	var a := float(aperture[0]) if str(wall.axis) == "x" \
			else float(aperture[1])
	var b := float(aperture[2]) if str(wall.axis) == "x" \
			else float(aperture[3])
	var height := float(door.get("height", 2.13))
	_add_wall_stile(records, wall, a - DOOR_CASING_W_M * 0.5,
			0.0, height, DOOR_CASING_W_M, RELIEF_M + 0.025)
	_add_wall_stile(records, wall, b + DOOR_CASING_W_M * 0.5,
			0.0, height, DOOR_CASING_W_M, RELIEF_M + 0.025)
	_add_wall_run(records, wall, a - DOOR_CASING_W_M,
			b + DOOR_CASING_W_M, height + 0.052,
			DOOR_CASING_W_M, RELIEF_M + 0.026)
	# The slightly proud cap is what makes the opening read as an old cased
	# doorway at flashlight distance instead of three bars around a hole.
	_add_wall_run(records, wall, a - DOOR_CASING_W_M * 1.45,
			b + DOOR_CASING_W_M * 1.45, height + 0.128,
			0.044, RELIEF_M + 0.036)


func _build_ceiling_medallion(records: Array[Transform3D], rect: Array,
		clear_ceiling: float) -> void:
	var center := Vector3((float(rect[0]) + float(rect[2])) * 0.5,
			clear_ceiling - 0.022,
			(float(rect[1]) + float(rect[3])) * 0.5)
	var room_radius := minf(float(rect[2]) - float(rect[0]),
			float(rect[3]) - float(rect[1]))
	var radius := clampf(room_radius * 0.17, 0.19, 0.42)
	for ring in 2:
		var rr := radius * (0.62 + float(ring) * 0.34)
		for segment in MEDALLION_SEGMENTS:
			var a0 := TAU * float(segment) / float(MEDALLION_SEGMENTS)
			var a1 := TAU * float(segment + 1) / float(MEDALLION_SEGMENTS)
			var mid := (a0 + a1) * 0.5
			var chord := 2.0 * rr * sin((a1 - a0) * 0.5)
			var at := center + Vector3(cos(mid) * rr, 0.0, sin(mid) * rr)
			_add_box(records, at, Vector3(chord + 0.012,
					0.030 + float(ring) * 0.008, 0.032), -mid)
	_add_box(records, center, Vector3(0.16, 0.045, 0.16), 0.0)


func _add_wall_run(records: Array[Transform3D], wall: Dictionary,
		a: float, b: float, y: float, height: float, depth: float) -> void:
	if b <= a:
		return
	var center := Vector3.ZERO
	var size := Vector3.ONE
	if str(wall.axis) == "x":
		center = Vector3((a + b) * 0.5, y,
				float(wall.fixed) + float(wall.inward) * depth * 0.5)
		size = Vector3(b - a, height, depth)
	else:
		center = Vector3(float(wall.fixed) + float(wall.inward) * depth * 0.5,
				y, (a + b) * 0.5)
		size = Vector3(depth, height, b - a)
	_add_box(records, center, size, 0.0)


func _add_wall_stile(records: Array[Transform3D], wall: Dictionary,
		at: float, y0: float, y1: float, width: float, depth: float) -> void:
	var center := Vector3.ZERO
	var size := Vector3.ONE
	if str(wall.axis) == "x":
		center = Vector3(at, (y0 + y1) * 0.5,
				float(wall.fixed) + float(wall.inward) * depth * 0.5)
		size = Vector3(width, y1 - y0, depth)
	else:
		center = Vector3(float(wall.fixed) + float(wall.inward) * depth * 0.5,
				(y0 + y1) * 0.5, at)
		size = Vector3(depth, y1 - y0, width)
	_add_box(records, center, size, 0.0)


func _add_box(records: Array[Transform3D], center: Vector3, size: Vector3,
		yaw: float) -> void:
	records.append(Transform3D(Basis(Vector3.UP, yaw).scaled(size), center))


func _emit_multimesh(node_name: String, records: Array[Transform3D],
		material: Material) -> void:
	if records.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = records.size()
	for index in records.size():
		mm.set_instance_transform(index, records[index])
	var visual := MultiMeshInstance3D.new()
	visual.name = node_name
	visual.multimesh = mm
	# Material override is also the discovery seam used by
	# DreamMazeRoot._collect_molten_materials().  Hiding it on BoxMesh.material
	# would leave this legitimate dream surface out of the lamp-pose update.
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(visual)


func _wall_for_side(side: String, rect: Array) -> Dictionary:
	match side:
		"west":
			return {"axis": "z", "fixed": float(rect[0]), "inward": 1.0}
		"east":
			return {"axis": "z", "fixed": float(rect[2]), "inward": -1.0}
		"north":
			return {"axis": "x", "fixed": float(rect[1]), "inward": 1.0}
		_:
			return {"axis": "x", "fixed": float(rect[3]), "inward": -1.0}


func _door_side(aperture: Array, rect: Array) -> String:
	var cx := (float(aperture[0]) + float(aperture[2])) * 0.5
	var cz := (float(aperture[1]) + float(aperture[3])) * 0.5
	var distances := {
		"west": absf(cx - float(rect[0])),
		"east": absf(cx - float(rect[2])),
		"north": absf(cz - float(rect[1])),
		"south": absf(cz - float(rect[3])),
	}
	var best := "west"
	for side in distances:
		if float(distances[side]) < float(distances[best]):
			best = str(side)
	return best


func _open_door_count(doors: Array) -> int:
	var count := 0
	for door in doors:
		if not bool(door.get("sealed", false)):
			count += 1
	return count
