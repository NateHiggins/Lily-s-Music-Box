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
## Cabs and wheels, each their own MultiMesh. Four draw calls carry every
## vehicle on the street, which is still nothing next to what a per-vehicle
## scene would cost - and a stepped silhouette on four wheels is the whole
## difference between a lorry and a crate sliding down the road.
var _cabs: MultiMeshInstance3D
var _wheels: MultiMeshInstance3D
var _live: Array[Dictionary] = []
var _spawn_accum := 0.0
var _rng := RandomNumberGenerator.new()
var _player: Node3D
var _shove_cooldown := 0.0
var _total_weight := 0.0
## A small pool of voices, reassigned to whichever vehicles are nearest. The
## brief's acceptance test is that a player can cross BY EAR with the camera
## facing a door, and fourteen players would be fourteen voices competing on
## the worst-performing station in the game. Five is enough: past the nearest
## few, traffic is a texture rather than a thing you are timing.
const VOICES := 5
var _voices: Array[AudioStreamPlayer3D] = []
var _engine: AudioStreamWAV
var _hooves: AudioStreamWAV


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

	_cabs = _make_batch(BoxMesh.new(), MAX_VEHICLES, false)
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.5
	wheel.bottom_radius = 0.5
	wheel.height = 1.0
	wheel.radial_segments = 10
	_wheels = _make_batch(wheel, MAX_VEHICLES * 4, false)

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
	_cabs.multimesh.visible_instance_count = n
	_wheels.multimesh.visible_instance_count = n * 4
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

		# The cab: a raised block set back from the nose, which is the single
		# read that says "vehicle" rather than "crate".
		var cab_len: float = length * float(k[6])
		var cab_h: float = height * float(k[7])
		var cm := _cabs.multimesh
		cm.set_instance_transform(i, Transform3D(
				Basis().scaled(Vector3(cab_len, cab_h, width * 0.92)),
				GameBoot.b2g([float(v.x) - float(v.dir) * length * 0.18, y,
						height + cab_h * 0.5])))
		cm.set_instance_color(i, Color(k[5]).darkened(0.25))

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
		var y: float = LANE_WEST if bool(v.lane) else LANE_EAST
		voice.global_position = GameBoot.b2g([float(v.x), y, 1.0])
		# Speed reads as pitch, which is most of how a person judges whether
		# they can make it. Bigger vehicles sit lower.
		voice.pitch_scale = clampf(float(v.speed) / 6.0, 0.6, 1.5) 				* clampf(3.0 / float(k[1]), 0.55, 1.25)
