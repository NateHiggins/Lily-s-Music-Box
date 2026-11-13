extends Node3D
## Isolated loaded-body capacity and matched renderer diagnostic. No attendance,
## live-world route, performance target, save, or artistic acceptance claim.
const Resident := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
const CastModel := preload("res://scripts/characters/cast_model_presentation.gd")
const Cast := preload("res://scripts/characters/harukiya_cast.gd")
const Glass := preload("res://scripts/props/harukiya_counter_glass.gd")
const AdelaPreview := preload("res://scripts/characters/adela_preview_follower.gd")
const WARM_FRAMES := 60
const SAMPLE_FRAMES := 180
const VIEWS := [
	{"id":"entrance_audience", "at":[3.2,-34.4,-1.18], "look":[-2.9,-33.0,-.55]},
	{"id":"balcony_stage", "at":[-4.95,-31.55,1.5], "look":[-.7,-35.2,-1.0]},
	{"id":"counter_audience", "at":[.75,-31.6,-1.25], "look":[-3.2,-32.6,-1.2]},
	{"id":"stage_audience", "at":[.65,-35.8,-.9], "look":[-1.2,-32.8,-.7]}]

var bar: OrisonV2BarRegion
var crowd: Node3D
var seats: Node3D
var camera: Camera3D
var residents: Array[AnimatedResident] = []
var cast: Array[Node3D] = []
var adela: CharacterBody3D
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var poses: Array[Dictionary] = []
var timings: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var initial_inputs: Dictionary = {}
var directory := ""
var preview_owned := false
var prior_data: Dictionary
var prior_mode: int
var prior_fps: int
var prior_vsync: int
var started := Time.get_ticks_msec()

func _ready() -> void: _run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks.append({"ok":ok,"label":label})
	if not ok: failures.append(label); push_error("HARUKIYA CROWD: " + label)
	return ok

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if not _check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory) == OK,"explicit writable crowd SHOT_DIR"):
		get_tree().quit(2); return
	prior_data = RealityState.data; prior_mode = GameBoot.launch_mode
	prior_fps = Engine.max_fps; prior_vsync = DisplayServer.window_get_vsync_mode()
	initial_inputs = _inputs()
	preview_owned = RealityState.begin_preview_campaign(self)
	if not _check(preview_owned,"exclusive nonpersistent campaign preview"):
		await _finish(); return
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	_check(CampaignClock.new().configure_date(1929,6,14,21*60),"Friday evening practical-light state in private context")
	if not _check(DisplayServer.get_name() != "headless","actual renderer required"):
		await _finish(); return
	var environment := WorldEnvironment.new(); environment.name = "WorldEnvironment"
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.035,.04,.05)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.7,.72,.76)
	environment.environment.ambient_light_energy = .18
	add_child(environment); get_viewport().use_taa = true
	bar = OrisonV2BarRegion.new(); bar.name = "ProductionHarukiya"; add_child(bar)
	if not _check(not bar.startup_failed and bar.get("destination") != null,"production room mounts unchanged"):
		await _finish(); return
	seats = preload("res://scripts/player/seat_gestures.gd").new(); add_child(seats)
	if not _check(bool(seats.call("mount_bar",bar)),"production seat authority binds actual destination markers"):
		await _finish(); return
	camera = Camera3D.new(); camera.fov = 72.; camera.near = .05; add_child(camera); camera.make_current()
	var rig := LightRig.new(); rig.name = "LightRig"; add_child(rig)
	crowd = Node3D.new(); crowd.name = "DiagnosticPresentations"; add_child(crowd)
	await _load_presentations()
	if failures.is_empty():
		Engine.max_fps = 0; DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
		for view: Dictionary in VIEWS.slice(0,2):
			_camera(view)
			for state: String in ["empty_before","occupied","empty_after"]:
				_occupied(state == "occupied")
				await _frames(WARM_FRAMES)
				timings.append(await _sample(str(view.id),state))
				if state != "empty_after": await _capture(str(view.id) + "_" + state)
		_occupied(true)
		for view: Dictionary in VIEWS.slice(2):
			_camera(view); await _frames(WARM_FRAMES)
			await _capture(str(view.id) + "_occupied")
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),false)
	await _finish()

func _load_presentations() -> void:
	var roster := Resident.roster()
	if not _check(roster.size() == 18,"eighteen approved original roster models are available"): return
	var registry := bar.resident_places
	for row: Dictionary in roster:
		var actor: AnimatedResident = Resident.new()
		actor.setup(row.display,row.id,row.unit,row.model); actor.externally_driven = true
		crowd.add_child(actor); residents.append(actor)
		if not _check(actor._model != null and actor._animation_player != null,"actual resident model and clips " + str(row.id)): return
		if actor.mina_animation != null: preload("res://scripts/characters/mina_idle_animation.gd").install(actor)
		var place: Dictionary = registry.call("preferred",str(row.id))
		if not _check(not place.is_empty() and bool(registry.call("claim",str(row.id),actor)),"unique preferred seat reservation " + str(row.id)): return
		var marker: Marker3D = place.marker
		actor.global_position = marker.global_position
		actor.global_rotation.y = float(place.npc_yaw)
		if actor.mina_animation != null:
			actor.global_position = registry.to_global(place.approach); actor.mina_animation.set_motion(false)
		else:
			if not _check(bool(actor.call("play_seated")),"personal seated clip exists " + str(row.id)): return
			actor._animation_player.advance(0.)
		await get_tree().process_frame
	# Let each personal clip finish its ordinary crossfade before measuring
	# the real deformed contact region. No shared guessed pelvis offset.
	await get_tree().create_timer(.35).timeout
	for actor: AnimatedResident in residents:
		var place: Dictionary = registry.call("preferred",actor.resident_id)
		if actor.mina_animation != null:
			_ground(actor,actor._model,registry.to_global(place.approach).y,"")
			poses.append({"id":actor.resident_id,"mode":"original standing idle; no personal seated clip", "at":actor.global_position,"seat_id":place.seat_id})
		else: _seat_actor(actor,place)
	var floor_y := bar.to_global(GameBoot.b2g([0,0,-2.8])).y
	var counter := bar.to_global(GameBoot.b2g([Glass.HOME[0],Glass.HOME[1],Glass.TOP_Z]))
	for identity: String in ["stacy","lily"]:
		var actor := CastModel.new()
		actor.configure(identity,"res://assets/characters/%s/%s.gltf" % [identity,identity],Cast.PARTS,
			"at_ease" if identity == "stacy" else "weight_on_one_leg")
		crowd.add_child(actor); cast.append(actor)
		if not _check(actor.ready_ok,"shipped base wardrobe face and hair " + identity): return
		actor.global_position = counter + (Vector3.FORWARD*1.10 if identity == "stacy" else Vector3(.95,0,.70))
		actor.global_position.y = floor_y; actor.rotation.y = 0. if identity == "stacy" else deg_to_rad(-20.)
		await get_tree().process_frame
		_ground(actor,actor.model,floor_y,"work_feet_")
		poses.append({"id":identity,"mode":"shipped CastModel work wardrobe and authored standing pose", "at":actor.global_position})
	# Reuse the tracked preview's own materials and personal idle. Only its
	# follower movement is disabled; this does not install a new cast body.
	adela = AdelaPreview.new(); crowd.add_child(adela)
	# Entering the tree enables a scripted physics callback. Disable the
	# follower afterwards: this isolated fixture has no player/world to follow.
	adela.set_physics_process(false); adela.show()
	if not _check(bool(adela.call("_load_model")),"tracked legacy Adela preview and personal idle load"): return
	var spec: Dictionary = bar.get("destination").get("spec")
	var vocalist: Array = spec.standing_positions.filter(func(row): return str(row.id) == "vocal_performer")
	if not _check(vocalist.size() == 1,"authored vocal stage diagnostic position"): return
	adela.global_position = bar.to_global(GameBoot.b2g(vocalist[0].at)); adela.rotation.y = PI
	await get_tree().process_frame
	_check(not adela.is_physics_processing() and adela.is_visible_in_tree(),"legacy preview stays visible with follower disabled after tree entry")
	_ground(adela,adela.get("model"),adela.global_position.y,"")
	poses.append({"id":"adela_voss","mode":"tracked legacy 28-bone preview; personal idle; follower disabled; new shared cast/wardrobe not present", "source":AdelaPreview.MODEL, "at":adela.global_position})
	_check(residents.size()+cast.size()+1 == 21 and poses.size() == 21,"twenty-one unique current presentations loaded; Adela explicitly legacy")
	_check((registry.get("claims") as Dictionary).size() == 18,"exactly eighteen staged resident reservations; no duplicate live-world owners")
	_check((seats.get("seats") as Dictionary).size() == 24,"room has twenty-four destination seat markers; body count is not seat/route qualification")

func _seat_actor(actor: AnimatedResident, place: Dictionary) -> void:
	var skeletons := actor._model.find_children("*","Skeleton3D",true,false)
	if not _check(skeletons.size() == 1,"one original skeleton for contact fit " + actor.resident_id): return
	var skeleton := skeletons[0] as Skeleton3D
	var pelvis := skeleton.find_bone("Hips")
	if not _check(pelvis >= 0,"original pelvis joint for contact fit " + actor.resident_id): return
	if not _check(actor.attention != null and actor.attention.pipeline.profile != null,"personal measured forward profile " + actor.resident_id): return
	var hip := skeleton.to_global(skeleton.get_bone_global_pose(pelvis).origin)
	var forward: Vector3 = skeleton.global_basis * actor.attention.pipeline.profile.forward
	forward.y = 0.; forward = forward.normalized()
	var candidates: Array[Dictionary] = []
	var geometry: Array[Dictionary] = []
	for draw: MeshInstance3D in actor._model.find_children("*","MeshInstance3D",true,false):
		var witnesses: Array[Dictionary] = []
		var points := _skin_points(draw,pelvis,witnesses)
		if not points.is_empty(): geometry.append({"mesh":str(actor._model.get_path_to(draw)),"surface_arrays_sha256":_geometry_digest(draw.mesh)})
		for index in points.size():
			var point := points[index]
			var delta := point - hip
			if delta.y < .05 and delta.y > -.35 and Vector2(delta.x,delta.z).length() < .32 and delta.dot(forward) < .03:
				var witness: Dictionary = witnesses[index]
				witness["mesh"] = str(actor._model.get_path_to(draw)); witness["world_point"] = _v(point)
				candidates.append(witness)
	if not _check(candidates.size() >= 8,"measured skinned pelvis underside exists " + actor.resident_id): return
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.world_point[1]) < float(b.world_point[1]))
	var selected_index := int(floor(float(candidates.size()-1)*.05))
	var contact_y := float(candidates[selected_index].world_point[1])
	var marker: Marker3D = place.marker
	var correction := Vector3(marker.global_position.x-hip.x,marker.global_position.y-contact_y,marker.global_position.z-hip.z)
	actor.global_position += correction
	var animation := actor._animation_player.get_animation(actor._animation_player.current_animation)
	poses.append({"id":actor.resident_id,"mode":"personal seated clip fitted from actual skinned pelvis underside", "seat_id":place.seat_id,
		"at":_v(actor.global_position),"yaw":actor.global_rotation.y,"seat":_v(marker.global_position),"correction":_v(correction),
		"seat_root_offset":_v(actor.global_position-marker.global_position),"seat_root_offset_space":"Godot world metres, root minus actual seat surface",
		"seat_source":marker.get_meta("seat"),"seat_layout_sha256":FileAccess.get_sha256("res://data/orison_v2/harukiya_destination_layout.json"),
		"asset_sources":_asset_sources(actor.model_path),"geometry":geometry,
		"contact_samples":candidates.size(),"contact_quantile":.05,"sampled_contact_y_before":contact_y,
		"contact_vertex":candidates[selected_index],"contact_candidate_vertices":candidates,
		"sampling_rule":{"hips_weight_min":.35,"hip_relative_y_m":[-.35,.05],"hip_horizontal_radius_m":.32,"rear_forward_dot_max_m":.03},
		"clip":actor._animation_player.current_animation,"clip_phase_s":actor._animation_player.current_animation_position,
		"clip_length_s":animation.length,"clip_tracks_sha256":_animation_digest(animation),
		"qualification":"candidate_for_visual_review_only; not applied to production",
		"limit":"one-phase diagnostic contact fit; no all-frame cloth, foot or seated-animation qualification"})

func _ground(actor: Node3D, model: Node3D, floor_y: float, prefix: String) -> void:
	var lowest := INF
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if not prefix.is_empty() and not str(draw.name).begins_with(prefix): continue
		for point: Vector3 in _skin_points(draw): lowest = minf(lowest,point.y)
	if _check(is_finite(lowest),"actual deformed foot/lowest geometry " + str(actor.name)):
		actor.global_position.y += floor_y-lowest

func _skin_points(draw: MeshInstance3D, pelvis := -1, witnesses: Array[Dictionary] = []) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if draw.mesh == null or not draw.is_visible_in_tree(): return result
	var skeleton := draw.get_node_or_null(draw.skeleton) as Skeleton3D if not draw.skeleton.is_empty() else null
	var transforms: Array[Transform3D] = []; var joint_ids: Array[int] = []
	if draw.skin != null and skeleton != null:
		for bind in draw.skin.get_bind_count():
			var bone_name := draw.skin.get_bind_name(bind)
			var bone := skeleton.find_bone(bone_name) if not bone_name.is_empty() else draw.skin.get_bind_bone(bind)
			if bone < 0: return result
			joint_ids.append(bone)
			transforms.append(skeleton.global_transform*skeleton.get_bone_global_pose(bone)*draw.skin.get_bind_pose(bind))
	for surface in draw.mesh.get_surface_count():
		var arrays := draw.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		if transforms.is_empty() or bones.is_empty():
			if pelvis < 0:
				for vertex: Vector3 in vertices: result.append(draw.global_transform*vertex)
			continue
		if vertices.is_empty() or bones.size() != weights.size() or bones.size()%vertices.size() != 0: continue
		var influences := int(bones.size()/vertices.size())
		for vertex in vertices.size():
			var influence := 0.
			if pelvis >= 0:
				for slot in influences:
					var index := vertex*influences+slot
					if bones[index] >= 0 and bones[index] < joint_ids.size() and joint_ids[bones[index]] == pelvis: influence += weights[index]
				if influence < .35: continue
			var point := Vector3.ZERO; var total := 0.
			for slot in influences:
				var index := vertex*influences+slot; var bind := bones[index]; var weight := weights[index]
				if weight <= 0. or bind < 0 or bind >= transforms.size(): continue
				point += (transforms[bind]*vertices[vertex])*weight; total += weight
			if total > .99:
				result.append(point/total)
				if pelvis >= 0: witnesses.append({"surface":surface,"vertex":vertex,"bind_local_point":_v(vertices[vertex]),"hips_weight":influence})
	return result

func _v(value: Vector3) -> Array[float]: return [value.x,value.y,value.z]

func _digest(value: Variant) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value)); return context.finish().hex_encode()

func _geometry_digest(mesh: Mesh) -> String:
	# Raw geometry arrays only: Resource instance IDs in material owners are
	# deliberately absent from this reproducible loaded-geometry signature.
	var surfaces: Array = []
	for surface in mesh.get_surface_count(): surfaces.append(mesh.surface_get_arrays(surface))
	return _digest(surfaces)

func _asset_sources(path: String) -> Array[Dictionary]:
	var paths: Array[String] = [path]
	if path.get_extension().to_lower() == "gltf":
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for kind: String in ["buffers","images"]:
			for entry: Dictionary in document.get(kind,[]):
				var uri := str(entry.get("uri",""))
				if not uri.is_empty() and not uri.begins_with("data:"):
					var asset := path.get_base_dir().path_join(uri.uri_decode()).simplify_path()
					if asset not in paths: paths.append(asset)
	var personal := path.get_basename()+"_moves.glb"
	if FileAccess.file_exists(personal): paths.append(personal)
	var result: Array[Dictionary] = []
	for asset: String in paths:
		var signature := FileAccess.get_sha256(asset)
		_check(not signature.is_empty(),"seated source hash " + asset)
		result.append({"path":asset,"sha256":signature})
	return result

func _animation_digest(animation: Animation) -> String:
	var tracks: Array = []
	for track in animation.get_track_count():
		var keys: Array = []
		for key in animation.track_get_key_count(track):
			keys.append([animation.track_get_key_time(track,key),animation.track_get_key_transition(track,key),animation.track_get_key_value(track,key)])
		tracks.append({"type":animation.track_get_type(track),"path":str(animation.track_get_path(track)),"interpolation":animation.track_get_interpolation_type(track),"enabled":animation.track_is_enabled(track),"keys":keys})
	return _digest({"length":animation.length,"loop":animation.loop_mode,"tracks":tracks})

func _occupied(enabled: bool) -> void:
	crowd.visible = enabled
	crowd.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	for actor: AnimatedResident in residents:
		if actor.attention != null: actor.attention.pipeline.active = enabled
	for actor: Node3D in cast: actor.call("set_active",enabled)

func _camera(view: Dictionary) -> void:
	camera.global_position = bar.to_global(GameBoot.b2g(view.at))
	camera.look_at(bar.to_global(GameBoot.b2g(view.look)))

func _frames(count: int) -> void:
	for frame in count: await RenderingServer.frame_post_draw

func _sample(view: String, state: String) -> Dictionary:
	var samples: Array = []; var frame_ms: Array[float] = []; var cpu: Array[float] = []; var gpu: Array[float] = []
	var draws: Array[float] = []; var primitives: Array[float] = []; var objects: Array[float] = []
	var rid := get_viewport().get_viewport_rid(); var previous := Time.get_ticks_usec()
	for frame in SAMPLE_FRAMES:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var row := [(now-previous)/1000., RenderingServer.viewport_get_measured_render_time_cpu(rid),RenderingServer.viewport_get_measured_render_time_gpu(rid),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)]
		previous = now; samples.append(row)
		frame_ms.append(row[0]); cpu.append(row[1]); gpu.append(row[2]); draws.append(row[3]); primitives.append(row[4]); objects.append(row[5])
	return {"view":view,"state":state,"warm_frames":WARM_FRAMES,"sample_frames":SAMPLE_FRAMES,
		"frame_ms":_distribution(frame_ms),"render_cpu_ms":_distribution(cpu),"render_gpu_ms":_distribution(gpu),
		"draws":_distribution(draws),"primitives":_distribution(primitives),"objects":_distribution(objects),
		"columns":["wall_ms","main_render_cpu_ms","main_render_gpu_ms","draws","primitives","objects"],"samples":samples}

func _distribution(values: Array[float]) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)],"min":values[0],"max":values[-1]}

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image(); var path := directory.path_join(label+".png")
	_check(image != null and image.save_png(path) == OK,"capture outside timed window " + label)
	captures.append({"label":label,"path":path,"sha256":FileAccess.get_sha256(path),"camera":camera.global_transform})

func _inputs() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://..").simplify_path(); var runtime: Array = []; var physical: Array = []; var head: Array = []
	_check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],runtime) == 0,"runtime source signature")
	_check(OS.execute("python",[root.path_join("tools/v2_physical_inputs.py"),"--root",root],physical) == 0,"physical source signature")
	_check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head) == 0,"repository source provenance")
	return {"runtime":str(runtime[0]).strip_edges() if not runtime.is_empty() else "","physical":str(physical[0]).strip_edges() if not physical.is_empty() else "",
		"head":str(head[0]).strip_edges() if not head.is_empty() else "","test":FileAccess.get_sha256(get_script().resource_path),"scene":FileAccess.get_sha256(scene_file_path)}

func _finish() -> void:
	var settings := {"viewport":get_viewport().get_visible_rect().size,"taa":get_viewport().use_taa,"msaa":get_viewport().msaa_3d,
		"max_fps_during_sample":Engine.max_fps,"vsync_during_sample":DisplayServer.window_get_vsync_mode(),"engine":Engine.get_version_info(),
		"lighting":"production practicals and LightRig; neutral ambient 0.18; Friday 21:00; no sky/full city",
		"controls":"all actors remain loaded in memory; empty controls hide them and disable subtree processing; warmups/readbacks excluded"}
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),false)
	if crowd != null: crowd.free(); crowd = null
	if seats != null: seats.free(); seats = null
	if bar != null: bar.shutdown(); bar.free(); bar = null
	await get_tree().process_frame
	if preview_owned:
		_check(RealityState.end_preview_campaign(self) and is_same(RealityState.data,prior_data),"original campaign context restored")
		preview_owned = false
	GameBoot.launch_mode = prior_mode; Engine.max_fps = prior_fps; DisplayServer.window_set_vsync_mode(prior_vsync)
	var final_inputs := _inputs()
	_check(final_inputs == initial_inputs,"source and fixture frozen for complete diagnostic")
	_check(timings.size() == 6 and captures.size() == 6,"two matched empty/occupied/empty sequences and four occupied views complete")
	var support_records: Array = poses.filter(func(row: Dictionary) -> bool: return row.has("seat_root_offset"))
	var support_path := directory.path_join("seat_support_candidates.json")
	var support_file := FileAccess.open(support_path,FileAccess.WRITE)
	if support_file != null:
		support_file.store_string(JSON.stringify({"schema_version":1,"source":final_inputs,"qualification":"Unqualified candidate measurements awaiting native visual review. No production offset changed.","records":support_records},"\t"))
		support_file.flush(); _check(support_file.get_error() == OK,"candidate seating measurements written"); support_file.close()
	else: _check(false,"candidate seating measurements writable")
	var result := {"evidence_class":"INERT","status":"technical_pass" if failures.is_empty() else "failed",
		"scope":"Isolated production room with 18 original resident presentations, shipped Lily/Stacy and tracked legacy Adela. Staged capacity/visibility and matched room renderer cost only; no attendance, arrivals, real routes, complete-world performance, saved-game, all-frame pose-contact or artistic acceptance.",
		"capacity":{"loaded_presentations":poses.size(),"planned_people":21,"available_seat_markers":24,
			"adela":"Tracked 28-bone preview GLB and own idle; not the new shared 76-bone cast/wardrobe. No private report assets imported."},
		"elapsed_s":(Time.get_ticks_msec()-started)/1000.,"source":final_inputs,"checks":checks,"failures":failures,
		"settings":settings,"poses":poses,"timings":timings,"captures":captures,"seating_candidates":{"path":support_path,"count":support_records.size(),"sha256":FileAccess.get_sha256(support_path)},
		"memory_limit":"All source resources stay loaded for both states. This comparison makes no memory-saving claim."}
	var file := FileAccess.open(directory.path_join("crowd_diagnostic.json"),FileAccess.WRITE)
	if file == null: push_error("crowd diagnostic could not open"); get_tree().quit(2); return
	file.store_string(JSON.stringify(result,"\t")); file.flush(); var write_ok := file.get_error() == OK; file.close()
	print("HARUKIYA DESTINATION CROWD: ","PASS" if failures.is_empty() and write_ok else "FAIL","; presentations=",poses.size(),"; failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() and write_ok else 1)
