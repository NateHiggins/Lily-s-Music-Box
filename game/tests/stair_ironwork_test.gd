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
		check(model.find_children("*","MeshInstance3D",true,false).size()==4,"three rail meshes and one structural mesh per assembly")
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				check(mesh.mesh.surface_get_material(surface).resource_name in ["cast_iron","wood_dark","steel"],"imported material retains exact catalogue key")
		check(model.find_children("*","CollisionObject3D",true,false).is_empty(),"ironwork does not replace traversal collision")
		var structure := model.get_node_or_null("StairStructure") as MeshInstance3D
		check(structure!=null,"imported stair understructure exists")
		if structure!=null:
			var outside := 0
			var vertices := 0
			var width := float(stair.width)
			var tread := float(stair.tread)
			var rise := float(stair.rise)
			var run := tread*int(stair.risers_per_flight)
			var half := rise*int(stair.risers_per_flight)
			var transform := model.global_transform.affine_inverse()*structure.global_transform
			for surface in structure.mesh.get_surface_count():
				for vertex: Vector3 in structure.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var p: Vector3 = transform*vertex
					var upper := half
					if p.z<run or p.y>half+.013:
						var returning := p.x>width
						var distance := run+float(stair.landing_depth)-p.z if returning else p.z
						upper = (half if returning else 0.0)+rise*clampf(floorf((distance+.0001)/tread)+1,1,10)
					if p.y>upper+.013 or p.y<upper-.501: outside+=1
					vertices+=1
			check(vertices>0 and outside==0,"actual structural vertices stay within 0.5 m below walking surfaces")
			check(half*2-.5>2.3,"stacked structural envelope leaves over 2.3 m clear height")
		var bearings := model.find_children("Bearing_*","Node3D",true,false)
		check(bearings.size()==40,"both stringers bear beneath every tread")
		for bearing: Node3D in bearings:
			var ray := PhysicsRayQueryParameters3D.create(bearing.global_position-Vector3.UP*.06,
				bearing.global_position+Vector3.UP*.08,1,[player.get_rid()])
			check(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"stringer bearing meets physical tread underside")
		for part in parent.get_children():
			if part is MeshInstance3D and "Guard" in str(part.name):
				check(not part.visible,"opaque review guard hidden in production")
		var supports := model.find_children("Foot_*","Node3D",true,false)
		check(supports.size()==58,"all inner, outer and landing feet remain authored")
		for foot: Node3D in supports:
			var ray := PhysicsRayQueryParameters3D.create(foot.global_position+Vector3.UP*.10,
				foot.global_position-Vector3.UP*.10,1,[player.get_rid()])
			check(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"post bears on physical tread or landing")
		var guards := parent.get_node_or_null("StairGuards") as StaticBody3D
		check(guards!=null,"semantic guard collision exists")
		if guards!=null:
			for returning in [false,true]:
				var width := float(stair.width)
				var tread := float(stair.tread)
				var offset := width+float(stair.gap) if returning else 0.0
				var z := tread*4.5+float(stair.landing_depth) if returning else tread*5.5
				# Lift the stationary sweep above the next nosing touched by the
				# capsule radius; continuous grounded movement is tested separately.
				var y := float(stair.rise)*(16 if returning else 6)+.25
				for direction in [-1.0,1.0]:
					var at := player.global_transform
					at.origin = model.to_global(Vector3(offset+width*.5,y,z))
					var collision := KinematicCollision3D.new()
					var hit := player.test_move(at,model.global_basis*Vector3(direction*width,0,0),collision)
					if not hit or collision.get_collider()!=guards:
						print("GUARD DIAGNOSTIC ",stair.id," returning=",returning," direction=",direction," hit=",hit," collider=",collision.get_collider().get_path() if hit else "none"," origin=",at.origin)
					check(hit and collision.get_collider()==guards,"player capsule cannot cross inner or outer flight guard")
			var landing_at := player.global_transform
			var rear := float(stair.tread)*10+float(stair.landing_depth)+.7-.025
			landing_at.origin = model.to_global(Vector3(float(stair.width)+float(stair.gap)*.5,float(stair.rise)*10+.25,rear-.55))
			var landing_hit := KinematicCollision3D.new()
			check(player.test_move(landing_at,model.global_basis*Vector3(0,0,1),landing_hit)
				and landing_hit.get_collider()==guards,"player capsule cannot cross rear landing guard")
		if str(stair.from)=="F01":
			camera.global_position = model.to_global(Vector3(float(stair.width)*.5,1.45,-.65))
			camera.look_at(model.to_global(Vector3(.12,1.8,1.5)))
			light.global_position = camera.global_position+Vector3.UP*.4
			await shot(str(stair.id)+"_approach")
			camera.global_position = model.to_global(Vector3(float(stair.width),2.7,float(stair.tread)*10+.5))
			camera.look_at(model.to_global(Vector3(.025,2.25,float(stair.tread)*10+.8)))
			light.global_position = camera.global_position
			await shot(str(stair.id)+"_landing")
			camera.global_position = model.to_global(Vector3(float(stair.width)+.15,1.1,.2))
			camera.look_at(model.to_global(Vector3(float(stair.width)-.04,.85,float(stair.tread)*7)))
			light.global_position = camera.global_position
			await shot(str(stair.id)+"_understructure")
			camera.global_position = model.to_global(Vector3(float(stair.width)+float(stair.gap)*.5,2.9,float(stair.tread)*10+float(stair.landing_depth)+.4))
			camera.look_at(model.to_global(Vector3(float(stair.width)+float(stair.gap)*.5,2.0,float(stair.tread)*10-1)))
			light.global_position = camera.global_position
			await shot(str(stair.id)+"_inner_turn")
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
