extends Node3D
## City greenery: street trees in iron-guarded pits along the kerbs, ailanthus, privet
## and weeds in back yards and vacant lots (art/blender/scripts/build_city_greenery.py).
## Additive: drawn as MultiMeshes by tile, near and distant stock crossing over by
## range, with a trunk collider for each tree the player can reach. No access, route,
## resident, shop, weather or save authority.
##
## The year turns in the leaves: the campaign clock picks the season's colour, and from
## December to March the street trees and the ailanthus stand bare.
const DATA := "res://data/orison_v2/exterior/city_greenery.json"
const SCHEMA := "orison.v2.city-greenery.v1"
## Catalogue keys by the stock's material names (RUL-008, RUL-012).
const FINISHES := ["plant", "wood_dark", "soil", "iron_blackened"]
const TREES := ["plane_a", "plane_b", "ailanthus"]
## Small things, seen only near: weeds and the iron-guarded tree pits.
const SMALL := ["weeds", "pit"]
## Leaf colour by month, multiplied over the catalogued plant finish and the stock's
## crown shading: spring's light green, summer, the plane trees' dull brown and the
## ailanthus' yellow in autumn. A null month is bare.
const SEASONS := {
	"plane": [null, null, null, Color(1.15, 1.25, 0.8), Color(1.08, 1.18, 0.82), Color(1, 1, 1), Color(1, 1, 1),
		Color(0.96, 0.98, 0.9), Color(1.1, 1.0, 0.7), Color(2.0, 1.15, 0.42), Color(1.8, 0.95, 0.4), null],
	"ailanthus": [null, null, null, null, Color(1.15, 1.25, 0.8), Color(1, 1.04, 0.95), Color(1, 1, 1),
		Color(1, 1, 0.92), Color(1.2, 1.12, 0.65), Color(2.2, 1.8, 0.4), Color(1.9, 1.4, 0.45), null],
	"shrub": [Color(0.8, 0.82, 0.7), Color(0.8, 0.82, 0.7), Color(0.88, 0.92, 0.75), Color(1.08, 1.18, 0.85),
		Color(1.05, 1.12, 0.88), Color(1, 1, 1), Color(1, 1, 1), Color(0.98, 0.98, 0.9), Color(1, 0.98, 0.85),
		Color(1.05, 0.95, 0.72), Color(0.95, 0.88, 0.7), Color(0.85, 0.85, 0.72)],
	"weeds": [Color(1.3, 1.0, 0.6), Color(1.3, 1.0, 0.6), Color(1.25, 1.05, 0.65), Color(1.05, 1.2, 0.8),
		Color(1.05, 1.15, 0.85), Color(1, 1, 1), Color(1.05, 1.02, 0.85), Color(1.15, 1.05, 0.7),
		Color(1.25, 1.05, 0.65), Color(1.4, 1.05, 0.6), Color(1.35, 1.0, 0.6), Color(1.3, 1.0, 0.6)],
}
const FoliageShader := preload("res://shaders/v2_city_foliage.gdshader")
## Wind for the leaves, read from the weather: km/h at which a crown bends fully.
const FULL_WIND_KMH := 36.0
const LEAF_GROUP := {"plane_a": "plane", "plane_b": "plane", "ailanthus": "ailanthus", "shrub": "shrub", "weeds": "weeds"}

var data: Dictionary = {}
var tree_draws: Array[MultiMeshInstance3D] = []
var bare_meshes: Dictionary = {}
var leaf_meshes: Dictionary = {}
var leaf_materials: Dictionary = {}
var month := -1
var bare := false
var instance_count := 0
var draw_count := 0
var collider_count := 0
## Tests may pin the month (1-12) instead of reading the campaign.
var month_override := 0
var _clock := CampaignClock.new()
var _elapsed := INF
var _wind_elapsed := INF
var wind_strength := 0.0


static func mount(parent: Node3D) -> Node3D:
	if not FileAccess.file_exists(DATA):
		return null
	var greenery := preload("res://scripts/building/orison_v2_city_greenery.gd").new()
	greenery.name = "CityGreenery"
	parent.add_child(greenery)
	return greenery if not greenery.data.is_empty() else null


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if parsed is not Dictionary or str(parsed.get("schema", "")) != SCHEMA or str(parsed.get("frame", "")) != "WORLD":
		push_error("CITY GREENERY: malformed table")
		return
	var model := (load(str(parsed.stock)) as PackedScene).instantiate() as Node3D
	var stock := {}
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		stock[str(draw.name)] = draw.mesh
	model.free()
	var finishes := {}
	for key: String in FINISHES:
		finishes[key] = _finish(key)
	for kind: String in parsed.stock_names:
		for name: String in parsed.stock_names[kind]:
			if not stock.has(name):
				push_error("CITY GREENERY: stock %s missing" % name)
				return
			if not leaf_meshes.has(name):
				_prepare(name, kind, stock[name], finishes)
	data = parsed
	_build_tiles()
	_build_colliders()
	_refresh(true)


func _finish(key: String) -> StandardMaterial3D:
	var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
	# UV0 is metric in the stock; keep the catalogue's tile scale, no triplanar.
	material.uv1_triplanar = false
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if key == "plant" or key == "wood_dark":
		# Crown and bark shading is in the stock's vertex colour.
		material.vertex_color_use_as_albedo = true
	if key == "plant":
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Leaves: the same catalogued plant maps, scale and response, in the foliage shader so
## they move in the wind (shaders/v2_city_foliage.gdshader).
func _foliage(plant: StandardMaterial3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FoliageShader
	material.set_shader_parameter("albedo_tex", plant.albedo_texture)
	material.set_shader_parameter("rough_tex", plant.roughness_texture)
	material.set_shader_parameter("normal_tex", plant.normal_texture)
	material.set_shader_parameter("uv_scale", Vector2(plant.uv1_scale.x, plant.uv1_scale.y))
	material.set_shader_parameter("roughness_scale", plant.roughness)
	material.set_shader_parameter("normal_scale", plant.normal_scale)
	material.set_meta("v2_surface_stock", "plant")
	return material


## The stock's own mesh with catalogue finishes, and for trees a bare copy (no leaves).
func _prepare(name: String, kind: String, source: Mesh, finishes: Dictionary) -> void:
	var leafy := ArrayMesh.new()
	var bare_mesh := ArrayMesh.new()
	for s in source.get_surface_count():
		var key := str(source.surface_get_material(s).resource_name) if source.surface_get_material(s) else ""
		if not finishes.has(key):
			push_error("CITY GREENERY: %s surface %d has no catalogue finish (%s)" % [name, s, key])
			continue
		var material: Material = finishes[key]
		if key == "plant":
			var group: String = LEAF_GROUP.get(kind, "plane")
			if not leaf_materials.has(group):
				leaf_materials[group] = _foliage(finishes.plant)
			material = leaf_materials[group]
		var arrays := source.surface_get_arrays(s)
		leafy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		leafy.surface_set_material(leafy.get_surface_count() - 1, material)
		if key != "plant":
			bare_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			bare_mesh.surface_set_material(bare_mesh.get_surface_count() - 1, material)
	leaf_meshes[name] = leafy
	bare_meshes[name] = bare_mesh if kind in TREES else leafy


func _build_tiles() -> void:
	var tile := float(data.tile_m)
	var fade := float(data.fade_m)
	for kind: String in data.kinds:
		var items: Array = data.kinds[kind]
		if items.is_empty():
			continue
		var names: Array = data.stock_names[kind]
		var tiles := {}
		for item: Array in items:
			tiles.get_or_add(Vector2i(floori(float(item[0]) / tile), floori(float(item[2]) / tile)), []).append(item)
		for key: Vector2i in tiles:
			var group: Array = tiles[key]
			var centre := Vector3((key.x + 0.5) * tile, 0.0, (key.y + 0.5) * tile)
			var ranges: Array = []
			if kind in TREES:
				ranges = [[names[0], 0.0, float(data.near_end_m), true], [names[1], float(data.far_begin_m), 0.0, false]]
			elif kind in SMALL:
				ranges = [[names[0], 0.0, float(data.small_end_m), false]]
			else:
				ranges = [[names[0], 0.0, 140.0, false]]
			for band: Array in ranges:
				var multimesh := MultiMesh.new()
				multimesh.transform_format = MultiMesh.TRANSFORM_3D
				multimesh.mesh = leaf_meshes[str(band[0])]
				multimesh.instance_count = group.size()
				for i in group.size():
					var item: Array = group[i]
					var basis := Basis(Vector3.UP, float(item[3])).scaled(Vector3.ONE * float(item[4]))
					multimesh.set_instance_transform(i, Transform3D(basis, Vector3(item[0], item[1], item[2]) - centre))
				var draw := MultiMeshInstance3D.new()
				draw.name = "%s_%d_%d_%s" % [kind, key.x, key.y, str(band[0])]
				draw.multimesh = multimesh
				draw.position = centre
				draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(band[3]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				draw.visibility_range_begin = float(band[1])
				draw.visibility_range_begin_margin = fade if float(band[1]) > 0.0 else 0.0
				draw.visibility_range_end = float(band[2])
				draw.visibility_range_end_margin = fade if float(band[2]) > 0.0 else 0.0
				draw.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				draw.set_meta("v2_city_greenery", kind)
				draw.set_meta("v2_greenery_stock", str(band[0]))
				add_child(draw)
				draw_count += 1
				if kind in TREES:
					tree_draws.append(draw)
			instance_count += group.size()


func _build_colliders() -> void:
	var body := StaticBody3D.new()
	body.name = "GreeneryCollision"
	add_child(body)
	for record: Array in data.colliders:
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = float(record[3])
		cylinder.height = float(record[4])
		shape.shape = cylinder
		shape.position = Vector3(record[0], float(record[1]) + float(record[4]) * 0.5, record[2])
		body.add_child(shape)
		collider_count += 1


## The calendar month, 1-12, of the campaign day.
func campaign_month() -> int:
	if month_override >= 1 and month_override <= 12:
		return month_override
	if not _clock.bind_state():
		return 7
	var day := floori(_clock.calendar_minutes() / CampaignClock.MINUTES_PER_DAY)
	for year: int in [1930, 1929, 1928]:
		for m in range(12, 0, -1):
			if day >= floori(CampaignClock.calendar_minute_of(year, m, 1, 0.0) / CampaignClock.MINUTES_PER_DAY):
				return m
	return 7


func _refresh(force := false) -> void:
	var now := campaign_month()
	if now == month and not force:
		return
	month = now
	for group: String in leaf_materials:
		var tone: Variant = (SEASONS[group] as Array)[month - 1]
		var tint: Color = tone if tone is Color else Color.WHITE
		(leaf_materials[group] as ShaderMaterial).set_shader_parameter("season_tint", tint)
	for draw in tree_draws:
		var stock_name := str(draw.get_meta("v2_greenery_stock"))
		var group: String = LEAF_GROUP.get(str(draw.get_meta("v2_city_greenery")), "plane")
		var leafless: bool = (SEASONS[group] as Array)[month - 1] == null
		draw.multimesh.mesh = bare_meshes[stock_name] if leafless else leaf_meshes[stock_name]
	bare = (SEASONS.plane as Array)[month - 1] == null


## The weather's wind in the leaves: speed sets the bend, gusts its unrest, the bearing
## which way the crowns lean (as the weather manager reads it).
func set_wind(weather: Dictionary) -> void:
	var speed := float(weather.get("wind_speed_kmh", 10.0))
	var gusts := float(weather.get("wind_gusts_kmh", speed))
	var bearing := deg_to_rad(float(weather.get("wind_direction_degrees", 285.0)))
	wind_strength = clampf(speed / FULL_WIND_KMH, 0.05, 1.4)
	var unrest := clampf((gusts - speed) / maxf(speed, 1.0), 0.0, 1.0)
	for group: String in leaf_materials:
		var material: ShaderMaterial = leaf_materials[group]
		material.set_shader_parameter("wind_direction", Vector2(-sin(bearing), cos(bearing)))
		material.set_shader_parameter("wind_strength", wind_strength)
		material.set_shader_parameter("gust", unrest)


func _process(delta: float) -> void:
	_elapsed += delta
	_wind_elapsed += delta
	if _wind_elapsed >= 5.0:
		_wind_elapsed = 0.0
		var world := get_parent() as OrisonV2RuntimeRoot
		if world != null:
			var weather := world.weather_conditions()
			if not weather.is_empty():
				set_wind(weather)
	if _elapsed < 30.0:
		return
	_elapsed = 0.0
	_refresh()
