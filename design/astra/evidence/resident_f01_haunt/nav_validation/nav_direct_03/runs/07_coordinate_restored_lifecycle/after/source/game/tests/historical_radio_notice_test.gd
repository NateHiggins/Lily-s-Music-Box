extends Node3D
## Production notice component and physical control; no live broadcast claim.

const NoticeScript := preload("res://scripts/game/historical_radio_notice.gd")
const BoardScript := preload("res://scripts/props/lobby_bulletin_board.gd")
var failures := 0
var checks := 0
var _civil := {"valid": true, "year": 1928, "month": 11,
		"day_of_month": 11, "day": "sun", "civil_doy": 316, "doy": 315,
		"minute_of_day": 179.0}


func _check(ok: bool, label: String) -> void:
	checks += 1
	print("[%s] %s" % ["NOTICE OK" if ok else "NOTICE FAIL", label])
	if not ok:
		failures += 1


func _clock_info() -> Dictionary:
	return _civil.duplicate(true)


func _tap_stream(board: LobbyBulletinBoard) -> WeakRef:
	# Resource-valued temporaries must leave a synchronous frame; a suspended
	# GDScript coroutine can otherwise keep its own observation alive.
	return weakref(board._inspection_tap.stream)


func _live_shared_tap(board: LobbyBulletinBoard, reference: WeakRef) -> bool:
	return board._inspection_tap.playing and board._inspection_tap.stream == reference.get_ref()


func _released(reference: WeakRef) -> bool:
	return reference.get_ref() == null


func _ready() -> void:
	var notice = NoticeScript.new()
	var before: Dictionary = notice.copy_at(_civil)
	_check(before.notice_phase == "BEFORE" and str(before.body).contains("WEAF 610")
			and str(before.body).contains("WJZ 660") and str(before.body).contains("WOR 710"),
			"02:59 on the civil November 11 keeps the previous assignments")
	_civil.minute_of_day = 179.999
	_check(notice.copy_at(_civil).notice_phase == "BEFORE", "no early boundary rounding")
	_civil.minute_of_day = 180.0
	var after: Dictionary = notice.copy_at(_civil)
	_check(after.notice_phase == "AFTER" and str(after.body).contains("WEAF 660")
			and str(after.body).contains("WJZ 760") and str(after.body).contains("WOR 710"),
			"03:00 exactly applies the revised list and leaves WOR unchanged")
	_check(str(after.body).contains("WNYC / WMCA: 570")
			and str(after.body).contains("PROGRAMME HOURS NOT GIVEN"),
			"shared frequency makes no invented programme or on-air claim")
	_civil.day_of_month = 10
	_civil.minute_of_day = 1439.0
	_civil.doy = 316 # A wrong legacy key must never move a civil event.
	_check(notice.copy_at(_civil).notice_phase == "BEFORE", "legacy schedule doy is not the event calendar")
	_civil.day_of_month = 12
	_civil.minute_of_day = 15.0
	var late: Dictionary = notice.copy_at(_civil)
	var reconstructed_civil: Dictionary = JSON.parse_string(JSON.stringify(_civil))
	var reconstructed_notice = NoticeScript.new()
	_check(late == reconstructed_notice.copy_at(reconstructed_civil),
			"late arrival and resolver reconstruction preserve the same dated copy")
	_check(notice.copy_at({}).notice_phase == "UNRESOLVED"
			and str(notice.copy_at({}).condition).contains("READ DATE UNAVAILABLE"),
			"missing civil time never falls back to the host clock or a guessed date")
	var invalid_civil := _civil.duplicate(true)
	invalid_civil.minute_of_day = NAN
	_check(notice.copy_at(invalid_civil).notice_phase == "UNRESOLVED",
			"nonfinite civil time cannot select an assignment")
	var observations_before: Dictionary = RealityState.data.get("npc_observations", {}).duplicate(true)
	var clock_before: Dictionary = RealityState.data.get("campaign_clock", {}).duplicate(true)
	var board = BoardScript.new()
	board.bind_civil_time_provider(Callable(self, "_clock_info"))
	add_child(board)
	await get_tree().process_frame
	await get_tree().physics_frame
	var control := board.get_node_or_null("WirelessNoticeInspection") as Area3D
	_check(control != null and control.has_method("interact")
			and str(control.call("interact_prompt")) == "Read wireless tuning notice",
			"the production board mounts a separately reachable notice control")
	if control != null:
		var from := control.global_position + Vector3(0, 0, 1.5)
		var to := control.global_position - Vector3(0, 0, 0.3)
		var ray := PhysicsRayQueryParameters3D.create(from, to, 1)
		ray.collide_with_areas = true
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		_check(not hit.is_empty() and hit.collider == control,
				"the printed paper owns its inspection ray, not the old board rectangle")
		var printed := str(board.get_node("WirelessLicenseNotice/WirelessLicenseText").text)
		_civil.day_of_month = 11
		_civil.minute_of_day = 179.0
		var prior: Dictionary = control.call("interact", self)
		_civil.minute_of_day = 180.0
		var changed: Dictionary = control.call("interact", self)
		var card := TelegramHud.card_from_interaction(control, changed)
		_check(prior.notice_phase == "BEFORE" and changed.notice_phase == "AFTER"
				and card.card_id == "ny_radio_reallocation_1928_11_11",
				"the actual hand control reaches the existing service-wire presenter")
		_check(printed == str(board.get_node("WirelessLicenseNotice/WirelessLicenseText").text)
				and printed.contains("BEFORE") and printed.contains("FROM 3 A.M."),
				"the paper keeps both printed columns instead of rewriting at the boundary")
	_check(RealityState.data.get("npc_observations", {}) == observations_before
			and RealityState.data.get("campaign_clock", {}) == clock_before,
			"reading neither grants global NPC knowledge nor advances campaign time")
	_check(board.find_children("*", "AudioStreamPlayer3D", true, false).size() == 1,
			"the notice reuses the paper tap and adds no alleged historical broadcast")
	var neighbor = BoardScript.new()
	neighbor.bind_civil_time_provider(Callable(self, "_clock_info"))
	neighbor.position.x = 2.0
	add_child(neighbor)
	var shared_stream: WeakRef = _tap_stream(neighbor)
	neighbor.interact_control("wireless_notice", self)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(neighbor._inspection_tap.playing, "a neighboring board owns live paper-tap playback")
	# Complete the owner's scene-removal boundary before judging shutdown.
	remove_child(board)
	board.free()
	_check(_live_shared_tap(neighbor, shared_stream),
			"retiring one board preserves its live neighbor's playback and stream")
	remove_child(neighbor)
	neighbor.free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	_check(_released(shared_stream),
			"the final board releases its decoder resource without a global cache purge")
	print("[HISTORICAL RADIO NOTICE] RESULT: %s (%d/%d)" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
