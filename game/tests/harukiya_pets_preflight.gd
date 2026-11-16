extends Node3D
## Nearby actual bar assembly. Does not replace composed-world qualification.
var failures: Array[String] = []
var checks := 0
func _ready() -> void:
	RealityState.persistence_enabled=false
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func _run() -> void:
	_dump_imported_materials()
	var before := RealityState.data.duplicate(true)
	var bar := OrisonV2BarRegion.new()
	add_child(bar)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not bar.startup_failed,"actual retained bar assembly initializes")
	var result: Dictionary={}
	if not bar.startup_failed:
		result=preload("res://tests/harukiya_pets_review.gd").new().validate_in_region(bar)
		checks+=int(result.checks)
		for failure: String in result.failures: check(false,failure)
		for identity: String in ["judge","lafitte"]:
			var model := bar.get_node("RetainedBarGeometry/HarukiyaPets/"+identity)
			for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
				for surface in draw.mesh.get_surface_count():
					var material := draw.get_active_material(surface) as StandardMaterial3D
					check(material!=null,"imported animal uses ordinary PBR")
					if material==null:continue
					for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
						check(texture!=null,"loaded custom map exists")
						if texture==null:continue
						var image := texture.get_image()
						check(image!=null and image.get_mipmap_count()==int(floor(log(maxi(image.get_width(),image.get_height()))/log(2.0))),"complete loaded mip chain: "+texture.resource_path)
	var initialization_changed: Array[String]=[]
	for key: String in RealityState.data:
		if not before.has(key) or before[key]!=RealityState.data[key]: initialization_changed.append(key)
	if not bar.startup_failed: _validate_pet_roundtrip(bar.source_layout)
	bar.free()
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		FileAccess.open(directory.path_join("pet_preflight.json"),FileAccess.WRITE).store_string(JSON.stringify({"scope":"Actual production bar component fixture, finite collision probes and loaded animal maps/mips; no full-world, route, save-reload, play or artistic acceptance","checks":checks,"failures":failures,"physical":result,"bar_initialization_changed_keys":initialization_changed},"\t"))
	_finish.call_deferred()
func _finish() -> void:
	for frame in 8: await get_tree().process_frame
	print("HARUKIYA PET PREFLIGHT: ",checks," checks; ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)

func _dump_imported_materials() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/harukiya_pets.json"))
	var observed := {}
	for row: Dictionary in data.animals:
		var model := (load(str(row.asset)) as PackedScene).instantiate() as Node3D
		var draws := []
		for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			var surfaces := []
			for index in draw.mesh.get_surface_count():
				var material := draw.mesh.surface_get_material(index) as BaseMaterial3D
				var fields := {"class":material.get_class(),"name":material.resource_name,"triangles":draw.mesh.surface_get_array_index_len(index)/3}
				for property: String in ["albedo_color","metallic","roughness","normal_scale","normal_enabled","uv1_triplanar","uv2_triplanar","uv1_scale","uv1_offset","roughness_texture_channel","transparency","cull_mode"]:
					fields[property]=str(material.get(property))
				for property: String in ["albedo_texture","roughness_texture","normal_texture"]:
					var texture := material.get(property) as Texture2D
					fields[property]=texture.resource_path if texture!=null else "MISSING"
				surfaces.append(fields)
			draws.append({"name":str(draw.name),"transform":str(draw.transform),"surfaces":surfaces})
		observed[str(row.id)]={"root_transform":str(model.transform),"draws":draws}
		model.free()
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		FileAccess.open(directory.path_join("imported_materials.json"),FileAccess.WRITE).store_string(JSON.stringify(observed,"\t"))

func _validate_pet_roundtrip(layout: Dictionary) -> void:
	var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/harukiya_pets.json"))
	var source := (load("res://assets/building/floor_01_cells/shop_bar.gltf") as PackedScene).instantiate() as Node3D
	var draw := source.get_node(str(spec.retirement.name)) as MeshInstance3D
	var shape := draw.find_children("*","CollisionShape3D",true,false)[0] as CollisionShape3D
	var original_mesh := draw.mesh
	var original_shape := shape.shape
	var before := RealityState.data.duplicate(true)
	var mount := preload("res://scripts/building/orison_v2_bar_pets.gd").new()
	check(mount.mount_cell(source,layout),"pet-only mount uses actual imported source and exact retirement")
	check(RealityState.data==before,"pet-only mount preserves campaign content")
	mount.restore()
	check(draw.mesh==original_mesh and shape.shape==original_shape,"pet restore returns exact source renderer/collision resources")
	check(not source.has_node("HarukiyaPets"),"pet restore removes presentation and native collision")
	check(RealityState.data==before,"pet-only restore preserves campaign content")
	source.free()
