extends Node
## Every minigame panel, on screen, once.
##
## Five games shipped with tests and none of their interfaces had ever
## been LOOKED AT. The rules were proven and the panels were assumed —
## which is exactly the arrangement that had a phone screen rendering
## perfectly behind its own casing for a session, and a torch mask that
## was never drawing at all. A panel can be laid out wrong, off-screen,
## black-on-black, or throwing every frame, and no rules test will ever
## notice.
##
## So: open each one against a real building, drive it to a state worth
## seeing rather than its blank first frame, and save a frame.
##
##   SHOT_DIR=<abs windows path> godot --path game \
##       res://tests/PanelShots.tscn
##
## Real window required. A CanvasLayer needs something to draw into.

var root: Node3D
var _dir := ""
var _fails := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	await _run()


func _shot(name: String) -> void:
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	if img.save_png(path) != OK:
		print("[PANELS] FAILED writing %s" % path)
		_fails += 1
	else:
		print("[PANELS] saved %s" % name)


func _run() -> void:
	var pl = root.player

	# ---- THE SONGBOOK ------------------------------------------------
	var song := SongResource.load_song("last_train_home")
	var sb = load("res://scripts/ui/songbook_panel.gd").new()
	sb.open(song, pl, null)
	get_tree().current_scene.add_child(sb)
	# Into the editor with a line typed, which is the screen that has to
	# carry the syllable map and the advice.
	sb.cursor = 0
	sb._show_edit()
	if sb._edit:
		sb._edit.text = "the last train home is never coming back"
		sb._on_typed(sb._edit.text)
	await _shot("p_01_songbook_editor")
	sb.close()

	# ---- THE RAINBOW ROUND -------------------------------------------
	var dp = load("res://scripts/ui/darts_panel.gd").new()
	dp.open(pl, null, "Cam")
	get_tree().current_scene.add_child(dp)
	# A thrown dart and the reveal, so the board, the slices and the
	# answer line are all on screen at once.
	dp.trivia.card = {"q": "Miles Davis, 1959. Kind of what?",
		"a": "blue", "kind": "named", "why": "Kind of Blue."}
	dp._landed = [Vector2(-96.0, -128.0), Vector2(28.0, 141.0)]
	dp.trivia.throw_for(0, -96.0, -128.0)
	dp.trivia.throw_for(1, 28.0, 141.0)
	dp.step = dp.Step.REVEAL
	dp._refresh()
	await _shot("p_02_rainbow_round")
	dp.close()

	# ---- POINT BALL --------------------------------------------------
	var pb = load("res://scripts/ui/point_ball_panel.gd").new()
	pb.open(pl, null, "Cam")
	get_tree().current_scene.add_child(pb)
	# Break the rack so the table is not fifteen balls in a triangle.
	pb.table.shoot(Vector2(1.0, 0.06).normalized(), 0.95)
	pb.table.resolve()
	pb._refresh()
	await _shot("p_03_point_ball")
	pb.close()

	# ---- DEAD LETTERS ------------------------------------------------
	var dl = load("res://scripts/ui/dead_letters_panel.gd").new()
	dl.open(pl, null)
	get_tree().current_scene.add_child(dl)
	# File one wrongly on purpose: the reveal is the interesting screen,
	# and a misfile is the one the game is built around remembering.
	var wrong := "6C"
	if str(dl.game.current().get("answer", "")) == wrong:
		wrong = "2B"
	dl.reveal = dl.game.file_into(wrong)
	dl._refresh()
	await _shot("p_04_dead_letters")
	dl.close()

	# ---- OTIS --------------------------------------------------------
	var ot = load("res://scripts/ui/otis_panel.gd").new()
	ot.open(pl, null)
	get_tree().current_scene.add_child(ot)
	# Put people on landings and the car between floors, so the shaft is
	# doing something rather than sitting at the lobby empty.
	ot.game.calls_enabled = false
	ot.game.waiting = [
		{"who": "Sacha Reed", "from": 6, "to": 1, "patience": 22.0},
		{"who": "Mina Vale", "from": 2, "to": 1, "patience": 9.0},
		{"who": "Cam Ortiz", "from": 4, "to": 1, "patience": 17.0},
		{"who": "Nadia Quell", "from": 5, "to": 7, "patience": 25.0},
	]
	ot.game.call_to(6)
	for i in 90:
		ot.game.tick(1.0 / 30.0)
	ot._refresh()
	await _shot("p_05_otis")
	ot.close()


	# ---- A BOOKSHELF -------------------------------------------------
	var bs = load("res://scripts/ui/bookshelf_panel.gd").new()
	var fake := BookshelfProp.new()
	fake.owner_name = "Mae Kessler"
	fake.sorter.load_library()
	fake.sorter.begin("Mae Kessler", 0.55, 42)
	bs.open(pl, fake)
	get_tree().current_scene.add_child(bs)
	bs.guessed = true          # show what the order is meant to be
	bs.shelf.touch(2)          # one down, so the gap reads
	bs._hover = 2
	bs._refresh()
	await _shot("p_06_bookshelf")
	bs.close()

	print("[PANELS] RESULT: %s" % ["PASS" if _fails == 0 else "FAIL"])
	get_tree().quit(_fails)
