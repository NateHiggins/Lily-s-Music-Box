extends "res://tests/v2_golden_repair_profile.gd"
## INERT layout survey in the complete production world. No installation grant.
func _init() -> void:route_label="V2 UNRACKED HOSE WORLD SURVEY"

func _prepare_player_start() -> void:
	player.global_position=world.adapter.root.to_global(Vector3(1.925,.02,-3.5));player.velocity=Vector3.ZERO

func _play_route() -> void:
	player.profile_physics=true
	for target: Vector3 in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.65,3.2,-3.4)]:
		if not await _walk(target):return
	profile_phase="layout_survey_excluded"
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
	var rows: Array=[]
	var projection: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_unracked_fire_hose_rig.json"))
	var placement: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_unracked_fire_hose_placement.json"))
	for id: String in native.stations:
		if OS.get_environment("ORISON_HOSE_SURVEY_STATION")!="" and id!=OS.get_environment("ORISON_HOSE_SURVEY_STATION"):continue
		var actor: Node3D=native.stations[id].get_ref()
		var saved: Dictionary=actor.mechanism_snapshot()
		# Coupling is an explicit survey precondition, not claimed user assembly.
		actor.door_open=true;actor._refresh_cabinet();actor.nozzle_coupled=true;actor._nozzle_joint.restore_legacy(true)
		var hose:=preload("res://scripts/props/fire_unracked_hose.gd").new();actor.add_child(hose)
		hose.guide_enabled=true;hose.ground_y_local=-1.2
		var start: int=Time.get_ticks_usec()
		var configured: bool=hose.configure(actor,"res://tests/fixtures/v2_unracked_fire_hose.glb",projection,placement)
		await get_tree().physics_frame;await get_tree().physics_frame
		var clear: bool=configured and hose.prepare_contact()
		var collider: Object=hose.contact.last_collider
		var row: Dictionary={"id":id,"configured":configured,"clear":clear,"error":hose.error,"prepare_ms":(Time.get_ticks_usec()-start)/1000.,"actor_transform":str(actor.global_transform),"collider":str(collider.get_path()) if collider is Node else str(collider),"player_collision_layer":player.collision_layer,"player_collision_mask":player.collision_mask}
		rows.append(row);print("UNRACKED WORLD STATION: ",JSON.stringify(row))
		if OS.get_environment("ORISON_HOSE_SURVEY_DIRECTIONS")=="1":
			for degrees: float in [30.,45.,60.,90.,120.,180.,240.,270.,300.,330.]:
				# Each contact owner binds once. Reuse cached immutable assets,
				# but create a fresh candidate and numerical placement per trial.
				var trial:=preload("res://scripts/props/fire_unracked_hose.gd").new();actor.add_child(trial)
				trial.guide_enabled=true;trial.ground_y_local=-1.2
				trial.guide_axis_local=Vector3.LEFT.rotated(Vector3.UP,deg_to_rad(degrees))
				trial.guide_side_local=Vector3.BACK.rotated(Vector3.UP,deg_to_rad(degrees))
				var fit: bool=trial.configure(actor,"res://tests/fixtures/v2_unracked_fire_hose.glb",projection,placement) and trial.prepare_contact()
				var hit: Object=trial.contact.last_collider
				var alternate: Dictionary={"id":id,"degrees":degrees,"clear":fit,"error":trial.error,"collider":str(hit.get_path()) if hit is Node else str(hit)}
				rows.append(alternate);print("UNRACKED WORLD DIRECTION: ",JSON.stringify(alternate))
				trial.free()
		hose.free();actor.restore_mechanism(saved)
		await get_tree().physics_frame
	var directory: String=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("layout_survey.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"complete-world layout diagnostic, no installed removal or runtime qualification","stations":rows,"failures":failures},"\t"))
