extends MultiMeshInstance3D
## Ambient trains on the two existing tracks east of Queensboro Plaza.

const ALIGNMENT := "res://data/orison_v2/exterior/queensboro_el_alignment.json"
const CARS_PER_TRAIN := 6
const CAR_PITCH_M := 15.2
const TRUCK_HALF_SPAN_M := 5.0
const HALF_BODY_M := 7.36
const SPEED_MPS := 7.0
const SERVICE_INTERVAL_S := 66.0
const INBOUND_PHASE_S := 27.0
const STATION_START_M := -30.0
const STATION_FADE_END_M := -17.0
const FAR_FADE_M := 24.0
const PAINT := Color(0.32, 0.36, 0.30)

var _station_x: float
var _center_z: float
var _turn_x: float
var _radius: float
var _far_z: float
var _rail_top: float
var _track_offset: float
var _straight_m: float
var _arc_lengths: Array[float] = []
var _windows: StandardMaterial3D
var _elapsed := 22.0


func _ready() -> void:
	var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string(ALIGNMENT))
	if not layout is Dictionary:
		push_error("Queensboro elevated alignment did not load")
		set_process(false)
		return
	_station_x = float(layout.station_end_x)
	_center_z = float(layout.centerline_z)
	_turn_x = float(layout.cross_street_x)
	_radius = float(layout.curve_radius)
	_far_z = float(layout.far_end_z)
	_rail_top = float(layout.rail_top)
	_track_offset = float(layout.track_offset)
	_straight_m = _turn_x - _radius - _station_x
	_arc_lengths = [(_radius + _track_offset) * PI / 2.0, (_radius - _track_offset) * PI / 2.0]
	var mesh := _load_stock()
	if mesh == null or _windows == null:
		push_error("Queensboro elevated car or window finish did not load")
		set_process(false)
		return
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = CARS_PER_TRAIN * 2
	var minimum := Vector3(_station_x + STATION_START_M - HALF_BODY_M, _rail_top, _center_z - _track_offset - 3.0)
	var maximum := Vector3(_turn_x + _track_offset + 3.0, _rail_top + 4.0, _far_z + HALF_BODY_M)
	multimesh.custom_aabb = AABB(minimum, maximum - minimum)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_update_cars()


func _load_stock() -> Mesh:
	var table := OrisonV2StreetTrams.load_table()
	var materials := {}
	for finish: Dictionary in table.get("finishes", []):
		var material := OrisonV2StreetTraffic.stock_material(finish)
		if bool(finish.get("paint", false)):
			material.albedo_color *= PAINT.srgb_to_linear()
		# Instance alpha lets each car disappear into the station or mist while
		# retaining its mapped finish and depth until the last visible pixels.
		material.vertex_color_use_as_albedo = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
		materials[str(finish.id)] = material
	_windows = materials.get("window") as StandardMaterial3D
	return OrisonV2StreetTraffic.stock_meshes(str(table.get("stock", "")), materials).get("el_car") as Mesh


func set_darkness_from_minute(minute_of_day: float) -> void:
	if _windows == null:
		return
	var hour := minute_of_day / 60.0
	var daylight := smoothstep(6.0, 7.5, hour) * (1.0 - smoothstep(16.8, 18.3, hour))
	_windows.emission_energy_multiplier = float(_windows.get_meta("lamp_energy", 1.0)) * lerpf(1.0, 0.08, daylight)


func _process(delta: float) -> void:
	_elapsed = fposmod(_elapsed + delta, SERVICE_INTERVAL_S)
	_update_cars()


func _track_end(lane: int) -> float:
	return _straight_m + _arc_lengths[lane] + _far_z - _center_z - _radius


func _track_point(distance: float, lane: int) -> Vector3:
	var offset := -_track_offset if lane == 0 else _track_offset
	if distance <= _straight_m:
		return Vector3(_station_x + distance, _rail_top, _center_z + offset)
	var curve_end := _straight_m + _arc_lengths[lane]
	if distance >= curve_end:
		return Vector3(_turn_x - offset, _rail_top, _center_z + _radius + distance - curve_end)
	var radius := _radius - offset
	var theta := (distance - _straight_m) / radius
	return Vector3(_turn_x - _radius + radius * sin(theta), _rail_top, _center_z + _radius - radius * cos(theta))


func _update_cars() -> void:
	var slot := 0
	for lane in 2:
		var direction := 1.0 if lane == 0 else -1.0
		var route_end := _track_end(lane)
		var travel := fposmod(_elapsed + (0.0 if lane == 0 else INBOUND_PHASE_S), SERVICE_INTERVAL_S) * SPEED_MPS
		var head := (STATION_START_M if lane == 0 else route_end) + direction * travel
		for car in CARS_PER_TRAIN:
			var distance := head - direction * CAR_PITCH_M * car
			var opacity := smoothstep(STATION_START_M, STATION_FADE_END_M, distance) \
				* (1.0 - smoothstep(route_end - FAR_FADE_M, route_end, distance))
			if opacity <= 0.0:
				continue
			# Orient each car from its truck centres. The platform and rails use
			# the same alignment and each curve has its own travel length.
			var leading := _track_point(distance + direction * TRUCK_HALF_SPAN_M, lane)
			var trailing := _track_point(distance - direction * TRUCK_HALF_SPAN_M, lane)
			var forward := (leading - trailing).normalized()
			multimesh.set_instance_transform(slot, Transform3D(
				Basis(forward, Vector3.UP, forward.cross(Vector3.UP)), (leading + trailing) * 0.5))
			multimesh.set_instance_color(slot, Color(1.0, 1.0, 1.0, opacity))
			slot += 1
	multimesh.visible_instance_count = slot
