extends Node3D
## PRIVATE diagnostic proposal. Not a collision profile or runtime-contract writer.
const Cast = preload("res://scripts/characters/cast_model_presentation.gd")
const Owner = preload("res://scripts/characters/harukiya_cast.gd")
const Rules = preload("res://scripts/characters/wardrobe_rules.gd")
const SAMPLE_COUNT := 32
const INTERVAL := 0.25
var failures: Array[String] = []
var records: Array = []
var attention_case: Dictionary={}
var attention_plan: Array=[]
var modified_pose: Dictionary={}
var modified_pose_serial := 0
var captured_stills: Array=[]
var material_inventory: Dictionary={}
var uv_inventory: Dictionary={}
var inputs := {}
var output := ""
var lease := false
var actor: Node3D
var grounding: Node3D
var scenarios: Array=[]
var prior_data: Dictionary
var prior_text := ""
var prior_status := {}
var prior_files := {}
var captured_state := false
var current_case := {}
var expected_samples: Dictionary={}
var completed_samples: Dictionary={}

func _ready() -> void:
	var profile := OS.get_environment("STAFF_POSE_ISOLATED_APPDATA").replace("\\", "/").simplify_path()
	var actual_user_dir := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	if not profile.begins_with("C:/ov/reports/harukiya_overhaul_20261112/") or actual_user_dir != profile.path_join("PleaseRemainOnTheLine"):
		push_error("Staff pose measurement requires dedicated isolated APPDATA")
		get_tree().quit(2); return
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	if not ok: failures.append(label); push_error(label)
	return ok

func _signature() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var runtime: Array = []; var physical: Array = []
	_check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],runtime)==0,"runtime source binding")
	_check(OS.execute("python",[root.path_join("tools/v2_physical_inputs.py"),"--root",root],physical)==0,"physical source binding")
	var displacement_sources: Dictionary={}
	for path: String in ["res://shaders/character_hair.gdshader","res://shaders/stage_wisps.gdshader","res://scripts/characters/head_hair_motion.gd"]:
		_check(FileAccess.file_exists(path),"displacement source exists "+path)
		displacement_sources[path]=FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	return {"displacement_sources":displacement_sources,"runtime":str(runtime[0]).strip_edges() if not runtime.is_empty() else "", "physical":str(physical[0]).strip_edges() if not physical.is_empty() else "", "observer":FileAccess.get_file_as_string(get_script().resource_path).replace("\r\n","\n").sha256_text(), "scene_path":scene_file_path, "scene":FileAccess.get_file_as_string(scene_file_path).replace("\r\n","\n").sha256_text()}

func _run() -> void:
	output=OS.get_environment("SHOT_DIR")
	if not _check(not output.is_empty() and DirAccess.make_dir_recursive_absolute(output)==OK,"private output directory"):get_tree().quit(2);return
	if not _check(DisplayServer.get_name()!="headless","rendered backend required for current skin state"):get_tree().quit(2);return
	inputs=_signature()
	prior_data=RealityState.data
	prior_text=JSON.stringify(prior_data,"",true,true)
	prior_status=_status().duplicate(true)
	prior_files=_save_bundle()
	captured_state=true
	lease=RealityState.begin_preview_campaign(self)
	if not _check(lease,"exclusive nonpersistent preview"): _finish();return
	if not await _synthetic_order_check():_finish();return
	grounding=Owner.new() # Unmounted: no production actors, schedule or conversations.
	grounding._floor_y=0.0
	if not _check(grounding._rules.load_table(),"actual owner wardrobe rules loaded"):_finish();return
	var ensembles:=_ensembles()
	if not failures.is_empty():_finish();return
	for row: Dictionary in ensembles:expected_samples[str(row.ensemble_key)]=SAMPLE_COUNT
	for ensemble: Dictionary in ensembles:
		current_case=ensemble
		var person: String=ensemble.person
		var outfit: String=ensemble.outfit
		var parts: Array=ensemble.parts
		actor=Cast.new()
		actor.configure(person,"res://assets/characters/%s/%s.gltf" % [person,person],Owner.PARTS,"at_ease" if person=="stacy" else "weight_on_one_leg")
		add_child(actor)
		if not _check(actor.ready_ok,"actual loaded actor "+person+"/"+outfit):break
		grounding._ground_rest_shoes(actor)
		grounding.actors[person]=actor
		grounding.dress_for_evening(str(ensemble.input_date),int(ensemble.input_minute))
		_check(actor.last_refusal.is_empty(),"actual owner wardrobe change not refused")
		_check(actor.worn_parts()==parts,"actual owner worn parts equal rule resolution")
		_check_makeup(person,str(ensemble.makeup))
		modified_pose={}
		actor.skeleton.skeleton_updated.connect(_capture_modified_pose)
		if not failures.is_empty():break
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		attention_plan=_attention_stages()
		var began:=Time.get_ticks_msec()
		for sample: int in SAMPLE_COUNT:
			if sample%4==0:_begin_attention_stage(int(sample/4),person)
			await get_tree().create_timer(INTERVAL).timeout
			await RenderingServer.frame_post_draw
			# Keep early transition samples; give final sample bounded time for real
			# attention lookaway/reacquisition, with no owner timer/pose bypass.
			if sample%4==3:await _await_stage_observation()
			records.append(_measure(person,outfit,sample,(Time.get_ticks_msec()-began)/1000.0))
			completed_samples[str(ensemble.ensemble_key)]=int(completed_samples.get(str(ensemble.ensemble_key),0))+1
			if not failures.is_empty():break
		_check_attention_coverage(person,outfit)
		if failures.is_empty():await _capture_views(person,outfit)
		actor.stop_speaking()
		actor.attention._on_conversation_ended(person)
		actor.attention.staged_target=null
		grounding.actors.clear()
		actor.queue_free(); actor=null
		await get_tree().process_frame
		if not failures.is_empty():break
	_finish()

func _group(name: String, morphs: int) -> String:
	if morphs>0:return "face_or_morph_composed"
	if name=="Skin_hips":return "visible_skin_hips"
	if name in ["Skin_trunk","Skin_chest"]:return "visible_skin_torso"
	if name.to_lower().contains("hair"):return "hair_nominal_no_shader"
	if name.begins_with("Skin_"):return "other_visible_skin"
	if name.begins_with("Face_"):return "face_composed"
	return "wardrobe_or_accessory"

func _measure(person: String,outfit: String,sample: int,time: float) -> Dictionary:
	var rows: Array=[]; var groups: Dictionary={};var hidden: Array=[]
	for draw: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		if not draw.is_visible_in_tree():hidden.append(str(draw.name));continue
		var source:=draw.mesh as ArrayMesh
		if not _check(source!=null,"visible draw is ArrayMesh "+str(draw.name)):continue
		var morphs:=source.get_blend_shape_count()
		var weights: Dictionary={}
		for i: int in morphs:weights[str(source.get_blend_shape_name(i))]=draw.get_blend_shape_value(i)
		var baked: ArrayMesh=draw.bake_mesh_from_current_blend_shape_mix() if morphs>0 else source
		if draw.skin!=null:
			# Engine applies global bone pose * inverse bind to source vertices.
			# Require actual loader's mesh/skeleton identity alignment; never guess a correction.
			var skel:=draw.get_node_or_null(draw.skeleton) as Skeleton3D
			if not _check(skel!=null and skel==actor.skeleton,"actual shared skeleton "+str(draw.name)):continue
			if not _check((skel.global_transform.affine_inverse()*draw.global_transform).is_equal_approx(Transform3D.IDENTITY),"mesh/skeleton coordinates coincide "+str(draw.name)):continue
			baked=_morph_then_skin(draw)
		if not _check(baked!=null and baked.get_surface_count()==source.get_surface_count(),"bake preserves surfaces "+str(draw.name)):continue
		var vertices:=0;var bounds:=AABB();var first:=true
		var local:=actor.global_transform.affine_inverse()*draw.global_transform
		for surface: int in baked.get_surface_count():
			var points: PackedVector3Array=baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var original: PackedVector3Array=source.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			_check(points.size()==original.size(),"bake preserves vertex count "+str(draw.name))
			for point: Vector3 in points:
				point=local*point
				if not _check(point.is_finite(),"finite measured vertex"):continue
				if first:bounds=AABB(point,Vector3.ZERO);first=false
				else:bounds=bounds.expand(point)
				vertices+=1
		if not _check(not first,"nonempty measured draw"):continue
		var category:=_group(str(draw.name),morphs)
		groups[category]=bounds if not groups.has(category) else (groups[category] as AABB).merge(bounds)
		groups["all_visible_morph_skin_no_shader"]=bounds if not groups.has("all_visible_morph_skin_no_shader") else (groups.all_visible_morph_skin_no_shader as AABB).merge(bounds)
		rows.append({"name":str(draw.name),"group":category,"vertices":vertices,"bounds":_box(bounds),"morph_count":morphs,"applied_morph_weights":weights,"skinned":draw.skin!=null,"presentation":_draw_presentation(draw)})
	var packed: Dictionary={}
	for key: String in groups:packed[key]=_box(groups[key])
	return {"attention_observation":_attention_observation(),"resolved_case":current_case.duplicate(true),"person":person,"outfit":outfit,"parts":actor.worn_parts(),"sample":sample,"elapsed_s":time,"actor_position":_vec(actor.position),"floor_local_y":-actor.position.y,"hair_driver_transforms":_hair_driver_transforms(),"groups":packed,"draws":rows,"hidden_draws":hidden}

func _vec(v: Vector3) -> Array:return [v.x,v.y,v.z]
func _box(b: AABB) -> Dictionary:return {"min":_vec(b.position),"max":_vec(b.end),"size":_vec(b.size)}

func _finish() -> void:
	if is_instance_valid(grounding):grounding.actors.clear()
	if is_instance_valid(actor):actor.free()
	_check(not expected_samples.is_empty() and completed_samples==expected_samples,"every distinct ensemble completed exact sample count")
	if is_instance_valid(grounding):grounding.free()
	if lease:_check(RealityState.end_preview_campaign(self),"preview returned");lease=false
	if captured_state:
		_check(is_same(prior_data,RealityState.data) and JSON.stringify(RealityState.data,"",true,true)==prior_text,"original state identity and values restored")
		_check(_status()==prior_status,"original protection persistence and status restored")
		_check(_save_bundle()==prior_files,"save backup transaction bytes unchanged")
	_check(captured_stills.size()==expected_samples.size()*4,"four verified stills per completed ensemble")
	_check(inputs==_signature(),"bound source inputs unchanged")
	var file:=FileAccess.open(output.path_join("measurements.json"),FileAccess.WRITE)
	if file!=null:
		var report:=JSON.stringify({"evidence_class":"INERT diagnostic measurements", "inputs":inputs,"failures":failures,"scenarios":scenarios,"expected_samples":expected_samples,"completed_samples":completed_samples,"samples":records,"stills":captured_stills,"material_inventory":material_inventory,"uv_inventory":uv_inventory,"limits":"Morph plus skin at sampled attention and speech states. GPU displacement and alpha silhouette excluded from raw geometry; recorded shader data supports offline expansion. No complete pose envelope, fitted radius or accepted profile."},"\t")
		file.store_string(report)
		file.flush()
		_check(file.get_error()==OK,"report flush succeeded")
		file.close()
		_check(FileAccess.get_file_as_string(output.path_join("measurements.json"))==report,"report bytes read back exactly")
	else:failures.append("report write failed")
	get_tree().quit(0 if failures.is_empty() else 1)


## Synchronous snapshot: no await, no existing mesh/weights/skin assignment.
func _morph_then_skin(draw: MeshInstance3D) -> ArrayMesh:
	var source:=draw.mesh as ArrayMesh
	var original_ref:=draw.get_skin_reference()
	if not _check(original_ref!=null,"original registered SkinReference"):return null
	var morphed:=draw.bake_mesh_from_current_blend_shape_mix()
	if not _check(morphed!=null and morphed.get_surface_count()==source.get_surface_count(),"morph bake surface conservation"):return null
	for surface: int in source.get_surface_count():
		var a:=source.surface_get_arrays(surface)
		var b:=morphed.surface_get_arrays(surface)
		if not _check(a[Mesh.ARRAY_BONES]==b[Mesh.ARRAY_BONES] and a[Mesh.ARRAY_WEIGHTS]==b[Mesh.ARRAY_WEIGHTS],"morph retains exact full bone indices and weights"):return null
		var points: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array=a[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
		var stride:=8 if (source.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)!=0 else 4
		if not _check(bones.size()==points.size()*stride and weights.size()==bones.size(),"complete four/eight weight streams"):return null
		for vertex: int in points.size():
			var total:=0.0
			for slot: int in stride:
				var k:=vertex*stride+slot
				if not _check(is_finite(weights[k]) and weights[k]>=0.0 and bones[k]>=0 and bones[k]<draw.skin.get_bind_count(),"finite valid skin binding"):return null
				total+=weights[k]
			if not _check(absf(total-1.0)<0.001,"normalized original skin weights"):return null
	var helper:=MeshInstance3D.new()
	helper.name="MeasurementOnlyMorphSkin"
	helper.visible=false
	helper.mesh=morphed
	helper.skin=draw.skin
	helper.skeleton=draw.skeleton
	helper.transform=draw.transform
	draw.get_parent().add_child(helper)
	# Engine register_skin reuses the same ref for the same Skin object.
	# Require identity: a new pending skin would need a deferred update.
	var same:=is_same(helper.get_skin_reference(),original_ref) and helper.get_skin_reference().get_skeleton()==original_ref.get_skeleton()
	var aligned:=helper.global_transform.is_equal_approx(draw.global_transform) and helper.get_node_or_null(helper.skeleton)==draw.get_node_or_null(draw.skeleton)
	var result: ArrayMesh=null
	if _check(same and aligned,"helper shares live skin RID and exact space"):
		result=helper.bake_mesh_from_current_skeleton_pose()
	helper.free()
	_check(is_same(draw.mesh,source) and is_same(draw.get_skin_reference(),original_ref),"existing draw untouched")
	return result

func _synthetic_order_check() -> bool:
	var parent:=Node3D.new()
	parent.transform=Transform3D(Basis(Vector3.UP,.37),Vector3(1.7,.6,-.9))
	add_child(parent)
	var skeleton:=Skeleton3D.new();parent.add_child(skeleton)
	skeleton.add_bone("SyntheticRoot")
	skeleton.set_bone_rest(0,Transform3D.IDENTITY)
	var turn:=Basis(Vector3.FORWARD,PI/2.0)
	var shift:=Vector3(.3,.2,.1)
	skeleton.set_bone_pose_rotation(0,turn.get_rotation_quaternion())
	skeleton.set_bone_pose_position(0,shift)
	var skin:=Skin.new();skin.add_bind(0,Transform3D.IDENTITY)
	var original:=PackedVector3Array([Vector3(.2,.1,0),Vector3(.6,.1,0),Vector3(.2,.5,0)])
	var delta:=Vector3(.4,0,0)
	for mode: int in [Mesh.BLEND_SHAPE_MODE_RELATIVE,Mesh.BLEND_SHAPE_MODE_NORMALIZED]:
		var mesh:=ArrayMesh.new();mesh.set_blend_shape_mode(mode);mesh.add_blend_shape("KnownMorph")
		var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=original
		arrays[Mesh.ARRAY_BONES]=PackedInt32Array([0,0,0,0,0,0,0,0,0,0,0,0])
		arrays[Mesh.ARRAY_WEIGHTS]=PackedFloat32Array([1,0,0,0,1,0,0,0,1,0,0,0])
		var morph: Array=[];morph.resize(Mesh.ARRAY_MAX)
		var targets:=PackedVector3Array()
		for point: Vector3 in original:targets.append(point+delta if mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED else delta)
		morph[Mesh.ARRAY_VERTEX]=targets
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[morph])
		var draw:=MeshInstance3D.new();draw.mesh=mesh;draw.skin=skin;draw.skeleton=NodePath("..")
		skeleton.add_child(draw);draw.set_blend_shape_value(0,.5)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var baked:=_morph_then_skin(draw)
		if _check(baked!=null,"synthetic composed bake"):
			var points: PackedVector3Array=baked.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for i: int in original.size():
				var expected:=turn*(original[i]+delta*.5)+shift
				var wrong:=turn*original[i]+shift+delta*.5
				_check(points[i].distance_to(expected)<0.00001,"known morph before rotated translated bone")
				_check(points[i].distance_to(wrong)>.1,"fixture rejects reversed order")
				_check((draw.global_transform*points[i]).distance_to(parent.global_transform*expected)<0.00001,"known nonidentity parent world space")
		draw.free()
	parent.free()
	return failures.is_empty()


func _ensembles() -> Array:
	var rules:=Rules.new()
	if not _check(rules.load_table(),"production wardrobe rules loaded"):return []
	var calendar: Variant=JSON.parse_string(FileAccess.get_file_as_string(Rules.CALENDAR))
	if not _check(calendar is Dictionary,"authored temporal calendar loaded"):return []
	var dates: Dictionary={}
	for row: Dictionary in calendar.get("calendar",[]):
		dates[str(row.date)]="calendar:"+str(row.name)
	for key: String in calendar.get("anchors",{}):
		var row: Dictionary=calendar.anchors[key]
		if row.has("date"):dates[str(row.date)]="anchor_date:"+key
	var unique: Dictionary={}
	# Existing owner boundaries: previous evening until04:00, performance from18:00.
	# These are diagnostic queries of authored dates, never scheduled appointments.
	for date: String in dates:
		for minute: int in [0,239,240,960,1079,1080,1200,1439]:
			for person: String in ["stacy","lily"]:
				var situation: Dictionary=Owner.evening_situation(person,date,minute)
				var outfit: String=rules.choose(person,situation)
				var parts: Array=rules.parts_for(person,outfit,{},str(situation.date),situation).parts
				if not _check(not parts.is_empty(),"production rules resolve nonempty parts"):return []
				var makeup: String="stage" if outfit=="occasion" else ""
				var key:=person+"|"+outfit+"|"+JSON.stringify(parts)+"|"+makeup
				var row: Dictionary={"person":person,"input_date":date,"input_minute":minute,"date_source":dates[date],"situation":situation,"outfit":outfit,"parts":parts,"makeup":makeup,"ensemble_key":key}
				scenarios.append(row)
				if not unique.has(key):unique[key]=row
	# Current production named looks have only work and occasion reachable at bar.
	# Require witnessed coverage; do not manufacture an unreachable look.
	for person: String in ["stacy","lily"]:
		for look: String in ["work","occasion"]:
			var seen:=false
			for row: Dictionary in unique.values():seen=seen or (row.person==person and row.outfit==look)
			_check(seen,"authored calendar witnesses "+person+"/"+look)
	return unique.values()

func _status() -> Dictionary:
	return {"load":RealityState.load_status(),"notice":RealityState.player_notice(),"last_save":RealityState.last_save_result(),"blocked":RealityState.save_write_blocked,"version":RealityState.incompatible_save_version,"persistence":RealityState.persistence_enabled,"save_path":RealityState.save_path}

func _save_bundle() -> Dictionary:
	var out: Dictionary={}
	for suffix: String in ["", ".bak", ".txn", ".tmp"]:
		var path: String=RealityState.save_path+suffix
		out[suffix]={"exists":FileAccess.file_exists(path),"sha256":FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""}
	return out


func _check_makeup(person: String, expected: String) -> void:
	var heads: Array[Node]=actor.model.find_children("Skin_head","MeshInstance3D",true,false)
	if not _check(heads.size()==1,"one actual head for makeup inspection"):return
	var head:=heads[0] as MeshInstance3D
	if expected.is_empty():
		_check(head.material_overlay==null,"work head has no makeup overlay")
		return
	var paint:=head.material_overlay as StandardMaterial3D
	if not _check(paint!=null,"selected makeup actually applied"):return
	var path: String="res://assets/characters/%s/%s_makeup_%s.png" % [person,person,expected]
	_check(paint.resource_name=="makeup_"+expected,"actual makeup material identity")
	_check(paint.albedo_texture!=null and paint.albedo_texture.resource_path==path,"actual makeup texture matches selected case")


func _transform_record(t: Transform3D) -> Dictionary:
	return {"origin":_vec(t.origin),"basis_columns":[_vec(t.basis.x),_vec(t.basis.y),_vec(t.basis.z)]}

func _draw_presentation(draw: MeshInstance3D) -> Dictionary:
	var surface_materials: Array=[]
	for surface: int in draw.mesh.get_surface_count():
		var uv_key:=str(draw.mesh.get_instance_id())+":"+str(surface)
		if not uv_inventory.has(uv_key):
			var arrays:=draw.mesh.surface_get_arrays(surface)
			var uv_row: Dictionary={"mesh_path":draw.mesh.resource_path,"surface":surface}
			for channel: int in [Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
				var values: Variant=arrays[channel]
				var label: String="uv0_y" if channel==Mesh.ARRAY_TEX_UV else "uv2_y"
				if values is PackedVector2Array and not values.is_empty():
					var low:=INF;var high:=-INF
					for v: Vector2 in values:low=minf(low,v.y);high=maxf(high,v.y)
					uv_row[label]={"min":low,"max":high,"count":values.size()}
				else:uv_row[label]={"missing":true}
			uv_inventory[uv_key]=uv_row
		surface_materials.append({"surface":surface,"uv_key":uv_key,"active":_material_chain(draw.get_active_material(surface)),"surface_override_id":_material_id(draw.get_surface_override_material(surface))})
	var skel:=draw.get_node_or_null(draw.skeleton) as Skeleton3D
	return {"global_transform":_transform_record(draw.global_transform),"actor_global_transform":_transform_record(actor.global_transform),"draw_to_actor":_transform_record(actor.global_transform.affine_inverse()*draw.global_transform),"skeleton_relative":_transform_record(skel.global_transform.affine_inverse()*draw.global_transform) if skel!=null else null,"skeleton_path":str(draw.skeleton),"skin_id":draw.skin.get_instance_id() if draw.skin!=null else 0,"override":_material_chain(draw.material_override),"overlay":_material_chain(draw.material_overlay),"surfaces":surface_materials}

func _material_id(material: Material) -> String:
	return str(material.get_instance_id()) if material!=null else ""

func _material_chain(material: Material) -> Array:
	var result: Array=[];var seen: Dictionary={}
	while material!=null:
		var key:=_material_id(material)
		if not _check(not seen.has(key),"acyclic observed material passes"):break
		seen[key]=true
		var shader_material:=material as ShaderMaterial
		var shader: Shader=shader_material.shader if shader_material!=null else null
		var shader_path: String=shader.resource_path if shader!=null else ""
		var parameters: Array[String]=[]
		if shader_path=="res://shaders/character_hair.gdshader":parameters.assign(["is_cap","sway","breeze"])
		elif shader_path=="res://shaders/stage_wisps.gdshader":parameters.assign(["sway_amplitude","sway_speed"])
		if not material_inventory.has(key):
			material_inventory[key]={"class":material.get_class(),"name":material.resource_name,"path":material.resource_path,"shader_path":shader_path,"shader_code_sha256":shader.code.replace("\r\n","\n").sha256_text() if shader!=null else "","motion_class":"observed_relevant_shader" if not parameters.is_empty() else ("unknown_shader_not_bounded" if shader!=null else "standard_or_other_material"),"next_pass_id":_material_id(material.next_pass)}
		if material is BaseMaterial3D:
			var standard:=material as BaseMaterial3D
			material_inventory[key]["grow"]=standard.grow
			material_inventory[key]["grow_amount"]=standard.grow_amount
		var values: Dictionary={}
		for parameter: String in parameters:
			var explicit: Variant=shader_material.get_shader_parameter(parameter)
			var fallback: Variant=RenderingServer.shader_get_parameter_default(shader.get_rid(),parameter)
			var effective: Variant=fallback if explicit==null else explicit
			_check(effective!=null,"effective displacement parameter resolved "+parameter)
			values[parameter]={"value":_parameter_value(effective),"origin":"shader_default" if explicit==null else "material_parameter","default":_parameter_value(fallback)}
		result.append({"material_id":key,"motion_parameters":values})
		material=material.next_pass
	return result

func _parameter_value(value: Variant) -> Variant:
	if value is Vector3:return _vec(value)
	if value==null or value is bool or value is float or value is int:return value
	_check(false,"unexpected motion parameter type")
	return str(value)


func _hair_driver_transforms() -> Array:
	var result: Array=[]
	for draw: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		if str(draw.name) not in ["Hair","HatHair"]:continue
		result.append({"name":str(draw.name),"visible":draw.is_visible_in_tree(),"global_transform":_transform_record(draw.global_transform),"draw_to_actor":_transform_record(actor.global_transform.affine_inverse()*draw.global_transform)})
	return result


func _attention_stages() -> Array:
	var pipeline: Node=actor.attention.pipeline
	var profile: RefCounted=pipeline.profile
	var up: Vector3=profile.up
	var forward: Vector3=pipeline.last_chest_forward
	forward=(forward-up*forward.dot(up)).normalized()
	var left:=up.cross(forward).normalized()
	var eye: Vector3=pipeline.eye_world()
	var basis: Basis=actor.skeleton.global_basis.orthonormalized()
	var result: Array=[{"name":"camera_front_speech","target":eye+basis*forward*2.0,"staged":false,"conversing":true}]
	for signs: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var yaw: float=signs.x*(float(profile.gaze_yaw)+deg_to_rad(12.0))
		var pitch: float=signs.y*(float(profile.gaze_pitch)+deg_to_rad(8.0))
		var direction: Vector3=(forward*cos(yaw)+left*sin(yaw))*cos(pitch)+up*sin(pitch)
		result.append({"name":"corner_%s_%s" % [int(signs.x),int(signs.y)],"target":eye+basis*direction*2.0,"staged":true,"conversing":true,"requested_yaw_rad":yaw,"requested_pitch_rad":pitch})
	result.append({"name":"rear_camera","target":eye-basis*forward*2.0,"staged":false,"conversing":true})
	result.append({"name":"distant_release","target":eye+basis*forward*8.0,"staged":false,"conversing":false})
	result.append({"name":"camera_return","target":eye+basis*forward*2.0,"staged":false,"conversing":true})
	return result

func _begin_attention_stage(index: int,person: String) -> void:
	attention_case=attention_plan[index].duplicate(true)
	var target: Vector3=attention_case.target
	var camera: Camera3D=get_viewport().get_camera_3d()
	if not _check(camera!=null,"real attention camera present"):return
	camera.global_position=target
	camera.look_at(actor.attention.pipeline.eye_world(),Vector3.UP)
	actor.attention.staged_target=target if bool(attention_case.staged) else null
	# Use actual owner's conversation transitions; don't write pipeline bones/weights.
	if index==0 or index==7:actor.attention._on_conversation_started(person,"diagnostic_articulation")
	elif index==6:actor.attention._on_conversation_ended(person)
	if not bool(attention_case.conversing):actor.stop_speaking();return
	var face_data: Variant=JSON.parse_string(FileAccess.get_file_as_string(actor.face.DATA))
	if not _check(face_data is Dictionary and face_data.has("mouth_shapes"),"authored mouth shapes available"):return
	if not _check(face_data.mouth_shapes is Array,"authored mouth shapes are rows"):return
	var values: Array=[]
	for row: Dictionary in face_data.mouth_shapes:
		if not _check(row.has("letter") and row.has("shapes"),"valid authored mouth shape row"):return
		values.append(str(row.letter))
	if not _check(not values.is_empty(),"nonempty supported mouth shapes"):return
	values.sort()
	var cues: Array=[]
	# Diagnostic timings select supported authored shapes, not invented dialogue.
	for i: int in values.size():
		cues.append({"start":float(i)*8.0/values.size(),"end":float(i+1)*8.0/values.size(),"value":str(values[i])})
	attention_case.cues=cues
	if index in [0,7]:
		attention_case.speech_mode="untimed_owner_fallback"
		actor.speak_untimed(8.0)
	else:
		attention_case.speech_mode="supported_cue_probe"
		actor.speak_cues(cues)

func _attention_observation() -> Dictionary:
	var attention: Node=actor.attention
	var pipeline: Node=attention.pipeline
	var up: Vector3=pipeline.profile.up
	var forward: Vector3=modified_pose.get("chest_forward",pipeline.last_chest_forward)
	forward=(forward-up*forward.dot(up)).normalized()
	var left:=up.cross(forward).normalized()
	var achieved: Vector3=modified_pose.get("facing",Vector3.ZERO)
	_check(not modified_pose.is_empty() and int(modified_pose.get("pipeline_frames",-1))==int(pipeline.frames),"observed actual modified skeleton phase matches sampled skin frame")
	var flat:=Vector2(achieved.dot(forward),achieved.dot(left))
	var context:=attention_case.duplicate(true)
	if context.get("target") is Vector3:context.target=_vec(context.target)
	return {"case":context,"camera_global":_vec(get_viewport().get_camera_3d().global_position),"conversing":attention.conversing,"looking":attention.is_looking(),"pipeline_attending":pipeline.attending(),"gaze_weight":pipeline.gaze_weight(),"pipeline_frames":pipeline.frames,"modified_pose_serial":modified_pose.get("serial",-1),"observer_phase":"Skeleton3D.skeleton_updated after modifiers before skin upload and CPU restore","pipeline_last_facing":_vec(pipeline.last_facing),"refused_writes":pipeline.refused_writes,"head_facing_skeleton":_vec(achieved),"chest_forward_skeleton":_vec(forward),"achieved_yaw_rad":atan2(flat.y,flat.x),"achieved_pitch_rad":atan2(achieved.dot(up),maxf(flat.length(),.0001)),"profile_yaw_rad":pipeline.profile.gaze_yaw,"profile_pitch_rad":pipeline.profile.gaze_pitch,"eye_world":_vec(pipeline.eye_world()),"face_bound":actor.face.bound,"face_writes_last_frame":actor.face.writes_last_frame,"speech_clock":actor.face._speech_clock,"speech_ends":actor.face._speech_ends,"eye_goal_degrees":[actor.face._eye_goal.x,actor.face._eye_goal.y]}


func _capture_views(person: String,outfit: String) -> void:
	var bounds:=AABB();var first:=true
	for row: Dictionary in records:
		if row.person!=person or row.outfit!=outfit:continue
		var b: Dictionary=row.groups.all_visible_morph_skin_no_shader
		var low:=Vector3(b.min[0],b.min[1],b.min[2])
		var high:=Vector3(b.max[0],b.max[1],b.max[2])
		var box:=AABB(low,high-low)
		bounds=box if first else bounds.merge(box);first=false
	if not _check(not first,"measured geometry available for still framing"):return
	var camera: Camera3D=get_viewport().get_camera_3d()
	get_window().size=Vector2i(1280,720)
	get_window().content_scale_size=Vector2i(1280,720)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	var center:=actor.global_transform*bounds.get_center()
	var forward: Vector3=actor.skeleton.global_basis.orthonormalized()*actor.attention.pipeline.profile.forward
	var up:=Vector3.UP
	forward=(forward-up*forward.dot(up)).normalized()
	var side:=up.cross(forward).normalized()
	var views: Dictionary={"front":forward,"side":side,"three_quarter":(forward+side).normalized(),"back":-forward}
	for label: String in views:
		actor.attention.staged_target=null
		camera.global_position=center+views[label]*3.5
		camera.look_at(center,up)
		var projected:=AABB();var first_corner:=true
		for i: int in 8:
			var point:=camera.global_transform.affine_inverse()*(actor.global_transform*bounds.get_endpoint(i))
			projected=AABB(point,Vector3.ZERO) if first_corner else projected.expand(point);first_corner=false
		camera.size=maxf(projected.size.y,projected.size.x/(1280.0/720.0))*1.25
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image:=get_viewport().get_texture().get_image()
		if not _check(image!=null and image.get_size()==Vector2i(1280,720),"actual1280x720 still"):continue
		var path:=output.path_join(person+"_"+outfit+"_"+label+".png")
		if not _check(image.save_png(path)==OK,"still written "+label):continue
		var reloaded:=Image.load_from_file(path)
		_check(reloaded!=null and reloaded.get_size()==Vector2i(1280,720),"still dimensions read back")
		captured_stills.append({"person":person,"outfit":outfit,"view":label,"path":path,"sha256":FileAccess.get_sha256(path),"camera":_transform_record(camera.global_transform),"orthographic_size":camera.size,"measured_nominal_frame":_box(bounds),"note":"Live pose at capture; shader displacement not included in measured framing box."})


func _check_attention_coverage(person: String,outfit: String) -> void:
	var corners: Dictionary={};var jaw_seen:=false;var release_seen:=false;var return_seen:=false
	for row: Dictionary in records:
		if row.person!=person or row.outfit!=outfit:continue
		var observed: Dictionary=row.attention_observation
		var label: String=observed.case.name
		_check(int(observed.refused_writes)==0,"actual pose pipeline has no refused writers")
		if label.begins_with("corner_") and bool(observed.looking) and float(observed.gaze_weight)>.8:
			var yaw_sign:=signf(float(observed.case.requested_yaw_rad))
			var pitch_sign:=signf(float(observed.case.requested_pitch_rad))
			if float(observed.achieved_yaw_rad)*yaw_sign>=float(observed.profile_yaw_rad)*.7 and float(observed.achieved_pitch_rad)*pitch_sign>=float(observed.profile_pitch_rad)*.7:corners[label]=true
		if label=="distant_release" and not bool(observed.pipeline_attending) and float(observed.gaze_weight)<.2:release_seen=true
		if label=="camera_return" and bool(observed.looking) and float(observed.gaze_weight)>.8:return_seen=true
		if str(observed.case.get("speech_mode",""))=="untimed_owner_fallback":
			for draw: Dictionary in row.draws:
				var weights: Dictionary=draw.applied_morph_weights
				if float(weights.get("jawOpen",0.0))>.01:jaw_seen=true
	_check(corners.size()==4,"all four actual corner regions observed at >=70percent profile yaw/pitch with active gaze")
	_check(jaw_seen,"actual jawOpen observed during owner untimed speech fallback")
	_check(release_seen and return_seen,"actual gaze releases and reacquires after distant camera transition")


func _capture_modified_pose() -> void:
	if not is_instance_valid(actor) or actor.attention==null:return
	var pipeline: Node=actor.attention.pipeline
	modified_pose_serial+=1
	modified_pose={"facing":pipeline.head_facing().normalized(),"chest_forward":pipeline.last_chest_forward,"pipeline_frames":pipeline.frames,"serial":modified_pose_serial}

func _await_stage_observation() -> void:
	var deadline:=Time.get_ticks_msec()+2500
	while Time.get_ticks_msec()<deadline:
		var o:=_attention_observation()
		var name: String=attention_case.name
		var ready:=true
		if name.begins_with("corner_"):
			ready=bool(o.looking) and float(o.gaze_weight)>.8 and float(o.achieved_yaw_rad)*signf(float(attention_case.requested_yaw_rad))>=float(o.profile_yaw_rad)*.7 and float(o.achieved_pitch_rad)*signf(float(attention_case.requested_pitch_rad))>=float(o.profile_pitch_rad)*.7
		elif name=="camera_return":ready=bool(o.looking) and float(o.gaze_weight)>.8
		elif name=="distant_release":ready=not bool(o.pipeline_attending) and float(o.gaze_weight)<.2
		if ready:return
		await get_tree().create_timer(.05).timeout
		await RenderingServer.frame_post_draw
	_check(false,"actual attention did not satisfy unchanged stage coverage within extra2.5s: "+str(attention_case.name))
