extends Node3D
## Production player, hand, reticle and water fixtures on an isolated bench.
## Proves the shared dial gesture (mouse right opens, left shuts) from several
## camera positions and contact points, that water follows the valves, and what
## the reticle reports. Not occupied-world qualification or artistic acceptance.
const Bath := preload("res://scripts/props/clawfoot_bath_prop.gd")
const KitchenSink := preload("res://scripts/building/orison_v2_kitchen_sink.gd")
const SinkMount := preload("res://scripts/building/orison_v2_sink.gd")
const DialGrip := preload("res://scripts/props/dial_grip.gd")

var player: PlayerController
var checks := 0
var failures: Array[String] = []
var directory := ""

func check(ok: bool,label: String) -> bool:
	checks+=1
	print("RETICLE VALVE ","PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
	return ok

func click() -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	player._unhandled_input(event)
	await settle()

func settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame

## Actual relative mouse motion, in small steps like a hand.
func drag(pixels: Vector2) -> void:
	var steps:=maxi(1,ceili(pixels.length()/12.))
	for step in steps:
		var motion:=InputEventMouseMotion.new()
		motion.relative=pixels/float(steps)
		player._unhandled_input(motion)
		await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame

func shot(label: String) -> void:
	if directory.is_empty():return
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	check(image.save_png(directory.path_join(label+".png"))==OK,"capture saved: "+label)
	# The mark is small on a full frame; a centred enlargement reads it.
	var mark: Vector2=player._target_dot.position
	var side:=mini(360,mini(image.get_width(),image.get_height()))
	var corner:=Vector2i(clampi(int(mark.x)-side/2,0,image.get_width()-side),clampi(int(mark.y)-side/2,0,image.get_height()-side))
	var detail:=image.get_region(Rect2i(corner,Vector2i(side,side)))
	detail.resize(side*2,side*2,Image.INTERPOLATE_LANCZOS)
	detail.save_png(directory.path_join(label+"_detail.png"))

func flowing(tap: TapProp) -> bool:
	var drawn:=tap._stream.visible
	if tap.get("filler") is Node3D:drawn=drawn or (tap.get("filler") as Node3D).visible
	return bool(tap.get_flow_state().hot or tap.get_flow_state().cold) and float(tap.get_flow_state().flow)>0. and drawn

func dry(tap: TapProp) -> bool:
	var drawn:=tap._stream.visible
	if tap.get("filler") is Node3D:drawn=drawn or (tap.get("filler") as Node3D).visible
	return is_zero_approx(float(tap.get_flow_state().flow)) and not drawn

func overlaid(part: Node3D) -> bool:
	var draws:=part.find_children("*","MeshInstance3D",true,false)
	if part is MeshInstance3D:draws.append(part)
	return draws.any(func(draw: MeshInstance3D)->bool:return draw.material_overlay!=null)

func stand(at: Vector3,aim: Vector3) -> void:
	player.position=at
	player.velocity=Vector3.ZERO
	player.face_world_point(aim)
	await settle()
	player.face_world_point(aim)
	await settle()

## One whole visit to one valve: aim, read the mark, take hold, turn, stop, let go.
func exercise(tap: TapProp,index: int,at: Vector3,aim: Vector3,label: String,capture:="") -> void:
	var handle: Node3D=tap._handles[index]
	var other:=1-index
	var word:="HOT" if index==0 else "COLD"
	tap.set_valve_opening(0,0.);tap.set_valve_opening(1,0.)
	await stand(at,aim)
	if not check(player._grab.find_target().get("part")==handle,label+": aim selects the "+word+" valve itself"):return
	var dot: Control=player._target_dot
	var guide: Dictionary=dot.guide
	check(dot.is_visible_in_tree() and dot.state=="available" and guide.get("archetype")=="dial",label+": hover mark is drawn and is the dial glyph")
	check(guide.get("label")==word and guide.get("ends")==["OFF","ON"] and is_zero_approx(float(guide.get("fraction",-1.))),label+": hover names the valve and reads it shut")
	check((guide.get("direction",Vector2.ZERO) as Vector2).is_equal_approx(Vector2.RIGHT),label+": hover arrow points right for open")
	check((guide.get("tint") as Color).is_equal_approx(DialGrip.HOT if index==0 else DialGrip.COLD),label+": warm for hot, cool for cold")
	check(player._part_outline.part==handle and player._part_outline.outlined() and overlaid(handle),label+": keyline is on the aimed handle")
	if capture!="":await shot(capture+"_hover_"+word.to_lower())
	check(dry(tap),label+": no water before the hand moves")
	await click()
	if not check(player._grab.active() and player._grab.target.part==handle and tap._held_valve==index,label+": primary click takes the valve"):return
	check(is_zero_approx(tap._valve_openings[index]) and dot.state=="grabbed",label+": taking hold moves nothing")
	var look:=player.camera.global_basis
	await drag(Vector2(0,72));await drag(Vector2(0,-72))
	check(is_zero_approx(tap._valve_openings[index]),label+": vertical travel does not turn a dial")
	await drag(Vector2(120,0))
	check(absf(tap._valve_openings[index]-.5)<.01,label+": 120 px right is half open, got "+str(tap._valve_openings[index]))
	check(flowing(tap) and is_zero_approx(tap._valve_openings[other]),label+": water runs from this valve alone")
	check(float(tap.get_flow_state().temperature)>0. if index==0 else is_zero_approx(float(tap.get_flow_state().temperature)),label+": mix follows the valve that is open")
	check(player.camera.global_basis.is_equal_approx(look),label+": the view holds still while a part is held")
	check(dot.state in ["grabbed","limit"] and absf(float(dot.guide.get("fraction",0.))-.5)<.01 and dot.travel_sign==1,label+": gauge reads half and rising state=%s fraction=%s sign=%s feedback=%s"%[dot.state,str(dot.guide.get("fraction")),str(dot.travel_sign),player._grab.motion_feedback])
	if capture!="":await shot(capture+"_grab_"+word.to_lower())
	await drag(Vector2(300,0))
	var stopped:=false
	for attempt in 4:
		var push:=InputEventMouseMotion.new();push.relative=Vector2(12,0)
		player._unhandled_input(push)
		await get_tree().physics_frame;await get_tree().physics_frame;await get_tree().process_frame
		stopped=stopped or dot.state=="limit"
	check(is_equal_approx(tap._valve_openings[index],1.) and stopped,label+": right stops at fully open and the mark reports the stop")
	if capture!="":await shot(capture+"_stop_"+word.to_lower())
	await drag(Vector2(-60,0))
	check(absf(tap._valve_openings[index]-.75)<.01 and dot.travel_sign==-1,label+": left closes it by the same measure")
	await drag(Vector2(-400,0))
	check(is_zero_approx(tap._valve_openings[index]) and dry(tap),label+": left to the stop shuts the water off")
	await drag(Vector2(96,0))
	await click()
	check(not player._grab.active() and tap._held_valve==-1 and absf(tap._valve_openings[index]-.4)<.01,label+": next click lets go without snapping")
	check(flowing(tap),label+": water keeps running after release")
	if capture!="":
		await stand(at,tap.get_node("SpoutOutlet").global_position if tap.has_node("SpoutOutlet") else aim)
		await shot(capture+"_running_"+word.to_lower())
	tap.set_valve_opening(index,0.)
	await settle()

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	directory=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var floor_body:=StaticBody3D.new();add_child(floor_body)
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(16,.2,8)
	collision.shape=box;collision.position.y=-.1;floor_body.add_child(collision)
	var ground:=MeshInstance3D.new();var slab:=BoxMesh.new();slab.size=Vector3(16,.02,8);ground.mesh=slab;ground.position.y=-.011
	var tile:=StandardMaterial3D.new();tile.albedo_color=Color(.30,.33,.33);ground.material_override=tile;add_child(ground)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.055,.067,.074)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.72,.78,.85);environment.environment.ambient_light_energy=.55;add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,-32,0);sun.light_energy=1.2;add_child(sun)

	var bath:=Bath.new();bath.prop_type="shower";bath.fixture="shower";bath.unit="4B";add_child(bath)
	var lavatory:=TapProp.new();lavatory.prop_type="sink";lavatory.fixture="bath_sink";lavatory.unit="4B";lavatory.position=Vector3(4,0,0);add_child(lavatory)
	var kitchen:=KitchenSink.new();kitchen.prop_type="sink";kitchen.fixture="kitchen_sink";kitchen.position=Vector3(-4,0,0);add_child(kitchen)
	check(SinkMount.new().mount(kitchen),"kitchen sink collision mounts")
	if not check(bath.native_ready and bath.mount_fixture_collision(),"prologue bath mounts on the actual fixture owner"):finish();return
	bath._curtain_hand.set_travel(Bath.CurtainMotion.TRAVEL)

	player=PlayerController.new();player.position=Vector3(.32,0,-1.15);add_child(player)
	player.set_physics_process(false);player.set_lamp_enabled(false);player.camera.make_current()
	# The carried teletype moves prompt words to paper. The mark must survive it.
	player.set_physical_display_enabled(true)
	check(player._interaction_hud.visible,"carrying the paper display leaves the aiming mark on screen")
	if player.carried_device!=null:player.carried_device.set_capture_hidden(true)
	for frame in 8:await get_tree().process_frame
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await settle()

	# The prologue's own fixture: beside the tub, and standing in it as the opening does.
	for index in 2:
		var handle: Node3D=bath._handles[index]
		var cap:=handle.global_position+handle.global_basis.x*.06
		await exercise(bath,index,Vector3(.32,0,-1.15),cap,"bath from the room",("bath" if not directory.is_empty() else ""))
		cap=handle.global_position+handle.global_basis.x*.06
		await exercise(bath,index,bath.model.to_global(Vector3(0,.239,0)),cap,"bath from inside the tub")
		cap=handle.global_position+handle.global_basis.x*.06
		await exercise(bath,index,Vector3(.95,0,-.80),cap,"bath from the far side")

	# The rose is tilted on its swivel so every jet lands inside the tub.
	var jet: Vector3=-bath._stream.basis.y
	var reach: float=(bath._water_empty_y-bath._stream.position.y)/jet.y
	var landing: Vector3=bath._stream.position+jet*reach-bath.model.position
	var cone: float=reach*tan(deg_to_rad(7.6))
	print("RETICLE VALVE spray jet=",jet," landing=",landing," cone=",cone)
	check(jet.x>.2 and absf(jet.z)<.01,"the rose leans toward the middle of the tub")
	check(absf(landing.x)+cone<.60 and absf(landing.z)+cone<.33,"the whole cone lands inside the tub's rim")
	var Moisture:=preload("res://scripts/building/v2_bathroom_moisture.gd")
	var lowest:=2.;var highest:=0.
	for tick in 600:
		var head: float=Moisture.pressure_at(float(tick)*.05)
		lowest=minf(lowest,head);highest=maxf(highest,head)
	check(lowest>=.3 and lowest<.5 and highest>1. and highest<=1.1,"supply pressure sags, knocks and recovers within bounds: %s..%s"%[lowest,highest])

	# The faucet and shower diverter is a one-click control, not a drag.
	await stand(Vector3(.32,0,-1.15),bath.diverter.global_position)
	var mark: Dictionary=player._target_dot.guide
	check(player._grab.find_target().get("part")==bath.diverter and mark.get("archetype")=="tap" and mark.get("ends")==["FAUCET","SHOWER"],"diverter hover is the click mark naming faucet and shower")
	bath.set_valve_opening(1,.5)
	await settle()
	check(bath._stream.visible and not bath.filler.visible,"water starts at the shower head")
	await click()
	check(not player._grab.active() and is_zero_approx(bath.shower_fraction) and bath.filler.visible and not bath._stream.visible,"one click sends the water to the faucet and latches nothing")
	await shot("bath_toggle_faucet")
	await click()
	check(is_equal_approx(bath.shower_fraction,1.) and bath._stream.visible and not bath.filler.visible,"the next click sends it back to the shower")
	await shot("bath_toggle_shower")
	bath.set_valve_opening(1,0.)
	await settle()

	# A wall-valved lavatory from the left, the right and close above.
	for index in 2:
		var handle: Node3D=lavatory._handles[index]
		var cap:=handle.global_position-lavatory.global_basis.z*.06
		await exercise(lavatory,index,lavatory.position+Vector3(-.40,0,-.72),cap,"lavatory from the left",("lavatory" if not directory.is_empty() else ""))
		await exercise(lavatory,index,lavatory.position+Vector3(.40,0,-.72),cap,"lavatory from the right")
		await exercise(lavatory,index,lavatory.position+Vector3(0,0,-.50),cap,"lavatory from above")

	# The old tangent gesture reversed between the top and bottom arm of a cross.
	for index in 2:
		var handle: Node3D=kitchen._handles[index]
		for arm: Vector3 in [Vector3(0,.034,-.06),Vector3(0,-.034,-.06)]:
			await exercise(kitchen,index,kitchen.position+Vector3(.25 if index==0 else -.25,0,-.80),handle.to_global(arm),"kitchen cross arm "+str(arm))

	# Leaving the valve clears the keyline and returns the idle ring.
	await stand(Vector3(0,0,-3),Vector3(0,3,-9))
	check(player._target_dot.state=="idle" and not player._part_outline.outlined(),"aim away: idle ring and no keyline")
	for tap: TapProp in [bath,lavatory,kitchen]:
		for handle: Node3D in tap._handles:
			check(not overlaid(handle),"no overlay left on "+str(tap.name)+"/"+str(handle.name))
	finish()

func finish() -> void:
	print("RETICLE VALVE RESULT checks=",checks," failures=",failures.size())
	for failure: String in failures:print("RETICLE VALVE FAILURE: ",failure)
	get_tree().quit(1 if not failures.is_empty() else 0)
