extends Node
## Actual production mirror captures; the supplied clip advances in real time.
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1;print("PLAYER MIRROR: ",label," = ",ok)
	if not ok:failures.append(label)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	var world: OrisonV2RuntimeRoot=load("res://scenes/building/orison_v2_runtime.tscn").instantiate();add_child(world)
	check(not world.startup_failed,"production occupied world starts")
	if world.startup_failed:get_tree().quit(1);return
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var avatar: Node3D=world.player_avatar
	check(avatar.native_ready and avatar.skeleton.get_bone_count()==52,"owner rig and supplied idle loaded")
	check(avatar.find_children("*","CollisionObject3D",true,false).is_empty(),"visual rig adds no physical authority")
	var layer: int=preload("res://scripts/player/doodle_player_avatar.gd").LAYER
	check((world.player.camera.cull_mask&layer)==0 and (world.mirror_renderer._camera.cull_mask&layer)!=0,"real reflected view includes avatar while first-person camera excludes it")
	check((preload("res://scripts/building/orison_v2_room_reflections.gd").CAPTURE_MASK&layer)==0,"room cube cache excludes transient avatar")
	for draw: MeshInstance3D in avatar.find_children("*","MeshInstance3D",true,false):
		check(draw.layers==layer and draw.mesh.get_faces().size()/3<25000,"one bounded native avatar partition")
		var finish:=draw.material_override as StandardMaterial3D
		check(finish!=null and not finish.uv1_triplanar and finish.normal_enabled,"registered custom finish uses supplied authored UVs")
		for texture: Texture2D in [finish.albedo_texture,finish.normal_texture,finish.roughness_texture]:
			check(texture!=null and texture.get_image().get_mipmap_count()>0,"loaded character map has mip chain")
	world.player.set_physics_process(false);world.player.velocity=Vector3.ZERO
	world.service_set_carrier.set_capture_hidden(true);world.player.set_lamp_enabled(false)
	world.player.global_position=Vector3(-14.325,6.400265,-.575)
	var mirror: Node3D
	for surface in get_tree().get_nodes_in_group("planar_mirror_surface"):
		var owner: Node=surface.get_parent()
		while owner!=null and not owner.has_method("mirror_center"):owner=owner.get_parent()
		if owner!=null and str(owner.name)=="F03_3B_MIRROR_01":mirror=owner;break
	check(mirror!=null,"existing 3B bathroom mirror resolves")
	if mirror==null:get_tree().quit(1);return
	# Looking obliquely at glass shows the room beside us. For a self-portrait
	# use a real full-capsule stance on its normal, with the basin still solid.
	var stance:=Vector3.INF
	for distance: float in [1.1,1.3,1.5,1.7,.9]:
		var feet: Vector3=mirror.mirror_center()+mirror.mirror_normal()*distance
		feet.y=6.400265
		var capsule:=CapsuleShape3D.new();capsule.radius=PlayerController.BODY_RADIUS;capsule.height=PlayerController.STANDING_HEIGHT
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=world.player.collision_mask;query.exclude=[world.player.get_rid()]
		query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*PlayerController.STANDING_HEIGHT*.5)
		if world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():stance=feet;break
	check(stance.is_finite(),"standing self-reflection clears actual basin and room collision")
	if not stance.is_finite():get_tree().quit(1);return
	world.player.global_position=stance
	world.player.face_world_point(mirror.mirror_center())
	var switches: SwitchSystem=world.get_node("V2RoomSwitches")
	var saved:=switches.room_snapshot("F03_B_BATH");var lit: Dictionary={}
	for id: String in saved:lit[id]=true
	switches.restore_room("F03_B_BATH",lit)
	for frame in 16:await RenderingServer.frame_post_draw
	check(world.mirror_renderer.active_mirror()==mirror,"production renderer selects this actual mirror")
	avatar.animator.play(avatar.idle_clip);avatar.animator.seek(0,true)
	var images: Array=[]
	for target: float in [1.,4.8,8.4]:
		while avatar.animator.current_animation_position<target:await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var label: String="mirror_idle_"+str(images.size()+1)
		check(get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))==OK,"actual player-camera mirror image: "+label)
		world.mirror_renderer._view.get_texture().get_image().save_png(directory.path_join(label+"_reflection.png"))
		var poses: Dictionary={}
		for bone: String in ["smartrig_Head","smartrig_LeftHand","smartrig_RightHand","smartrig_LeftFoot"]:
			var index: int=avatar.skeleton.find_bone(bone)
			if index>=0:poses[bone]=str(avatar.skeleton.get_bone_global_pose(index))
		images.append({"image":label+".png","clip_time":avatar.animator.current_animation_position,"bones":poses})
	check(images[0].bones!=images[1].bones and images[1].bones!=images[2].bones,"supplied skeletal idle changes across three real-time frames")
	var turn:=InputEventMouseMotion.new();turn.relative=Vector2(PI/PlayerController.MOUSE_SENS,0);Input.parse_input_event(turn)
	for frame in 8:await RenderingServer.frame_post_draw
	check(not avatar.reflected and not avatar.animator.active,"leaving mirror stops reflected animation work")
	switches.restore_room("F03_B_BATH",saved)
	FileAccess.open(directory.path_join("review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"images":images,"limits":"Installed owner rig, supplied idle and actual mirror images. Not locomotion, face morphs, full V2 qualification or human acceptance."},"\t"))
	print("PLAYER MIRROR REVIEW: ","PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)
