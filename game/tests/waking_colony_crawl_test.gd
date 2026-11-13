extends Node3D
## The waking cell crawls and feels (Lily, 2026-11-13): on a bare floor with a
## post beside it, a wall across one side and a room it may not leave, the
## drawn cell roams without entering or leaving any of them; its cilia reach
## out to the post and straighten onto it, the limbs beside them turn to it as
## one, and the far side stands as it was. The colony itself never moves.
## Headless.

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

	# The bank of vapour round its foot.
	var vapor := moss._waking.find_child("WakingVapor", true, false) as MeshInstance3D
	_check(vapor != null, "the cell has its vapour")
	if vapor != null:
		var fog := vapor.material_override as ShaderMaterial
		_check(fog.shader.resource_path.ends_with("waking_colony_vapor.gdshader"), "the vapour is the purple bank")
		_check(fog.render_priority > 0, "the vapour is drawn over the membrane")
		_check(vapor.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the vapour casts no shadow")
		_check((fog.get_shader_parameter("vapor_color") as Color).is_equal_approx(moss.WAKING_VAPOR_COLOR), "it is the encroachment's purple")
		var cloud := fog.get_shader_parameter("cloud_tex") as Texture2D
		_check(cloud != null and cloud.get_image().has_mipmaps(), "its billows are a mipmapped map")
		var reach := vapor.mesh.get_aabb()
		_check(reach.position.y > 0.0 and reach.end.y <= moss.WAKING_VAPOR_TOP + 0.001 and reach.end.x > 0.5,
			"it lies low and wider than the cell")
	_check(moss.waking_cell_position().is_equal_approx(moss._waking.global_position), "the cell says where it is")
	# The mark it leaves on the floor.
	var trail := moss.find_child("WakingTrail", true, false) as MeshInstance3D
	_check(trail != null and trail.get_parent() == moss, "the trail lies with the colony, not on the cell")
	if trail != null:
		var mark := trail.material_override as ShaderMaterial
		_check(mark.shader.resource_path.ends_with("waking_colony_trail.gdshader"), "the trail is the negative of the floor")
		_check(mark.render_priority < 0, "the trail is drawn under the membrane and the vapour")
		_check(trail.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the trail casts no shadow")
		_check(is_equal_approx(float(mark.get_shader_parameter("fade_s")), moss.WAKING_TRAIL_FADE), "it is told how long a mark lasts")

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
	_check(wanting >= 6, "most of the cilia that can reach it do (%d)" % wanting)
	_check(wanting < moss._cilia_roots.size() / 4, "the rest of the cell keeps its places (%d reach)" % wanting)
	for step in 120:
		moss._animate_touch(1.0 / 60.0)
	_check(moss.waking_touching() == wanting, "the reaching cilia arrive (%d)" % moss.waking_touching())
	# One mind: limbs on the post's side that do not reach still turn to it,
	# and limbs on the far side do not stir.
	_check(is_equal_approx(moss._attend, 1.0), "the whole cell attends to what it has found")
	var turned := 0
	var near_side := 0
	var stirred_far := 0
	for i in moss._cilia_roots.size():
		if moss._cilia_touch[i] > 0.0:
			continue
		var at: Vector3 = moss._cilia_roots[i].position
		var rest_way: Vector3 = (moss._cilia_rest_basis[i] as Basis).y.normalized()
		var now_way: Vector3 = (moss.waking_cilium_pose(i) as Transform3D).basis.y.normalized()
		if at.x > 0.12:
			near_side += 1
			if now_way.dot(Vector3.RIGHT) > rest_way.dot(Vector3.RIGHT) - 0.0001 and now_way.distance_to(rest_way) > 0.01:
				turned += 1
		elif at.x < -0.05 and now_way.distance_to(rest_way) > 0.0001:
			stirred_far += 1
	_check(near_side > 0 and turned >= near_side * 3 / 4, "limbs beside the reaching ones turn toward the post (%d of %d)" % [turned, near_side])
	_check(stirred_far == 0, "limbs on the far side stand as they were (%d stirred)" % stirred_far)
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
	for step in 150:
		moss._animate_touch(1.0 / 60.0)
	_check(moss.waking_touching() == 0, "with nothing in reach the cilia go back to their places")
	var settled := true
	for i in moss._cilia_roots.size():
		if (moss.waking_cilium_pose(i) as Transform3D).basis.y.normalized().distance_to((moss._cilia_rest_basis[i] as Basis).y.normalized()) > 0.0001:
			settled = false
	_check(settled and moss._attend == 0.0, "and the cell stops attending")
	post.position = Vector3(0.40, 0.15, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Crawling: two simulated minutes in a room four metres square.
	moss.crawl_bounds = Rect2(-2.0, -2.0, 4.0, 4.0)
	var rooted := moss.global_position
	var farthest := 0.0
	var widest := 0.0
	var entered := 0
	var rests := 0
	var working := 0
	var standing := 0
	var most_marks := 0
	for step in 7200:
		moss._clock += 1.0 / 60.0
		if moss._crawl_rest > 0.0:
			rests += 1
		moss._crawl(1.0 / 60.0)
		moss._mark_trail()
		most_marks = maxi(most_marks, moss._trail_marks.size())
		if step % 18 == 0:
			moss._feel()
		if moss._crawl_effort > 0.3:
			working += 1
		elif moss._crawl_effort == 0.0:
			standing += 1
		var at: Vector3 = moss._waking.position
		farthest = maxf(farthest, at.length())
		widest = maxf(widest, maxf(absf(at.x), absf(at.z)))
		if step % 30 == 0 and not moss._crawl_clear(at):
			entered += 1
	print("[WAKING CRAWL] travelled %.2f m, farthest %.2f m, resting %d of 7200 steps" % [moss._crawl_travelled, farthest, rests])
	_check(moss._crawl_travelled > 0.5, "it crawls (%.2f m in two minutes)" % moss._crawl_travelled)
	_check(moss._crawl_travelled > 1.5, "it roams (%.2f m in two minutes)" % moss._crawl_travelled)
	_check(moss._crawl_travelled < moss.WAKING_CRAWL_SPEED * 120.0 + 0.01, "no faster than its pace (%.2f m)" % moss._crawl_travelled)
	_check(widest <= 2.0 - moss.WAKING_BODY_RADIUS + 0.01, "it keeps inside its room (%.2f m from the middle)" % widest)
	_check(working > 600 and standing > 60, "the cilia take up the work and lay it down (%d working, %d standing steps)" % [working, standing])
	_check(moss._crawl_heading.length() <= 1.001, "its heading is a direction")
	moss._animate_waking()
	var limb_material := moss._waking_cilia.material_override as ShaderMaterial
	_check(is_equal_approx(float(limb_material.get_shader_parameter("effort")), moss._crawl_effort)
		and (limb_material.get_shader_parameter("heading") as Vector2).is_equal_approx(moss._crawl_heading),
		"the cilia are told the cell's effort and heading")
	_check(is_equal_approx(float(limb_material.get_shader_parameter("cohorts")), moss.WAKING_COHORTS),
		"the cilia step in companies (%d)" % int(moss.WAKING_COHORTS))
	_check(rests >= 90, "it stops to feel about (%d resting steps)" % rests)
	_check(farthest <= moss.WAKING_CRAWL_LEASH + 0.01, "it keeps to its leash (%.2f m)" % farthest)
	_check(entered == 0, "it never enters the post or the wall (%d bad places)" % entered)
	_check(absf(moss._waking.position.y) < 0.001, "it stays on the floor")
	_check(moss.global_position.is_equal_approx(rooted), "the colony stays rooted")
	_check(moss.waking_cell_position().distance_to(rooted) > 0.05, "and the cell says where it has got to")
	# The trail: laid along the way, never more than it may keep, each mark
	# stamped, the newest where the cell is, and gone when its time is up.
	_check(most_marks >= 8 and most_marks <= moss.WAKING_TRAIL_MAX, "it marks the floor as it goes (%d marks at most)" % most_marks)
	var marks: Array = moss._trail_marks
	_check(not marks.is_empty() and (marks[-1].at as Vector3).distance_to(moss._waking.position) <= moss.WAKING_TRAIL_STEP + 0.001,
		"the newest mark is where the cell is")
	var ordered := true
	var fresh := true
	for i in marks.size():
		if i > 0 and float(marks[i].born) < float(marks[i - 1].born):
			ordered = false
		if moss._clock - float(marks[i].born) > moss.WAKING_TRAIL_FADE + 0.05:
			fresh = false
	_check(ordered and fresh, "marks are in the order they were laid and none is older than a mark lasts")
	# Each mark remembers the way the cell was going, so its ripples follow it.
	var headed := 0
	for i in range(1, marks.size()):
		var leg := (marks[i].at as Vector3) - (marks[i - 1].at as Vector3)
		var way: Vector2 = marks[i].way
		if is_equal_approx(way.length(), 1.0) and way.dot(Vector2(leg.x, leg.z).normalized()) > 0.999:
			headed += 1
	_check(marks.size() > 1 and headed == marks.size() - 1, "every mark carries the heading it was laid on (%d of %d)" % [headed, marks.size() - 1])
	var drawn := (trail.mesh as ArrayMesh).surface_get_arrays(0) if trail != null and trail.mesh.get_surface_count() > 0 else []
	_check(not drawn.is_empty() and (drawn[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == marks.size() * 4,
		"each mark is one disc on the floor")
	if not drawn.is_empty():
		var low := INF
		var high := -INF
		for point: Vector3 in drawn[Mesh.ARRAY_VERTEX]:
			low = minf(low, point.y)
			high = maxf(high, point.y)
		_check(low > 0.0 and high < 0.01, "the discs lie on the floor (%.4f to %.4f m)" % [low, high])
		_check(absf((drawn[Mesh.ARRAY_TEX_UV2] as PackedVector2Array)[0].x - float(marks[0].born)) < 0.01, "each disc carries when it was laid")
		var told := drawn[Mesh.ARRAY_COLOR] as PackedColorArray
		var last_way: Vector2 = marks[-1].way
		var read_back := Vector2(told[told.size() - 1].r, told[told.size() - 1].g) * 2.0 - Vector2.ONE
		_check(told.size() == marks.size() * 4 and read_back.distance_to(last_way) < 0.02, "each disc carries its heading to the shader")
	# It stands still for longer than a mark lasts: the floor is given back,
	# all but the mark it stands on.
	moss._crawl_rest = 1000.0
	for step in int((moss.WAKING_TRAIL_FADE + 2.0) * 60.0):
		moss._clock += 1.0 / 60.0
		moss._mark_trail()
	_check(moss._trail_marks.size() <= 1, "left alone, the floor goes back to itself (%d marks left)" % moss._trail_marks.size())
	_check(not moss._crawl_clear(Vector3(0.40, 0.0, 0.0)), "the post's place is not open floor")
	_check(not moss._crawl_clear(Vector3(0.0, 0.0, -0.75)), "the wall's place is not open floor")
	_check(not moss._crawl_clear(Vector3(0.0, 0.0, 6.0)), "off the floor is not open floor")
	_finish()


func _finish() -> void:
	print("[WAKING CRAWL] RESULT: %s (%d checks, %d failures)" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	get_tree().quit(0 if _fails == 0 else 1)
