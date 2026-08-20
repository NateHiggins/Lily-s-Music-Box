extends Node
## OWNER TARGET: animated dark-live tentacles and remembered Orison contents.
##
## The render judges the look. This proves the facts it cannot: the gold has a
## bounded dark state, the motion never stops with the lamp, every dangerous
## growth maps back to the existing hazard owner, and furnishing contains only
## extracted production meshes rather than waking gameplay systems.

const EXPECTED_CHECKS := 21
const HazardGrowthScript := preload(
		"res://scripts/dream/dream_hazard_growth.gd")

var checks := 0
var failures := 0
var finished := false
var root: DreamMazeRoot


func _ready() -> void:
	_watchdog()
	await _build()
	_growth_contract()
	_furnishing_contract()
	if checks != EXPECTED_CHECKS:
		failures += 1
		printerr("[DREAM TARGET] HARNESS FAIL: %d checks, expected %d"
				% [checks, EXPECTED_CHECKS])
	finished = true
	print("DREAM SURFACE TARGET TEST: %s (%d checks)" % [
			"PASS" if failures == 0 else "FAIL %d" % failures, checks])
	get_tree().quit(failures)


func _watchdog() -> void:
	await get_tree().create_timer(50.0, true, false, true).timeout
	if not finished:
		printerr("[DREAM TARGET] WATCHDOG: exceeded 50 seconds")
		get_tree().quit(1)


func _build() -> void:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	root = scene.instantiate() as DreamMazeRoot
	root.autonomous = false
	root.configure_dream({
		"case_id": "mina_caption_crisis",
		"profile_id": "mina_release_print",
		"window": {},
		"seed_hex": "f123456789abcdef",
		"maze_revision": 1,
		"outcome": "",
		"night_index": 7,
		"spawn_anchor": 0,
	})
	add_child(root)
	await get_tree().process_frame
	root.player.set_physics_process(false)
	root.pursuer.set_physics_process(false)
	root.set_physics_process(false)
	_stage_target_pocket()
	# DreamRoomBuilder retires forgotten rooms with queue_free(). Judge the
	# live pocket after that queue has drained, not while both generations are
	# present for the remainder of this frame.
	await get_tree().process_frame


## The campaign spawn is intentionally arbitrary and need not contain a
## hazard at all. Select a deterministic descendant whose live neighbourhood
## carries at least two of Mina's dark-live sockets, then ask the production
## pocket and field owners to perform the same rebuild a threshold crossing
## would. This stages content; it does not manufacture geometry or danger.
func _stage_target_pocket() -> void:
	var atlas: DreamAtlas = root.rooms.atlas
	var queue: Array[PackedInt32Array] = [PackedInt32Array()]
	var chosen := PackedInt32Array()
	var found := false
	var examined := 0
	while not queue.is_empty() and examined < 2400:
		var path: PackedInt32Array = queue.pop_front()
		var room: Dictionary = atlas.room(path)
		var dark_sources := 1 if _source_is_dark_hazard(str(room.source)) else 0
		for door_index in int(room.doors):
			var child := DreamAtlas.step(path, door_index)
			var child_room: Dictionary = atlas.room(child)
			if _source_is_dark_hazard(str(child_room.source)):
				dark_sources += 1
			if path.size() < 8:
				queue.append(child)
		if dark_sources >= 2:
			chosen = path
			found = true
			break
		examined += 1
	if not found:
		return
	var key := DreamRoomBuilder.key_of(chosen)
	root.rooms.advance(root.get("_architecture") as Node3D, chosen)
	root.rooms.write_plan(root.plan, key)
	root.set("_here_path", chosen)
	root.set("_here_key", key)
	root.hazards.rearm(root.plan, root.profile_hazards)
	root.call("_rebuild_hazard_growth")


func _source_is_dark_hazard(source: String) -> bool:
	return source in ["D01_F04_LONG_HALL", "D03_LIFT_VOID"]


func _growth_contract() -> void:
	var growth := root.get("_hazard_growth") as MeshInstance3D
	_check("production root builds the dark-live growth", growth != null)
	var ids: Array = growth.get_meta("hazard_ids", []) if growth else []
	_check("the target seed carries plural tentacled sections", ids.size() >= 2)
	_check("all sections are fused into one populated surface",
			growth != null and growth.mesh != null
			and growth.mesh.get_surface_count() == 1
			and int(growth.get_meta("surfaces", 0)) == 1)
	_check("the surface adds no collision owner",
			growth != null and growth.find_children("*", "CollisionObject3D",
			true, false).is_empty())
	var mapped := 0
	var all_dark_live := true
	var min_radius := INF
	var paths_registered := 0
	var remote_limb_contacts := false
	var remote_contact := Vector3.ZERO
	var contact_owner: DreamHazard = null
	for hazard in root.hazards.hazards:
		if ids.has(hazard.id):
			mapped += 1
			all_dark_live = all_dark_live \
					and hazard.condition != "lamp_on" \
					and hazard._condition_live(false, 4.6)
			min_radius = minf(min_radius, hazard.clearance_radius)
			paths_registered += hazard.contact_paths.size()
			for path in hazard.contact_paths:
				for point in path:
					var at_floor := Vector3(point.x, 0.0, point.z)
					if point.y < 1.35 \
							and at_floor.distance_to(hazard.position) \
							> hazard.clearance_radius * 1.45 \
							and hazard._touches_contact_path(at_floor):
						remote_limb_contacts = true
						remote_contact = at_floor
						contact_owner = hazard
						break
	_check("every visible section maps to one authoritative live hazard",
			mapped == ids.size())
	_check("switching the lamp off does not disarm these sections",
			all_dark_live)
	_check("every substantial tendril is registered with the hazard owner",
			growth != null and paths_registered
			== int(growth.get_meta("contact_paths", -1)))
	_check("a limb beyond the old root radius remains real contact",
			remote_limb_contacts)
	_check("the visual sway stays inside the owner's static contact margin",
			growth != null and float(growth.get_meta("max_sway_m", 1.0))
			< min_radius * 0.20)
	var material := growth.material_override as ShaderMaterial if growth else null
	_check("the shared gold shader compiled on the growth",
			material != null and material.shader != null
			and not material.shader.get_shader_uniform_list().is_empty())
	var glow := float(material.get_shader_parameter("dark_glow")) \
			if material else 0.0
	_check("darkness retains a nonzero but subordinate biological glow",
			glow > 0.0 and glow <= 0.68)
	_check("motion is slow continuous deformation, never a flash",
			material != null
			and is_equal_approx(float(material.get_shader_parameter("motion_hz")),
			0.13) and float(material.get_shader_parameter("motion_gain")) == 1.0)
	_check("the batched anatomy carries eyes without extra surfaces",
			growth != null and int(growth.get_meta("eyes", 0)) >= ids.size() * 4)

	var duplicate := HazardGrowthScript.new()
	duplicate.configure(root.hazards.hazards, root.plan)
	_check("the same pocket reconstructs the same dangerous body",
			duplicate.mesh != null and growth != null
			and duplicate.mesh.surface_get_array_len(0)
			== growth.mesh.surface_get_array_len(0)
			and duplicate.get_aabb().is_equal_approx(growth.get_aabb()))
	duplicate.free()
	var contacted_in_dark := false
	if contact_owner != null:
		contact_owner.evaluate(remote_contact, false, 4.6,
				root.hazards.elapsed_s + 1.0)
		contacted_in_dark = contact_owner.contacted
	_check("the existing hazard owner commits limb contact in darkness",
			contacted_in_dark)


func _furnishing_contract() -> void:
	var rooms := root.rooms.live_rooms()
	var furnishing_nodes := root.find_children("OrisonFurnishing", "Node3D",
			true, false)
	_check("every live generation carries a furnishing decision",
			furnishing_nodes.size() == rooms.size())
	var nonblank := 0
	var populated := 0
	var source_meshes := 0
	var waking_owners := 0
	var forbidden_nodes := 0
	for furnishing in furnishing_nodes:
		var count := int(furnishing.get_meta("production_prop_count", 0))
		var key := str(furnishing.get_meta("room_key", ""))
		var room: Dictionary = root.rooms.room_at_key(key)
		if not bool(room.get("blank", false)):
			nonblank += 1
			if count > 0:
				populated += 1
		for visual in furnishing.get_children():
			if str(visual.get_meta("source_script", "")).begins_with(
					"res://scripts/props/"):
				source_meshes += visual.find_children("*", "MeshInstance3D",
						true, false).size()
		waking_owners += furnishing.find_children("*", "FunctionalProp",
				true, false).size()
		forbidden_nodes += furnishing.find_children("*", "CollisionObject3D",
				true, false).size()
		forbidden_nodes += furnishing.find_children("*", "Light3D",
				true, false).size()
		forbidden_nodes += furnishing.find_children("*", "AudioStreamPlayer3D",
				true, false).size()
	_check("every remembered nonblank room is visibly furnished",
			nonblank > 0 and populated == nonblank)
	_check("furnishings are extracted from production Orison prop scripts",
			source_meshes > 0)
	_check("no waking FunctionalProp owner crosses into the dream",
			waking_owners == 0)
	_check("no borrowed interaction, collision, light or sound crosses over",
			forbidden_nodes == 0)
	var armed_records := 0
	for record in root.plan.get("hazards", []):
		if bool(record.get("armed", false)):
			armed_records += 1
	_check("growth adds no second hazard population",
			root.hazards.hazards.size() == armed_records)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  ok   %s" % label)
	else:
		failures += 1
		printerr("  FAIL %s" % label)
