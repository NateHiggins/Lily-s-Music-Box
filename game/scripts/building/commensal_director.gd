class_name CommensalDirector
extends Node3D
## Bounded waking-world C1.  One owner derives four presentations from the
## existing lamp, kitchen, riser and hoarding owners.  It stores nothing,
## routes nothing, and creates three shadowless MultiMesh draws: moths,
## roaches and static weeds.  Audio is only requested from AmbientSoundscape.

const KITCHEN_ROOM := "F04_B_KITCHEN"
const TICK_SECONDS := 1.0
const ROACH_SECONDS := 1.35
const PENDING_SECONDS := 3.0

var moth_batch: MultiMeshInstance3D
var roach_batch: MultiMeshInstance3D
var weed_batch: MultiMeshInstance3D
var pressure: Dictionary = {}
var census: Dictionary = {}
var schedule: Dictionary = {}
var anchor_ids: Dictionary = {}
var last_tick_usec := 0
var tick_count := 0
var roach_scatter_count := 0

var _root: Node3D
var _player: Node3D
var _audio: AmbientSoundscape
var _day_night: DayNightDirector
var _switches: SwitchSystem
var _layout: Dictionary
var _shift := 0
var _campaign_seed := ""
var _mouse_at := Vector3.ZERO
var _roach_at := Vector3.ZERO
var _street_eligible := true
var _f04_eligible := false
var _mouse_elapsed := 0.0
var _mouse_cued := false
var _roach_pending := false
var _pending_left := 0.0
var _night_override: Variant
var _tick := Timer.new()


func setup(root: Node3D, layout: Dictionary, switches: SwitchSystem,
		ambient: AmbientSoundscape, day_night: DayNightDirector,
		player: Node3D) -> void:
	_root = root
	_layout = layout
	_switches = switches
	_audio = ambient
	_day_night = day_night
	_player = player
	_shift = int(RealityState.data.get("dreams_had", 0))
	_campaign_seed = str(RealityState.data.get("dream_seed", "0"))
	_resolve_anchors()
	_derive_shift_state()
	_build_moths()
	_build_roaches()
	_build_weeds()
	if _switches and not _switches.room_toggled.is_connected(_on_room_toggled):
		_switches.room_toggled.connect(_on_room_toggled)
	_tick.name = "LowHzTick"
	_tick.wait_time = TICK_SECONDS
	_tick.autostart = true
	_tick.timeout.connect(_on_tick)
	add_child(_tick)
	_apply_visibility()


func _resolve_anchors() -> void:
	var entry: Dictionary = {}
	var lamps: Array[Dictionary] = []
	var kitchens: Array[Dictionary] = []
	var risers: Array[Dictionary] = []
	for floor in _layout.get("floors", []):
		for marker in floor.get("markers", []):
			var id := str(marker.get("id", ""))
			if id == "F01_DOOR_06":
				entry = marker
			elif str(marker.get("kind", "")) == "street_lamp":
				lamps.append(marker)
			elif str(marker.get("unit", "")) == "4B" \
					and str(marker.get("kind", "")) == "sink" \
					and id.contains("KITCHEN"):
				kitchens.append(marker)
			elif str(floor.get("id", "")) == "F02" \
					and str(marker.get("kind", "")) == "radiator" \
					and not str(marker.get("riser", "")).is_empty():
				risers.append(marker)
	assert(not entry.is_empty(), "commensal entry owner missing")
	assert(lamps.size() >= 2, "commensal street-lamp owners missing")
	assert(not kitchens.is_empty(), "commensal 4B kitchen owner missing")
	assert(not risers.is_empty(), "commensal F02 riser owners missing")
	var entry_at := GameBoot.b2g(entry.pos)
	lamps.sort_custom(func(a, b):
		return GameBoot.b2g(a.pos).distance_squared_to(entry_at) \
				< GameBoot.b2g(b.pos).distance_squared_to(entry_at))
	var selected_lamps: Array[Dictionary] = [lamps[0], lamps[1]]
	anchor_ids.lamps = selected_lamps.map(func(m): return str(m.id))
	anchor_ids.kitchen = str(kitchens[0].id)
	var riser_index := _stable_seed("F02_RISER") % risers.size()
	var riser: Dictionary = risers[riser_index]
	anchor_ids.riser = str(riser.riser)
	anchor_ids.riser_fixture = str(riser.id)
	assert(AcousticGraphData.nodes.has(str(riser.id)),
			"commensal F02 riser is absent from the acoustic graph")
	_mouse_at = AcousticGraphData.node_pos(str(riser.id))
	# The fixture's local -Z is its authored room-facing side.  Place the
	# scatter on the exposed floor in front of that owner, not inside its
	# cabinet collision or at a second world coordinate.
	var kitchen_yaw := deg_to_rad(float(kitchens[0].get("yaw_deg", 0.0)))
	var kitchen_front := Basis(Vector3.UP, kitchen_yaw) * Vector3.FORWARD
	_roach_at = GameBoot.b2g(kitchens[0].pos) + kitchen_front * 0.46
	var hoarding := _root.find_child("StreetEndHoardingFaces", true, false) \
			as MultiMeshInstance3D
	assert(hoarding != null and hoarding.multimesh != null \
			and hoarding.multimesh.instance_count > 0,
			"commensal named hoarding owner missing")
	anchor_ids.hoarding = str(hoarding.name)
	# The chosen base is the first transform authored by the hoarding owner.
	# No street-end world position is duplicated here.
	anchor_ids.hoarding_transform = hoarding.multimesh.get_instance_transform(0)
	var hoarding_transform: Transform3D = anchor_ids.hoarding_transform
	anchor_ids.hoarding_base = hoarding_transform.origin \
			- Vector3.UP * hoarding_transform.basis.y.length() * 0.5
	anchor_ids.lamp_positions = selected_lamps.map(
			func(m): return GameBoot.b2g(m.pos))


func _derive_shift_state() -> void:
	for key in ["lamps", "kitchen", "riser", "hoarding"]:
		pressure[key] = _stable_seed(str(anchor_ids.get(key, key))) % 4
	census = {
		"moths": 8 + _stable_seed("moths") % 5,
		"roaches": 4 + _stable_seed("roaches") % 3,
		"weeds": 4 + _stable_seed("weeds") % 3,
		"mouse_cues": 1,
	}
	schedule = {
		"mouse_delay_seconds": 18 + _stable_seed("mouse_schedule") % 23,
		# One verdict is the motif boundary: no patterned subdivision exists.
		"mouse_cadence_positions": 1,
		"roach_scatters_per_shift": 1,
	}


func _stable_seed(anchor: String) -> int:
	return absi((anchor + "|" + str(_shift) + "|" + _campaign_seed).hash())


func _build_moths() -> void:
	var winged := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.004, 0.0, 0.0), Vector3(-0.043, 0.019, 0.0),
		Vector3(-0.034, -0.016, 0.0),
		Vector3(0.004, 0.0, 0.0), Vector3(0.043, 0.019, 0.0),
		Vector3(0.034, -0.016, 0.0),
		Vector3(-0.004, 0.015, 0.002), Vector3(0.004, 0.015, 0.002),
		Vector3(0.0, -0.021, 0.002),
	])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([
		Color(0.58, 0.40, 0.16), Color(0.31, 0.19, 0.07),
		Color(0.42, 0.27, 0.09), Color(0.58, 0.40, 0.16),
		Color(0.31, 0.19, 0.07), Color(0.42, 0.27, 0.09),
		Color(0.08, 0.045, 0.018), Color(0.08, 0.045, 0.018),
		Color(0.08, 0.045, 0.018),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8])
	winged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
void vertex() {
	float phase = INSTANCE_CUSTOM.r * 6.2831853;
	float radius = mix(0.18, 0.62, INSTANCE_CUSTOM.g);
	float speed = mix(0.42, 0.78, INSTANCE_CUSTOM.b);
	VERTEX.x *= 0.62 + 0.38 * abs(sin(TIME * 5.4 + phase));
	VERTEX.x += cos(TIME * speed + phase) * radius;
	VERTEX.y += sin(TIME * speed * 1.37 + phase) * radius * 0.42;
	VERTEX.z += sin(TIME * speed + phase) * radius;
}
void fragment() {
	ALBEDO = COLOR.rgb * vec3(0.58, 0.50, 0.38);
	ROUGHNESS = 0.82;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	winged.surface_set_material(0, material)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = winged
	mm.instance_count = census.moths
	var lamp_positions: Array = anchor_ids.lamp_positions
	for i in census.moths:
		var at: Vector3 = lamp_positions[i % lamp_positions.size()]
		var tilt := (float(_stable_seed("moth_tilt_%d" % i) % 100) / 100.0
				- 0.5) * 0.9
		mm.set_instance_transform(i, Transform3D(
				Basis(Vector3.UP, tilt) * Basis(Vector3.FORWARD, tilt * 0.55), at))
		mm.set_instance_custom_data(i, Color(
				float(_stable_seed("moth_phase_%d" % i) % 1000) / 1000.0,
				float(_stable_seed("moth_radius_%d" % i) % 100) / 100.0,
				float(_stable_seed("moth_speed_%d" % i) % 100) / 100.0, 1.0))
	moth_batch = MultiMeshInstance3D.new()
	moth_batch.name = "EntryLampMoths"
	moth_batch.multimesh = mm
	moth_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moth_batch)


func _build_roaches() -> void:
	var body := _roach_mesh()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float scatter_start = -100.0;
void vertex() {
	float t = smoothstep(0.0, 1.0, clamp((TIME - scatter_start) / 1.2, 0.0, 1.0));
	vec2 direction = normalize(INSTANCE_CUSTOM.rg * 2.0 - 1.0);
	VERTEX.xz += direction * t * mix(0.76, 1.49, INSTANCE_CUSTOM.b);
}
void fragment() {
	ALBEDO = vec3(0.18, 0.060, 0.014);
	ROUGHNESS = 0.58;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = body
	mm.instance_count = census.roaches
	for i in int(census.roaches):
		var angle: float = TAU * float(i) / float(census.roaches)
		var local := Vector3(cos(angle) * 0.11, 0.025, sin(angle) * 0.08)
		var basis := Basis(Vector3.UP, angle).scaled(Vector3.ONE * 0.55)
		mm.set_instance_transform(i, Transform3D(basis, _roach_at + local))
		mm.set_instance_custom_data(i, Color(
				0.5 + cos(angle) * 0.5, 0.5 + sin(angle) * 0.5,
				float(_stable_seed("roach_%d" % i) % 100) / 100.0, 1.0))
	roach_batch = MultiMeshInstance3D.new()
	roach_batch.name = "KitchenRoachScatter"
	roach_batch.multimesh = mm
	roach_batch.material_override = material
	roach_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	roach_batch.visible = false
	add_child(roach_batch)


func _roach_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[Vector3] = []
	for i in 8:
		var angle := TAU * float(i) / 8.0
		ring.append(Vector3(sin(angle) * 0.014, 0.007,
				cos(angle) * 0.029))
	for i in 8:
		_add_roach_triangle(surface, Vector3(0, 0.012, 0), ring[i],
				ring[(i + 1) % 8])
	# Six splayed legs and two long feelers keep the tiny silhouette legible.
	for z in [-0.018, 0.0, 0.018]:
		_add_roach_triangle(surface, Vector3(-0.010, 0.006, z),
				Vector3(-0.037, 0.001, z - 0.009),
				Vector3(-0.035, 0.001, z - 0.006))
		_add_roach_triangle(surface, Vector3(0.010, 0.006, z),
				Vector3(0.037, 0.001, z - 0.009),
				Vector3(0.035, 0.001, z - 0.006))
	_add_roach_triangle(surface, Vector3(-0.006, 0.008, 0.026),
			Vector3(-0.026, 0.004, 0.070), Vector3(-0.023, 0.004, 0.069))
	_add_roach_triangle(surface, Vector3(0.006, 0.008, 0.026),
			Vector3(0.026, 0.004, 0.070), Vector3(0.023, 0.004, 0.069))
	return surface.commit()


func _add_roach_triangle(surface: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


func _build_weeds() -> void:
	var blade := PrismMesh.new()
	blade.size = Vector3(0.055, 0.72, 0.035)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.16, 0.22, 0.075)
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	blade.material = material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade
	mm.instance_count = census.weeds
	var owner_transform: Transform3D = anchor_ids.hoarding_transform
	var base: Vector3 = anchor_ids.hoarding_base
	for i in census.weeds:
		var spread := (float(i) - float(census.weeds - 1) * 0.5) * 0.12
		var basis := Basis(Vector3.FORWARD, spread * 0.7).scaled(
				Vector3(0.7 + i * 0.07, 0.55 + (i % 3) * 0.16, 0.7))
		mm.set_instance_transform(i, Transform3D(basis,
				base + owner_transform.basis.x.normalized() * spread \
				+ Vector3.UP * 0.18))
	weed_batch = MultiMeshInstance3D.new()
	weed_batch.name = "HoardingBaseWeeds"
	weed_batch.multimesh = mm
	weed_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(weed_batch)


func set_visibility_context(at: Vector3) -> void:
	var in_passage: bool = _root.call("_point_is_in_passage", at)
	var outside := not in_passage and (absf(at.x) > float(_root.OUTSIDE_HALF_X) \
			or absf(at.z) > float(_root.OUTSIDE_HALF_Z))
	_street_eligible = not in_passage and (outside or at.y < 1.75)
	var f04_y := float(_layout.meta.levels.F04)
	_f04_eligible = not outside and not in_passage and absf(at.y - f04_y) < 1.75
	_apply_visibility()


func _on_room_toggled(room_id: String, now_on: bool) -> void:
	if room_id != KITCHEN_ROOM or not now_on or roach_scatter_count > 0:
		return
	if _protected_window():
		_roach_pending = true
		_pending_left = PENDING_SECONDS
		return
	_try_roach_scatter()


func _try_roach_scatter() -> bool:
	if roach_scatter_count > 0 or not _is_night() or not _f04_eligible \
			or _protected_window():
		return false
	roach_scatter_count += 1
	_roach_pending = false
	var material := roach_batch.material_override as ShaderMaterial
	material.set_shader_parameter("scatter_start",
			float(Time.get_ticks_msec()) / 1000.0)
	roach_batch.visible = true
	return true


func _on_tick() -> void:
	var started := Time.get_ticks_usec()
	tick_count += 1
	_mouse_elapsed += TICK_SECONDS
	if _roach_pending:
		_pending_left -= TICK_SECONDS
		if _pending_left <= 0.0:
			_roach_pending = false
		elif not _protected_window():
			_try_roach_scatter()
	if roach_batch.visible and roach_scatter_count > 0:
		var material := roach_batch.material_override as ShaderMaterial
		var started_at := float(material.get_shader_parameter("scatter_start"))
		if float(Time.get_ticks_msec()) / 1000.0 - started_at > ROACH_SECONDS:
			roach_batch.visible = false
	if not _mouse_cued and _mouse_elapsed >= float(schedule.mouse_delay_seconds) \
			and _is_night() and _f02_nearby() and not _protected_window():
		_mouse_cued = _audio != null \
				and _audio.request_commensal_cue("mouse_riser", _mouse_at)
	_apply_visibility()
	last_tick_usec = Time.get_ticks_usec() - started


func _f02_nearby() -> bool:
	return _player != null and absf(_player.global_position.y \
			- float(_layout.meta.levels.F02)) < 1.75 \
			and _player.global_position.distance_to(_mouse_at) < 18.0


func _protected_window() -> bool:
	return _player != null and bool(_player.get("call_locked"))


func _is_night() -> bool:
	if _night_override != null:
		return bool(_night_override)
	if _day_night == null:
		return true
	var profile := _day_night.resolved_profile()
	return str(profile.get("state_a", "night")) == "night" \
			or str(profile.get("state_b", "night")) == "night"


func _apply_visibility() -> void:
	# Same-build performance control: retain construction, scheduling and every
	# ownership/index side effect while removing only the three presentations.
	if OS.get_environment("PERF_COMMENSALS_VISUAL_OFF") == "1":
		for batch in [moth_batch, roach_batch, weed_batch]:
			if batch:
				batch.visible = false
		return
	if moth_batch:
		moth_batch.visible = _street_eligible and _is_night()
	if weed_batch:
		# Plant life persists by day even though animal activity is C1-night.
		weed_batch.visible = _street_eligible
	if roach_batch and (not _f04_eligible or not _is_night()):
		roach_batch.visible = false


func diagnostic_snapshot() -> Dictionary:
	return {
		"anchors": anchor_ids.duplicate(true),
		"pressure": pressure.duplicate(true),
		"census": census.duplicate(true),
		"schedule": schedule.duplicate(true),
		"draw_batches": 3,
		"collision_nodes": find_children("*", "CollisionObject3D", true, false).size(),
		"lights": find_children("*", "Light3D", true, false).size(),
		"shadow_casters": [moth_batch, roach_batch, weed_batch].filter(
				func(n): return n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF).size(),
		"roach_scatter_count": roach_scatter_count,
		"mouse_cadence_positions": schedule.mouse_cadence_positions,
		"last_tick_usec": last_tick_usec,
	}


func force_night_for_test(value: Variant) -> void:
	_night_override = value
	_apply_visibility()


func tick_for_test() -> void:
	_on_tick()


func reset_habituation_for_test() -> void:
	roach_scatter_count = 0
	_roach_pending = false
	roach_batch.visible = false
