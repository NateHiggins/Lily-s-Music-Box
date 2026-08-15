class_name StreetTraffic
extends Node3D
## The stream you cross. See design/ORISON_STREET_BRIEF.md §2-§3.
##
## ONE BATCHED STREAM. Street elevation remains over the 16.6 target and is
## CPU-bound on submission rather than on the GPU (TASKS P2), so every visual
## layer is one MultiMesh shared by every vehicle. A dray and a coal lorry are
## the same box at different sizes, which at night on a wet road is also true.
##
## THE CROSSING IS A TEXTURE, NOT A CHALLENGE. This is the constraint that
## decides everything else here:
##
##   * no death, no damage, no failure - a hit is a horn, a shove and four
##     seconds of lost dignity
##   * no UI, ever
##   * no dedicated crossing point; cross anywhere, the kerb is not a gate
##   * a gap is ALWAYS coming. `MAX_WAIT` is a promise, not a tendency
##
## A player who never learns to read it still gets across. They just get shoved
## more, which is a story about them rather than a punishment.

## The carriageway, from the layout: walks end at y -14.6, the south kerb sits
## near -24. Driving on the right, so westbound keeps the north half.
const LANE_WEST := -17.0
const LANE_EAST := -21.8
const SPAWN_X := 52.0
## Slow. Slow traffic is more readable, more crossable, more 1928 and cheaper.
const SPEED_MIN := 4.2
const SPEED_MAX := 7.6
## Nobody waits longer than this for a gap. Enforced, not hoped for.
const MAX_WAIT := 8.0
## A gap a person can walk through without hurrying.
const GAP_SECONDS := 3.4
const MAX_VEHICLES := 14
## T5's south-pavement shelter spans x -12.6..-8.2. Eastbound trams stop
## with their centre aligned to it, wait long enough for one unhurried boarding
## beat, then continue into the east storm mouth. The shelter is therefore a
## transit place rather than scenery that lies about a service.
const TRANSIT_STOP_ID := "south_shelter"
const TRANSIT_STOP_X := -10.4
const TRANSIT_STOP_DWELL := 4.5
## T6's one-shot arrival uses the ordinary traffic batches, but starts tucked
## against the south kerb. It idles just long enough to make the already-exited
## player and the car read as one event, then merges into the eastbound lane and
## is swallowed shortly beyond the authored storm boundary.
const ARRIVAL_START_X := -4.50
const ARRIVAL_KERB_Y := -22.55
const ARRIVAL_HOLD_SECONDS := 1.15
const ARRIVAL_CRUISE_SPEED := 6.40
const ARRIVAL_ACCELERATION := 3.80
const ARRIVAL_MERGE_RATE := 0.72
const EAST_TEAR_X := 20.60
const ARRIVAL_DESPAWN_X := 27.0
const ARRIVAL_TRAFFIC_DELAY := 5.0
const PIANO_REPAIR_KIND := 8
const PIANO_REPAIR_SIGN := \
		"res://assets/building/textures/traffic/we_tuna_pianos_sign.png"
## A reflected beam painted onto the wet carriageway, not illumination. The
## whole stream shares one shadowless batch; this is T2d's readability spend.
const HEADLIGHT_POOL_LENGTH := 5.2
const HEADLIGHT_POOL_WIDTH := 1.55
const HEADLIGHT_POOL_ALPHA := 0.13

signal transit_arrived(stop_id: String, vehicle_kind: String)
signal arrival_entered_weather
signal arrival_departed

## 95% credible 1928, 5% wrong and never acknowledged. Absurd traffic is
## charming for ten seconds and then it is a joke that keeps talking, and the
## haunting has to compete with it - so the wrong ones are quiet wrong. The
## same dray passing a third time beats a herd of geese and costs nothing.
const KINDS := [
	# name, length, width, height, weight, tint, cab
	#
	# `cab` is what turns a crate into a vehicle: the fraction of the length
	# taken by a raised body, and how much taller it sits. A dray is a low bed
	# with a high driver's box at the front; a motor car is one continuous
	# shape with a slightly raised greenhouse; a tram is all cab. Zero means the
	# thing genuinely is a box, which is only true of the one that is wrong.
	# Tints lifted hard from the first pass, which ran 0.045-0.18 and put pure
	# black rectangles on a dark street - a vehicle you cannot see is not
	# atmosphere, it is a missing texture. Painted coachwork under a sodium
	# lamp still returns light, and the shape has to be legible before it can
	# be threatening.
	["dray", 4.2, 1.9, 2.3, 22.0, Color(0.34, 0.26, 0.18), 0.34, 0.55],
	["motor_car", 4.1, 1.7, 1.5, 20.0, Color(0.20, 0.21, 0.24), 0.46, 0.34],
	["coal_lorry", 6.0, 2.2, 2.6, 14.0, Color(0.26, 0.23, 0.19), 0.30, 0.42],
	["delivery_van", 4.8, 1.9, 2.2, 13.0, Color(0.30, 0.28, 0.26), 0.62, 0.30],
	["hansom", 3.2, 1.6, 2.1, 9.0, Color(0.17, 0.16, 0.18), 0.55, 0.40],
	["milk_float", 3.6, 1.7, 2.0, 8.0, Color(0.52, 0.50, 0.47), 0.40, 0.34],
	["tram", 9.4, 2.5, 3.1, 5.0, Color(0.36, 0.27, 0.16), 0.90, 0.16],
	["hearse", 5.2, 1.9, 2.3, 3.0, Color(0.13, 0.125, 0.135), 0.70, 0.26],
	# A real trade truck with an unreasonable sign. Nothing comments.
	["piano_repair", 5.8, 2.05, 2.30, 2.0,
			Color(0.12, 0.29, 0.30), 0.28, 0.38],
	# The wrong 5%. Never remarked on by anyone, ever.
	["too_long", 13.5, 2.3, 2.6, 1.6, Color(0.22, 0.21, 0.20), 0.22, 0.30],
	["riderless", 4.2, 1.9, 2.3, 1.4, Color(0.33, 0.26, 0.19), 0.34, 0.55],
]

var _mm: MultiMeshInstance3D
## Lamps, as an emissive MultiMesh rather than as lights. Two per vehicle,
## front and rear. Real headlamps would be the single most expensive thing on
## this street - illumination is already the dominant term out here at -33%,
## twice the atrium's - and at these distances an emissive quad reads exactly
## the same. It is also what makes a black mass become a lorry.
var _lamps: MultiMeshInstance3D
## Cabs and wheels, each their own MultiMesh. Four baseline draw calls carry
## every vehicle on the street. The piano repair truck adds one sign-panel batch
## only while one is present; it does not turn into a per-vehicle scene.
var _cabs: MultiMeshInstance3D
var _wheels: MultiMeshInstance3D
var _piano_signs: MultiMeshInstance3D
var _piano_sign_origins: Array[Vector3] = []
var _headlight_pools: MultiMeshInstance3D
var _headlight_pool_origins: Array[Vector3] = []
var _live: Array[Dictionary] = []
var _spawn_accum := 0.0
var _rng := RandomNumberGenerator.new()
var _player: Node3D
var _shove_cooldown := 0.0
var _total_weight := 0.0
var _arrival_started := false
var _arrival_finished := false
## A small pool of voices, reassigned to whichever vehicles are nearest. The
## brief's acceptance test is that a player can cross BY EAR with the camera
## facing a door, and fourteen players would be fourteen voices competing on
## the worst-performing station in the game. Five is enough: past the nearest
## few, traffic is a texture rather than a thing you are timing.
const VOICES := 5
var _voices: Array[AudioStreamPlayer3D] = []
var _engine: AudioStreamWAV
var _hooves: AudioStreamWAV


func build(player: Node3D = null) -> void:
	name = "StreetTraffic"
	_player = player
	_rng.randomize()
	for k in KINDS:
		_total_weight += float(k[4])

	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.62
	mat.metallic = 0.35
	mesh.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = MAX_VEHICLES
	mm.visible_instance_count = 0

	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = mm
	# Traffic does not cast shadows. Fourteen moving casters on the worst
	# station in the game, where lighting is already the dominant term (-33%
	# with illumination hidden, twice the atrium's), is the one thing the brief
	# says not to spend.
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mm)

	_cabs = _make_batch(BoxMesh.new(), MAX_VEHICLES, false)
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.5
	wheel.bottom_radius = 0.5
	wheel.height = 1.0
	wheel.radial_segments = 10
	_wheels = _make_batch(wheel, MAX_VEHICLES * 4, false)
	_build_piano_sign_batch()
	_build_headlight_pool_batch()

	var lamp_mesh := QuadMesh.new()
	lamp_mesh.size = Vector2(0.34, 0.34)
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.vertex_color_use_as_albedo = true
	lamp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lamp_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lamp_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	lamp_mesh.material = lamp_mat
	var lm := MultiMesh.new()
	lm.transform_format = MultiMesh.TRANSFORM_3D
	lm.use_colors = true
	lm.mesh = lamp_mesh
	lm.instance_count = MAX_VEHICLES * 2
	lm.visible_instance_count = 0
	_lamps = MultiMeshInstance3D.new()
	_lamps.multimesh = lm
	_lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lamps)

	# Nothing in PropAudio is a vehicle, so both voices are forged the same way
	# the phonautogram's traces are. A 1928 motor is a slow irregular putter,
	# not a modern engine note; a dray is iron rims on stone with hooves over
	# the top of it.
	_engine = _forge(2.4, false)
	_hooves = _forge(2.0, true)
	for i in VOICES:
		var v := AudioStreamPlayer3D.new()
		v.unit_size = 9.0
		v.max_distance = 46.0
		v.volume_db = -12.0
		v.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(v)
		_voices.append(v)


func _build_piano_sign_batch() -> void:
	var panel := QuadMesh.new()
	panel.size = Vector2(3.15, 1.55)
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(PIANO_REPAIR_SIGN) as Texture2D
	material.roughness = 0.88
	material.metallic = 0.05
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	panel.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = panel
	multimesh.instance_count = MAX_VEHICLES * 2
	multimesh.visible_instance_count = 0
	_piano_signs = MultiMeshInstance3D.new()
	_piano_signs.name = "PianoRepairSigns"
	_piano_signs.multimesh = multimesh
	_piano_signs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_piano_signs)


func _build_headlight_pool_batch() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never,
		shadows_disabled;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)),
				hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// One soft wet-road reflection with the two lamp sources only faintly
	// legible inside it. UV.x begins at the vehicle and follows its travel.
	float spread = mix(0.12, 0.34, UV.x);
	float separation = mix(0.15, 0.075, UV.x);
	float left_trace = 1.0 - smoothstep(spread * 0.18, spread,
			abs(UV.y - (0.5 - separation)));
	float right_trace = 1.0 - smoothstep(spread * 0.18, spread,
			abs(UV.y - (0.5 + separation)));
	float paired = max(left_trace, right_trace);
	float broad_width = mix(0.22, 0.47, UV.x);
	float broad = 1.0 - smoothstep(broad_width * 0.32, broad_width,
			abs(UV.y - 0.5));
	float beam = mix(broad, paired, 0.24);
	float near_feather = smoothstep(0.0, 0.075, UV.x);
	float distance_fade = 1.0 - smoothstep(0.18, 1.0, UV.x);
	float side_feather = 1.0 - smoothstep(0.42, 0.50, abs(UV.y - 0.5));
	// Low-frequency breakup prevents the pool reading as a clean game decal.
	// It is fixed in the beam so this layer never becomes another rain system.
	float wet_breakup = mix(0.54, 1.0, value_noise(
			vec2(UV.x * 19.0, UV.y * 6.0 + 13.0)));
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * beam * near_feather * distance_fade
			* side_feather * wet_breakup;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	quad.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = MAX_VEHICLES
	multimesh.visible_instance_count = 0
	_headlight_pools = MultiMeshInstance3D.new()
	_headlight_pools.name = "TrafficWetHeadlightPools"
	_headlight_pools.multimesh = multimesh
	_headlight_pools.cast_shadow = \
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_headlight_pools)


func bind_player(player: Node3D) -> void:
	_player = player


## The arrival is not a second vehicle system and never becomes standing
## scenery. It occupies one slot in the same shared MultiMeshes as every other
## road user. Clearing startup traffic gives the first image one
## readable action; the ordinary stream resumes behind it after five seconds.
func begin_arrival() -> bool:
	if _arrival_started or _arrival_finished or _mm == null:
		return false
	_arrival_started = true
	_live.clear()
	_live.append({
		"arrival": true,
		"kind": 1, # motor_car
		"lane": false,
		"dir": 1.0,
		"x": ARRIVAL_START_X,
		"y": ARRIVAL_KERB_Y,
		"speed": 0.0,
		"hold": ARRIVAL_HOLD_SECONDS,
		"weather_entered": false,
		"stop_stage": 0,
		"dwell": 0.0,
		# Ordinary traffic deliberately reads at distance. The first car is close
		# enough to need a lower motor silhouette instead of the generic block,
		# while still using those exact batches.
		"length": 4.45,
		"width": 1.72,
		"height": 0.78,
		"cab_length": 2.28,
		"cab_height": 0.72,
		"cab_offset": -0.06,
		"body_color": Color(0.10, 0.15, 0.18),
		"cab_color": Color(0.035, 0.20, 0.21),
	})
	_spawn_accum = ARRIVAL_TRAFFIC_DELAY
	_write_instances()
	return true


## One batched, vertex-coloured, shadowless mesh. Everything traffic draws goes
## through here so the cost of adding a layer stays one draw call.
func _make_batch(mesh: Mesh, count: int, additive: bool) -> MultiMeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.66
	mat.metallic = 0.3
	if additive:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# PrimitiveMesh carries its material on a property; surface_set_material is
	# ArrayMesh API and silently does nothing here, which would leave every cab
	# and wheel on the street with the default white material.
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = mat
	else:
		mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _process(delta: float) -> void:
	if _mm == null:
		return
	_shove_cooldown = maxf(0.0, _shove_cooldown - delta)
	_advance(delta)
	_spawn(delta)
	_write_instances()
	_voice_nearest()
	_check_shove()


func _advance(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for v in _live:
		var remaining := delta
		if bool(v.get("arrival", false)):
			var hold_left: float = float(v.get("hold", 0.0)) - delta
			v.hold = maxf(0.0, hold_left)
			if hold_left > 0.0:
				kept.append(v)
				continue
			remaining = -hold_left
			var old_speed: float = float(v.get("speed", 0.0))
			var new_speed := minf(ARRIVAL_CRUISE_SPEED,
					old_speed + ARRIVAL_ACCELERATION * remaining)
			v.speed = new_speed
			v.x += float(v.dir) * (old_speed + new_speed) * 0.5 * remaining
			v.y = move_toward(float(v.get("y", ARRIVAL_KERB_Y)),
					LANE_EAST, ARRIVAL_MERGE_RATE * remaining)
			if float(v.x) >= EAST_TEAR_X \
					and not bool(v.get("weather_entered", false)):
				v.weather_entered = true
				arrival_entered_weather.emit()
			if float(v.x) < ARRIVAL_DESPAWN_X:
				kept.append(v)
			else:
				_arrival_finished = true
				arrival_departed.emit()
			continue
		if _serves_transit_stop(v):
			var stop_stage: int = int(v.get("stop_stage", 0))
			if stop_stage == 1:
				var dwell_left: float = float(v.get("dwell", 0.0)) - delta
				v.dwell = maxf(0.0, dwell_left)
				if dwell_left > 0.0:
					kept.append(v)
					continue
				# Preserve the fraction of this frame left after the dwell expires.
				remaining = -dwell_left
				v.stop_stage = 2
			elif stop_stage == 0:
				var next_x: float = float(v.x) + float(v.dir) \
						* float(v.speed) * delta
				if float(v.x) < TRANSIT_STOP_X and next_x >= TRANSIT_STOP_X:
					v.x = TRANSIT_STOP_X
					v.stop_stage = 1
					v.dwell = TRANSIT_STOP_DWELL
					transit_arrived.emit(TRANSIT_STOP_ID,
							str(KINDS[int(v.kind)][0]))
					kept.append(v)
					continue
		v.x += v.dir * v.speed * remaining
		if absf(v.x) < SPAWN_X + 4.0:
			kept.append(v)
	_live = kept


func _vehicle_y(v: Dictionary) -> float:
	return float(v.get("y", LANE_WEST if bool(v.lane) else LANE_EAST))


func _serves_transit_stop(v: Dictionary) -> bool:
	# The shelter fronts the eastbound lane. Westbound trams and every other
	# vehicle remain ordinary through traffic.
	var kind: int = int(v.get("kind", -1))
	return kind >= 0 and kind < KINDS.size() \
			and not bool(v.get("lane", true)) \
			and str(KINDS[kind][0]) == "tram"


## Spawn cadence with a PROMISE in it: if the near lane has been solid for
## MAX_WAIT, the next spawn is held back long enough to open a real gap. The
## player never learns this is happening; they learn that a gap always comes.
func _spawn(delta: float) -> void:
	_spawn_accum -= delta
	if _spawn_accum > 0.0:
		return
	var lane_west := _rng.randf() < 0.5
	var v := {
		"kind": _pick(),
		"lane": lane_west,
		"dir": -1.0 if lane_west else 1.0,
		"x": SPAWN_X if lane_west else -SPAWN_X,
		"speed": _rng.randf_range(SPEED_MIN, SPEED_MAX),
		"stop_stage": 0,
		"dwell": 0.0,
	}
	if _live.size() < MAX_VEHICLES:
		_live.append(v)
	# The gap. Sometimes short, sometimes generous, never longer than the
	# promise - and the pause is measured in the time it takes to WALK the
	# lane, not in seconds of clock.
	var crowd := float(_live.size()) / float(MAX_VEHICLES)
	_spawn_accum = _rng.randf_range(1.1, 2.6) + (GAP_SECONDS if _rng.randf() < 0.28 else 0.0)
	_spawn_accum = minf(_spawn_accum, MAX_WAIT) * (1.0 - crowd * 0.35)


func _pick() -> int:
	var roll := _rng.randf() * _total_weight
	for i in KINDS.size():
		roll -= float(KINDS[i][4])
		if roll <= 0.0:
			return i
	return 0


func _write_instances() -> void:
	var mm := _mm.multimesh
	var sign_mm := _piano_signs.multimesh
	var pool_mm := _headlight_pools.multimesh
	var sign_count := 0
	_piano_sign_origins.clear()
	_headlight_pool_origins.clear()
	var n: int = mini(_live.size(), MAX_VEHICLES)
	mm.visible_instance_count = n
	_lamps.multimesh.visible_instance_count = n * 2
	_cabs.multimesh.visible_instance_count = n
	_wheels.multimesh.visible_instance_count = n * 4
	_headlight_pools.multimesh.visible_instance_count = n
	for i in n:
		var v: Dictionary = _live[i]
		var k: Array = KINDS[int(v.kind)]
		var length := float(v.get("length", k[1]))
		var width := float(v.get("width", k[2]))
		var height := float(v.get("height", k[3]))
		var y := _vehicle_y(v)
		var is_piano_repair := str(k[0]) == "piano_repair"
		var body_length := 3.70 if is_piano_repair else length
		var body_offset := -float(v.dir) * 0.85 if is_piano_repair else 0.0
		var body_x: float = float(v.x) + body_offset
		var basis := Basis().scaled(Vector3(body_length, height, width))
		var at := GameBoot.b2g([body_x, y, height * 0.5])
		mm.set_instance_transform(i, Transform3D(basis, at))
		mm.set_instance_color(i, Color(v.get("body_color", k[5])))

		# The cab: a raised block set back from the nose, which is the single
		# read that says "vehicle" rather than "crate".
		var cab_len := 1.65 if is_piano_repair \
				else float(v.get("cab_length", length * float(k[6])))
		var cab_h := 1.65 if is_piano_repair \
				else float(v.get("cab_height", height * float(k[7])))
		var cab_offset := float(v.dir) * 1.72 if is_piano_repair \
				else float(v.get("cab_offset", -float(v.dir) * length * 0.18))
		var cab_base := 0.35 if is_piano_repair else height
		var cm := _cabs.multimesh
		cm.set_instance_transform(i, Transform3D(
				Basis().scaled(Vector3(cab_len, cab_h, width * 0.92)),
				GameBoot.b2g([float(v.x) + cab_offset, y,
						cab_base + cab_h * 0.5])))
		cm.set_instance_color(i, Color(v.get("cab_color",
				Color(k[5]).darkened(0.25))))

		# Four wheels, sized to the vehicle and sunk so they meet the road.
		var wr: float = clampf(height * 0.22, 0.28, 0.52)
		var wm := _wheels.multimesh
		for w in 4:
			var along: float = length * (0.32 if w < 2 else -0.32)
			var across: float = width * (0.5 if w % 2 == 0 else -0.5)
			var wb := Basis(Vector3.RIGHT, PI * 0.5).scaled(
					Vector3(wr * 2.0, width * 0.10, wr * 2.0))
			wm.set_instance_transform(i * 4 + w, Transform3D(wb,
					GameBoot.b2g([float(v.x) + along, y + across, wr])))
			wm.set_instance_color(i * 4 + w, Color(0.09, 0.085, 0.08))

		# Lamps ride at the ends: warm ahead, red behind, and they are the
		# first thing a player reads when judging a gap in the dark.
		var lm := _lamps.multimesh
		var nose: float = float(v.x) + float(v.dir) * length * 0.5
		var tail: float = float(v.x) - float(v.dir) * length * 0.5
		lm.set_instance_transform(i * 2, Transform3D(Basis(),
				GameBoot.b2g([nose, y, height * 0.42])))
		lm.set_instance_color(i * 2, Color(1.0, 0.86, 0.60))
		lm.set_instance_transform(i * 2 + 1, Transform3D(Basis().scaled(
				Vector3(0.6, 0.6, 0.6)),
				GameBoot.b2g([tail, y, height * 0.38])))
		lm.set_instance_color(i * 2 + 1, Color(0.85, 0.10, 0.06))

		# A real lamp would multiply the street's dominant cost. On rain-dark
		# paving the information the player needs is the warm reflection: where
		# the nose is, which way it points, and how quickly it is arriving.
		var pool_x := nose + float(v.dir) * HEADLIGHT_POOL_LENGTH * 0.48
		var pool_origin := GameBoot.b2g([pool_x, y, 0.035])
		var pool_x_axis := Vector3(float(v.dir) * HEADLIGHT_POOL_LENGTH,
				0.0, 0.0)
		var pool_y_axis := Vector3(0.0, 0.0,
				-float(v.dir) * HEADLIGHT_POOL_WIDTH)
		pool_mm.set_instance_transform(i, Transform3D(Basis(pool_x_axis,
				pool_y_axis, Vector3.UP), pool_origin))
		pool_mm.set_instance_color(i, Color(1.0, 0.76, 0.52,
				HEADLIGHT_POOL_ALPHA))
		_headlight_pool_origins.append(pool_origin)

		# The approved enamel advertisement rides as two dull painted panels,
		# never as emissive UI. Both sides share one MultiMesh draw across every
		# repair truck in the stream.
		if is_piano_repair:
			var panel_x := body_x
			var panel_z := 1.28
			var south_y := y - width * 0.505
			var north_y := y + width * 0.505
			var south_origin := GameBoot.b2g([panel_x, south_y, panel_z])
			var north_origin := GameBoot.b2g([panel_x, north_y, panel_z])
			sign_mm.set_instance_transform(sign_count, Transform3D(Basis(),
					south_origin))
			_piano_sign_origins.append(south_origin)
			sign_count += 1
			sign_mm.set_instance_transform(sign_count, Transform3D(
					Basis(Vector3.UP, PI), north_origin))
			_piano_sign_origins.append(north_origin)
			sign_count += 1
	_piano_signs.multimesh.visible_instance_count = sign_count


## A hit is a shove. No damage, no death, no screen, no sound cue that reads as
## a fail state - a horn, a stumble and four seconds. The player gets up.
func _check_shove() -> void:
	if _player == null or _shove_cooldown > 0.0:
		return
	var p := _player.global_position
	for v in _live:
		var y := _vehicle_y(v)
		var at := GameBoot.b2g([float(v.x), y, 0.0])
		var k: Array = KINDS[int(v.kind)]
		if absf(p.x - at.x) > float(v.get("length", k[1])) * 0.5 + 0.4:
			continue
		if absf(p.z - at.z) > float(v.get("width", k[2])) * 0.5 + 0.4:
			continue
		_shove(v)
		return


func _shove(v: Dictionary) -> void:
	_shove_cooldown = 4.0
	if _player.has_method("stagger"):
		# Traffic moves on world X. Carry the player with the vehicle rather
		# than kicking them sideways across an unrelated lane axis.
		_player.stagger(Vector3(signf(float(v.dir)) * 3.4, 0, 0))
	print("[STREET] shoved by a %s" % str(KINDS[int(v.kind)][0]))


## Forge a loop. `hooved` gives the rhythmic strike of a walking horse over the
## rumble; otherwise it is a motor firing unevenly, which is what a 1928 engine
## sounded like and is also easier to judge distance from than a smooth note.
func _forge(seconds: float, hooved: bool) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * seconds)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210 if hooved else 4711
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(rate)
		# The rumble both share: broadband, low, and rolling.
		var v := (rng.randf() * 2.0 - 1.0) * 0.30
		phase += TAU * (38.0 if hooved else 27.0) / float(rate)
		v += sin(phase) * 0.42
		v += sin(phase * 0.5) * 0.22
		if hooved:
			# Four beats a bar, uneven, because a horse is not a metronome.
			var beat := fposmod(t * 3.1, 1.0)
			var strike: float = exp(-beat * 34.0) + exp(-fposmod(beat + 0.42, 1.0) * 40.0)
			v += (rng.randf() * 2.0 - 1.0) * strike * 0.55
		else:
			# Firing unevenly: a slow chuff with the odd miss in it.
			var fire := fposmod(t * 7.3, 1.0)
			var miss := 0.35 if fposmod(t, 0.83) < 0.1 else 1.0
			v += exp(-fire * 12.0) * 0.5 * miss
		var s := int(clampf(v * 8000.0, -32000.0, 32000.0))
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	wav.data = data
	return wav


## Give the nearest few vehicles a voice and let the rest be silent. Reassigning
## by distance every frame would chatter, so a voice keeps its vehicle until
## that vehicle leaves or something gets materially closer.
func _voice_nearest() -> void:
	if _player == null or _voices.is_empty():
		return
	var here := _player.global_position
	var order := _live.duplicate()
	order.sort_custom(func(a, b):
		return absf(float(a.x) - here.x) < absf(float(b.x) - here.x))
	for i in _voices.size():
		var voice := _voices[i]
		if i >= order.size():
			voice.stop()
			continue
		var v: Dictionary = order[i]
		var k: Array = KINDS[int(v.kind)]
		var hooved: bool = str(k[0]) in ["dray", "hansom", "milk_float", "riderless"]
		var want: AudioStreamWAV = _hooves if hooved else _engine
		if voice.stream != want:
			voice.stream = want
			voice.play()
		elif not voice.playing:
			voice.play()
		var y := _vehicle_y(v)
		voice.global_position = GameBoot.b2g([float(v.x), y, 1.0])
		# Speed reads as pitch, which is most of how a person judges whether
		# they can make it. Bigger vehicles sit lower.
		voice.pitch_scale = clampf(float(v.speed) / 6.0, 0.6, 1.5) \
				* clampf(3.0 / float(v.get("length", k[1])), 0.55, 1.25)
