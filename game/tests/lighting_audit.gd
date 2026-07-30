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
	await _audit()


func _audit() -> void:
	var fixtures := get_tree().get_nodes_in_group("light_fixtures")
	var incompatible_shadow_modes := 0
	for fixture in fixtures:
		if fixture.light and \
				fixture.light.omni_shadow_mode != OmniLight3D.SHADOW_CUBE:
			incompatible_shadow_modes += 1
	_check(incompatible_shadow_modes == 0,
			"all omni lights use Compatibility-safe cubemap shadows")
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
			cam.global_position = GameBoot.b2g([cx, cy, floor_y + 1.62])
			root.light_rig._process(1.0)

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


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children(true):
		_stop_audio(child)
