extends "res://scripts/building/orison_v2_native_domestic_furniture.gd"
## Existing light actors retain circuits, emissions, sound and conductor state.
const PATH := "res://data/orison_v2/fixed_lighting.json"
const PhotoLight := preload("res://scripts/props/photo_darkroom_light.gd")
var installed: Dictionary = {}
var _offsets: Dictionary = {}
var errors: Array[String] = []
var superseded_bar_mounts: Array[String] = []

func prepare() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not _prepare_family(data): return false
	for row: Dictionary in data.instances:
		var offset: Array = row.get("visual_offset", [0,0,0])
		_offsets[str(row.id)] = Vector3(offset[0],offset[1],offset[2])
	# The owner's native score panel has a face 10 mm behind the old proxy.
	# Seat existing stock with the same explicit fitting-offset mechanism.
	var current_fits: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/owner_light_fits.json"))
	if not _offsets.has("F01_BAR_LT_WEST1") or current_fits.size()!=1:return false
	var fit: Array=current_fits["F01_BAR_LT_WEST1"]
	_offsets["F01_BAR_LT_WEST1"]+=Vector3(fit[0],fit[1],fit[2])
	for row: Dictionary in data.assemblies:
		for i in row.parts.size():
			var component := str(row.parts[i].component)
			if component not in ["Body", "Mount", "Bulb", "Stained"]: return false
			_variants[str(row.id)][i]["component"] = component
	return true

func mount(world: Node3D) -> bool:
	if not prepare(): return false
	var actors: Array[LightFixtureProp] = []
	for node: Node in world.find_children("*", "Node3D", true, false):
		if not node is LightFixtureProp: continue
		var prop := node as LightFixtureProp
		if prop is PhotoLight or not _instances.has(str(prop.name)): continue
		actors.append(prop)
	# This family now owns the complete fitted support for these bar fixtures.
	# Keep canopy stays and retained V1 rods; remove only superseded lamp brackets.
	var old_mounts: Array[MeshInstance3D] = []
	for node: Node in world.find_children("*", "MeshInstance3D", true, false):
		var part := str(node.get_meta("bar_fixture_mount_part", ""))
		if part.begins_with("F01_BAR_LT_") and _instances.has(part.get_slice("__",0)):
			old_mounts.append(node as MeshInstance3D)
	for draw: MeshInstance3D in old_mounts:
		superseded_bar_mounts.append(str(draw.get_meta("bar_fixture_mount_part")))
		draw.get_parent().remove_child(draw)
		draw.free()
	# Replacing stock frees descendants from the initial tree snapshot.
	# Collect the surviving actor owners before mutating any of their children.
	for prop: LightFixtureProp in actors:
		if not install_on(prop): return false
	for identity: String in _instances:
		if not installed.has(identity): errors.append("Missing fixed light: " + identity)
	return errors.is_empty()

func install_on(prop: LightFixtureProp) -> bool:
	var identity := str(prop.name)
	if installed.has(identity) or prop._swing_node == null or prop._bulb_mat == null: return false
	var variant: String = _instances[identity]
	var source_visuals: Array[Node] = []
	var stained: Material
	for child: Node in prop._swing_node.get_children():
		if child is MeshInstance3D and child != prop._halo:
			source_visuals.append(child)
			if str(child.name).to_lower().contains("stained") or str(child.name).to_lower().contains("prismatic"):
				stained = (child as MeshInstance3D).get_active_material(0)
	# Refuse missing special optics before removing any original stock.
	if _variants[variant].any(func(part): return part.component == "Stained") and stained == null: return false
	prop.set_meta("v2_source_light_snapshot", {"actor_pose":prop.transform,
		"light":prop.light.get_instance_id(), "bounce":prop.bounce.get_instance_id(),
		"bulb_material":prop._bulb_mat.get_instance_id(), "halo":prop._halo.get_instance_id(),
		"swing":prop._swing_node.get_instance_id(), "light_pose":prop.light.transform,
		"bounce_pose":prop.bounce.transform,
		"base_energy":prop._base_energy, "range":prop.light.omni_range,
		"standby":prop.standby_scale, "navigation":prop.navigation_light,
		"graph_node_id":prop.graph_node_id})
	for child: Node in source_visuals:
		prop._swing_node.remove_child(child)
		child.free()
	prop._swing_node.position += _offsets[identity]
	prop.bounce.position += _offsets[identity]
	for part: Dictionary in _variants[variant]:
		var draw := MeshInstance3D.new()
		draw.name = str(part.name)
		draw.mesh = part.mesh
		draw.transform = part.pose
		if part.component == "Mount": draw.position += _offsets[identity]
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.set_meta("native_fixed_light_part", part.name)
		draw.set_meta("material_key", part.key)
		if part.component == "Bulb":
			var finish := part.mesh.surface_get_material(0) as StandardMaterial3D
			prop._bulb_mat.albedo_texture = finish.albedo_texture
			prop._bulb_mat.roughness_texture = finish.roughness_texture
			prop._bulb_mat.normal_enabled = finish.normal_enabled
			prop._bulb_mat.normal_texture = finish.normal_texture
			prop._bulb_mat.normal_scale = finish.normal_scale
			prop._bulb_mat.roughness = finish.roughness
			prop._bulb_mat.uv1_triplanar = false
			prop._bulb_mat.uv1_scale = finish.uv1_scale
			draw.material_override = prop._bulb_mat
		elif part.component == "Stained": draw.material_override = stained
		(prop if part.component == "Mount" else prop._swing_node).add_child(draw)
	# Bound the local optical halo to this small globe beside the medicine mirror.
	# The original halo object, gradient, light energy and circuit remain owners.
	if identity == "3B_LT_SCONCE":
		var halo_mesh := prop._halo.mesh.duplicate() as QuadMesh
		halo_mesh.size = Vector2(.205, .205)
		prop._halo.mesh = halo_mesh
	prop.set_meta("v2_native_fixed_light_variant", variant)
	installed[identity] = weakref(prop)
	return true

func finish() -> void:
	installed.clear()
	_offsets.clear()
	superseded_bar_mounts.clear()
	super.finish()
