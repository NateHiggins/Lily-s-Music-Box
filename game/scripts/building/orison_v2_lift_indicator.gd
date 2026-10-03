extends Node3D
## Readable ceiling-mounted dial, with the existing height-driven needle owner.
var labels: Array[Label3D] = []
var mounts: MeshInstance3D
var housing: MeshInstance3D

func mount(lift: OrisonElevator) -> void:
	lift._cabin.add_child(self)
	position=Vector3(0,2.045,.925)
	var library := (preload("res://assets/props/lift_indicator.glb") as PackedScene).instantiate()
	var parts: Dictionary = lift._indicator_parts
	for old in [parts.face,parts.bezel]: old.hide()
	for old in parts.labels:
		if old!=null: old.hide()
	housing=_mesh(library,"IndicatorCase",parts.bezel.material_override)
	_mesh(library,"IndicatorFace",parts.face.material_override)
	mounts=_mesh(library,"CeilingMounts",parts.bezel.material_override)
	var pivot := _mesh(library,"PivotCap",parts.bezel.material_override)
	pivot.position.z=-.044
	var needle := parts.needle as MeshInstance3D
	needle.mesh=(library.find_child("IndicatorNeedle",true,false) as MeshInstance3D).mesh
	needle.position=Vector3.ZERO
	lift._needle.position=position+Vector3(0,0,-.040)
	lift._needle_sweep_sign=-1.0
	for index in lift.stop_order.size():
		var angle := deg_to_rad(lerpf(-72.0,72.0,float(index)/(lift.stop_order.size()-1)))
		var tick := _mesh(library,"Tick",needle.material_override)
		tick.position=Vector3(-sin(angle)*.120,cos(angle)*.120,-.036)
		tick.rotation.z=angle
		var label := Label3D.new()
		label.text=OrisonElevator.PLATE_LEGEND.get(lift.stop_order[index],lift.stop_order[index])
		label.font=preload("res://assets/fonts/courier_prime/CourierPrime-Bold.ttf")
		label.font_size=48; label.pixel_size=.00052
		label.modulate=Color(.015,.012,.008); label.outline_size=0
		label.shaded=false; label.double_sided=false
		label.position=Vector3(-sin(angle)*.140,cos(angle)*.140,-.035)
		label.rotation.y=PI
		add_child(label); labels.append(label)
	library.free()
	lift._indicator_visual=self

func _mesh(library: Node, part: String, material: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh=(library.find_child(part,true,false) as MeshInstance3D).mesh
	result.material_override=material
	add_child(result)
	return result
