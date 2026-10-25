extends AnimatedResident
## Presentation adapter only. Original V1 rigs, personal moves and interaction
## authorities remain owners; each actor receives a local V2 atlas material.
var _local_libraries: Dictionary = {}
var _local_loops: Dictionary = {}

static func roster() -> Array[Dictionary]:
	var profiles: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/resident_animation_profiles.json"))
	var schedules: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			ScheduleDirector.SCHEDULE_PATH))
	var result: Array[Dictionary] = []
	if profiles is not Array or schedules is not Dictionary: return result
	for profile: Dictionary in profiles:
		var slug := str(profile.slug)
		if not schedules.residents.has(slug): return []
		var model := "res://assets/characters/%s/%s.gltf" % [slug, slug]
		if not ResourceLoader.exists(model) or not MatLib.SETS.has("resident_" + slug): return []
		result.append({"id": slug, "display": str(profile.display),
			"unit": str(schedules.residents[slug].unit), "model": model})
	return result if result.size() == 18 else []

func _ready() -> void:
	# Bare imported clips use clip_01..08, rather than a literal "idle".
	# Keep the existing per-resident temperament and personal rest-correct bake.
	var roles: Dictionary = ResidentRoutines.CHARACTER_ROLES.get(resident_id, {})
	preferred_idle = str(ResidentRoutines.ROLES.get(str(roles.get("idle", "idle")), "clip_01"))
	preferred_walk = "walk"
	super._ready()
	if mina_animation == null and _animation_player != null:
		_local_loop(preferred_idle)
		_local_loop(preferred_walk)
		_play_named("idle")

func _local_loop(clip: String) -> bool:
	if _animation_player == null or not _animation_player.has_animation(clip): return false
	if _local_loops.has(clip): return true
	var library_name := clip.get_slice("/", 0) if clip.contains("/") else ""
	var animation_name := clip.get_slice("/", 1) if clip.contains("/") else clip
	if not _local_libraries.has(library_name):
		# Evelyn's embedded library is shared by the imported PackedScene.
		# Duplicate its dictionary, then only the clips this actor actually uses.
		var local_library := _animation_player.get_animation_library(library_name).duplicate(false) as AnimationLibrary
		_animation_player.remove_animation_library(library_name)
		_animation_player.add_animation_library(library_name, local_library)
		_local_libraries[library_name] = local_library
	var library: AnimationLibrary = _local_libraries[library_name]
	var animation := library.get_animation(animation_name).duplicate(true) as Animation
	animation.loop_mode = Animation.LOOP_LINEAR
	library.remove_animation(animation_name); library.add_animation(animation_name, animation)
	_local_loops[clip] = true
	return true

func play_seated() -> bool:
	# Mina's supplied twenty clips have no seated motion. Her owner retains
	# its own idle and standing spot; never graft a retired donor pose onto her.
	if mina_animation != null or not _local_loop("clip_06"): return false
	_animation_player.play("clip_06", .25)
	var animation := _animation_player.get_animation("clip_06")
	# Deterministic per-person phase avoids a room of synchronized gestures.
	_animation_player.seek(animation.length * float(resident_id.hash() & 65535) / 65536.0, true)
	return true

func _apply_presence_glow(node: Node) -> void:
	if node is MeshInstance3D:
		var draw := node as MeshInstance3D
		if resident_id == "jonah_price": _repair_atlas_uv(draw)
		var key := "resident_" + resident_id
		for surface in draw.mesh.get_surface_count():
			var original := draw.get_active_material(surface) as StandardMaterial3D
			var finish := MatLib.get_mat(key).duplicate() as StandardMaterial3D
			finish.uv1_triplanar = false
			finish.uv1_scale = Vector3.ONE
			finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if original != null: finish.cull_mode = original.cull_mode
			finish.emission_enabled = true
			finish.emission = PRESENCE_GLOW
			finish.emission_energy_multiplier = 1.0
			draw.set_surface_override_material(surface, finish)
		draw.set_meta("material_key", key)
		draw.set_meta("v2_resident_atlas", true)
	for child in node.get_children(): _apply_presence_glow(child)

func _repair_atlas_uv(draw: MeshInstance3D) -> void:
	# Blender-authored UV-only repair. Keep the approved rig and all skin,
	# geometry, blend shapes and original shared mesh data byte-for-byte.
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/orison_v2/resident_atlas_uv_repair.json"))
	if source.schema_version != 1 or source.resident != resident_id \
			or source.source != model_path or FileAccess.get_sha256(model_path) != source.source_sha256:
		push_error("Resident UV repair source changed"); return
	var local := draw.mesh.duplicate() as ArrayMesh
	for surface in local.get_surface_count():
		var arrays := local.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var changed := 0
		var repaired_vertices := {}
		for repair: Dictionary in source.repairs:
			if int(repair.native_loops) != 1:
				push_error("Resident UV repair no longer has a single native corner"); return
			var at := Vector3(repair.position[0], repair.position[1], repair.position[2])
			var before := Vector2(repair.before[0], repair.before[1])
			var after := Vector2(repair.after[0], repair.after[1])
			for index in vertices.size():
				if vertices[index].distance_to(at) < .00001 and uvs[index].distance_to(before) < .0001:
					uvs[index] = after; changed += 1; repaired_vertices[index] = true
		if changed == 0: push_error("Resident UV repair vertex not found"); continue
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		# Renew only the repaired face's tangent frame; keep every other
		# authored normal/tangent and all skin attributes unchanged.
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for face in range(0, indices.size(), 3):
			var a := indices[face]; var b := indices[face+1]; var c := indices[face+2]
			if not repaired_vertices.has(a) and not repaired_vertices.has(b) and not repaired_vertices.has(c): continue
			var u := uvs[b]-uvs[a]; var v := uvs[c]-uvs[a]
			var determinant := u.cross(v)
			if absf(determinant) < 1e-12: push_error("Native UV repair remains degenerate"); return
			var edge := vertices[b]-vertices[a]; var other := vertices[c]-vertices[a]
			var tangent := (edge*v.y-other*u.y)/determinant
			var bitangent := (other*u.x-edge*v.x)/determinant
			for vertex: int in [a,b,c]:
				var normal := normals[vertex]
				var direction := (tangent-normal*normal.dot(tangent)).normalized()
				tangents[vertex*4] = direction.x; tangents[vertex*4+1] = direction.y; tangents[vertex*4+2] = direction.z
				tangents[vertex*4+3] = -1.0 if normal.cross(direction).dot(bitangent) < 0 else 1.0
		arrays[Mesh.ARRAY_TANGENT] = tangents
		# The approved character is one surface, no blend shapes. Rebuild only
		# the local arrays so imported compressed buffers remain untouched.
		if local.get_surface_count() != 1 or local.get_blend_shape_count() != 0:
			push_error("Resident UV repair mesh ABI changed"); return
		var material := local.surface_get_material(surface)
		var original_surface: Dictionary = local.get("_surfaces")[surface]
		var shadow := local.shadow_mesh
		local.clear_surfaces()
		local.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		# UV repair doesn't change vertex numbering. Retain the imported LOD
		# index buffers and position-only shadow mesh for distant residents.
		var rebuilt: Array = local.get("_surfaces")
		rebuilt[0].lods = original_surface.get("lods", {}).duplicate(true)
		local.clear_surfaces(); local.set("_surfaces", rebuilt)
		local.shadow_mesh = shadow
		local.surface_set_material(0, material)
		draw.set_meta("native_uv_repairs", changed)
		draw.mesh = local
