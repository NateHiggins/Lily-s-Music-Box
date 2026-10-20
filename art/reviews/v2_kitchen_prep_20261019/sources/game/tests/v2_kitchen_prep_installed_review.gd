extends Node
## Combined installed diagnostics, local physical input and render review.
var checks: Array[Dictionary]=[]
var failures: Array[String]=[]
func check(ok: bool,label: String) -> bool:
	checks.append({"ok":ok,"label":label})
	if not ok:failures.append(label);push_error(label)
	return ok
func click(player: PlayerController) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;player._unhandled_input(event)
func run(world: OrisonV2RuntimeRoot,directory: String) -> bool:
	var root: Node3D=world.adapter.root;var player: PlayerController=world.player
	player.set_physics_process(false);player.set_lamp_enabled(false);player.carried_device.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var survey:=preload("res://tests/v2_kitchen_prep_survey.gd").new();add_child(survey)
	# Reuses the source survey's player capsule and current production collision.
	var discovery: Dictionary=survey.run(world,directory)
	for room: Dictionary in discovery.rooms:
		check(room.unresolved_existing_stances.is_empty(),"existing kitchen clearance stances retained: "+str(room.space))
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/kitchen_prep_stations.json"))
	var saved: Dictionary=world.household_state.snapshot();var pictures: Array=[];var textures: Dictionary={}
	var camera:=Camera3D.new();add_child(camera)
	for row: Dictionary in data.stations:
		var station:=world.adapter.resolve(str(row.id)) as Node3D
		if not check(station!=null,"installed prep owner: "+str(row.id)):continue
		check(saved.records.has(str(row.id)) and saved.records[str(row.id)].kind=="mechanism","household save owns prep tools: "+str(row.id))
		check(station.valid_mechanism(station.mechanism_snapshot()),"installed loose poses valid: "+str(row.id))
		var bridge: bool=row.template=="SinkBridge"
		var excluded: Array[RID]=[]
		for collision: CollisionObject3D in station.find_children("*","CollisionObject3D",true,false):excluded.append(collision.get_rid())
		var bearings: Array[Vector3]=[]
		if bridge:
			for x: float in [-.305,.305]:bearings.append(Vector3(x,.9125,-.035))
		else:
			for template: Dictionary in data.templates:
				if template.id!=row.template:continue
				for x: float in [-float(template.width)/2.+.055,float(template.width)/2.-.055]:
					for z: float in [-float(template.depth)/2.+.055,float(template.depth)/2.-.055]:bearings.append(Vector3(x,0,z))
		for local: Vector3 in bearings:
			var at: Vector3=station.to_global(local)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.025,at-Vector3.UP*.025,1,excluded))
			check(not hit.is_empty() and hit.position.distance_to(at)<.00004 and hit.normal.y>(.9 if bridge else .99),"actual native support meets prep stock: "+str(row.id)+str(local))
		for draw: MeshInstance3D in station.find_children("*","MeshInstance3D",true,false):
			var material:=draw.get_active_material(0) as StandardMaterial3D
			check(material!=null and not material.uv1_triplanar and material.normal_enabled,"installed authored PBR surface: "+str(row.id)+str(draw.name))
			if material==null:continue
			for texture: Texture2D in [material.albedo_texture,material.normal_texture,material.roughness_texture]:
				if texture==null:check(false,"missing installed PBR map");continue
				if textures.has(texture.resource_path):continue
				var image:=texture.get_image();var complete: bool=image!=null and image.has_mipmaps() and image.get_mipmap_count()==int(floor(log(maxi(image.get_width(),image.get_height()))/log(2.)))
				textures[texture.resource_path]=complete;check(complete,"complete installed PBR mip chain: "+texture.resource_path)
		var depth:=.6
		if not bridge:
			for template: Dictionary in data.templates:
				if template.id==row.template:depth=template.depth
		var selected:=false
		for distance: float in [depth*.5+.43,.90,1.08]:
			for x: float in [0.,-.20,.20]:
				var feet: Vector3=station.to_global(Vector3(x,.025,-distance))
				if survey.clear_feet(root.to_local(feet)):
					player.global_position=feet;player.velocity=Vector3.ZERO;selected=true;break
			if selected:break
		if not check(selected,"clear player stance at added prep stock: "+str(row.id)):continue
		player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		var body: RigidBody3D=station.tools["SinkBridge" if bridge else "Breadboard"]
		# Pick the clear front edge; a pin laid across the board remains a separate part.
		var point: Vector3=body.to_global(Vector3(0,.02,-.11))
		player.camera.look_at(point);await get_tree().physics_frame;await get_tree().physics_frame;player.camera.look_at(point)
		check(player._grab.find_target().get("part")==body,"installed board ray selection: "+str(row.id))
		var before:=body.transform;click(player)
		check(player._grab.active() and station.held==body,"installed click grabs board: "+str(row.id))
		for step in 6:
			var motion:=InputEventMouseMotion.new();motion.relative=Vector2(0,-12);player._unhandled_input(motion);await get_tree().physics_frame
		check(body.position.distance_to(before.origin)>.025,"installed mouse lifts board: "+str(row.id))
		click(player);check(not player._grab.active() and station.held==null,"installed click releases board: "+str(row.id))
		# Restore the retained original scene arrangement for visual comparison.
		player.cancel_manipulation();station.restore_mechanism(saved.records[str(row.id)].value)
		camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
		camera.global_position=station.to_global(Vector3(.48,1.65,-1.55));camera.look_at(station.to_global(Vector3(0,.9,0)));camera.fov=60.
		for frame in 6:await RenderingServer.frame_post_draw
		var image:=get_viewport().get_texture().get_image();var name: String=str(row.id)+".png"
		check(image.save_png(directory.path_join(name))==OK,"installed kitchen image: "+str(row.id));pictures.append(name)
	check(data.stations.size()==18,"all eighteen kitchen preparation programmes installed")
	check(world.household_state.validate(world.household_state.snapshot(),world.household_state._kinds),"installed household snapshot validates with new tool owners")
	FileAccess.open(directory.path_join("installed_review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Installed discovery, native bearing rays, loaded PBR maps, local player grab/mouse/release, save-domain membership and posed kitchen views; not whole-building played routes or human acceptance","checks":checks,"failures":failures,"pictures":pictures,"loaded_maps":textures},"\t"))
	print("KITCHEN PREP INSTALLED: kitchens=",data.stations.size()," checks=",checks.size()," failures=",failures.size())
	camera.free();survey.free()
	return failures.is_empty()
