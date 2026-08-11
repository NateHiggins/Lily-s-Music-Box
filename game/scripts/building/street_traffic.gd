class_name StreetTraffic
extends Node3D
## The stream you cross. See design/ORISON_STREET_BRIEF.md §2-§3.
##
## ONE DRAW CALL FOR ALL OF IT. Street elevation is the second-worst station in
## the game at 33.28 ms against a 16.6 target, and it is CPU-bound on submission
## rather than on the GPU (TASKS P2) - so every vehicle is an instance in a
## single MultiMesh, scaled and tinted per instance. A dray and a coal lorry are
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

## 95% credible 1928, 5% wrong and never acknowledged. Absurd traffic is
## charming for ten seconds and then it is a joke that keeps talking, and the
## haunting has to compete with it - so the wrong ones are quiet wrong. The
## same dray passing a third time beats a herd of geese and costs nothing.
const KINDS := [
	# name, length, width, height, weight, tint
	# Tints lifted hard from the first pass, which ran 0.045-0.18 and put pure
	# black rectangles on a dark street - a vehicle you cannot see is not
	# atmosphere, it is a missing texture. Painted coachwork under a sodium
	# lamp still returns light, and the shape has to be legible before it can
	# be threatening.
	["dray", 4.2, 1.9, 2.3, 22.0, Color(0.34, 0.26, 0.18)],
	["motor_car", 4.1, 1.7, 1.5, 20.0, Color(0.20, 0.21, 0.24)],
	["coal_lorry", 6.0, 2.2, 2.6, 14.0, Color(0.26, 0.23, 0.19)],
	["delivery_van", 4.8, 1.9, 2.2, 13.0, Color(0.30, 0.28, 0.26)],
	["hansom", 3.2, 1.6, 2.1, 9.0, Color(0.17, 0.16, 0.18)],
	["milk_float", 3.6, 1.7, 2.0, 8.0, Color(0.52, 0.50, 0.47)],
	["tram", 9.4, 2.5, 3.1, 5.0, Color(0.36, 0.27, 0.16)],
	["hearse", 5.2, 1.9, 2.3, 3.0, Color(0.13, 0.125, 0.135)],
	# The wrong 5%. Never remarked on by anyone, ever.
	["too_long", 13.5, 2.3, 2.6, 1.6, Color(0.22, 0.21, 0.20)],
	["riderless", 4.2, 1.9, 2.3, 1.4, Color(0.33, 0.26, 0.19)],
]

var _mm: MultiMeshInstance3D
## Lamps, as an emissive MultiMesh rather than as lights. Two per vehicle,
## front and rear. Real headlamps would be the single most expensive thing on
## this street - illumination is already the dominant term out here at -33%,
## twice the atrium's - and at these distances an emissive quad reads exactly
## the same. It is also what makes a black mass become a lorry.
var _lamps: MultiMeshInstance3D
var _live: Array[Dictionary] = []
var _spawn_accum := 0.0
var _rng := RandomNumberGenerator.new()
var _player: Node3D
var _shove_cooldown := 0.0
var _total_weight := 0.0


func build(player: Node3D) -> void:
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


func _process(delta: float) -> void:
	if _mm == null:
		return
	_shove_cooldown = maxf(0.0, _shove_cooldown - delta)
	_advance(delta)
	_spawn(delta)
	_write_instances()
	_check_shove()


func _advance(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for v in _live:
		v.x += v.dir * v.speed * delta
		if absf(v.x) < SPAWN_X + 4.0:
			kept.append(v)
	_live = kept


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
	var n: int = mini(_live.size(), MAX_VEHICLES)
	mm.visible_instance_count = n
	_lamps.multimesh.visible_instance_count = n * 2
	for i in n:
		var v: Dictionary = _live[i]
		var k: Array = KINDS[int(v.kind)]
		var length := float(k[1])
		var width := float(k[2])
		var height := float(k[3])
		var y: float = LANE_WEST if bool(v.lane) else LANE_EAST
		var basis := Basis().scaled(Vector3(length, height, width))
		var at := GameBoot.b2g([float(v.x), y, height * 0.5])
		mm.set_instance_transform(i, Transform3D(basis, at))
		mm.set_instance_color(i, k[5])

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


## A hit is a shove. No damage, no death, no screen, no sound cue that reads as
## a fail state - a horn, a stumble and four seconds. The player gets up.
func _check_shove() -> void:
	if _player == null or _shove_cooldown > 0.0:
		return
	var p := _player.global_position
	for v in _live:
		var y: float = LANE_WEST if bool(v.lane) else LANE_EAST
		var at := GameBoot.b2g([float(v.x), y, 0.0])
		var k: Array = KINDS[int(v.kind)]
		if absf(p.x - at.x) > float(k[1]) * 0.5 + 0.4:
			continue
		if absf(p.z - at.z) > float(k[2]) * 0.5 + 0.4:
			continue
		_shove(v)
		return


func _shove(v: Dictionary) -> void:
	_shove_cooldown = 4.0
	if _player.has_method("stagger"):
		_player.stagger(Vector3(0, 0, -signf(float(v.dir)) * 3.4))
	print("[STREET] shoved by a %s" % str(KINDS[int(v.kind)][0]))
