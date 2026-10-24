extends Node3D
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	var holder:=PlayerController.new();add_child(holder);holder.set_physics_process(false)
	var avatar:=preload("res://scripts/player/doodle_player_avatar.gd").new();avatar.holder=holder;holder.add_child(avatar)
	avatar.set_reflection_active(true)
	var camera:=Camera3D.new();add_child(camera);camera.position=Vector3(0,.9,-3);camera.look_at(Vector3(0,.8,0));camera.make_current()
	var environment:=WorldEnvironment.new();var finish:=Environment.new();finish.background_mode=Environment.BG_COLOR;finish.background_color=Color(.3,.3,.3);finish.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;finish.ambient_light_color=Color.WHITE;finish.ambient_light_energy=.8;environment.environment=finish;add_child(environment)
	var light:=DirectionalLight3D.new();add_child(light);light.rotation_degrees=Vector3(-35,-25,0)
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	var records: Array=[]
	for time: float in [0.,4.8,8.4]:
		avatar.animator.seek(time,true);avatar.animator.advance(0)
		await RenderingServer.frame_post_draw
		var geometry: Array=[]
		for draw: MeshInstance3D in avatar.find_children("*","MeshInstance3D",true,false):geometry.append({"name":str(draw.get_path()),"pose":str(draw.global_transform),"bounds":str(draw.get_aabb()),"world_bounds":str(draw.global_transform*draw.get_aabb()),"visible":draw.is_visible_in_tree(),"skeleton_path":str(draw.skeleton),"layers":draw.layers})
		var bones: Dictionary={}
		for index in avatar.skeleton.get_bone_count():bones[avatar.skeleton.get_bone_name(index)]=str(avatar.skeleton.get_bone_global_pose(index))
		records.append({"time":time,"geometry":geometry,"skeleton_pose":str(avatar.skeleton.global_transform),"bones":bones})
		get_viewport().get_texture().get_image().save_png(directory.path_join("rig_"+str(records.size())+".png"))
	FileAccess.open(directory.path_join("rig.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","records":records,"animation_names":avatar.animator.get_animation_list()},"\t"))
	print("PLAYER RIG BENCH: PASS diagnostic only");get_tree().quit()
