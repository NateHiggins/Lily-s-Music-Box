extends Node3D
## Stable, resident-specific places. This registry never chooses attendance,
## spawns a second resident, changes a timetable, or adds a blocking seat box.
const DATA := "res://data/orison_v2/bar_resident_places.json"
var places: Dictionary = {}
var claims: Dictionary = {}
var errors: Array[String] = []

func setup(region: OrisonV2BarRegion) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if source is not Dictionary or source.get("schema_version") != 1: return false
	var rows := {}
	var geometry := region.get_node_or_null("RetainedBarGeometry")
	if geometry == null or not geometry.has_meta("bar_cafe_yaw_correction"): return false
	var chair_correction := float(geometry.get_meta("bar_cafe_yaw_correction"))
	for floor: Dictionary in region.source_layout.floors:
		if floor.id == "F01":
			for row: Dictionary in floor.furniture: rows[str(row.id)] = row
	if not rows.has("retail_bar_floor"): return false
	var floor_source: Dictionary = rows["retail_bar_floor"]
	var main_floor := float(floor_source.z0) + float(floor_source.h)
	var additions := {}
	for row: Dictionary in source.alcove:
		if additions.has(str(row.id)): return false
		additions[str(row.id)] = row
	var owners := {}
	var roster := preload("res://scripts/characters/orison_v2_resident_presentation.gd").roster()
	for resident: Dictionary in roster: owners[str(resident.id)] = true
	for row: Dictionary in source.places:
		var identity := str(row.resident)
		var furniture := str(row.furniture)
		if not owners.has(identity) or places.has(identity) or str(row.reason).is_empty(): return false
		var at: Vector3
		var yaw := 0.0
		var standing_height := -2.8
		if additions.has(furniture):
			var chair: Dictionary = additions[furniture]
			var p: Array = chair.at
			standing_height = float(p[2])
			at = GameBoot.b2g([p[0], p[1], standing_height + .49])
			yaw = deg_to_rad(float(chair.yaw)) + PI
		elif rows.has(furniture):
			var item: Dictionary = rows[furniture]
			if furniture.begins_with("retail_bar_stool"):
				# Pipe seats own p0/p1, not an assembly's z0. Their support is
				# the actual retained room floor, not the raised seat endpoint.
				standing_height = main_floor
				at = GameBoot.b2g(item.p1)
				yaw = PI # counter is north of the stools in source XY.
			else:
				standing_height = float(item.z0)
				var p: Array = item.at
				var seat_height := .475 if item.asm == "couch" else .478
				at = GameBoot.b2g([p[0], p[1], standing_height + seat_height])
				yaw = deg_to_rad(float(item.yaw)) + (PI if item.asm == "chair" else 0.0)
				if item.asm == "chair": yaw += chair_correction
		else: return false
		var marker := Marker3D.new()
		marker.name = "Preferred_" + identity
		add_child(marker); marker.position = at; marker.rotation.y = yaw
		var forward := marker.basis.z
		# Approach café chairs and stools from the aisle behind them, rather
		# than placing a standing body inside the table or counter footrail.
		var behind := furniture.begins_with("retail_bar_ch") or furniture.begins_with("retail_bar_stool")
		# Mina's standing place stays close to her chair, leaving the actual
		# 660 mm player capsule an aisle beside the retained deck handrail.
		var distance := .6 if identity == "mina_vale" else .8
		var approach := at + forward * (-distance if behind else distance)
		approach.y = standing_height
		places[identity] = {"marker": marker, "furniture": furniture, "reason": str(row.reason),
			"approach": approach, "floor_y": standing_height}
	if places.size() != 18 or owners.size() != 18: return false
	if not _mount_native(source, region): return false
	# Refit the existing three player sockets to their actual banquettes.
	# Keep their existing seated/occupied authority; no extra collision boxes.
	for i in 3:
		var seat := region.actors.get_node_or_null("BAR_SEAT_%d" % i) as BarSeatZone
		if seat == null: return false
		var owner_id := ""
		for resident: String in places:
			if str(places[resident].furniture) == "retail_bar_banq%d" % i: owner_id = resident
		if owner_id.is_empty(): return false
		var marker: Marker3D = places[owner_id].marker
		seat.global_transform = marker.global_transform
		places[owner_id]["player_socket"] = seat
	return true

func _mount_native(source: Dictionary, region: OrisonV2BarRegion) -> bool:
	var packed := load(str(source.asset)) as PackedScene
	if packed == null: return false
	var model := packed.instantiate() as Node3D
	var parts := {}
	for part: Dictionary in source.parts:
		if parts.has(str(part.name)) or not MatLib.SETS.has(str(part.catalog_key)): model.free(); return false
		parts[str(part.name)] = part
	var mounted := 0
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not parts.has(str(draw.name)): model.free(); return false
		var part: Dictionary = parts[str(draw.name)]
		if draw.mesh.get_surface_count() != 1 or draw.mesh.get_faces().size() != int(part.triangles) * 3:
			model.free(); return false
		var key := str(part.catalog_key)
		if absf(float(MatLib.SETS[key][3]) - float(part.tile)) > .000001: model.free(); return false
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false; material.uv1_scale = Vector3.ONE / float(part.tile)
		var tint: Array = part.tint
		material.albedo_color = Color(tint[0], tint[1], tint[2], tint[3])
		draw.mesh = draw.mesh.duplicate() as ArrayMesh
		draw.mesh.surface_set_material(0, material)
		draw.name = "F01_retail_bar_native_alcove_" + str(part.name)
		draw.set_meta("material_key", key)
		draw.set_meta("bar_resident_assembly", str(part.assembly))
		# Static native furniture retains real support and obstacle faces.
		# There is no collision or sweep simulation on the NPC place markers.
		draw.create_trimesh_collision()
		mounted += 1
	if mounted != parts.size(): model.free(); return false
	add_child(model)
	# Preserve the same material-state and cache owner as the other bar stock.
	region.surface_pass.apply({"bar_resident_alcove": model})
	return true

func preferred(resident: String) -> Dictionary:
	return places.get(resident, {})

func claim(resident: String, actor: Node3D) -> bool:
	if not places.has(resident) or not is_instance_valid(actor): return false
	if claims.has(resident) and is_instance_valid(claims[resident]) and claims[resident] != actor: return false
	var place: Dictionary = places[resident]
	var socket := place.get("player_socket") as BarSeatZone
	if socket != null:
		if socket.seated or (not socket.occupied_by.is_empty() and socket.occupied_by != resident): return false
		socket.occupied_by = resident
	claims[resident] = actor
	return true

func release(resident: String, actor: Node3D) -> void:
	if claims.get(resident) != actor: return
	var socket := places[resident].get("player_socket") as BarSeatZone
	if socket != null and socket.occupied_by == resident: socket.occupied_by = ""
	claims.erase(resident)
