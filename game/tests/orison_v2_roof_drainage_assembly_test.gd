extends "res://tests/orison_v2_roof_route_test.gd"
## Inspect the installed construction without replacing any provider or actor.
## Static physical clearance, live machinery and seal motion; no flow claim.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests();CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	world=Runtime.instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	if world.startup_failed:world.free();get_tree().quit(1);return
	player=world.player;player.set_physics_process(false);_prepare_player_start()
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var root: Node3D=world.adapter.root
	await _doors(root);await _plant(root);await _receivers(root)
	print("INSTALLED ROOF DRAINAGE ASSEMBLY: failures=",failures.size())
	world.shutdown_for_tests();world.free();await get_tree().create_timer(.25).timeout
	get_tree().quit(0 if failures.is_empty() else 1)

func _actual_faces(mesh: Mesh) -> PackedVector3Array:
	return preload("res://scripts/building/orison_v2_native_faces.gd").read(mesh)

func _v(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

func _doors(root: Node3D) -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_drainage_door_weather.json"))
	var specs: Dictionary={};var blades: Dictionary={}
	for spec: Dictionary in fixture.door_pans:specs[str(spec.id)]=spec
	for part: Dictionary in fixture.parts:
		if not part.moving or part.material!="rubber_aged":continue
		var identity: String=str(part.owner).split("__")[0]
		var draws: Array[Node]=_leaf(identity)._body.find_children(str(part.name),"MeshInstance3D",true,false)
		_require(draws.size()==1,"native moving blade belongs to original live leaf: "+identity)
		if draws.size()==1:blades[identity]=draws[0]
	var sweeps:=0;var seal_contacts:=0
	var physics: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	print("INSTALLED PHYSICS BACKEND ",ProjectSettings.get_setting("physics/3d/physics_engine"))
	for identity: String in specs:
		var spec: Dictionary=specs[identity];var leaf:=_leaf(identity);var blade:=blades[identity] as MeshInstance3D
		_require(not leaf.swing_out and leaf.width==spec.source_record.width and leaf.height==spec.source_record.height,"original source leaf dimensions and swing setting retained: "+identity)
		var fixed: Node3D=leaf.get_node("FixedIronmongery");var saddle_faces:=PackedVector3Array()
		for draw: MeshInstance3D in fixed.find_children("*","MeshInstance3D",true,false):saddle_faces.append_array((leaf.global_transform.affine_inverse()*draw.global_transform)*_actual_faces(draw.mesh))
		var blade_faces: PackedVector3Array=(leaf.global_transform.affine_inverse()*blade.global_transform)*_actual_faces(blade.mesh)
		for x: float in [.03,leaf.width*.5,leaf.width-.03]:
			var point:=Vector3(x,.004,(float(spec.bottom_seal_z[0])+float(spec.bottom_seal_z[1]))*.5);var up:=Vector3.UP
			var blade_at:=_nearest_face(blade_faces,point-up*.002,point+up*.002);var saddle_at:=_nearest_face(saddle_faces,point+up*.002,point-up*.002)
			print("INSTALLED DOOR SEAL SEAT ",identity," query=",point," blade=",blade_at," saddle=",saddle_at," leaf=",leaf.transform," fixed=",fixed.transform)
			_require(not blade_at.is_empty() and not saddle_at.is_empty() and (blade_at.point as Vector3).distance_to(saddle_at.point)<.000005,"actual imported bottom blade seats on original saddle: "+identity);seal_contacts+=1
		var target_degrees:=roundi(absf(rad_to_deg(leaf.motion_target_angle(true))))
		var original_shape:=leaf._body.get_child(0) as CollisionShape3D
		for degrees: int in range(0,target_degrees+1,4):
			var pose: Transform3D=leaf._body.transform;pose.basis=Basis(Vector3.UP,deg_to_rad(float(degrees)))
			# Query the actual new blade's full oriented volume. An arbitrary ray
			# below the toe confuses a close but clear roof with an intersection.
			var bounds:=blade.mesh.get_aabb();var shape:=BoxShape3D.new();shape.size=bounds.size
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.margin=0.;query.transform=leaf.global_transform*pose*blade.transform*Transform3D(Basis.IDENTITY,bounds.get_center());query.collision_mask=1;query.exclude=[player.get_rid(),leaf._body.get_rid()]
			var hits: Array[Dictionary]=physics.intersect_shape(query,32)
			for hit: Dictionary in hits:
				print("INSTALLED BLADE VOLUME CONTACT ",identity," degree=",degrees," owner=",root.get_path_to(hit.collider)," blade_bounds=",bounds," volume_pose=",query.transform," leaf_pose=",leaf.global_transform," owner_pose=",hit.collider.global_transform)
				for contacted_shape: CollisionShape3D in hit.collider.get_children():
					print("INSTALLED CONTACT SHAPE ",contacted_shape.name," shape=",contacted_shape.shape," pose=",contacted_shape.global_transform)
			_require(hits.is_empty(),"actual bottom blade volume clears retained fixed fabric during original swing: "+identity+" "+str(degrees));sweeps+=1
			var original_query:=PhysicsShapeQueryParameters3D.new();var original_box:=BoxShape3D.new();original_box.size=Vector3(leaf.width-.02,leaf.height-.02,.052)
			original_query.shape=original_box;original_query.margin=0.;original_query.transform=leaf.global_transform*pose*original_shape.transform;original_query.collision_mask=1;original_query.exclude=query.exclude
			var original_hits: Array[Dictionary]=physics.intersect_shape(original_query,32)
			for hit: Dictionary in original_hits:
				print("INSTALLED ORIGINAL LEAF CONTACT ",identity," degree=",degrees," owner=",root.get_path_to(hit.collider)," query_pose=",original_query.transform," size=",original_box.size," owner_pose=",hit.collider.global_transform)
				for contacted_shape: CollisionShape3D in hit.collider.get_children():
					if contacted_shape.shape is ConcavePolygonShape3D:
						var at:=AABB();var native_faces: PackedVector3Array=contacted_shape.shape.get_faces();at.position=native_faces[0]
						for p: Vector3 in native_faces:at=at.expand(p)
						print("INSTALLED ORIGINAL HEAD BOUNDS ",at," shape_pose=",contacted_shape.global_transform," draw_pose=",hit.collider.get_parent().global_transform)
			_require(original_hits.is_empty(),"complete original 52 mm visual leaf envelope clears fixed fabric: "+identity+" "+str(degrees))
		var p: Vector3=root.get_node(identity).position
		var eye:=Vector3(p.x-.9,20.85,p.z-.6);player.global_position=root.to_global(eye)-Vector3.UP*player.STANDING_EYE;player.camera.global_position=root.to_global(eye);player.set_lamp_enabled(true);await _roof_capture("fitted_pan_"+identity,Vector3(p.x-.25,float(spec.curb_top_y),p.z-.5))
		leaf.interact(null);await get_tree().create_timer(.7).timeout
		_require(leaf.open and absf(leaf._body.rotation.y-leaf.motion_target_angle(true))<.001,"original door opens with retained live tween: "+identity)
		await _roof_capture("open_pan_"+identity,Vector3(p.x,float(spec.curb_top_y)+.06,p.z))
		leaf.interact(null);await get_tree().create_timer(.7).timeout;_require(not leaf.open and is_zero_approx(leaf._body.rotation.y),"original door closes with retained live tween: "+identity)
	print("INSTALLED DOOR WEATHER: ",seal_contacts," imported saddle seats; ",sweeps," bottom swing checks; 2 live open/close cycles; failures=",failures.size())

func _nearest_face(faces: PackedVector3Array,from: Vector3,to: Vector3) -> Dictionary:
	var nearest:=INF;var result: Dictionary={};var direction: Vector3=(to-from).normalized();var reach: float=from.distance_to(to)
	for i in range(0,faces.size(),3):
		# Unit ray avoids the engine's small-segment determinant rejection on
		# a 2 mm blade. Retain the actual finite segment and 5 micron fit bound.
		var hit: Variant=Geometry3D.ray_intersects_triangle(from,direction,faces[i],faces[i+1],faces[i+2])
		if hit!=null and from.distance_to(hit)<=reach+.000005 and from.distance_to(hit)<nearest:nearest=from.distance_to(hit);result={"point":hit,"distance":nearest}
	return result

func _plant(root: Node3D) -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_drainage_plant_weather.json"))
	var models: Dictionary={};var source_audio: Dictionary={}
	for spec: Dictionary in fixture.fan_curbs:
		var fan:=world.adapter.resolve(spec.id) as ExhaustFanProp
		_require(fan!=null,"actual production fan resolved: "+str(spec.id))
		if fan==null:continue
		models[spec.id]=fan
		_require(root.to_local(fan.global_position).distance_to(_v(spec.center))<.000005,"original fan anchor retained: "+str(spec.id))
		_require(absf(fan._rotor.position.y-(.70+float(spec.machine_offset_y)))<.000005,"machine rises once as the original assembly: "+str(spec.id))
		for emitter: AudioStreamPlayer3D in fan._duct_emitters:
			var node_id: String=str(emitter.name).trim_prefix("Duct_")
			var register:=world.adapter.resolve(node_id) as Node3D
			_require(register!=null and emitter.global_position.distance_to(register.global_position)<.000005,"original register audio anchor retained: "+node_id)
		source_audio[spec.id]=fan._duct_emitters.size()
		var before:=fan._rotor.basis;fan.set_running(true,true);await get_tree().create_timer(.12).timeout
		_require(not fan._rotor.basis.is_equal_approx(before),"raised original rotor remains live: "+str(spec.id))
		_require(absf(fan._louver.rotation.x-deg_to_rad(-24.))<.001,"raised shutter opens on original cycle: "+str(spec.id));fan.set_running(false,true)
		_require(is_zero_approx(fan._louver.rotation.x),"raised shutter closes on original cycle: "+str(spec.id))
		_require("SERVICE ISOLATION REQUIRED" in str(fan.service_wire_card().condition),"raised original guard refusal retained: "+str(spec.id))
	var physical: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	var bearing_checks:=0
	for spec: Dictionary in fixture.fan_curbs:
		var p:=_v(spec.center);var owner: StaticBody3D=models[spec.id].get_node("PlantCollision")
		for delta: Vector3 in [Vector3(-.2,0,0),Vector3(.2,0,0),Vector3(0,0,-.2),Vector3(0,0,.2)]:
			var query:=PhysicsRayQueryParameters3D.create(root.to_global(p+delta+Vector3.UP*.004),root.to_global(p+delta-Vector3.UP*.004),1,[player.get_rid(),owner.get_rid()])
			var hit: Dictionary=physical.intersect_ray(query);_require(not hit.is_empty() and "/Floor/Collision" in str(root.get_path_to(hit.collider)) and absf(root.to_local(hit.position).y-19.2)<.00003,"hollow curb extension bears on original structural slab: "+str(spec.id));bearing_checks+=1
		var eye:=Vector3(p.x+1.,20.85,p.z-.9);player.global_position=root.to_global(eye)-Vector3.UP*player.STANDING_EYE;player.camera.global_position=root.to_global(eye);player.set_lamp_enabled(true);await _roof_capture("raised_"+str(spec.id),Vector3(p.x,float(spec.weather_terminal_y)+.18,p.z))
	for spec: Dictionary in fixture.tank_boots:
		var leg: Node3D=root.get_node(spec.id);var p:=leg.position
		var eye:=Vector3(p.x+.65,20.85,p.z-.65);player.global_position=root.to_global(eye)-Vector3.UP*player.STANDING_EYE;player.camera.global_position=root.to_global(eye);player.set_lamp_enabled(true);await _roof_capture("weather_"+str(spec.id),Vector3(p.x,float(spec.weather_terminal_y)-.06,p.z))
	print("INSTALLED PLANT WEATHER: 4 live fans; ",bearing_checks," original slab bearings; register emitters=",source_audio," failures=",failures.size())

func _receivers(root: Node3D) -> void:
	var receiver_fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_drainage_receivers.json"))
	var receiver_model: Node3D=root.get_node("RoofReceivers")
	var exclusions: Array[RID]=[player.get_rid()]
	for model: Node3D in [receiver_model,root.get_node("Ground"),root.get_node("RoofLeaders")]:
		for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):exclusions.append(body.get_rid())
	var physics:=world.get_world_3d().direct_space_state
	var clearance:=0
	var paths: Array=receiver_fixture.trunks.duplicate(true)
	for row: Dictionary in receiver_fixture.receivers:var q:=row.duplicate(true);q["path"]=q.axis;paths.append(q)
	for row: Dictionary in receiver_fixture.cleanouts:paths.append({"id":row.id,"path":row.riser_axis,"outer_radius":.1683})
	for row: Dictionary in paths:
		for i in range(row.path.size()-1):
			var a:=_v(row.path[i]);var b:=_v(row.path[i+1]);var count:=ceili(a.distance_to(b)/.08)
			for k in range(count+1):
				var at:=a.lerp(b,float(k)/count);var shape:=SphereShape3D.new();shape.radius=.190 if float(row.outer_radius)>.16 else .094
				var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.margin=0.;query.transform=Transform3D(Basis.IDENTITY,root.to_global(at));query.collision_mask=1;query.exclude=exclusions
				var hits: Array[Dictionary]=physics.intersect_shape(query,32)
				for hit: Dictionary in hits:print("INSTALLED RECEIVER RETAINED CONTACT ",row.id," at ",at," ",root.get_path_to(hit.collider))
				_require(hits.is_empty(),"complete collector and cleanout envelope clears retained owners "+str(row.id)+" "+str(at));clearance+=1
	var beds: Array=receiver_fixture.main_saddle_beds.duplicate(true)
	for row: Dictionary in receiver_fixture.receivers+receiver_fixture.cleanouts:
		for stock: Dictionary in receiver_fixture.closed_stocks:
			if stock.name==row.bed_owner:beds.append({"id":stock.name,"bounds":stock.bounds})
	for row: Dictionary in beds:
		var low:=_v(row.bounds.slice(0,3));var high:=_v(row.bounds.slice(3,6));var shape:=BoxShape3D.new();shape.size=high-low-Vector3.ONE*.00001
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.margin=0.;query.transform=Transform3D(Basis.IDENTITY,root.to_global((low+high)*.5));query.collision_mask=1;query.exclude=exclusions
		var hits: Array[Dictionary]=physics.intersect_shape(query,32)
		for hit: Dictionary in hits:print("INSTALLED BED RETAINED CONTACT ",row.id," ",root.get_path_to(hit.collider))
		_require(hits.is_empty(),"native concrete bed clears retained non-soil owners "+str(row.id));clearance+=1
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	for row: Dictionary in receiver_fixture.receivers+receiver_fixture.cleanouts:
		var p:=_v(row.axis[0]) if row.has("axis") else Vector3(float(row.center[0]),0.,float(row.center[1]));p.y=float(row.native_grade_y if row.has("native_grade_y") else row.grade_y)
		var offset:=Vector3(.55,1.65,.65)
		if str(row.id).begins_with("W"):offset=Vector3(-16.35-p.x,1.65,.65)
		elif str(row.id).begins_with("S_"):offset=Vector3(.55,1.65,-.65)
		elif row.id=="EAST_CLEANOUT":offset=Vector3(-.45,1.65,-.65)
		var eye: Vector3=p+offset;player.global_position=root.to_global(eye)-Vector3.UP*player.STANDING_EYE;player.camera.global_position=root.to_global(eye);player.set_lamp_enabled(true)
		# Read-only views must come from clear air in the actual narrow passages.
		var eye_volume:=SphereShape3D.new();eye_volume.radius=.025;var eye_query:=PhysicsShapeQueryParameters3D.new();eye_query.shape=eye_volume;eye_query.margin=0.;eye_query.transform=Transform3D(Basis.IDENTITY,root.to_global(eye));eye_query.collision_mask=1;eye_query.exclude=[player.get_rid()]
		var eye_hits: Array[Dictionary]=physics.intersect_shape(eye_query,32)
		for hit: Dictionary in eye_hits:print("INSTALLED RECEIVER CAMERA CONTACT ",row.id," ",root.get_path_to(hit.collider))
		_require(eye_hits.is_empty(),"receiver view eye is in actual clear air "+str(row.id))
		await _roof_capture("receiver_"+str(row.id),p+Vector3.UP*.05)
	print("INSTALLED RECEIVER COMPOSITION: ",clearance," retained envelope/bed checks; failures=",failures.size())
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"));FileAccess.open(OS.get_environment("SHOT_DIR").path_join("receiver-composition.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","failures":failures,"retained_clearance_checks":clearance}))
