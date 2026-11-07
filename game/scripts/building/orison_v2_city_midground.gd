extends Node3D
## Mid-ground streets and blocks between the composed near city and the old 450 m
## ring. Walkable inside 215 m (Lily's 200 m edge, ruling barrier_distance); beyond
## that the fabric is for the view and carries no collision (art/blender/scripts/build_city_midground.py). Additive: it
## builds only where a survey of the running world found bare apron, and edits no
## installed owner. Adds street, sidewalk, building, stoop, fence and furniture
## collision; window glass is the background-window optics on MultiMeshes; lamps
## follow the installed street-lamp clock. No access, resident, shop, weather or
## save authority.
const ASSET := "res://assets/props/city_midground.glb"
const DATA := "res://data/orison_v2/exterior/city_midground.json"
const FacadeShader := preload("res://shaders/v2_far_city_facade.gdshader")
const WindowMaterial := preload("res://scripts/building/v2_background_window_material.gd")
const FAR_FACADES := {"far_brick": "brick", "far_city_grey_brick": "city_grey_brick", "far_limestone": "limestone"}
const PLAIN := ["brick", "city_grey_brick", "limestone", "terracotta", "galvanized_roof", "roof_bitumen",
	"door_paint", "fabric_warm", "iron_blackened", "tank_staves", "site_softwood", "asphalt", "concrete",
	"cast_iron", "glass_frosted", "fire_cabinet_enamel", "zinc_liner", "glass_cut"]
## Near detail and far masses cross over here (metres from the camera to a tile's centre).
const NEAR_END := 250.0
const FAR_BEGIN := 220.0
const FADE := 30.0

var facade_materials: Array[ShaderMaterial] = []
var window_materials: Array[ShaderMaterial] = []
var lamp_materials: Array[StandardMaterial3D] = []
var data: Dictionary = {}
var _clock := CampaignClock.new()
var _elapsed := INF
var _minute := -INF


static func mount(parent: Node3D) -> Node3D:
	# Absent until the generator has run against a survey of the installed world;
	# the survey itself (tests/V2MidgroundOccupancyProbe.tscn) runs without it.
	if not ResourceLoader.exists(ASSET) or not FileAccess.file_exists(DATA):
		return null
	var midground := preload("res://scripts/building/orison_v2_city_midground.gd").new()
	midground.name = "Midground"
	parent.add_child(midground)
	return midground


func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	assert(data is Dictionary and int(data.schema) == 1 and str(data.frame) == "WORLD", "mid-ground data")
	var model := (load(ASSET) as PackedScene).instantiate() as Node3D
	add_child(model)
	var made := {}
	var stock := {}
	var ground_body := StaticBody3D.new()
	ground_body.name = "MidgroundGround"
	add_child(ground_body)
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var group := str(draw.name).get_slice("__", 0)
		var key := str(draw.name).get_slice("__", 1)
		if not made.has(key):
			made[key] = _material(key)
		draw.material_override = made[key]
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		draw.set_meta("v2_city_midground", true)
		if group.begins_with("furn_"):
			stock.get_or_add(group.trim_prefix("furn_"), []).append(draw)
			draw.visible = false
		elif group.begins_with("far"):
			draw.visibility_range_begin = FAR_BEGIN
			draw.visibility_range_begin_margin = FADE
			draw.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		elif group.begins_with("v"):
			pass  # ground beyond the walkable edge: seen, never stood on
		elif group.begins_with("g"):
			var shape := CollisionShape3D.new()
			shape.shape = draw.mesh.create_trimesh_shape()
			shape.transform = draw.global_transform if draw.is_inside_tree() else draw.transform
			ground_body.add_child(shape)
		else:
			draw.visibility_range_end = NEAR_END
			draw.visibility_range_end_margin = FADE
			draw.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_build_panes()
	_build_furniture(stock)
	_build_colliders()
	_refresh(true)


func _material(key: String) -> Material:
	if FAR_FACADES.has(key):
		var source: StandardMaterial3D = MatLib.get_mat(str(FAR_FACADES[key]))
		var facade := ShaderMaterial.new()
		facade.shader = FacadeShader
		facade.set_shader_parameter("albedo_tex", source.albedo_texture)
		facade.set_shader_parameter("rough_tex", source.roughness_texture)
		facade.set_shader_parameter("normal_tex", source.normal_texture)
		facade.set_shader_parameter("physical_uv_scale", Vector2(source.uv1_scale.x, source.uv1_scale.y))
		facade_materials.append(facade)
		return facade
	assert(key in PLAIN, "unmapped mid-ground material " + key)
	var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
	# UV0 is already metric; keep the catalogue's tile scale and turn triplanar off.
	material.uv1_triplanar = false
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if key == "glass_frosted" or key == "glass_cut":
		material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		material.emission_enabled = true
		material.emission = Color(1.0, 0.72, 0.42) if key == "glass_frosted" else Color(1.0, 0.18, 0.08)
		material.set_meta("lamp_energy", 2.4 if key == "glass_frosted" else 1.6)
		lamp_materials.append(material)
	return material


static func _pane_mesh(size: Vector2) -> ArrayMesh:
	# A pane in XY facing +Z: UV metric, UV2 the normalized chart (top-left origin).
	var w := size.x * 0.5
	var h := size.y * 0.5
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-w, -h, 0), Vector3(w, -h, 0), Vector3(w, h, 0), Vector3(-w, h, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, size.y), Vector2(size.x, size.y), Vector2(size.x, 0), Vector2(0, 0)])
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_panes() -> void:
	var tile := float(data.tile_m)
	for spec: Dictionary in data.panes:
		var cls := str(spec["class"])
		var size := Vector2(spec.size[0], spec.size[1])
		var material := WindowMaterial.create("midground_" + cls, int(spec.room_kind), size)
		window_materials.append(material)
		var mesh := _pane_mesh(size)
		var tiles := {}
		for item: Array in spec.items:
			var key := Vector2i(floori((item[0] + 500.0) / tile), floori((item[2] + 500.0) / tile))
			tiles.get_or_add(key, []).append(item)
		for key: Vector2i in tiles:
			var items: Array = tiles[key]
			var centre := Vector3((key.x + 0.5) * tile - 500.0, 0.0, (key.y + 0.5) * tile - 500.0)
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_custom_data = true
			multimesh.mesh = mesh
			multimesh.instance_count = items.size()
			for i in items.size():
				var item: Array = items[i]
				var basis := Basis(Vector3.UP, atan2(float(item[3]), float(item[4]))).scaled(Vector3(item[5], item[6], 1.0))
				multimesh.set_instance_transform(i, Transform3D(basis, Vector3(item[0], item[1], item[2]) - centre))
				multimesh.set_instance_custom_data(i, Color(fposmod(float(item[7]), 8192.0) / 8192.0, 0, 0, 0))
			var draw := MultiMeshInstance3D.new()
			draw.name = "Panes_%s_%d_%d" % [cls, key.x, key.y]
			draw.multimesh = multimesh
			draw.material_override = material
			draw.position = centre
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			draw.visibility_range_end = NEAR_END
			draw.visibility_range_end_margin = FADE
			draw.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(draw)


func _build_furniture(stock: Dictionary) -> void:
	for group: Dictionary in data.furniture:
		var kind := str(group.kind)
		var items: Array = group["items"]
		if not stock.has(kind) or items.is_empty():
			continue
		for source: MeshInstance3D in stock[kind]:
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = source.mesh
			multimesh.instance_count = items.size()
			for i in items.size():
				var item: Array = items[i]
				multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(item[3])), Vector3(item[0], item[1], item[2])))
			var draw := MultiMeshInstance3D.new()
			draw.name = "Furniture_" + str(source.name)
			draw.multimesh = multimesh
			draw.material_override = source.material_override
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			add_child(draw)


func _build_colliders() -> void:
	var body := StaticBody3D.new()
	body.name = "MidgroundCollision"
	add_child(body)
	for item: Array in data.colliders:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(item[3], item[4], item[5])
		shape.shape = box
		shape.position = Vector3(item[0], item[1], item[2])
		body.add_child(shape)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.5:
		return
	_elapsed = 0.0
	_refresh(false)


func _refresh(force: bool) -> bool:
	_follow_lamps()
	if not _clock.bind_state():
		return false
	var minute := floorf(_clock.calendar_minutes())
	if minute == _minute and not force:
		_copy_fog()
		return true
	_minute = minute
	return project_clock(_clock)


func _follow_lamps() -> void:
	# The installed street lamps own dusk and dawn; the new lamps light with them.
	var lit := 0.0
	for node in get_tree().get_nodes_in_group("v2_street_lamp_clocks"):
		lit = maxf(lit, float(node.get("lit")))
	for material in lamp_materials:
		material.emission_energy_multiplier = float(material.get_meta("lamp_energy", 1.0)) * lit


## Also used by a prologue or capture that borrows the world clock.
func project_clock(clock: CampaignClock) -> bool:
	var day := clock.day_info()
	if not bool(day.get("valid", false)):
		return false
	var minute_of_day := clock.minute_of_day()
	var hour := minute_of_day / 60.0
	var dusk := smoothstep(15.5, 17.5, hour) * (1.0 - smoothstep(20.0, 22.0, hour)) \
		+ smoothstep(4.5, 6.0, hour) * (1.0 - smoothstep(7.0, 8.5, hour))
	for material in facade_materials:
		material.set_shader_parameter("minute_of_day", minute_of_day)
		material.set_shader_parameter("weekend", str(day.day) in ["sat", "sun"])
		material.set_shader_parameter("dusk_fill", dusk)
	for material in window_materials:
		WindowMaterial.sync_clock(material, clock)
	_copy_fog()
	return true


func _copy_fog() -> void:
	var environment: Environment = null
	if is_inside_tree() and get_viewport() != null and get_viewport().world_3d != null:
		environment = get_viewport().world_3d.environment
	if environment == null:
		return
	var density := environment.fog_density if environment.fog_enabled else 0.0
	for material in facade_materials:
		material.set_shader_parameter("fog_density", density)
		material.set_shader_parameter("fog_begin", environment.fog_depth_begin)
		material.set_shader_parameter("fog_end", environment.fog_depth_end)
		material.set_shader_parameter("fog_curve", environment.fog_depth_curve)
		material.set_shader_parameter("fog_colour", environment.fog_light_color * environment.fog_light_energy)
