extends Node3D
## Uninstalled candidate: loaded surfaces and voxel-light captures only.
## No gameplay, room, deployment or runtime-contract acceptance.
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	print("FIRE CAPACITY CHECK: ",label," = ",ok)
	if not ok:failures.append(label)
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	var packed:=load("res://assets/props/fire_capacity_candidate.glb") as PackedScene
	check(packed!=null,"candidate native scene loads")
	if packed==null:get_tree().quit(1);return
	var model:=packed.instantiate();add_child(model)
	var metrics: Node=preload("res://tests/orison_v2_domestic_native_test.gd").new()
	var draws: Array[Node]=model.find_children("*","MeshInstance3D",true,false)
	check(draws.size()==1,"one continuous native cloth surface")
	var catalogue: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/runtime_material_sets.json"))
	var tile: float=catalogue.materials.linen.meters_per_tile
	var finish: StandardMaterial3D=MatLib.get_mat("linen").duplicate()
	finish.uv1_triplanar=false;finish.uv1_scale=Vector3.ONE/tile
	finish.albedo_color=Color(.75,.71,.59);finish.normal_scale=.08;finish.roughness=.9;finish.metallic=0.
	check(finish.normal_enabled and not finish.uv1_triplanar,"registered custom linen samples authored metre UVs with normal mapping")
	for texture: Texture2D in [finish.albedo_texture,finish.roughness_texture,finish.normal_texture]:
		check(texture!=null and texture.get_image().get_mipmap_count()>0,"actual loaded linen PBR map has mip chain")
	for draw: MeshInstance3D in draws:
		metrics._check_cap_mapping(draw.mesh,true)
		draw.material_override=finish
	for failure: String in metrics.failures:check(false,failure)
	metrics.free()
	if not failures.is_empty():
		print("V2 FIRE CAPACITY NATIVE: FAIL failures=",failures.size())
		get_tree().quit(1);return
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();add_child(environment)
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.025,.025,.03)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.45,.5,.6);environment.environment.ambient_light_energy=.06
	var player:=PlayerController.new();player.position=Vector3(0,-1.15,1.0);add_child(player)
	player.set_physics_process(false);player.camera.make_current();player.camera.look_at(Vector3(0,.38,.1))
	var atmosphere:=preload("res://scripts/building/orison_v2_lamp_atmosphere.gd").new();add_child(atmosphere)
	check(atmosphere.setup(player,environment.environment),"production reduced carried voxel lamp mounts")
	player.set_lamp_enabled(true)
	for frame in 60:await get_tree().process_frame
	check(atmosphere.field!=null and atmosphere.field.ready and atmosphere.field.failed.is_empty(),"actual voxel field initializes without failure")
	check(player.flashlight.light_projector==null,"no patterned projector on carried source")
	var directory: String=OS.get_environment("SHOT_DIR")
	check(not directory.is_empty(),"capture destination provided")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(directory.path_join("capacity_voxel_full.png"))==OK,"full native cloth frame saved with production voxel light")
		player.position=Vector3(-.08,-.98,.46);player.camera.look_at(Vector3(-.08,.68,.1))
		for frame in 12:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(directory.path_join("capacity_voxel_crowns.png"))==OK,"close cloth chart seams and relief frame saved")
	print("V2 FIRE CAPACITY NATIVE: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	atmosphere.free();player.free();model.free();environment.free()
	for frame in 8:await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
