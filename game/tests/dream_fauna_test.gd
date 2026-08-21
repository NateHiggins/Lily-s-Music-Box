extends Node
## OWNER AMENDMENT 2026-08-20: FA-V1's historical no-bitmap rule is
## superseded for future dream substance plates. This suite continues to prove
## that procedural channels own regions, semantics and danger readability; it
## deliberately does not treat sampler2D presence as a failure. Future plates
## must be static, case-selected fills beneath these same authoritative masks.
const PRODUCTION_MESH_SHA256 := {
	"GildersButtons": "a7eaadef2d0b911b903fbd8241887342c419852cea5c6cc6fd0e7ad0367045c4",
	"Tessellates": "6f0ead38a951b6021bf4f88cbbadef180d3eb15bece791002611a1a32cc006e0",
	"WineAnemones": "a7c49555665e629f4ab9c4622f21c2b9fc1d1c45b25be0a235d6a7ba45691470",
	"Ribbonettes": "ddbfe1fee97a0f6d9aeb88672dd1795526db1baa009a90079ff6392ffc3b4513",
	"TheLoupe": "1268785614f7998c9712d3ec202e64e23fa98b2a1ec7938aeaebda8c818ac201",
}
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
	var production_parts := {
		"GildersButtons": DreamFaunaParts.buttons(),
		"Tessellates": DreamFaunaParts.tessellates(),
		"WineAnemones": DreamFaunaParts.anemones(),
		"Ribbonettes": DreamFaunaParts.ribbonettes(),
		"TheLoupe": DreamFaunaParts.loupe(),
	}
	var production_parts_ok := true
	for family_name in production_parts:
		var part := production_parts[family_name] as ArrayMesh
		var batch := fauna.get_node(family_name) as MultiMeshInstance3D
		var part_format := part.surface_get_format(0)
		var signature := DreamFaunaParts.mesh_signature(part)
		production_parts_ok = production_parts_ok and batch.multimesh.mesh == part \
				and part.get_surface_count() == 1 \
				and part.get_faces().size() / 3 < DreamFaunaParts.TRIANGLE_CEILING \
				and (part_format & Mesh.ARRAY_FORMAT_COLOR) != 0 \
				and (part_format & Mesh.ARRAY_FORMAT_CUSTOM0) != 0 \
				and signature == PRODUCTION_MESH_SHA256[family_name]
		if family_name == "TheLoupe":
			var loupe_regions := {}
			for vertex_color in part.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
				var region := roundi(vertex_color.r * 7.0)
				loupe_regions[region] = int(loupe_regions.get(region, 0)) + 1
			production_parts_ok = production_parts_ok \
					and loupe_regions.has(0) and loupe_regions.has(1) \
					and loupe_regions.has(2) and loupe_regions.has(4) \
					and loupe_regions.has(5) and loupe_regions.has(6)
			print("[DREAM FAUNA PARTS] Loupe regions="+str(loupe_regions))
		print("[DREAM FAUNA PARTS] %s=%s triangles=%d" % [
				family_name, signature, part.get_faces().size() / 3])
	_check("all five cached production kits are bounded attributed surfaces",
			production_parts_ok)
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
	# FA-V4: collision-free inspection reads the director's own submission
	# record (the headless renderer's buffer readback is identity/default, so
	# the renderer is deliberately not the source here).
	var nodes_before:int=fauna.find_children("*","",true,false).size()
	var inspect_signature:String=fauna.realization_signature()
	var inspect_plan:=var_to_bytes(root.plan)
	var seed_room:Dictionary=root.rooms.live_rooms()[0]; var sr:Array=seed_room.rect
	var seed_centre:=Vector3((sr[0]+sr[2])*0.5,0.0,(sr[1]+sr[3])*0.5)
	var target_report:Dictionary=fauna.nearest_to(seed_centre,"Tessellates")
	var target:Vector3=target_report.get("position",Vector3.ZERO)
	var eye:=target+Vector3(0.0,1.2,2.4)
	var report:Dictionary=fauna.inspect_ray(eye,target-eye,40.0)
	var again:Dictionary=fauna.inspect_ray(eye,target-eye,40.0)
	var recorded_rows:Dictionary=fauna.get("_records").get("Tessellates",{})
	var recorded_raw:Color=(recorded_rows.custom as Array)[int(target_report.get("index",0))] \
			if not recorded_rows.is_empty() else Color()
	_check("F inspection selects the aimed grazer analytically",
			not target_report.is_empty() and not report.is_empty()
			and str(report.batch)=="Tessellates"
			and int(report.index)==int(target_report.index)
			and int(report.family_motif)==1
			and str(report.family).begins_with("Tessellate")
			and float(report.miss)<0.001 and absf(float(report.distance)-eye.distance_to(target))<0.001)
	_check("inspection reports that instance's exact packed genome",
			not report.is_empty() and report.custom_raw==recorded_raw
			and report.channels==DreamFaunaChannels.decode(recorded_raw)
			and report.flags is PackedStringArray
			and report.has("shader_compiled")
			and str(report.shader).ends_with("dream_fauna.gdshader")
			and float(report.material.gait_hz)==1.8
			and int(report.cast_shadow)==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and DreamFaunaDirector.inspection_text(report).begins_with("FAUNA Tessellate")
			and DreamFaunaDirector.inspection_text(report).contains("compiled "))
	_check("inspection is deterministic and names the live room and density",
			report==again and not str(report.get("room_key","")).is_empty()
			and (report.get("density",{}) as Dictionary).has("grazer")
			and str(fauna.nearest_to(target).batch)=="Tessellates"
			and int(fauna.nearest_to(target).index)==int(target_report.index)
			and report.has("gpu_custom"))
	# The Compatibility renderer's half-float truncation keeps every high byte
	# and quantizes the low byte; the model below is what the windowed probe
	# measures against the real buffer.
	var half_ok:=DreamFaunaChannels.compatibility_half(45276.0)==45248.0 \
			and DreamFaunaChannels.compatibility_half(16448.0)==16448.0 \
			and DreamFaunaChannels.compatibility_half(0.0)==0.0 \
			and absf(DreamFaunaChannels.compatibility_half(0.5033)-0.50292968)<1e-6
	for high in 256:
		for low in [0,1,15,16,127,255]:
			var seen:=DreamFaunaChannels.unpack_pair(
					DreamFaunaChannels.compatibility_half(
					DreamFaunaChannels.pack_pair(high,low)))
			half_ok=half_ok and seen.x==high and seen.y<=low
	_check("half-float truncation preserves every packed high byte",half_ok)
	_check("inspection names nothing outside the cone or past the reach",
			fauna.inspect_ray(Vector3(0.0,80.0,0.0),Vector3.UP,40.0).is_empty()
			and fauna.inspect_ray(eye,target-eye,0.5).is_empty()
			and fauna.inspect_ray(eye,Vector3.ZERO,40.0).is_empty())
	var inspect_forbidden:=0
	for node in fauna.find_children("*","",true,false):
		if node is CollisionObject3D or node is Light3D: inspect_forbidden+=1
	_check("inspection adds no node, collision, light or mutation",
			fauna.find_children("*","",true,false).size()==nodes_before
			and inspect_forbidden==0
			and inspect_signature==fauna.realization_signature()
			and inspect_plan==var_to_bytes(root.plan)
			and DreamFaunaChannels.flag_names(DreamFaunaChannels.FLAG_HUSH
					|DreamFaunaChannels.FLAG_CAMERA_TRACKER)
					==PackedStringArray(["HUSH","CAMERA_TRACKER"]))
	# Buttons never set gold_gain on their material; the report must still
	# render every line rather than abort on the unset uniform.
	var button_report:Dictionary=fauna.nearest_to(target,"GildersButtons")
	var button_text:String=DreamFaunaDirector.inspection_text(button_report)
	print("[DREAM FAUNA FA4] "+button_text.replace("\n","\n[DREAM FAUNA FA4] "))
	_check("inspection survives a batch whose material left a uniform unset",
			str(button_report.get("batch",""))=="GildersButtons"
			and button_text.begins_with("FAUNA Gilder's Button")
			and button_text.contains("gold_gain ")
			and button_text.contains("flags [PEARL_COLONY]")
			and DreamFaunaDirector.inspection_text({})
					=="fauna: none under the crosshair")
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
