extends Node
## The waking organism in V2 (v1r_waking_organism_20261109): the encroachment
## finds every organism case's flat in V2, its living fields cover V2's
## storeys, the fields bind V2's own wall materials, and the organism lives.

var _fails := 0
var _checks := 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


## RUL-012 for the cell's physical parts: every organelle and the cilia draw a
## registered recipe's three maps, with a full mip chain, on real mesh UVs.
## The lensing membrane is the one optical effect and is not held to this.
func _check_colony_surfaces(moss: Node3D, cilia: MultiMeshInstance3D) -> void:
	var drawn: Array = []
	for row: Dictionary in moss._organelles:
		var mi := row.node as MeshInstance3D
		drawn.append([str(mi.name), mi.mesh, mi.material_override as ShaderMaterial])
	if cilia != null:
		drawn.append(["WakingCilia", cilia.multimesh.mesh, cilia.material_override as ShaderMaterial])
	var skeleton: MeshInstance3D = moss._waking_skeleton
	_check(skeleton != null, "the cell has its microtubule cytoskeleton")
	if skeleton != null:
		drawn.append(["Cytoskeleton", skeleton.mesh, skeleton.material_override as ShaderMaterial])
		_check(not moss._organelles.any(func(row: Dictionary) -> bool: return row.node == skeleton),
			"the cytoskeleton is fixed to the cell and does not stream")
	var membrane := moss._waking.find_child("Membrane", true, false) as MeshInstance3D
	var web := (membrane.material_override as ShaderMaterial).get_shader_parameter("cytoplasm_web") as Texture2D
	_check(web != null and web.get_image().has_mipmaps(), "the membrane reads the milky cytoplasm web, mipmapped")
	# The cilia start inside the cell and leave through the membrane.
	if cilia != null:
		var roots: Array = moss._waking_cilium_roots((moss._waking.find_child("CiliumRoots", true, false) as MeshInstance3D).mesh)
		_check(roots.size() == moss.WAKING_CILIA and cilia.multimesh.instance_count == roots.size(),
			"every cilium has a basal body (%d)" % roots.size())
		var inside := 0
		var outward := 0
		var reach := membrane.mesh.get_aabb()
		for root: Dictionary in roots:
			var at: Vector3 = root.position
			# Inside the membrane's own bounds, above the floor.
			if at.y > 0.005 and absf(at.x) < reach.end.x and absf(at.z) < reach.end.z:
				inside += 1
			if (root.out as Vector3).dot(Vector3(at.x, 0.0, at.z).normalized()) > 0.3:
				outward += 1
		_check(inside == roots.size(), "the basal bodies sit inside the cell (%d of %d)" % [inside, roots.size()])
		_check(outward == roots.size(), "each cilium leaves outward through the membrane (%d of %d)" % [outward, roots.size()])
		# Every cilium is tied to the cytoskeleton: a fibre ends on its basal
		# body and carries its place, so fibre and limb work in one beat.
		if skeleton != null:
			var arrays := skeleton.mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var anatomy: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var ends: Array[Vector3] = []
			var places: Array[float] = []
			for i in points.size():
				if anatomy[i].a < 0.75 and anatomy[i].r > 0.985:
					ends.append(points[i])
					places.append(anatomy[i].g)
			var tied := 0
			var in_step := 0
			for root: Dictionary in roots:
				var nearest := INF
				var place := -1.0
				for i in ends.size():
					var d := ends[i].distance_to(root.position)
					if d < nearest:
						nearest = d
						place = places[i]
				if nearest < 0.004:
					tied += 1
				if absf(place - float(root.around)) < 0.002:
					in_step += 1
			_check(tied == roots.size(), "a microtubule ends on every basal body (%d of %d)" % [tied, roots.size()])
			_check(in_step == roots.size(), "each cilium's fibre carries its place around the cell (%d of %d)" % [in_step, roots.size()])
			var tubule := skeleton.material_override as ShaderMaterial
			var limb := cilia.material_override as ShaderMaterial
			_check(tubule.get_shader_parameter("pull_rate") == limb.get_shader_parameter("pull_rate")
				and tubule.get_shader_parameter("pull_waves") == limb.get_shader_parameter("pull_waves")
				and tubule.get_shader_parameter("work_color") == limb.get_shader_parameter("work_color")
				and tubule.get_shader_parameter("limb_color") == limb.get_shader_parameter("base_color"),
				"fibres and cilia share one beat and one palette")
	var recipes := {}
	for entry: Array in drawn:
		var label: String = entry[0]
		var mesh: Mesh = entry[1]
		var material: ShaderMaterial = entry[2]
		var uvs: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] if mesh != null else PackedVector2Array()
		var spread := Rect2()
		if uvs.size() > 0:
			spread = Rect2(uvs[0], Vector2.ZERO)
			for uv in uvs:
				spread = spread.expand(uv)
		_check(uvs.size() > 0 and spread.size.x > 0.05 and spread.size.y > 0.05, "%s has real UVs" % label)
		var recipe := str(material.get_meta("recipe", "")) if material != null else ""
		_check(recipe.begins_with("waking_colony_"), "%s names its registered recipe (%s)" % [label, recipe])
		recipes[recipe] = true
		for uniform: String in ["albedo_tex", "rough_tex", "normal_tex"]:
			var texture := material.get_shader_parameter(uniform) as Texture2D if material != null else null
			var image := texture.get_image() if texture != null else null
			_check(image != null and image.has_mipmaps(), "%s %s is a mipmapped map" % [label, uniform])
	for recipe: String in recipes:
		var path := "res://assets/dream/waking_colony/%s_recipe.json" % recipe.trim_prefix("waking_colony_")
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_check(parsed is Dictionary and str((parsed as Dictionary).get("material_key", "")) == recipe,
			"%s has its recipe record" % recipe)
	_check(recipes.size() >= 7, "the cell draws seven recipes (%d)" % recipes.size())


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var world := (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not world.startup_failed, "the V2 world starts")
	if world.startup_failed:
		_finish(world)
		return
	var enc: Node = world.apartment_encroachment
	_check(enc != null, "the encroachment is composed")
	if enc == null:
		_finish(world)
		return
	var cases: Array = enc.CASES.keys()
	print("[V2 WAKING ORGANISM] cases %d, flats found %d, fields %s, storey %s"
		% [cases.size(), enc.units.size(), str(enc.fields.keys()), str(enc.storey_rect)])
	_check(enc.units.size() == cases.size(), "every organism case's flat is found in V2")
	for case_id: String in enc.units:
		var unit := str(enc.CASES[case_id].unit)
		var rect: Vector4 = enc.units[case_id].rect
		_check(rect.x >= enc.storey_rect.x - 0.01 and rect.z <= enc.storey_rect.z + 0.01
			and rect.y >= enc.storey_rect.y - 0.01 and rect.w <= enc.storey_rect.w + 0.01,
			"%s's flat lies inside the storey field" % case_id)
		_check(enc.field_source.has(case_id), "%s has a source in its storey's field" % case_id)
		var floor_id: String = enc._floor_of(case_id)
		_check(floor_id == "F0" + unit.left(1), "%s lives on its own storey (%s)" % [case_id, floor_id])
	for floor_id: String in enc.fields:
		var bound: int = (enc.storey_materials.get(floor_id, []) as Array).size()
		print("[V2 WAKING ORGANISM] %s binds %d V2 materials" % [floor_id, bound])
		_check(bound >= 5, "the %s field binds its case flats' V2 materials" % floor_id)
	_check(enc.dream_field != null, "the waking dream field runs")
	# Rooted on the floor, drawn in the waking style.
	var mosses: Array = []
	for child in enc.get_children():
		if child.get_script() != null and str(child.get_script().resource_path).ends_with("dream_moss_colony_renderer.gd"):
			mosses.append(child)
	_check(mosses.size() == enc.units.size(), "every organism case has a moss colony (%d)" % mosses.size())
	for case_id: String in enc.units:
		_check(enc.source_points.has(case_id), "%s is rooted on open floor" % case_id)
	for moss: Node3D in mosses:
		var floor_y := INF
		for case_id: String in enc.units:
			if enc.source_points.has(case_id) and (enc.source_points[case_id] as Vector3).distance_to(moss.global_position) < 0.05:
				floor_y = float(enc.units[case_id].floor_y)
		_check(floor_y < INF and absf(moss.global_position.y - floor_y) < 0.1,
			"a moss colony sits on its flat's floor (y %.2f, floor %.2f)" % [moss.global_position.y, floor_y])
		_check(moss.waking_style and moss._waking != null, "the colony is the Blender-authored cell")
		if moss._waking != null:
			var membrane := moss._waking.find_child("Membrane", true, false) as MeshInstance3D
			_check(membrane != null and (membrane.material_override as ShaderMaterial).shader.resource_path.ends_with("waking_colony_membrane.gdshader"),
				"the membrane is the lensing, opalescent film")
			_check(moss._organelles.size() >= 15, "the cell holds its organelles (%d)" % moss._organelles.size())
			var cilia := moss._waking.find_child("WakingCilia", true, false) as MultiMeshInstance3D
			_check(cilia != null and cilia.multimesh.instance_count == moss.WAKING_CILIA, "the jointed cilia fringe the skirt")
			_check(not moss._heart.visible and not moss._cilia.visible, "the procedural colony is hidden")
			_check_colony_surfaces(moss, cilia)
	_check(enc.surface_tendrils == null and enc.critters == null, "V2 builds no tendrils and no critters")
	_check(enc.margin != null and enc.palp_renderer != null, "the margin and its palps are built")
	# The margin runs only on the storey the dream field was seeded on.
	var player: Node3D = world.player
	var margin_floor: String = enc._margin_floor
	var other_y := INF
	var margin_y := INF
	for case_id: String in enc.units:
		var fy := float(enc.units[case_id].floor_y)
		if enc._floor_of(case_id) == margin_floor:
			margin_y = fy
		else:
			other_y = fy
	var rect: Vector4 = enc.storey_rect
	var mid := Vector3((rect.x + rect.z) * 0.5, 0.0, (rect.y + rect.w) * 0.5)
	if other_y < INF and margin_y < INF:
		player.global_position = Vector3(mid.x, other_y + 1.0, mid.z)
		for i in 3: await get_tree().physics_frame
		_check(enc.margin.process_mode == Node.PROCESS_MODE_DISABLED and not enc.palp_renderer.visible,
			"off the margin's storey the margin pauses and its palps hide")
		player.global_position = Vector3(mid.x, margin_y + 1.0, mid.z)
		for i in 3: await get_tree().physics_frame
		_check(enc.margin.process_mode == Node.PROCESS_MODE_INHERIT and enc.palp_renderer.visible,
			"on %s the margin runs and its palps draw" % margin_floor)
	# The organism lives: its fields step.
	var before: Dictionary = {}
	for floor_id: String in enc.fields:
		before[floor_id] = int(enc.fields[floor_id].steps)
	for i in 120:
		await get_tree().physics_frame
	for floor_id: String in enc.fields:
		_check(int(enc.fields[floor_id].steps) > int(before[floor_id]), "the %s field advances" % floor_id)
	# The drawn cell crawls on its leash while the colony stays rooted.
	var started := {}
	for moss: Node3D in mosses:
		if moss._waking != null:
			# A cell rooted against something may be leaving it; only one that
			# starts on open floor is held to staying on open floor.
			started[moss] = [moss.global_position, moss._waking.position, moss._crawl_clear(moss._waking.position)]
	for i in 240:
		await get_tree().physics_frame
	var moved := 0
	for moss: Node3D in started:
		var before: Array = started[moss]
		_check(moss.global_position.is_equal_approx(before[0]), "a crawling cell leaves its colony rooted")
		var offset: Vector3 = moss._waking.position
		_check(absf(offset.y) < 0.001 and offset.length() <= moss.WAKING_CRAWL_LEASH + 0.01,
			"the cell keeps to the floor and its leash (%.2f m out)" % offset.length())
		if offset.distance_to(before[1]) > 0.004:
			moved += 1
			if before[2]:
				_check(moss._crawl_clear(offset), "where the cell has crawled to is open floor")
	print("[V2 WAKING ORGANISM] %d of %d cells crawled in four seconds" % [moved, started.size()])
	_check(moved >= 1, "at least one cell crawls (%d of %d)" % [moved, started.size()])
	print("[V2 WAKING ORGANISM] startup_ms %.0f" % world.startup_ms)
	var last := 0.0
	for row: Dictionary in world.startup_milestones:
		var at := float(row.wall_ms_since_start)
		if at - last > 2000.0 or str(row.stage) in ["reality_director_ready", "waking_organism_ready"]:
			print("[V2 WAKING ORGANISM] milestone %s at %.0f ms (+%.0f)" % [row.stage, at, at - last])
		last = at
	_finish(world)


func _finish(world: Node) -> void:
	var ok := _fails == 0
	print("[V2 WAKING ORGANISM] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	if world.has_method("shutdown_for_tests"):
		world.shutdown_for_tests()
	get_tree().quit(0 if ok else 1)
