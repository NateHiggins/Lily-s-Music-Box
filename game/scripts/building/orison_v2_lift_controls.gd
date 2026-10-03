extends Node3D
## Presentation only: production lift owns calls, travel and indicator state.
const Model := preload("res://assets/props/lift_call_plate.glb")
var buttons: Dictionary = {}

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
		var screws := MeshInstance3D.new()
		screws.mesh = screw_mesh
		screws.material_override = MatLib.get_mat("nickel_plated",Color(.64,.63,.58))
		plate.add_child(screws)
		cap.mesh = cap_mesh
		cap.rotation = Vector3.ZERO
		cap.position.z = faces[0]+.021
		(cap.material_override as StandardMaterial3D).roughness = .24
		# Keep the existing input owner centered over the seated hardware.
		area.position.z = faces[0]+.03
		buttons[level] = {"cap":cap,"rest":cap.position.z,"tween":null}
	lift.landing_button_pressed.connect(_press)
	return true

func _press(level: String) -> void:
	if not buttons.has(level): return
	var state: Dictionary = buttons[level]
	if state.tween!=null and is_instance_valid(state.tween): state.tween.kill()
	var tween := create_tween()
	state.tween = tween
	tween.tween_property(state.cap,"position:z",float(state.rest)-.003,.07)
	tween.tween_interval(.10)
	tween.tween_property(state.cap,"position:z",float(state.rest),.14)
