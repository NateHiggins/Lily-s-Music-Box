extends RefCounted
## Dossier slice 52: positional wear, the inherited layer only. Soft projected decals: a
## grout-and-water ring round each bath's shower receptor and the mop-shadow corner; in the
## halls the dulled walking line, foot scuffs at each apartment door, the mop-shadow corner
## and the trolley rub at 0.6 m near the core. No collision, no owner, no lettering.
## Dossier slice 60 adds the basement: coal dust down the boiler approach and on the
## lowest service treads, a door leaf's sweep, the chute's dust fan and a chalked log.
## Slice 61: the water line under each shower curtain's hem and the 5D fire's soot ghost.
const DATA := "res://data/orison_v2/positional_wear.json"
const ROOT := "res://assets/building/textures/wear_decals/"
const KINDS := ["receptor", "corner", "path", "threshold", "trolley", "coal", "arc", "fan", "chalk", "waterline", "soot", "drip", "scuff"]

static func mount(blockout: Node3D) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if parsed is not Dictionary or parsed.get("schema_version") != 1 or parsed.get("decals") is not Array:
		push_error("positional wear data malformed")
		return false
	var levels: Dictionary = {}
	for level: Dictionary in blockout.layout.levels: levels[str(level.id)] = float(level.y)
	var textures: Dictionary = {}
	for key: String in parsed.get("textures", []):
		var texture := load(ROOT + key + ".png") as Texture2D
		if texture == null:
			push_error("positional wear texture missing: " + key)
			return false
		textures[key] = texture
	# Refuse a bad row before anything is added, so a refusal never leaves a
	# partial set of decals in the world.
	for row: Dictionary in parsed.decals:
		if str(row.kind) not in KINDS or not textures.has(str(row.texture)) or not levels.has(str(row.level)):
			push_error("positional wear row refused: " + str(row.get("id", "")))
			return false
	var parent := Node3D.new()
	parent.name = "PositionalWear"
	blockout.add_child(parent)
	for row: Dictionary in parsed.decals:
		var decal := Decal.new()
		decal.name = str(row.id)
		decal.set_meta("wear_kind", str(row.kind))
		decal.set_meta("room_id", str(row.space))
		decal.texture_albedo = textures[str(row.texture)]
		decal.modulate = Color(1, 1, 1, float(row.opacity))
		decal.albedo_mix = 1.0
		decal.upper_fade = float(row.get("fade", 0.15))
		decal.lower_fade = float(row.get("fade", 0.15))
		# A tall box over stepped treads keeps the texture off the risers.
		decal.normal_fade = float(row.get("normal_fade", 0.0))
		decal.distance_fade_enabled = true
		decal.distance_fade_begin = 14.0
		decal.distance_fade_length = 4.0
		var size: Array = row.size
		var into := Vector3(float(row.into[0]), float(row.into[1]), float(row.into[2]))
		var at := Vector3(float(row.position[0]), levels[str(row.level)] + float(row.position[1]), float(row.position[2]))
		if into.is_equal_approx(Vector3.DOWN):
			# Floor: the box straddles the floor plane, thin enough to spare what stands on it.
			decal.size = Vector3(float(size[0]), float(row.get("height", 0.08)), float(size[1]))
			decal.position = at + Vector3(0, 0.01, 0)
			decal.rotation.y = float(row.yaw)
		else:
			# Wall: project along `into`, texture v running down the wall.
			decal.size = Vector3(float(size[0]), 0.06, float(size[1]))
			var y_axis := -into.normalized()
			var z_axis := Vector3.DOWN
			decal.basis = Basis(y_axis.cross(z_axis), y_axis, z_axis)
			decal.position = at
		parent.add_child(decal)
	parent.set_meta("decal_count", parsed.decals.size())
	return true
