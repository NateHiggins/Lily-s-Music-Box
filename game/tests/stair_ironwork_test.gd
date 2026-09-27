extends "res://tests/orison_v2_vertical_route_test.gd"
## Imported support geometry and declared production camera stations.
func _init() -> void: route_label = "STAIR IRONWORK"

func check(ok: bool, label: String) -> void:
	print("IRONWORK ","PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)

func _route() -> void:
	player.set_physics_process(false)
	player.set_lamp_enabled(false)
	for child in player.carried_device.get_children():
		if child is CanvasLayer: child.hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 72
	camera.make_current()
	var light := OmniLight3D.new()
	world.add_child(light)
	light.light_energy = .7
	light.omni_range = 6
	var seen := 0
	for stair: Dictionary in world.layout.stairs:
		var parent := world.adapter.resolve(str(stair.id)) as Node3D
		var model := parent.get_node_or_null("Ironwork") as Node3D
		check(model!=null,str(stair.id)+" has imported ironwork")
		if model==null: continue
		seen += 1
		check(model.find_children("*","MeshInstance3D",true,false).size()==3,"three shared material meshes per assembly")
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				check(mesh.mesh.surface_get_material(surface).resource_name in ["cast_iron","wood_dark","steel"],"imported material retains exact catalogue key")
		check(model.find_children("*","CollisionObject3D",true,false).is_empty(),"ironwork does not replace traversal collision")
		for part in parent.get_children():
			if part is MeshInstance3D and "Guard" in str(part.name):
				check(not part.visible,"opaque review guard hidden in production")
		var supports := model.find_children("Foot_*","Node3D",true,false)
		check(supports.size()==37,"all flight and landing feet remain authored")
		for foot: Node3D in supports:
			var ray := PhysicsRayQueryParameters3D.create(foot.global_position+Vector3.UP*.10,
				foot.global_position-Vector3.UP*.10,1,[player.get_rid()])
			check(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"post bears on physical tread or landing")
		if str(stair.from)=="F01":
			camera.global_position = model.to_global(Vector3(float(stair.width)*.5,1.45,-.65))
			camera.look_at(model.to_global(Vector3(.12,1.8,1.5)))
			light.global_position = camera.global_position+Vector3.UP*.4
			await shot(str(stair.id)+"_approach")
			camera.global_position = model.to_global(Vector3(float(stair.width),2.7,float(stair.tread)*10+.5))
			camera.look_at(model.to_global(Vector3(.025,2.25,float(stair.tread)*10+.8)))
			light.global_position = camera.global_position
			await shot(str(stair.id)+"_landing")
	check(seen==world.layout.stairs.size(),"both cores dressed through basement and roof")
	light.free()
	camera.free()

func shot(label: String) -> void:
	var path := OS.get_environment("SHOT_DIR")
	if path.is_empty(): return
	DirAccess.make_dir_recursive_absolute(path)
	await get_tree().create_timer(.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path.path_join(label+".png"))
