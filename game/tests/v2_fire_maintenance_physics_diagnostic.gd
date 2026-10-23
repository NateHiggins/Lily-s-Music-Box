extends Node3D
## Isolate the small-stock settling defect. Diagnostic, no input qualification.
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	var tolerance:=OS.get_environment("V2_STOCK_CONTACT_TOLERANCE_M")
	if not tolerance.is_empty():PhysicsServer3D.space_set_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION,float(tolerance))
	var packed:=load("res://assets/props/fire_maintenance_stock.glb") as PackedScene
	var native: Node=packed.instantiate()
	var mesh: Mesh=(native.find_child("Bottle",true,false) as MeshInstance3D).mesh
	var cases: Array[Dictionary]=[
		{"name":"native_ccd","ccd":true,"friction":.85,"damp":0.,"primitive":false},
		{"name":"native_discrete","ccd":false,"friction":.85,"damp":0.,"primitive":false},
		{"name":"native_glaze_discrete","ccd":false,"friction":.35,"damp":0.,"primitive":false},
		{"name":"native_damped","ccd":true,"friction":.85,"damp":5.,"primitive":false},
		{"name":"cylinder_ccd","ccd":true,"friction":.35,"damp":0.,"primitive":true},
		{"name":"cylinder_discrete","ccd":false,"friction":.35,"damp":0.,"primitive":true}]
	var bodies: Array[RigidBody3D]=[]
	for index in cases.size():
		var spec: Dictionary=cases[index]
		var floor:=StaticBody3D.new();floor.position=Vector3(index*1.,-.10,0);add_child(floor)
		var support:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.9,.20,.9);support.shape=box;floor.add_child(support)
		var body:=RigidBody3D.new();body.mass=.42;body.continuous_cd=spec.ccd;body.angular_damp=spec.damp
		var contact:=PhysicsMaterial.new();contact.friction=spec.friction;contact.bounce=0.;body.physics_material_override=contact
		body.position=Vector3(index*1.,1.178775,0);body.basis=Basis(Quaternion(-.02735786,.97029299,.13223569,.20074110).normalized())
		add_child(body);bodies.append(body)
		var shape:=CollisionShape3D.new()
		if spec.primitive:
			var cylinder:=CylinderShape3D.new();cylinder.radius=.034;cylinder.height=.166;shape.shape=cylinder;shape.position.y=.083
		else:shape.shape=mesh.create_convex_shape()
		body.add_child(shape)
	native.free()
	var rows: Array[Dictionary]=[]
	for frame in 600:
		await get_tree().physics_frame
		if frame%60==59:
			for index in cases.size():
				var body: RigidBody3D=bodies[index]
				rows.append({"case":cases[index].name,"frame":frame+1,"position":str(body.position),"velocity":str(body.linear_velocity),"spin":str(body.angular_velocity),"sleeping":body.sleeping})
	for index in cases.size():print("PHYSICS MATRIX ",JSON.stringify({"case":cases[index],"sleeping":bodies[index].sleeping,"position":str(bodies[index].position),"spin":str(bodies[index].angular_velocity)}))
	var report: Dictionary={"evidence_class":"INERT","contact_allowed_penetration_m":PhysicsServer3D.space_get_param(get_world_3d().space,PhysicsServer3D.SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION),"cases":cases,"samples":rows}
	var output:=OS.get_environment("SHOT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file:=FileAccess.open(output.path_join("physics.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print("PHYSICS MATRIX COMPLETE: diagnostic only")
	get_tree().quit()
