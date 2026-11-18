extends "res://tests/carried_case_route_test.gd"
## Lily's strips on the Harukiya's bar in the production V2 root with real input:
## a click grabs the top strip, mouse motion draws it toward the customer, and drawn
## far enough it is bought for a penny into the comics pocket. Before a strip's day
## the pile has none; while the bar is shut, or the cash is short, nothing changes;
## a strip is sold once; and a kept strip is re-read from the case as a picture.

const Stack := preload("res://scripts/props/harukiya_strip_stack.gd")
const BEFORE := [1929, 11, 5]
const DAY := [1929, 11, 7]
const EIGHT_PM := 1200
const THREE_PM := 900

func _init() -> void:
	route_label = "HARUKIYA STRIP ROUTE"

func _at_date(date: Array, minute: int) -> void:
	CampaignClock.new().configure_date(date[0], date[1], date[2], minute)
	await get_tree().physics_frame

func _click() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	await get_tree().physics_frame

func _draw(stack: Node3D) -> void:
	var at: Vector3 = stack.top.global_position + Vector3.UP * 0.01
	player.camera.look_at(at)
	await get_tree().physics_frame
	player.camera.look_at(at)
	var grip: Dictionary = player._grab.find_target()
	if not _require(grip.get("owner") == stack and grip.get("part") == stack.top,
			"the player's ray reaches the top strip: %s" % str(grip.get("part"))):
		return
	await _click()
	_require(player._grab.active() and is_zero_approx(float(grip.read.call())), "a click grabs without drawing")
	for _step in 200:
		if not player._grab.active() or float(grip.read.call()) >= Stack.SLIDE * Stack.DRAWN_AT:
			break
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(0, 6)
		player._unhandled_input(motion)
		await get_tree().physics_frame
	if player._grab.active():
		await _click()
	await get_tree().create_timer(0.6).timeout

func _cash() -> int:
	return int(world.get_node("CaretakerEconomy").book().cash)

func _route() -> void:
	world.resident_agenda.enabled = false
	var stack: Node3D = world.harukiya_strips
	if not _require(stack != null and stack.top != null, "the Harukiya has a strip stack"): return
	player.global_position = stack.global_position + Vector3(0.0, -1.08, 1.25)
	await get_tree().physics_frame

	# Before the first strip's day there is nothing on the pile to draw.
	await _at_date(BEFORE, EIGHT_PM)
	await get_tree().create_timer(1.2).timeout
	_require(stack.on_pile().is_empty() and not stack.top.visible, "no strip is on the pile before its day")

	# The day comes: both strips are on the pile, newest on top. The bar is shut at three.
	await _at_date(DAY, THREE_PM)
	await get_tree().create_timer(1.2).timeout
	_require(stack.on_pile().size() == 2 and str(stack.on_pile()[0].id) == "strip_1929_11_07",
			"on its day the pile holds both strips, the newest on top: %s" % str(stack.on_pile()))
	var cash := _cash()
	await _draw(stack)
	_require(PaperPocket.book().strips.is_empty() and _cash() == cash, "while the bar is shut nothing is sold")
	_require(stack.notice.text == Stack.REFUSED.terminal_unavailable, "the bar says it is closed: %s" % stack.notice.text)

	# Open at eight: the top strip is bought for exactly a penny.
	await _at_date(DAY, EIGHT_PM)
	await _capture_interaction("harukiya_strips")
	await _draw(stack)
	_require(PaperPocket.has_strip("strip_1929_11_07") and _cash() == cash - 1,
			"the drawn strip is in the case and a penny is taken: %d -> %d" % [cash, _cash()])
	_require(not player._grab.active(), "the strip goes into the case: the hand has let go")
	_require(stack.on_pile().size() == 1, "one strip is left on the pile")

	# Short of a penny: refused, and nothing moves.
	world.get_node("CaretakerEconomy").book().cash = 0
	await _draw(stack)
	_require(not PaperPocket.has_strip("strip_1929_11_06") and _cash() == 0, "short cash buys nothing")
	_require(stack.notice.text == Stack.REFUSED.insufficient_funds, "the bar says why: %s" % stack.notice.text)
	world.get_node("CaretakerEconomy").book().cash = cash
	await _draw(stack)
	_require(PaperPocket.has_strip("strip_1929_11_06") and _cash() == cash - 1, "with cash again the second strip sells")
	await get_tree().create_timer(1.2).timeout
	_require(stack.on_pile().is_empty() and not stack.top.visible, "a strip is sold once: the pile is empty")

	# Re-read from the case: the newest strip first, held up as a picture.
	var catalog := get_tree().get_first_node_in_group("newspaper_catalog") as NewspaperCatalog
	var strips := PaperPocket.contents(catalog).filter(func(paper): return paper.get("strip", false))
	_require(strips.size() == 2 and str(strips[0].id) == "strip_1929_11_07" and str(strips[0].image) != "",
			"both strips are in the comics pocket, newest first: %s" % str(strips.map(func(paper): return paper.id)))
	var reader := PocketPaperPanel.new()
	add_child(reader)
	reader.open(strips[0])
	await get_tree().process_frame
	var art := reader.find_child("Strip", true, false) as TextureRect
	_require(art != null and art.texture != null and art.custom_minimum_size.x > art.custom_minimum_size.y * 2.0,
			"the strip is read as a picture, three panels wide")
	await _capture_interaction("harukiya_strip_read")
	reader.close()
