extends Node
## DEV-GUARD-1: the blockout validator must REFUSE bad geometry.
##
## Each case starts from one clean, hand-built fixture and injects exactly one
## fault, so the reported failure is attributable to that fault alone. The
## fixture is written to user:// per case; nothing under res:// is mutated and
## the production layout is only ever read.
##
## The defects under test were found by DEV-REHEARSE-1 and recorded in
## design/ORISON_V2_FLOOR_LANDING_REHEARSAL_CHECKPOINT_2026-08-29.md: before
## this guard, overlapping rooms and dangling references both built silently.

const BlockoutScript := preload("res://scripts/building/orison_v2_blockout.gd")

const CLEAN := "res://tests/fixtures/orison_v2_guard/clean_blockout.json"
const PRODUCTION := "res://data/orison_v2_blockout.json"
const SCRATCH := "user://orison_v2_guard_case.json"

var failures := 0

func _ready() -> void:
	await _clean_fixture_builds()
	await _production_layout_still_builds()
	await _dangling_stair_level_is_refused()
	await _overlap_off_f04_is_refused()
	await _door_to_missing_space_is_refused()
	await _more_referential_faults_are_refused()
	await _a_refusal_builds_nothing()
	_finish()

# -- the two things that must NOT change -------------------------------------

func _clean_fixture_builds() -> void:
	var root := await _build(CLEAN)
	_check(root.failures.is_empty(),
			"clean fixture validates: " + str(root.failures))
	_check(root.is_in_group("orison_v2_blockout"),
			"clean fixture joins the selector group")
	_check(root.get_child_count() > 0, "clean fixture builds geometry")
	root.queue_free()
	await get_tree().process_frame

func _production_layout_still_builds() -> void:
	## The real layout carries three deliberate overlaps - the street and rear
	## aprons and the F02/F04 landing decision zones lie inside a core - and
	## every one of them is an open_shell zone that builds no walls. The guard
	## must not refuse them.
	var root := await _build(PRODUCTION)
	_check(root.failures.is_empty(),
			"production layout still validates: " + str(root.failures))
	_check(root.is_in_group("orison_v2_blockout"),
			"production layout joins the selector group")
	root.queue_free()
	await get_tree().process_frame

# -- the three faults the brief names ----------------------------------------

func _dangling_stair_level_is_refused() -> void:
	var layout := _load_clean()
	(layout.stairs[0] as Dictionary)["from"] = "F07"
	var failure := await _refusal_for(layout, "dangling stair level")
	_check(failure.contains("PRIMARY_B1_F01") and failure.contains("F07")
			and failure.contains("stair from"),
			"stair failure names the stair, the field and the level: " + failure)

func _overlap_off_f04_is_refused() -> void:
	## Deliberately on F02: the only overlap checks that existed were keyed to
	## the id prefixes F04_B_*, B1_* and F02_B_*, so a room on any other floor
	## was never compared with anything.
	var layout := _load_clean()
	for space: Dictionary in layout.spaces:
		if str(space.id) == "F02_A_MAIN":
			space.rect = [-9.0, -2.0, 1.0, 4.0]  # now eats F02_HALL
	var failure := await _refusal_for(layout, "overlap on F02")
	_check(failure.contains("F02_A_MAIN") and failure.contains("F02_HALL")
			and failure.contains("F02"),
			"overlap failure names both rooms and the level: " + failure)

func _door_to_missing_space_is_refused() -> void:
	var layout := _load_clean()
	(layout.doors[1] as Dictionary)["connects"] = ["F02_HALL", "F02_A_LOBBY"]
	var failure := await _refusal_for(layout, "door to a missing space")
	_check(failure.contains("F02_DOOR_02") and failure.contains("F02_A_LOBBY")
			and failure.contains("door connects"),
			"door failure names the leaf, the field and the target: " + failure)

# -- the rest of the reference surface ---------------------------------------

func _more_referential_faults_are_refused() -> void:
	var opening := _load_clean()
	(opening.openings[0] as Dictionary)["connects"] = ["F01_VESTIBULE", "NOWHERE"]
	_check((await _refusal_for(opening, "opening to a missing space"))
			.contains("opening connects"), "opening connects is checked")

	var window := _load_clean()
	(window.windows[0] as Dictionary)["space"] = "F01_GHOST"
	_check((await _refusal_for(window, "window on a missing space"))
			.contains("window space"), "window space is checked")

	var landing := _load_clean()
	(landing.lift_landings[0] as Dictionary)["shaft"] = "NO_SUCH_SHAFT"
	_check((await _refusal_for(landing, "landing on a missing shaft"))
			.contains("lift landing shaft"), "lift landing shaft is checked")

	var edge := _load_clean()
	(edge.route_edges[0] as Dictionary)["via"] = "NO_SUCH_STAIR"
	_check((await _refusal_for(edge, "route edge via nothing"))
			.contains("route edge via"), "route edge via is checked")

	var service := _load_clean()
	(service.service_connections[0] as Dictionary)["to"] = "NO_SUCH_RISER"
	_check((await _refusal_for(service, "service connection to nothing"))
			.contains("service connection to"),
			"service connection endpoints are checked")

	## A reference that resolves to the WRONG table is still a fault: a leaf
	## may not connect to a riser.
	var wrong := _load_clean()
	(wrong.doors[1] as Dictionary)["connects"] = ["F02_HALL", "HEAT_STACK"]
	_check((await _refusal_for(wrong, "door connected to a riser"))
			.contains("must name a spaces record"),
			"a reference into the wrong table is refused")

# -- silence is the defect ---------------------------------------------------

func _a_refusal_builds_nothing() -> void:
	var layout := _load_clean()
	(layout.stairs[0] as Dictionary)["from"] = "F07"
	var root := await _build(_write_scratch(layout))
	_check(not root.failures.is_empty(), "refused layout reports failures")
	_check(root.get_child_count() == 0,
			"refused layout builds no partial geometry")
	_check(not root.is_in_group("orison_v2_blockout"),
			"refused layout does not join the selector group")
	root.queue_free()
	await get_tree().process_frame

# -- helpers -----------------------------------------------------------------

func _build(path: String) -> Node3D:
	var root := BlockoutScript.new()
	root.layout_path = path
	add_child(root)
	await get_tree().process_frame
	return root

func _load_clean() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CLEAN)) as Dictionary

func _write_scratch(layout: Dictionary) -> String:
	var file := FileAccess.open(SCRATCH, FileAccess.WRITE)
	file.store_string(JSON.stringify(layout))
	file.close()
	return SCRATCH

## Build one mutated layout, assert it was refused, and return the single
## failure message so the caller can assert what the message says.
func _refusal_for(layout: Dictionary, label: String) -> String:
	var root := await _build(_write_scratch(layout))
	var reported: Array[String] = root.failures.duplicate()
	root.queue_free()
	await get_tree().process_frame
	_check(reported.size() == 1,
			"%s is refused with exactly one failure, got %s" % [label, reported])
	return reported[0] if reported.size() > 0 else ""

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)

func _finish() -> void:
	if DirAccess.open("user://") != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	print("ORISON V2 BLOCKOUT GUARD TEST: %s (%d failure(s))"
			% ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(failures)
