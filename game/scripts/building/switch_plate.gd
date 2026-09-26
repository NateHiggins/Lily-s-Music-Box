extends StaticBody3D
## One live switch plate. See switch_system.gd.

var system: Node
var _toggle: Node3D
var _throw: Tween
var _pose_known := false
var _pose_on := false


## V2 supplies the visual; V1 already has its plates in the baked building.
func mount_model() -> void:
	var model := load("res://assets/props/light_switch.glb") as PackedScene
	var visual := model.instantiate() as Node3D
	visual.name = "SwitchModel"
	add_child(visual)
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface)
			mesh.set_surface_override_material(surface, MatLib.get_mat(source.resource_name))
	_toggle = visual.find_child("TogglePivot", true, false) as Node3D
	system.room_toggled.connect(_on_room_toggled)
	RealityState.state_changed.connect(_queue_sync)
	_queue_sync()


func _queue_sync() -> void:
	# Household restoration runs synchronously on the same signal. Read its
	# final fixture verdict afterwards; never create a second saved switch state.
	_sync_pose.call_deferred()


func _sync_pose() -> void:
	if not is_inside_tree() or _toggle == null or not is_instance_valid(system): return
	var identities: Array = system._room_fixtures.get(str(get_meta("room_id", "")), [])
	for fixture in get_tree().get_nodes_in_group("light_fixtures"):
		if str(fixture.name) in identities:
			_set_pose(fixture.powered, false)
			return
	_set_pose(false, false)


func _on_room_toggled(room: String, now_on: bool) -> void:
	if room == str(get_meta("room_id", "")): _set_pose(now_on, true)


func _set_pose(now_on: bool, animate: bool) -> void:
	if _toggle == null: return
	if _pose_known and _pose_on == now_on: return
	_pose_known = true
	_pose_on = now_on
	if _throw != null: _throw.kill()
	var angle := deg_to_rad(22.0 if now_on else -22.0)
	if animate:
		_throw = create_tween()
		_throw.tween_property(_toggle, "rotation:x", angle, .09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_toggle.rotation.x = angle


func _exit_tree() -> void:
	if _throw != null: _throw.kill()
	if RealityState.state_changed.is_connected(_queue_sync):
		RealityState.state_changed.disconnect(_queue_sync)
	if is_instance_valid(system) and system.room_toggled.is_connected(_on_room_toggled):
		system.room_toggled.disconnect(_on_room_toggled)


func interact_prompt() -> String:
	return "[E]  Bathroom light" if get_meta("bathroom_switch", false) \
			else "[E]  Light switch"


func interact(_player: Node) -> void:
	# The click is unconditional. A toggle brake (an empty room,
	# a fixture already dead) must still feel like a switch under the
	# hand — a plate that answers silently reads as broken scenery.
	var now_on := false
	if system:
		now_on = system.toggle_room(str(get_meta("room_id", "")))
	# Unlike the old random pitch, throw and return now report the circuit
	# verdict consistently. The plate remains the physical source.
	if now_on:
		AudioPolicy.present_3d(&"interaction.switch_on", global_position,
				1.0, StringName(name))
	else:
		AudioPolicy.present_3d(&"interaction.switch_off", global_position,
				1.0, StringName(name))
