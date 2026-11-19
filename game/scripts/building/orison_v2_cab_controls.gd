extends Node3D
## Fabricated presentation; production input, travel, bell and lamps remain owners.
const LandingControls := preload("res://scripts/building/orison_v2_lift_controls.gd")
var buttons: Dictionary = {}

func mount(lift: OrisonElevator) -> void:
	var model := (preload("res://assets/props/lift_cab_controls.glb") as PackedScene).instantiate()
	var caps := (preload("res://assets/props/lift_call_plate.glb") as PackedScene).instantiate()
	var cap_mesh := (caps.find_child("ButtonCap",true,false) as MeshInstance3D).mesh
	var plate := lift._cabin_controls.plate as MeshInstance3D
	plate.mesh = (model.find_child("CabPlate",true,false) as MeshInstance3D).mesh
	LandingControls.bind_metre_finish(plate, "brass_dull")
	plate.position = Vector3(.732,1.1475,.88)
	plate.rotation = Vector3(0,-PI*.5,0)
	var screws := MeshInstance3D.new()
	screws.mesh = (model.find_child("CabFixings",true,false) as MeshInstance3D).mesh
	screws.material_override = MatLib.get_mat("nickel_plated",Color(.64,.63,.58))
	LandingControls.bind_metre_finish(screws, "nickel_plated")
	plate.add_child(screws)
	for control: String in lift._cabin_controls.buttons:
		var cap := lift._cabin_controls.buttons[control] as MeshInstance3D
		cap.mesh = cap_mesh
		cap.rotation = Vector3(0,-PI*.5,0)
		cap.position.x = .712
		LandingControls.bind_metre_finish(cap, "bakelite_black" if control == "alarm" else "milk_glass")
		buttons[control] = LandingControls.bind_button(lift, lift._cabin_controls.areas[control], cap, Vector3.RIGHT)
	var stop := lift._cabin_controls.stop as MeshInstance3D
	stop.mesh = (model.find_child("StopCap",true,false) as MeshInstance3D).mesh
	stop.rotation = Vector3(0,-PI*.5,0)
	stop.position.x = .712
	LandingControls.bind_metre_finish(stop, "indicator_enamel")
	model.free(); caps.free()
	lift.cabin_button_pressed.connect(_press)

func _press(control: String) -> void:
	if buttons.has(control):
		LandingControls.pulse_button(buttons[control])
