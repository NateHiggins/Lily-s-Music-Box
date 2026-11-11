extends "res://scripts/building/period_reality_layer.gd"
## The airmail aircraft over V2 (Lily, v1r_period_layer_20261109: "the
## aircraft only; V2's city, trams and el cover the rest").
##
## V1's PeriodRealityLayer keeps its authority here: one Pitcairn Mailwing on
## the New York-Atlanta mail (CAM 19), a pass every 7 to 13 minutes from V1's
## own seeded draw, 18 seconds a pass, V1's arc, crosswind drift and gust, the
## rule that no pass is staged under weather that hides it, the weather's
## muffling of the engine, and V1's synthesized nine-cylinder radial. This
## script replaces what is seen and where it flies:
##
##  - The aircraft is Blender stock (art/blender/scripts/build_airmail_biplane.py)
##    at its true size, in catalogue finishes, with the propeller disc turning
##    on its shaft.
##  - V1 flew a compressed 4.5 m read 250 m across its own block. V2's city is
##    walkable for 200 m, so the track is V1's, enlarged about the house until
##    the aircraft is high over the roofs and well outside anything walked:
##    the same heading, the same 18 seconds, now at a Mailwing's real pace.
##    V1's arc, wobble and audio reach are enlarged by the same factor.
##  - V1's distant Flushing-line train is not carried: V2 has its own el.
const DATA := "res://data/orison_v2/airmail_aircraft.json"
const SELF := "res://scripts/building/orison_v2_aircraft.gd"
## The length of V1's authored track, (-92, 51, -76) to (98, 58, 82).
const V1_TRACK := 247.2
const WEATHER_SECONDS := 5.0

var errors: Array[String] = []
var propeller: MeshInstance3D
var parts: Array[MeshInstance3D] = []
## The track in the world, and how much larger it is than V1's.
var track_start := Vector3.ZERO
var track_finish := Vector3.ZERO
var enlargement := 1.0
## Tests may hold the weather still instead of following the atmosphere.
var follow_weather := true

var _world: Node
var _stock: Array[Dictionary] = []
var _reach := 260.0
var _turns := 0.0
var _weather_wait := 0.0


static func mount(root: Node3D, blockout: Node3D, _layout: Dictionary, _adapter: Variant) -> Node:
	var node: Node3D = load(SELF).new()
	node.name = "PeriodAircraft"
	node.prepare(root, blockout)
	root.add_child(node)
	return node


## Reads the stock and the track before V1's _ready builds the aircraft.
func prepare(root: Node3D, blockout: Node3D) -> void:
	_world = root
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not (data is Dictionary) or int(data.schema_version) != 1:
		errors.append("aircraft data missing")
		return
	var packed := load(str(data.asset)) as PackedScene
	if packed == null:
		errors.append("aircraft stock missing")
		return
	var model := packed.instantiate()
	for row: Dictionary in data.parts:
		var draw := model.find_child(str(row.mesh), true, false) as MeshInstance3D
		var finish := _finish(str(row.material), Color.from_string(str(row.tint), Color.WHITE), float(row.alpha))
		if draw == null or draw.mesh == null or finish == null:
			errors.append("aircraft part missing: " + str(row.id))
			continue
		_stock.append({"id": str(row.id), "mesh": draw.mesh, "finish": finish, "pose": draw.transform})
	model.free()
	var start: Array = data.track_start
	var finish_at: Array = data.track_finish
	track_start = blockout.to_global(Vector3(start[0], start[1], start[2]))
	track_finish = blockout.to_global(Vector3(finish_at[0], finish_at[1], finish_at[2]))
	enlargement = track_start.distance_to(track_finish) / V1_TRACK
	_reach = float(data.visibility_range_m)
	_turns = float(data.propeller_turns_per_second)


func _finish(key: String, tint: Color, alpha: float) -> StandardMaterial3D:
	if not MatLib.SETS.has(key):
		errors.append("unregistered aircraft finish: " + key)
		return null
	var mat := MatLib.get_mat(key).duplicate() as StandardMaterial3D
	mat.uv1_triplanar = false
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	if alpha < 1.0:
		# The turning propeller: seen through, from either side.
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _build_aircraft() -> void:
	_aircraft = MeshInstance3D.new()
	_aircraft.name = "CAM19Mailwing"
	_aircraft.visible = false
	add_child(_aircraft)
	for part: Dictionary in _stock:
		var draw := _aircraft
		if str(part.id) != "fuselage":
			draw = MeshInstance3D.new()
			draw.name = str(part.id).capitalize()
			_aircraft.add_child(draw)
			draw.transform = part.pose
		draw.mesh = part.mesh
		draw.material_override = part.finish
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.visibility_range_end = _reach
		parts.append(draw)
		if str(part.id) == "propeller":
			propeller = draw
	if parts.size() != 4 or propeller == null:
		errors.append("the aircraft is not whole")


## V1's radial alone, heard as far as the enlarged track needs.
func _build_audio() -> void:
	_air_audio = AudioStreamPlayer3D.new()
	_air_audio.bus = "World"
	_air_audio.name = "DistantRadialEngine"
	_air_audio.stream = _synthesize_loop(2.0, true)
	_air_audio.volume_db = -18.0
	_air_audio.max_distance = 210.0 * enlargement
	_air_audio.unit_size = 32.0 * enlargement
	add_child(_air_audio)


func _process(delta: float) -> void:
	if follow_weather and _world != null:
		_weather_wait -= delta
		if _weather_wait <= 0.0:
			_weather_wait = WEATHER_SECONDS
			var conditions: Dictionary = _world.call("weather_conditions") if _world.has_method("weather_conditions") else {}
			if not conditions.is_empty():
				set_live_conditions(conditions)
	if _air_elapsed >= 0.0:
		_air_elapsed += delta
		if propeller != null:
			propeller.rotate_object_local(Vector3.BACK, TAU * _turns * delta)
		_update_aircraft()
	else:
		_until_aircraft -= delta
		if _until_aircraft <= 0.0:
			start_airmail_pass()


func trigger_train_pass() -> bool:
	return false


func set_live_conditions(conditions: Dictionary) -> void:
	super.set_live_conditions(conditions)
	for draw in parts:
		draw.transparency = 1.0 - _aircraft_contrast


## V1's pass, on the enlarged track.
func _update_aircraft() -> void:
	var t := clampf(_air_elapsed / AIR_DURATION, 0.0, 1.0)
	var direction := (track_finish - track_start).normalized()
	var at := track_start.lerp(track_finish, t)
	at += _wind_mps * (sin(t * PI) * 0.42) * enlargement
	at.y += (sin(t * PI) * 5.0 + sin(t * TAU * 3.0) * 0.18) * enlargement
	at.y += sin(t * TAU * 5.0) * _wind_mps.length() * 0.012 * enlargement
	_aircraft.global_position = at
	_aircraft.look_at(at + direction, Vector3.UP)
	_air_audio.global_position = at
	if t >= 1.0:
		_air_elapsed = -1.0
		_aircraft.visible = false
		_air_audio.stop()
		_until_aircraft = _rng.randf_range(AIR_PASS_MIN, AIR_PASS_MAX)


func seconds_until_pass() -> float:
	return _until_aircraft


func pass_progress() -> float:
	return -1.0 if _air_elapsed < 0.0 else clampf(_air_elapsed / AIR_DURATION, 0.0, 1.0)


func diagnostic_snapshot() -> Dictionary:
	return {
		"aircraft_visible": _aircraft != null and _aircraft.visible,
		"aircraft_draws": parts.size(),
		"aircraft_collision_bodies": find_children("*", "CollisionObject3D", true, false).size(),
		"aircraft_shadow": _aircraft.cast_shadow if _aircraft else -1,
		"audio_streams": 1,
		"persistent": false,
		"aircraft_contrast": _aircraft_contrast,
		"wind_mps": _wind_mps,
		"air_filter_hz": _air_audio.attenuation_filter_cutoff_hz,
	}
