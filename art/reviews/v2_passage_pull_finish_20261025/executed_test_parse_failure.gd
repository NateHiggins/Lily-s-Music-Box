extends "res://tests/v2_easy_door_bench.gd"
## INERT native finish/input diagnostic. No occupied-world or save qualification.
var motion_trace: Array=[]
func drag(x: float) -> void:
	var row: Dictionary={"x":x,"active_before":player._grab.active()}
	if player._grab.active():row["before"]=player._grab.target.read.call()
	super.drag(x)
	row["active_after"]=player._grab.active()
	if player._grab.active():row["after"]=player._grab.target.read.call()
	motion_trace.append(row)

func _exit_tree() -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		FileAccess.open(directory.path_join("motion_trace.json"),FileAccess.WRITE).store_string(JSON.stringify(motion_trace,"\t"))

func check(ok: bool,label: String) -> void:
	super.check(ok,label)
	if label=="240-pixel horizontal gesture reaches full stop":
		print("PULL TRAVEL OBSERVATION: active=",player._grab.active()," target=",player._grab.target.read.call() if player._grab.active() else null," camera=",player.camera.global_position)

func _ready() -> void:
	# Controlled diffuse fill makes both sides readable; this is a fixture light,
	# not evidence of the installed passage's lighting or performance.
	var fill:=WorldEnvironment.new()
	fill.environment=Environment.new()
	fill.environment.background_mode=Environment.BG_COLOR
	fill.environment.background_color=Color(.12,.14,.17)
	fill.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	fill.environment.ambient_light_color=Color(.78,.83,.9)
	fill.environment.ambient_light_energy=.7
	# Metallic brass needs reflected light as well as diffuse fill. A colour
	# background alone gives a black metal response, unlike the installed sky.
	fill.environment.sky=Sky.new()
	fill.environment.sky.sky_material=ProceduralSkyMaterial.new()
	fill.environment.reflected_light_source=Environment.REFLECTED_SOURCE_SKY
	add_child(fill)
	preload("res://tests/v2_control_finish_review.gd").new().validate_material_contract(self)
	super._ready()

func make_door() -> DoorProp:
	var door:=preload("res://scripts/building/orison_v2_passage_shop_door.gd").new()
	door.width=.95
	door.height=2.10
	door.door_kind="storefront"
	return door

func inspect_door(door: DoorProp,swing: bool) -> void:
	var inventory:=preload("res://tests/orison_v2_surface_inventory.gd").new()
	var native:=preload("res://assets/props/passage_shop_leaves.glb").instantiate()
	var originals:=native.find_children("*","MeshInstance3D",true,false)
	check(originals.size()==9,"native export uses seven joinery/glass meshes and two combined brass pulls")
	for draw: MeshInstance3D in originals:
		for surface: Dictionary in inventory._mesh(draw.mesh).surfaces:
			check(not surface.missing_uv and surface.nonfinite_uv==0 and surface.degenerate_uv_triangles==0,str(draw.name)+" loaded metric UVs are finite and nondegenerate")
	native.free()
	var expected:=MatLib.get_mat("door_oak")
	check(expected.uv1_triplanar,"catalogue UV defaults remain unchanged")
	check(expected.albedo_texture.get_width()==1024,"door oak resolves a 1024-pixel source")
	var wood_seen:=false
	for draw: MeshInstance3D in door._body.find_children("*","MeshInstance3D",true,false):
		for index in draw.mesh.get_surface_count():
			var finish:=draw.get_active_material(index)
			var row: Dictionary=inventory._material(finish)
			check(not row.get("triplanar",false) and int(row.get("uv_mode",0))==0,"fitted door samples native UVs")
			if finish is StandardMaterial3D and finish.albedo_texture==expected.albedo_texture:
				wood_seen=true
				check(finish.albedo_color==Color.WHITE and finish.uv1_scale==expected.uv1_scale,"oak retains source colour and catalogue physical scale")
	check(wood_seen,"sharp oak is installed on retained joinery")
	for row: Dictionary in inventory.texture_rows.values():
		var expected_levels:=int(floor(log(float(maxi(row.width,row.height)))/log(2.0)))
		check(row.mips and row.mip_levels==expected_levels,"surface map has a loaded full mip chain")
	inventory.free()
	var directory:=OS.get_environment("SHOT_DIR")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory)
	var prior:=player.camera.global_transform
	var mode:=Input.mouse_mode
	# Real rendered source, two useful distances on both sides of the production leaf.
	for close in [false,true]:
		var side:=1.0 if swing else -1.0
		player.camera.global_position=door.to_global(Vector3(1.08 if close else .48,1.12 if close else 1.1,side*(.65 if close else 1.65)))
		player.camera.look_at(door.to_global(Vector3(.885 if close else .475,1.03,0)))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join(("out" if swing else "in")+("_pull.png" if close else "_leaf.png")))
	player.camera.global_transform=prior
	Input.mouse_mode=mode
