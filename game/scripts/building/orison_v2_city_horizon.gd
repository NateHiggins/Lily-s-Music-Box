extends Node3D
## Passive stock in the retained building/grade frame and temporary walk radius.
const FINISHES := "res://data/orison_v2/exterior/city_horizon.json"
const WindowOptics := preload("res://scripts/building/v2_background_window_material.gd")
var _window_materials: Dictionary = {}
var _window_clock := CampaignClock.new()
var _window_check_left := 0.0
var _window_minute := -INF

func _ready() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FINISHES))
	var manifest_errors:=manifest_failures(source)
	assert(manifest_errors.is_empty(),JSON.stringify(manifest_errors))
	var profiles: Dictionary = {}
	for row: Dictionary in source.buildings: profiles[str(row.id)] = row
	var replacement: Dictionary=source.get("body_lod",{})
	var lower_roots: Array[Node3D]=[]
	var lower_parts: Dictionary={}
	if not replacement.is_empty():
		assert(float(replacement.error_m)>0. and not (replacement.parts as Array).is_empty())
		for entry: Dictionary in replacement.assets:
			var lower: Node3D=(load(str(entry.asset)) as PackedScene).instantiate() as Node3D
			add_child(lower)
			var errors:=model_failures(lower,entry)
			assert(errors.is_empty(),JSON.stringify(errors))
			lower_roots.append(lower)
			for draw: MeshInstance3D in lower.find_children("*","MeshInstance3D",true,false):
				assert(str(draw.name) in replacement.parts and not lower_parts.has(str(draw.name)))
				lower_parts[str(draw.name)]=draw
		assert(lower_parts.size()==replacement.parts.size())
	var replaced:=0
	var optical_usec := 0
	var materials: Dictionary = {}
	var roof_finishes := preload("res://scripts/building/orison_v2_owner_finishes.gd").new()
	# Every block's chimney cap is the top of its limestone stock: St. Elmo's tips.
	var StElmo := preload("res://scripts/building/orison_v2_st_elmo.gd")
	var tips := PackedVector3Array()
	for entry: Dictionary in source.assets:
		var model: Node3D=(load(str(entry.asset)) as PackedScene).instantiate() as Node3D
		add_child(model)
		var errors:=model_failures(model,entry)
		assert(errors.is_empty(),JSON.stringify(errors))
		for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var pieces := str(draw.name).split("__")
			var identity: String = pieces[0]
			var key: String = pieces[-1]
			assert(profiles.has(identity) and MatLib.SETS.has(key))
			var profile: Dictionary = profiles[identity]
			var collision_mesh:=draw.mesh
			if lower_parts.has(str(draw.name)):
				var far_draw: MeshInstance3D=lower_parts[str(draw.name)]
				assert(draw.global_transform.is_equal_approx(far_draw.global_transform))
				# Reuse the installed source-owned complete-body LOD assembler.
				# It copies both physical attribute sets and removes importer tails.
				draw.mesh=preload("res://scripts/building/orison_v2_city_transport.gd")._with_lod(collision_mesh,far_draw.mesh,float(replacement.error_m))
				draw.set_meta("v2_city_horizon_body_lod",true)
				replaced+=1
			var tint: Array = profile.wall_tint if key == str(profile.wall_key) else profile.get("joinery_tint",[1,1,1,1]) if key in ["door_paint","cast_iron"] else [.16,.20,.23,1] if key == "mirror_aged" else [1,1,1,1]
			var cache_key := key + "|" + str(tint)
			if not materials.has(cache_key):
				var stock := MatLib.get_mat(key).duplicate() as StandardMaterial3D
				stock.uv1_triplanar = false
				stock.albedo_color = Color(tint[0],tint[1],tint[2],tint[3])
				stock.normal_scale = .12 if key == "mirror_aged" else .55
				if key == "mirror_aged":
					stock.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					stock.metallic = 0.0
					stock.roughness = .45
				materials[cache_key] = stock
			draw.material_override = materials[cache_key]
			if key == "mirror_aged":
				var optical_started := Time.get_ticks_usec()
				var kind := WindowOptics.kind_for(str(profile.get("window_typology", "walkup")))
				if not _window_materials.has(kind):
					var optical: ShaderMaterial = WindowOptics.create("city-type-%d" % kind, kind, Vector2(1.2, 1.8))
					optical.set_shader_parameter("optical_vertex_data", true)
					optical.set_shader_parameter("glass_tint", Vector3(.16, .20, .23))
					_window_materials[kind] = optical
				draw.set_meta("v2_window_source_mesh", draw.mesh)
				draw.set_meta("v2_window_source_material", materials[cache_key])
				draw.mesh = WindowOptics.project(draw.mesh, identity)
				draw.material_override = _window_materials[kind]
				optical_usec += Time.get_ticks_usec() - optical_started
			if key == "galvanized_roof":
				draw.set_meta("v2_city_roof_source",materials[cache_key])
				draw.material_override = roof_finishes.material_for(materials[cache_key],"roof")
			draw.set_meta("v2_city_horizon_building",identity)
			if key == "limestone": tips.append(StElmo.crown_of(draw, self))
			var body := StaticBody3D.new()
			body.name = "HorizonCollision"
			draw.add_child(body)
			var shape := CollisionShape3D.new()
			var native := ConcavePolygonShape3D.new()
			native.set_faces(preload("res://scripts/building/orison_v2_native_faces.gd").read(collision_mesh))
			shape.shape = native
			body.add_child(shape)
	assert(replaced==lower_parts.size())
	for lower: Node3D in lower_roots:lower.free()
	var clock_faces: Array = source.get("clock_faces", [])
	if not clock_faces.is_empty():
		var movement := FactoryClock.new()
		movement.name = "FactoryClockMovement"
		assert(movement.configure_faces(self, clock_faces, profiles.keys()), "Factory dial presentation must bind native stock and campaign time")
		add_child(movement)
	add_child(StElmo.new(tips, 2.6))
	set_meta("window_optical_preparation_ms", float(optical_usec) / 1000.0)
	_refresh_windows()

func _process(delta: float) -> void:
	_window_check_left -= delta
	if _window_check_left > 0.0: return
	_window_check_left = 0.25
	_refresh_windows()

func _refresh_windows() -> void:
	if not _window_clock.bind_state(): return
	var minute := floorf(_window_clock.calendar_minutes())
	if minute == _window_minute: return
	project_window_clock(_window_clock)
	_window_minute = minute

func project_window_clock(clock: CampaignClock) -> void:
	for material: ShaderMaterial in _window_materials.values():
		WindowOptics.sync_clock(material, clock)

static func asset_paths(source: Dictionary, include_lower: bool=true) -> Array[String]:
	var result: Array[String]=[]
	for asset: Dictionary in source.get("assets",[]):result.append(str(asset.asset))
	if include_lower:
		for asset: Dictionary in source.get("body_lod",{}).get("assets",[]):result.append(str(asset.asset))
	return result

static func _roster(entries: Array, profiles: Dictionary, lower: bool=false) -> Dictionary:
	var errors: Array[String]=[]
	var names: Dictionary={}
	var owners: Dictionary={}
	var parts_by_building: Dictionary={}
	var paths: Dictionary={}
	for entry: Dictionary in entries:
		var path:=str(entry.get("asset",""))
		var expected_path: String="res://assets/props/city_horizon_"+str(entry.get("block","")).trim_prefix("HORIZON_").to_lower()+("_lod1" if lower else "")+".glb"
		if path!=expected_path:errors.append("asset does not match registered block: "+path)
		if path.is_empty() or paths.has(path):errors.append("missing/duplicate asset: "+path)
		paths[path]=true
		var declared: Array=entry.get("buildings",[])
		var found: Dictionary={}
		var roster: Array=entry.get("parts",[])
		if roster.is_empty() or declared.is_empty():errors.append("empty block roster: "+path)
		var unique_declared: Dictionary={}
		for identity: String in declared:
			if unique_declared.has(identity):errors.append("duplicate building declaration: "+identity)
			unique_declared[identity]=true
		for name: String in roster:
			var pieces:=name.split("__")
			if pieces.size()!=2 or pieces[-1].is_empty():
				errors.append("invalid part ID: "+name)
				continue
			var identity: String=pieces[0]
			var block: String="_".join(identity.split("_").slice(0,4))
			if block!=str(entry.get("block","")):errors.append("split/wrong block: "+name)
			if names.has(name):errors.append("duplicate part: "+name)
			names[name]=true;found[identity]=true
			if not profiles.has(identity) or not unique_declared.has(identity):errors.append("undeclared building: "+identity)
			if owners.has(identity) and owners[identity]!=path:errors.append("building split between assets: "+identity)
			owners[identity]=path
			if not parts_by_building.has(identity):parts_by_building[identity]=[]
			parts_by_building[identity].append(name)
		if found.size()!=unique_declared.size():errors.append("missing building in block: "+path)
	return {"errors":errors,"names":names,"owners":owners,"parts_by_building":parts_by_building}

static func manifest_failures(source: Dictionary) -> Array[String]:
	var errors: Array[String]=[]
	if int(source.get("schema",0))!=2 or str(source.get("frame",""))!="ORISON_V2_BUILDING_FRAME":errors.append("invalid horizon schema/frame")
	var profiles: Dictionary={}
	for row: Dictionary in source.get("buildings",[]):
		var identity:=str(row.id)
		if profiles.has(identity):errors.append("duplicate profile: "+identity)
		profiles[identity]=row
	var base:=_roster(source.get("assets",[]),profiles)
	errors.append_array(base.errors)
	if profiles.is_empty() or base.owners.size()!=profiles.size():errors.append("base does not cover every profile")
	var replacement: Dictionary=source.get("body_lod",{})
	var lower:=_roster(replacement.get("assets",[]),profiles,true)
	errors.append_array(lower.errors)
	var flat: Array=replacement.get("parts",[])
	if float(replacement.get("error_m",0.))<=0. or flat.is_empty():errors.append("invalid complete-body LOD declaration")
	var flat_names: Dictionary={}
	for name: String in flat:
		if flat_names.has(name) or not lower.names.has(name):errors.append("duplicate/missing flat LOD part: "+name)
		flat_names[name]=true
	if flat_names.size()!=lower.names.size():errors.append("incomplete flat LOD roster")
	for identity: String in lower.parts_by_building:
		var high: Array=base.parts_by_building.get(identity,[]).duplicate()
		var low: Array=lower.parts_by_building[identity].duplicate()
		high.sort();low.sort()
		if high!=low:errors.append("incomplete replacement body: "+identity)
	var paths:=asset_paths(source)
	var unique_paths: Dictionary={}
	for path: String in paths:unique_paths[path]=true
	if unique_paths.size()!=paths.size():errors.append("asset reused across base/lower roles")
	errors.append_array(FactoryClock.face_failures(source.get("clock_faces", []), profiles.keys()))
	return errors

static func model_failures(model: Node3D, entry: Dictionary) -> Array[String]:
	var errors: Array[String]=[]
	var seen: Dictionary={}
	var expected: Array=entry.parts
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var name:=str(draw.name)
		if seen.has(name) or not name in expected:errors.append("duplicate/unexpected imported part: "+name)
		seen[name]=true
	if seen.size()!=expected.size():errors.append("imported block roster differs: "+str(entry.asset))
	return errors


class FactoryClock extends "res://scripts/building/orison_v2_arcade_clock_movement.gd":
	## Passive native hand instances; inherited presentation reads CampaignClock.
	## No saved field, clock writer, collision owner, light or new material key.
	const HAND_STOCK := preload("res://assets/props/arcade_clock.glb")

	static func face_failures(faces: Variant, buildings: Array) -> Array[String]:
		var problems: Array[String] = []
		if not faces is Array: return ["factory clock faces must be an array"]
		if faces.is_empty(): return problems
		if faces.size() != 2: return ["factory clock requires exactly two dial faces"]
		var identities: Dictionary = {}
		var normals: Array[Vector3] = []
		var dial_building := ""
		for face: Variant in faces:
			if not face is Dictionary:
				problems.append("factory clock face must be a dictionary"); continue
			var identity := str(face.get("id", ""))
			var building := str(face.get("building", ""))
			if identity.is_empty() or identities.has(identity): problems.append("missing/duplicate factory dial identity")
			identities[identity] = true
			if not buildings.has(building): problems.append("factory dial has no registered building")
			if dial_building.is_empty(): dial_building = building
			elif dial_building != building: problems.append("factory dials must belong to the same building")
			var vectors: Dictionary = {}
			for key: String in ["center_godot", "right_godot", "up_godot", "normal_godot"]:
				var values: Variant = face.get(key)
				if not values is Array or values.size() != 3:
					problems.append("invalid factory dial vector " + key); continue
				var valid := true
				for value: Variant in values:
					if not (value is float or value is int) or not is_finite(float(value)): valid = false
				if not valid:
					problems.append("nonfinite/nonnumeric factory dial vector " + key); continue
				vectors[key] = _v(values)
			if vectors.size() == 4:
				var right: Vector3 = vectors.right_godot
				var up: Vector3 = vectors.up_godot
				var normal: Vector3 = vectors.normal_godot
				if not right.is_normalized() or not up.is_normalized() or not normal.is_normalized() or not right.cross(up).is_equal_approx(normal):
					problems.append("factory dial requires an outward orthonormal frame")
				normals.append(normal)
			var scale_value: Variant = face.get("hand_scale")
			if not (scale_value is float or scale_value is int) or not is_equal_approx(float(scale_value), 3.6):
				problems.append("factory native hand scale must be 3.6")
		if normals.size() == 2 and absf(normals[0].dot(normals[1])) > .00001:
			problems.append("factory clock requires two perpendicular faces")
		return problems

	func configure_faces(model: Node3D, faces: Array, buildings: Array) -> bool:
		if model == null or not _hands.is_empty() or faces.size() != 2 or not _clock.bind_state(): return false
		if not face_failures(faces, buildings).is_empty(): return false
		var stock := HAND_STOCK.instantiate() as Node3D
		var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/arcade_clock.json"))
		var definitions: Dictionary = {}
		for part: Dictionary in metadata.cells[0].parts:
			if str(part.name) in ["south_hour_hand", "south_minute_hand"]: definitions[str(part.name)] = part
		var pending: Array[MeshInstance3D] = []
		for face: Dictionary in faces:
			var identity := str(face.id)
			var right := _v(face.right_godot)
			var up := _v(face.up_godot)
			var normal := _v(face.normal_godot)
			var center := _v(face.center_godot)
			var hand_scale := float(face.hand_scale)
			for kind: String in ["hour", "minute"]:
				var source_key := "south_" + kind + "_hand"
				var source := stock.find_child(source_key, true, false) as MeshInstance3D
				if source == null or not definitions.has(source_key):
					stock.free(); _discard(pending); return false
				var definition: Dictionary = definitions[source_key]
				if str(definition.catalog_key) != "iron_blackened" or not is_equal_approx(float(definition.tile), .4):
					stock.free(); _discard(pending); return false
				var material := MatLib.get_mat(str(definition.catalog_key)).duplicate() as StandardMaterial3D
				material.uv1_triplanar = false
				# Native charts measure metres. Scale repeats with the instance so
				# the registered .4m material retains its physical grain size.
				material.uv1_scale = Vector3.ONE * hand_scale / float(definition.tile)
				var draw := MeshInstance3D.new()
				draw.name = identity + "_" + kind + "_hand"
				draw.mesh = source.mesh
				draw.material_override = material
				# Center is already at .045m dial-front depth. These offsets give
				# .070/.082m wall depth: clear of .060m ticks and each other.
				draw.transform = Transform3D(Basis(right,up,normal).scaled(Vector3.ONE*hand_scale),center+normal*(.037 if kind == "minute" else .025))
				draw.set_meta("city_clock_hand", true)
				draw.set_meta("city_clock_building", str(face.building))
				draw.set_meta("city_clock_source_part", source_key)
				pending.append(draw)
		stock.free()
		for draw: MeshInstance3D in pending:
			model.add_child(draw)
			_hands[str(draw.name)] = draw
			_rest[str(draw.name)] = draw.transform
		return refresh_from_campaign()

	func _discard(pending: Array[MeshInstance3D]) -> void:
		for draw: MeshInstance3D in pending: draw.free()
