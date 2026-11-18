extends Node3D
## Exact surviving opaque wall triangles. No inferred boxes across apertures.
## Install after bar mounts; invalidate before any future structural mutation.
const WALLS := ["F01_OWN_SHOP_BAR_retail_bar_bar_wall","F01_OWN_SHOP_BAR_retail_bar_common_brick"]
var errors: Array[String] = []
var records: Array = []
var sources: Array = []
var enabled := false
var _invalidated := false
var _prepared := false

func setup(bar: Node3D) -> bool:
	if _prepared or not sources.is_empty() or bar == null or not is_inside_tree(): return false
	if not errors.is_empty(): return false
	var coverage: Dictionary = {}
	for draw: MeshInstance3D in bar.find_children("*","MeshInstance3D",true,false):
		var identity := str(draw.get_meta("harukiya_entry_part",""))
		if identity not in ["Static__teal","Static__brick"]:
			identity = ""
			for wall: String in WALLS:
				if str(draw.name) in [wall,wall+"-col",wall+"_col"]: identity = wall; break
			if identity.is_empty(): continue
		if coverage.has(identity): errors.append("duplicate structural identity "+identity); continue
		coverage[identity] = true
		if not _admit(draw): errors.append("nonopaque or deforming source "+identity); continue
		var faces: PackedVector3Array = draw.mesh.get_faces()
		if faces.is_empty() or faces.size()%3 != 0 or faces.size()>30000:
			errors.append("invalid source triangles "+identity); continue
		var finite := true
		for point: Vector3 in faces: finite = finite and point.is_finite()
		if not finite or not draw.global_transform.is_finite(): errors.append("nonfinite source "+identity); continue
		var indices := PackedInt32Array()
		for index in faces.size(): indices.append(index)
		var array := ArrayOccluder3D.new()
		array.set_arrays(faces,indices)
		var proxy := OccluderInstance3D.new()
		proxy.name = "ExactWall_"+str(records.size()); proxy.occluder = array
		proxy.visible = false
		add_child(proxy); proxy.global_transform = draw.global_transform
		sources.append({"draw":draw,"proxy":proxy,"previous_ignore":draw.ignore_occlusion_culling,
			"mesh":draw.mesh,"relative_transform":global_transform.affine_inverse()*draw.global_transform,
			"materials":_materials(draw)})
		records.append({"identity":identity,"path":str(draw.get_path()),"triangles":faces.size()/3,
			"local_faces_sha256":faces.to_byte_array().hex_encode().sha256_text(),
			"hash_encoding":"sha256 of hex-encoded native packed-vector bytes",
			"transform":draw.global_transform,"previous_ignore":draw.ignore_occlusion_culling})
	for identity: String in [WALLS[0],WALLS[1],"Static__teal","Static__brick"]:
		if not coverage.has(identity): errors.append("missing exact structural identity "+identity)
	if sources.size()!=4: errors.append("exact four structural sources required")
	var triangles := 0
	for record: Dictionary in records: triangles += int(record.triangles)
	if triangles != 296: errors.append("expected qualified 296 structural triangles")
	if not errors.is_empty():
		shutdown()
		return false
	for row: Dictionary in sources:
		var draw: MeshInstance3D = row.draw
		draw.tree_exiting.connect(_source_changed)
		draw.visibility_changed.connect(_source_changed)
		var mesh: Mesh = row.mesh
		if not mesh.changed.is_connected(_source_changed): mesh.changed.connect(_source_changed)
	_prepared = true
	RenderingServer.frame_pre_draw.connect(_guard_sources)
	return true

static func _materials(draw: MeshInstance3D) -> Array:
	var result: Array = []
	for surface in draw.mesh.get_surface_count(): result.append(draw.get_active_material(surface))
	return result

static func _admit(draw: MeshInstance3D) -> bool:
	if not draw.mesh is ArrayMesh or draw.skin != null or draw.get_skin_reference() != null or draw.mesh.get_blend_shape_count()>0 or draw.material_overlay != null: return false
	for surface in draw.mesh.get_surface_count():
		if draw.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return false
		if draw.mesh.surface_get_format(surface) & (Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FORMAT_WEIGHTS): return false
		var material := draw.get_active_material(surface)
		if material == null or material.next_pass != null: return false
		if material is ShaderMaterial:
			if material.shader == null or material.shader.resource_path!="res://shaders/orison_surface.gdshader": return false
		elif material is StandardMaterial3D:
			if material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or material.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED or material.grow or material.fixed_size or material.proximity_fade_enabled or material.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED: return false
		else: return false
	return true

func _source_changed() -> void:
	_invalidate("structural source exited, changed visibility or changed mesh")

func _invalidate(reason: String) -> void:
	if _invalidated: return
	_invalidated = true
	errors.append(reason)
	set_enabled(false)

func _guard_sources() -> void:
	if not _prepared or _invalidated: return
	# Four bounded identity/admission checks, no per-frame face copies or hashes.
	# Covers mesh reassignment and relative ancestor motion, neither of which
	# necessarily emits the originally subscribed mesh's changed signal.
	for row: Dictionary in sources:
		if not is_instance_valid(row.draw) or not is_instance_valid(row.proxy):
			_invalidate("structural source or proxy disappeared"); return
		var draw: MeshInstance3D = row.draw
		if not draw.is_inside_tree() or not draw.is_visible_in_tree() or draw.mesh != row.mesh:
			_invalidate("structural source identity or visibility changed"); return
		if not _admit(draw) or _materials(draw) != row.materials:
			_invalidate("structural source material admission changed"); return
		var relative := global_transform.affine_inverse()*draw.global_transform
		if not relative.is_equal_approx(row.relative_transform):
			_invalidate("structural source relative transform changed"); return

func set_enabled(value: bool) -> void:
	if value:
		_guard_sources()
		if not _prepared or _invalidated: return
	enabled = value
	for row: Dictionary in sources:
		if is_instance_valid(row.draw):
			row.draw.ignore_occlusion_culling = true if value else row.previous_ignore
		if is_instance_valid(row.proxy): row.proxy.visible = value

func shutdown() -> bool:
	set_enabled(false)
	_prepared = false
	if RenderingServer.frame_pre_draw.is_connected(_guard_sources):
		RenderingServer.frame_pre_draw.disconnect(_guard_sources)
	var restored := true
	for row: Dictionary in sources:
		if is_instance_valid(row.draw):
			var draw: MeshInstance3D = row.draw
			restored = restored and draw.ignore_occlusion_culling == row.previous_ignore
			if draw.tree_exiting.is_connected(_source_changed): draw.tree_exiting.disconnect(_source_changed)
			if draw.visibility_changed.is_connected(_source_changed): draw.visibility_changed.disconnect(_source_changed)
		var mesh: Mesh = row.mesh
		if is_instance_valid(mesh) and mesh.changed.is_connected(_source_changed): mesh.changed.disconnect(_source_changed)
		if is_instance_valid(row.proxy): row.proxy.free()
	sources.clear()
	return restored

func _exit_tree() -> void:
	shutdown()
