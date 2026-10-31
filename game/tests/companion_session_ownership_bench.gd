extends "res://tests/companion_session_bench.gd"
## Overlapping waking roots may briefly contain two presentations, but only
## the current correspondence owner may publish a campaign snapshot.

func additional_checks() -> void:
	await key(KEY_ENTER)
	if not check(await wait_for(func(): return carrier.session.typing), "first owner takes native typing focus before handoff"): return
	await type_text(" a draft")
	var pending: String = carrier.session.draft
	var automatic_keys:Array[String]=["A"]
	check(not carrier.rig.typing_arm.begin(automatic_keys) and carrier.session.draft==pending,"typing arm cannot steal the human editor or its unsent draft")
	var old: Node = carrier
	var next := preload("res://scripts/device/companion_world_carrier.gd").new()
	await next.setup(player, player.camera, null)
	carrier = next
	player.carried_device = next
	check(old.session.retired and not old.session.typing and player.text_input_owner == null, "new presentation retires only the old typing lease")
	check(get_tree().get_nodes_in_group("companion_correspondence_owner").size() == 1 and next.session.draft == pending, "one campaign owner inherits the exact unsent native draft")
	next.session.dialogue.respond("thank you", {})
	next.session._snapshot()
	var expected: Dictionary = next.session.dialogue.memory.snapshot()
	old.session._snapshot()
	check(RealityState.data.companion.memory == expected, "retired snapshot callback cannot overwrite newer correspondence")
	check(old.is_capture_hidden() and not old.hand_is_enabled(), "retired presentation is hidden and cannot offer controls")
	await key(KEY_E)
	await wait_for(func(): return not carrier.device.teletype.printing)
	await key(KEY_ENTER)
	if not check(await wait_for(func(): return carrier.session.typing), "new owner explicitly resumes on its native keyboard"): return
	await select_all()
	await type_text("help")
	await key(KEY_ESCAPE)
	check(carrier.session.draft == "help" and not player.call_locked, "new owner keeps edited draft and releases its own focus")
	await key(KEY_ENTER)
	if not await wait_for(func(): return carrier.session.typing): return
	await select_all()
	await type_text("quiet please")
	await key(KEY_ENTER)
	check(not carrier.session.chatter_enabled and not carrier.reading, "actual quiet request silences optional remarks")
	await wait_for(func(): return not carrier.device.teletype.printing)
	await key(KEY_E)
	await key(KEY_ENTER)
	if not await wait_for(func(): return carrier.session.typing): return
	await type_text("help")
	await key(KEY_ESCAPE)
	check(carrier.session.draft == "help" and not carrier.session.chatter_enabled, "an unsent draft does not revoke the explicit quiet preference")
	var arm:Node=carrier.rig.typing_arm
	var draft_before:String=carrier.session.draft
	check(arm.begin(automatic_keys) and player.text_input_owner==arm,"explicit automatic typing obtains the existing exclusive input lease")
	carrier._advance_presentation(.016)
	check(arm.active(),"the companion does not mistake its own arm lease for a foreign protected conversation")
	carrier.witness._sample_left=0;carrier.witness._hesitation=19
	carrier.witness.observe(.3)
	check(carrier.witness._hesitation==0,"machine-owned input cannot become a witnessed player hesitation")
	var before:float=arm.elapsed
	get_tree().paused=true;arm.advance(1.0);get_tree().paused=false
	check(arm.elapsed==before and player.text_input_owner==arm,"pause retains the exact automatic pose and lease")
	player.call_locked=true;arm.advance(.016)
	check(player.text_input_owner==null and player.protected_input_active() and carrier.session.draft==draft_before,"protected conversation immediately retires only the arm input lease")
	check(await wait_for(func():return not arm.active(),3.0) and player.protected_input_active() and carrier.session.draft==draft_before,"protected conversation permits only bounded safe garage stow without unlocking the call")
	player.call_locked=false
	check(arm.begin(automatic_keys),"physical automatic cycle starts on the live foreground companion")
	var captured:=false
	var deadline:=Time.get_ticks_msec()+20000
	while arm.active() and Time.get_ticks_msec()<deadline:
		await frames(1)
		if not captured and arm.phase=="press":
			captured=true;await capture("automatic_arm.png")
	check(captured and not arm.active() and player.text_input_owner==null and carrier.session.draft==draft_before,"live foreground cycle finishes and returns input without rewriting the human draft")
	carrier.rig.request_keyboard(false)
	carrier.rig.keyboard_open=0;carrier.rig._apply_keyboard()
	check(arm.begin(automatic_keys),"stalled keyboard control begins with an owned input lease")
	arm.advance(0);arm.advance(arm.PREOPEN_END) # Garage clears; keyboard callback deliberately stalled.
	arm.advance(8.1)
	check(player.text_input_owner==null and carrier.session.draft==draft_before,"stalled keyboard releases only its own lease at the bounded opening deadline")
	for frame in 200:carrier.rig._advance_mechanism(1.0/120);arm.advance(1.0/120)
	check(not arm.active(),"stalled deployment closes its garage after releasing focus")
