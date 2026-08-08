extends Node
## Does PAIRS deal, match, and reveal a photograph the player took?
##
## Runs the whole loop headless-ish: stands in the lobby, takes four
## photographs with the handset's own camera, opens the cartridge, then
## drives it to a win by peeking at the deck the way no player can. The
## point is not the game logic in isolation — it is that the camera
## roll and the cartridge are actually joined, which is the only novel
## thing about this port.

var root: Node3D
var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.4).timeout
	_run()


func _run() -> void:
	var carrier = root.get("phone_carrier")
	var phone = carrier.phone
	var cam = phone.cam
	var pairs = phone.pairs

	# A roll with something in it, taken here, now.
	for p in cam.roll.duplicate():
		DirAccess.remove_absolute(str(p))
	cam.roll.clear()
	root.player.global_position = Vector3(-0.4, 0.0, 8.6)
	root.player.camera.make_current()
	phone.os_sim.screen = PhoneOS.Screen.APP
	phone.os_sim.app_id = "cam"
	phone.os_sim.gallery_open = false
	carrier.raised = true
	for i in 24:
		await get_tree().process_frame
	for i in 4:
		root.player.rotation.y = deg_to_rad(-150.0 + i * 45.0)
		for f in 10:
			await get_tree().process_frame
		cam.capture()
	_check("four photographs on the roll", cam.roll.size() == 4)

	# Deal, using the roll as the gallery.
	pairs.start(cam.roll, func(p): return cam.load_photo(p))
	_check("deck is %d cards" % (CartPairs.COLS * CartPairs.ROWS),
			pairs.deck.size() == CartPairs.COLS * CartPairs.ROWS)
	var counts := {}
	for f in pairs.deck:
		counts[f] = int(counts.get(f, 0)) + 1
	var all_two := true
	for k in counts:
		if int(counts[k]) != 2:
			all_two = false
	_check("every face appears exactly twice", all_two)
	_check("the veil covers a photograph the player took",
			pairs.reveal_tex != null)
	_check("nothing revealed before a move", pairs.matched == 0)

	# Play it out by looking at the deck, which a player cannot do.
	var seen := {}
	for i in pairs.deck.size():
		var f: int = pairs.deck[i]
		if seen.has(f):
			pairs.cursor = int(seen[f])
			pairs.key("ok")
			pairs.cursor = i
			pairs.key("ok")
			pairs.tick(0.02)
		else:
			seen[f] = i
	_check("all pairs matched", pairs.matched == CartPairs.PAIRS)
	_check("game reports won", pairs.state == CartPairs.State.WON)
	_check("moves counted honestly (%d)" % pairs.moves,
			pairs.moves == CartPairs.PAIRS)

	# A mismatch must turn back down rather than stay up.
	pairs.start(cam.roll, func(p): return cam.load_photo(p))
	var a := 0
	var b := -1
	for i in range(1, pairs.deck.size()):
		if pairs.deck[i] != pairs.deck[0]:
			b = i
			break
	pairs.cursor = a
	pairs.key("ok")
	pairs.cursor = b
	pairs.key("ok")
	_check("a wrong pair holds up to be read",
			pairs.facing[a] and pairs.facing[b])
	pairs.tick(1.0)
	_check("then turns back down",
			not pairs.facing[a] and not pairs.facing[b])

	print("[PAIRS] RESULT: %s (%d failures)"
			% ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
