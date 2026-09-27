extends Node3D
## Fabricated presentation; production input, travel, bell and lamps remain owners.
var buttons: Dictionary = {}

func mount(lift: OrisonElevator) -> void:
	var model := (preload("res://assets/props/lift_cab_controls.glb") as PackedScene).instantiate()
	var caps := (preload("res://assets/props/lift_call_plate.glb") as PackedScene).instantiate()
	var cap_mesh := (caps.find_child("ButtonCap",true,false) as MeshInstance3D).mesh
	var plate := lift._cabin_controls.plate as MeshInstance3D
	plate.mesh = (model.find_child("CabPlate",true,false) as MeshInstance3D).mesh
	plate.position = Vector3(.732,1.1475,.88)
	plate.rotation = Vector3(0,-PI*.5,0)
	var screws := MeshInstance3D.new()
	screws.mesh = (model.find_child("CabFixings",true,false) as MeshInstance3D).mesh
	screws.material_override = MatLib.get_mat("nickel_plated",Color(.64,.63,.58))
	plate.add_child(screws)
	for control: String in lift._cabin_controls.buttons:
		var cap := lift._cabin_controls.buttons[control] as MeshInstance3D
		cap.mesh = cap_mesh
		cap.rotation = Vector3(0,-PI*.5,0)
		cap.position.x = .712
		buttons[control] = {"cap":cap,"rest":cap.position.x,"tween":null}
	var stop := lift._cabin_controls.stop as MeshInstance3D
	stop.mesh = (model.find_child("StopCap",true,false) as MeshInstance3D).mesh
	stop.rotation = Vector3(0,-PI*.5,0)
	stop.position.x = .712
	model.free(); caps.free()
	lift.cabin_button_pressed.connect(_press)

func _press(control: String) -> void:
	if not buttons.has(control): return
	var state: Dictionary = buttons[control]
	if state.tween!=null and is_instance_valid(state.tween): state.tween.kill()
	var tween := create_tween()
	state.tween = tween
	tween.tween_property(state.cap,"position:x",float(state.rest)+.003,.07)
	tween.tween_interval(.10)
	tween.tween_property(state.cap,"position:x",float(state.rest),.14)
