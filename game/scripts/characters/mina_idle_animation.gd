extends RefCounted
## A restrained idle authored in Mina's own bind frame. No donor joint
## spacing/axes and no change to the imported mesh or its proportions.
static func install(actor: AnimatedResident) -> bool:
	var skeleton := ResidentMovesLibrary._find_skeleton(actor)
	var player := actor._animation_player
	if skeleton == null or player == null: return false
	var animation := Animation.new()
	animation.length = 3.6
	animation.loop_mode = Animation.LOOP_LINEAR
	var root := player.get_node(player.root_node)
	var skeleton_path := root.get_path_to(skeleton)
	for bone in skeleton.get_bone_count():
		var rest := skeleton.get_bone_rest(bone)
		var rotation := rest.basis.get_rotation_quaternion()
		var bone_name := skeleton.get_bone_name(bone)
		if bone_name in ["LeftArm","RightArm"]:
			var elbow := skeleton.find_bone("LeftForeArm" if bone_name == "LeftArm" else "RightForeArm")
			var arm_rest := skeleton.get_bone_global_rest(bone)
			var direction := skeleton.get_bone_global_rest(elbow).origin-arm_rest.origin
			var desired := Vector3(signf(direction.x)*.15,-1,0).normalized()
			var delta := Quaternion(direction.normalized(),desired)
			var parent_rest := skeleton.get_bone_global_rest(skeleton.get_bone_parent(bone))
			rotation = parent_rest.basis.get_rotation_quaternion().inverse()*delta*arm_rest.basis.get_rotation_quaternion()
		var translation_track := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(translation_track,NodePath("%s:%s"%[skeleton_path,bone_name]))
		animation.position_track_insert_key(translation_track,0,rest.origin)
		var rotation_track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(rotation_track,NodePath("%s:%s"%[skeleton_path,bone_name]))
		for time in [0.0,1.8,3.6]:
			var pose := rotation
			if bone_name == "Spine" and time == 1.8:
				pose = rotation * Quaternion(Vector3.RIGHT,deg_to_rad(.35))
			animation.rotation_track_insert_key(rotation_track,time,pose)
	var library := player.get_animation_library("")
	if library.has_animation("mina_calm_idle"): library.remove_animation("mina_calm_idle")
	library.add_animation("mina_calm_idle",animation)
	actor.preferred_idle = "mina_calm_idle"
	actor.preferred_walk = "mina_vale_Walk"
	player.stop()
	skeleton.reset_bone_poses()
	actor._play_named("idle")
	return true
