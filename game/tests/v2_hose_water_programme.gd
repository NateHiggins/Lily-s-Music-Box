extends RefCounted
## Actual water-control input, with explicit repaired-line fixture preconditions.
func _section_capture(bench: Node,hose: Node3D,name: String) -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory)
	var camera:=Camera3D.new();bench.add_child(camera);camera.fov=45.
	var point: Vector3=hose.model.to_global(hose.rig.strand.points[hose.rig.indices.size()/2])
	camera.global_position=point+Vector3(.1,.4,.5);camera.look_at(point);camera.make_current()
	await RenderingServer.frame_post_draw
	bench.check(bench.get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))==OK,"native hose section render saved: "+name)
	bench.player.camera.make_current();camera.free()

func run(bench: Node,actor: Node3D,hose: Node3D) -> void:
	hose.enable_visual_follow()
	var middle: int=hose.rig.indices.size()/2
	var scale: Vector3=hose.rig.skeleton.get_bone_pose_scale(hose.rig.indices[middle])
	bench.check(scale.x<.11 and scale.z>1.5,"uncharged native hose is a flat ribbon with unchanged longitudinal scale")
	bench.check(not hose.is_physics_processing(),"empty uncharged hose performs no resting fluid or cloth tick")
	await _section_capture(bench,hose,"flat_native_stock")
	# This programme tests operation, not the earlier maintenance assembly.
	actor.gasket_seated=true;actor.coupling_made_up=true;actor.nozzle_coupled=true
	actor._nozzle_joint.restore_legacy(true)
	var hand: Node=bench.Hand.PatrolHand.new();hand.player=bench.player;bench.add_child(hand)
	await bench.aim(actor._tag.to_global(Vector3(0,0,.0035)));bench.click();bench.key(KEY_SPACE)
	if not bench.check(bench.player.inspecting(),"actual grabbed tag enters water-control inspection"):hand.free();return
	if not bench.check(await bench.inspect_operate(hand,actor._lever,actor._lever.to_global(Vector3(.07,0,0)),0.),"actual mouse closes nozzle lever before charging"):hand.free();return
	var wheel: Node3D=actor._valve_wheel
	if not bench.check(await bench.inspect_operate(hand,wheel,wheel.to_global(Vector3(.04,0,0)),TAU*2.),"actual grab and mouse rotation open the separate supply valve"):hand.free();return
	for frame in range(Engine.physics_ticks_per_second*4+2):await bench.get_tree().physics_frame
	print("HOSE CHARGE: ",hose.water.snapshot()," supply=",actor._wheel_angle," lever=",actor._lever_angle," ticks=",Engine.physics_ticks_per_second)
	bench.check(hose.water.fill>.99 and hose.water.pressure>.99 and hose.water.spray==0.,"closed nozzle can hold a full charge without spraying")
	scale=hose.rig.skeleton.get_bone_pose_scale(hose.rig.indices[middle])
	bench.check(scale.is_equal_approx(Vector3.ONE),"charging rounds the native hose without changing its length axis")
	bench.check(not hose.is_physics_processing(),"stable charged hose stops CPU fluid and cloth callbacks")
	await _section_capture(bench,hose,"round_native_stock")
	if not bench.check(await bench.inspect_operate(hand,actor._lever,actor._lever.to_global(Vector3(.07,0,0)),-.95),"actual separate nozzle lever starts water spray"):hand.free();return
	for frame in 35:await bench.get_tree().physics_frame
	bench.check(hose.water.spray>.7 and hose._spray!=null and hose._spray.emitting,"open lever emits water only through the charged nozzle")
	var finish: StandardMaterial3D=hose._spray.draw_pass_1.material
	bench.check(finish.normal_enabled and not finish.uv1_triplanar,"water spray retains the registered UV-based custom water finish")
	for texture: Texture2D in [finish.albedo_texture,finish.normal_texture,finish.roughness_texture]:
		bench.check(texture!=null and texture.get_image().get_mipmap_count()>0,"spray PBR map has its loaded mip chain")
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var camera:=Camera3D.new();bench.add_child(camera);camera.fov=55.
		var tip: Vector3=actor._nozzle_joint.body.to_global(Vector3(0,.171,0))
		var forward: Vector3=actor._nozzle_joint.body.global_basis.y
		camera.global_position=tip+forward*.5+Vector3(0,.3,.7)
		camera.look_at(tip+forward*.6);camera.make_current()
		await RenderingServer.frame_post_draw
		bench.check(bench.get_viewport().get_texture().get_image().save_png(directory.path_join("charged_spray.png"))==OK,"charged spray and round hose are captured")
		bench.player.camera.make_current();camera.free()
	if not bench.check(await bench.inspect_operate(hand,wheel,wheel.to_global(Vector3(.04,0,0)),0.),"actual supply valve closure is independent of nozzle lever"):hand.free();return
	for frame in range(Engine.physics_ticks_per_second*5+2):await bench.get_tree().physics_frame
	bench.check(hose.water.fill<.001 and hose.water.pressure<.001 and hose.water.spray==0. and not hose._spray.emitting,"open nozzle drains the isolated hose and stops spray")
	scale=hose.rig.skeleton.get_bone_pose_scale(hose.rig.indices[middle])
	bench.check(scale.x<.11 and scale.z>1.5 and not hose.is_physics_processing(),"drained hose lies flat without resting simulation")
	bench.check(not actor.tag_signed and not actor.gasket_seen,"charging and spraying do not certify or fabricate gasket inspection")
	# Negative fixture condition: do not claim this is a user gasket-removal
	# programme. The actual valve input must respect the original joint truth.
	actor.gasket_seated=false
	if not bench.check(await bench.inspect_operate(hand,wheel,wheel.to_global(Vector3(.04,0,0)),TAU*2.),"actual supply operation exercises the missing-gasket denial"):hand.free();return
	for frame in range(Engine.physics_ticks_per_second+2):await bench.get_tree().physics_frame
	bench.check(hose.water.fill==0. and hose.water.pressure==0. and hose.water.spray==0. and not hose._spray.emitting,"missing gasket prevents hose charging and nozzle spray")
	bench.check(await bench.inspect_operate(hand,wheel,wheel.to_global(Vector3(.04,0,0)),0.),"actual supply input returns the denied line to shut")
	bench.key(KEY_ESCAPE);hand.free()
