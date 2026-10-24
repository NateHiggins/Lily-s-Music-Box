extends Node3D
## Loaded native stock/UV/material checks, plus carried-voxel-light comparisons.
## This scoped bench grants no played-room, save or whole-world acceptance.
class EmptyAdapter extends OrisonV2AnchorAdapter:
	func resolve(_identity: String) -> Node: return null

const KEYS := ["book_brown","book_burgundy","book_green","book_navy","book_ochre","book_teal"]
var failures: Array[String] = []
var checks := 0
var player: PlayerController

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("BINDING CHECK: "+label)
	return ok

func _ready() -> void: _run.call_deferred()

func _material(material: Material, key: String) -> void:
	if key not in KEYS: return
	var stock := material as StandardMaterial3D
	if not check(stock != null,"binding uses lit standard material: "+key): return
	check(stock.normal_enabled and is_equal_approx(stock.normal_scale,1.),"metric construction strength: "+key)
	check(not stock.uv1_triplanar and stock.uv1_scale.is_equal_approx(Vector3.ONE/.32),"authored metre UV: "+key)
	for texture: Texture2D in [stock.albedo_texture,stock.roughness_texture,stock.normal_texture]:
		if not check(texture != null,"custom PBR map: "+key): continue
		var image := texture.get_image()
		var required := int(round(log(float(max(texture.get_width(),texture.get_height())))/log(2.)))
		check(image != null and image.has_mipmaps() and image.get_mipmap_count()==required,"complete loaded mip chain: "+key)

func _capture(label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	for frame in 12: await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))

func _run() -> void:
	preload("res://tests/v2_control_finish_review.gd").new().validate_material_contract(self)
	if not failures.is_empty(): get_tree().quit(1);return
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	for family: String in ["domestic_objects","domestic_storage","reading_nook","surface_stock"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/"+family+".json"))
		var packed := load(str(data.asset)) as PackedScene
		if not check(packed != null,"native family imports: "+family): continue
		var source := packed.instantiate()
		for row: Dictionary in data.assemblies:
			for part: Dictionary in row.parts:
				var draw := source.find_child(str(part.name),true,false) as MeshInstance3D
				if check(draw != null,"native partition resolves: "+str(part.name)):
					metrics._check_cap_mapping(draw.mesh,true)
		source.free()
	for failure: String in metrics.failures: check(false,failure)
	metrics.free()
	var storage := preload("res://scripts/building/orison_v2_native_domestic_storage.gd").new()
	var objects := preload("res://scripts/building/orison_v2_native_domestic_objects.gd").new()
	for factory: RefCounted in [storage,objects]:
		if check(factory.prepare(),"production native material factory prepares"):
			for parts: Array in factory._variants.values():
				for part: Dictionary in parts: _material(part.mesh.surface_get_material(0),str(part.key))
	var hero := StaticBody3D.new()
	add_child(hero)
	check(storage.mount_on(hero,"4B_shelf"),"original bookshelf partition programme mounts")
	var surface := preload("res://scripts/building/orison_v2_surface_stock.gd").new()
	var other_stock := Node3D.new()
	add_child(other_stock)
	if check(surface.prepare(),"production passive stock factory prepares"):
		for identity: String in surface.rows:
			var owner_body := Node3D.new()
			other_stock.add_child(owner_body)
			check(surface.mount_on(owner_body,identity),"passive partition programme mounts: "+identity)
			for draw: MeshInstance3D in owner_body.find_children("*","MeshInstance3D",false,false):
				_material(draw.mesh.surface_get_material(0),str(draw.get_meta("material_key","")))
	var nook_root := Node3D.new()
	add_child(nook_root)
	var adapter := EmptyAdapter.new(nook_root)
	check(preload("res://scripts/building/orison_v2_reading_nook.gd").mount(adapter),"production reading nook mounts")
	for draw: MeshInstance3D in adapter.root.find_children("*","MeshInstance3D",true,false):
		_material(draw.mesh.surface_get_material(0),str(draw.get_meta("material_key","")))
	other_stock.hide()
	nook_root.hide()
	if not failures.is_empty():
		storage.finish();objects.finish();surface.finish()
		get_tree().quit(1);return
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size=Vector3(8.,.2,8.)
	floor_shape.shape=floor_box
	floor_body.position.y=-.1
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-35,-25,0)
	sun.light_energy=.16
	add_child(sun)
	var environment := Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color(.022,.025,.031)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color(.34,.39,.46)
	environment.ambient_light_energy=.22
	var world_environment := WorldEnvironment.new()
	world_environment.environment=environment
	add_child(world_environment)
	player=PlayerController.new()
	player.position=Vector3(.55,.02,-1.35)
	add_child(player)
	player.set_lamp_enabled(true)
	player.camera.make_current()
	var air := preload("res://scripts/building/orison_v2_lamp_atmosphere.gd").new()
	add_child(air)
	check(air.setup(player,environment),"production carried voxel light initializes")
	for frame in 30: await get_tree().physics_frame
	check(air.field != null and air.field.ready and air.field.failed.is_empty(),"live voxel field ready")
	check(player.flashlight.light_projector==null and player._light_mask == null,"legacy light plate disabled")
	player.camera.look_at(Vector3(0,1.15,0))
	await _capture("native_bindings_normals_on")
	var materials: Array[StandardMaterial3D] = []
	for draw: MeshInstance3D in hero.find_children("*","MeshInstance3D",false,false):
		var stock := draw.mesh.surface_get_material(0) as StandardMaterial3D
		if str(draw.get_meta("material_key","")) in KEYS:
			materials.append(stock)
			stock.normal_enabled=false
	await _capture("native_bindings_normals_off")
	for material: StandardMaterial3D in materials: material.normal_enabled=true
	player.position=Vector3(.3,.02,-.70)
	player.camera.look_at(Vector3(0,1.3,0))
	for frame in 12: await get_tree().physics_frame
	await _capture("native_bindings_close_normals_on")
	for material: StandardMaterial3D in materials: material.normal_enabled=false
	await _capture("native_bindings_close_normals_off")
	for material: StandardMaterial3D in materials: material.normal_enabled=true
	storage.finish();objects.finish();surface.finish()
	print("V2 BINDING STOCK BENCH: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
