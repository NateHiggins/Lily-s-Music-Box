extends Node
## SR7-Q — the door check, on a bench, with a real leaf hung next to it.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/DoorCheckTest.tscn `
##         -ProjectPath <checkout>/game
##
## THE ONE CLAIM THIS SUITE EXISTS FOR:
##
##     A DOOR THAT CAN BE SHUT IS NOT A DOOR THAT WILL CLOSE ITSELF.
##
## Every leaf in the Orison can be shut by a hand. Exactly one of them has a
## closer on it, and until this suite is satisfied that closer does no work at
## all — because its arm is off its spindle, which you can see from the floor.
##
## What is proved here rather than in production:
##
##   * as found, the closer is complete to look at and connected to nothing;
##   * a leaf pushed shut by hand does not make it self-closing, and the
##     apparatus says so in as many words;
##   * a closer that cannot deliver a close DOES NOT ASK FOR ONE — it lets the
##     leaf stand and records that it stopped short;
##   * the arm cannot be shipped with the spring live;
##   * a LOCKED leaf is refused, never opened, and never unlocked;
##   * `DoorProp` remains the only thing in the world that moves a leaf: the
##     closer's entire vocabulary against the door is `npc_set_open`;
##   * abort puts this apparatus back and does not touch the door;
##   * and the refusals are five different photographs, not one shrug.

const CloserScript := preload("res://scripts/props/door_check_closer_prop.gd")
const CLOSER_PATH := "res://scripts/props/door_check_closer_prop.gd"

var failures := 0
var checks := 0


## A leaf that answers like `DoorProp` and writes down every word said to it.
## The real door proves what HAPPENS; this proves what was ASKED.
class SpyDoor:
	extends Node3D
	var open := false
	var leaf_state := "closed"
	var _moving := false
	var heard: Array[String] = []

	func npc_set_open(want_open: bool) -> void:
		heard.append("npc_set_open(%s)" % want_open)
		if leaf_state == "locked" or _moving or open == want_open:
			return
		open = want_open

	func interact(_player: Node) -> void:
		heard.append("interact")

	func _rattle() -> void:
		heard.append("_rattle")


func _ready() -> void:
	RealityState.persistence_enabled = false
	await get_tree().process_frame
	await _as_found()
	await _shutting_by_hand_proves_nothing()
	await _refusals()
	await _the_port_decides()
	await _one_owner_of_the_leaf()
	await _abort()
	_poses()
	_source_discipline()
	_finish()


func _bench() -> Array:
	var door := DoorProp.new()
	door.width = 0.96
	door.height = 2.10
	door.door_kind = "service"
	door.finish_variant = 2
	add_child(door)
	var closer: Node = CloserScript.new()
	closer.prop_type = "door_check_closer"
	closer.door_path = NodePath("..")
	door.add_child(closer)
	await get_tree().process_frame
	return [door, closer]


func _spy_bench() -> Array:
	var door := SpyDoor.new()
	add_child(door)
	var closer: Node = CloserScript.new()
	closer.prop_type = "door_check_closer"
	closer.door_path = NodePath("..")
	door.add_child(closer)
	await get_tree().process_frame
	return [door, closer]


func _settle() -> void:
	await get_tree().create_timer(0.65).timeout


# --- as found ----------------------------------------------------------------

func _as_found() -> void:
	var bench := await _bench()
	var closer: Node = bench[1]
	_check(not bool(closer.get("arm_shipped")),
			"AS FOUND the arm is off its spindle")
	_check(float(closer.get("port_turns")) == 0.0,
			"and the regulating screw is home (%s)" % closer.call("port_reads"))
	_check(not bool(closer.call("connected")), "so the closer drives nothing")
	_check(not bool(closer.call("metered")),
			"and would pass no liquid if it did")
	_check(not bool(closer.call("ready")), "the closer is NOT ready")
	_check(closer.call("faults") == ["arm_shipped", "port_open"],
			"and it names both faults, in the order a hand fixes them")
	_check(not bool(closer.get("arm_seen")), "nobody has looked at it")
	_check(closer.call("last_record").is_empty(), "it has published nothing")
	_check(bool(closer.call("shuts_by_hand")),
			"the leaf SHUTS BY HAND — true of every leaf in the building")
	_check(not bool(closer.call("closes_itself")),
			"AND IT DOES NOT CLOSE ITSELF. That is the whole increment.")
	(bench[0] as Node).queue_free()


# --- the central proof -------------------------------------------------------

func _shutting_by_hand_proves_nothing() -> void:
	var bench := await _bench()
	var door: DoorProp = bench[0]
	var closer: Node = bench[1]
	closer.call("read_arm")
	# A hand pushes it open and a hand pushes it shut. This is what happens at
	# every leaf in the building today.
	door.interact(null)
	await _settle()
	_check(door.open, "a hand pushed the leaf open")
	door.interact(null)
	await _settle()
	_check(not door.open, "and a hand pushed it shut again")
	_check(not bool(closer.call("closes_itself")),
			"THE CLOSER STILL DOES NOT CLOSE IT. A shut door is not evidence.")
	_check(str(closer.get("last_attempt")) == "",
			"because nothing was ever let go of")
	# And it refuses to be asked while the leaf is shut, which is the refusal
	# that makes the distinction impossible to fake.
	_check(not bool(closer.call("prove_close")),
			"and it REFUSES to test a leaf that is already shut")
	_check(str(closer.call("balk_focus")) == "leaf",
			"balking at the leaf, not at its own iron")
	_check(closer.call("last_record").is_empty(),
			"a refused test publishes nothing")
	door.queue_free()


# --- the refusals ------------------------------------------------------------

func _refusals() -> void:
	var bench := await _bench()
	var door: DoorProp = bench[0]
	var closer: Node = bench[1]

	# 1. adjusting under live spring load
	_check(not bool(closer.call("ship_arm")),
			"the arm CANNOT be shipped with the leaf free — the spring is live")
	_check(str(closer.call("balk_focus")) == "hold",
			"and the refusal points at the catch, which is the fix")
	_check(not bool(closer.get("arm_shipped")), "the arm stayed off")

	# 2. metering a cylinder that drives nothing
	_check(not bool(closer.call("turn_check")),
			"the regulating screw REFUSES while the arm is off its spindle")
	_check(str(closer.call("balk_focus")) == "arm", "pointing at the arm")
	_check(float(closer.get("port_turns")) == 0.0, "and the port did not move")

	# 3. the catch, and then the arm
	_check(bool(closer.call("hold_leaf")), "throw the hold-open catch")
	_check(bool(closer.call("ship_arm")), "NOW the arm ships onto its spindle")
	_check(bool(closer.call("connected")), "and the closer drives the leaf")
	_check(not bool(closer.call("ready")), "but it is still not ready")

	# 4. testing against a catch that is holding the leaf
	door.npc_set_open(true)
	await _settle()
	_check(door.open, "the leaf is open")
	_check(not bool(closer.call("prove_close")),
			"a test REFUSES while the catch is holding the leaf")
	_check(str(closer.call("balk_focus")) == "hold",
			"because whatever happens next would be the catch's doing")
	_check(closer.call("last_record").is_empty(), "and nothing was published")
	_check(bool(closer.call("release_leaf")), "take the catch off")

	# 5. certifying a mechanism nobody looked at
	closer.set("arm_seen", false)
	_check(not bool(closer.call("prove_close")),
			"a test REFUSES before anyone has read the arm")
	closer.call("read_arm")
	_check(bool(closer.get("arm_seen")), "read the arm")

	# 6. locked is not closed, and a closer is not a key
	door.leaf_state = "locked"
	var was_open := door.open
	_check(not bool(closer.call("prove_close")),
			"a test REFUSES on a LOCKED leaf")
	_check(str(closer.call("balk_focus")) == "lock", "and says so")
	_check(door.leaf_state == "locked",
			"THE LEAF IS STILL LOCKED. A closer does not unlock anything.")
	_check(door.open == was_open, "and the closer did not move it either")
	_check(closer.call("last_record").is_empty(), "nothing published")
	door.leaf_state = "closed"
	door.queue_free()


# --- the port decides --------------------------------------------------------

func _the_port_decides() -> void:
	var bench := await _bench()
	var door: DoorProp = bench[0]
	var closer: Node = bench[1]
	closer.call("read_arm")
	closer.call("hold_leaf")
	closer.call("ship_arm")
	closer.call("release_leaf")
	door.npc_set_open(true)
	await _settle()
	_check(door.open, "the leaf stands open, arm shipped, port home")

	# STOPPING SHORT. The spring has nothing to move the liquid through, so
	# this apparatus does not ask for a close it cannot deliver.
	_check(not bool(closer.call("prove_close")),
			"the closer will not request a close it cannot finish")
	_check(door.open, "SO THE LEAF STANDS WHERE IT WAS. Nothing pretended.")
	var short: Dictionary = closer.call("last_record")
	_check(not short.is_empty(), "and it published the attempt anyway")
	_check(bool(short.get("stopped_short"))
			and not bool(short.get("reached_closed")),
			"recorded as STOPPED SHORT, not as a close")
	_check(not bool(short.get("requested_by_closer")),
			"and the record says the closer never asked")
	_check(str(closer.get("last_attempt")) == "stopped_short",
			"the apparatus's own state agrees")
	_check(not bool(closer.call("closes_itself")),
			"and it STILL does not claim to close itself")
	_check(str(closer.call("balk_focus")) == "valve",
			"the refusal points at the regulating screw, which is the fix")

	# Now open the port. Dizer: the size of the leakage port decides the speed.
	var turns := 0
	while not bool(closer.call("metered")) and turns < 12:
		closer.call("turn_check")
		turns += 1
	_check(bool(closer.call("metered")),
			"the screw backed out to %s and the port passes liquid"
					% closer.call("port_reads"))
	_check(bool(closer.call("ready")), "THE CLOSER IS READY")
	_check(closer.call("faults").is_empty(), "with nothing left against it")

	var published: Array[Dictionary] = []
	closer.connect("closer_proved", func(r: Dictionary) -> void:
			published.append(r))
	_check(door.open, "the leaf is still standing open")
	_check(bool(closer.call("prove_close")), "LET IT GO")
	await _settle()
	_check(not door.open, "AND IT CAME HOME ON ITS OWN.")
	_check(bool(closer.call("closes_itself")),
			"NOW it closes itself, and only now")
	_check(published.size() == 1, "one record published (%d)" % published.size())
	var rec: Dictionary = published[0] if published.size() == 1 else {}
	_check(bool(rec.get("requested_by_closer")),
			"the record says THE CLOSER asked, not a hand")
	_check(bool(rec.get("reached_closed"))
			and not bool(rec.get("stopped_short")),
			"and that the leaf reached closed")
	for field in CloserScript.RECORD_FIELDS:
		_check(rec.has(field), "the record carries %s" % field)
	_check(rec.keys().size() == CloserScript.RECORD_FIELDS.size(),
			"and nothing else (%d fields)" % rec.keys().size())
	_check(not rec.has("leaf_state") and not rec.has("locked"),
			"THE RECORD DOES NOT MENTION THE LOCK. Locked is not closed.")

	# Screwing the port home again takes the readiness away. There is no memory
	# of having once worked.
	while bool(closer.call("metered")):
		closer.call("turn_check")
	_check(not bool(closer.call("ready")),
			"screwing the port home takes readiness back")
	door.queue_free()


# --- one owner of the leaf ---------------------------------------------------

func _one_owner_of_the_leaf() -> void:
	# What the closer SAYS to a door, word for word.
	var spy_bench := await _spy_bench()
	var spy: SpyDoor = spy_bench[0]
	var closer: Node = spy_bench[1]
	closer.call("read_arm")
	closer.call("hold_leaf")
	closer.call("ship_arm")
	closer.call("release_leaf")
	while not bool(closer.call("metered")):
		closer.call("turn_check")
	spy.open = true
	spy.heard.clear()
	_check(bool(closer.call("prove_close")), "the closer proves a close")
	_check(spy.heard == ["npc_set_open(false)"],
			"AND ITS WHOLE VOCABULARY AGAINST A DOOR IS `npc_set_open(false)`: %s"
					% str(spy.heard))
	spy.heard.clear()
	spy.open = false
	closer.call("prove_close")
	spy.open = true
	spy.leaf_state = "locked"
	closer.call("prove_close")
	spy.leaf_state = "closed"
	closer.call("hold_leaf")
	closer.call("prove_close")
	_check(spy.heard.is_empty(),
			"and every refusal says NOTHING to the door at all: %s"
					% str(spy.heard))
	spy.queue_free()

	# What actually HAPPENS to a real leaf.
	var bench := await _bench()
	var door: DoorProp = bench[0]
	var closer2: Node = bench[1]
	var body: Node3D = door.get_node("HingedLeaf")
	var resting := body.rotation.y
	closer2.call("read_arm")
	closer2.call("hold_leaf")
	closer2.call("ship_arm")
	closer2.call("release_leaf")
	while not bool(closer2.call("metered")):
		closer2.call("turn_check")
	closer2.call("prove_close")
	closer2.call("turn_check")
	await get_tree().process_frame
	_check(is_equal_approx(body.rotation.y, resting),
			"the leaf never moved for anything except the door's own tween")
	_check(door.leaf_state == "closed" and not door.open,
			"and `leaf_state` and `open` are exactly what DoorProp left them")
	# The closer's own arm is the only transform it maintains.
	var arm: Node3D = closer2.get_node("MainArm")
	var shut_pose := arm.rotation.y
	door.npc_set_open(true)
	await _settle()
	_check(not is_equal_approx(arm.rotation.y, shut_pose),
			"the arm follows the leaf it watches (%.3f → %.3f rad)"
					% [shut_pose, arm.rotation.y])
	closer2.call("hold_leaf")
	_check((closer2.get_node("HoldOpenCatch") as Node3D).rotation.z < -0.1,
			"and the catch is thrown where a camera can see it")
	_check(not RealityState.data.has("door_closer")
			and not RealityState.data.has("closer_state"),
			"SR7-Q wrote no save key of its own")
	door.queue_free()


# --- abort -------------------------------------------------------------------

func _abort() -> void:
	var bench := await _bench()
	var door: DoorProp = bench[0]
	var closer: Node = bench[1]
	var before: String = JSON.stringify(closer.call("maintenance_snapshot"))
	closer.call("read_arm")
	closer.call("hold_leaf")
	closer.call("ship_arm")
	closer.call("turn_check")
	closer.call("turn_check")
	_check(JSON.stringify(closer.call("maintenance_snapshot")) != before,
			"a half-done job is not the job as found")
	closer.call("restore_maintenance_snapshot", JSON.parse_string(before))
	_check(JSON.stringify(closer.call("maintenance_snapshot")) == before,
			"ABORT puts every owned fact back, byte for byte")
	_check(not bool(closer.call("balking")), "and clears the refusal with it")
	_check(door.leaf_state == "closed" and not door.open,
			"and the door is untouched, because it was never this thing's")
	door.queue_free()


# --- the poses ---------------------------------------------------------------

func _poses() -> void:
	# Five refusals, five different photographs. A frozen sheet does not tick,
	# so the pose has to be applied inside the balk itself.
	var poses: Dictionary = {}
	for focus in ["arm", "valve", "hold", "leaf", "lock"]:
		var door := DoorProp.new()
		add_child(door)
		var closer: Node = CloserScript.new()
		closer.prop_type = "door_check_closer"
		closer.door_path = NodePath("..")
		door.add_child(closer)
		closer.call("_balk", 2.0, focus)
		var arm: Node3D = closer.get_node("MainArm")
		var valve: Node3D = closer.get_node("RegulatingScrew")
		var catch: Node3D = closer.get_node("HoldOpenCatch")
		poses[focus] = "%.4f|%.4f|%.4f|%.4f|%.4f" % [arm.rotation.y,
				arm.rotation.z, arm.position.z, valve.rotation.x,
				catch.rotation.z]
		door.queue_free()
	var seen: Dictionary = {}
	for focus in poses:
		seen[poses[focus]] = true
	_check(seen.size() == poses.size(),
			"%d refusals hold %d DISTINCT poses" % [poses.size(), seen.size()])

	# AND EVERY ONE OF THEM LETS GO AGAIN. The proof sheet caught this: a calm
	# frame taken after five refusals was 0.00414 off the same state taken
	# before them, because the valve balk nudged `position.x` and nothing ever
	# put it back. A refusal that leaves a mark is a refusal that lies about
	# the next frame.
	var door := DoorProp.new()
	add_child(door)
	var closer: Node = CloserScript.new()
	closer.prop_type = "door_check_closer"
	closer.door_path = NodePath("..")
	door.add_child(closer)
	var rest := _iron(closer)
	for focus in ["arm", "valve", "hold", "leaf", "lock"]:
		closer.call("_balk", 2.0, focus)
		_check(_iron(closer) != rest, "the %s refusal moves the iron" % focus)
		closer.set("_balk_left", 0.0)
		closer.set("_balk_focus", "")
		closer.call("_refresh_closer")
		_check(_iron(closer) == rest,
				"and the %s refusal puts EVERY part back where it was" % focus)
	door.queue_free()


## Every transform this apparatus owns, as one string. If a refusal leaves any
## of it moved, this catches it.
func _iron(closer: Node) -> String:
	var out := ""
	for part in ["MainArm", "MainArm/Forearm", "ShoePivot", "RegulatingScrew",
			"HoldOpenCatch"]:
		var node: Node3D = closer.get_node(part) as Node3D
		out += "%s=%.5f,%.5f,%.5f/%.5f,%.5f,%.5f|" % [part,
				node.position.x, node.position.y, node.position.z,
				node.rotation.x, node.rotation.y, node.rotation.z]
	return out


# --- source discipline -------------------------------------------------------

func _source_discipline() -> void:
	var text := FileAccess.get_file_as_string(CLOSER_PATH)
	_check(not text.is_empty(), "the apparatus source is readable")
	# The comments say plenty about what is refused; only CODE is scanned,
	# because a comment saying "no timer" is not a timer.
	var code := ""
	for line in text.split("\n"):
		var stripped := String(line)
		var hash_at := stripped.find("#")
		if hash_at >= 0:
			stripped = stripped.substr(0, hash_at)
		code += stripped.to_lower() + "\n"
	for word in ["timer", "durability", "wear", "schedule", "due_", "osha",
			"nfpa", "randf", "randi"]:
		_check(not code.contains(word),
				"no `%s` anywhere in the code: the facts are the iron" % word)
	# It must never WRITE the door's own state. Reading it — `get("open")`,
	# `get("leaf_state")` — is the whole point of an observer, so the scan is
	# for assignment and for the leaf body, not for the words.
	for forbidden in ["leaf_state =", "leaf_state=", "set(\"leaf_state\"",
			"set(\"open\"", ".open =", "_body", "hingedleaf", "unlock",
			"animatablebody", "call(\"interact\"", ".interact(",
			"_rattle"]:
		_check(not code.contains(forbidden),
				"the code never touches `%s`" % forbidden)
	_check(code.contains("npc_set_open"),
			"and the one thing it does say to a door is `npc_set_open`")
	_check(code.count("npc_set_open") == 1,
			"exactly once, in one place (%d)" % code.count("npc_set_open"))


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [door check ok] ", label)
	else:
		failures += 1
		printerr("  [DOOR CHECK FAIL] ", label)


func _finish() -> void:
	print("DOOR CHECK TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
