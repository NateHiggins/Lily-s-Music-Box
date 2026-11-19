extends Node3D
## Presentation only: production lift owns calls, travel and indicator state.
const Model := preload("res://assets/props/lift_call_plate.glb")
const TRAVEL := .003
const CONTACT := .0026
var buttons: Dictionary = {}


static func bind_metre_finish(draw: MeshInstance3D, key: String) -> void:
	var finish := draw.material_override as StandardMaterial3D
	var maps := MatLib.get_mat(key)
	if MatLib.is_shared_material(finish):
		finish = finish.duplicate() as StandardMaterial3D
	if finish.albedo_texture == null:
		finish.normal_scale = .12
		finish.metallic = maps.metallic
	finish.albedo_texture = maps.albedo_texture
	finish.roughness_texture = maps.roughness_texture
	finish.roughness_texture_channel = maps.roughness_texture_channel
	finish.normal_texture = maps.normal_texture
	finish.normal_enabled = true
	finish.uv1_triplanar = false
	finish.uv1_scale = maps.uv1_scale
	finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	draw.material_override = finish
	draw.set_meta("material_key", key)


func mount(lift: OrisonElevator, layout: Dictionary) -> bool:
	var library := Model.instantiate()
	var plate_mesh := (library.find_child("CallPlate",true,false) as MeshInstance3D).mesh
	var screw_mesh := (library.find_child("CallFixings",true,false) as MeshInstance3D).mesh
	var cap_mesh := (library.find_child("ButtonCap",true,false) as MeshInstance3D).mesh
	library.free()
	for level: String in lift.stop_order:
		var controls: Dictionary = lift._landing_controls[level]
		var plate := controls.plate as MeshInstance3D
		var cap := controls.button as MeshInstance3D
		var area := controls.area as Area3D
		var faces: Array[float] = []
		# Use the same authored solid fixtures as the shaft builder. Select
		# the wall covering this control by geometry, without a generated ID.
		for fixture: Dictionary in layout.fixtures:
			if fixture.level!=level or not bool(fixture.get("collision",true)): continue
			var at := Vector3(float(fixture.position[0]),float(lift.stops[level])+float(fixture.position[1]),float(fixture.position[2]))
			var size := Vector3(float(fixture.size[0]),float(fixture.size[1]),float(fixture.size[2]))
			var bounds: AABB = lift.transform.affine_inverse()*AABB(at-size*.5,size)
			if absf(bounds.get_center().z-OrisonElevator.FRONT_Z)>.001: continue
			if plate.position.x>bounds.position.x and plate.position.x<bounds.end.x and plate.position.y>bounds.position.y and plate.position.y<bounds.end.y:
				faces.append(bounds.end.z)
		if faces.size()!=1: return false
		plate.position.z = faces[0]
		plate.mesh = plate_mesh
		bind_metre_finish(plate, "brass_dull")
		var screws := MeshInstance3D.new()
		screws.mesh = screw_mesh
		screws.material_override = MatLib.get_mat("nickel_plated",Color(.64,.63,.58))
		bind_metre_finish(screws, "nickel_plated")
		plate.add_child(screws)
		cap.mesh = cap_mesh
		cap.rotation = Vector3.ZERO
		cap.position.z = faces[0]+.021
		(cap.material_override as StandardMaterial3D).roughness = .24
		bind_metre_finish(cap, "milk_glass")
		# Keep the existing input owner centered over the seated hardware.
		area.position.z = faces[0]+.03
		buttons[level] = bind_button(lift, area, cap, Vector3.FORWARD)
	lift.landing_button_pressed.connect(_press)
	return true

func _press(level: String) -> void:
	if buttons.has(level):
		pulse_button(buttons[level])


static func bind_button(lift: OrisonElevator, area: Area3D, cap: MeshInstance3D, axis: Vector3) -> Dictionary:
	var state := {"cap": cap, "rest": cap.position, "axis": axis, "tween": null, "held": false, "fired": false}
	lift.register_button_grip(area, _button_target.bind(lift, area, state))
	return state


static func _button_target(lift: OrisonElevator, area: Area3D, state: Dictionary) -> Dictionary:
	var cap: MeshInstance3D = state.cap
	var rest: Vector3 = state.rest
	var axis: Vector3 = state.axis
	return {
		"owner": area, "part": cap, "frame": cap.get_parent(), "kind": "slide", "axis": axis,
		"minimum": 0.0, "maximum": TRAVEL, "gesture_screen_axis": Vector2.UP, "gesture_travel_px": 32.0,
		"read": func() -> float: return (cap.position - rest).dot(axis),
		"begin": func() -> bool:
			if state.held:
				return false
			_stop_pulse(state)
			cap.position = rest
			state.held = true
			state.fired = false
			return true,
		"owns": func() -> bool: return state.held,
		"write": func(depth: float) -> void:
			if not state.held:
				return
			cap.position = rest + axis * depth
			if depth >= CONTACT and not state.fired:
				state.fired = true
				lift.interact_area(area),
		"end": func() -> void:
			state.held = false
			var spring := cap.create_tween()
			state.tween = spring
			spring.tween_property(cap, "position", rest, .14),
	}


static func pulse_button(state: Dictionary) -> void:
	if state.held:
		return
	_stop_pulse(state)
	var cap: MeshInstance3D = state.cap
	var tween := cap.create_tween()
	state.tween = tween
	tween.tween_property(cap, "position", state.rest + state.axis * TRAVEL, .07)
	tween.tween_interval(.10)
	tween.tween_property(cap, "position", state.rest, .14)


static func _stop_pulse(state: Dictionary) -> void:
	var tween: Tween = state.tween
	if tween != null and tween.is_valid():
		tween.kill()
