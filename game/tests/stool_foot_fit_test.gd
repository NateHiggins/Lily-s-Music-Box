extends "res://tests/staff_pose_attention.gd"
## Exact production seating in a synthetic fitting diagnostic; evidence remains INERT.
const RuntimeScene = preload("res://scenes/building/orison_v2_runtime.tscn")
const CounterSource = preload("res://scripts/props/luncheonette_counter.gd")
const ResidentSource = preload("res://scripts/characters/orison_v2_resident_presentation.gd")
const BodyRegistry = preload("res://scripts/characters/cast_bodies.gd")
const NATIVE_IDENTITY = "res://tests/fixtures/stool_foot_native_identity.json"
const SAMPLES := 6
class PassageView:
	extends Node3D
	var fitting_root: Node3D
	func transaction_actor_root() -> Node3D: return fitting_root
class SeatLedger:
	extends Node
	var taken: Dictionary = {}
class FittingWorld:
	extends Node3D
	var passage_region: Node3D
	var seat_gestures: Node
class KneeProbe:
	extends RefCounted
	var original: RefCounted
	var snapshot: Array=[]
	var errors: Array:
		get: return original.errors
	var maximum_reach_error: float:
		get: return original.maximum_reach_error
	func apply(skeleton: Skeleton3D, write: Callable) -> void:
		snapshot=[]
		for leg: Dictionary in original.legs:
			var knee: Vector3=skeleton.get_bone_global_pose(leg.bones[1]).origin
			var foot: Vector3=skeleton.get_bone_global_pose(leg.bones[2]).origin
			var offset: Vector3=skeleton.global_basis*((leg.foot_basis as Basis)*(leg.anchor as Vector3))
			snapshot.append({"knee_world":[(skeleton.global_transform*knee).x,(skeleton.global_transform*knee).y,(skeleton.global_transform*knee).z],"shin_length":(skeleton.global_basis*(foot-knee)).length(),"anchor_offset_world":[offset.x,offset.y,offset.z],"target_world":[leg.target.x,leg.target.y,leg.target.z]})
		original.apply(skeleton,write)
var runtime: OrisonV2RuntimeRoot
var fitting_world: Node3D
var fitting_counter: Node3D
var fitting_root: Node3D
var native_identity: Dictionary = {}
var stool_frames: Dictionary = {}
var native_geometry: Array = []
var shoe_samples: Array = []
var actual_counter_before: Dictionary = {}
var prior_mode := 0
var prior_mouse := 0
var prior_freeze := false
var error_logger: Logger
var completed_residents: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	output=OS.get_environment("SHOT_DIR")
	var profile: String=OS.get_environment("STOOL_FOOT_ISOLATED_APPDATA").replace("\\","/").simplify_path()
	if not _check(profile.begins_with("C:/ov/reports/stool_fit_20261116/feet_intake_01/") and OS.get_environment("APPDATA").replace("\\","/").simplify_path()==profile and OS.get_user_data_dir().replace("\\","/").simplify_path()==profile.path_join("PleaseRemainOnTheLine"),"isolated APPDATA before autoload"):
		get_tree().quit(2);return
	if not _check(not output.is_empty() and not FileAccess.file_exists(output.path_join("measurements.json")) and DirAccess.make_dir_recursive_absolute(output)==OK,"fresh output directory"):
		get_tree().quit(2);return
	_check(DisplayServer.get_name()!="headless","live rendered SkinReference backend")
	for key: String in ["SCHEDULE","SCHEDULE_DAY","SCHEDULE_DOY","SCHEDULE_MINUTE","SCHEDULE_FIRST_SAT","AGENDA","CAMPAIGN_TIME_FREEZE"]:
		_check(OS.get_environment(key).is_empty(),"no chronology override "+key)
	if not failures.is_empty():get_tree().quit(2);return
	error_logger=preload("res://tests/guide_bell_error_capture.gd").new();OS.add_logger(error_logger)
	inputs=_signature()
	prior_data=RealityState.data;prior_text=JSON.stringify(prior_data,"",true,true)
	prior_status=_status().duplicate(true);prior_files=_save_bundle();captured_state=true
	prior_mode=GameBoot.launch_mode;prior_mouse=Input.mouse_mode;prior_freeze=CampaignTime._frozen_for_tests
	lease=RealityState.begin_preview_campaign(self)
	if not _check(lease,"exclusive nonpersistent preview"):_finish();return
	# No date jump, timetable override, motive adjustment, counter attendance call or new foot IK.
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	if not await _synthetic_order_check():_finish();return
	native_identity=JSON.parse_string(FileAccess.get_file_as_string(NATIVE_IDENTITY))
	if not _check(native_identity is Dictionary and native_identity.has("source_bindings"),"native identity packet"):_finish();return
	for path: String in native_identity.source_bindings:
		var binding: Dictionary=native_identity.source_bindings[path]
		var absolute: String=ProjectSettings.globalize_path("res://../"+path)
		var actual_hash: String=FileAccess.get_file_as_string(absolute).replace("\r\n","\n").sha256_text() if binding.kind=="lf" else FileAccess.get_sha256(absolute)
		_check(actual_hash==str(binding.sha256),"unchanged native intake source "+path)
	if not failures.is_empty():_finish();return
	runtime=RuntimeScene.instantiate();add_child(runtime)
	await get_tree().physics_frame;await get_tree().physics_frame
	if not _check(not runtime.startup_failed and runtime.passage_region!=null and runtime.luncheonette_counter!=null,"actual single composed runtime"):_finish();return
	var passage: Node3D=runtime.passage_region
	# Same nearby service stance as the existing real-input LuncheonetteRouteTest.
	# SITE_SHOP_IN* are three cage lamps, not an entry marker (original failure retained).
	var point: Node3D=runtime.shop_counters.get("luncheonette")
	if not _check(point!=null,"actual diner service point"):_finish();return
	runtime.player.global_position=point.global_position+Vector3(-1.35,-1.1,0)
	await get_tree().physics_frame
	var deadline: int=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		var cell: Node3D=passage.cell_nodes.get("shop_luncheonette")
		if cell!=null and cell.has_node("ShopSeating"):break
		await get_tree().create_timer(.1).timeout
	var cell: Node3D=passage.cell_nodes.get("shop_luncheonette")
	if not _check(cell!=null and cell.has_node("ShopSeating"),"actual resident native seating mount"):_finish();return
	_capture_native(cell.get_node("ShopSeating"))
	if not failures.is_empty():_finish();return
	actual_counter_before=_counter_identity(runtime.luncheonette_counter)
	fitting_root=Node3D.new();fitting_root.name="SyntheticFittingActors";add_child(fitting_root)
	fitting_world=FittingWorld.new();add_child(fitting_world)
	var view:=PassageView.new();fitting_world.add_child(view)
	view.global_transform=passage.global_transform;view.fitting_root=fitting_root
	var ledger:=SeatLedger.new();fitting_world.add_child(ledger)
	fitting_world.passage_region=view;fitting_world.seat_gestures=ledger
	fitting_counter=CounterSource.new();fitting_counter.set_process(false)
	fitting_counter.world=fitting_world;fitting_world.add_child(fitting_counter)
	fitting_counter.set_process(false)
	var roster: Array=ResidentSource.roster()
	if not _check(roster.size()==18,"all eighteen actual eligible counter residents"):_finish();return
	var order: Array[String]=["mina_vale","iris_bell"]
	for row: Dictionary in roster:
		if not order.has(str(row.id)):order.append(str(row.id))
	var requested: String=OS.get_environment("STOOL_FOOT_RESIDENTS")
	if not requested.is_empty():
		var subset: Array[String]=[]
		for who: String in requested.split(","):
			if not _check(order.has(who) and not subset.has(who),"valid unique fitting subset "+who):_finish();return
			subset.append(who)
		order=subset
	for who: String in order:
		if not failures.is_empty():break
		await _fit_resident(who)
	_check(completed_residents.size()==order.size(),"declared residents completed exact six samples")
	_check(_counter_identity(runtime.luncheonette_counter)==actual_counter_before,"real counter body/stool authority untouched by fitting")
	_finish()

func _counter_identity(counter: Node3D) -> Dictionary:
	var body_ids: Dictionary={}
	for who: String in counter.bodies:
		var body: Node=counter.bodies[who];body_ids[who]=body.get_instance_id() if is_instance_valid(body) else 0
	return {"bodies":body_ids,"stools":counter._stools.duplicate(true)}

func _capture_native(model: Node3D) -> void:
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var part: String=str(draw.get_meta("seating_part",""))
		if not part.begins_with("storm_shop_luncheonette_stool"):continue
		var matches: Array=[]
		for row: Dictionary in native_identity.native_parts:
			if str(row.name)==part:matches.append(row)
		if not _check(matches.size()==1,"exact named native part "+part):continue
		var row: Dictionary=matches[0]
		_check(draw.mesh.get_faces().size()/3==int(row.triangles),"complete mounted native triangle count "+part)
		var shapes: Array[Node]=draw.find_children("*","CollisionShape3D",true,false)
		_check(shapes.size()==1 and not shapes[0].disabled and shapes[0].shape is ConcavePolygonShape3D,"real seating collider "+part)
		if shapes.size()==1:
			_check(shapes[0].global_transform.is_equal_approx(draw.global_transform),"native collider transform "+part)
		var assembly: String=part.get_slice("__",0)
		if str(row.name).ends_with("__chrome"):
			# Exact loaded chrome origin is the source floor/centroid frame, not rounded Counter.STOOLS.
			stool_frames[assembly]=draw.global_transform
		# get_faces() constructs a TriangleMesh and snaps to .1mm on this engine.
		# Keep original rendered surface vertices separately from collider geometry.
		var faces:=PackedVector3Array()
		for surface: int in draw.mesh.get_surface_count():
			var arrays: Array=draw.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for index: int in indices:faces.append(points[index])
		native_geometry.append({"part":part,"native_identity":row,"world_transform":_matrix(draw.global_transform),"mounted_faces_mesh_local":_points(faces),"mounted_collider_faces_mesh_local":_points((shapes[0].shape as ConcavePolygonShape3D).get_faces()) if shapes.size()==1 and shapes[0].shape is ConcavePolygonShape3D else [],"canonical_triangle_ids_not_assumed_imported_indices":true})
	_check(stool_frames.size()==3,"exact three active native stool frames")

func _fit_resident(who: String) -> void:
	print("[STOOL FIT] begin ",who)
	# The only call creating/positioning/dressing/starting the seated actor is production Counter._seat.
	fitting_counter._seat(who)
	var resident: Node3D=fitting_counter.bodies.get(who)
	if not _check(resident!=null,"production seat created "+who):return
	var body: Node3D=resident.cast_body
	if not _check(body!=null and body.ready_ok and resident.model_path==BodyRegistry.model_for(who),"actual current CastBody without old-body fallback "+who):return
	var ap: AnimationPlayer=resident._animation_player
	if not _check(ap!=null and ap.is_playing(),"actual seated clip player "+who):return
	var clip: String=ap.current_animation
	if not _check(clip.get_slice("/",clip.get_slice_count("/")-1)=="clip_06","production selected shared clip06 "+who):return
	var length: float=ap.current_animation_length
	if not _check(length>0.4,"nonzero shared seated clip "+who):return
	var began: int=Time.get_ticks_msec()
	await get_tree().create_timer(.45).timeout
	await RenderingServer.frame_post_draw
	var stool_index: int=int(fitting_counter._stools[who])
	var number: int=int(CounterSource.STOOLS[stool_index][0])
	var assembly: String=CounterSource.STOOL_SEAT%number
	var frame: Transform3D=stool_frames[assembly]
	var contact: RefCounted=body.attention.pipeline.seated_feet
	var probe: KneeProbe
	if OS.get_environment("STOOL_KNEE_PREFLIGHT")=="1" and contact!=null:
		probe=KneeProbe.new();probe.original=contact
		body.attention.pipeline.seated_feet=probe;contact=probe
	if OS.get_environment("STOOL_FOOT_REQUIRE_CONTACT")=="1":
		if not _check(contact!=null and contact.errors.is_empty(),"actual footrest contact bound "+who):return
	for sample: int in SAMPLES:
		if sample>0:await get_tree().create_timer(length/float(SAMPLES)).timeout
		await RenderingServer.frame_post_draw
		_check(ap.is_playing() and ap.current_animation==clip,"same real clip throughout "+who)
		if contact!=null:
			_check(body.attention.pipeline.refused_writes==0 and contact.maximum_reach_error<.001,"reachable single-writer foot contacts %s (error=%s, refused=%d)" % [who,str(contact.maximum_reach_error),body.attention.pipeline.refused_writes])
			if OS.get_environment("STOOL_REQUIRE_FIXED_THIGHS")=="1":
				for side: String in ["Left","Right"]:
					_check(not body.attention.pipeline.writers.has(body.skeleton.find_bone(side+"UpLeg")),"original seated thigh kept "+who+"/"+side)
		if sample==0 and OS.get_environment("STOOL_FOOT_CAPTURE")=="1":
			var camera:=Camera3D.new();add_child(camera)
			camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.65
			camera.global_position=frame.origin+Vector3(1.5,.9,1.5)
			camera.look_at(frame.origin+Vector3(.12,.56,0));camera.make_current()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output.path_join(who+".png"))
			camera.queue_free()
		actor=body # accepted morph-before-skin helper checks this actual CastPresentation skeleton.
		var posterior: Dictionary=_posterior_support_export(body,frame)
		var footwear: String=str(body.wardrobe.worn.get("feet",""))
		var draws: Array=body.wardrobe._meshes.get(footwear,[])
		if not _check(not footwear.is_empty() and not draws.is_empty(),"actual worn footwear "+who):break
		var surfaces: Array=[]
		for draw: MeshInstance3D in draws:
			if not _check(draw.is_visible_in_tree(),"actual worn shoe is visible "+who):continue
			var source: ArrayMesh=draw.mesh as ArrayMesh
			if not _check(source!=null,"source footwear ArrayMesh"):continue
			var baked: ArrayMesh=_morph_then_skin(draw) if draw.skin!=null else (draw.bake_mesh_from_current_blend_shape_mix() if source.get_blend_shape_count()>0 else source)
			if not _check(baked!=null and baked.get_surface_count()==source.get_surface_count(),"actual complete footwear bake"):continue
			var mix: Dictionary={}
			for i: int in source.get_blend_shape_count():mix[str(source.get_blend_shape_name(i))]=draw.get_blend_shape_value(i)
			for surface: int in baked.get_surface_count():
				var a: Array=baked.surface_get_arrays(surface)
				var original: Array=source.surface_get_arrays(surface)
				var points: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX]
				_check(points.size()==(original[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() and indices==original[Mesh.ARRAY_INDEX],"shoe vertex/triangle identity retained")
				var local:=PackedVector3Array();var minimum:=INF;var vertex_id: int=-1
				var to_frame: Transform3D=frame.affine_inverse()*draw.global_transform
				for i: int in points.size():
					var p: Vector3=to_frame*points[i];local.append(p)
					_check(p.is_finite(),"finite evaluated shoe vertex")
					if p.y<minimum:minimum=p.y;vertex_id=i
				var incident: Array=[]
				for tri: int in indices.size()/3:
					if indices[tri*3]==vertex_id or indices[tri*3+1]==vertex_id or indices[tri*3+2]==vertex_id:incident.append(tri)
				var shaders: Array=[]
				for mat: Material in [draw.get_active_material(surface),draw.material_overlay]:
					if mat!=null:shaders.append({"class":mat.get_class(),"path":mat.resource_path})
				_check(not draw.get_active_material(surface) is ShaderMaterial and not draw.material_overlay is ShaderMaterial,"no unmeasured footwear vertex shader")
				surfaces.append({"mesh_path":str(body.get_path_to(draw)),"source_mesh_resource":source.resource_path,"surface":surface,"part":footwear,"morph_weights":mix,"skinned":draw.skin!=null,"vertex_count":points.size(),"triangle_count":indices.size()/3,"positions_stool_local":_points(local),"indices":Array(indices),"whole_surface_min_y":minimum,"minimum_vertex":vertex_id,"minimum_incident_triangles":incident,"presentation":shaders,"source_skin_bind_names":_bind_names(draw),"source_bone_indices":Array(original[Mesh.ARRAY_BONES]) if original[Mesh.ARRAY_BONES]!=null else [],"source_bone_weights":Array(original[Mesh.ARRAY_WEIGHTS]) if original[Mesh.ARRAY_WEIGHTS]!=null else []})
		shoe_samples.append({"kind":"synthetic_actual_production_counter_seat","resident":who,"source_model":resident.model_path,"outfit":body.worn_parts(),"stool":assembly,"stool_world_frame":_matrix(frame),"seat_actor_world":_matrix(resident.global_transform),"body_world":_matrix(body.global_transform),"clip":clip,"clip_position":ap.current_animation_position,"clip_length":length,"elapsed_after_seat_s":(Time.get_ticks_msec()-began)/1000.0,"sample":sample,"surfaces":surfaces,"source_counter_top":CounterSource.STOOL_TOP,"source_seated_support":fitting_counter._body_seated_support(resident,who)})
		_check(not surfaces.is_empty(),"whole worn shoe surfaces retained "+who)
		shoe_samples[shoe_samples.size()-1]["posterior_support"]=posterior
		if probe!=null:shoe_samples[shoe_samples.size()-1]["original_knee_preflight"]=probe.snapshot.duplicate(true)
	completed_residents.append(who)
	print("[STOOL FIT] measured ",who," clip_seconds=",length)
	actor=null
	resident.free();fitting_counter.bodies.erase(who);fitting_counter._stools.erase(who)
	fitting_world.seat_gestures.taken.clear()
	await get_tree().process_frame

func _bind_names(draw: MeshInstance3D) -> Array:
	var names: Array=[]
	if draw.skin==null:return names
	var skel: Skeleton3D=draw.get_node_or_null(draw.skeleton) as Skeleton3D
	for i: int in draw.skin.get_bind_count():
		var bone: int=draw.skin.get_bind_bone(i)
		var named: String=str(skel.get_bone_name(bone)) if bone>=0 else str(draw.skin.get_bind_name(i))
		names.append(named)
	return names

func _points(points: PackedVector3Array) -> Array:
	var out: Array=[]
	for p: Vector3 in points:out.append([p.x,p.y,p.z])
	return out
func _matrix(t: Transform3D) -> Dictionary:
	return {"basis_columns":[_vec(t.basis.x),_vec(t.basis.y),_vec(t.basis.z)],"origin":_vec(t.origin)}

func _finish() -> void:
	actor=null
	if is_instance_valid(fitting_world):fitting_world.free()
	if is_instance_valid(fitting_root):fitting_root.free()
	if is_instance_valid(runtime):runtime.shutdown_for_tests();runtime.free()
	if lease:_check(RealityState.end_preview_campaign(self),"preview returned");lease=false
	if captured_state:
		GameBoot.launch_mode=prior_mode;Input.mouse_mode=prior_mouse;CampaignTime.set_frozen_for_tests(prior_freeze)
		_check(is_same(prior_data,RealityState.data) and JSON.stringify(RealityState.data,"",true,true)==prior_text,"campaign identity/values restored")
		_check(_status()==prior_status and _save_bundle()==prior_files,"save bytes and protection restored")
		_check(inputs==_signature(),"source bindings unchanged")
	var errors: Array=[]
	if error_logger!=null:errors=error_logger.errors.duplicate();OS.remove_logger(error_logger)
	_check(errors.is_empty(),"no actual engine errors")
	var file:=FileAccess.open(output.path_join("measurements.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"evidence_class":"INERT synthetic fitting diagnostic","inputs":inputs,"failures":failures,"engine_errors":errors,"completed_residents":completed_residents,"native_geometry":native_geometry,"samples":shoe_samples,"limits":"Unaccepted sampled technical fit, not natural attendance, locomotion, gameplay service, full animation envelope, artistic acceptance, footrest support or proposed height. Actual whole shoe surfaces exported; minima are not sole-support proof. Canonical/imported triangle index mapping must be reconciled geometrically before contact acceptance. Contact anchors do not prove support. No body scaling, limb-length change or collision disable."},"\t"));file.close()
	get_tree().quit(0 if failures.is_empty() else 1)

# Append these methods to stool_foot_fit_test.gd; inherited bench uses them unchanged.
# Geometry export only. Does not write any bone, morph, transform, or source mesh.
func _posterior_joint_name(value: String) -> String:
	return value.replace(":", "_").get_slice("_", 1) if value.begins_with("mixamorig") else value

func _posterior_support_export(body: Node3D, frame: Transform3D) -> Dictionary:
	var skeleton: Skeleton3D=body.skeleton
	var actor_from_world: Transform3D=body.global_transform.affine_inverse()
	var actor_from_skeleton: Transform3D=actor_from_world*skeleton.global_transform
	var chains: Dictionary={}
	for side: String in ["Left", "Right"]:
		var upper_id: int=skeleton.find_bone(side+"UpLeg")
		var lower_id: int=skeleton.find_bone(side+"Leg")
		if not _check(upper_id>=0 and lower_id>=0,"posterior actual femur bones "+side):return {}
		# Only origins and femur LENGTH are consumed. The foot solver retains these
		# under its rigid UpLeg turn; post-draw reset knee DIRECTION is NOT final IK.
		var origin: Vector3=actor_from_skeleton*skeleton.get_bone_global_pose(upper_id).origin
		var knee: Vector3=actor_from_skeleton*skeleton.get_bone_global_pose(lower_id).origin
		var length: float=origin.distance_to(knee)
		if not _check(length>.001,"posterior finite femur length "+side):return {}
		chains[side]={"origin_actor":origin,"length":length}
	var result_surfaces: Array=[]
	var present: Dictionary={}
	var maximum_selected_count: int=0
	var largest_candidates: Array=[]
	for node: Node in body.model.find_children("Skin_*","MeshInstance3D",true,false):
		var draw: MeshInstance3D=node as MeshInstance3D
		var name: String=str(draw.name)
		if name not in ["Skin_hips","Skin_legs"]:continue
		if not _check(not present.has(name),"one posterior base skin draw "+name):return {}
		present[name]=true
		var source: ArrayMesh=draw.mesh as ArrayMesh
		if not _check(source!=null and draw.skin!=null and draw.get_node_or_null(draw.skeleton)==skeleton,"posterior actual base skin "+name):return {}
		var baked: ArrayMesh=_morph_then_skin(draw)
		if not _check(baked!=null and baked.get_surface_count()==source.get_surface_count(),"posterior morph-before-skin conservation "+name):return {}
		var bind_names: Array=_bind_names(draw)
		var mix: Dictionary={}
		for blend: int in source.get_blend_shape_count():mix[str(source.get_blend_shape_name(blend))]=draw.get_blend_shape_value(blend)
		var actor_from_draw: Transform3D=actor_from_world*draw.global_transform
		var stool_from_draw: Transform3D=frame.affine_inverse()*draw.global_transform
		for surface: int in source.get_surface_count():
			var original: Array=source.surface_get_arrays(surface)
			var evaluated: Array=baked.surface_get_arrays(surface)
			var points: PackedVector3Array=evaluated[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=evaluated[Mesh.ARRAY_INDEX]
			var source_points: PackedVector3Array=original[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=original[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array=original[Mesh.ARRAY_WEIGHTS]
			var stride: int=8 if (source.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)!=0 else 4
			if not _check(points.size()==source_points.size() and indices==original[Mesh.ARRAY_INDEX] and bones.size()==points.size()*stride and weights.size()==bones.size(),"posterior complete vertex/index/skin identity "+name):return {}
			var stool_points:=PackedVector3Array()
			var actor_points:=PackedVector3Array()
			var selected: Array[int]=[]
			var selected_set: Dictionary={}
			var dominant_names: Array[String]=[]
			var selected_minimum: float=INF
			var selected_minimum_vertex: int=-1
			for vertex: int in points.size():
				var p_actor: Vector3=actor_from_draw*points[vertex]
				var p_stool: Vector3=stool_from_draw*points[vertex]
				if not _check(p_actor.is_finite() and p_stool.is_finite(),"finite posterior evaluated vertex"):return {}
				actor_points.append(p_actor);stool_points.append(p_stool)
				var maximum_weight: float=-1.0
				var dominant: String=""
				for slot: int in stride:
					var offset: int=vertex*stride+slot
					var bind_index: int=bones[offset]
					if not _check(bind_index>=0 and bind_index<bind_names.size() and is_finite(weights[offset]) and weights[offset]>=0.0,"posterior actual bind/weight"):return {}
					# Strict > retains FIRST maximum-weight slot, matching NumPy argmax.
					if weights[offset]>maximum_weight:
						maximum_weight=weights[offset];dominant=_posterior_joint_name(str(bind_names[bind_index]))
				dominant_names.append(dominant)
				var pick: bool=dominant=="Hips"
				for side: String in ["Left","Right"]:
					if dominant==side+"UpLeg" and p_actor.distance_to(chains[side].origin_actor)<.55*float(chains[side].length):pick=true
				if pick:
					selected.append(vertex);selected_set[vertex]=true
					if p_actor.y<selected_minimum:selected_minimum=p_actor.y;selected_minimum_vertex=vertex
			var all_selected_triangles: Array[int]=[]
			var any_selected_triangles: Array[int]=[]
			var minimum_incident_triangles: Array[int]=[]
			for triangle: int in indices.size()/3:
				var count: int=0
				for corner: int in 3:
					var vertex: int=indices[triangle*3+corner]
					if not _check(vertex>=0 and vertex<points.size(),"posterior valid original triangle index"):return {}
					if selected_set.has(vertex):count+=1
					if vertex==selected_minimum_vertex and not minimum_incident_triangles.has(triangle):minimum_incident_triangles.append(triangle)
				if count==3:all_selected_triangles.append(triangle)
				if count>0:any_selected_triangles.append(triangle)
			var record: Dictionary={"mesh_path":str(body.get_path_to(draw)),"draw_name":name,"visible_in_tree":draw.is_visible_in_tree(),"source_mesh_resource":source.resource_path,"surface":surface,"source_array_vertex_ids":Array(range(points.size())),"vertex_id_scope":"Original imported ArrayMesh surface vertex IDs, NOT assumed canonical glTF indices","vertex_count":points.size(),"triangle_count":indices.size()/3,"positions_stool_local":_points(stool_points),"indices":Array(indices),"source_skin_bind_names":bind_names,"source_bone_indices":Array(bones),"source_bone_weights":Array(weights),"source_weight_stride":stride,"dominant_joint_per_vertex":dominant_names,"selected_source_array_vertex_ids":selected,"selected_count":selected.size(),"producer_surface_eligible":selected.size()>=50,"producer_selected_minimum_actor_y":selected_minimum if selected_minimum_vertex>=0 else null,"producer_minimum_vertex":selected_minimum_vertex,"producer_minimum_incident_triangles":minimum_incident_triangles,"region_all_three_selected_triangle_ids":all_selected_triangles,"region_any_selected_triangle_ids":any_selected_triangles,"region_predicate":"all-three-selected is interior subset; any-selected includes boundary; FULL skin triangles retained independently","morph_weights":mix,"draw_world":_matrix(draw.global_transform),"skeleton_world":_matrix(skeleton.global_transform)}
			result_surfaces.append(record)
			if selected.size()>=50:
				var candidate: Dictionary={"mesh_path":record.mesh_path,"surface":surface,"selected_count":selected.size(),"minimum_actor_y":selected_minimum,"minimum_vertex":selected_minimum_vertex}
				if selected.size()>maximum_selected_count:maximum_selected_count=selected.size();largest_candidates.clear()
				if selected.size()==maximum_selected_count:largest_candidates.append(candidate)
	if not _check(present.size()==2,"whole actual Skin_hips and Skin_legs captured"):return {}
	return {"surfaces":result_surfaces,"producer_max_count_surface_candidates":largest_candidates,"selection":"Dominant Hips OR dominant Left/RightUpLeg with evaluated point within strict .55 femur length; same original producer predicate","origin_reference":{"Left":_vec(chains.Left.origin_actor),"Right":_vec(chains.Right.origin_actor)},"femur_lengths":{"Left":chains.Left.length,"Right":chains.Right.length},"reference_scope":"Only retained upper-leg origins and femur lengths consumed; no reset knee direction claimed final IK","actor_world":_matrix(body.global_transform),"stool_world":_matrix(frame),"limit":"Finite actual morph-before-skin support-region export. Low point OUTSIDE native cushion footprint is not penetration; exact cushion triangle overlap remains independent. Hidden base skin is anatomical geometry, not visible clothing support."}
