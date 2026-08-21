extends Node
const TESSELLATES_MESH_SHA256 := "37406ea797a95c3d3929416834a704b3049b7aa2628066594732197560b3bf3e"
var checks:=0; var failures:=0
func _ready()->void:
	call_deferred("_run")
func _run()->void:
	RealityState.persistence_enabled=false; RealityState.reset_campaign_for_tests()
	var root = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous=false; root.configure_dream({"case_id":"mina_caption_crisis","profile_id":"mina_release_print","window":{},"seed_hex":"f123456789abcdef","maze_revision":1,"outcome":"","night_index":1,"spawn_anchor":1})
	add_child(root); await get_tree().process_frame
	root.set_physics_process(false)
	var fauna=root.fauna; fauna.set_physics_process(false); fauna.refresh()
	var first:Dictionary=fauna.census()
	var plan_before:=var_to_bytes(root.plan); var save_before:=var_to_bytes(RealityState.data)
	var hazard_before:=_hazard_signature(root.hazards); var exposure_before:float=root.exposure.sample(root.player.global_position)
	var realization_before:String=fauna.realization_signature()
	fauna.refresh(); var second:Dictionary=fauna.census()
	var family_batches:Array[Node]=fauna.find_children(
			"*","MultiMeshInstance3D",false,false)
	_check("one presentation owner builds all five ruled families",
			family_batches.size()==5 and first==second)
	_check("the ruled pocket cap holds", _total(first)<=96)
	var forbidden:=0
	for node in fauna.find_children("*","",true,false):
		if node is CollisionObject3D or node is Light3D: forbidden+=1
	_check("fauna own no collision or light", forbidden==0)
	var tess=fauna.get_node("Tessellates") as MultiMeshInstance3D
	var all_shadowless:=true
	for batch in family_batches:
		var family := batch as MultiMeshInstance3D
		all_shadowless=all_shadowless and family!=null \
				and family.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_check("every family is one shadowless batch",tess!=null and all_shadowless)
	var binding_count:=0; var molten_count:=0; var lamp_bound:=true
	root.call("_collect_molten_materials"); root.call("_update_molten")
	var molten:Array=root.get("_molten_materials")
	for batch in family_batches:
		var family := batch as MultiMeshInstance3D
		var material:ShaderMaterial=family.multimesh.mesh.surface_get_material(0)
		if material!=null:
			binding_count+=1
			if molten.has(material): molten_count+=1
			lamp_bound=lamp_bound and float(material.get_shader_parameter("lamp_energy"))>0.0
	var bindings:=fauna.get_node("FaunaMaterialBindings") as Node3D
	var bindings_zero_draw:=bindings!=null and bindings.get_child_count()==5
	if bindings!=null:
		for child in bindings.get_children():
			bindings_zero_draw=bindings_zero_draw and child is MeshInstance3D \
					and (child as MeshInstance3D).mesh==null and not child.visible
	_check("five zero-draw bindings cross the existing molten owner boundary",
			binding_count==5 and molten_count==5 and lamp_bound and bindings_zero_draw)
	var production_shader:Shader=load("res://shaders/dream_fauna.gdshader")
	_check("production fauna shader owns no emission or PBR writes",
			production_shader!=null and not production_shader.code.contains("EMISSION") \
			and not production_shader.code.contains("METALLIC") \
			and not production_shader.code.contains("ROUGHNESS"))
	var channels_ok:=true
	for high in [0,1,127,255]:
		for low in [0,1,127,255]:
			var pair:=DreamFaunaChannels.unpack_pair(
					DreamFaunaChannels.pack_pair(high,low))
			channels_ok=channels_ok and pair==Vector2i(high,low)
	var encoded:=DreamFaunaChannels.encode(0.375,1.0,0.0,
			DreamFaunaChannels.FLAG_HUSH|DreamFaunaChannels.FLAG_CAMERA_TRACKER,
			0.5,0.25,0.75)
	var decoded:=DreamFaunaChannels.decode(encoded)
	channels_ok=channels_ok and is_equal_approx(float(decoded.identity_phase),0.375) \
			and int(decoded.flags)==9 \
			and absf(float(decoded.activity)-0.5)<0.003 \
			and DreamFaunaChannels.has_flag(encoded,DreamFaunaChannels.FLAG_HUSH)
	_check("packed fauna channels round-trip byte boundaries and flags",channels_ok)
	var tess_mesh:=DreamFaunaParts.tessellates()
	var tess_format:=tess_mesh.surface_get_format(0)
	var tess_sig:=DreamFaunaParts.mesh_signature(tess_mesh)
	_check("cached Tessellates part kit is one bounded attributed surface",
			tess.multimesh.mesh==tess_mesh and DreamFaunaParts.tessellates()==tess_mesh \
			and tess_mesh.get_surface_count()==1 \
			and tess_mesh.get_faces().size()/3<DreamFaunaParts.TRIANGLE_CEILING \
			and (tess_format&Mesh.ARRAY_FORMAT_COLOR)!=0 \
			and (tess_format&Mesh.ARRAY_FORMAT_CUSTOM0)!=0 \
			and tess_sig==TESSELLATES_MESH_SHA256)
	print("[DREAM FAUNA PARTS] tessellates="+tess_sig)
	var kit_samples:Array[ArrayMesh]=[
		DreamFaunaParts.lathe(PackedVector2Array([
				Vector2(0.04,0.0),Vector2(0.08,0.1),Vector2(0.02,0.2)]),8),
		DreamFaunaParts.sweep(PackedVector3Array([
				Vector3.ZERO,Vector3(0.0,0.1,0.1),Vector3(0.1,0.2,0.15)]),
				PackedFloat32Array([0.03,0.04,0.02]),6),
		DreamFaunaParts.ribbon(PackedVector3Array([
				Vector3.ZERO,Vector3(0.1,0.02,0.1),Vector3(0.2,0.0,0.2)])),
		DreamFaunaParts.bead_chain(PackedVector3Array([
				Vector3.ZERO,Vector3(0.08,0.0,0.0)])),
		DreamFaunaParts.aperture_sweep(PackedVector3Array([
				Vector3(-0.1,0.0,0.0),Vector3(0.0,0.1,0.0),
				Vector3(0.1,0.0,0.0),Vector3(0.0,-0.1,0.0)])),
		DreamFaunaParts.gem(),
	]
	kit_samples.append(DreamFaunaParts.assemble([kit_samples[0],kit_samples[5]]))
	var kit_ok:=true
	for sample in kit_samples:
		kit_ok=kit_ok and sample!=null and sample.get_surface_count()==1 \
				and (sample.surface_get_format(0)&Mesh.ARRAY_FORMAT_COLOR)!=0 \
				and (sample.surface_get_format(0)&Mesh.ARRAY_FORMAT_CUSTOM0)!=0
	_check("every ruled procedural part path emits one attributed surface",kit_ok)
	var buttons:=fauna.get_node("GildersButtons") as MultiMeshInstance3D
	var excluded_portal_layer:=1<<19
	var all_in_shared_world:=true
	for batch in family_batches:
		var family := batch as MultiMeshInstance3D
		all_in_shared_world=all_in_shared_world and (family.layers&1)!=0 \
				and (family.layers&excluded_portal_layer)==0
	_check("all five families remain visible through the shared R6 world",
			buttons!=null and tess!=null and all_in_shared_world)
	_check("refresh is byte-stable for plan, hazards, exposure and save",
			plan_before==var_to_bytes(root.plan) and save_before==var_to_bytes(RealityState.data)
			and hazard_before==_hazard_signature(root.hazards)
			and exposure_before==root.exposure.sample(root.player.global_position))
	_check("the same pocket realizes the same deterministic slots",
			realization_before==fauna.realization_signature())
	var birth_frames:=0
	for body in get_tree().get_nodes_in_group("dream_lineage_bodies"):
		birth_frames+=(body.get_meta("birth_frames",[]) as Array).size()
	_check("lineage bodies publish real birth-frame anchors",birth_frames>0)
	var densities:Dictionary=fauna.density_snapshot(); var four_values:=true
	for state in densities.values():
		four_values=four_values and state.has("nutrient") and state.has("grazer") \
				and state.has("predator") and state.has("detritus") \
				and float(state.predator)==0.0
	_check("the 3 Hz owner carries four bounded harmless densities",four_values)
	var trophic_plan:=var_to_bytes(root.plan); var trophic_hazards:=_hazard_signature(root.hazards)
	var feed_room:Dictionary=root.rooms.live_rooms()[0]; var fr:Array=feed_room.rect
	root.player.global_position=Vector3((fr[0]+fr[2])*0.5,0.0,(fr[1]+fr[3])*0.5)
	for _i in 14: fauna.advance_fixed()
	fauna.refresh(); var trophic:Dictionary=fauna.census()
	var predator_live:=false
	for state in fauna.density_snapshot().values(): predator_live=predator_live or float(state.predator)>0.0
	_check("crop, grazers, courtship, detritivores and one Loupe close the loop",
			int(trophic.buttons)>0 and int(trophic.tessellates)>0
			and int(trophic.anemones)>0 and int(trophic.ribbonettes)>0
			and int(trophic.loupe)==1 and predator_live and _total(trophic)<=96)
	_check("the harmless trophic tick cannot mutate plan or hazards",
			trophic_plan==var_to_bytes(root.plan)
			and trophic_hazards==_hazard_signature(root.hazards))
	var fed_count:=int(fauna.census().tessellates); var old_pos:Vector3=root.player.global_position
	root.player.global_position=Vector3(999.0,0.0,999.0)
	for live_room in root.rooms.live_rooms():
		root.exposure.clear_room(str(live_room.get("key","")))
	for _i in 12: fauna.advance_fixed()
	fauna.refresh(); root.player.global_position=old_pos
	_check("unfed grazer density dies back into the bounded record",
			int(fauna.census().tessellates)<fed_count)
	var architecture:=root.get("_architecture") as Node3D
	var revisit:=PackedInt32Array([2,3,1,2,0,3])
	var elsewhere:=PackedInt32Array([1,0,3,2,1,0,2])
	root.rooms.advance(architecture,revisit); await get_tree().process_frame; fauna.refresh()
	var revisit_key:=DreamRoomBuilder.key_of(revisit)
	var revisit_signature:String=fauna.room_signature(revisit_key)
	root.rooms.advance(architecture,elsewhere); await get_tree().process_frame; fauna.refresh()
	_check("forgotten rooms retain no fauna record",
			root.rooms.room_at_key(revisit_key).is_empty()
			and not fauna.realization_signature().is_empty())
	root.rooms.advance(architecture,revisit); await get_tree().process_frame; fauna.refresh()
	_check("a forgotten pocket re-derives identical fauna",
			not revisit_signature.is_empty()
			and revisit_signature==fauna.room_signature(revisit_key))
	# Put her at a live room's centre, rather than assuming the player's spawn
	# lies within the director's centre-based hush radius.
	var hush_room:Dictionary=root.rooms.live_rooms()[0]; var hr:Array=hush_room.rect
	root.pursuer.global_position=Vector3((hr[0]+hr[2])*0.5,0.0,(hr[1]+hr[3])*0.5); fauna.refresh()
	await get_tree().process_frame
	_check("the Tenant hush submerges nearby grazers",
			int(fauna.census().hushed)>0 and int(fauna.census().submerged)>0)
	fauna.freeze_for_capture()
	_check("capture freezes and hides the ecosystem", fauna.frozen and not tess.visible)
	print("DREAM FAUNA TEST: %s (%d/%d)"%["PASS" if failures==0 else "FAIL",checks-failures,checks]); get_tree().quit(failures)
func _hazard_signature(field:DreamHazardField)->String:
	var rows:Array[String]=[]
	for hazard in field.hazards:
		rows.append("%s:%s:%s:%s"%[hazard.id,hazard.tell_started_s,hazard.contacted,hazard.contact_s])
	return "|".join(rows)
func _total(c:Dictionary)->int:
	return int(c.buttons)+int(c.tessellates)+int(c.anemones)+int(c.ribbonettes)+int(c.loupe)
func _check(label:String,ok:bool)->void:
	checks+=1
	if not ok: failures+=1; printerr("[FAUNA FAIL] "+label)
	else: print("[fauna ok] "+label)
