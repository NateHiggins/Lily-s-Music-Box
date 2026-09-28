extends RefCounted
## Complete the existing semantic openings without replacing glazing authority.
static func mount(root: Node3D) -> void:
	var source := (preload("res://assets/props/window_joinery.glb") as PackedScene).instantiate()
	var mesh := (source.find_child("WindowJoinery",true,false) as MeshInstance3D).mesh
	source.free()
	for record: Dictionary in root.layout.windows:
		var opening := root.get_node(str(record.id)) as Node3D
		var jamb := opening.get_node("JambA") as MeshInstance3D
		var frame := MeshInstance3D.new()
		frame.name="FittedWindowJoinery"
		frame.mesh=mesh
		frame.material_override=jamb.get_active_material(0)
		frame.position.y=float(record.sill)+float(record.height)*.5
		frame.rotation.y=PI*.5 if str(record.axis)=="z" else 0
		var span: Vector2=root.window_reveal_span(record)
		var axis := 0 if str(record.axis)=="z" else 2
		frame.position[axis]=(span.x+span.y)*.5-float(record.center[0 if axis==0 else 1])
		frame.scale=Vector3(float(record.width),float(record.height),(span.y-span.x)/.35)
		opening.add_child(frame)
		jamb.hide()
		opening.get_node("JambB").hide()
