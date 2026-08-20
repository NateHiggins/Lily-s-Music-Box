extends Node
## THE REPRODUCTIVE PATH, PROVED AS DATA AND AS GEOMETRY.
##
## This suite does not judge whether the result is beautiful; the committed
## render does that. It proves the facts a frame can conceal: inheritance is
## bounded, siblings are not clones, the old topology did not move, every live
## room pays exactly one surface, sealed possibilities become buds, the shared
## parent aperture carries the child's genome on both sides, and the organism
## cannot collide with the player.

var checks := 0
var failures := 0


func _ready() -> void:
	print("[LINEAGE] START")
	_data_contract()
	_geometry_contract()
	print("[LINEAGE] CHECKS: %d/%d fails=%d" %
			[checks - failures, checks, failures])
	print("DREAM LINEAGE TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(failures)


func _atlas(seed_hex: String = "f123456789abcdef",
		case_key: String = "mina_caption_crisis") -> DreamAtlas:
	var atlas := DreamAtlas.new()
	atlas.setup(seed_hex, 7, case_key)
	return atlas


func _data_contract() -> void:
	var atlas := _atlas()
	var other := _atlas()
	var parent_path := PackedInt32Array([1, 0, 2, 1, 3])
	var child_path := DreamAtlas.step(parent_path, 2)
	var sibling_path := DreamAtlas.step(parent_path, 3)
	var parent := atlas.lineage(parent_path)
	var child := atlas.lineage(child_path)
	var sibling := atlas.lineage(sibling_path)

	_check("the same lineage reconstructs exactly",
			child == atlas.lineage(child_path) and child == other.lineage(child_path))
	_check("generation is the number of reproductive choices",
			int(child.generation) == child_path.size())
	_check("the child names its actual parent room",
			int(child.parent_room_id) == atlas.room_id(parent_path))
	_check("the birth door is carried as ancestry", int(child.birth_door) == 2)
	_check("siblings are distinct descendants",
			int(child.genome_id) != int(sibling.genome_id))
	_check("a child mutates phase by at most the ruled step",
			_angle_distance(float(parent.phase), float(child.phase)) <= 0.34001)
	_check("a child mutates curl by at most the ruled step",
			absf(float(parent.curl) - float(child.curl)) <= 0.05501)
	_check("a child mutates girth by at most the ruled step",
			absf(float(parent.girth) - float(child.girth)) <= 0.00351)
	_check("a child mutates pulse by at most the ruled step",
			absf(float(parent.pulse_hz) - float(child.pulse_hz)) <= 0.00301)
	_check("the pulse is always slow enough to be breath, never flash",
			float(child.pulse_hz) >= 0.065 and float(child.pulse_hz) <= 0.105)
	_check("handedness is an inherited sign",
			absi(int(child.handedness)) == 1)
	var other_case := _atlas("f123456789abcdef", "juno_stolen_channel")
	_check("a different attachment grows a different lineage",
			int(other_case.lineage(child_path).genome_id) != int(child.genome_id))

	# The visible genome is additive. The room's old golden identity is pinned
	# by DreamAtlasTest; this restates the important boundary locally.
	var before_id := atlas.room_id(child_path)
	var room := atlas.room(child_path)
	_check("lineage exists on the room record", room.has("lineage"))
	_check("reading lineage cannot alter room identity",
			before_id == atlas.room_id(child_path) and int(room.id) == before_id)


func _geometry_contract() -> void:
	var atlas := _atlas()
	var builder := DreamRoomBuilder.new()
	builder.setup(atlas, [])
	var plot := Node3D.new()
	add_child(plot)
	var path := PackedInt32Array([1, 0, 2, 1, 3])
	builder.advance(plot, path)

	var bodies := 0
	var malformed := 0
	var collision_nodes := 0
	var joined_child_genomes := 0
	var live_by_key := {}
	for room_value in builder.live_rooms():
		var live_room: Dictionary = room_value
		live_by_key[str(live_room.key)] = live_room
	var found_bodies := plot.find_children("LineageBody", "MeshInstance3D",
			true, false)
	bodies = found_bodies.size()
	for found_body in found_bodies:
		var body := found_body as MeshInstance3D
		var room_key := str(body.get_meta("room_key", ""))
		var room: Dictionary = live_by_key.get(room_key, {})
		if room.is_empty():
			print("[LINEAGE] unmatched body parent=%s keys=%s"
					% [str(body.get_parent().name), str(live_by_key.keys())])
			malformed += 1
			continue
		if body.mesh == null or int(body.get_meta("surfaces", 0)) != 1:
			print("[LINEAGE] malformed mesh room=%s mesh=%s surfaces=%s"
					% [room_key, str(body.mesh),
					str(body.get_meta("surfaces", -1))])
			malformed += 1
		var material := body.material_override as ShaderMaterial
		if material == null or material.shader == null \
				or material.shader.get_shader_uniform_list().is_empty():
			print("[LINEAGE] lineage gold shader did not compile in %s" % room_key)
			malformed += 1
		if int(body.get_meta("branch_count", -1)) != room.doors.size():
			print("[LINEAGE] branch mismatch room=%s meta=%s doors=%d"
					% [room_key, str(body.get_meta("branch_count", -1)),
					room.doors.size()])
			malformed += 1
		var sealed := 0
		for door in room.doors:
			if bool(door.sealed):
				sealed += 1
		if int(body.get_meta("sealed_buds", -1)) != sealed:
			print("[LINEAGE] bud mismatch room=%s meta=%s sealed=%d"
					% [room_key, str(body.get_meta("sealed_buds", -1)), sealed])
			malformed += 1
		collision_nodes += body.find_children("*", "CollisionObject3D", true,
				false).size()
		var roles: Array = body.get_meta("branch_roles", [])
		var genomes: Array = body.get_meta("branch_genomes", [])
		for i in roles.size():
			if str(roles[i]) == "parent" \
					and int(genomes[i]) == int(room.lineage.genome_id):
				joined_child_genomes += 1
		print("[LINEAGE] room=%s roles=%s genomes=%s own=%s"
				% [room_key, str(roles), str(genomes),
				str(room.lineage.genome_id)])

	_check("every live room has exactly one lineage body",
			bodies == builder.live_rooms().size())
	_check("every lineage body is one populated mesh surface", malformed == 0)
	_check("the anatomy carries no collision", collision_nodes == 0)
	_check("remembered parent joins wear the child's genome on this side",
			joined_child_genomes > 0)

	# A sealed door depends on pocket overlap and this particular live
	# neighbourhood need not have one. Force the already-valid authored state
	# on a disposable room and prove its geometric reading directly.
	var bud_plot := Node3D.new()
	add_child(bud_plot)
	var bud_room := builder.describe(PackedInt32Array([3, 2, 1, 0, 2, 3]))
	bud_room.doors[0].sealed = true
	bud_room.doors[0].leads_to = ""
	var bud_node := builder.build(bud_plot, bud_room)
	var bud_body := bud_node.find_child("LineageBody", false, false) \
			as MeshInstance3D
	_check("a sealed possibility becomes one closed bud",
			bud_body != null and int(bud_body.get_meta("sealed_buds", 0)) == 1)

	var first := plot.find_child("LineageBody", true, false) as MeshInstance3D
	_check("the organism is suspended above the player's body",
			first != null and first.get_aabb().position.y > 0.10)
	var old_scale := first.scale if first != null else Vector3.ONE
	if first != null:
		first.call("_process", 1.0)
	_check("the body breathes without changing topology",
			first != null and first.scale != old_scale
			and float(first.get_meta("pulse_hz", 1.0)) <= 0.105)
	bud_plot.free()
	plot.free()


func _angle_distance(a: float, b: float) -> float:
	return absf(wrapf(b - a, -PI, PI))


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  ok   %s" % label)
	else:
		failures += 1
		printerr("  FAIL %s" % label)
