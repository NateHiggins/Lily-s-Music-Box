extends Node
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const DECODER_RELEASE_DEADLINE_MS := 1000
var checks := 0
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("UPPER EQUIPMENT: "+label)
func _has_stream(emitter: AudioStreamPlayer3D) -> bool:
	return emitter.stream != null
func _record_playbacks(radio: BakedFurnitureInteraction, records: Array[Dictionary], phase: String) -> void:
	# Only WeakRefs cross the coroutine boundary. get_stream_playback() returns
	# the most recently requested decoder, including a not-yet-mixed 3D play.
	for key: String in ["_radio_bed", "_control_click"]:
		var emitter := radio.get(key) as AudioStreamPlayer3D
		if emitter.has_stream_playback():
			records.append({"owner":str(radio.get_meta("v2_furniture_id")),
				"sound":key, "phase":phase, "reference":weakref(emitter.get_stream_playback())})
func _playback_report(records: Array[Dictionary], phase := "") -> Dictionary:
	var live: Array[Dictionary] = []
	var count := 0
	for record: Dictionary in records:
		if not phase.is_empty() and record.phase != phase: continue
		count += 1
		var playback := (record.reference as WeakRef).get_ref() as AudioStreamPlayback
		if playback != null:
			live.append({"owner":record.owner,"sound":record.sound,"phase":record.phase,
				"decoder_is_playing":playback.is_playing(),"references_including_probe":playback.get_reference_count()})
	return {"observed":count,"live":live}
func _live_playbacks(records: Array[Dictionary]) -> int:
	var live := 0
	for record: Dictionary in records:
		if (record.reference as WeakRef).get_ref() != null: live += 1
	return live
func _ready() -> void:
	RealityState.persistence_enabled=false
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/v2_upper_equipment_probes.json"))
	check(source.equipment.size()==15,"fourteen authored objects and a comparison table")
	for cycle in 2:
		RealityState.reset_campaign_for_tests()
		var world := Runtime.instantiate() as OrisonV2RuntimeRoot
		add_child(world)
		check(not world.startup_failed,"complete production world starts")
		if world.startup_failed:world.shutdown_for_tests();world.free();break
		var player := world.player
		player.set_physics_process(false);player.set_process_unhandled_input(false)
		player.camera.make_current()
		var radios: Array[BakedFurnitureInteraction]=[]
		var refs: Array[WeakRef]=[]
		var audio_refs: Array[WeakRef]=[]
		var playback_refs: Array[Dictionary]=[]
		var world_ref: WeakRef = weakref(world)
		var player_ref: WeakRef = weakref(player)
		var capsule := CapsuleShape3D.new();capsule.radius=.38;capsule.height=1.524
		for row: Dictionary in source.equipment:
			var prop := world.adapter.resolve(row.id) as StaticBody3D
			var stance := world.adapter.resolve(row.stance) as Node3D
			check(prop!=null and stance!=null,"one equipment owner and approach: "+str(row.id))
			if prop==null or stance==null:continue
			refs.append(weakref(prop))
			check(str(prop.get_meta("v2_furniture_id",""))==row.id,"semantic identity retained")
			var meshes := prop.find_children("*","MeshInstance3D",true,false)
			check(not meshes.is_empty(),"authored equipment geometry present")
			for mesh: MeshInstance3D in meshes:
				var material := mesh.material_override as StandardMaterial3D
				check(material!=null and material.albedo_texture!=null,"equipment retains texture-backed material")
			player.global_position=stance.global_position
			player.camera.global_position=player.global_position+Vector3.UP*player.STANDING_EYE
			var center := Vector3(0,(float(row.bounds[0][1])+float(row.bounds[1][1]))*.5,0)
			player.camera.look_at(prop.to_global(center))
			await get_tree().physics_frame
			var query := PhysicsShapeQueryParameters3D.new();query.shape=capsule
			query.transform=Transform3D(Basis.IDENTITY,player.global_position+Vector3.UP*.787);query.exclude=[player.get_rid()]
			check(player.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"equipment approach admits standing capsule: "+str(row.id))
			if row.kind=="radio":
				var radio := prop as BakedFurnitureInteraction
				radios.append(radio)
				for emitter: AudioStreamPlayer3D in [radio.get("_radio_bed"),radio.get("_control_click")]:
					audio_refs.append(weakref(emitter))
					check(_has_stream(emitter),"specialist sound has a recorded stream")
				check(radio.owner_unit==row.unit and not radio.get("_powered"),"collector set retains its resident and starts silent")
				player.use_primary_interaction()
				_record_playbacks(radio,playback_refs,"first_on")
				check(radio.get("_powered") and radio.get("_radio_bed").playing,"actual E reaches distinct specialist set: "+str(row.id))
				player.use_primary_interaction()
				_record_playbacks(radio,playback_refs,"second_off")
				check(not radio.get("_powered") and not radio.get("_radio_bed").playing,"second E stops this set")
			else:check(not prop.has_method("interact"),"fixed display equipment adds no invented mechanism")
		check(radios.size()==4,"all four upper specialist comparison sets")
		for radio: BakedFurnitureInteraction in radios:
			radio.interact(player)
			_record_playbacks(radio,playback_refs,"retire_unmixed")
		world.shutdown_for_tests();world.free()
		for ref: WeakRef in refs:check(ref.get_ref()==null,"equipment retires with world")
		check(world_ref.get_ref()==null and player_ref.get_ref()==null,"world and actual player retire synchronously")
		for ref: WeakRef in audio_refs:check(ref.get_ref()==null,"specialist audio emitter retires synchronously")
		check(playback_refs.size()==20,"all per-radio on/off and retirement decoders observed")
		var unmixed := _playback_report(playback_refs,"retire_unmixed")
		check(unmixed.observed==8 and unmixed.live.is_empty(),"unmixed specialist decoders retire synchronously")
		print("EQUIPMENT DECODERS IMMEDIATE: "+JSON.stringify(_playback_report(playback_refs)))
		# A started decoder can remain in AudioServer's playback list until the
		# audio mixer removes it and a later main-loop AudioServer.update cleans
		# that list. process_frame occurs before that update. Observe this actual
		# owner release with a bounded deadline; do not require a shared clip to
		# die with one consumer, or sleep for its recorded duration.
		var retired_at := Time.get_ticks_msec()
		var frames := 0
		while _live_playbacks(playback_refs)>0 and Time.get_ticks_msec()-retired_at<DECODER_RELEASE_DEADLINE_MS:
			await get_tree().process_frame
			frames += 1
		var remaining := _playback_report(playback_refs)
		check(remaining.live.is_empty(),"specialist decoders retire after AudioServer cleanup: "+JSON.stringify(remaining))
		print("UPPER EQUIPMENT LIFETIME: cycle=%d audio_emitters=%d decoders=%d drain_frames=%d drain_ms=%d objects=%d resources=%d nodes=%d orphans=%d" % [cycle,audio_refs.size(),playback_refs.size(),frames,Time.get_ticks_msec()-retired_at,Performance.get_monitor(Performance.OBJECT_COUNT),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])

	print("UPPER EQUIPMENT: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
