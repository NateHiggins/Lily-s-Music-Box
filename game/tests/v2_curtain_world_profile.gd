extends "res://tests/v2_bathroom_optics_profile.gd"
## INERT occupied-world curtain profile. Exact same fixture before/after.
var curtain_inputs: Array[Dictionary]=[]

func _init() -> void: route_label="V2 CURTAIN WORLD PROFILE"

func _ready() -> void:
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	GameBoot.settings.weather_network_enabled=false
	OS.set_environment("WEATHER_SIMULATE","")
	super._ready()

func _route() -> void:
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"):
		driver.set_frozen_for_tests(true)
	player.camera.fov=75.0
	var switches: SwitchSystem=world.get_node("V2RoomSwitches")
	var original: Dictionary=switches.room_snapshot("F04_B_BATH")
	var lit: Dictionary={}
	for id: String in original: lit[id]=true
	switches.restore_room("F04_B_BATH",lit)
	await _profile_route()
	switches.restore_room("F04_B_BATH",original)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("curtain_input.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","scope":"actual occupied 4B bath, original door/walking approach then repeated primary grab/motion/release; no full V2 qualification",
		"clock":world.campaign_clock.datetime_string(),"resolution":str(get_viewport().get_visible_rect().size),
		"fov":player.camera.fov,"settings":{"render_method":RenderingServer.get_current_rendering_method(),
			"quality":int(GameBoot.settings.get("quality",0)),"msaa_3d":get_viewport().msaa_3d,
			"taa":get_viewport().use_taa,"vsync":false,"input_cadence":"one curtain motion per process frame"},
		"drawn_source_sha256":FileAccess.get_sha256("res://assets/props/bath_shower.glb"),
		"motion_source_sha256":FileAccess.get_sha256("res://scripts/props/shower_curtain_motion.gd"),
		"phases":curtain_inputs,"failures":failures},"\t"))

func _played_bathroom(shower: TapProp,bath_door: DoorProp,inside_sign: float) -> bool:
	_phase="door_input"
	if not await _drag_part(bath_door,bath_door.to_global(Vector3(bath_door.width-.085,1.0,0)),bath_door.motion_target_angle(true),"bathroom_easy_open"):return false
	_phase="approach_shower_walk"
	if not await _walk(world.adapter.root.to_local(bath_door.to_global(Vector3(bath_door.width*.5,.02,inside_sign*.75)))):return false
	if not await _walk(Vector3(-8.45,9.6,4.35)):return false
	if not await _wet_route(shower):return false
	_require(true,"complete repeated curtain input sequence")
	return _require(not bath_door.open and absf(bath_door._body.rotation.y)<.001,"released room door closes automatically during ordinary use")

func _wet_route(shower: TapProp) -> bool:
	if not _require(is_zero_approx(shower._curtain_hand.travel),"curtain starts closed through its actual owner"):return false
	await _measure("curtain_idle_before",shower.to_global(Vector3(0,1.18,-.32)),3.0)
	for round_index in 3:
		for opening: bool in [true,false]:
			var goal:=1.78 if opening else 0.0
			var label:="curtain_%s_%d"%["open" if opening else "close",round_index+1]
			var aim: Vector3=shower.to_global(Vector3(0,1.18,-.32)) if opening else shower._curtain_hand.hand.global_position
			_phase=label
			player._grab.profile_records.clear()
			var before: Dictionary=shower.mechanism_snapshot().duplicate(true)
			var started:=Time.get_ticks_usec()
			var ok:=await _drag_part(shower,aim,goal,label)
			curtain_inputs.append({"phase":label,"ok":ok,"wall_ms":(Time.get_ticks_usec()-started)/1000.0,
				"aim":[aim.x,aim.y,aim.z],"before":before,"after":shower.mechanism_snapshot(),
				"callbacks":player._grab.profile_records.duplicate(true),"physics_frame":Engine.get_physics_frames()})
			if not ok:return false
			await _measure(label+"_settled",shower._curtain_hand.hand.global_position,1.0)
	await _measure("curtain_idle_after",shower.to_global(Vector3(0,1.18,-.32)),3.0)
	return _require(not player._grab.active() and not shower._curtain_hand.held,"three complete real opening/closing pairs release their owner")

func _drag_part(owner_node: Node3D,aim: Vector3,goal: float,label: String) -> bool:
	if owner_node!=_tap:return await super._drag_part(owner_node,aim,goal,label)
	player.camera.look_at(aim)
	await get_tree().physics_frame
	player.camera.look_at(aim)
	var grip: Dictionary=player._grab.find_target()
	if not _require(grip.get("owner")==owner_node,"actual player ray selects operable part: "+label):return false
	var initial: float=grip.read.call()
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	player._unhandled_input(click)
	if not _require(player._grab.active() and is_equal_approx(initial,float(grip.read.call())),"click grabs without toggling: "+label):return false
	for step in 160:
		if absf(float(grip.read.call())-goal)<.00001 or not player._grab.active():break
		var motion:=InputEventMouseMotion.new();motion.relative=_part_gesture(grip,goal)
		player._unhandled_input(motion)
		# Avoid injecting eight expensive movements in physics catch-up before
		# one render. Each motion gets a process/render opportunity, like the
		# accumulated mouse input used by ordinary play.
		await get_tree().process_frame
	var reached:=absf(float(grip.read.call())-goal)<.00001
	if player._grab.active():player._unhandled_input(click)
	await get_tree().physics_frame;await get_tree().physics_frame
	if not _require(owner_node.valid_mechanism(owner_node.mechanism_snapshot()),"physical stop remains saveable: "+label):return false
	return _require(reached and not player._grab.active(),"mouse motion reaches stop and second click releases: "+label)
