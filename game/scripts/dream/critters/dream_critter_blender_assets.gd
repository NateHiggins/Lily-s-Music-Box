class_name DreamCritterBlenderAssets
extends RefCounted
## Shared, weakly cached imported pose data. The imported meshes are read once;
## both fauna batches retain this one immutable atlas, never one per animal.

const SPECIES := {3: "tardigrade", 6: "vorticella"}
const ROOT := "res://assets/dream/critters_blender/"
const LAW_KEYS := ["Basis", "law_01", "law_02", "law_03", "law_04", "law_05",
	"law_06", "law_07", "law_half", "law_09", "law_10", "law_11", "law_12",
	"law_13", "law_14", "law_15", "law_full"]
const PHASE_KEYS := ["gait_a", "gait_b"]
const WIDTH := 1024
const POSES := 19
const MAX_ATLAS_HEIGHT := 16384

static var _shared: WeakRef

var ready := false
var error := ""
var texture: ImageTexture
var width := WIDTH
var pose_count := POSES
var templates: Dictionary = {}
var atlas_vertices := 0
var atlas_height := 0
var atlas_bytes := 0
var load_usec := 0


static func acquire() -> DreamCritterBlenderAssets:
	if _shared != null:
		var cached := _shared.get_ref() as DreamCritterBlenderAssets
		if cached != null and cached.ready:
			return cached
	var result := DreamCritterBlenderAssets.new()
	result._load_assets()
	if result.ready:
		_shared = weakref(result)
	return result


func _fail(message: String) -> bool:
	error = message
	return false


func _load_assets() -> void:
	var began := Time.get_ticks_usec()
	for kind in [3, 6]:
		var species := String(SPECIES[kind])
		templates[kind] = {}
		for lod in [0, 1]:
			var stem := species + ("_lod0" if lod == 0 else "")
			var directory := ROOT + species + "/"
			var template := _read_template(directory + stem + ".manifest.json", directory, kind, lod)
			if template.is_empty():
				templates.clear()
				load_usec = Time.get_ticks_usec() - began
				return
			template["atlas_base"] = atlas_vertices
			atlas_vertices += (template.positions as PackedVector3Array).size()
			template["foot_base"] = atlas_vertices if kind == 3 else -1
			if kind == 3:
				atlas_vertices += 8
			template["cilium_base"] = atlas_vertices if kind == 6 else -1
			template["cilium_anchor_count"] = 12 if kind == 6 else 0
			if kind == 6:
				atlas_vertices += 12
			templates[kind][lod] = template
	if not _make_atlas():
		templates.clear()
		load_usec = Time.get_ticks_usec() - began
		return
	ready = true
	load_usec = Time.get_ticks_usec() - began


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Cannot read manifest: " + path)
		return {}
	var parser := JSON.new()
	var code := parser.parse(file.get_as_text())
	file.close()
	if code != OK or not parser.data is Dictionary:
		_fail("Malformed manifest: " + path)
		return {}
	return parser.data


func _read_template(path: String, directory: String, kind: int, lod: int) -> Dictionary:
	var manifest := _read_json(path)
	if manifest.is_empty():
		return {}
	var stem := String(SPECIES[kind]) + ("_lod0" if lod == 0 else "")
	if manifest.get("schema_version") != 1 or manifest.get("species_id") != kind \
			or manifest.get("mesh_file") != stem + ".glb" \
			or manifest.get("law_keys") != LAW_KEYS or manifest.get("phase_keys") != PHASE_KEYS \
			or manifest.get("closed_body") != "Skin" or not manifest.get("foot_anchors") is Array \
			or not manifest.get("cilium_anchors") is Array:
		_fail("Manifest does not match the admitted species/pose contract: " + path)
		return {}
	var anchors := _read_feet(manifest.foot_anchors, kind)
	if not error.is_empty() or (kind == 3 and anchors.is_empty()):
		return {}
	var cilia := _read_cilia(manifest.cilium_anchors, kind)
	if not error.is_empty() or (kind == 6 and cilia.is_empty()):
		return {}
	var mesh_path := directory + stem + ".glb"
	if not _validate_glb_channels(mesh_path):
		return {}
	var packed := load(mesh_path) as PackedScene
	if packed == null:
		_fail("GLB is not imported as a scene: " + mesh_path)
		return {}
	var scene := packed.instantiate()
	var meshes: Array[Dictionary] = []
	_collect_meshes(scene, Transform3D.IDENTITY, meshes)
	var data := {"positions": PackedVector3Array(), "normals": PackedVector3Array(),
		"uvs": PackedVector2Array(), "colors": PackedColorArray(),
		"leg_bind": PackedVector2Array(), "indices": PackedInt32Array(),
		"pose_positions": [], "pose_normals": [], "foot_anchors": anchors, "cilium_anchors": cilia,
		"source": mesh_path, "manifest": path, "lod": lod, "kind": kind,
		"triangles": 0, "bounds": AABB()}
	for _pose in POSES:
		(data.pose_positions as Array).append(PackedVector3Array())
		(data.pose_normals as Array).append(PackedVector3Array())
	var has_skin := false
	var valid := not meshes.is_empty()
	for entry: Dictionary in meshes:
		var node: MeshInstance3D = entry.node
		has_skin = has_skin or String(node.name) == "Skin"
		if not _append_mesh(data, node, entry.transform, kind):
			valid = false
			break
	scene.free()
	if not valid:
		if error.is_empty():
			_fail("No imported mesh geometry: " + mesh_path)
		return {}
	if not has_skin:
		_fail("Declared closed-body node Skin is absent: " + mesh_path)
		return {}
	var indices: PackedInt32Array = data.indices
	var triangles := int(indices.size() / 3)
	if triangles <= 0 or triangles > (20000 if lod == 0 else 5000):
		_fail("Imported triangle count exceeds its LOD budget: " + mesh_path)
		return {}
	if kind == 3:
		var seen: Dictionary = {}
		for leg: Vector2 in data.leg_bind:
			if leg.x >= 0.0:
				seen[int(roundf(leg.x))] = true
		if seen.size() != 8:
			_fail("Tardigrade must carry all eight authored leg bindings: " + mesh_path)
			return {}
	if kind == 6:
		var seen_cilia: Dictionary = {}
		for binding: Vector2 in data.leg_bind:
			if binding.x <= -2.0 and binding.y > 0.0001:
				seen_cilia[-2 - int(roundf(binding.x))] = true
		if seen_cilia.size() != 12:
			_fail("Vorticella must carry all twelve authored cilium bindings: " + mesh_path)
			return {}
	var points: PackedVector3Array = data.positions
	var bounds := AABB(points[0], Vector3.ZERO)
	for pose: PackedVector3Array in data.pose_positions:
		for point: Vector3 in pose:
			bounds = bounds.expand(point)
	data.bounds = bounds
	data.triangles = triangles
	return data


func _read_feet(raw: Array, kind: int) -> Array:
	if kind != 3:
		if not raw.is_empty():
			_fail("A non-tardigrade manifest cannot claim foot anchors")
		return []
	if raw.size() != POSES:
		_fail("Foot anchors must contain all nineteen law/phase poses")
		return []
	var anchors: Array = []
	for pose: Variant in raw:
		if not pose is Array or pose.size() != 8:
			_fail("Each foot-anchor pose must contain eight points")
			return []
		var row := PackedVector3Array()
		for point: Variant in pose:
			if not point is Array or point.size() != 3:
				_fail("A foot anchor must be a three-number point")
				return []
			for component: Variant in point:
				if (not component is float and not component is int) or not is_finite(float(component)):
					_fail("Non-finite foot anchor")
					return []
			row.append(Vector3(float(point[0]), float(point[1]), float(point[2])))
		anchors.append(row)
	return anchors


func _read_cilia(raw: Array, kind: int) -> Array:
	if kind != 6:
		if not raw.is_empty():
			_fail("A non-vorticella manifest cannot claim cilium anchors")
		return []
	if raw.size() != POSES:
		_fail("Cilium anchors must contain all nineteen law/phase poses")
		return []
	var anchors: Array = []
	for pose: Variant in raw:
		if not pose is Array or pose.size() != 12:
			_fail("Each cilium-anchor pose must contain twelve points")
			return []
		var row := PackedVector3Array()
		for point: Variant in pose:
			if not point is Array or point.size() != 3:
				_fail("A cilium anchor must be a three-number point")
				return []
			for component: Variant in point:
				if (not component is float and not component is int) or not is_finite(float(component)):
					_fail("Non-finite cilium anchor")
					return []
			row.append(Vector3(float(point[0]), float(point[1]), float(point[2])))
		anchors.append(row)
	return anchors


func _validate_glb_channels(path: String) -> bool:
	# Imported targets with no NORMAL accessor silently inherit base normals.
	# Read the actual GLB declaration so that omission cannot pass as animation.
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Cannot inspect source GLB: " + path)
	if file.get_length() < 20 or file.get_32() != 0x46546c67 or file.get_32() != 2:
		file.close()
		return _fail("Invalid GLB header: " + path)
	var length := file.get_32()
	var json_length := file.get_32()
	var chunk_kind := file.get_32()
	if length != file.get_length() or chunk_kind != 0x4e4f534a \
			or json_length <= 0 or json_length > length - 20:
		file.close()
		return _fail("Invalid GLB JSON chunk: " + path)
	var parser := JSON.new()
	var code := parser.parse(file.get_buffer(json_length).get_string_from_utf8())
	file.close()
	if code != OK or not parser.data is Dictionary:
		return _fail("Malformed GLB JSON: " + path)
	var document: Dictionary = parser.data
	if not document.get("meshes") is Array or (document.meshes as Array).is_empty():
		return _fail("GLB has no mesh declarations: " + path)
	var names: Array = LAW_KEYS.slice(1)
	names.append_array(PHASE_KEYS)
	for mesh: Variant in document.meshes:
		if not mesh is Dictionary or not mesh.get("extras") is Dictionary \
				or mesh.extras.get("targetNames") != names or not mesh.get("primitives") is Array:
			return _fail("GLB target names differ from the manifest: " + path)
		for primitive: Variant in mesh.primitives:
			if not primitive is Dictionary or not primitive.get("attributes") is Dictionary \
					or int(primitive.get("mode", 4)) != 4 or not primitive.get("targets") is Array \
					or primitive.targets.size() != POSES - 1:
				return _fail("Invalid GLB triangle/target declaration: " + path)
			for attribute in ["POSITION", "NORMAL", "TEXCOORD_0", "TEXCOORD_1", "COLOR_0"]:
				if not primitive.attributes.has(attribute):
					return _fail("GLB omits required attribute " + attribute + ": " + path)
			for target: Variant in primitive.targets:
				if not target is Dictionary or not target.has("POSITION") or not target.has("NORMAL"):
					return _fail("GLB pose omits position or normal channel: " + path)
	return true


func _collect_meshes(node: Node, parent_transform: Transform3D, result: Array[Dictionary]) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		result.append({"node": node, "transform": transform})
	for child: Node in node.get_children():
		_collect_meshes(child, transform, result)


func _append_mesh(data: Dictionary, node: MeshInstance3D, transform: Transform3D, kind: int) -> bool:
	var mesh := node.mesh as ArrayMesh
	if mesh == null or mesh.get_blend_shape_mode() != Mesh.BLEND_SHAPE_MODE_NORMALIZED \
			or mesh.get_blend_shape_count() != POSES - 1 or not transform.is_finite() \
			or absf(transform.basis.determinant()) < 0.000001:
		return _fail("Expected finite normalized morph mesh: " + String(node.name))
	if node.skin != null and not _validate_rest_skin(node, transform):
		return false
	var names: Array = LAW_KEYS.slice(1)
	names.append_array(PHASE_KEYS)
	var shape_indices := PackedInt32Array()
	for name: String in names:
		var found := -1
		for i in mesh.get_blend_shape_count():
			if String(mesh.get_blend_shape_name(i)) == name:
				found = i
				break
		if found < 0:
			return _fail("Missing imported shape: " + name)
		shape_indices.append(found)
	var normal_basis := transform.basis.inverse().transposed()
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			return _fail("Imported primitive is not triangles")
		var arrays: Array = mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var legs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := positions.size()
		if count == 0 or normals.size() != count or uvs.size() != count \
				or legs.size() != count or colors.size() != count:
			return _fail("Imported vertex channels have different lengths")
		if node.skin != null and not _validate_weights(arrays, count, node.skin.get_bind_count()):
			return false
		if indices.is_empty():
			for i in count:
				indices.append(i)
		if indices.size() % 3 != 0:
			return _fail("Imported triangle indices are incomplete")
		var offset: int = (data.positions as PackedVector3Array).size()
		var joined_indices: PackedInt32Array = data.indices
		for index in indices:
			if index < 0 or index >= count:
				return _fail("Imported index escapes its surface")
			joined_indices.append(index + offset)
		data.indices = joined_indices
		for i in count:
			var leg := legs[i]
			var color := colors[i]
			var region := int(roundf(color.b * 255.0))
			if not uvs[i].is_finite() or not leg.is_finite() \
					or absf(leg.x - roundf(leg.x)) > 0.0001 \
					or leg.y < -0.0001 or leg.y > 1.0001 \
					or (leg.x == -1.0 and absf(leg.y) > 0.0001) \
					or (kind == 3 and (leg.x < -1.0 or leg.x > 7.0)) \
					or (kind == 6 and (leg.x < -13.0 or leg.x > -1.0)):
				return _fail("Imported species-specific limb binding is invalid")
			if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) \
					or color.r < 0.0 or color.r > 1.0 or color.g < 0.0 or color.g > 1.0 \
					or region < 1 or region > 5 or absf(color.a - 1.0) > 0.001:
				return _fail("Imported anatomical color channels are invalid")
		var joined_uvs: PackedVector2Array = data.uvs
		var joined_legs: PackedVector2Array = data.leg_bind
		var joined_colors: PackedColorArray = data.colors
		joined_uvs.append_array(uvs)
		joined_legs.append_array(legs)
		joined_colors.append_array(colors)
		data.uvs = joined_uvs
		data.leg_bind = joined_legs
		data.colors = joined_colors
		var shapes: Array = mesh.surface_get_blend_shape_arrays(surface)
		if shapes.size() != POSES - 1:
			return _fail("Imported shape surface count differs from shape names")
		for pose in POSES:
			var pose_arrays: Array = arrays if pose == 0 else shapes[shape_indices[pose - 1]]
			var pose_positions: PackedVector3Array = pose_arrays[Mesh.ARRAY_VERTEX]
			var pose_normals: PackedVector3Array = pose_arrays[Mesh.ARRAY_NORMAL]
			if pose_positions.size() != count or pose_normals.size() != count:
				return _fail("Imported pose topology or normals differ from Basis")
			var transformed_positions := PackedVector3Array()
			var transformed_normals := PackedVector3Array()
			transformed_positions.resize(count)
			transformed_normals.resize(count)
			for i in count:
				var position := transform * pose_positions[i]
				var normal := normal_basis * pose_normals[i]
				if not position.is_finite() or not normal.is_finite() or normal.length_squared() < 0.000001:
					return _fail("Non-finite pose position or degenerate normal")
				transformed_positions[i] = position
				transformed_normals[i] = normal.normalized()
			# Imported NORMALIZED targets already contain absolute positions and
			# normals. Adding Basis here would apply the rest geometry twice.
			var collected_positions: PackedVector3Array = data.pose_positions[pose]
			var collected_normals: PackedVector3Array = data.pose_normals[pose]
			collected_positions.append_array(transformed_positions)
			collected_normals.append_array(transformed_normals)
			data.pose_positions[pose] = collected_positions
			data.pose_normals[pose] = collected_normals
			if pose == 0:
				data.positions = collected_positions
				data.normals = collected_normals
	return true


func _node_rest_transform(node: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var cursor := node
	while cursor != null:
		if cursor is Node3D:
			result = (cursor as Node3D).transform * result
		cursor = cursor.get_parent()
	return result


func _validate_rest_skin(node: MeshInstance3D, mesh_transform: Transform3D) -> bool:
	# Rigs remain useful Blender authoring sources. Their imported rest skin
	# may be omitted only after proving that it leaves these mesh vertices
	# unchanged; a posed/deformed skeleton is not silently baked incorrectly.
	var skeleton := node.get_node_or_null(node.skeleton) as Skeleton3D
	if skeleton == null or node.skin.get_bind_count() <= 0:
		return _fail("Imported skin has no resolvable skeleton/binds")
	var skeleton_to_mesh := mesh_transform.affine_inverse() * _node_rest_transform(skeleton)
	for bind in node.skin.get_bind_count():
		var bone := node.skin.get_bind_bone(bind)
		var bone_name := node.skin.get_bind_name(bind)
		if not String(bone_name).is_empty():
			bone = skeleton.find_bone(bone_name)
		if bone < 0 or bone >= skeleton.get_bone_count():
			return _fail("Imported skin bind names an absent bone")
		var rest := skeleton_to_mesh * skeleton.get_bone_global_rest(bone) * node.skin.get_bind_pose(bind)
		if not rest.is_finite() or rest.origin.length() > 0.0001 \
				or rest.basis.x.distance_to(Vector3.RIGHT) > 0.0001 \
				or rest.basis.y.distance_to(Vector3.UP) > 0.0001 \
				or rest.basis.z.distance_to(Vector3.BACK) > 0.0001:
			return _fail("Authoring skin rest is not an identity deformation")
	return true


func _validate_weights(arrays: Array, count: int, binds: int) -> bool:
	if not arrays[Mesh.ARRAY_BONES] is PackedInt32Array \
			or not arrays[Mesh.ARRAY_WEIGHTS] is PackedFloat32Array:
		return _fail("Skinned authoring mesh omits bone/weight channels")
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if bones.size() != weights.size() or (bones.size() != count * 4 and bones.size() != count * 8):
		return _fail("Skinned authoring mesh has inconsistent weight counts")
	var stride := int(bones.size() / count)
	for vertex in count:
		var sum := 0.0
		for influence in stride:
			var index := vertex * stride + influence
			if bones[index] < 0 or bones[index] >= binds or not is_finite(weights[index]) or weights[index] < 0.0:
				return _fail("Authoring skin contains an invalid bone weight")
			sum += weights[index]
		if absf(sum - 1.0) > 0.005:
			return _fail("Authoring skin weights do not sum to one")
	return true


func _make_atlas() -> bool:
	atlas_height = ceili(float(atlas_vertices * POSES * 2) / float(WIDTH))
	if atlas_vertices <= 0 or atlas_height > MAX_ATLAS_HEIGHT:
		return _fail("Pose atlas exceeds the declared texture budget")
	var pixels := PackedFloat32Array()
	pixels.resize(WIDTH * atlas_height * 4)
	atlas_bytes = pixels.size() * 4
	for kind in [3, 6]:
		for lod in [0, 1]:
			var template: Dictionary = templates[kind][lod]
			var count: int = (template.positions as PackedVector3Array).size()
			for pose in POSES:
				var positions: PackedVector3Array = template.pose_positions[pose]
				var normals: PackedVector3Array = template.pose_normals[pose]
				for i in count:
					_write_texel_pair(pixels, int(template.atlas_base) + i, pose, positions[i], normals[i])
				if kind == 3:
					var feet: PackedVector3Array = template.foot_anchors[pose]
					for foot in 8:
						_write_texel_pair(pixels, int(template.foot_base) + foot, pose, feet[foot], Vector3.UP)
				if kind == 6:
					var cilia: PackedVector3Array = template.cilium_anchors[pose]
					for cilium in 12:
						_write_texel_pair(pixels, int(template.cilium_base) + cilium, pose, cilia[cilium], Vector3.UP)
	var image := Image.create_from_data(WIDTH, atlas_height, false, Image.FORMAT_RGBAF, pixels.to_byte_array())
	if image == null or image.is_empty():
		return _fail("Pose atlas image allocation failed")
	texture = ImageTexture.create_from_image(image)
	return texture != null or _fail("Pose atlas texture allocation failed")


func _write_texel_pair(pixels: PackedFloat32Array, vertex: int, pose: int,
		position: Vector3, normal: Vector3) -> void:
	var offset := (vertex * POSES + pose) * 8
	pixels[offset] = position.x
	pixels[offset + 1] = position.y
	pixels[offset + 2] = position.z
	pixels[offset + 3] = 1.0
	pixels[offset + 4] = normal.x
	pixels[offset + 5] = normal.y
	pixels[offset + 6] = normal.z
	pixels[offset + 7] = 1.0


func stats() -> Dictionary:
	var sources: Array[Dictionary] = []
	for kind in templates:
		for lod in templates[kind]:
			var template: Dictionary = templates[kind][lod]
			sources.append({"kind": kind, "lod": lod, "source": template.source,
				"manifest": template.manifest, "vertices": (template.positions as PackedVector3Array).size(),
				"triangles": template.triangles, "atlas_base": template.atlas_base,
				"foot_base": template.foot_base, "cilium_base": template.cilium_base,
				"cilium_anchor_count": template.cilium_anchor_count, "bounds": template.bounds})
	return {"ready": ready, "error": error, "width": width, "height": atlas_height,
		"pose_count": pose_count, "atlas_vertices": atlas_vertices, "bytes": atlas_bytes,
		"load_usec": load_usec, "templates": sources}
