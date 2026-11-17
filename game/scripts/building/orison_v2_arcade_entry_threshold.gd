extends RefCounted
## Prepared entry ramp in fabrication coordinates. The region owns placement.
const DATA := "res://data/orison_v2/arcade_entry_threshold.json"
const ASSET := "res://assets/props/arcade_entry_threshold.glb"
const DRAW := "ArcadeGatewayThreshold"

static func prepare() -> Node3D:
	var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if spec is not Dictionary or spec.get("schema") != "orison.v2.arcade-entry-threshold.v1":
		return null
	if FileAccess.get_sha256(ASSET) != spec.get("asset_sha256", ""):
		return null
	var settings := ConfigFile.new()
	if settings.load(ASSET+".import") != OK or settings.get_value("params","meshes/force_disable_compression",false) != true:
		return null
	var scene := load(ASSET) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate() as Node3D
	var draw := root.get_node_or_null(DRAW) as MeshInstance3D
	if draw == null or root.get_child_count() != 1 or not root.transform.is_equal_approx(Transform3D.IDENTITY) \
		or not draw.transform.is_equal_approx(Transform3D.IDENTITY) or draw.mesh == null or draw.mesh.get_surface_count() != 1 \
		or draw.mesh.get_faces().size() != 36:
		root.free()
		return null
	var key := "arcade_terrazzo"
	var finish := MatLib.get_mat(key).duplicate() as StandardMaterial3D
	finish.uv1_triplanar = false
	finish.uv1_scale = Vector3.ONE / float(MatLib.SETS[key][3])
	finish.normal_scale = .18
	finish.roughness = 1.
	draw.material_override = SurfacePass.surface_for(finish, {"uv_mode":0, "pigment_variation":1.})
	draw.set_meta("material_key", key)
	draw.create_trimesh_collision()
	root.name = "ArcadeEntryThreshold"
	return root
