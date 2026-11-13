extends Node3D
## The waking cell crawls and feels (Lily, 2026-11-13): on a bare floor with a
## post beside it and a wall across one side, the drawn cell wanders on its
## leash without entering either, and its cilia reach out to the post and
## straighten onto it. The colony itself never moves. Headless.

class StubColony:
	var seed := 11
	var source_id := "crawl_test"

var _fails := 0
var _checks := 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _box(at: Vector3, size: Vector3, label: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	add_child(body)
	return body


func _ready() -> void:
	_box(Vector3(0.0, -0.1, 0.0), Vector3(8.0, 0.2, 8.0), "Floor")
	# A post just beyond the rim on +X, inside the cilia's reach.
	var post := _box(Vector3(0.40, 0.15, 0.0), Vector3(0.06, 0.30, 0.06), "Post")
	# A wall across -Z, closer than the leash.
	_box(Vector3(0.0, 0.5, -0.75), Vector3(8.0, 1.0, 0.1), "Wall")
	var moss := DreamMossColonyRenderer.new()
	moss.colony = StubColony.new()
	moss.waking_style = true
	add_child(moss)
	# The stub is not a colony record; drive the waking presentation directly.
	moss.set_process(false)
	moss.set_physics_process(false)
	moss._build_waking()
	_check(moss._waking != null and moss._waking_cilia != null, "the cell is built")
	if moss._waking == null:
		_finish()
		return
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Feeling, before it moves: the post is in reach on one side only.
	moss._clock = 0.0
	moss._feel()
	var wanting := 0
	var on_post_side := 0
	for i in moss._cilia_roots.size():
		if moss._cilia_want[i] > 0.5:
			wanting += 1
			if (moss._cilia_roots[i].position as Vector3).x > 0.05:
				on_post_side += 1
	_check(wanting >= 2, "some cilia reach for the post (%d)" % wanting)
	_check(wanting == on_post_side, "only cilia on the post's side reach (%d of %d)" % [on_post_side, wanting])
	_check(wanting < moss._cilia_roots.size() / 4, "it feels, it does not grab: most cilia keep stepping (%d reach)" % wanting)
	for step in 90:
		moss._animate_touch(1.0 / 60.0)
	_check(moss.waking_touching() == wanting, "the reaching cilia arrive (%d)" % moss.waking_touching())
	var landed := 0
	for i in moss._cilia_roots.size():
		if moss._cilia_touch[i] < 0.99:
			continue
		# The headless renderer keeps no instance data; ask the owner for the pose.
		var pose: Transform3D = moss.waking_cilium_pose(i)
		# The straightened limb runs along the instance's +Y for its length.
		var tip := pose.origin + pose.basis.y.normalized() * moss.WAKING_LIMB_LENGTH * pose.basis.get_scale().y
		if tip.distance_to(moss._cilia_aim[i]) < 0.03 and absf(tip.x - 0.37) < 0.08:
			landed += 1
		_check(pose.basis.y.normalized().dot(Vector3.RIGHT) > 0.5, "a reaching cilium points at the post")
	_check(landed == wanting, "each reaching tip lands on the post (%d of %d)" % [landed, wanting])
	# Nothing to feel: they let go.
	post.position = Vector3(5.0, 0.15, 5.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	moss._feel()
	for step in 120:
		moss._animate_touch(1.0 / 60.0)
	_check(moss.waking_touching() == 0, "with nothing in reach the cilia go back to stepping")
	post.position = Vector3(0.40, 0.15, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Crawling: two simulated minutes.
	var rooted := moss.global_position
	var farthest := 0.0
	var entered := 0
	var rests := 0
	for step in 7200:
		moss._clock += 1.0 / 60.0
		if moss._crawl_rest > 0.0:
			rests += 1
		moss._crawl(1.0 / 60.0)
		var at: Vector3 = moss._waking.position
		farthest = maxf(farthest, at.length())
		if step % 30 == 0 and not moss._crawl_clear(at):
			entered += 1
	print("[WAKING CRAWL] travelled %.2f m, farthest %.2f m, resting %d of 7200 steps" % [moss._crawl_travelled, farthest, rests])
	_check(moss._crawl_travelled > 0.5, "it crawls (%.2f m in two minutes)" % moss._crawl_travelled)
	_check(moss._crawl_travelled < 0.022 * 120.0 + 0.01, "it crawls slowly (%.2f m)" % moss._crawl_travelled)
	_check(rests >= 90, "it stops to feel about (%d resting steps)" % rests)
	_check(farthest <= moss.WAKING_CRAWL_LEASH + 0.01, "it keeps to its leash (%.2f m)" % farthest)
	_check(entered == 0, "it never enters the post or the wall (%d bad places)" % entered)
	_check(absf(moss._waking.position.y) < 0.001, "it stays on the floor")
	_check(moss.global_position.is_equal_approx(rooted), "the colony stays rooted")
	_check(not moss._crawl_clear(Vector3(0.40, 0.0, 0.0)), "the post's place is not open floor")
	_check(not moss._crawl_clear(Vector3(0.0, 0.0, -0.75)), "the wall's place is not open floor")
	_check(not moss._crawl_clear(Vector3(0.0, 0.0, 6.0)), "off the floor is not open floor")
	_finish()


func _finish() -> void:
	print("[WAKING CRAWL] RESULT: %s (%d checks, %d failures)" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	get_tree().quit(0 if _fails == 0 else 1)
