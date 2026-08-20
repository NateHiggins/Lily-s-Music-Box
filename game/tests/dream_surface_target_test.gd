extends Node
## OWNER TARGET: animated dark-live tentacles and remembered Orison contents.
##
## The render judges the look. This proves the facts it cannot: the gold has a
## bounded dark state, the motion never stops with the lamp, every dangerous
## growth maps back to the existing hazard owner, and furnishing contains only
## extracted production meshes rather than waking gameplay systems.

const EXPECTED_CHECKS := 47
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
	_interior_contract()
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
	var layers: PackedStringArray = growth.get_meta("material_layers",
			PackedStringArray()) if growth else PackedStringArray()
	_check("the organism exposes reusable tissue wet-film and gold layers",
			layers == PackedStringArray([
			"subsurface_tissue", "wet_microfilm", "living_gold"]))
	_check("the layered substrate is tuned as tissue rather than a gold coat",
			material != null
			and float(material.get_shader_parameter("organic_mix")) >= 0.90
			and float(material.get_shader_parameter("tissue_transmission")) > 0.0
			and float(material.get_shader_parameter("wet_specular_gain")) > 0.0
			and float(material.get_shader_parameter("gold_vessel_width")) >= 0.94)
	var glow := float(material.get_shader_parameter("dark_glow")) \
			if material else 0.0
	_check("darkness retains a nonzero but subordinate biological glow",
			glow > 0.0 and glow <= 0.68)
	_check("motion is slow continuous deformation, never a flash",
			material != null
			and is_equal_approx(float(material.get_shader_parameter("motion_hz")),
			0.13) and float(material.get_shader_parameter("motion_gain")) == 1.0)
	var eye_records: Array = growth.get_meta("eye_records", []) if growth else []
	_check("the batched anatomy carries five composed eyes per danger",
			growth != null and int(growth.get_meta("eyes", 0)) == ids.size() * 5
			and eye_records.size() == int(growth.get_meta("eyes", 0)))
	_check("the geometry publishes the deterministic eye-family contract",
			growth != null
			and str(growth.get_meta("eye_family", ""))
			== "seeded_compositional_v1"
			and growth.get_meta("eye_debug_views", PackedStringArray())
			== PackedStringArray([
				"beauty", "rest_and_tracking", "gaze_target"]))
	var records_valid := true
	var ids_unique: Dictionary = {}
	var per_hazard: Dictionary = {}
	var gaze_modes: Dictionary = {}
	var closed_or_half := 0
	var direct_trackers := 0
	for eye_value in eye_records:
		var eye: Dictionary = eye_value
		var eye_id := str(eye.get("id", ""))
		var hazard_id := str(eye.get("hazard_id", ""))
		var rest_state := str(eye.get("rest_state", ""))
		var gaze_mode := str(eye.get("gaze_mode", ""))
		records_valid = records_valid and not eye_id.is_empty() \
				and not ids_unique.has(eye_id) and hazard_id in ids \
				and eye.get("anchor") is Vector3 \
				and eye.get("target") is Vector3 \
				and eye.get("forward") is Vector3 \
				and is_equal_approx((eye.forward as Vector3).length(), 1.0) \
				and float(eye.get("scale", 0.0)) >= 0.76 \
				and float(eye.get("scale", 9.0)) <= 1.341 \
				and float(eye.get("blink_phase", -1.0)) >= 0.0 \
				and float(eye.get("blink_phase", 2.0)) <= 1.0 \
				and float(eye.get("blink_hz", 0.0)) >= 0.045 \
				and float(eye.get("blink_hz", 1.0)) <= 0.074 \
				and rest_state in ["closed", "half_lidded", "open"] \
				and gaze_mode in [
					"hazard_root", "branch_tip", "room_center", "camera"] \
				and absf(float(eye.get("roll_rad", 9.0))) <= deg_to_rad(14.01)
		ids_unique[eye_id] = true
		per_hazard[hazard_id] = int(per_hazard.get(hazard_id, 0)) + 1
		gaze_modes[gaze_mode] = true
		if rest_state in ["closed", "half_lidded"]:
			closed_or_half += 1
		if gaze_mode == "camera":
			direct_trackers += 1
	_check("every eye owns a valid seeded scale blink frame and gaze record",
			records_valid and ids_unique.size() == eye_records.size())
	var five_each := per_hazard.size() == ids.size()
	for hazard_id_value in ids:
		five_each = five_each and int(per_hazard.get(hazard_id_value, 0)) == 5
	_check("eye anchors remain sparse and evenly composed across live dangers",
			five_each)
	_check("closed and half-lidded resting states dominate the family",
			closed_or_half == ids.size() * 4
			and closed_or_half == int(growth.get_meta(
			"eyes_closed_or_half", -1)))
	_check("direct camera attention is a single sparse event",
			direct_trackers == 1
			and direct_trackers == int(growth.get_meta(
			"eyes_tracking_camera", -1))
			and gaze_modes.has("hazard_root")
			and gaze_modes.has("branch_tip")
			and gaze_modes.has("room_center"))
	_check("the production material exposes but does not force eye diagnostics",
			material != null
			and int(material.get_shader_parameter("eye_debug_view")) == 0)
	_check("load-bearing limbs become wall grafts rather than ending in air",
			growth != null and int(growth.get_meta("wall_membranes", 0))
			>= ids.size() * 3)
	_check("fine wall capillaries stay in the same batched surface",
			growth != null and int(growth.get_meta("visual_capillaries", 0))
			== int(growth.get_meta("wall_membranes", 0)) * 7)

	var duplicate := HazardGrowthScript.new()
	duplicate.configure(root.hazards.hazards, root.plan)
	_check("the same pocket reconstructs the same dangerous body",
			duplicate.mesh != null and growth != null
			and duplicate.mesh.surface_get_array_len(0)
			== growth.mesh.surface_get_array_len(0)
			and duplicate.get_aabb().is_equal_approx(growth.get_aabb())
			and duplicate.get_meta("eye_records", []) == eye_records)
	duplicate.free()
	var contacted_in_dark := false
	if contact_owner != null:
		contact_owner.evaluate(remote_contact, false, 4.6,
				root.hazards.elapsed_s + 1.0)
		contacted_in_dark = contact_owner.contacted
	_check("the existing hazard owner commits limb contact in darkness",
			contacted_in_dark)


func _interior_contract() -> void:
	var world_environment := root.get_node_or_null("DreamEnvironment") \
			as WorldEnvironment
	var ambient := world_environment.environment if world_environment else null
	_check("the cool photographic lift is present but below practical light",
			ambient != null
			and ambient.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR
			and ambient.ambient_light_energy > 0.0
			and ambient.ambient_light_energy <= 0.181
			and ambient.ambient_light_sky_contribution <= 0.001)
	var black_level := root.player.get_node_or_null("DreamBlackLevel") \
			as OmniLight3D
	_check("a bounded carried black level photographs only the near Orison",
			black_level != null and black_level.omni_range <= 5.01
			and black_level.light_energy <= 1.46
			and not black_level.shadow_enabled)
	var practicals: Array = root.get("_practicals")
	var practicals_bounded := not practicals.is_empty()
	for practical in practicals:
		practicals_bounded = practicals_bounded \
				and (practical as OmniLight3D).omni_range <= 8.51 \
				and (practical as OmniLight3D).light_energy <= 1.36 \
				and not (practical as OmniLight3D).shadow_enabled
	_check("warm practical islands stay bounded and shadow-free",
			practicals_bounded)
	var rooms := root.rooms.live_rooms()
	var interiors := root.find_children("OrisonInterior", "Node3D", true,
			false)
	_check("every live generation carries an Orison architecture decision",
			interiors.size() == rooms.size())
	var nonblank := 0
	var described := 0
	var blank_honest := true
	var bounded_draws := true
	var forbidden := 0
	var dimensions_exact := true
	var casings_exact := true
	var shader_surfaces := 0
	var relief_vocabulary_exact := true
	var anchors_exact := true
	var interior_materials_bound := true
	var shell_materials_bound := true
	var relief_meter_bounded := true
	for interior in interiors:
		var key := str(interior.get_meta("room_key", ""))
		var room: Dictionary = root.rooms.room_at_key(key)
		var millwork := int(interior.get_meta("millwork_instances", 0))
		var panels := int(interior.get_meta("wainscot_instances", 0))
		var visuals := interior.find_children("*", "MultiMeshInstance3D",
				true, false)
		if bool(room.get("blank", false)):
			blank_honest = blank_honest and millwork == 0 and panels == 0 \
					and visuals.is_empty()
		else:
			nonblank += 1
			if millwork > 0 and not visuals.is_empty():
				described += 1
		bounded_draws = bounded_draws and visuals.size() <= 2
		forbidden += interior.find_children("*", "CollisionObject3D", true,
				false).size()
		forbidden += interior.find_children("*", "Light3D", true, false).size()
		forbidden += interior.find_children("*", "AudioStreamPlayer3D", true,
				false).size()
		dimensions_exact = dimensions_exact \
				and (millwork == 0 or is_equal_approx(
				float(interior.get_meta("dado_height_m", 0.0)), 1.32)) \
				and float(interior.get_meta("max_relief_m", 1.0)) <= 0.055
		var open_doors := 0
		for door in room.get("doors", []):
			if not bool(door.get("sealed", false)):
				open_doors += 1
		casings_exact = casings_exact and (millwork == 0 \
				or int(interior.get_meta("door_casings", -1)) == open_doors)
		if millwork > 0:
			relief_vocabulary_exact = relief_vocabulary_exact \
					and interior.get_meta("shader_relief_layers",
					PackedStringArray()) == PackedStringArray([
					"tessera_faces", "recessed_grout", "cracked_medallions"])
			anchors_exact = anchors_exact and interior.get_meta(
					"transition_anchors", PackedStringArray()) \
					== PackedStringArray([
					"floor_wall_joints", "room_corners", "skirting", "dado",
					"picture_rail", "cornice", "door_casings", "ceiling_rose"])
			relief_meter_bounded = relief_meter_bounded \
					and float(interior.get_meta("shader_relief_max_m", 1.0)) \
					<= 0.0421
		for visual in visuals:
			var material := (visual as GeometryInstance3D).material_override \
					as ShaderMaterial
			if material != null and material.shader != null \
					and not material.shader.get_shader_uniform_list().is_empty():
				shader_surfaces += 1
				var surface_kind := int(material.get_shader_parameter(
						"architecture_surface"))
				var bounds: Vector4 = material.get_shader_parameter(
						"architecture_bounds")
				interior_materials_bound = interior_materials_bound \
						and surface_kind in [4, 5] \
						and bounds.is_equal_approx(Vector4(float(room.rect[0]),
						float(room.rect[1]), float(room.rect[2]),
						float(room.rect[3]))) \
						and is_equal_approx(float(material.get_shader_parameter(
						"architecture_clear_ceiling")), 3.015) \
						and float(material.get_shader_parameter(
						"architecture_pull")) > 0.0
				relief_meter_bounded = relief_meter_bounded \
						and float(material.get_shader_parameter(
						"tessera_relief_m")) <= 0.0121 \
						and float(material.get_shader_parameter(
						"medallion_relief_m")) <= 0.0421 \
						and int(material.get_shader_parameter(
						"surface_debug_view")) in [0, 1, 2, 3]
		# The collision shells stay authoritative; their child render meshes now
		# share the room bounds but identify the architectural class they own.
		var expected_shell_classes := {
			"Floor": 2, "Ceiling": 3, "Wall": 1, "Lintel": 6,
			"Shaft": 7,
		}
		for body_value in interior.get_parent().get_children():
			var body := body_value as StaticBody3D
			if body == null:
				continue
			var expected_kind := -1
			for prefix in expected_shell_classes:
				if body.name.begins_with(str(prefix)):
					expected_kind = int(expected_shell_classes[prefix])
					break
			if expected_kind < 0:
				continue
			var meshes := body.find_children("*", "MeshInstance3D", true, false)
			if meshes.is_empty():
				shell_materials_bound = false
				continue
			var shell_material := (meshes[0] as MeshInstance3D).material_override \
					as ShaderMaterial
			if shell_material == null:
				shell_materials_bound = false
				continue
			var shell_bounds: Vector4 = shell_material.get_shader_parameter(
					"architecture_bounds")
			shell_materials_bound = shell_materials_bound \
					and int(shell_material.get_shader_parameter(
					"architecture_surface")) == expected_kind \
					and shell_bounds.is_equal_approx(Vector4(float(room.rect[0]),
					float(room.rect[1]), float(room.rect[2]),
					float(room.rect[3]))) \
					and is_equal_approx(float(shell_material.get_shader_parameter(
					"architecture_clear_ceiling")), 3.015) \
					and float(shell_material.get_shader_parameter(
					"architecture_pull")) > 0.0
	_check("every remembered nonblank room has historic millwork relief",
			nonblank > 0 and described == nonblank)
	_check("blanking also removes the descriptive architectural relief",
			blank_honest)
	_check("millwork and wainscot cost no more than two draws per room",
			bounded_draws)
	_check("architectural relief owns no collision, light or sound",
			forbidden == 0)
	_check("the Orison's 1.32 m dado is shallow visual relief",
			dimensions_exact)
	_check("cased openings follow the authoritative live door schedule",
			casings_exact)
	_check("the service lamp reaches the batched historic materials",
			shader_surfaces > 0)
	_check("R2 exposes tessera grout and cracked-medallion relief as one vocabulary",
			relief_vocabulary_exact)
	_check("growth is biased only to named Orison construction anchors",
			anchors_exact)
	_check("batched millwork and panels carry their authoritative room bounds",
			interior_materials_bound)
	_check("wall floor ceiling door and shaft materials carry the same room bounds",
			shell_materials_bound)
	_check("parallax relief stays shallow meter-valued and diagnostically switchable",
			relief_meter_bounded)


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
