extends "res://tests/carried_case_route_test.gd"
## The two clue carriers in the V2 root with the real hand: neither moves before its date; a
## part-way draw finds nothing; a full draw grants the clue. The drain's work order waits in
## the box for its day.

const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")
const Carriers := preload("res://scripts/building/orison_v2_clue_carriers.gd")

func _init() -> void:
	route_label = "CLUE CARRIERS ROUTE"

func _date(month: int, day: int) -> void:
	CampaignClock.new().configure_date(1929, month, day, 12 * 60)
	await get_tree().process_frame

func _stand(prop: Node3D) -> void:
	var front: Vector3 = prop.global_position + prop.global_basis * Vector3.BACK * 0.85
	var hit := prop.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(front, front + Vector3.DOWN * 3.0))
	player.global_position = hit.position + Vector3.UP * 0.05 if not hit.is_empty() else front
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.camera.look_at(prop.part.global_position)
	await get_tree().physics_frame

func _due_mail(bank: MailBankProp) -> Array:
	return bank.pending().map(func(item): return str(item.id))

func _route() -> void:
	var carriers: Dictionary = world.clue_carriers
	if not _require(not carriers.is_empty(), "the carriers are mounted"): return
	var hand: Node = Hands.new()
	hand.set_meta("shared_world_validation", true)
	add_child(hand)
	hand.player = player

	var books: Node3D = carriers.notebooks
	await _date(7, 1)
	Carriers.refresh_spines(books)
	await _stand(books)
	await _capture_interaction("notebooks_early")
	_require(books.grip().is_empty(), "the July book isn't there on 1 July")
	_require(not books.get_node("Book_1").visible, "and it can't be seen")
	await _date(8, 6)
	Carriers.refresh_spines(books)
	await _stand(books)
	await _capture_interaction("notebooks")
	await hand.aim(books.part.global_position)
	hand.click()
	if not _require(player._grab.active() and player._grab.target.part == books.part, "the hand takes the book"): return
	await hand._gesture_to(books.reach * 0.4)
	hand.click()
	_require(not RealityState.has_knowledge("m_notebook_spine"), "a part-way draw reads nothing")
	await get_tree().create_timer(0.8).timeout
	_require(books.travel < 0.01, "the book goes back")
	await hand.aim(books.part.global_position)
	hand.click()
	await hand._gesture_to(books.reach)
	if player._grab.active():
		hand.click()
	_require(RealityState.has_knowledge("m_notebook_spine"), "drawing it out reads the spine")
	await _capture_interaction("notebooks_read")

	var bank: MailBankProp = null
	for found: Node in get_tree().get_nodes_in_group("mail_bank"):
		bank = found
	if not _require(bank != null, "the mail bank is in the world"): return
	var drain: Node3D = carriers.drain
	_require(not _due_mail(bank).has("work_order_yard_drain"), "no work order the day before")
	_require(drain.grip().is_empty(), "the clean-out isn't due")
	await _date(8, 7)
	_require(_due_mail(bank).has("work_order_yard_drain"), "the work order is in the box")
	await _stand(drain)
	await _capture_interaction("drain")
	await hand.aim(drain.part.global_position)
	hand.click()
	if not _require(player._grab.active() and player._grab.target.part == drain.part, "the hand takes the plug"): return
	await hand._gesture_to(drain.reach)
	if player._grab.active():
		hand.click()
	_require(RealityState.has_knowledge("m_glove_scrap"), "the trap gives up the scrap")
	await _capture_interaction("drain_cleared")
