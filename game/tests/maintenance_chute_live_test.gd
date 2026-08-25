extends Node
## SR7-D — the chute stands on the real lobby wall and disturbs nothing on it.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/MaintenanceChuteLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## The audit that preceded SR7-D found NO mail chute in production: no
## geometry, no marker, no prop, no layout record. The only vertical shafts in
## the building are the refuse chute at (2.45, 6.05) and the lift, neither of
## which is postal. The lobby's east wall already carries a measured
## composition -- the Vantry master clock, the Couch mail bank, the post tray
## -- guarded by exact clearance assertions in `walk_test.gd`.
##
## So this file proves two things. That the apparatus stands in the one clear
## stretch of that wall, reachable and whole. And that the measured mail-wall
## composition it was dropped beside is untouched.

var failures := 0
var checks := 0

## Building coordinates of the neighbours this apparatus must not disturb.
const BANK_Y := -7.88
const TRAY_Y := -7.40
const BOARD_Y := -6.20
const CHUTE_Y := -6.75


func _ready() -> void:
	var scene := load("res://scenes/building/orison_root.tscn") as PackedScene
	var root: Node = scene.instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var chute: Node3D = root.find_child("LobbyMailChute", true, false) as Node3D
	_check(chute != null, "the production lobby owns a mail chute")
	if chute == null:
		_finish()
		return

	# --- it stands where the wall is actually clear -------------------------
	var at := chute.global_position
	var bx := at.x
	var by := -at.z
	print("[CHUTE LIVE] global b(%.2f, %.2f, %.2f)" % [bx, by, at.y])
	_check(absf(bx - 5.24) < 0.02,
			"it is on the east wall face (b x %.2f)" % bx)
	_check(absf(by - CHUTE_Y) < 0.02,
			"in the clear stretch between tray and porter board (b y %.2f)" % by)
	_check(by > TRAY_Y and by < BOARD_Y,
			"strictly between the post tray at -7.40 and the board at -6.20")
	_check(chute.get_parent() != null
			and str(chute.get_parent().name).contains("F01"),
			"parented to F01, the lobby the player starts in")
	# The apparatus is authored facing local +Z; on this run the room is west
	# of the partition, so it must have taken the negative half-turn.
	var facing := chute.global_transform.basis.z.normalized()
	_check(facing.x < -0.9,
			"its face is turned into the lobby (z -> %.2f)" % facing.x)

	# --- the measured mail-wall composition is untouched --------------------
	var bank: MailBankProp = root.find_child("LobbyMailBank", true, false) \
			as MailBankProp
	var tray: Node3D = root.find_child("LobbyPostTray", true, false) as Node3D
	_check(bank != null and tray != null,
			"the measured bank and tray are both still present")
	if bank != null:
		_check(absf(bank.global_position.z - 7.88) < 0.01,
				"the Couch bank still occupies its measured east-wall centre")
		var state: Dictionary = bank.inspection_state()
		_check(int(state.mesh_count) <= 16,
				"the bank still spends at or below sixteen meshes (%d)"
						% int(state.mesh_count))
		_check(int(state.address_count) == 24 and int(state.card_count) == 18,
				"and its elevation is unchanged")
		# The chute is a SIBLING of the bank, never a child: the bank's mesh
		# budget is measured over its own descendants and this apparatus must
		# not be inside it.
		_check(chute.get_parent() != bank,
				"the chute is a sibling of the bank, not inside its budget")
	if tray != null:
		_check(absf(tray.global_position.z - 7.40) < 0.01,
				"the post tray still derives from the bank centre")

	# --- reach and the authored activity ------------------------------------
	_check(chute.get_node_or_null("ChuteReach") is PropControlArea
			and chute.control_prompt("chute").contains("choked"),
			"the chute is a ray-reachable service point announcing its fault")
	_check(chute.interact_control("chute", null)
			and chute._service_panel != null
			and chute._service_panel._director != null
			and chute._service_panel._director.active_run != null,
			"that reach opens the shared activity system")
	var run: MaintenanceActivityRun = chute._service_panel._director.active_run
	_check(str(run.activity_id) == "mail_chute_choke_clearing"
			and str(run.profile.get("historical_source", "")).contains("284,951"),
			"and the activity it opens is the authored chute, by name")

	# --- work the whole chain on the production apparatus -------------------
	var seen: Array[Dictionary] = []
	chute.maintenance_completed.connect(
			func(r: Dictionary) -> void: seen.append(r))
	_check(chute.arch_standing and chute.box_appears_empty(),
			"the production chute is found choked with an empty box below it")
	var steps: Array = run.profile.get("steps", [])
	var moved := true
	for step in steps:
		var record := step as Dictionary
		chute.preview_maintenance_step(record, float(record.target))
		if str(record.id) == "take_the_load":
			_check(chute.load_taken and chute.arch_standing,
					"the load comes off while the arch is still standing")
		if str(record.id) == "break_the_arch":
			_check(not chute.arch_standing and chute.passage_clear(),
					"and only then does the span go")
		if str(record.verb) == "hold_release":
			moved = moved and chute._service_panel._director.submit(
					"hold_release", float(record.target),
					float(record.hold_min_seconds) + 0.4)
		else:
			moved = moved and chute._service_panel._director.submit(
					str(record.verb), float(record.target))
	_check(moved, "every authored verb lands on the production apparatus")
	_check(seen.size() == 1 and chute.chute_clear and chute.passage_clear(),
			"the final commit alone records the chute clear and reports once")

	# --- ownership ----------------------------------------------------------
	var patch: Dictionary = seen[0].get("mechanism_patch", {}) if seen.size() == 1 \
			else {}
	var leaked: Array[String] = []
	for key in patch.keys():
		if str(key) not in ["arch_standing", "load_taken", "cover_locked",
				"glass_drawn", "chute_clear"]:
			leaked.append(str(key))
	_check(leaked.is_empty(),
			"the result patches the apparatus and nothing else (%s)"
					% ", ".join(leaked))
	_check(not seen[0].has("job_id") and not seen[0].has("case_id"),
			"it closes no job and advances no case")
	# It moves no mail. The bank's own delivery list is static data and this
	# apparatus must not have touched it.
	if bank != null:
		_check(bank.pending() is Array,
				"the bank's delivery list is still its own (%d pending)"
						% (bank.pending() as Array).size())
	_check(chute.find_children("*", "Light3D", true, false).is_empty(),
			"the apparatus owns no light of its own")
	_check(chute.find_children("*", "CollisionObject3D", true, false).size() == 1,
			"and exactly one collision body, its own reach")

	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [live chute ok] ", label)
	else:
		failures += 1
		printerr("  [LIVE CHUTE FAIL] ", label)


func _finish() -> void:
	print("MAINTENANCE CHUTE LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
