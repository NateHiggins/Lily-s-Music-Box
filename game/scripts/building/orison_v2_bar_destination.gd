extends Node3D
## The room's destination layout. Native construction, sockets and retained
## mechanisms share one frame; clocks, dialogue and game rules remain owners.
const DATA := "res://data/orison_v2/harukiya_destination_layout.json"
const Retirement := preload("res://scripts/building/harukiya_destination_retirement.gd")
const Kit := preload("res://scripts/building/orison_v2_harukiya_drumkit.gd")
var spec: Dictionary = {}
var retirement_audit: Dictionary = {}

func mount(cell: Node3D, original_layout: Dictionary) -> bool:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if decoded is not Dictionary or decoded.get("schema_version") != 1: return false
	spec = decoded
	if spec.seats.size() < 24 or spec.native_parts.is_empty(): return false
	retirement_audit = Retirement.apply(cell, original_layout)
	if retirement_audit.is_empty(): return false
	name = "HarukiyaDestination"
	cell.add_child(self)
	if not _mount_architecture(): return false
	if not _retire_native_mounts(cell): return false
	var pool := cell.get_node_or_null("BarPool") as Node3D
	var curtains := cell.get_node_or_null("BarStage") as Node3D
	var furniture := cell.get_node_or_null("BarFurniture") as Node3D
	if pool == null or curtains == null or furniture == null: return false
	pool.transform = relocation("pool") * pool.transform
	# Keep the existing pool practical, its native suspension and game owner
	# together. Moving only the felt leaves its light a metre off-centre.
	var pool_supports := ["F01_BAR_LT_POOL__brass_dull", "F01_BAR_LT_POOL__iron_blackened"]
	var moved_supports := 0
	for draw: MeshInstance3D in cell.get_node("BarFixtureMounts").find_children("*", "MeshInstance3D", true, false):
		if str(draw.get_meta("bar_fixture_mount_part", "")) in pool_supports:
			draw.transform = relocation("pool") * draw.transform
			moved_supports += 1
	if moved_supports != pool_supports.size(): return false
	curtains.transform = relocation("stage_curtains") * curtains.transform
	var moves := {"Piano": "piano", "Microphone": "microphone", "DartsCabinet": "darts", "ScorePanel": "score_panel"}
	var counts := {}
	for draw: MeshInstance3D in furniture.find_children("*", "MeshInstance3D", true, false):
		var identity := str(draw.get_meta("bar_furniture_part", ""))
		var assembly := identity.get_slice("__", 0)
		if not moves.has(assembly): return false
		draw.transform = relocation(str(moves[assembly])) * draw.transform
		# The source microphone's old coarse hull is retired with its stock.
		if assembly == "Microphone": draw.create_trimesh_collision()
		counts[assembly] = int(counts.get(assembly, 0)) + 1
	if counts.size() != moves.size(): return false
	var kit_at: Array = spec.drumkit.at
	var kit_transform := Transform3D(Basis(Vector3.UP, deg_to_rad(float(spec.drumkit.yaw_deg))), GameBoot.b2g(kit_at))
	if Kit.mount(self, kit_transform) == null: return false
	var sockets := Node3D.new(); sockets.name = "SeatSockets"; add_child(sockets)
	for seat: Dictionary in spec.seats:
		if sockets.has_node(str(seat.id)): return false
		var marker := Marker3D.new(); marker.name = str(seat.id)
		# Furniture construction origin and a person's cushion contact differ.
		# Backed seats supply an explicit contact; open stools retain the center.
		marker.position = GameBoot.b2g(seat.get("sitter_at", seat.at))
		# Source furniture faces +Y; Godot's camera faces local -Z.
		marker.rotation.y = deg_to_rad(float(seat.yaw_deg))
		marker.set_meta("destination_seat_id", str(seat.id))
		marker.set_meta("seat", seat.duplicate(true)); sockets.add_child(marker)
	var navigation := Node3D.new(); navigation.name = "Navigation"; add_child(navigation)
	for row: Dictionary in spec.navigation.nodes:
		if navigation.has_node(str(row.id)): return false
		var marker := Marker3D.new(); marker.name = str(row.id)
		marker.position = GameBoot.b2g(row.at); navigation.add_child(marker)
	for edge: Array in spec.navigation.edges:
		if edge.size() != 2 or not navigation.has_node(str(edge[0])) or not navigation.has_node(str(edge[1])): return false
	return true

func relocation(identity: String) -> Transform3D:
	var row: Dictionary = spec.relocations[identity]
	var turn := Basis(Vector3.UP, deg_to_rad(float(row.get("source_yaw_delta_deg", row.get("yaw_deg", 0.0)))))
	return Transform3D(turn, GameBoot.b2g(row.at) - turn * GameBoot.b2g(row.source_anchor))

func _retire_native_mounts(cell: Node3D) -> bool:
	var sources := {
		"BarFixtureMounts": ["res://data/orison_v2/bar_fixture_mounts.json", "bar_fixture_mount_part"],
		"BarPipeSupports": ["res://data/orison_v2/bar_pipe_supports.json", "bar_pipe_support_part"]}
	var known := {}
	for group: String in sources:
		var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(sources[group][0]))
		if decoded is not Dictionary: return false
		known[group] = {}
		for part: Dictionary in decoded.parts: known[group][str(part.name)] = part
	var retiring: Array[MeshInstance3D] = []
	for row: Dictionary in spec.get("retire_native_parts", []):
		var group := str(row.parent)
		if not known.has(group) or not known[group].has(str(row.name)): return false
		var parent := cell.get_node_or_null(group)
		if parent == null: return false
		var found: MeshInstance3D
		for draw: MeshInstance3D in parent.find_children("*", "MeshInstance3D", true, false):
			if str(draw.get_meta(sources[group][1], "")) != str(row.name): continue
			if found != null or retiring.has(draw): return false
			found = draw
		if found == null: return false
		retiring.append(found)
	var records: Array = []
	for draw: MeshInstance3D in retiring:
		var count := draw.mesh.get_faces().size()/3
		var group := str(draw.get_parent().name)
		records.append({"parent": group, "name": str(draw.get_meta(sources[group][1])), "triangles": count,
			"colliders": draw.find_children("*", "CollisionShape3D", true, false).size()})
		draw.get_parent().remove_child(draw); draw.free()
	retirement_audit["retired_native_mounts"] = records
	return true

func _mount_architecture() -> bool:
	var packed := load(str(spec.asset)) as PackedScene
	if packed == null: return false
	var model := packed.instantiate() as Node3D
	if model == null: return false
	var parts := {}; var seen := {}; var finishes := {}
	for part: Dictionary in spec.native_parts:
		if parts.has(str(part.name)): model.free(); return false
		parts[str(part.name)] = part
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var identity := str(draw.name)
		if not parts.has(identity) or seen.has(identity): model.free(); return false
		var part: Dictionary = parts[identity]
		if draw.mesh.get_surface_count() != 1 or draw.mesh.get_faces().size() != int(part.triangles)*3:
			model.free(); return false
		var finish_id := str(part.material)
		if not finishes.has(finish_id):
			var finish: Dictionary = spec.materials.get(finish_id, {})
			var key := str(finish.get("catalog_key", ""))
			if not MatLib.SETS.has(key): model.free(); return false
			var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
			material.uv1_triplanar = false
			material.uv1_scale = Vector3.ONE / float(MatLib.SETS[key][3])
			var tint: Array = finish.tint
			material.albedo_color = Color(tint[0], tint[1], tint[2], tint[3])
			material.normal_scale = float(finish.get("normal", material.normal_scale))
			material.roughness = float(finish.get("roughness", material.roughness))
			finishes[finish_id] = material
		draw.mesh = draw.mesh.duplicate() as ArrayMesh
		draw.mesh.surface_set_material(0, finishes[finish_id])
		draw.set_meta("material_key", str(spec.materials[finish_id].catalog_key))
		draw.set_meta("harukiya_destination_part", identity)
		draw.set_meta("harukiya_pigment", float(spec.materials[finish_id].get("pigment", 0.9)))
		draw.name = "F01_retail_bar_destination_" + identity
		draw.create_trimesh_collision(); seen[identity] = true
	if seen.size() != parts.size(): model.free(); return false
	model.name = "Architecture"; add_child(model)
	return true

func marker_record(original: Dictionary) -> Dictionary:
	var result := original.duplicate(true)
	if str(original.id) in ["F01_BAR_POOL", "F01_BAR_LT_POOL"]:
		result.pos = _source(relocation("pool") * GameBoot.b2g(original.pos))
	elif str(original.id) == "F01_BAR_DARTS":
		result.pos = spec.architecture.darts_ledge.actor_at
		result.yaw_deg = float(original.get("yaw_deg", 0.0)) - float(spec.relocations.darts.source_yaw_delta_deg)
	elif str(original.id) == "F01_BAR_STAGE_SIGN":
		result.pos = _source(relocation("stage_curtains") * GameBoot.b2g(original.pos))
	for row: Dictionary in spec.get("fixture_relocations", []):
		if str(original.id) == str(row.id):
			if original.pos != row.source_at: return {}
			result.pos = row.at
	return result

func fit_actors(region: OrisonV2BarRegion) -> bool:
	var pool := region.actors.get_node_or_null("BAR_POOL_TABLE") as InspectableZone
	if pool == null: return false
	# Inspection area is already fitted in its old frame; move its owner once.
	pool.transform = relocation("pool") * pool.transform
	# Old toggle sockets are superseded by all 24 authored direct-grab seats.
	for i in 3:
		var old := region.actors.get_node_or_null("BAR_SEAT_%d" % i)
		if old == null: return false
		region.actors.remove_child(old); old.free()
	return true

func calibrate() -> void:
	Kit.calibrate(get_node("HarukiyaDrumKit"))
	for draw: MeshInstance3D in get_node("Architecture").find_children("*", "MeshInstance3D", true, false):
		for surface in draw.mesh.get_surface_count():
			var material := draw.get_surface_override_material(surface) as ShaderMaterial
			if material != null:
				material.set_shader_parameter("pigment_variation", float(draw.get_meta("harukiya_pigment", 0.9)))

static func _source(point: Vector3) -> Array:
	return [point.x, -point.z, point.y]
