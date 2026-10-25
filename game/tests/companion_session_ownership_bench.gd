extends "res://tests/companion_session_bench.gd"
## Overlapping waking roots may briefly contain two presentations, but only
## the current correspondence owner may publish a campaign snapshot.

func additional_checks() -> void:
	await key(KEY_ENTER)
	if not check(await wait_for(func(): return carrier.session.typing), "first owner takes native typing focus before handoff"): return
	await type_text(" a draft")
	var pending: String = carrier.session.draft
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
