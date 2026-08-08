class_name SwcGraybox
extends RefCounted

## The graybox: what the level looks like with no World Package loaded at all.
##
## Two jobs, and the second is the important one:
##
## 1. Be deliberately readable. Flat colour per semantic type, no texture, no
##    ornament, so the mechanical shape of the level is the only thing on screen.
## 2. Be the shape a material-only skin reuses. An entity whose freedom is
##    MATERIAL_ONLY gets these exact primitives with the World Bible's material
##    on them, which is why the shapes live here rather than inside the builder.
##
## Every primitive is derived from the semantic scene - bounds, clearance,
## collision, gameplay params - never from a package.

const _TYPE_COLORS := {
	"wall": Color(0.58, 0.58, 0.60),
	"floor": Color(0.36, 0.37, 0.40),
	"ceiling": Color(0.30, 0.30, 0.33),
	"stairs": Color(0.86, 0.76, 0.32),
	"ramp": Color(0.80, 0.72, 0.34),
	"door": Color(0.92, 0.52, 0.18),
	"door_frame": Color(0.72, 0.44, 0.22),
	"window": Color(0.44, 0.70, 0.82),
	"column": Color(0.66, 0.64, 0.60),
	"railing": Color(0.74, 0.70, 0.44),
	"catwalk": Color(0.56, 0.54, 0.46),
	"crate": Color(0.62, 0.45, 0.27),
	"barrel": Color(0.48, 0.42, 0.30),
	"chair": Color(0.52, 0.40, 0.34),
	"table": Color(0.54, 0.42, 0.34),
	"terminal": Color(0.32, 0.52, 0.66),
	"lamp": Color(0.96, 0.94, 0.80),
	"machinery": Color(0.40, 0.46, 0.54),
	"decoration": Color(0.60, 0.44, 0.64),
	"vegetation": Color(0.36, 0.58, 0.36),
	"sign": Color(0.82, 0.82, 0.70),
	"pickup": Color(0.32, 0.86, 0.44),
	"weapon": Color(0.86, 0.82, 0.30),
	"objective": Color(0.90, 0.28, 0.72),
	"enemy_spawn": Color(0.90, 0.24, 0.24),
	"player_spawn": Color(0.24, 0.62, 0.92),
	"trigger_volume": Color(0.90, 0.60, 0.20),
	"ambience_zone": Color(0.50, 0.50, 0.62),
	"nav_hint": Color(0.70, 0.70, 0.40),
}

## Types drawn as translucent volumes rather than solids: they are gameplay
## regions, not objects, and hiding the level behind them would defeat the point.
const _VOLUME_TYPES := ["trigger_volume", "ambience_zone", "player_spawn", "enemy_spawn"]

static var _material_cache: Dictionary = {}


static func color_for(type_name: String) -> Color:
	return _TYPE_COLORS.get(type_name, Color(0.7, 0.7, 0.7))


static func material_for(type_name: String) -> StandardMaterial3D:
	if _material_cache.has(type_name):
		return _material_cache[type_name]

	var material := StandardMaterial3D.new()
	material.resource_name = "graybox_%s" % type_name
	material.albedo_color = color_for(type_name)
	material.roughness = 0.85
	material.metallic = 0.0

	if type_name in _VOLUME_TYPES:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.16
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elif type_name == "lamp":
		material.emission_enabled = true
		material.emission = color_for(type_name)
		material.emission_energy_multiplier = 1.4

	_material_cache[type_name] = material
	return material


## Primitive list for one entity, in entity-local space.
## Each entry: {shape: "box"|"cylinder", size: Vector3, offset: Vector3, radius, height}
static func primitives(entity: Dictionary) -> Array[Dictionary]:
	var type_name := String(entity.get("type", ""))
	var size := SwcScene.size_of(entity)
	var offset := SwcScene.bounds_offset_of(entity)

	match type_name:
		"stairs":
			return _stairs(entity, size, offset)
		"door_frame":
			return _frame(entity, size, offset, false)
		"window":
			return _frame(entity, size, offset, true)
		"column":
			return [
				{
					"shape": "cylinder",
					"radius": min(size.x, size.z) * 0.5,
					"height": size.y,
					"offset": offset,
				}
			]
		"lamp":
			return [
				{"shape": "box", "size": size, "offset": offset},
				{
					"shape": "box",
					"size": Vector3(size.x * 0.55, size.y * 0.25, size.z * 0.6),
					"offset": offset + Vector3(0.0, -size.y * 0.34, size.z * 0.28),
					"emissive": true,
				},
			]
		"railing":
			# Two rails and end posts: a solid box would read as a wall, and the
			# graybox has to communicate that a player can shoot over it.
			var rail: float = minf(0.08, size.z)
			return [
				{"shape": "box", "size": Vector3(size.x, rail, rail), "offset": offset + Vector3(0, size.y * 0.48, 0)},
				{"shape": "box", "size": Vector3(size.x, rail, rail), "offset": offset + Vector3(0, 0.0, 0)},
				{"shape": "box", "size": Vector3(rail, size.y, rail), "offset": offset + Vector3(-size.x * 0.5 + rail * 0.5, 0, 0)},
				{"shape": "box", "size": Vector3(rail, size.y, rail), "offset": offset + Vector3(size.x * 0.5 - rail * 0.5, 0, 0)},
			]
		_:
			return [{"shape": "box", "size": size, "offset": offset}]


static func _stairs(entity: Dictionary, size: Vector3, offset: Vector3) -> Array[Dictionary]:
	var params := SwcScene.params_of(entity)
	var steps := int(params.get("step_count", 0))
	var rise := float(params.get("step_rise", 0.0))
	var run := float(params.get("step_run", 0.0))
	var width := float(params.get("flight_width", size.x))
	if steps <= 0 or rise <= 0.0 or run <= 0.0:
		return [{"shape": "box", "size": size, "offset": offset}]

	var out: Array[Dictionary] = []
	var base_y := offset.y - size.y * 0.5
	var base_z := offset.z - size.z * 0.5
	for step in range(1, steps + 1):
		var height := step * rise
		out.append(
			{
				"shape": "box",
				"size": Vector3(width, height, run),
				"offset": Vector3(offset.x, base_y + height * 0.5, base_z + (step - 0.5) * run),
			}
		)
	return out


static func _frame(
	entity: Dictionary, size: Vector3, offset: Vector3, with_glass: bool
) -> Array[Dictionary]:
	var clearance := SwcScene.clearance_of(entity)
	if clearance.is_empty():
		return [{"shape": "box", "size": size, "offset": offset}]

	var aperture_w := float(clearance.get("width", size.x * 0.5))
	var aperture_h := float(clearance.get("height", size.y * 0.5))
	var raw_offset: Array = clearance.get("offset", [0, 0, 0])
	var aperture_centre := Vector3(raw_offset[0], raw_offset[1], raw_offset[2])

	var outer_x0 := offset.x - size.x * 0.5
	var outer_x1 := offset.x + size.x * 0.5
	var outer_y0 := offset.y - size.y * 0.5
	var outer_y1 := offset.y + size.y * 0.5
	var ax0 := aperture_centre.x - aperture_w * 0.5
	var ax1 := aperture_centre.x + aperture_w * 0.5
	var ay0 := aperture_centre.y - aperture_h * 0.5
	var ay1 := aperture_centre.y + aperture_h * 0.5

	var out: Array[Dictionary] = []

	var add_slab := func(x0: float, x1: float, y0: float, y1: float) -> void:
		if x1 - x0 <= 0.001 or y1 - y0 <= 0.001:
			return
		out.append(
			{
				"shape": "box",
				"size": Vector3(x1 - x0, y1 - y0, size.z),
				"offset": Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, offset.z),
			}
		)

	add_slab.call(outer_x0, ax0, outer_y0, outer_y1)
	add_slab.call(ax1, outer_x1, outer_y0, outer_y1)
	add_slab.call(ax0, ax1, ay1, outer_y1)
	add_slab.call(ax0, ax1, outer_y0, ay0)

	if with_glass:
		out.append(
			{
				"shape": "box",
				"size": Vector3(aperture_w, aperture_h, size.z * 0.1),
				"offset": Vector3(aperture_centre.x, aperture_centre.y, offset.z),
				"glass": true,
			}
		)
	return out


static func build_mesh_instances(
	entity: Dictionary, material_override: Material = null
) -> Array[MeshInstance3D]:
	var type_name := String(entity.get("type", ""))
	var base_material := material_override if material_override != null else material_for(type_name)
	var instances: Array[MeshInstance3D] = []

	for primitive in primitives(entity):
		var instance := MeshInstance3D.new()
		if String(primitive.get("shape", "box")) == "cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = float(primitive["radius"])
			cylinder.bottom_radius = float(primitive["radius"])
			cylinder.height = float(primitive["height"])
			cylinder.radial_segments = 12
			instance.mesh = cylinder
		else:
			var box := BoxMesh.new()
			box.size = primitive["size"]
			instance.mesh = box
		instance.position = primitive.get("offset", Vector3.ZERO)

		var material := base_material
		if bool(primitive.get("glass", false)):
			material = _glass_variant(base_material)
		elif bool(primitive.get("emissive", false)) and material_override == null:
			material = material_for("lamp")
		instance.material_override = material

		if type_name in _VOLUME_TYPES:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instances.append(instance)

	return instances


static func _glass_variant(source: Material) -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.78, 0.86, 0.28)
	if source is StandardMaterial3D:
		glass.albedo_color = (source as StandardMaterial3D).albedo_color
		glass.albedo_color.a = 0.28
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	glass.metallic = 0.0
	return glass
