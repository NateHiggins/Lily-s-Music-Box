extends "res://tests/orison_v2_vertical_route_test.gd"
## Same-frame native depth injection, independent of gameplay acceptance.
const Field := preload("res://scripts/lamp/lamp_optical_voxel_field.gd")
const Shadow := preload("res://scripts/lamp/lamp_scene_shadow.gd")
const Observation := preload("res://scripts/lamp/carried_lamp_observation.gd")
var comparisons: Array=[]
var view_timings: Array=[]
var layer_guards: Array=[]

func _init() -> void:route_label="V2 DEPTH LIGHT CULLING PROBE"

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
	var atmosphere: Node=world.get_node("LampAtmosphere")
	var production_binding: RefCounted=atmosphere.receivers
	var production_view: SubViewport=atmosphere.scene_shadow.viewport
	_guard(production_binding.isolate_depth_lights and production_binding.depth_geometry_clear,"actual world has no geometry on the reserved light layers")
	_guard(atmosphere.scene_shadow.excluded_light_layers==((1<<16)|(1<<18)),"production depth camera uses the qualified light exclusion")
	_guard(player.camera.cull_mask & (1<<16)!=0,"actual presentation camera retains ordinary fixture lighting")
	var old_update:=production_view.render_target_update_mode
	production_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	var light_layers: Dictionary={}
	for light: Light3D in world.find_children("*","Light3D",true,false):
		if light.layers==1:
			light_layers[light]=light.layers;light.layers=1<<16
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
			var view:=Shadow.new();add_child(view);view.setup(field,lamp,true);view.set_process(false);views.append(view)
		views[0].viewport.positional_shadow_atlas_size=0
		views[0].viewport.use_occlusion_culling=true
		var observation:=Observation.new();add_child(observation)
		var roof:=world.adapter.resolve("ROOF_PUBLIC_DOOR") as Node3D
		var shop: DoorProp=world.passage_region.doors.values()[0]
		var stations: Array=[
			["lobby",world.adapter.root.to_global(Vector3(1.925,1.43,-3.5)),world.adapter.root.to_global(Vector3(1.925,1.43,-7.5))],
			["mina_library",world.adapter.root.to_global(Vector3(-8.5,4.61,0)),world.adapter.root.to_global(Vector3(-13.4,4.3,.75))],
			["shop_leaf",shop.to_global(Vector3(.45,1.43,1.1)),shop.to_global(Vector3(.45,1.1,0))]]
		if roof!=null:stations.append(["actual_roof_door",roof.to_global(Vector3(.3,1.43,1.1)),roof.to_global(Vector3(.3,1.1,0))])
		else:failures.append("roof semantic station missing")
		for options: Array in [["exclude_light_work",true]]:
			views[1].viewport.positional_shadow_atlas_size=0
			views[1].viewport.use_occlusion_culling=options[1]
			for station: Array in stations:
				lamp.global_position=station[1];lamp.look_at(station[2])
				for index in 2:
					var camera: Camera3D=views[index].camera
					camera.global_transform=lamp.global_transform;camera.far=lamp.spot_range;camera.fov=lamp.spot_angle*2.
					camera.cull_mask=lamp.shadow_caster_mask if index==0 else lamp.shadow_caster_mask & ~((1<<16)|(1<<18))
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
				await _profile_views(views,str(station[0]))
				if views[0].effect.passes==0 or views[1].effect.passes==0:failures.append("scene depth compositor did not execute")
				print("DEPTH FIELD COMPARISON ",options[0]," ",station[0]," channels=",record.channels)
		observation.free()
	# Exercise both conservative fallbacks in this same actual production owner.
	var conflict:=MeshInstance3D.new();conflict.mesh=BoxMesh.new();conflict.layers=1<<16;conflict.visible=false;world.add_child(conflict)
	for frame in 3:await get_tree().process_frame
	atmosphere._update_volume(0)
	_guard(not production_binding.depth_geometry_clear and atmosphere.scene_shadow.excluded_light_layers==0,"late reserved-layer geometry restores full scene depth")
	conflict.free()
	var expected_layers: Dictionary={}
	for row: Array in production_binding.lights.values():
		var light: Light3D=row[0].get_ref()
		if is_instance_valid(light) and row[2]!=null:expected_layers[light]=int(row[2])
	var old_mask:=player.camera.cull_mask;player.camera.cull_mask=1
	atmosphere._update_volume(0)
	var restored:=not production_binding.isolate_depth_lights and atmosphere.scene_shadow.excluded_light_layers==0
	for light: Light3D in expected_layers:restored=restored and light.layers==expected_layers[light]
	_guard(not expected_layers.is_empty() and restored,"independent layer-one camera restores all ordinary world lights without camera edits")
	_guard(player.camera.cull_mask==1,"fallback preserves the independently authored camera mask")
	player.camera.cull_mask=old_mask
	lamp.global_transform=original_pose
	for light: Light3D in light_layers:light.layers=light_layers[light]
	production_view.render_target_update_mode=old_update
	for view: Node in views:view.free()
	for field: RefCounted in fields:field.dispose()
	for frame in 3:await get_tree().process_frame
	world.process_mode=Node.PROCESS_MODE_INHERIT
	FileAccess.open(directory.path_join("depth_equivalence.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Paired same-frame mid/near radiance and optics bytes after original scene-depth injection. Four fixed native world views; no route or full-world visual acceptance.","comparisons":comparisons,"view_timings":view_timings,"layer_guards":layer_guards,"failures":failures},"\t"))

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

func _profile_views(views: Array,station: String) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	for view: Node in views:RenderingServer.viewport_set_measure_render_time(view.viewport.get_viewport_rid(),true)
	for treatment: String in ["reference","candidate","reference_restored"]:
		for index in 2:views[index].viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if index==(1 if treatment=="candidate" else 0) else SubViewport.UPDATE_DISABLED
		for frame in 30:await RenderingServer.frame_post_draw
		var samples: Array=[];var before:=Time.get_ticks_usec()
		for frame in 90:
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec();var active: Node=views[1 if treatment=="candidate" else 0]
			samples.append([(now-before)/1000.,RenderingServer.viewport_get_measured_render_time_cpu(active.viewport.get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(active.viewport.get_viewport_rid())]);before=now
		view_timings.append({"station":station,"treatment":treatment,"columns":["wall_ms","view_cpu_ms","view_gpu_ms"],"samples":samples})
	for view: Node in views:view.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS

func _guard(ok: bool,label: String) -> void:
	layer_guards.append({"ok":ok,"label":label});print("DEPTH WORLD GUARD: ",label," = ",ok)
	if not ok:failures.append(label)
