extends Node
## Headless bench for the far-light shadow owner: a street or vestibule light
## keeps its shadow only near an eye (and, indoors, on the eye's storey), never
## loses its light, fades its shadow natively over the last metres, and gets
## everything back as authored when the owner is switched off.
const Policy := preload("res://scripts/building/orison_v2_far_light_shadows.gd")

var failures := 0
var checks := 0


class BenchAdapter extends RefCounted:
	var root: Node3D


class BenchPlayer extends Node3D:
	var camera: Camera3D


class BenchWorld extends Node3D:
	var layout := {"dimensions": {"floor_to_floor": 3.2}}
	var adapter := BenchAdapter.new()
	var exterior_cell: Node3D
	var player: BenchPlayer
	var mirror_renderer: Node = null


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("FAR LIGHT CHECK: ", label, " = ", ok)


func _light(parent: Node3D, at: Vector3, shadow := true) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.shadow_enabled = shadow
	light.light_energy = 2.5
	parent.add_child(light)
	light.global_position = at
	return light


func _run() -> void:
	var world := BenchWorld.new()
	add_child(world)
	world.exterior_cell = Node3D.new()
	world.add_child(world.exterior_cell)
	world.adapter.root = Node3D.new()
	world.add_child(world.adapter.root)
	var vestibule := Node3D.new()
	vestibule.name = "EntryVestibule"
	world.adapter.root.add_child(vestibule)
	var lamp := _light(world.exterior_cell, Vector3(0, 3.9, 0))
	var unshadowed := _light(world.exterior_cell, Vector3(2, 3.9, 0), false)
	var faded := _light(world.exterior_cell, Vector3(4, 2.0, 0))
	faded.distance_fade_enabled = true
	faded.distance_fade_begin = 30.0
	faded.distance_fade_length = 6.0
	var mantle := _light(vestibule, Vector3(0, 2.0, 6))
	world.player = BenchPlayer.new()
	world.add_child(world.player)
	var camera := Camera3D.new()
	world.player.add_child(camera)
	world.player.camera = camera
	camera.make_current()

	var policy := Policy.new()
	world.add_child(policy)
	check(policy.setup(world), "the owner binds the shadowed street and vestibule lights")
	check(policy.rows.size() == 3, "unshadowed lights are left alone (%d rows)" % policy.rows.size())

	# On the street beside the lamp and the vestibule door.
	camera.global_position = Vector3(0, 1.6, 4)
	policy.set_enabled(true)
	check(lamp.shadow_enabled and mantle.shadow_enabled and faded.shadow_enabled, "near eye on the ground storey keeps every shadow")
	check(lamp.distance_fade_enabled and is_equal_approx(lamp.distance_fade_begin, Policy.LIGHT_FADE_BEGIN_M) and is_equal_approx(lamp.distance_fade_shadow, Policy.REACH_M - Policy.FADE_M), "the shadow fades natively before the reach while the light does not")
	check(is_equal_approx(faded.distance_fade_begin, 30.0) and is_equal_approx(faded.distance_fade_shadow, Policy.REACH_M - 6.0), "an authored light fade is kept, the shadow fades inside the reach")

	# Two floors up, directly above: close, but on another storey.
	camera.global_position = Vector3(0, 7.8, 6)
	policy.tick()
	check(lamp.shadow_enabled, "a street lamp within reach keeps its shadow from a window above")
	check(not mantle.shadow_enabled, "a vestibule light gives up its shadow to an eye on another storey")

	# Down the block.
	camera.global_position = Vector3(0, 1.6, 40)
	policy.tick()
	check(not lamp.shadow_enabled and not faded.shadow_enabled and not mantle.shadow_enabled, "far eye: no far shadows")
	check(lamp.visible and is_equal_approx(lamp.light_energy, 2.5) and mantle.visible, "far eye: every light still burns as authored")
	check(not unshadowed.shadow_enabled, "an unshadowed light stays unshadowed")

	policy.set_enabled(false)
	check(lamp.shadow_enabled and mantle.shadow_enabled and faded.shadow_enabled, "switching off gives every shadow back")
	check(not lamp.distance_fade_enabled and faded.distance_fade_enabled and is_equal_approx(faded.distance_fade_begin, 30.0), "switching off gives every fade back as authored")

	world.queue_free()
	await get_tree().process_frame
	print("FAR LIGHT RESULT: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
