extends "res://tests/character_squeeze_player_test.gd"
## Actual staff and player on diagnostic solids; no native Harukiya claim.
const Staff = preload("res://scripts/characters/harukiya_staff_body.gd")
const Owner = preload("res://scripts/characters/harukiya_cast.gd")
var preview_owned := false
var prior_data: Dictionary
var prior_text := ""
var prior_status := {}
var prior_files := {}
var prior_mouse := 0
var source_before := {}
var output := ""
var player: PlayerController
var peer: Node3D
var owner_fixture: Node3D
var observations := {}

func _ready() -> void:
	var profile:=OS.get_environment("STAFF_SQUEEZE_ISOLATED_APPDATA").replace("\\","/").simplify_path()
	var actual:=OS.get_user_data_dir().replace("\\","/").simplify_path()
	if not profile.begins_with("C:/ov/reports/harukiya_overhaul_20261112/staff_squeeze_") or actual!=profile.path_join("PleaseRemainOnTheLine"):
		push_error("Staff squeeze needs dedicated process-start APPDATA");get_tree().quit(2);return
	output=OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output)!=OK:get_tree().quit(2);return
	if DisplayServer.get_name()=="headless":push_error("Loaded staff test requires hidden windowed renderer");get_tree().quit(2);return
	run.call_deferred()

func run() -> void:
	prior_mouse=Input.mouse_mode
	prior_data=RealityState.data;prior_text=JSON.stringify(prior_data,"",true,true)
	prior_status=_status().duplicate(true);prior_files=_save_bundle()
	source_before=_sources()
	check(not Input.is_action_pressed("move_forward"),"diagnostic input starts released")
	preview_owned=RealityState.begin_preview_campaign(self)
	check(preview_owned,"exclusive nonpersistent preview")
	if not failures.is_empty():_finish();return
	block(Vector3(0,-.1,0),Vector3(10,.2,10))
	block(Vector3(0,1,-2),Vector3(10,2,.2))
	peer=Staff.new()
	peer.configure("stacy","res://assets/characters/stacy/stacy.gltf",Owner.PARTS,"at_ease")
	add_child(peer)
	check(peer.ready_ok,"actual Stacy work presentation loads")
	if not peer.ready_ok:_finish();return
	owner_fixture=Owner.new();owner_fixture._floor_y=0.0
	owner_fixture._ground_rest_shoes(peer)
	check(peer.load_standing_profiles(),"actual sealed source-bound standing profiles load")
	peer.set_active(true)
	var column: Dictionary=peer.standing_occupancy()
	check(not column.is_empty() and peer.is_in_group("animated_residents"),"actual active staff column participates")
	check(peer.find_children("*","CollisionObject3D",true,false).is_empty(),"staff has no invented hard body")
	if not failures.is_empty():_finish();return
	var identity:=peer.get_instance_id();var model_id: int=peer.model.get_instance_id()
	var column_before:=column.duplicate(true)
	var parts_before: Array=peer.worn_parts().duplicate()
	player=PlayerController.new();add_child(player)
	player.global_position=Vector3(column.base.x,.02,1.2)
	player.set_mouse_released(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame
	var separation:=maxf(.65,player.BODY_RADIUS+float(column.radius)+.04)
	check(player.global_position.z>column.base.z+separation,"player starts clear on forward approach")
	if not failures.is_empty():_finish();return
	var previous:=player.global_position
	var minimum_z:=player.global_position.z
	var yielded_frames:=0;var first_cue_seconds:=-1.0;var first_cue_contact: Dictionary={};var held_seconds:=0.0
	var trace: Array=[]
	Input.action_press("move_forward")
	for i: int in Engine.physics_ticks_per_second*8:
		await get_tree().physics_frame
		held_seconds+=player.get_physics_process_delta_time()
		minimum_z=minf(minimum_z,player.global_position.z)
		var gap:=Vector2(player.global_position.x-column.base.x,player.global_position.z-column.base.z).length()
		if player.global_position.z>column.base.z and absf(gap-separation)<.15 and player.global_position.distance_to(previous)<.001:yielded_frames+=1
		if first_cue_seconds<0.0 and player._squeeze.cue_count>0:
			first_cue_seconds=held_seconds
			first_cue_contact=player._squeeze._contacts.get(peer.get_instance_id(),{}).duplicate(true)
		if i%30==0:trace.append({"seconds":held_seconds,"position":str(player.global_position),"cues":player._squeeze.cue_count,"gap":gap})
		previous=player.global_position
	Input.action_release("move_forward")
	check(yielded_frames>1,"directional input briefly yields at actual measured column")
	check(player.global_position.z<column.base.z-float(column.radius)-player.BODY_RADIUS,"ordinary directional input clears far side of full staff column")
	check(first_cue_seconds>=player._squeeze.WAIT and float(first_cue_contact.get("seconds",-1.0))>=player._squeeze.WAIT,"cue follows actual peer contact courtesy wait")
	check(player._squeeze.cue_count==1,"one courtesy cue for actual staff passage")
	check(minimum_z>=-1.9+player.BODY_RADIUS-.03,"actual solid wall face remains impassable to full player capsule")
	check(player.get_collision_exceptions().is_empty(),"no native collision exceptions")
	check(peer.get_instance_id()==identity and peer.model.get_instance_id()==model_id and peer.worn_parts()==parts_before,"actual staff and loaded model identity unchanged")
	check(peer.standing_occupancy()==column_before and peer.is_in_group("animated_residents"),"source-bound standing column unchanged")
	observations={"column":column_before,"staff_id":identity,"model_id":model_id,"parts":parts_before,"yielded_frames":yielded_frames,"first_cue_seconds":first_cue_seconds,"first_cue_contact":first_cue_contact,"minimum_z":minimum_z,"trace":trace}
	_finish()

func _sources() -> Dictionary:
	var result: Dictionary={}
	for path: String in ["res://tests/character_squeeze_staff_test.gd","res://tests/CharacterSqueezeStaffTest.tscn","res://tests/character_squeeze_player_test.gd","res://scripts/player/player_controller.gd","res://scripts/characters/character_squeeze_past.gd","res://scripts/characters/harukiya_staff_body.gd","res://scripts/characters/standing_occupancy.gd","res://scripts/characters/harukiya_staff_profile_binding.gd","res://data/characters/harukiya_staff_standing_columns.json"]:
		result[path]=FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	return result

func _status() -> Dictionary:
	return {"load":RealityState.load_status(),"notice":RealityState.player_notice(),"last_save":RealityState.last_save_result(),"blocked":RealityState.save_write_blocked,"version":RealityState.incompatible_save_version,"persistence":RealityState.persistence_enabled,"save_path":RealityState.save_path}

func _save_bundle() -> Dictionary:
	var out: Dictionary={}
	for suffix: String in ["", ".bak", ".txn", ".tmp"]:
		var path: String=RealityState.save_path+suffix
		out[suffix]={"exists":FileAccess.file_exists(path),"sha256":FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""}
	return out

func _finish() -> void:
	Input.action_release("move_forward")
	if is_instance_valid(owner_fixture):owner_fixture.free()
	for child: Node in get_children():child.free()
	Input.mouse_mode=prior_mouse
	if preview_owned:check(RealityState.end_preview_campaign(self),"preview lease returned");preview_owned=false
	check(is_same(prior_data,RealityState.data) and JSON.stringify(RealityState.data,"",true,true)==prior_text,"original campaign identity/content restored")
	check(_status()==prior_status and _save_bundle()==prior_files,"original status/protection/save bytes restored")
	check(Input.mouse_mode==prior_mouse and not Input.is_action_pressed("move_forward") and get_child_count()==0,"diagnostic actors/input/mouse cleaned")
	check(_sources()==source_before,"named sources unchanged")
	var report:=JSON.stringify({"evidence_class":"INERT bounded diagnostic","scope":"Real player motor and loaded Stacy work profile on diagnostic floor/wall only; no native venue or whole-cast claim","failures":failures,"sources":source_before,"observations":observations},"\t")
	var path:=output.path_join("staff_squeeze.json")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:failures.append("report open failed")
	else:
		file.store_string(report);file.flush();check(file.get_error()==OK,"diagnostic report flushed");file.close()
		check(FileAccess.get_file_as_string(path)==report,"diagnostic report bytes verified")
	get_tree().quit(0 if failures.is_empty() else 1)
