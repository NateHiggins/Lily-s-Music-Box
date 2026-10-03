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
				if str(stair.id).begins_with("PRIMARY_"):_check_planar_mapping(mesh.mesh,true)
				var key: String=mesh.mesh.surface_get_material(surface).resource_name
				var allowed: Array=["cast_iron","wood_dark","metal"] if str(stair.id).begins_with("PRIMARY_") else ["cast_iron","wood_dark","steel"]
				check(key in allowed,"imported material retains its assembly catalogue key")
				if str(stair.id).begins_with("PRIMARY_"):check(MatLib.SETS.has(key),"public ironwork uses a mapped runtime material")
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

func _check_planar_mapping(mesh: Mesh, check_derivatives: bool=false) -> void:
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
		check(vertices.size()>=4 and normals.size()==vertices.size() and uv.size()==vertices.size() and tangents.size()==vertices.size()*4,"planar quad has active UV, normal and tangent on every imported vertex")
		var valid:=true
		for i in vertices.size():
			valid=valid and vertices[i].is_finite() and uv[i].is_finite() and absf(normals[i].length()-1)<.001
			if tangents.size()==vertices.size()*4:
				var tangent:=Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
				valid=valid and tangent.is_finite() and absf(tangent.length()-1)<.001 and absf(tangent.dot(normals[i]))<.001 and absf(absf(tangents[i*4+3])-1)<.001
		check(valid,"finite unit normals and orthogonal tangent handedness")
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		check(indices.size()>=6 and indices.size()%3==0,"planar surface has complete native indexed triangles")
		var mapped:=true
		var widest:=0.0
		var excess:=0.0
		var derivatives:=true
		var bad_derivatives:=0
		var min_determinant:=INF
		var worst_dot:=1.0
		for triangle in range(0,indices.size(),3):
			if check_derivatives:
				var a:=indices[triangle]
				var b:=indices[triangle+1]
				var c:=indices[triangle+2]
				var first:=vertices[b]-vertices[a]
				var second:=vertices[c]-vertices[a]
				var uv_first:=uv[b]-uv[a]
				var uv_second:=uv[c]-uv[a]
				var determinant:=uv_first.x*uv_second.y-uv_second.x*uv_first.y
				min_determinant=minf(min_determinant,absf(determinant))
				derivatives=derivatives and absf(determinant)>1e-12
				if absf(determinant)>1e-12:
					var expected: Vector3=(first*uv_second.y-second*uv_first.y)/determinant
					var bitangent: Vector3=(second*uv_first.x-first*uv_second.x)/determinant
					for index: int in [a,b,c]:
						var projected: Vector3=(expected-normals[index]*expected.dot(normals[index])).normalized()
						var actual:=Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2])
						worst_dot=minf(worst_dot,projected.dot(actual))
						if projected.dot(actual)<=.999 or normals[index].cross(actual).dot(bitangent)*tangents[index*4+3]<=0:
							bad_derivatives+=1
							if bad_derivatives<4:print("UV DERIVATIVE DIAGNOSTIC: ",mesh.resource_name," tri=",triangle," n=",normals[index]," actual=",actual," expected=",projected," bitangent=",bitangent," determinant=",determinant)
						derivatives=derivatives and projected.dot(actual)>.999
						derivatives=derivatives and normals[index].cross(actual).dot(bitangent)*tangents[index*4+3]>0
			for edge in 3:
				var a:=indices[triangle+edge]
				var b:=indices[triangle+(edge+1)%3]
				var length:=vertices[a].distance_to(vertices[b])
				var texture:=uv[a].distance_to(uv[b])
				mapped=mapped and texture<=length+.00005
				excess=maxf(excess,texture-length)
				if length>.00005: widest=maxf(widest,texture/length)
		check(mapped and absf(widest-1)<.005,"planar mapping retains one texture metre per model metre")
		if check_derivatives: check(derivatives,"tangent direction and handedness match actual imported UV derivatives")
		print("CEILING MAPPING: mesh=",mesh.resource_name," valid_basis=",valid," max_uv_excess=",excess," widest=",widest," vertices=",vertices.size()," derivatives=",derivatives," bad_derivatives=",bad_derivatives," min_determinant=",min_determinant," worst_dot=",worst_dot)
