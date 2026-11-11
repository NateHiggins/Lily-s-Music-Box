extends "res://scripts/building/commensal_director.gd"
## The commensals in V2 (Lily, v1r_commensals_20261109: "Import").
##
## V1's CommensalDirector keeps its authority here: the per-shift census and
## schedule, the stable seed, the once-a-shift roach scatter when 4B's kitchen
## light goes on at night, the protected call window, the night rule and the
## one-second tick. This script replaces what V1 drew and where V1 found it:
##
##  - Bodies are Blender stock (art/blender/scripts/build_commensals.py) in
##    catalogue finishes, drawn by MultiMesh: the moth's body and its two wing
##    pairs (three draws for every moth in the street) and the roach (one).
##  - Moths gather at the two street lamps nearest the front door, as V1's
##    did, but at V2's own lamps and only while a lamp burns: when the lamp
##    clock puts a lamp out its moths drift off into the dark, and they come
##    back when it is lit again. V1's orbit and wing timing are kept; the
##    wing beat that V1 faked by squeezing a flat sprite is a real dihedral.
##  - Roaches wait on the floor in front of 4B's kitchen sink, found through
##    V2's own anchors.
##
## Not carried: V1's weeds grew at the base of the street-end hoarding, which
## V2's street does not have, and V1's mouse-in-the-riser cue was requested
## from AmbientSoundscape, which V2 does not run.
const DATA := "res://data/orison_v2/commensals.json"
const SELF := "res://scripts/building/orison_v2_commensals.gd"
## How long a moth takes to give up a dark lamp, or to find a lit one.
const GATHER_SECONDS := 5.0
## How far a moth wanders from a lamp that has gone out before it is lost.
const LEAVE_METRES := 5.0
## V1's shader constants, kept as they were.
const WING_HZ := 5.4
const ROACH_RUN_SECONDS := 1.2
const ROACH_SCALE := 0.55

var errors: Array[String] = []
var moth_wing_batches: Array[MultiMeshInstance3D] = []
## One row per moth: lamp, phase, radius, speed, tilt.
var moths: Array[Dictionary] = []
var lamp_lights: Array[OmniLight3D] = []
## 0 while a lamp's moths are away, 1 while they are gathered.
var gathered: PackedFloat32Array = PackedFloat32Array()
var roaches: Array[Dictionary] = []

var _blockout: Node3D
var _wing_roots: Array[Vector3] = []
var _roach_started := -100.0
var _f04_height := 0.0
var _clock := 0.0


static func mount(root: Node3D, blockout: Node3D, layout: Dictionary, _adapter: Variant) -> Node:
	var node: Node3D = load(SELF).new()
	node.name = "Commensals"
	root.add_child(node)
	node.compose(root, blockout, layout)
	return node


func compose(root: Node3D, blockout: Node3D, layout: Dictionary) -> void:
	_root = root
	_blockout = blockout
	_layout = layout
	_switches = root.get_node_or_null("V2RoomSwitches") as SwitchSystem
	_day_night = root.get("day_night_director") as DayNightDirector
	_player = root.get("player") as Node3D
	_shift = int(RealityState.data.get("dreams_had", 0))
	_campaign_seed = str(RealityState.data.get("dream_seed", "0"))
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not (data is Dictionary) or int(data.schema_version) != 1:
		errors.append("commensal data missing")
		return
	var packed := load(str(data.asset)) as PackedScene
	if packed == null:
		errors.append("commensal stock missing")
		return
	var model := packed.instantiate()
	var stock: Dictionary = {}
	for row: Dictionary in data.parts:
		var draw := model.find_child(str(row.mesh), true, false) as MeshInstance3D
		var finish := _finish(str(row.material), Color.from_string(str(row.tint), Color.WHITE))
		if draw == null or draw.mesh == null or finish == null:
			errors.append("commensal part missing: " + str(row.id))
			continue
		stock[str(row.id)] = {"mesh": draw.mesh, "finish": finish, "root": draw.position}
	model.free()
	if not errors.is_empty():
		return
	_resolve_v2_anchors(int(data.moth_lamps), str(data.roach_fixture), str(data.roach_stance))
	_derive_shift_state()
	if not lamp_lights.is_empty():
		_build_v2_moths(stock, float(data.moth_range_m))
	if anchor_ids.has("kitchen"):
		_build_v2_roaches(stock.roach, float(data.roach_range_m))
	if _switches != null and not _switches.room_toggled.is_connected(_on_room_toggled):
		_switches.room_toggled.connect(_on_room_toggled)
	_tick.name = "LowHzTick"
	_tick.wait_time = TICK_SECONDS
	_tick.autostart = true
	_tick.timeout.connect(_on_tick)
	add_child(_tick)
	_update_context()
	_apply_visibility()
	print("[V2 COMMENSALS] %d moths at %d lamps, %d roaches at %s" % [
			moths.size(), lamp_lights.size(), roaches.size(), anchor_ids.get("kitchen", "nowhere")])


func _finish(key: String, tint: Color) -> StandardMaterial3D:
	if not MatLib.SETS.has(key):
		errors.append("unregistered commensal finish: " + key)
		return null
	var mat := MatLib.get_mat(key).duplicate() as StandardMaterial3D
	mat.uv1_triplanar = false
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.albedo_color = tint
	# Wings and legs are single blades, seen from both sides (as V1 drew them).
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## V1 chose the two street lamps nearest the entry and 4B's kitchen sink from
## its own layout markers. V2's lamps are the lamp clock's lights, nearest the
## front-door threshold the street is framed on; the sink is V2's anchor.
func _resolve_v2_anchors(lamp_count: int, fixture: String, stance: String) -> void:
	var lights: Array[OmniLight3D] = []
	var threshold := Vector3.ZERO
	for clock in get_tree().get_nodes_in_group("v2_street_lamp_clocks"):
		if not is_ancestor_of(clock) and _root.is_ancestor_of(clock):
			lights.append_array(clock.lights)
			threshold = (clock.get_parent().get_parent() as Node3D).global_position
	lights.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool:
		return a.global_position.distance_squared_to(threshold) < b.global_position.distance_squared_to(threshold))
	lamp_lights = lights.slice(0, lamp_count)
	if lamp_lights.size() < lamp_count:
		errors.append("commensal street-lamp owners missing")
	anchor_ids.lamps = lamp_lights.map(func(light: OmniLight3D) -> String:
		return str(light.get_meta("authored_record_id", light.name)))
	anchor_ids.lamp_positions = lamp_lights.map(func(light: OmniLight3D) -> Vector3: return light.global_position)
	gathered.resize(lamp_lights.size())
	var levels: Dictionary = {}
	for level: Dictionary in _layout.get("levels", []):
		levels[str(level.id)] = float(level.y)
	var sink: Dictionary = {}
	var front: Dictionary = {}
	for anchor: Dictionary in _layout.get("anchors", []):
		if str(anchor.id) == fixture:
			sink = anchor
		elif str(anchor.id) == stance:
			front = anchor
	if sink.is_empty() or front.is_empty() or str(sink.space) != KITCHEN_ROOM:
		errors.append("commensal 4B kitchen owner missing")
		return
	anchor_ids.kitchen = fixture
	_f04_height = levels[str(sink.level)]
	var sink_at := Vector3(float(sink.position[0]), levels[str(sink.level)], float(sink.position[2]))
	var front_at := Vector3(float(front.position[0]), sink_at.y, float(front.position[2]))
	# V1: on the exposed floor 0.46 m in front of the sink, not inside it.
	_roach_at = _blockout.to_global(sink_at + (front_at - sink_at).normalized() * 0.46)


func _batch(batch_name: String, part: Dictionary, count: int, reach: float, centre: Vector3, spread: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = part.mesh
	mm.instance_count = count
	var batch := MultiMeshInstance3D.new()
	batch.name = batch_name
	batch.multimesh = mm
	batch.material_override = part.finish
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.custom_aabb = AABB(to_local(centre) - Vector3.ONE * spread, Vector3.ONE * spread * 2.0)
	batch.visibility_range_end = reach + spread
	add_child(batch)
	return batch


func _build_v2_moths(stock: Dictionary, reach: float) -> void:
	var centre := Vector3.ZERO
	for light in lamp_lights:
		centre += light.global_position / float(lamp_lights.size())
	var spread := LEAVE_METRES + 2.0
	for light in lamp_lights:
		spread = maxf(spread, light.global_position.distance_to(centre) + LEAVE_METRES + 2.0)
	moth_batch = _batch("LampMothBodies", stock.moth_body, census.moths, reach, centre, spread)
	moth_wing_batches = [
		_batch("LampMothWingsLeft", stock.moth_wings_left, census.moths, reach, centre, spread),
		_batch("LampMothWingsRight", stock.moth_wings_right, census.moths, reach, centre, spread)]
	_wing_roots = [stock.moth_wings_left.root, stock.moth_wings_right.root]
	for i in int(census.moths):
		# V1's own draws from the shift seed: phase, orbit radius and speed, tilt.
		moths.append({
			"lamp": i % lamp_lights.size(),
			"phase": float(_stable_seed("moth_phase_%d" % i) % 1000) / 1000.0 * TAU,
			"radius": lerpf(0.18, 0.62, float(_stable_seed("moth_radius_%d" % i) % 100) / 100.0),
			"speed": lerpf(0.42, 0.78, float(_stable_seed("moth_speed_%d" % i) % 100) / 100.0),
			"tilt": (float(_stable_seed("moth_tilt_%d" % i) % 100) / 100.0 - 0.5) * 0.9,
		})
	for lamp in lamp_lights.size():
		gathered[lamp] = 1.0 if lamp_lit(lamp) else 0.0
	_pose_moths()


func _build_v2_roaches(part: Dictionary, reach: float) -> void:
	roach_batch = _batch("KitchenRoachScatter", part, census.roaches, reach, _roach_at, 1.6)
	roach_batch.visible = false
	for i in int(census.roaches):
		var angle: float = TAU * float(i) / float(census.roaches)
		roaches.append({
			"at": _roach_at + Vector3(cos(angle) * 0.11, 0.0, sin(angle) * 0.08),
			"run": Vector3(cos(angle), 0.0, sin(angle)),
			# V1 authored 0.76 to 1.49 m in the body's own frame, drawn at 0.55.
			"reach": lerpf(0.76, 1.49, float(_stable_seed("roach_%d" % i) % 100) / 100.0) * ROACH_SCALE,
		})
	_pose_roaches(0.0)


func lamp_lit(lamp: int) -> bool:
	var light := lamp_lights[lamp]
	return is_instance_valid(light) and light.visible and light.light_energy > 0.01


## Where moth `index` is now, in the world.
func moth_position(index: int) -> Vector3:
	return to_global(moth_batch.multimesh.get_instance_transform(index).origin)


## True while moth `index` is drawn at all (a lost moth has no size).
func moth_present(index: int) -> bool:
	return moth_batch.visible and moth_batch.multimesh.get_instance_transform(index).basis.x.length() > 0.05


func roach_position(index: int) -> Vector3:
	return to_global(roach_batch.multimesh.get_instance_transform(index).origin)


func _process(delta: float) -> void:
	_clock += delta
	if moth_batch != null and moth_batch.visible:
		for lamp in lamp_lights.size():
			gathered[lamp] = move_toward(gathered[lamp], 1.0 if lamp_lit(lamp) else 0.0, delta / GATHER_SECONDS)
		_pose_moths()
	if roach_batch != null and roach_batch.visible:
		_pose_roaches(clampf((_clock - _roach_started) / ROACH_RUN_SECONDS, 0.0, 1.0))


func _moth_at(moth: Dictionary, time: float) -> Vector3:
	var near := float(gathered[int(moth.lamp)])
	var away := 1.0 - smoothstep(0.0, 1.0, near)
	var swing: float = time * float(moth.speed) + float(moth.phase)
	var radius: float = float(moth.radius) + away * LEAVE_METRES
	var lamp: Vector3 = lamp_lights[int(moth.lamp)].global_position
	# V1's orbit: a level circle with a slower vertical wander.
	return lamp + Vector3(cos(swing) * radius,
			sin(time * float(moth.speed) * 1.37 + float(moth.phase)) * radius * 0.42 + away * 1.5,
			sin(swing) * radius)


func _pose_moths() -> void:
	var inverse := global_transform.affine_inverse()
	for i in moths.size():
		var moth: Dictionary = moths[i]
		var at := _moth_at(moth, _clock)
		var heading := _moth_at(moth, _clock + 0.05) - at
		var size := smoothstep(0.0, 0.2, float(gathered[int(moth.lamp)]))
		var basis := Basis.IDENTITY
		if heading.length_squared() > 1e-10 and absf(heading.normalized().y) < 0.98:
			basis = Basis.looking_at(heading.normalized(), Vector3.UP)
		basis = basis * Basis(Vector3.FORWARD, float(moth.tilt) * 0.55)
		var body := inverse * Transform3D(basis.scaled(Vector3.ONE * size), at)
		moth_batch.multimesh.set_instance_transform(i, body)
		# V1 narrowed the sprite to 0.62..1.0 of its span at 5.4 rad/s; that
		# foreshortening is this dihedral.
		var lift := acos(clampf(0.62 + 0.38 * absf(sin(_clock * WING_HZ + float(moth.phase))), -1.0, 1.0))
		for side in 2:
			var wing := Transform3D(Basis(Vector3.BACK, lift if side == 1 else -lift), _wing_roots[side])
			moth_wing_batches[side].multimesh.set_instance_transform(i, body * wing)


func _pose_roaches(run: float) -> void:
	var inverse := global_transform.affine_inverse()
	var eased := smoothstep(0.0, 1.0, run)
	for i in roaches.size():
		var roach: Dictionary = roaches[i]
		var run_to: Vector3 = roach.run
		var basis := Basis(Vector3.UP, atan2(run_to.x, run_to.z)).scaled(Vector3.ONE * ROACH_SCALE)
		roach_batch.multimesh.set_instance_transform(i,
				inverse * Transform3D(basis, (roach.at as Vector3) + run_to * eased * float(roach.reach)))


## Stands the roaches on the kitchen's real floor finish.
func _settle_roaches() -> void:
	var query := PhysicsRayQueryParameters3D.create(_roach_at + Vector3.UP * 0.4, _roach_at + Vector3.DOWN * 0.2)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	for roach: Dictionary in roaches:
		roach.at = Vector3(roach.at.x, (hit.position as Vector3).y, roach.at.z)


## V1's rule, with the run clocked here instead of in a shader.
func _try_roach_scatter() -> bool:
	if roach_batch == null or roach_scatter_count > 0 or not _is_night() or not _f04_eligible \
			or _protected_window():
		return false
	roach_scatter_count += 1
	_roach_pending = false
	_roach_started = _clock
	_settle_roaches()
	_pose_roaches(0.0)
	roach_batch.visible = true
	return true


func _on_tick() -> void:
	var started := Time.get_ticks_usec()
	tick_count += 1
	_update_context()
	if _roach_pending:
		_pending_left -= TICK_SECONDS
		if _pending_left <= 0.0:
			_roach_pending = false
		elif not _protected_window():
			_try_roach_scatter()
	if roach_batch != null and roach_batch.visible and roach_scatter_count > 0 \
			and _clock - _roach_started > ROACH_SECONDS:
		roach_batch.visible = false
	_apply_visibility()
	last_tick_usec = Time.get_ticks_usec() - started


## V1 was told where the player stood by its root; V2 asks its own.
func _update_context() -> void:
	if _player == null or _blockout == null:
		return
	set_visibility_context(_player.global_position)


func set_visibility_context(at: Vector3) -> void:
	var outside := str(_root.call("room_at_world", at)).is_empty()
	var height := _blockout.to_local(at).y
	_street_eligible = outside or height < 1.75
	_f04_eligible = not outside and absf(height - _f04_height) < 1.75
	_apply_visibility()


func _apply_visibility() -> void:
	var off := OS.get_environment("PERF_COMMENSALS_VISUAL_OFF") == "1"
	if moth_batch != null:
		var shown := not off and _street_eligible and _is_night()
		moth_batch.visible = shown
		for batch in moth_wing_batches:
			batch.visible = shown
	if roach_batch != null and (off or not _f04_eligible or not _is_night()):
		roach_batch.visible = false


func draw_batches() -> Array[MultiMeshInstance3D]:
	var batches: Array[MultiMeshInstance3D] = []
	for batch: MultiMeshInstance3D in [moth_batch, roach_batch] + moth_wing_batches:
		if batch != null:
			batches.append(batch)
	return batches


func diagnostic_snapshot() -> Dictionary:
	return {
		"anchors": anchor_ids.duplicate(true),
		"pressure": pressure.duplicate(true),
		"census": census.duplicate(true),
		"schedule": schedule.duplicate(true),
		"draw_batches": draw_batches().size(),
		"collision_nodes": find_children("*", "CollisionObject3D", true, false).size(),
		"lights": find_children("*", "Light3D", true, false).size(),
		"shadow_casters": draw_batches().filter(func(batch: MultiMeshInstance3D) -> bool:
			return batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF).size(),
		"roach_scatter_count": roach_scatter_count,
		"last_tick_usec": last_tick_usec,
	}


func reset_habituation_for_test() -> void:
	roach_scatter_count = 0
	_roach_pending = false
	if roach_batch != null:
		roach_batch.visible = false
