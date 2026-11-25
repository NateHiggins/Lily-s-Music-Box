extends Node
## Headless bench for the service practicals' scope: a source sealed to its
## storey by slabs is dark and unshadowed to an eye on another storey, a source
## on a shaft is not, a neighbour a metre away still lights its own side, and
## switching the policy off gives every light back as authored.
const Policy := preload("res://scripts/building/orison_v2_service_light_visibility.gd")

var failures := 0
var checks := 0


class BenchAdapter extends RefCounted:
	var root: Node3D


class BenchPlayer extends Node3D:
	var camera: Camera3D


class BenchMirror extends Node:
	var camera: Camera3D
	func active_camera() -> Camera3D: return camera


class BenchWorld extends Node3D:
	var layout: Dictionary
	var adapter := BenchAdapter.new()
	var player: BenchPlayer
	var mirror_renderer: Node = null
	var view_override: Camera3D = null
	var context_room := ""
	func room_at_world(_point: Vector3) -> String: return context_room


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("SERVICE SCOPE CHECK: ", label, " = ", ok)


func _space(id: String, level: String, open := false) -> Dictionary:
	var row := {"id": id, "level": level, "class": "core" if open else "service"}
	if open:
		row.no_ceiling = true
		row.no_floor = true
	return row


func _run() -> void:
	var world := BenchWorld.new()
	world.layout = {
		"dimensions": {"floor_to_floor": 3.2},
		"spaces": [_space("F01_A", "F01"), _space("F01_B", "F01"), _space("F02_A", "F02"),
			_space("F02_B", "F02"), _space("F02_CORE", "F02", true), _space("lower_core", "F01", true),
			_space("bench_SERVICE_HALL", "F02"), _space("bench_SERVICE_CORE", "F02", true)],
		"openings": [
			{"id": "F01_SEALED", "connects": ["F01_A", "F01_B"], "shared_wall_owner": "x", "at": Vector3(0, 2.34, 0)},
			{"id": "F01_CROWDED", "connects": ["F01_A", "F01_B"], "shared_wall_owner": "x", "at": Vector3(0.8, 2.34, 0)},
			{"id": "F01_OMITTED", "connects": ["F01_A", "F01_B"], "shared_wall_owner": "x", "omit": true},
			{"id": "F02_SEALED", "connects": ["F02_A", "F02_B"], "shared_wall_owner": "x", "at": Vector3(0, 5.54, 0)},
			{"id": "F02_SHAFT", "connects": ["F02_B", "F02_CORE"], "shared_wall_owner": "x", "at": Vector3(2.5, 5.54, 0)},
			{"id": "qualified_shaft_fixture", "connects": ["bench_SERVICE_HALL", "bench_SERVICE_CORE"], "shared_wall_owner": "x", "at": Vector3(1.8, 5.54, 0)},
			{"id": "lower_core_link", "connects": ["F01_B", "lower_core"]},
		],
		"doors": [],
	}
	add_child(world)
	var root := Node3D.new()
	world.add_child(root)
	world.adapter.root = root
	var lights := {}
	for opening: Dictionary in world.layout.openings:
		var anchor := Node3D.new()
		anchor.name = str(opening.id)
		root.add_child(anchor)
		if not opening.has("shared_wall_owner"):
			continue
		if opening.get("omit", false):
			anchor.set_meta("service_practical_omitted", true)
			continue
		var practical := Node3D.new()
		practical.name = "ServicePractical"
		anchor.add_child(practical)
		var light := OmniLight3D.new()
		light.name = "WarmServiceLight"
		light.shadow_enabled = true
		light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
		practical.add_child(light)
		light.global_position = opening.at
		lights[str(opening.id)] = light
	world.player = BenchPlayer.new()
	world.add_child(world.player)
	var camera := Camera3D.new()
	world.player.add_child(camera)
	world.player.camera = camera
	camera.make_current()

	var policy := Policy.new()
	world.add_child(policy)
	check(policy.setup(world), "the policy binds every authored bench source")
	check(policy.sources.size() == 5 and policy.edges.size() == 7, "an unlit opening stays in the room graph")
	var by_id := {}
	for source: Dictionary in policy.sources:
		by_id[source.id] = source
	check(not by_id.F01_SEALED.shaft and not by_id.F02_SEALED.shaft and by_id.F02_SHAFT.shaft, "sealed and shaft sources told apart by their rooms")
	check(policy.level_at(Vector3(0, 4.6, 0)) == "F02" and policy.level_at(Vector3(0, 1.4, 0)) == "F01" and policy.level_at(Vector3(0, -1.6, 0)) == "B1", "storeys come from the slab pitch")

	# An eye on F02, close enough to every source that distance alone kept them.
	camera.global_position = Vector3(0, 4.6, 3)
	policy.set_enabled(true)
	check(policy.conservative, "an unknown room is the conservative case the gate is for")
	var f01: OmniLight3D = lights.F01_SEALED
	var crowded: OmniLight3D = lights.F01_CROWDED
	var f02: OmniLight3D = lights.F02_SEALED
	var shaft: OmniLight3D = lights.F02_SHAFT
	check(f01.global_position.distance_to(camera.global_position) < 8.0, "the sealed F01 source is within the old 8 m reach")
	check(not f01.visible and not f01.shadow_enabled, "a source sealed below the eye's storey is dark and unshadowed")
	check(not crowded.visible and not crowded.shadow_enabled, "its sealed neighbour is dark below the eye's storey too")
	check(f02.visible and f02.shadow_enabled, "a sealed source on the eye's storey keeps light and shadow")
	check(shaft.visible and shaft.shadow_enabled, "a shaft source keeps light and shadow on its own storey")

	# The same eye walks down a storey.
	camera.global_position = Vector3(0, 1.4, 3)
	policy.distance_budget.tick()
	check(f01.visible and f01.shadow_enabled, "the sealed F01 source lights the storey it belongs to")
	check(crowded.visible and crowded.shadow_enabled, "a neighbour a metre away still lights its own side")
	check(not f02.visible and not f02.shadow_enabled, "a source sealed above the eye's storey is dark and unshadowed")
	check(shaft.visible and shaft.shadow_enabled, "a shaft source is still seen from the storey below")

	var qualified_shaft: OmniLight3D = lights.qualified_shaft_fixture
	check(qualified_shaft.omni_shadow_mode == OmniLight3D.SHADOW_CUBE,
		"the unknown-room case retains the original shadow map")
	world.context_room = "F01_A"
	policy._poll()
	check(qualified_shaft.visible and qualified_shaft.shadow_enabled and qualified_shaft.omni_shadow_mode == OmniLight3D.SHADOW_DUAL_PARABOLOID,
		"the named shaft practical keeps light and shadow with the adjacent-storey map")
	check(shaft.omni_shadow_mode == OmniLight3D.SHADOW_CUBE, "unmeasured shaft lights keep their original map")

	var mirror := BenchMirror.new()
	world.add_child(mirror)
	mirror.camera = Camera3D.new()
	mirror.add_child(mirror.camera)
	mirror.camera.global_position = Vector3(0, 4.6, 3)
	world.mirror_renderer = mirror
	policy.distance_budget.tick()
	check(qualified_shaft.omni_shadow_mode == OmniLight3D.SHADOW_CUBE,
		"a reflection on the practical's storey retains its original map")
	world.mirror_renderer = null
	mirror.queue_free()

	camera.global_position = Vector3(0, 4.6, 3)
	world.context_room = "F02_B"
	policy._poll()
	check(qualified_shaft.omni_shadow_mode == OmniLight3D.SHADOW_CUBE,
		"walking to the practical's own storey retains its original map")
	camera.global_position = Vector3(0, 1.4, 3)
	world.context_room = "F01_A"
	policy._poll()
	check(qualified_shaft.omni_shadow_mode == OmniLight3D.SHADOW_DUAL_PARABOLOID,
		"returning across storeys reinstates the lighter map")
	policy.set_enabled(false)
	check(qualified_shaft.omni_shadow_mode == OmniLight3D.SHADOW_CUBE,
		"disabling the policy restores the authored shadow map")
	var restored := true
	for light: OmniLight3D in lights.values():
		restored = restored and light.visible and light.shadow_enabled
	check(restored, "switching the policy off gives every light back as authored")

	world.queue_free()
	await get_tree().process_frame
	print("SERVICE SCOPE RESULT: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
