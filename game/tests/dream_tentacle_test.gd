extends Node
## Contract for the Dream tentacle (design/DREAM_TENTACLE_DIRECTION.md): the
## rig, the behaviour's states, the eye, the suckers, the membrane, the
## contact conversion into the living field, the lights, the withdrawal.
##     godot --headless --path game res://tests/DreamTentacleTest.tscn
var checks := 0
var failures := 0
var root: Node3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("ENCROACH_FORCE", "mina:0.9")
	OS.set_environment("LIVING_ALL", "1")
	OS.set_environment("TENTACLE_FORCE", "1")
	OS.set_environment("TENTACLE_HOLD", "1")
	# 2A's west wall between the sofa and the radiator, facing into the room.
	OS.set_environment("TENTACLE_ANCHOR", "-13.62,4.75,4.35,1,0,0")
	OS.set_environment("ENCROACH_DEBUG", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(3.5).timeout
	var enc: Node = root.get("apartment_encroachment")
	_check("the encroachment exists", enc != null)
	if enc == null:
		return _finish()
	var live: Array = enc.tentacles.get("F02", [])
	_check("a forced case puts a tentacle out on its storey", live.size() >= 1)
	if live.is_empty():
		return _finish()
	var t: Node = live[0]
	var flesh: MeshInstance3D = t.get_node_or_null("Flesh")
	_check("the body is a detailed mesh under the Dream entity stack", flesh != null
			and flesh.mesh.get_faces().size() >= 12000
			and (flesh.material_override as ShaderMaterial).shader.resource_path.ends_with("dream_tentacle.gdshader"))
	_check("the anatomy is composed: skeleton, dendrites, the ocular organ (globe, cornea, orbital gold, cilia, crystal, three lids), suckers, halos, membrane",
			t.get_node_or_null("GoldPiece0") != null and t.get_node_or_null("GoldPiece5") != null and t.get_node_or_null("GoldDendrites") != null
			and t.get_node_or_null("Eye") != null and t.get_node_or_null("Cornea") != null
			and t.get_node_or_null("OrbitalGold") != null and t.get_node_or_null("OrbitalCilia") != null
			and t.get_node_or_null("CrystalOrgan") != null and t.get_node_or_null("Lid0") != null
			and t.get_node_or_null("Lid1") != null and t.get_node_or_null("Lid2") != null
			and t.get_node_or_null("Suckers") != null and t.get_node_or_null("Halos") != null
			and t.get_node_or_null("Membrane") != null)
	_check("it anchors on the wall with its normal into the room",
			(t.anchor_normal as Vector3).dot(Vector3.RIGHT) > 0.99)
	_check("it finds the radiator interesting: " + str(t.target_name),
			t.sensor.target_profile != null and str(t.target_name).to_lower().contains("radiator"))
	# The silhouette profile is not a tube: radius, flatten and twist vary.
	var prof: PackedVector4Array = t.rig.prof
	var flat_max := 0.0
	var twist_max := 0.0
	var r_min := 9.0
	var r_max := 0.0
	for p in prof:
		flat_max = maxf(flat_max, p.y)
		twist_max = maxf(twist_max, p.z)
		r_min = minf(r_min, p.x)
		r_max = maxf(r_max, p.x)
	_check("the silhouette profile varies along the length (flatten %.2f twist %.2f radius %.2f..%.2f)"
			% [flat_max, twist_max, r_min, r_max], flat_max > 0.3 and twist_max > 1.0 and r_max - r_min > 0.3)
	# The states, in order: membrane bulge, emergence, orienting, seeking...
	var seen: Array[String] = [t.state_name()]
	var waited := 0.0
	while waited < 40.0 and t.state_name() not in ["CARESSING", "TASTING", "RESTING"]:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
		if t.state_name() != seen[seen.size() - 1]:
			seen.append(t.state_name())
	print("[tentacle] states: %s" % ", ".join(seen))
	_check("it goes through the membrane, orients, seeks, approaches, hovers and touches (%s)" % ", ".join(seen),
			"EMERGING" in seen and "SEEKING" in seen and "APPROACHING" in seen
			and "HOVER_INSPECTION" in seen and "TOUCHING" in seen and "CARESSING" in seen)
	_check("it is through (grow %.2f)" % float(t.grow), float(t.grow) >= 0.95)
	var c: Dictionary = t.census()
	var sp0: Vector3 = t.rig.pos[0]
	var sp15: Vector3 = t.rig.pos[15]
	var mid: Vector3 = t.rig.pos[8]
	print("[tentacle] spine span root=%s mid=%s tip=%s" % [sp0, mid, sp15])
	print("[tentacle] ocular at %s  gaze %s  anchor %s" % [t.ocular.position, t.ocular.gaze, t.anchor])
	_check("the tip is on the contact, within reach (%.3f m off, %.2f m out)"
			% [(c.tip as Vector3).distance_to(c.contact), (c.tip as Vector3).distance_to(c.anchor)],
			(c.tip as Vector3).distance_to(c.contact) < 0.13
			and (c.tip as Vector3).distance_to(c.anchor) <= 1.5)
	_check("the eye is open and watching (%.2f)" % float(c.eye_open), float(c.eye_open) > 0.6)
	_check("the suckers near the tip are engaged (%d)" % int(c.suckers_engaged), int(c.suckers_engaged) >= 3)
	_check("the membrane clings around the root, not a hole", float(t.membrane.through) > 0.5
			and (t.get_node("Membrane") as MeshInstance3D).visible)
	# Conversion: the substance is in the field at the contact.
	waited = 0.0
	while waited < 8.0 and int(t.deposits) < 2:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	_check("the touch converts matter into the field (%d deposits)" % int(t.deposits), int(t.deposits) >= 2)
	var field = enc.fields.get("F02")
	var cc: Vector3 = c.contact
	var survey: Array = field.survey(Vector4(cc.x - 0.6, cc.z - 0.6, cc.x + 0.6, cc.z + 0.6))
	_check("the field holds it in the source's ink", int(survey[int(t.source_index)].count) >= 1)
	var eye_l: OmniLight3D = t.get_node_or_null("EyeLight")
	var gold_l: OmniLight3D = t.get_node_or_null("GoldLight")
	var contact_l: OmniLight3D = t.get_node_or_null("ContactLight")
	_check("its gold, eye and sucker rims cast light", eye_l != null and gold_l != null and contact_l != null
			and eye_l.light_energy > 0.3 and gold_l.light_energy > 0.2 and contact_l.visible)
	# The length holds: joints a segment apart, sides orthonormal.
	var pos: PackedVector3Array = t.rig.pos
	var side: PackedVector3Array = t.rig.side
	var seg := float(t.behavior_profile.length_m) / 15.0
	var well := true
	var total := 0.0
	for i in 15:
		var d: float = pos[i + 1].distance_to(pos[i])
		total += d
		var tng: Vector3 = (pos[i + 1] - pos[i]).normalized()
		well = well and d <= seg * 1.06 and absf(side[i].dot(tng)) < 0.2 and absf(side[i].length() - 1.0) < 0.01
	_check("the rig keeps its length (%.2f m of %.2f) with transported sides" % [total, t.behavior_profile.length_m],
			well and total > float(t.behavior_profile.length_m) * 0.6)
	# The player at arm's reach: it flinches, then watches.
	var who: Node3D = root.get("player")
	if who != null:
		who.global_position = (c.tip as Vector3) + Vector3(0.5, 0.0, 0.0)
		await get_tree().create_timer(0.6).timeout
		var flinched: bool = t.state_name() in ["FLINCH", "WATCH_PLAYER"]
		_check("the player at arm's reach makes it flinch and watch (%s)" % t.state_name(), flinched)
		who.global_position = (c.tip as Vector3) + Vector3(4.0, 0.0, 4.0)
	# Cost.
	var t0 := Time.get_ticks_usec()
	for _i in 30:
		t._tick(1.0 / 60.0)
	var per := float(Time.get_ticks_usec() - t0) / 30.0 / 1000.0
	_check("a frame of it costs under 1.2 ms on the CPU (%.3f ms)" % per, per < 1.2)
	# Withdraw.
	t.withdraw()
	await get_tree().create_timer(3.6).timeout
	_check("withdrawn, it is gone", not is_instance_valid(t) or t.is_queued_for_deletion())
	_finish()


func _finish() -> void:
	print("DREAM TENTACLE TEST: %s (%d/%d)" % ["PASS" if failures == 0 else "FAIL",
			checks - failures, checks])
	get_tree().quit(failures)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("[tentacle ok] " + label)
	else:
		failures += 1
		printerr("[TENTACLE FAIL] " + label)
