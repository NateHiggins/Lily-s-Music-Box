extends "res://tests/companion_session_ownership_bench.gd"
## Late-phase diagnostic, not proof that preceding prologue scenes were played.
const Opening:=preload("res://scripts/game/prologue_state.gd")
const Director:=preload("res://scripts/game/prologue_director.gd")
const Console:=preload("res://scripts/game/prologue_temporal_console.gd")
var accepted_count:=0
var contact_keys:Array[String]=[]

func _ready() -> void:
	_run.call_deferred()
	get_tree().create_timer(240.0).timeout.connect(func():
		if not finished:check(false,"temporal diagnostic deadline");finish())

func late_phase() -> Dictionary:
	var value:Dictionary=Opening.request_skip(Opening.initial())
	while value.phase!="temporal_command":
		if value.phase=="companion_crossing":value=Opening.applied(value,"companion_materialized")
		value=Opening.advance(value,Opening.PHASES[Opening.PHASES.find(value.phase)+1])
	return value

func mount_director(value:Dictionary) -> Node:
	var director:=Director.new();add_child(director)
	director.world=self;director.player=player;director._carrier=carrier
	director.state=Opening.restore(value);director._document=RealityState.data
	RealityState.data.prologue=director.state.duplicate(true)
	return director

func additional_checks() -> void:
	await super.additional_checks()
	await wait_for(func():return not carrier.device.teletype.printing and not carrier.arm_busy())
	var draft:String=carrier.session.draft
	var paper:Node=carrier.device.teletype
	var reports:int=carrier.device.printed_count
	var before:Dictionary=RealityState.data.duplicate(true)
	var director:Node=mount_director(late_phase())
	if not check(director.begin_temporal_command(),"late-phase diagnostic starts the real command printer and arm"):return
	var console:Node=director.temporal_console
	var destination:Dictionary=director.state.target.duplicate(true)
	check(Opening.valid_target(destination),"director freezes one validated destination before physical typing")
	console.accepted.connect(func(_target:Dictionary):accepted_count+=1)
	carrier.rig.typing_arm.key_pressed.connect(record_contact)
	if not check(await wait_for(func():return console.cursor>=12,30),"real finger contacts progressively type the command"):director.shutdown();return
	check(not console.returned and accepted_count==0 and "destination_accepted" not in director.state.events,"partial command cannot accept the date")
	check(paper.pages[0].contains(console.text.substr(0,8)) and paper.printing,"physical paper consumes actual contact characters")
	var register:Node=carrier.rig.temporal_register
	check(register.phase=="open" and register._target==destination and register.labels.Departure.text=="DEPARTURE  UNKNOWN","physical register presents immutable destination without inventing departure")
	var visible_rows:=true
	var frame:Node=carrier.screen_frame
	var aperture:=Rect2(Vector2.ZERO,Vector2(frame.view.size)).grow(-1)
	for label:Label3D in register.labels.values():
		var box:AABB=label.get_aabb()
		for corner in 8:
			visible_rows=visible_rows and aperture.has_point(frame.view_camera.unproject_position(label.to_global(box.get_endpoint(corner))))
	check(visible_rows and frame.safe_rect.position.x>=.67,"all temporal rows fit the real right-third reading frame")
	await capture("temporal_typing.png")
	get_tree().paused=true
	var at:int=console.cursor
	var register_pose:Transform3D=register.hinge.transform
	await frames(3)
	check(console.cursor==at and player.text_input_owner==carrier.rig.typing_arm,"pause retains command progress and its exclusive input lease")
	check(register.hinge.transform==register_pose,"pause retains the deployed temporal hardware")
	get_tree().paused=false
	if not check(await wait_for(func():return console.returned,35),"Return follows the complete physically typed command"):director.shutdown();return
	check(console.cursor==console.text.length() and contact_keys.back()=="ENTER" and contact_keys.size()==console.text.length()+1,"every command character and Return has exactly one contact")
	check(accepted_count==1 and "destination_accepted" in director.state.events and director.state.phase=="temporal_command","acceptance recorded once while the real arm retracts")
	check(carrier.device.printed_count==reports+1 and paper.pages[0].contains("DATE ACCEPTED"),"accepted copy uses the existing device report owner")
	# Save the actual accepted-but-retracting boundary, then cancel presentation.
	var original_path:String=RealityState.save_path
	var original_enabled:bool=RealityState.persistence_enabled
	RealityState.save_path=directory.path_join("temporal_boundary.json")
	RealityState.persistence_enabled=true
	var saved:bool=RealityState.save_game()
	check(saved,"validated campaign storage saves the accepted command boundary")
	director.shutdown();director.queue_free()
	await wait_for(func():return not carrier.arm_busy() and not paper.printing)
	await capture("temporal_accepted.png")
	if saved:
		RealityState.load_game()
		var restored:Dictionary=Opening.restore(RealityState.data.prologue)
		check(restored.target==destination and "destination_accepted" in restored.events,"validated reload restores immutable destination and acceptance")
		director=mount_director(RealityState.data.prologue)
		check(director.begin_temporal_command() and director.state.phase=="temporal_synchronization" and director.state.target==destination,"reload resumes beyond acceptance without resampling or retyping")
		check(not carrier.arm_busy() and carrier.device.printed_count==reports+1,"reload produces no second physical copy or arm cycle")
		check(register.phase=="idle" and register._owner==null,"accepted-command reload leaves no stale register owner")
		director.shutdown();director.queue_free()
	RealityState.save_path=original_path;RealityState.persistence_enabled=original_enabled
	check(not RealityState.data.prologue.effects.clock_applied,"typing acceptance does not bypass campaign-clock authority")
	# JSON numeric canonicalization is part of the existing save contract.
	# Compare every other domain after the same round trip on both sides.
	var normalized_before:Dictionary=JSON.parse_string(JSON.stringify(before))
	var normalized_after:Dictionary=JSON.parse_string(JSON.stringify(RealityState.data))
	var unchanged:=true
	for domain:String in normalized_before:
		if domain not in ["prologue","companion"]:unchanged=unchanged and normalized_before[domain]==normalized_after[domain]
	check(unchanged and carrier.session.draft==draft,"command and reload preserve gameplay domains and the human draft")
	carrier.rig.typing_arm.key_pressed.disconnect(record_contact)
	# Interrupt a new presentation before Return using a genuine field copy.
	var interrupted:=Console.new();add_child(interrupted)
	var previous_pages:Array=paper.pages.duplicate()
	player.acquire_text_input(self)
	check(not interrupted.start(carrier,destination) and player.text_input_owner==self and paper.pages==previous_pages,"failed arm acquisition restores paper and respects a foreign input lease")
	player.release_text_input(self)
	if check(interrupted.start(carrier,destination),"second diagnostic copy starts for priority interruption"):
		check(carrier.rig.typing_arm.program.size()==interrupted.text.length()+1,"retry after refused input ownership contains no duplicate command")
		await wait_for(func():return interrupted.cursor>=2,20)
		carrier.device.print_telegram_card({"title":"PRIORITY CONTROL","body":"Original field copy wins."})
		check(not interrupted.active and not interrupted.returned and paper.pages[0].contains("Original field copy wins."),"incoming field copy cancels automatic typing without restoring stale paper")
		check(register._owner==null and register.capacitor.get_shader_parameter("capacitor_charge")==0.0,"priority copy releases temporal readout and retires capacitor")
		check(carrier.session.draft==draft and accepted_count==1,"interruption neither submits the human draft nor accepts another date")
		await wait_for(func():return not carrier.arm_busy() and not paper.printing)
	interrupted.queue_free()
	# Exercise the uninterrupted success callback, not just Return acceptance.
	director=mount_director(Opening.with_target(late_phase(),destination))
	if check(director.begin_temporal_command(),"fresh late-phase diagnostic starts uninterrupted command"):
		console=director.temporal_console
		if check(await wait_for(func():return console.succeeded,40),"physical copy and arm complete without an artificial finish"):
			check(director.state.phase=="temporal_synchronization" and director.state.target==destination and not carrier.arm_busy() and not paper.printing,"only finished paper and retracted arm advance to sky synchronization")
			await get_tree().create_timer(.3).timeout
			await capture("temporal_completed.png")
			# Explicit end-of-visual seam diagnostic. No sky travel is claimed.
			check(director.finish_temporal_synchronization(),"director delegates the completed visual seam to the campaign clock owner")
			var clock:=CampaignClock.new()
			check(director.state.phase=="title_reveal" and director.state.effects.clock_applied and int(Time.get_unix_time_from_datetime_dict(clock.utc_datetime()))==int(destination.utc_unix_seconds),"live director advances only with exact clock-owner acknowledgement")
	director.shutdown();director.queue_free()
	FileAccess.open(directory.path_join("temporal_contacts.json"),FileAccess.WRITE).store_string(JSON.stringify({"destination":destination,"contacts":contact_keys,"accepted":accepted_count},"\t"))

func record_contact(character:String) -> void:
	contact_keys.append(character)
