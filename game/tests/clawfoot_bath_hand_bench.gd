extends Node3D
## Isolated production actor/input diagnostic, not occupied-world qualification.
const Bath=preload("res://scripts/props/clawfoot_bath_prop.gd")
const Hand=preload("res://tests/fixed_gesture_patrol_hand.gd")
var bath:TapProp
var player:PlayerController
var hand:Node3D
var checks:=0
var failures:Array[String]=[]
var directory:String

func check(ok:bool,label:String) -> bool:
	checks+=1;print("CLAWFOOT HAND ","PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
	return ok

func click() -> void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.position=get_viewport().get_mouse_position();event.global_position=event.position
		Input.parse_input_event(event)
	await get_tree().physics_frame
	for frame in 3:await get_tree().process_frame

func operate(point:Vector3,goal:float,label:String) -> bool:
	player.face_world_point(point)
	await get_tree().physics_frame;await get_tree().physics_frame
	await click()
	if not check(player._grab.active() and player._grab.target.get("owner")==bath,"primary acquires "+label):return false
	var moved:bool=await hand.move_to(goal)
	check(moved,"mouse motion reaches "+label)
	await click()
	return check(not player._grab.active(),"next primary releases "+label) and moved

func shot(label:String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))

func check_surface(draw:MeshInstance3D,surface:int,material:Material) -> void:
	var arrays:=draw.mesh.surface_get_arrays(surface)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var valid:=uv.size()==vertices.size() and normals.size()==vertices.size() and tangents.size()==vertices.size()*4
	var minimum:=1.0
	var metric_error:=0.0
	if valid:
		for start in range(0,indices.size(),3):
			var a:=indices[start];var b:=indices[start+1];var c:=indices[start+2]
			var s:=uv[b]-uv[a];var t:=uv[c]-uv[a];var det:=s.cross(t)
			if not is_finite(det) or absf(det)<=1e-12:valid=false;continue
			var derivative:=((vertices[b]-vertices[a])*t.y-(vertices[c]-vertices[a])*s.y)/det
			for edge:Array in [[a,b],[b,c],[c,a]]:
				var length:float=vertices[edge[0]].distance_to(vertices[edge[1]])
				if length>1e-8:metric_error=maxf(metric_error,absf(uv[edge[0]].distance_to(uv[edge[1]])/length-1.0))
			for index:int in [a,b,c]:
				var tangent:=Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2])
				var expected:=(derivative-normals[index]*normals[index].dot(derivative)).normalized()
				minimum=minf(minimum,tangent.dot(expected))
				valid=valid and vertices[index].is_finite() and uv[index].is_finite() and normals[index].is_finite() and tangent.is_finite()
	check(valid and minimum>.995,"loaded finite metric charts and tangent derivatives: "+str(draw.name)+" / "+str(surface)+" minimum="+str(minimum))
	check(metric_error<.005,"loaded physical UV edges within 0.5 percent: "+str(draw.name)+" / "+str(surface)+" maximum="+str(metric_error))
	var maps:Array=[]
	if material is StandardMaterial3D:
		check(not MatLib.is_shared_material(material) and not material.uv1_triplanar,"private finish samples authored charts")
		maps=[material.albedo_texture,material.roughness_texture,material.normal_texture]
	elif material is ShaderMaterial:
		maps=[material.get_shader_parameter("albedo_tex"),material.get_shader_parameter("rough_tex"),material.get_shader_parameter("normal_tex")]
	for texture:Texture2D in maps:
		var image:=texture.get_image() if texture!=null else null
		check(image!=null and image.has_mipmaps() and image.get_mipmap_count()==int(floor(log(float(maxi(image.get_width(),image.get_height())))/log(2.0))),"loaded complete PBR mip chain")

func walk_to(goal:Vector3,label:String) -> bool:
	player.face_world_point(Vector3(goal.x,player.camera.global_position.y,goal.z))
	player.set_physics_process(true)
	var event:=InputEventAction.new();event.action="move_forward";event.pressed=true;Input.parse_input_event(event)
	for i in 300:
		await get_tree().physics_frame
		if Vector2(player.global_position.x-goal.x,player.global_position.z-goal.z).length()<.09:break
	event=InputEventAction.new();event.action="move_forward";event.pressed=false;Input.parse_input_event(event)
	for i in 60:await get_tree().physics_frame
	player.set_physics_process(false)
	print("CLAWFOOT WALK ",label," goal=",goal," actual=",player.global_position)
	return check(Vector2(player.global_position.x-goal.x,player.global_position.z-goal.z).length()<.13 and absf(player.global_position.y-goal.y)<.045,label+" through actual movement and full capsule collision")

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	directory=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var floor_body:=StaticBody3D.new();add_child(floor_body)
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(8,.2,8)
	collision.shape=box;collision.position.y=-.1;floor_body.add_child(collision)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.055,.067,.074)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.72,.78,.85);environment.environment.ambient_light_energy=.55;add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,-32,0);sun.light_energy=1.2;add_child(sun)
	bath=Bath.new();bath.prop_type="shower";bath.fixture="shower";bath.unit="4B";add_child(bath)
	if not check(bath.native_ready and bath.mount_fixture_collision(),"native vessel and bowl collision mount on actual TapProp"):finish();return
	player=PlayerController.new();player.position=Vector3(.32,0,-1.15);add_child(player)
	player.set_physics_process(false);player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	hand=Hand.new();hand.player=player;add_child(hand)
	# The native fullscreen override settles after two rendered frames. Input
	# queued before the first OS-window frame is not a valid pointer exercise.
	for frame in 8:await get_tree().process_frame
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame;await get_tree().physics_frame
	var material_count:=0
	for draw:MeshInstance3D in bath.model.find_children("*","MeshInstance3D",true,false):
		for surface in draw.mesh.get_surface_count():
			var material:=draw.get_surface_override_material(surface)
			check(material!=null,"private native finish "+str(draw.name)+" / "+str(surface));material_count+=1
			check_surface(draw,surface,material)
	check(material_count==13,"all thirteen native surfaces have finish bindings")
	var curtain_point:Vector3=bath.model.to_global(Bath.CurtainMotion.cloth_centerline(.75,.5,0))
	if not await operate(curtain_point,Bath.CurtainMotion.TRAVEL*.5,"half curtain"):finish();return
	await shot("curtain_half")
	curtain_point=bath.model.to_global(Bath.CurtainMotion.cloth_centerline(.75,.5,.5))
	if not await operate(curtain_point,Bath.CurtainMotion.TRAVEL,"open curtain"):finish();return
	check(bath.is_curtain_open(),"actual curtain gesture opens usable aperture")
	for index in 2:
		var part:Node3D=bath._handles[index]
		if not await operate(part.global_position+Vector3(0,0,-.06),PI*.25,"hot valve" if index==0 else "cold valve"):finish();return
	check(is_equal_approx(float(bath.get_flow_state().hot_opening),.5) and is_equal_approx(float(bath.get_flow_state().cold_opening),.5),"independent physical valves retain exact partial flow")
	if not await operate(bath.diverter.global_position,0.0,"bath diverter"):finish();return
	check(bath.spray_flow_amount()==0 and bath.filler.visible and not bath._stream.visible,"diverter routes actual supply to filler without shower spray")
	await shot("bath_filler")
	# The low stopper is reached from inside the vessel, not through its wall.
	if not await walk_to(bath.model.to_global(Vector3(0,.239,0)),"enter tub"):finish();return
	await get_tree().physics_frame
	var capsule:=PhysicsShapeQueryParameters3D.new();capsule.shape=player._capsule
	capsule.transform=player.global_transform*player._shape.transform;capsule.exclude=[player.get_rid()]
	var overlaps:=get_world_3d().direct_space_state.intersect_shape(capsule)
	print("CLAWFOOT STANDING CAPSULE ",overlaps)
	check(overlaps.is_empty(),"full-size standing capsule clears native bowl at the standing datum")
	player.face_world_point(bath._bath_plug.global_position)
	await get_tree().physics_frame;await get_tree().physics_frame
	await click()
	if not check(player._grab.active() and player._grab.target.get("part")==bath._bath_plug,"primary grabs the actual removable stopper"):finish();return
	var seat:Vector3=bath.model.to_global(bath.plug_seat)
	var pixels:=player.camera.unproject_position(seat)-player.camera.unproject_position(bath._bath_plug.global_position)
	for i in 12:
		var motion:=InputEventMouseMotion.new();motion.relative=pixels/12
		Input.parse_input_event(motion);await get_tree().physics_frame
	check(bath._plug_hand.held,"mouse movement retains plug ownership")
	var held_snapshot:Dictionary=bath.mechanism_snapshot()
	check(Vector3(held_snapshot.plug[0],held_snapshot.plug[1],held_snapshot.plug[2]).distance_to(bath.plug_parked)<.00001,"save snapshot excludes an uncommitted held plug pose")
	await click()
	check(bath._stopper and bath._bath_plug.position.distance_to(bath.plug_seat)<.00001,"release snaps stopper into drain without rest simulation")
	await get_tree().create_timer(1.5).timeout
	check(bath._water_level>.05,"closed drain collects authoritative mixed water")
	for index in 2:
		if not await operate(bath._handles[index].global_position+Vector3(0,0,-.06),0.0,"closed valve "+str(index)):finish();return
	var snapshot:Dictionary=bath.mechanism_snapshot()
	check(bath.valid_mechanism(snapshot),"complete curtain, diverter, stopper and water snapshot validates")
	var path:=directory.path_join("mechanism.json")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(snapshot,"",true,true))
	var decoded:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(bath.valid_mechanism(decoded),"JSON disk round trip retains validated mechanism domain")
	for key:String in ["hot","cold","curtain","water","diverter"]:
		var corrupt:=decoded.duplicate(true);corrupt[key]=NAN
		check(not bath.valid_mechanism(corrupt),"nonfinite save rejected: "+key)
	var extra:=decoded.duplicate(true);extra["invented"]=true
	check(not bath.valid_mechanism(extra),"unknown save field rejected")
	check(bath.valid_mechanism({"hot":.2,"cold":.4,"curtain":.7}),"existing shower save remains accepted")
	bath.restore_mechanism({"hot":0,"cold":0,"curtain":0})
	bath.restore_mechanism(decoded)
	var restored:Dictionary=bath.mechanism_snapshot()
	# JSON's decimal parser can differ in the final double bit; plug positions
	# are authoritative Vector3 (float32), not arbitrary double-valued arrays.
	var expected_plug:=Vector3(decoded.plug[0],decoded.plug[1],decoded.plug[2])
	var restored_plug:=Vector3(restored.plug[0],restored.plug[1],restored.plug[2])
	var expected_scalars:=decoded.duplicate(true);expected_scalars.erase("plug")
	var restored_scalars:=restored.duplicate(true);restored_scalars.erase("plug")
	var scalar_error:=0.0
	for key:String in expected_scalars:scalar_error=maxf(scalar_error,absf(float(expected_scalars[key])-float(restored_scalars[key])))
	check(restored_plug==expected_plug and scalar_error<=1e-12,"restore recovers exact Vector3 pose and scalar fields within decimal parser roundoff: "+str(scalar_error))
	var chain_ids:Array=[]
	for i in bath.chain.instance_count:chain_ids.append(bath.chain.get_instance_transform(i))
	for i in 15:await get_tree().physics_frame
	var unchanged:=true
	for i in bath.chain.instance_count:unchanged=unchanged and chain_ids[i]==bath.chain.get_instance_transform(i)
	check(unchanged,"resting stopper chain remains stationary")
	await shot("saved_bath")
	check(await walk_to(bath.model.to_global(Vector3(0,0,-1.05)),"exit tub"),"open tub permits return to room floor")
	finish()

func finish() -> void:
	var report:={"evidence_class":"INERT","checks":checks,"failures":failures,"scope":"Isolated production bath with actual player grab/motion/release, walked entry/exit, full-size capsule and mechanism JSON disk round trip. Not occupied-world access, validated campaign reconstruction, performance, surface qualification or human acceptance."}
	FileAccess.open(directory.path_join("clawfoot_hand.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CLAWFOOT HAND COMPLETE ",JSON.stringify(report))
	if is_instance_valid(player):player._grab.release()
	get_tree().quit(0 if failures.is_empty() else 1)
