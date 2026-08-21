extends Node
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
	_check("one presentation owner builds all five ruled families", fauna.get_child_count()==5 and first==second)
	_check("the ruled pocket cap holds", _total(first)<=96)
	var forbidden:=0
	for node in fauna.find_children("*","",true,false):
		if node is CollisionObject3D or node is Light3D: forbidden+=1
	_check("fauna own no collision or light", forbidden==0)
	var tess=fauna.get_node("Tessellates") as MultiMeshInstance3D
	var all_shadowless:=true
	for batch in fauna.get_children():
		all_shadowless=all_shadowless and batch is MultiMeshInstance3D \
				and batch.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_check("every family is one shadowless batch",tess!=null and all_shadowless)
	var buttons:=fauna.get_node("GildersButtons") as MultiMeshInstance3D
	var excluded_portal_layer:=1<<19
	var all_in_shared_world:=true
	for batch in fauna.get_children():
		all_in_shared_world=all_in_shared_world and (batch.layers&1)!=0 \
				and (batch.layers&excluded_portal_layer)==0
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
