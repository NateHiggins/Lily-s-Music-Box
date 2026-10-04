extends Node
## Exercises delivered mineral shader binding on actual semantic geometry.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
var failures: Array[String] = []
var surfaces := 0
var concrete_surfaces := 0

func _ready() -> void: call_deferred("_run")

func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var shared:=MatLib.get_mat("stair")
	var retained_name:=shared.resource_name
	var concrete_shared:=MatLib.get_mat("concrete")
	var concrete_name:=concrete_shared.resource_name
	var world:=Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not world.startup_failed,"production startup")
	if world.startup_failed:
		world.free();get_tree().quit(1);return
	for draw: MeshInstance3D in world.adapter.root.find_children("*","MeshInstance3D",true,false):
		if draw.mesh==null:continue
		for slot in draw.mesh.get_surface_count():
			var material:=draw.get_active_material(slot) as ShaderMaterial
			if material==null:continue
			var albedo: Texture2D=material.get_shader_parameter("albedo_tex")
			if albedo==null:continue
			var is_stair:=albedo.resource_path.get_file()=="T_ai_materials_stair_albedo.png"
			var is_concrete:=albedo.resource_path.get_file()=="T_ai_materials_concrete_albedo.png"
			if not is_stair and not is_concrete:continue
			if is_stair:surfaces+=1
			else:concrete_surfaces+=1
			_check(bool(material.get_shader_parameter("has_height")),"actual mineral surface binds authored height: "+str(draw.get_path()))
			var height: Texture2D=material.get_shader_parameter("height_tex")
			var expected_height:="res://assets/building/textures/height/stair.png" if is_stair else "res://assets/building/textures/height/concrete.png"
			_check(height!=null and height.resource_path==expected_height,"delivered physical height owner")
			var relief: Variant=material.get_shader_parameter("height_relief_mm")
			var expected_relief:=(.16 if is_stair else .8)*SurfacePass.RELIEF_EXAGGERATION
			_check(relief!=null and is_equal_approx(float(relief),expected_relief),"physical units retain owner exaggeration")
			_check(material.get_shader_parameter("height_range")==Vector2(0,1),"physical height range remains authored")
			_check(is_equal_approx(float(material.get_shader_parameter("tile_m")),1.2 if is_stair else 2.8),"retained catalogue metre chart")
	_check(surfaces>100,"actual tread and half-landing population")
	_check(concrete_surfaces>100,"actual concrete wall and slab population")
	var materials: RefCounted=world.adapter.root.architectural_materials
	_check(materials.material_for("Step00","core")==materials.material_for("HalfLanding","core"),"stable named input preserves surface cache")
	_check(MatLib.get_mat("stair")==shared and shared.resource_name==retained_name,"shared catalogue material remains unmodified")
	_check(materials.material_for("WallNorth02","service")==materials.material_for("WallWest02","service"),"concrete walls preserve the stable surface cache")
	_check(materials.material_for("Floor","service")!=materials.material_for("WallNorth02","service"),"concrete floor and wall recipes retain separate shader owners")
	_check(MatLib.get_mat("concrete")==concrete_shared and concrete_shared.resource_name==concrete_name,"shared concrete catalogue material remains unmodified")
	world.shutdown_for_tests();world.free()
	await get_tree().create_timer(.25).timeout
	print("MINERAL MATERIAL: stair_surfaces=",surfaces," concrete_surfaces=",concrete_surfaces," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
