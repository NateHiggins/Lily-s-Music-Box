extends Node
## Does Shattered break a picture into glass that tiles it exactly, and
## can every piece be put back?
##
## The load-bearing check is COVERAGE. The pieces come from a jittered
## grid, and the whole reason it is a grid is that neighbours share
## their wandered corners — get that wrong and the triangles no longer
## meet, so the reassembled picture has hairline gaps of background
## running through it. That reads as a rendering artefact rather than a
## geometry bug, and it would be chased in the shader for an afternoon.
## So this samples points across the frame and demands every one of them
## land inside some piece.
##
## REAL WINDOW REQUIRED — no --headless. The picture comes from the
## handset's camera, which photographs the world through a SubViewport,
## and headless has nothing to read back:
##
##   godot --path game res://tests/CartShardsTest.tscn

const PANEL := Rect2(10, 32, 460, 304)

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


func _in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var s1 := (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
	var s2 := (c.x - b.x) * (p.y - b.y) - (c.y - b.y) * (p.x - b.x)
	var s3 := (a.x - c.x) * (p.y - c.y) - (a.y - c.y) * (p.x - c.x)
	return (s1 >= 0.0 and s2 >= 0.0 and s3 >= 0.0) 			or (s1 <= 0.0 and s2 <= 0.0 and s3 <= 0.0)


## Every sample point must be covered by some piece's HOME position.
func _uncovered(g: CartShards, rect: Rect2) -> int:
	var misses := 0
	for iy in 24:
		for ix in 32:
			var p := Vector2(
					rect.position.x + (ix + 0.5) * rect.size.x / 32.0,
					rect.position.y + (iy + 0.5) * rect.size.y / 24.0)
			var hit := false
			for s in g.shards:
				var pts: PackedVector2Array = s["pts"]
				if _in_tri(p, pts[0], pts[1], pts[2]):
					hit = true
					break
			if not hit:
				misses += 1
	return misses


func _run() -> void:
	var carrier = root.get("phone_carrier")
	var phone = carrier.phone
	var cam = phone.cam
	var g: CartShards = phone.shards

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
	for i in 3:
		root.player.rotation.y = deg_to_rad(-150.0 + i * 50.0)
		for f in 10:
			await get_tree().process_frame
		cam.capture()
	_check("three photographs on the roll", cam.roll.size() == 3)

	g.start(cam.roll, func(p): return cam.load_photo(p), 12)
	g.layout(PANEL)
	_check("twelve pieces of glass", g.shards.size() == 12)
	_check("a photograph waits under the cracks", g.art_tex != null)

	# The invariant.
	_check("the pieces tile the frame with no gaps",
			_uncovered(g, PANEL) == 0)

	# And at the harder break, where a wrong grid has more chances.
	g.start(cam.roll, func(p): return cam.load_photo(p), 24)
	g.layout(PANEL)
	_check("twenty-four pieces of glass", g.shards.size() == 24)
	_check("the harder break tiles the frame too",
			_uncovered(g, PANEL) == 0)

	# Nothing starts seated, and nothing starts outside the frame.
	g.start(cam.roll, func(p): return cam.load_photo(p), 12)
	g.layout(PANEL)
	_check("every piece starts loose", g.locked_count() == 0)
	var scattered := true
	var inside := true
	for s in g.shards:
		var off: Vector2 = s["off"]
		if off.length() < 1.0:
			scattered = false
		var lo: Vector2 = s["lo"] + off
		var hi: Vector2 = s["hi"] + off
		if lo.x < PANEL.position.x - 0.5 or lo.y < PANEL.position.y - 0.5:
			inside = false
		if hi.x > PANEL.position.x + PANEL.size.x + 0.5:
			inside = false
		if hi.y > PANEL.position.y + PANEL.size.y + 0.5:
			inside = false
	_check("every piece starts away from its hole", scattered)
	_check("no piece starts outside the frame", inside)

	# A piece nudged near its hole and left alone must be drawn in.
	var one: Dictionary = g.shards[0]
	one["off"] = Vector2(CartShards.SNAP_DIST * 0.5, 0.0)
	one["v"] = Vector2.ZERO
	g.tilt_ax = 0.0
	g.tilt_ay = 0.0
	g.tick(0.016)
	_check("a piece close and slow is drawn in", one["locked"])
	_check("and it seats exactly, not approximately",
			(one["off"] as Vector2).length() == 0.0)

	# A piece close but flying must NOT stick.
	var two: Dictionary = g.shards[1]
	two["off"] = Vector2(CartShards.SNAP_DIST * 0.5, 0.0)
	two["v"] = Vector2(CartShards.SNAP_SPEED * 4.0, 0.0)
	g.tick(0.016)
	_check("a piece travelling too fast passes over its hole",
			not two["locked"])

	# Seat the rest and the picture is whole.
	for s in g.shards:
		if not s["locked"]:
			s["off"] = Vector2.ZERO
			s["v"] = Vector2.ZERO
	g.tick(0.016)
	_check("seating every piece finishes the picture",
			g.state == CartShards.State.WON)
	_check("the count agrees (%d/%d)"
			% [g.locked_count(), g.shards.size()],
			g.locked_count() == g.shards.size())

	# Breaking it again keeps the picture but makes new cracks.
	var before: PackedVector2Array = g.shards[0]["pts"]
	var kept := g.art_tex
	g.key("ok")
	_check("enter breaks it again", g.state == CartShards.State.PLAY)
	_check("the same picture, freshly broken",
			g.art_tex == kept and g.shards[0]["pts"] != before)

	print("[SHARDS] RESULT: %s (%d failures)"
			% ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
