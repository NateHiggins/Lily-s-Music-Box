extends Node
## Installed-world integration probe. Not a room/navigation acceptance suite.
var failures: Array[String] = []
var checks := 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("WORLD GRAB CHECK: ",label," = ",ok)

func same_value(actual: Variant, expected: Variant) -> bool:
	if expected is Array:
		if actual is not Array or actual.size()!=expected.size(): return false
		for i in expected.size():
			if not same_value(actual[i],expected[i]): return false
		return true
	if expected is bool: return actual==expected
	return is_equal_approx(float(actual),float(expected))

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var selector := preload("res://scripts/building/building_root_selector.gd")
	selector.reset_for_tests("v2")
	var world := (load(selector.scene_path()) as PackedScene).instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed and world.player!=null,"composed V2 starts with new controls")
	if world.startup_failed or world.player==null:
		world.free();get_tree().quit(1);return
	var player: PlayerController = world.player
	player.set_physics_process(false)
	player.call_locked = false
	player.set_mouse_released(false)
	var kinds := {}
	for actor: Node in world.adapter.root.find_children("*","Node3D",true,false):
		if actor.has_method("mechanism_snapshot"):
			var value: Dictionary = actor.call("mechanism_snapshot")
			check(actor.call("valid_mechanism",value),"valid installed mechanical state "+str(actor.name))
			var kind := str(actor.get_script().resource_path)
			kinds[kind]=int(kinds.get(kind,0))+1
	var household: Node = get_tree().get_first_node_in_group("v2_household_state")
	check(household!=null,"shared household persistence owner bound")
	if household!=null:
		var snapshot: Dictionary = household.snapshot()
		check(household.validate(snapshot,household._kinds),"expanded household snapshot validates")
		check(household._kinds.values().has("mechanism"),"partial mechanisms registered for saves")
	print("WORLD GRAB FAMILIES: ",JSON.stringify(kinds))
	var tapped := 0
	for actor: Node in world.adapter.root.find_children("*","Node3D",true,false):
		if not actor is TapProp or actor.fixture!="kitchen_sink": continue
		var tap := actor as TapProp
		# Right-hand side as seen from the cap: upward mouse travel is the
		# counter-clockwise opening direction of these ordinary threaded valves.
		var target := tap._handles[0].to_global(Vector3(-.025,0,-.06))
		player.global_position=target+tap.global_basis*Vector3(0,-player.camera.position.y,-.75)
		player.camera.look_at(target)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var grip: Dictionary = player._grab.find_target()
		check(grip.get("owner")==tap,"installed hot cap resolves to actual tap "+tap.unit)
		if grip.get("owner")==tap:
			var click := InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
			var before := tap._valve_openings
			player._unhandled_input(click)
			check(player._grab.active() and tap._valve_openings==before,"cap acquisition preserves flow "+tap.unit)
			for i in 8:
				var motion := InputEventMouseMotion.new();motion.relative=Vector2(0,-6)
				player._unhandled_input(motion)
			player._unhandled_input(click)
			check(tap._valve_openings.x>before.x and is_equal_approx(tap._valve_openings.y,before.y),"drag operates only hot valve "+tap.unit+" actual="+str(tap._valve_openings))
			tap.restore_mechanism({"hot":before.x,"cold":before.y})
		var plug_saved: Dictionary=tap.mechanism_snapshot()
		tap.set_stopper(true)
		var plug_target: Vector3=tap._plug_hand.part.global_position
		player.global_position=plug_target+tap.global_basis*Vector3(.03,.55-player.camera.position.y,-.50)
		player.camera.look_at(plug_target)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var plug_grip: Dictionary=player._grab.find_target()
		check(plug_grip.get("part")==tap._plug_hand.part,"installed loose plug resolves through bowl opening "+tap.unit)
		if plug_grip.get("part")==tap._plug_hand.part:
			var click := InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
			player._unhandled_input(click)
			var motion := InputEventMouseMotion.new();motion.relative=Vector2(0,-32)
			player._unhandled_input(motion)
			check(not tap._stopper and tap._plug_hand.part.position.y>tap._plug_hand.seat.y,"installed mouse lift unseats drain plug "+tap.unit)
			player._unhandled_input(click)
		tap.restore_mechanism(plug_saved)
		tapped+=1
		if tapped==3:break
	check(tapped==3,"three installed native kitchens exercised")
	var ranged := 0
	for actor: Node in world.adapter.root.find_children("*","Node3D",true,false):
		if not actor is StoveProp: continue
		var stove := actor as StoveProp
		var target := stove._knobs[0].to_global(Vector3(0,0,-.02))
		player.global_position=target+stove.global_basis*Vector3(0,-player.camera.position.y,-.65)
		player.camera.look_at(target)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var grip: Dictionary = player._grab.find_target()
		check(grip.get("part")==stove._knobs[0],"native range resolves exact gas knob "+stove.unit)
		if grip.get("part")==stove._knobs[0]:
			var click := InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
			var before: Dictionary = stove.mechanism_snapshot()
			player._unhandled_input(click)
			check(player._grab.active() and same_value(stove._gas_openings,before.gas),"installed gas acquisition leaves settings unchanged "+stove.unit)
			for direction: Vector2 in [Vector2(12,0),Vector2(0,12),Vector2(-12,0),Vector2(0,-12)]:
				var motion := InputEventMouseMotion.new();motion.relative=direction
				player._unhandled_input(motion)
				if not is_equal_approx(stove._gas_openings[0],float(before.gas[0])): break
			player._unhandled_input(click)
			check(not is_equal_approx(stove._gas_openings[0],float(before.gas[0])) and is_equal_approx(stove._gas_openings[1],float(before.gas[1])),"installed mouse motion isolates selected cock "+stove.unit)
			stove.restore_mechanism(before)
		ranged+=1
		if ranged==3: break
	check(ranged==3,"three installed ranges exercised")
	var shower_tested := false
	for actor: Node in world.adapter.root.find_children("*","Node3D",true,false):
		if not actor is TapProp or actor.fixture!="shower": continue
		var curtain_saved: Dictionary=actor.mechanism_snapshot()
		actor.set_curtain_open(false)
		var target: Vector3=actor.to_global(Vector3(0,1.25,-.32))
		player.global_position=target+actor.global_basis*Vector3(0,-player.camera.position.y,-.65)
		player.camera.look_at(target)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var grip: Dictionary=player._grab.find_target()
		check(grip.get("owner")==actor and grip.get("part")==actor._curtain_hand.hand,"installed cloth is targetable")
		if grip.get("part")==actor._curtain_hand.hand:
			var click := InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
			player._unhandled_input(click)
			for i in 4:
				var motion := InputEventMouseMotion.new();motion.relative=Vector2(-12,0)
				player._unhandled_input(motion)
			player._unhandled_input(click)
			check(actor._curtain_hand.travel>.02 and actor._curtain_hand.travel<1.78,"installed mouse drag retains partially gathered curtain")
		actor.restore_mechanism(curtain_saved)
		shower_tested=true
		break
	check(shower_tested,"installed shower sampled")
	var window: Node=household._subjects.get("B1_BOILER_AIR_E")
	if window!=null:
		window.restore_open_state(false)
		var sash_grip: Dictionary=window._window_grip(window.sash)
		sash_grip.begin.call();sash_grip.write.call(.2);sash_grip.end.call()
		check(is_zero_approx(window.angle_degrees),"window sash remains shut behind engaged cam")
		var cam_grip: Dictionary=window._window_grip(window.latch)
		cam_grip.begin.call();cam_grip.write.call(PI*.5);cam_grip.end.call()
		player.global_position=Vector3(30,1,30)
		await get_tree().physics_frame
		sash_grip.begin.call();sash_grip.write.call(.3);sash_grip.end.call()
		check(window.angle_degrees>5,"unlatched installed window clears fitted reveal")
		cam_grip.begin.call();cam_grip.write.call(0.0);cam_grip.end.call()
		check(window.latch_fraction>=.8,"cam cannot enter keeper with sash away")


	player._grab.release()
	var expected := {}
	var sampled := {}
	for identity: String in household._subjects:
		var actor: Node = household._subjects[identity]
		var pose := {}
		var family := ""
		if actor is StoveProp:
			family="range";pose={"door":.43,"broiler":.07,"gas":[.37,.21,0.0,0.0],"lit":[false,false,false,false]}
			pose.lit[(actor.blocked_burner+1)%2]=true
		elif actor is FridgeProp: family="fridge";pose={"door":.31,"ice":0.0,"tray":.09 if actor._tray!=null else 0.0}
		elif actor is WasherProp: family="washer";pose={"lid":.7,"swing":-.35,"gap":.02,"pressure":TAU*1.5}
		elif actor is LaundryAirerProp: family="airer";pose={"height":1.67}
		elif actor is TapProp and actor._curtain_hand!=null:
			family="curtain";pose={"hot":0.0,"cold":0.0,"curtain":.89}
		elif actor is TapProp:
			if actor._plug_hand==null: continue
			family="tap";pose=actor.mechanism_snapshot()
			pose.hot=0.0;pose.cold=0.0;pose.water=.35
			var seat: Vector3=actor._plug_hand.seat
			pose.plug=[seat.x,seat.y,seat.z]
		elif actor is BoilerProp: family="boiler";pose=actor.mechanism_snapshot();pose.fire=.42;pose.ash=.17;pose.draft=.36;pose.witness=1.07
		elif actor.get_script().resource_path.ends_with("orison_v2_boiler_window.gd"): family="window";pose={"angle":25.0,"latch":1.0}
		if family.is_empty() or sampled.has(family): continue
		actor.restore_mechanism(pose)
		expected[identity]=actor.mechanism_snapshot();sampled[family]=true
	check(sampled.size()==8,"eight installed families prepared for fresh-root restoration")
	household.capture_now()
	check(RealityState.data.has(household.KEY),"partial mechanism document captured by household owner")
	world.shutdown_for_tests();world.free()
	await get_tree().process_frame
	world=(load(selector.scene_path()) as PackedScene).instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed,"fresh V2 root accepts saved partial mechanism document")
	household=get_tree().get_first_node_in_group("v2_household_state")
	if household!=null:
		for identity: String in expected:
			var actor: Node=household._subjects.get(identity)
			check(actor!=null,"fresh root resolves durable identity "+identity)
			if actor==null: continue
			var restored: Dictionary=actor.mechanism_snapshot()
			for key: String in expected[identity]:
				check(same_value(restored[key],expected[identity][key]),"fresh root retains partial "+identity+"/"+key)
	world.shutdown_for_tests();world.free()
	await get_tree().process_frame
	print("DIRECT MANIPULATION WORLD: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
