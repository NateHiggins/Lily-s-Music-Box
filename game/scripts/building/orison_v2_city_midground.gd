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
	"cast_iron", "glass_frosted", "fire_cabinet_enamel", "zinc_liner", "glass_cut", "milk_glass", "copper_aged",
	"iron_neutral", "monks_cloth", "limewash_plaster"]
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
		elif group == "lm":
			pass  # landmarks keep their detail at every distance
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
	_build_parked()
	_build_signs()
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
	if key == "milk_glass":
		# The bank's four clock dials, lit with the street lamps.
		material.emission_enabled = true
		material.emission = Color(1.0, 0.86, 0.62)
		material.set_meta("lamp_energy", 1.3)
		lamp_materials.append(material)
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


func _build_parked() -> void:
	# Parked period stock, drawn with the street traffic's own meshes and finishes.
	var table := OrisonV2StreetTraffic.load_table()
	if table.is_empty():
		return
	var finishes := {}
	for id: String in table.finishes:
		var material := OrisonV2StreetTraffic.stock_material(table.finishes[id])
		if material.emission_enabled:
			material.emission_energy_multiplier = 0.0  # parked: lamps out, engine off
		finishes[id] = material
	var meshes := OrisonV2StreetTraffic.stock_meshes(str(table.stock), finishes)
	for group: Dictionary in data.vehicles:
		_parked_batch("Parked_", str(group.stock), group["items"], meshes, false)
	for group: Dictionary in data.wheels:
		_parked_batch("ParkedWheels_", str(group.stock), group["items"], meshes, true)


func _parked_batch(prefix: String, stock: String, items: Array, meshes: Dictionary, wheels: bool) -> void:
	# One batch per stock: each of a car's finishes is a draw, so batches are kept few.
	if not meshes.has(stock) or items.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = meshes[stock]
	multimesh.instance_count = items.size()
	for i in items.size():
		var item: Array = items[i]
		var body := Transform3D(Basis(Vector3.UP, float(item[3])), Vector3(item[0], item[1], item[2]))
		if wheels:
			# Unit wheels (radius 0.5) scaled as the moving traffic scales them.
			var s := float(item[7]) / 0.5
			var wheel := Basis.IDENTITY.scaled(Vector3(s, s, s * float(item[8])))
			multimesh.set_instance_transform(i, body * Transform3D(wheel, Vector3(item[4], item[5], item[6])))
			multimesh.set_instance_color(i, Color(1, 1, 1))
		else:
			multimesh.set_instance_transform(i, body)
			multimesh.set_instance_color(i, Color(item[4], item[5], item[6]))
	_add_stock(prefix + stock, multimesh, Vector3.ZERO)


func _add_stock(name: String, multimesh: MultiMesh, at: Vector3) -> void:
	var draw := MultiMeshInstance3D.new()
	draw.name = name
	draw.position = at
	draw.multimesh = multimesh
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	draw.visibility_range_end = NEAR_END
	draw.visibility_range_end_margin = FADE
	draw.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(draw)


const SIGN_FONT := preload("res://assets/fonts/eb_garamond/EBGaramond[wght].ttf")
## Lettering shows only up close; each label is a draw.
const SIGN_RANGE := 45.0


func _build_signs() -> void:
	# 1929 corner signs (Lily's ruling midground_sign_mapping): two dark enamel blades on the
	# post, the new name in white capitals with the old name small beneath, lettered with
	# Label3D on both faces (no lettering in textures, RUL-008).
	var enamel := MatLib.get_mat("enamel").duplicate() as StandardMaterial3D
	enamel.albedo_color = Color(0.07, 0.1, 0.2)
	enamel.uv1_triplanar = false
	for sign: Dictionary in data.signs:
		var at := Vector3(sign.x, sign.y, sign.z)
		# The avenue blade runs along the avenue (x), the street blade along the street (z).
		_sign_blade(at + Vector3(0, 3.22, 0), 0.0, sign.avenue, enamel)
		_sign_blade(at + Vector3(0, 2.92, 0), PI * 0.5, sign.street, enamel)


func _sign_blade(at: Vector3, yaw: float, names: Array, material: Material) -> void:
	var blade := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.95, 0.24, 0.025)
	blade.mesh = box
	blade.material_override = material
	blade.position = at
	blade.rotation.y = yaw
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blade.visibility_range_end = SIGN_RANGE
	add_child(blade)
	for face: float in [0.0, PI]:
		var lines: Array = [[str(names[0]), 0.035, 0.0013, 52], [str(names[1]), -0.07, 0.0008, 40]]
		for line: Array in lines:
			if str(line[0]).is_empty():
				continue
			var label := Label3D.new()
			label.text = str(line[0])
			label.font = SIGN_FONT
			label.font_size = int(line[3])
			label.pixel_size = float(line[2])
			label.modulate = Color(0.96, 0.95, 0.9)
			label.outline_size = 0
			label.double_sided = false
			label.position = Vector3(0, float(line[1]) + (0.03 if str(names[1]).is_empty() else 0.0), 0.014)
			label.visibility_range_end = SIGN_RANGE
			var holder := Node3D.new()
			holder.rotation.y = face
			holder.add_child(label)
			blade.add_child(holder)


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
