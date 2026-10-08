extends Node
## Production finish review. --diagnostic enables temporary comparison states.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const PARAMETERS := ["albedo_mean", "pigment_variation", "detail_albedo_strength",
		"detail_normal_strength", "normal_scale", "mask_amount"]
const VIEWS := [
	{"id":"dim_2A", "feet":Vector3(-8.846,3.23,1.988), "target":Vector3(-11.6,4.1,-.375)},
	{"id":"bright_3B", "feet":Vector3(14.2805,6.43,-4.362), "target":Vector3(13.575,7.3,-2.475)},
	{"id":"vestibule", "feet":Vector3(1.632,.03,-10.042), "target":Vector3(0,.9,-10.45)},
	{"id":"lobby", "feet":Vector3(3.672,.03,-4.714), "target":Vector3(0,.9,-6.55)},
	{"id":"laundry", "feet":Vector3(-3.448,-3.17,2.618), "target":Vector3(-6.1,-2.3,0)},
	{"id":"roof", "feet":Vector3(-11.5,19.23,1.8), "target":Vector3(-11.5,20,4)}]
var failures: Array[String] = []
var materials: Array[Dictionary] = []
var frames: Array[Dictionary] = []
var directory: String
var world: OrisonV2RuntimeRoot

func _ready() -> void: _run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)

func _run() -> void:
	_check_linear_statistics()
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless":
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	world = Runtime.instantiate()
	add_child(world)
	await get_tree().physics_frame
	_check(not world.startup_failed,"production world starts")
	if world.startup_failed: get_tree().quit(1); return
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false): layer.hide()
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"): driver.set_frozen_for_tests(true)
	world.shop_simulation.set_process(false)
	world.player.global_position = world.adapter.root.to_global(Vector3(0,.03,-10.45))
	for frame in 600:
		if world.passage_region.residency.state=="RESIDENT": break
		await get_tree().process_frame
	_check(world.passage_region.residency.state=="RESIDENT","normal passage prefetch completes")
	_collect_materials()
	if OS.get_environment("FINISH_SOURCE_CENSUS") == "1": _export_source_census()
	var fixtures: Array[LightFixtureProp] = []
	for node in world.find_children("*","Node",true,false):
		if node is LightFixtureProp: fixtures.append(node)
	var reference := preload("res://scripts/lamp/lamp_optical_state.gd").new()
	reference.configure(0x28A11CE,true)
	reference.advance(2.0)
	var snapshot: Dictionary = reference.save_state()
	var air := world.get_node("LampAtmosphere")
	var states := ["production"]
	if "--diagnostic" in OS.get_cmdline_user_args():
		states = ["baseline", "linear_mean", "quiet_surfaces", "light_comparison"]
	for view: Dictionary in VIEWS:
		world.player.set_process(true)
		world.service_set_carrier.set_process(true)
		world.player.global_position = world.adapter.root.to_global(view.feet)
		world.player.face_world_point(world.adapter.root.to_global(view.target))
		world.player.set_lamp_enabled(true)
		await get_tree().create_timer(1.0).timeout
		world.player.set_process(false)
		world.service_set_carrier.set_process(false)
		air.driver.state.restore_state(snapshot)
		air.driver.apply_output()
		var light_state: Array[Dictionary] = []
		for fixture in fixtures:
			fixture.set_process(false)
			light_state.append({"fixture":fixture,"direct":fixture.light.light_color,
					"bounce":fixture.bounce.light_color,"energy":fixture.light.light_energy,
					"emission":fixture._bulb_mat.emission})
		for state: String in states:
			_restore_materials()
			if state in ["linear_mean", "quiet_surfaces", "light_comparison"]: _apply_linear_means()
			if state in ["quiet_surfaces","light_comparison"]: _apply_quiet_surfaces()
			if state == "light_comparison":
				for row in light_state:
					var fixture: LightFixtureProp = row.fixture
					# Diagnostic only: same energy and light nodes. This is not a
					# change to authored Kelvin/maintenance controls.
					fixture.light.light_color = (row.direct as Color).lerp(Color.WHITE,.32)
					fixture.bounce.light_color = (row.bounce as Color).lerp(Color.WHITE,.22)
			await get_tree().create_timer(.35).timeout
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var label: String = str(view.id)+"_"+state
			image.save_png(directory.path_join(label+".png"))
			var record := {"view":view.id,"state":state,"image":label+".png",
					"lamp_energy":world.player.flashlight.light_energy,
					"lamp_color":str(world.player.flashlight.light_color),
					"exposure":world.get_node("WakingAtmosphere").environment.tonemap_exposure,
					"render_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
					"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					"primitive_count":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
			frames.append(record)
			for row in light_state: _check(is_equal_approx(row.fixture.light.light_energy,row.energy),"fixed direct energy: "+label)
		for row in light_state:
			row.fixture.light.light_color = row.direct
			row.fixture.bounce.light_color = row.bounce
			row.fixture.set_process(true)
	_restore_materials()
	var metadata: Array[Dictionary] = []
	for row in materials:
		metadata.append({"texture":row.path,"mean_bound":str(row.before.albedo_mean),
				"mean_linear":str(row.linear_mean),"mipmaps":row.mipmaps})
	FileAccess.open(directory.path_join("calibration.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","scope":"Matched in-world diagnostic; no runtime-contract proof",
		"renderer":RenderingServer.get_current_rendering_method(),"frames":frames,"materials":metadata,"failures":failures},"\t"))
	materials.clear()
	world.shutdown_for_tests()
	world.free()
	await get_tree().process_frame
	print("FINISH CALIBRATION: frames=",frames.size()," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _collect_materials() -> void:
	var seen: Dictionary = {}
	var means: Dictionary = {}
	for draw: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		if draw.mesh==null: continue
		for i in draw.mesh.get_surface_count():
			var material := draw.get_active_material(i) as ShaderMaterial
			if material==null or seen.has(material.get_instance_id()): continue
			seen[material.get_instance_id()] = true
			if material.shader!=SurfacePass.OPAQUE and material.shader!=SurfacePass.CUTOUT: continue
			var texture := material.get_shader_parameter("albedo_tex") as Texture2D
			if texture==null: continue
			var path := texture.resource_path
			if not means.has(path):
				var image := texture.get_image()
				if image.is_compressed(): image.decompress()
				var mips := image.has_mipmaps()
				image.resize(64,64,Image.INTERPOLATE_BILINEAR)
				var sum := Vector3.ZERO
				for y in 64:
					for x in 64:
						var c := image.get_pixel(x,y).srgb_to_linear()
						sum += Vector3(c.r,c.g,c.b)
				means[path] = {"value":sum/4096.0,"mips":mips}
			var before: Dictionary = {}
			for parameter in PARAMETERS: before[parameter] = material.get_shader_parameter(parameter)
			materials.append({"material":material,"path":path,"before":before,
					"linear_mean":means[path].value,"mipmaps":means[path].mips})
	_check(not materials.is_empty(),"layered materials present")

func _restore_materials() -> void:
	for row in materials:
		for parameter in PARAMETERS: row.material.set_shader_parameter(parameter,row.before[parameter])

func _apply_linear_means() -> void:
	for row in materials: row.material.set_shader_parameter("albedo_mean",row.linear_mean)

func _apply_quiet_surfaces() -> void:
	for row in materials:
		var material: ShaderMaterial = row.material
		var path: String = row.path
		if "_floor_oak_" in path or "_plaster_stained_" in path or "_terrazzo_" in path:
			material.set_shader_parameter("pigment_variation",.45 if "_floor_oak_" in path else .6)
			material.set_shader_parameter("detail_albedo_strength",.025)
			material.set_shader_parameter("detail_normal_strength",.18)
			material.set_shader_parameter("normal_scale",.20)
			material.set_shader_parameter("mask_amount",Vector4(0,.08,0,.06))

func _check_linear_statistics() -> void:
	var sample := Image.create(32,32,false,Image.FORMAT_RGBAF)
	sample.fill(Color(.5,.5,.5,1.))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(sample)
	var stats := SurfacePass.texture_stats(material)
	var expected := Color(.5,.5,.5).srgb_to_linear().r
	_check(absf(stats.albedo_mean.x-expected)<.00001,"texture means share source_color linear space")

func _export_source_census() -> void:
	# Review/export only: source owners and their child ordering are untouched.
	var plan_path := "res://../art/reviews/v2_remaining_20261008/sources/dossier-capture-plan.json"
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(plan_path))
	var actors: Array[Dictionary] = []
	for selector: Dictionary in plan.models:
		var actor: Node3D
		for node in world.find_children("*","Node3D",true,false):
			if selector.has("name") and str(node.name)==str(selector.name): actor=node; break
			if selector.has("script") and node.get_script()!=null and node.get_script().resource_path==selector.script: actor=node; break
		_check(actor!=null,"source census actor: "+str(selector))
		if actor==null: continue
		var row := {"id":selector.id,"actor":str(actor.name),"script":actor.get_script().resource_path if actor.get_script()!=null else "", "meshes":[]}
		for draw: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
			if draw.mesh==null: continue
			var mesh := draw.mesh
			var pose := actor.global_transform.affine_inverse()*draw.global_transform
			var part := {"index":row.meshes.size(),"path":str(actor.get_path_to(draw)),"name":str(draw.name),"type":mesh.get_class(),"position":_vec(pose.origin),"basis":[_vec(pose.basis.x),_vec(pose.basis.y),_vec(pose.basis.z)],"visible":draw.visible,"materials":[]}
			if mesh is BoxMesh: part["size"]=_vec(mesh.size)
			elif mesh is CylinderMesh: part.merge({"top_radius":mesh.top_radius,"bottom_radius":mesh.bottom_radius,"height":mesh.height,"radial_segments":mesh.radial_segments})
			elif mesh is SphereMesh: part.merge({"radius":mesh.radius,"height":mesh.height})
			elif mesh is TorusMesh: part.merge({"inner_radius":mesh.inner_radius,"outer_radius":mesh.outer_radius})
			for surface in mesh.get_surface_count():
				var material := draw.get_active_material(surface)
				var mat := {"class":material.get_class() if material!=null else "null","name":material.resource_name if material!=null else ""}
				if material is BaseMaterial3D:
					mat.merge({"color":[material.albedo_color.r,material.albedo_color.g,material.albedo_color.b,material.albedo_color.a],"metallic":material.metallic,"roughness":material.roughness,"albedo":material.albedo_texture.resource_path if material.albedo_texture!=null else ""})
				part.materials.append(mat)
			row.meshes.append(part)
		actors.append(row)
	FileAccess.open(directory.path_join("source-census.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","actors":actors},"\t"))

func _vec(v: Vector3) -> Array:
	return [v.x,v.y,v.z]
