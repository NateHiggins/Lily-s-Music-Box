extends "res://tests/direct_manipulation_test.gd"
## INERT: actual grab/motion/release at two ranges and two fields of view.
func _run() -> void:
	RealityState.persistence_enabled=false
	var shower:=TapProp.new();shower.fixture="shower";shower.prop_type="shower";add_child(shower)
	player=PlayerController.new();add_child(player);player.set_physics_process(false);player.camera.make_current()
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-25,0);add_child(sun)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var rows: Array=[]
	check(shower._curtain_skinned and shower._curtain_hand.configured,"native skin is the installed interaction path")
	if not shower._curtain_skinned or not shower._curtain_hand.configured:
		get_tree().quit(1);return
	check(shower._curtain_hand.skeleton.get_bone_count()==116,"native cloth and rigid rings retain all bearings")
	check(shower._curtain_hand.proxies.size()==36,"selection uses fixed reusable shapes")
	var mesh_ids: Array=[]
	var inspector:=preload("res://tests/orison_v2_surface_inventory.gd").new()
	var surfaces: Array=[]
	for draw: MeshInstance3D in shower._curtain_closed.find_children("*","MeshInstance3D",true,false):
		check(draw.skin!=null and draw.get_node_or_null(draw.skeleton)==shower._curtain_hand.skeleton,"actual imported draw is bound to the native skeleton")
		mesh_ids.append(draw.mesh.get_instance_id())
		var mesh: Dictionary=inspector._mesh(draw.mesh)
		for surface: Dictionary in mesh.surfaces:
			check(not surface.missing_uv and surface.nonfinite_uv==0 and surface.degenerate_uv_triangles==0,"native cloth/ring UVs remain finite and nondegenerate")
		var material: Dictionary=inspector._material(draw.get_active_material(0))
		check(material.maps.size()>=3,"cloth/rings retain custom PBR maps")
		surfaces.append({"mesh":mesh,"material":material})
	check(mesh_ids.size()==2,"exactly two native curtain draws")
	for path: String in inspector.texture_rows:
		var texture: Dictionary=inspector.texture_rows[path]
		var expected:=int(log(float(maxi(int(texture.width),int(texture.height))))/log(2.0)+.000001)
		check(texture.mips and int(texture.mip_levels)==expected,"loaded complete mip chain: "+path)
	for stop: float in [0.,.89,1.78]:
		shower._curtain_hand.set_travel(stop)
		var saved: Dictionary=shower.mechanism_snapshot()
		check(shower.valid_mechanism(saved),"existing mechanism owner validates curtain stop")
		var rebuilt:=TapProp.new();rebuilt.fixture="shower";rebuilt.prop_type="shower";add_child(rebuilt)
		rebuilt.restore_mechanism(saved)
		check(rebuilt.mechanism_snapshot()==saved and not rebuilt._curtain_hand.held,"fresh fixture reconstructs exact released partial/full curtain state")
		rebuilt.free()
	player.position=Vector3(1.1,-.15,-1.2);player.camera.look_at(Vector3(0,1.15,0))
	for stop: float in [0.,.89,1.78]:
		shower._curtain_hand.set_travel(stop)
		for frame in 4:await get_tree().process_frame
		var output:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(output)
		get_viewport().get_texture().get_image().save_png(output.path_join("curtain_%03d.png"%int(stop*100)))
	for distance: float in [.85,1.55]:
		for fov: float in [55.,85.]:
			shower.set_curtain_open(false)
			player.position=Vector3(0,-.35,-distance)
			player.camera.fov=fov;player.camera.look_at(shower.to_global(Vector3(0,1.25,-.32)))
			for frame in 2:await get_tree().physics_frame
			click();check(player._grab.active() and shower._curtain_hand.held,"real cloth acquired")
			check(is_zero_approx(shower._curtain_hand.travel),"acquisition alone leaves cloth closed")
			for step in 24:drag(Vector2(-12,0));await get_tree().physics_frame
			var opened: float=shower._curtain_hand.travel
			check(is_equal_approx(opened,shower._curtain_hand.TRAVEL),"288 pixels open full U rail")
			for step in 24:drag(Vector2(12,0));await get_tree().physics_frame
			check(is_zero_approx(shower._curtain_hand.travel),"matching reverse gesture closes full U rail")
			click();check(not shower._curtain_hand.held,"next primary releases cloth")
			rows.append({"distance":distance,"fov":fov,"gesture_pixels":288,"opening_m":opened,"closing_m":shower._curtain_hand.travel})
	var final_ids: Array=[]
	for draw: MeshInstance3D in shower._curtain_closed.find_children("*","MeshInstance3D",true,false):final_ids.append(draw.mesh.get_instance_id())
	check(final_ids==mesh_ids,"all gestures reuse the original imported meshes")
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("gestures.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","rows":rows,"surfaces":surfaces,"textures":inspector.texture_rows,"failures":failures},"\t"))
	inspector.free()
	print("CURTAIN GESTURE BENCH: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	get_tree().quit(failures.size())
