extends Node
## The possessed household objects V2 had no counterpart for
## (v1r_witness_tells_20261109, retirement plan section B): every one of V1's
## nineteen household tells is now on an object in its owner's flat, twelve of
## them period objects built in Blender and one a hand on 4B's cabinet mirror;
## each tell moves its own part and puts it back exactly; nothing moves while
## the player stands looking at it; every mounted surface is authored geometry
## in a catalogue finish. With SHOT_DIR set (windowed), photographs each one at
## rest and during its tell.
const Composer := preload("res://scripts/building/orison_v2_possessed_objects.gd")
const Witnesses := preload("res://scripts/building/orison_v2_domestic_witnesses.gd")
const PossessedObject := preload("res://scripts/building/orison_v2_possessed_object.gd")
## V1's catalogue (data/domestic_anomaly_props.json): id, flat, kind, tell.
const V1 := [
	["evelyn_mirror", "1A", "mirror", "late_reflection"], ["mina_intercom", "2A", "intercom", "unlisted_call"],
	["lena_coat_hook", "2B", "coat_hook", "one_more_hook"], ["juno_speaker", "2C", "smart_speaker", "stolen_voice"],
	["malcolm_plant", "3A", "houseplant", "turns_to_listen"], ["omar_outlet", "3B", "power_outlet", "wrong_voltage"],
	["rhea_telephone", "3D", "telephone", "open_line"], ["peter_thermostat", "4A", "thermostat", "approval_required"],
	["cam_noel_chain", "4C", "door_chain", "shared_threshold"],
	["guest_luggage_scale", "4D", "luggage_scale", "departure_weight"], ["nadia_level", "5A", "spirit_level", "false_level"],
	["cal_radio", "5B", "table_radio", "previous_room"], ["iris_picture_frame", "5C", "picture_frame", "changed_pose"],
	["sacha_camera", "6A", "security_camera", "tracks_after"], ["jonah_typewriter", "6B", "typewriter", "finishes_sentence"],
	["mae_key_bowl", "6C", "key_bowl", "extra_key"], ["player_answering_machine", "4B", "telephone", "open_line"],
	["player_smart_speaker", "4B", "smart_speaker", "stolen_voice"], ["player_wrong_mirror", "4B", "mirror", "late_reflection"]]
## The thirteen V2 lacked, with V1's inspection title for the built ones.
const NEW := {
	"evelyn_mirror": "FRAMED DOMESTIC MIRROR", "mina_intercom": "VANTRY APARTMENT INTERCOM",
	"lena_coat_hook": "WALL-MOUNTED COAT HOOK", "omar_outlet": "TWO-POINT WALL RECEPTACLE",
	"rhea_telephone": "CARBON TELEPHONE SET", "peter_thermostat": "ADJUSTABLE SIGNAL THERMOSTAT",
	"cam_noel_chain": "CHAIN DOOR FASTENING", "guest_luggage_scale": "GRADUATED LUGGAGE SCALE",
	"nadia_level": "PROTECTED SPIRIT LEVEL", "jonah_typewriter": "FRONT-STRIKE TYPEWRITER",
	"mae_key_bowl": "HOUSEHOLD KEY BOWL", "player_answering_machine": "CARBON TELEPHONE SET", "player_wrong_mirror": ""}
const A_CASE := "malcolm_memory_plants"

var _fails := 0
var _checks := 0
var _world: Node
var _eye := Vector3.ZERO
var _look := Vector3.ZERO
var _framing := false


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _process(_delta: float) -> void:
	if _framing and _world != null and _world.player != null:
		_world.player.camera.global_position = _eye
		_world.player.camera.look_at(_look)


func _settle(node: Node) -> void:
	var began := Time.get_ticks_msec()
	var quiet := 0
	while (quiet < 60 or not node.can_process()) and Time.get_ticks_msec() - began < 90000:
		var before := Time.get_ticks_msec()
		await get_tree().process_frame
		quiet = quiet + 1 if Time.get_ticks_msec() - before < 250 else 0


func _ready() -> void:
	process_priority = 1000
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(_world)
	while not _world.startup_failed and _world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not _world.startup_failed, "the V2 world starts")
	if _world.startup_failed:
		_finish()
		return
	# The runtime root mounts the family once it is integrated; until then the
	# test mounts it and reads the witnesses' table again over the new objects.
	var blockout: Node3D = _world.get("_blockout")
	var mounted: Variant = _world.get("possessed_objects")
	var witnesses: Node = _world.get("domestic_witnesses")
	if not (mounted is Dictionary) or (mounted as Dictionary).is_empty():
		mounted = Composer.mount(_world, blockout, _world.layout, _world.adapter)
		if witnesses != null and _world.sanity.intruded.is_connected(witnesses._on_intruded):
			_world.sanity.intruded.disconnect(witnesses._on_intruded)
		witnesses = Witnesses.new()
		_world.add_child(witnesses)
		witnesses.mount(_world.adapter, _world.get("vantry_points"))
		witnesses.bind_clocks(_world.witness_clocks.get("clocks", {}))
		witnesses.bind_director(_world.sanity, _world.player)
	var objects: Dictionary = mounted.objects
	_check((mounted.errors as Array).is_empty(), "the mount reports no errors: %s" % [mounted.errors])
	_check(objects.size() == NEW.size(), "thirteen objects are mounted or bound (%d)" % objects.size())
	if objects.size() != NEW.size():
		_finish()
		return
	await _settle(witnesses)

	# Every V1 object is accounted for, none unmatched, each as V1 catalogued it.
	_check(witnesses.errors.is_empty() and witnesses.unmatched.is_empty(),
		"every tell found its object (%s %s)" % [witnesses.errors, witnesses.unmatched])
	_check(witnesses.tells.size() == V1.size(), "all nineteen of V1's household tells are in V2 (%d)" % witnesses.tells.size())
	_check(witnesses.home_relays.size() == 3, "4B has its three relays again (%d)" % witnesses.home_relays.size())
	_check(_world.sanity.intruded.is_connected(witnesses._on_intruded), "the routing is bound to the sanity director")
	for row: Array in V1:
		var tell: Node = witnesses.tells.get(str(row[0]))
		_check(tell != null and str(tell.kind) == str(row[2]) and str(tell.tell) == str(row[3]) and str(tell.unit) == str(row[1]),
			"%s keeps V1's kind and tell" % row[0])
		if tell == null:
			continue
		var at: Vector3 = tell.target.global_position
		if tell.target is PossessedObject:
			var out: Vector3 = tell.target.global_transform.basis.z
			at += out * 0.12 if _wall(tell.target) else Vector3.UP * 0.05
		_check(str(_world.unit_at_world(at)) == str(row[1]), "%s is in %s (found '%s')" % [row[0], row[1], _world.unit_at_world(at)])
		_check(NEW.has(str(row[0])) == (objects.get(str(row[0])) == tell.target), "%s rides %s" % [row[0], tell.target.name])

	var built: Array = []
	for id: String in objects:
		if objects[id] is PossessedObject:
			built.append(objects[id])
	_check(built.size() == 12, "twelve are Blender-built period objects (%d)" % built.size())
	for prop: Node3D in built:
		_support_check(prop)
	_surface_checks(built)

	# Unwatched, each tell moves its own part and is put back exactly.
	witnesses.player = null
	for row: Array in V1:
		var id := str(row[0])
		if not NEW.has(id):
			continue
		var tell: Node = witnesses.tells[id]
		var target: Node3D = tell.target
		var before: Array = target.tell_signature()
		var cases: Array = tell.case_ids
		if cases.is_empty():
			_check(tell.relay_all and tell.stage_haunt(A_CASE, 2, null), "%s answers for the building" % id)
			_check(_performs(target, A_CASE, 2), "%s performs '%s'" % [id, row[3]])
		for case_id: String in cases:
			witnesses.restore_all()
			_world.sanity.intruded.emit(case_id, 2)
			_check(tell.busy and bool(target.possessed), "%s answers %s" % [id, case_id])
			_check(_performs(target, case_id, 2), "%s performs '%s' for %s" % [id, row[3], case_id])
			var relays := 0
			for relay: Node in witnesses.home_relays:
				relays += 1 if relay.busy else 0
			_check(relays == 1, "exactly one of 4B's own things answers %s (%d)" % [case_id, relays])
		_check(target.tell_signature() != before, "%s is visibly altered" % id)
		if target is PossessedObject:
			_check(str(target.service_wire_card().condition).contains("VISIBLY ALTERED"), "%s reports itself altered" % id)
		witnesses.restore_all()
		_check(not tell.busy and not bool(target.possessed) and target.tell_signature() == before, "%s is put back exactly" % id)
		if target is PossessedObject:
			var card: Dictionary = target.interact(null)
			_check(str(card.get("title", "")) == str(NEW[id]) and str(card.get("condition", "")).contains("AT REST")
					and str(card.get("card_id", "")) == "case_object", "%s answers inspection with V1's card (%s)" % [id, card.get("title", "")])
			_check(target.name == "DomesticAnomaly_" + id and target.is_in_group("possessed_domestic_props"),
				"%s keeps V1's name and group" % id)
	for i in 30:
		await get_tree().process_frame
	witnesses.restore_all()

	# Tier scales the tells V1 scaled, and nobody else's object answers.
	var mina: Node = witnesses.tells["mina_intercom"]
	_check(witnesses.force("mina_caption_crisis", 3) and _performs(mina.target, "mina_caption_crisis", 3),
		"Mina's receiver swings three steps at tier 3")
	_check(not witnesses.tells["evelyn_mirror"].busy and not witnesses.tells["jonah_typewriter"].busy,
		"nobody else's object answers Mina's case")
	witnesses.restore_all()

	# It restores itself on the tell's own clock (tier 1: ten seconds).
	var chain: Node = witnesses.tells["cam_noel_chain"]
	var chain_rest: Array = chain.target.tell_signature()
	witnesses.force("noel_domestic_museum", 1)
	_check(chain.busy and chain.target.tell_signature() != chain_rest, "the chain swings for Noel")
	var began := Time.get_ticks_msec()
	while chain.busy and Time.get_ticks_msec() - began < 14000:
		await get_tree().process_frame
	_check(not chain.busy and chain.target.tell_signature() == chain_rest, "and hangs still again by itself")
	witnesses.restore_all()

	# Watched, nothing moves: the player stands and looks at each one.
	var player: Node3D = _world.player
	witnesses.player = player
	player.set_physics_process(false)
	for id: String in NEW:
		var tell: Node = witnesses.tells[id]
		var target: Node3D = tell.target
		var seen := await _stand_and_look(tell)
		_check(seen, "the player is looking at %s" % id)
		var before: Array = target.tell_signature()
		var case_id := A_CASE if (tell.case_ids as Array).is_empty() else str(tell.case_ids[0])
		_check(tell.stage_haunt(case_id, 2, player) and not tell.busy and target.tell_signature() == before,
			"watched, %s only ticks and stays as it is" % id)
		if id == "peter_thermostat":
			_check(tell.stage_haunt(case_id, 4, player) and tell.busy and target.tell_signature() != before,
				"at the worst tier it moves even while watched")
			tell.restore()
	witnesses.player = null
	witnesses.restore_all()
	if not OS.get_environment("SHOT_DIR").is_empty():
		await _photograph(witnesses)
	_finish()


static func _wall(prop: Node3D) -> bool:
	return str(prop.native.mounting(prop.stock)) == "wall"


static func _turned(prop: Node, component: String) -> float:
	var part: Node3D = prop._parts[component]
	return ((prop._rest[component] as Transform3D).basis.inverse() * part.transform.basis).get_euler().z


static func _moved(prop: Node, component: String) -> Vector3:
	var part: Node3D = prop._parts[component]
	return (prop._rest[component] as Transform3D).affine_inverse() * part.transform.origin


## True when the object shows its V1 tell at this tier, on the right part.
func _performs(target: Node, case_id: String, tier: int) -> bool:
	if not (target is PossessedObject):
		return bool(target.possessed) and bool(target.cabinet.is_door_open()) != bool(target._left_open)
	var steps := float(tier)
	match str(target.tell):
		"late_reflection":
			return is_equal_approx(_turned(target, "Mirror"), 0.045 * steps)
		"unlisted_call":
			return is_equal_approx(_turned(target, "Receiver"), -0.16 * steps)
		"one_more_hook":
			return (target._parts["ExtraHook"] as Node3D).visible
		"wrong_voltage":
			return target._jewel.material_override == target._jewel_lit and target._jewel_lit.emission_enabled
		"open_line":
			return _moved(target, "Receiver").is_equal_approx(Vector3(0, 0.025 * steps, 0)) \
					and _turned(target, "Hook") < -0.1 and (target._parts["CordDrop"] as Node3D).scale.y > 1.2
		"approval_required":
			return is_equal_approx(_turned(target, "Pointer"), 0.89)
		"shared_threshold":
			return is_equal_approx(_turned(target, "Chain"), (-0.20 if case_id == "cam_tilted_room" else 0.20) * steps)
		"departure_weight":
			return _moved(target, "Pointer").is_equal_approx(Vector3(0, -0.15, 0))
		"false_level":
			return _moved(target, "Bubble").is_equal_approx(Vector3(0.0045 * steps, 0, 0))
		"finishes_sentence":
			return _moved(target, "Carriage").is_equal_approx(Vector3(-0.12, 0, 0))
		"extra_key":
			return (target._parts["ExtraKey"] as Node3D).visible
	return false


## Short rays from inside the object to what carries it: the wall behind a
## hung one, the furniture under a standing one. All within 3 cm.
func _support_check(prop: Node3D) -> void:
	var space := prop.get_world_3d().direct_space_state
	var extent: AABB = prop.native.bounds(prop.stock)
	var exclude: Array[RID] = []
	for body in prop.find_children("*", "CollisionObject3D", true, false):
		exclude.append((body as CollisionObject3D).get_rid())
	var toward := Vector3.FORWARD if _wall(prop) else Vector3.DOWN
	var points: Array[Vector3] = [Vector3.ZERO]
	if not _wall(prop):
		points = [Vector3(extent.position.x * 0.5, 0, 0), Vector3.ZERO, Vector3(extent.end.x * 0.5, 0, 0)]
	var worst := 0.0
	var missed := 0
	for point: Vector3 in points:
		var from := prop.global_transform * (point - toward * 0.05)
		var to := prop.global_transform * (point + toward * 0.05)
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			missed += 1
			continue
		worst = maxf(worst, absf((hit.position as Vector3).distance_to(from) - 0.05))
	_check(missed == 0 and worst <= 0.03, "%s rests on a real %s (%d of %d rays missed, worst gap %.1f mm)" % [
		prop.name, "wall" if _wall(prop) else "support", missed, points.size(), worst * 1000.0])


func _surface_checks(built: Array) -> void:
	var draws := 0
	var triangles := 0
	for prop: Node3D in built:
		var bad: Array[String] = []
		for node in prop.find_children("*", "MeshInstance3D", true, false):
			var draw := node as MeshInstance3D
			draws += 1
			if not (draw.mesh is ArrayMesh) or draw.mesh.get_surface_count() != 1:
				bad.append("%s is not one authored surface" % draw.name)
				continue
			var arrays := draw.mesh.surface_get_arrays(0)
			var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
			triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			if uvs == null or (uvs as PackedVector2Array).is_empty() or arrays[Mesh.ARRAY_TANGENT] == null:
				bad.append("%s has no authored UVs or tangents" % draw.name)
			var finish := draw.material_override as StandardMaterial3D
			if finish == null or finish.albedo_texture == null or finish.roughness_texture == null \
					or finish.normal_texture == null or finish.uv1_triplanar:
				bad.append("%s is not a catalogue finish on its own UVs" % draw.name)
			if draw.visibility_range_end <= 0.0:
				bad.append("%s has no visibility range" % draw.name)
		for node in prop.find_children("*", "Label3D", true, false):
			var label := node as Label3D
			if label.double_sided or label.font == null or label.visibility_range_end <= 0.0 or not label.shaded:
				bad.append("%s is not a single-sided ranged label" % label.name)
		_check(bad.is_empty(), "%s: every surface is authored geometry in a catalogue finish %s" % [prop.name, bad])
	print("  [V2 POSSESSED OBJECTS] %d mesh draws, %d triangles mounted" % [draws, triangles])


## Stands the player a step from the object, facing it, until the tell's own
## watch test sees it. Tries the object's front first, then the other sides.
func _stand_and_look(tell: Node) -> bool:
	var target: Node3D = tell.target
	var at := target.global_position
	var floor_y := floorf((at.y + 0.3) / 3.2) * 3.2
	var front := target.global_transform.basis.z
	if not (target is PossessedObject):
		front = (at - (target.get_parent() as Node3D).global_position).normalized()
	front.y = 0.0
	front = front.normalized()
	var player: Node3D = _world.player
	for turn: float in [0.0, 0.6, -0.6, PI * 0.5, -PI * 0.5, PI]:
		for reach: float in [1.1, 0.7]:
			var stand := at + front.rotated(Vector3.UP, turn) * reach
			stand.y = floor_y + 0.02
			for i in 12:
				player.global_position = stand
				player.camera.look_at(at)
				await get_tree().physics_frame
			player.global_position = stand
			player.camera.look_at(at)
			if tell._watched(player):
				return true
	return false


# -- photographs -----------------------------------------------------------
func _photograph(witnesses: Node) -> void:
	var dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	for layer in _world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	if _world.get("service_set_carrier") != null:
		_world.service_set_carrier.visible = false
	_world.player.set_physics_process(false)
	_world.player.set_lamp_enabled(false)
	var only := OS.get_environment("SHOT_ONLY")
	for id: String in NEW:
		if not only.is_empty() and not id.contains(only):
			continue
		var tell: Node = witnesses.tells[id]
		var target: Node3D = tell.target
		var at := target.global_position
		var front := target.global_transform.basis.z
		var centre := at
		var size := 0.4
		if target is PossessedObject:
			var extent: AABB = target.native.bounds(target.stock)
			centre = target.global_transform * extent.get_center()
			size = maxf(extent.size.length(), 0.16)
		else:
			front = (at - (target.get_parent() as Node3D).global_position).normalized()
		front.y = 0.0
		front = front.normalized()
		var floor_y := floorf((at.y + 0.3) / 3.2) * 3.2
		# Stand the player by the object too, so the room around it is live.
		_world.player.global_position = Vector3(at.x, floor_y + 0.02, at.z) + front * 1.2
		var views := [["room", front * 1.9 + Vector3.UP * (floor_y + 1.55 - centre.y)],
			["close", (front + Vector3.UP * 0.45 + front.cross(Vector3.UP) * 0.35).normalized() * size * 1.9]]
		for view: Array in views:
			_look = centre
			_eye = centre + (view[1] as Vector3)
			_framing = true
			for i in 30:
				await get_tree().process_frame
			await _shoot("%s/%s_%s.png" % [dir, id, view[0]])
		var case_id := A_CASE if (tell.case_ids as Array).is_empty() else str(tell.case_ids[0])
		tell.stage_haunt(case_id, 2, null)
		for i in 12:
			await get_tree().process_frame
		await _shoot("%s/%s_tell.png" % [dir, id])
		tell.restore()
	_framing = false


func _shoot(path: String) -> void:
	for i in 10:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _finish() -> void:
	var ok := _fails == 0
	print("[V2 POSSESSED OBJECTS] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	_framing = false
	if _world != null:
		if _world.has_method("shutdown_for_tests"):
			_world.shutdown_for_tests()
		remove_child(_world)
		_world.free()
		_world = null
	get_tree().quit(0 if ok else 1)
