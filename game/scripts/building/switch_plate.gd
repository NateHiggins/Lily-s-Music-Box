extends StaticBody3D
## One live switch plate. See switch_system.gd.

var system: Node
var unit := ""
var mounting_secure := true:
	set(value):
		mounting_secure = value
		if value and is_instance_valid(_model):
			if _wobble != null: _wobble.kill()
			_model.rotation.z = 0
var _model: Node3D
var _wobble: Tween
var _toggle: Node3D
var _throw: Tween
var _pose_known := false
var _pose_on := false


## V2 supplies the visual; V1 already has its plates in the baked building.
func mount_model() -> void:
	var model := load("res://assets/props/light_switch.glb") as PackedScene
	var visual := model.instantiate() as Node3D
	visual.name = "SwitchModel"
	_model = visual
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
	if _wobble != null: _wobble.kill()
	if RealityState.state_changed.is_connected(_queue_sync):
		RealityState.state_changed.disconnect(_queue_sync)
	if is_instance_valid(system) and system.room_toggled.is_connected(_on_room_toggled):
		system.room_toggled.disconnect(_on_room_toggled)


func interact_prompt() -> String:
	return "[E]  Bathroom light" if get_meta("bathroom_switch", false) \
			else "[E]  Light switch"


func interact(_player: Node) -> void:
	if not mounting_secure and is_instance_valid(_model):
		if _wobble != null: _wobble.kill()
		_wobble = create_tween()
		_wobble.tween_property(_model, "rotation:z", .025, .08)
		_wobble.tween_property(_model, "rotation:z", -.012, .09)
		_wobble.tween_property(_model, "rotation:z", 0.0, .13)
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

func power_snapshot() -> Dictionary:
	return system.room_snapshot(str(get_meta("room_id", ""))) if is_instance_valid(system) else {}

func location_name() -> String:
	var parts := str(get_meta("room_id", "")).split("_")
	return unit if parts.size()>=3 and parts[1] in ["A","B","C","D"] else "Shared building"

func room_name() -> String:
	var parts := str(get_meta("room_id", "")).split("_")
	var first := 2 if location_name() != "Shared building" else 1
	var room := " ".join(parts.slice(first))
	return str({"MAIN":"LIVING ROOM", "BATH":"BATHROOM", "BED":"BEDROOM", "BED1":"BEDROOM 1",
		"BED2":"BEDROOM 2", "PRIVATE HALL":"HALL", "VESTIBULE":"ENTRY"}.get(room,room))

func restore_power(state: Dictionary) -> bool:
	return system.restore_room(str(get_meta("room_id", "")),state) if is_instance_valid(system) else false

func at_detent() -> bool:
	return _toggle != null and (_throw == null or not _throw.is_running()) \
		and is_equal_approx(_toggle.rotation.x, deg_to_rad(22.0 if _pose_on else -22.0))
