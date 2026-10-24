extends "res://tests/orison_v2_vertical_route_test.gd"
## Same-frame native depth injection, independent of gameplay acceptance.
const Field := preload("res://scripts/lamp/lamp_optical_voxel_field.gd")
const Shadow := preload("res://scripts/lamp/lamp_scene_shadow.gd")
const Observation := preload("res://scripts/lamp/carried_lamp_observation.gd")
var comparisons: Array=[]

func _init() -> void:route_label="V2 LAMP DEPTH EQUIVALENCE"

func _route() -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	player.set_physics_process(false);player.velocity=Vector3.ZERO
	var first_shop: DoorProp=world.passage_region.doors.values()[0]
	player.global_position=first_shop.to_global(Vector3(.45,.04,1.15))
	for frame in 900:
		if world.passage_region.residency.state=="RESIDENT":break
		await get_tree().process_frame
	if world.passage_region.residency.state!="RESIDENT":failures.append("native shop geometry did not become resident")
	world.process_mode=Node.PROCESS_MODE_DISABLED
	var lamp:=player.flashlight
	var original_pose:=lamp.global_transform
	var fields: Array=[Field.new(),Field.new()]
	var views: Array=[]
	for field: RefCounted in fields:field.initialize(1)
	for frame in 300:
		if fields[0].ready and fields[1].ready:break
		await get_tree().process_frame
	if not fields[0].ready or not fields[1].ready:
		failures.append("paired GPU fields did not initialize")
	else:
		for field: RefCounted in fields:
			var view:=Shadow.new();add_child(view);view.setup(field,lamp);views.append(view)
		var observation:=Observation.new();add_child(observation)
		var roof:=world.adapter.resolve("ROOF_PUBLIC_DOOR") as Node3D
		var shop: DoorProp=world.passage_region.doors.values()[0]
		var stations: Array=[
			["lobby",world.adapter.root.to_global(Vector3(1.925,1.43,-3.5)),world.adapter.root.to_global(Vector3(1.925,1.43,-7.5))],
			["mina_library",world.adapter.root.to_global(Vector3(-8.5,4.61,0)),world.adapter.root.to_global(Vector3(-13.4,4.3,.75))],
			["shop_leaf",shop.to_global(Vector3(.45,1.43,1.1)),shop.to_global(Vector3(.45,1.1,0))]]
		if roof!=null:stations.append(["actual_roof_door",roof.to_global(Vector3(.3,1.43,1.1)),roof.to_global(Vector3(.3,1.1,0))])
		else:failures.append("roof semantic station missing")
		for options: Array in [["atlas_zero",false],["atlas_zero_occlusion",true]]:
			views[1].viewport.positional_shadow_atlas_size=0
			views[1].viewport.use_occlusion_culling=options[1]
			for station: Array in stations:
				lamp.global_position=station[1];lamp.look_at(station[2])
				for frame in 8:
					observation.observe_light(lamp,true,1.0/60.0)
					# Positive diagnostic radiance prevents an unpowered logical lamp
					# from making two empty fields look like a valid depth comparison.
					observation.state.intensity=maxf(lamp.light_energy,1.0)
					observation.state.intensity_rate=0
					for field: RefCounted in fields:field.observe(observation,true)
					await RenderingServer.frame_post_draw
				var record: Dictionary={"option":options[0],"station":station[0],"channels":[]}
				for cascade in ["mid","near"]:
					for optical in [false,true]:
						var sources: Array=fields if cascade=="mid" else [fields[0].near_cascade,fields[1].near_cascade]
						var a: PackedByteArray=await _read(sources[0],optical)
						var b: PackedByteArray=await _read(sources[1],optical)
						var same: bool=not a.is_empty() and a==b
						if not optical and a.count(0)==a.size():same=false
						record.channels.append({"cascade":cascade,"optics":optical,"bytes":a.size(),"equal":same,"reference_sha256":_hash(a),"candidate_sha256":_hash(b)})
						if not same:failures.append(str(options[0])+" "+str(station[0])+" "+cascade+" optics="+str(optical)+" differs")
				for i in 2:views[i].viewport.get_texture().get_image().save_png(directory.path_join(str(options[0])+"_"+str(station[0])+"_"+str(i)+".png"))
				comparisons.append(record)
				if views[0].effect.passes==0 or views[1].effect.passes==0:failures.append("scene depth compositor did not execute")
				print("DEPTH FIELD COMPARISON ",options[0]," ",station[0]," channels=",record.channels)
		observation.free()
	lamp.global_transform=original_pose
	for view: Node in views:view.free()
	for field: RefCounted in fields:field.dispose()
	for frame in 3:await get_tree().process_frame
	world.process_mode=Node.PROCESS_MODE_INHERIT
	FileAccess.open(directory.path_join("depth_equivalence.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Paired same-frame mid/near radiance and optics bytes after original scene-depth injection. Four fixed native world views; no route or full-world visual acceptance.","comparisons":comparisons,"failures":failures},"\t"))

func _read(field: RefCounted,optical: bool) -> PackedByteArray:
	var result: Dictionary={}
	field.debug_readback(func(data: PackedByteArray):result.data=data,optical)
	for frame in 300:
		if result.has("data"):return result.data
		await get_tree().process_frame
	return PackedByteArray()

func _hash(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes)
	return context.finish().hex_encode()
