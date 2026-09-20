class_name DreamCritterBlenderAssets
extends RefCounted
## Shared, weakly cached imported pose data. The imported meshes are read once;
## both fauna batches retain this one immutable atlas, never one per animal.

const SPECIES := {0: "seam_grazer", 1: "crystal_listener", 2: "fold_crab",
	3: "tardigrade", 4: "stentor", 5: "lacrymaria", 6: "vorticella",
	7: "euplotes", 8: "spirostomum", 9: "heliozoan", 10: "euglena", 11: "volvox", 12: "noctiluca", 13: "bacillaria",
	14: "salpingoeca", 15: "mesodinium"}
const MOTION_PROFILES := {0: "seam_grazer_unfold", 1: "crystal_listener_spin", 2: "fold_crab_joints",
	4: "stentor_contractile_trumpet", 5: "lacrymaria_search",
	7: "euplotes_cirral_walk", 8: "spirostomum_contractile_spindle", 9: "heliozoan_capture",
	10: "euglena_metaboly", 11: "volvox_daughter_inversion",
	12: "noctiluca_flash", 13: "bacillaria_raphe_slide", 14: "salpingoeca_rosette",
	15: "mesodinium_archipelago"}
# The historical manifest field cilium_anchors also carries the two
# count-owned Noctiluca feeding-appendage roots. Heliozoan rays use authored
# law-pose selection and have no collapse-anchor rows.
const CILIUM_COUNTS := {0: 8, 1: 12, 2: 5, 4: 12, 6: 12, 7: 6, 8: 36, 10: 1, 11: 12, 12: 2, 15: 12}
const BRANCH_COUNTS := {0: 8, 1: 12, 2: 5, 4: 12, 6: 12, 7: 6, 8: 36, 9: 12, 10: 1, 11: 12, 12: 2, 15: 12}
const FOOT_SPECIES := [2, 3]
const EUPLOTES_CIRRUS_CONTROLS := [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7]
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
	for kind in SPECIES:
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
			template["foot_base"] = atlas_vertices if kind in FOOT_SPECIES else -1
			if kind in FOOT_SPECIES:
				atlas_vertices += 8
			var cilium_count := int(CILIUM_COUNTS.get(kind, 0))
			template["cilium_base"] = atlas_vertices if cilium_count > 0 else -1
			template["cilium_anchor_count"] = cilium_count
			atlas_vertices += cilium_count
			for channel in ["prop", "joint", "manipulator"]:
				var row_count := int(template[channel + "_row_count"])
				template[channel + "_base"] = atlas_vertices if row_count > 0 else -1
				atlas_vertices += row_count
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
	if MOTION_PROFILES.has(kind) and manifest.get("motion_profile") != MOTION_PROFILES[kind]:
		_fail("Manifest motion profile differs from the species law: " + path)
		return {}
	if kind == 5 and (manifest.get("neck_root") != [0.0, 0.03, 0.37] \
			or manifest.get("neck_reach") != [1.2, 6.4]):
		_fail("Lacrymaria neck root/reach differs from the authored search contract: " + path)
		return {}
	if kind == 7 and manifest.get("cirrus_controls") != EUPLOTES_CIRRUS_CONTROLS:
		_fail("Euplotes must retain its fourteen tips and eight authored cirral groups: " + path)
		return {}
	var anchors := _read_feet(manifest.foot_anchors, kind)
	if not error.is_empty() or (kind in FOOT_SPECIES and anchors.is_empty()):
		return {}
	var cilia := _read_cilia(manifest.cilium_anchors, kind)
	if not error.is_empty() or (CILIUM_COUNTS.has(kind) and cilia.is_empty()):
		return {}
	var props: Array = []
	var joints: Array = []
	var manipulators: Array = []
	if kind == 1:
		props = _read_pose_rows(manifest.get("prop_anchors"), 5, "Listener prop anchors")
	if kind == 2:
		joints = _read_rest_chains(manifest.get("rest_joint_chains"), 8, 5, "Fold crab leg joints")
		manipulators = _read_rest_chains(manifest.get("rest_manipulator_chains"), 2, 3, "Fold crab manipulators")
	if not error.is_empty():
		return {}
	if kind == 2:
		for leg in 8:
			var flank := -1.0 if leg < 4 else 1.0
			var fore := 0.4 - float(leg % 4) * 0.8 / 3.0
			var expected_root := Vector3(flank * 0.36, 0.0, fore * 0.78)
			var expected_foot := Vector3(flank * 1.05, -0.52, fore)
			var rest: PackedVector3Array = joints[0]
			if rest[leg * 5].distance_to(expected_root) > 0.00001 \
					or rest[leg * 5 + 4].distance_to(expected_foot) > 0.00001:
				_fail("Fold crab canonical chain must preserve existing CPU rest sockets and feet: " + path)
				return {}
			for pose in POSES:
				if (anchors[pose] as PackedVector3Array)[leg].distance_to(expected_foot) > 0.00001:
					_fail("Fold crab authored foot anchors must remain planted across crease/phase keys: " + path)
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
		"prop_anchors": props, "joint_anchors": joints, "manipulator_anchors": manipulators,
		"prop_row_count": 5 if kind == 1 else 0, "joint_row_count": 40 if kind == 2 else 0,
		"manipulator_row_count": 6 if kind == 2 else 0,
		"source": mesh_path, "manifest": path, "lod": lod, "kind": kind,
		"triangles": 0, "bounds": AABB()}
	if kind == 5:
		data["neck_root"] = Vector3(float(manifest.neck_root[0]), float(manifest.neck_root[1]),
			float(manifest.neck_root[2]))
		data["neck_reach"] = Vector2(float(manifest.neck_reach[0]), float(manifest.neck_reach[1]))
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
	if kind in FOOT_SPECIES or kind == 1:
		var seen: Dictionary = {}
		for leg: Vector2 in data.leg_bind:
			if leg.x >= 0.0 and (kind != 1 or leg.y > 0.0001):
				seen[int(roundf(leg.x))] = true
		if seen.size() != (5 if kind == 1 else 8):
			_fail("Species must carry every authored positive limb binding: " + mesh_path)
			return {}
	if BRANCH_COUNTS.has(kind):
		var seen_cilia: Dictionary = {}
		for binding: Vector2 in data.leg_bind:
			if binding.x <= -2.0 and binding.x >= -1.0 - float(BRANCH_COUNTS[kind]) and binding.y > 0.0001:
				seen_cilia[-2 - int(roundf(binding.x))] = true
		if seen_cilia.size() != int(BRANCH_COUNTS[kind]):
			_fail("Species does not carry every declared authored appendage binding: " + mesh_path)
			return {}
	if kind == 2 and not _validate_fold_endpoints(data, mesh_path):
		return {}
	if kind == 12:
		var has_flash_sites := false
		for color: Color in data.colors:
			has_flash_sites = has_flash_sites or int(roundf(color.b * 255.0)) == 6
		if not has_flash_sites:
			_fail("Noctiluca source omits its region-six scintillon sites: " + mesh_path)
			return {}
	if kind == 5:
		var seen_neck := false
		var seen_head := false
		for binding: Vector2 in data.leg_bind:
			seen_neck = seen_neck or (binding.x == -2.0 and binding.y > 0.0001)
			seen_head = seen_head or (binding.x == -3.0 and binding.y >= 0.9999)
		if not seen_neck or not seen_head:
			_fail("Lacrymaria must carry both neck and head search roles: " + mesh_path)
			return {}
	if kind == 13:
		for pose in [16, 17, 18]:
			if data.pose_positions[pose] != data.positions or data.pose_normals[pose] != data.normals:
				_fail("Bacillaria closed-cycle endpoint and neutral gait keys must equal Basis: " + mesh_path)
				return {}
	var points: PackedVector3Array = data.positions
	var bounds := AABB(points[0], Vector3.ZERO)
	for pose: PackedVector3Array in data.pose_positions:
		for point: Vector3 in pose:
			bounds = bounds.expand(point)
	data.bounds = bounds
	data.triangles = triangles
	return data


func _valid_binding(kind: int, binding: Vector2) -> bool:
	var code := int(roundf(binding.x))
	if kind == 2:
		return (code >= -6 and code <= 7) or code in [-20, -21]
	if kind == 1:
		return code >= -13 and code <= 4
	if kind == 3:
		return code >= -1 and code <= 7
	if kind == 5:
		return code >= -3 and code <= -1 and (code != -3 or absf(binding.y - 1.0) <= 0.0001)
	if BRANCH_COUNTS.has(kind):
		return code >= -1 - int(BRANCH_COUNTS[kind]) and code <= -1
	return code == -1 and kind in [13, 14]


func _validate_fold_endpoints(data: Dictionary, path: String) -> bool:
	var roots: Dictionary = {}
	var tips: Dictionary = {}
	var jaws: Dictionary = {}
	for vertex in (data.positions as PackedVector3Array).size():
		var binding: Vector2 = data.leg_bind[vertex]
		var code := int(roundf(binding.x))
		var is_endpoint := code >= 0 and (binding.y <= 0.0001 or binding.y >= 0.9999)
		if code >= 0 and binding.y <= 0.0001:
			roots[code] = true
		if code >= 0 and binding.y >= 0.9999:
			tips[code] = true
		if code in [-20, -21]:
			jaws[code] = true
		if is_endpoint or code in [-20, -21]:
			var basis_position: Vector3 = data.positions[vertex]
			for pose in LAW_KEYS.size():
				var pose_position: Vector3 = data.pose_positions[pose][vertex]
				if pose_position.distance_to(basis_position) > 0.00001:
					return _fail("Fold crease poses must retain leg endpoints and mouth rest geometry: " + path)
	if roots.size() != 8 or tips.size() != 8 or jaws.size() != 2:
		return _fail("Fold source omits rooted leg endpoints or either mouth manipulator: " + path)
	return true


func _read_pose_rows(raw: Variant, count: int, label: String) -> Array:
	if not raw is Array or raw.size() != POSES:
		_fail(label + " must contain nineteen pose rows")
		return []
	var rows: Array = []
	for pose: Variant in raw:
		if not pose is Array or pose.size() != count:
			_fail(label + " has an incorrect point count")
			return []
		var row := PackedVector3Array()
		for point: Variant in pose:
			if not point is Array or point.size() != 3:
				_fail(label + " contains a malformed point")
				return []
			for component: Variant in point:
				if (not component is float and not component is int) or not is_finite(float(component)):
					_fail(label + " contains a non-finite point")
					return []
			row.append(Vector3(float(point[0]), float(point[1]), float(point[2])))
		rows.append(row)
	return rows


func _read_rest_chains(raw: Variant, count: int, joints: int, label: String) -> Array:
	if not raw is Array or raw.size() != count:
		_fail(label + " has an incorrect chain count")
		return []
	var flattened: Array = []
	for chain: Variant in raw:
		if not chain is Array or chain.size() != joints:
			_fail(label + " has an incorrect joint count")
			return []
		flattened.append_array(chain)
	var repeated: Array = []
	for _pose in POSES:
		repeated.append(flattened)
	var rows := _read_pose_rows(repeated, count * joints, label)
	if rows.is_empty():
		return []
	var rest: PackedVector3Array = rows[0]
	for chain in count:
		for joint in range(1, joints):
			if rest[chain * joints + joint].distance_to(rest[chain * joints + joint - 1]) < 0.00001:
				_fail(label + " contains a zero-length joint segment")
				return []
	return rows


func _read_feet(raw: Array, kind: int) -> Array:
	if kind not in FOOT_SPECIES:
		if not raw.is_empty():
			_fail("A species without articulated legs cannot claim foot anchors")
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
	if not CILIUM_COUNTS.has(kind):
		if not raw.is_empty():
			_fail("A species without counted cilia cannot claim cilium anchors")
		return []
	if raw.size() != POSES:
		_fail("Cilium anchors must contain all nineteen law/phase poses")
		return []
	var anchors: Array = []
	var expected_count := int(CILIUM_COUNTS[kind])
	for pose: Variant in raw:
		if not pose is Array or pose.size() != expected_count:
			_fail("Each appendage-anchor pose must contain %d points" % expected_count)
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
					or not _valid_binding(kind, leg):
				return _fail("Imported species-specific limb binding is invalid")
			if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) \
					or color.r < 0.0 or color.r > 1.0 or color.g < 0.0 or color.g > 1.0 \
					or region < 1 or region > (6 if kind == 12 else 5) or absf(color.a - 1.0) > 0.001:
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
	for kind in SPECIES:
		for lod in [0, 1]:
			var template: Dictionary = templates[kind][lod]
			var count: int = (template.positions as PackedVector3Array).size()
			for pose in POSES:
				var positions: PackedVector3Array = template.pose_positions[pose]
				var normals: PackedVector3Array = template.pose_normals[pose]
				for i in count:
					_write_texel_pair(pixels, int(template.atlas_base) + i, pose, positions[i], normals[i])
				if kind in FOOT_SPECIES:
					var feet: PackedVector3Array = template.foot_anchors[pose]
					for foot in 8:
						_write_texel_pair(pixels, int(template.foot_base) + foot, pose, feet[foot], Vector3.UP)
				if CILIUM_COUNTS.has(kind):
					var cilia: PackedVector3Array = template.cilium_anchors[pose]
					for cilium in int(template.cilium_anchor_count):
						_write_texel_pair(pixels, int(template.cilium_base) + cilium, pose, cilia[cilium], Vector3.UP)
				for channel in ["prop", "joint", "manipulator"]:
					if int(template[channel + "_row_count"]) > 0:
						var rows: PackedVector3Array = template[channel + "_anchors"][pose]
						for row in rows.size():
							_write_texel_pair(pixels, int(template[channel + "_base"]) + row, pose, rows[row], Vector3.UP)
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
			for channel in ["prop", "joint", "manipulator"]:
				sources[-1][channel + "_base"] = template[channel + "_base"]
				sources[-1][channel + "_row_count"] = template[channel + "_row_count"]
			if int(kind) == 5:
				sources[-1]["neck_root"] = template.neck_root
				sources[-1]["neck_reach"] = template.neck_reach
	return {"ready": ready, "error": error, "width": width, "height": atlas_height,
		"pose_count": pose_count, "atlas_vertices": atlas_vertices, "bytes": atlas_bytes,
		"load_usec": load_usec, "templates": sources}
