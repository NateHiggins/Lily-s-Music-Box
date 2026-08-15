extends Node
## Room-by-room lighting audit. Moves an inspection camera through every
## semantic space, verifies intended fixture coverage and asks the LightRig
## to assign its local shadow budget at each stop.

const LIT_KINDS := {
	"living": true, "bedroom": true, "alcove": true, "kitchen": true,
	"bathroom": true, "office": true, "common": true, "storage": true,
	"utility": true, "laundry": true, "boiler": true, "electrical": true,
	"storage_cages": true, "coal": true, "lobby": true, "hall": true,
	"atrium": true, "corridor": true,
}

var root: Node3D
var cam: Camera3D
var failures := 0
var spaces := 0
var intentionally_dark := 0


func _ready() -> void:
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(0.8).timeout
	root.show_all_floors = true
	cam = Camera3D.new()
	add_child(cam)
	cam.make_current()
	# Hand the rig this camera. Without it BuildingRoot keeps budgeting light
	# around the player parked in the lobby while this camera visits every room
	# in the building, so each room is lit only by its standby floor - and
	# dwelling fixtures have no standby, only circulation does. The result is
	# bathrooms and corridors that read normally and living rooms that are 97%
	# black, which looks exactly like a lighting bug and is not one.
	#
	# perf_probe.gd learned this and wrote it down; the lesson never reached the
	# other camera tools.
	root.view_override = cam
	await _audit()


func _audit() -> void:
	var fixtures := get_tree().get_nodes_in_group("light_fixtures")
	var catalog_fixtures := fixtures.filter(
			func(fixture): return fixture is LightFixtureProp)
	var mapped: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/fixture_light_map.json"))
	_check(mapped is Dictionary and int(mapped.get("fixture_count", -1)) ==
			catalog_fixtures.size(),
			"fixture light map covers all %d catalog fixtures" %
			catalog_fixtures.size())
	var incompatible_shadow_modes := 0
	var weak_shadow_settings := 0
	var dead_navigation_fixtures := 0
	for fixture in fixtures:
		if fixture.navigation_light and fixture.standby_scale < 0.20:
			dead_navigation_fixtures += 1
		if fixture.light and \
				fixture.light.omni_shadow_mode != OmniLight3D.SHADOW_CUBE:
			incompatible_shadow_modes += 1
		# The provenance pass (tools/author_light_provenance.py) authors
		# per-fixture shadow_opacity in [0.86, 1.0] as personality; the
		# audit floor sits just under that range. Below it, shadows wash
		# out under ambient fill — the original sin this check guards.
		if fixture.light and (fixture.light.shadow_opacity < 0.85 or
				fixture.light.shadow_bias > 0.02 or
				fixture.light.shadow_normal_bias > 0.12):
			weak_shadow_settings += 1
			print("  [light weak] %s (%s): opacity=%.2f bias=%.3f nbias=%.3f"
					% [fixture.name, fixture.prop_type,
					fixture.light.shadow_opacity, fixture.light.shadow_bias,
					fixture.light.shadow_normal_bias])
	_check(incompatible_shadow_modes == 0,
			"all omni lights use Compatibility-safe cubemap shadows")
	_check(weak_shadow_settings == 0,
			"all omni lights use visible contact-shadow settings")
	_check(dead_navigation_fixtures == 0,
			"every navigation fixture has an authored standby contribution")
	_audit_street_shadow_gate(fixtures)
	for fl in root.layout["floors"]:
		var floor_id: String = fl["id"]
		var floor_y: float = float(fl["z"])
		for room in fl["rooms"]:
			spaces += 1
			var kind: String = room["kind"]
			var unit: String = room.get("unit", "")
			var rect: Array = room["rect"]
			var cx: float = (float(rect[0]) + float(rect[2])) * 0.5
			var cy: float = (float(rect[1]) + float(rect[3])) * 0.5
			cam.global_position = GameBoot.b2g([
					cx, cy, floor_y + PlayerController.STANDING_EYE])
			# LightRig deliberately derives the active storey from the player's
			# feet, not from whichever debug camera happens to be current. The
			# old audit moved only this camera, leaving the player in F01, then
			# reported every F02-F06 fixture correctly gated off as a failure.
			# Move the occupant and inspection eye together: this now tests the
			# real contract at each room instead of bypassing its storey input.
			root.player.global_position = GameBoot.b2g([
					cx, cy, floor_y + 0.05])
			root.light_rig._process(1.0)
			_check(root.light_rig.active_floor == floor_id,
					"%s/%s selects its active floor" % [floor_id, room["id"]])

			var local_fixtures: Array[Node] = []
			for fixture in fixtures:
				var px: float = fixture.global_position.x
				var py: float = -fixture.global_position.z
				var pz: float = fixture.global_position.y
				if px >= float(rect[0]) - 0.08 and \
						px <= float(rect[2]) + 0.08 and \
						py >= float(rect[1]) - 0.08 and \
						py <= float(rect[3]) + 0.08 and \
						pz >= floor_y + 1.0 and pz <= floor_y + 3.10:
					local_fixtures.append(fixture)

			# 2D is sealed and 5D is fire-gutted by design; both explicitly
			# omit electrical fixtures in the layout generator.
			if LIT_KINDS.has(kind) and unit not in ["2D", "5D"]:
				_check(not local_fixtures.is_empty(),
						"%s/%s has a placed fixture" % [floor_id, room["id"]])
				var local_shadow := false
				for fixture in local_fixtures:
					if fixture.light and fixture.light.shadow_enabled:
						local_shadow = true
						break
				_check(local_shadow,
						"%s/%s receives a local shadow caster" %
						[floor_id, room["id"]])
			else:
				intentionally_dark += 1

	var moon := root.get_node_or_null("ExteriorMoon") as DirectionalLight3D
	_check(moon != null and moon.shadow_enabled,
			"roof/exterior directional shadow caster enabled")
	print("LIGHTING AUDIT: %d spaces, %d intentionally ambient/dark, %s" %
			[spaces, intentionally_dark,
			"PASS" if failures == 0 else "FAIL (%d)" % failures])
	await _cleanup()
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [light ok] ", label)
	else:
		failures += 1
		printerr("  [LIGHT FAIL] ", label)


func _cleanup() -> void:
	_stop_audio(root)
	root.queue_free()
	cam.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	PropAudio.clear_cache()
	await get_tree().process_frame


func _audit_street_shadow_gate(fixtures: Array) -> void:
	# Production player/lens together on the north pavement. The exterior gate
	# must preserve illumination and exterior shadows while declining only the
	# Orison core's off-zone shadow maps.
	cam.global_position = Vector3(-16.0, 1.68, 13.5)
	root.player.global_position = cam.global_position - Vector3(0.0,
			PlayerController.STANDING_EYE, 0.0)
	root.light_rig._accum = LightRig.INTERVAL
	root.light_rig._process(LightRig.INTERVAL)
	var core_fixtures: Array = fixtures.filter(func(fixture):
		var source: Light3D = fixture.light
		return source != null \
				and absf(source.global_position.x) <= LightRig.ORISON_CORE_HALF_X \
				and absf(source.global_position.z) <= LightRig.ORISON_CORE_HALF_Z)
	var exterior_lit: Array = fixtures.filter(func(fixture):
		var source: Light3D = fixture.light
		return source != null and source.visible and source.light_energy > 0.05 \
				and (absf(source.global_position.x) > LightRig.ORISON_CORE_HALF_X \
				or absf(source.global_position.z) > LightRig.ORISON_CORE_HALF_Z))
	_check(not core_fixtures.is_empty(),
			"STREET finds authored Orison-core fixtures to gate")
	_check(core_fixtures.all(
			func(fixture): return not fixture.light.shadow_enabled),
			"STREET suppresses only Orison-core fixture shadow maps")
	_check(exterior_lit.any(func(fixture): return fixture.light.shadow_enabled),
			"STREET retains a local exterior fixture shadow caster")

	# Walk back into the lobby: the same owner restores the ordinary ranked
	# shadow budget on its next update, with no saved-state table to go stale.
	cam.global_position = Vector3(-0.4, 1.68, 9.1)
	root.player.global_position = cam.global_position - Vector3(0.0,
			PlayerController.STANDING_EYE, 0.0)
	root.light_rig._accum = LightRig.INTERVAL
	root.light_rig._process(LightRig.INTERVAL)
	_check(core_fixtures.any(
			func(fixture): return fixture.light.shadow_enabled),
			"entering ORISON restores ranked core fixture shadows")


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children(true):
		_stop_audio(child)
