extends Node
## SR7-A — the dumbwaiter exists in the production Orison, not only in a test.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/MaintenanceDumbwaiterLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## This builds the real `orison_root.tscn` and goes looking for the apparatus
## the way a player would: by name, on a floor, with a reach the ray can find
## and a panel that opens onto the authored activity.
##
## The audit that preceded SR7-A found no dumbwaiter anywhere in production --
## no generator marker, no prop, no anchor, no mesh. The only prior hits for the
## word were the brief and TASKS.md. So the point of this file is narrow and
## load-bearing: prove that the seam used here is the SAME seam the porter's
## board already uses, and that the thing now stands in the lobby.

var failures := 0
var checks := 0


func _ready() -> void:
	var scene := load("res://scenes/building/orison_root.tscn") as PackedScene
	var root: Node = scene.instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var lift := root.find_child("LobbyServiceDumbwaiter", true, false) \
			as DumbwaiterProp
	_check(lift != null,
			"the production lobby owns a service dumbwaiter")
	if lift == null:
		_finish()
		return

	# It must live on the same hand-authored detail wall as the porter's board,
	# on the real ground floor, not parented to some test scaffold.
	var board := root.find_child("LobbyPorterBoard", true, false)
	_check(board != null and lift.get_parent() == board.get_parent(),
			"it stands on the porter board's wall run, on the same floor node")
	_check(lift.get_parent() != null
			and str(lift.get_parent().name).contains("F01"),
			"that floor is F01, the lobby the player actually enters")

	# A dumbwaiter is its own small apparatus. It must not have been parked
	# inside the passenger elevator shaft, whose plan rect is 0.85..3.0 by
	# -6.75..-4.55 in building coordinates.
	#
	# `b2g` maps Blender (x, y, z) to Godot (x, z, -y), so the inverse of the
	# prop's own placement is read back out of its transform. The LOCAL
	# transform is the right one: the floor node carries the storey height, and
	# the placement in the detail pass is written in exactly these terms.
	var placed := lift.position
	var bx := placed.x
	var by := -placed.z
	var bz := placed.y
	var in_shaft: bool = bx >= 0.85 and bx <= 3.0 and by >= -6.75 and by <= -4.55
	_check(not in_shaft,
			"it is clear of the passenger shaft (b %.2f, %.2f)" % [bx, by])
	_check(bz > 0.4 and bz < 1.8,
			"its sill sits at working height, not on the floor or overhead")
	# Same wall run as the porter's board, within the thickness of the
	# partition. They do not share an exact x: the board hangs on the face at
	# 5.20, while the dumbwaiter's ORIGIN is the face itself at 5.24, because
	# its casing is authored outward from z 0 rather than centred on the
	# mounting plane.
	var board_at: Vector3 = (board as Node3D).position if board is Node3D \
			else Vector3.ZERO
	_check(absf(board_at.x - placed.x) < 0.10,
			"it shares the porter board's wall run (board %.2f, hatch %.2f)"
					% [board_at.x, placed.x])

	# FACING. Everything the activity moves -- rope, sheave, band, pawl -- is
	# authored on local +Z. The partition is at x 5.33 and the corridor the
	# player walks is west of it, so the working face must point at -X. Getting
	# this backwards renders a blank board and hides the entire mechanism, which
	# is exactly what the first proof sheet showed.
	var facing := lift.global_transform.basis.z.normalized()
	_check(facing.x < -0.9,
			"the mechanism faces the corridor, not the partition (z -> %.2f, %.2f)"
					% [facing.x, facing.z])

	# The visible 1910 mechanism: every named part of the patent is present.
	for part in ["Shaftway", "Car", "LiftSheave", "HandRope", "Counterweight",
			"BrakeBand", "HoldingPawl"]:
		_check(lift.get_node_or_null(NodePath(part)) is MeshInstance3D,
				"the mechanism shows its %s" % part.to_lower())

	# The reach, and the panel it opens.
	_check(lift.get_node_or_null("BrakeReach") is PropControlArea
			and lift.control_prompt("brake").contains("brake"),
			"the holding brake is a literal ray-reachable service point")
	_check(lift.interact_control("brake", null)
			and lift._service_panel != null
			and lift._service_panel._director != null
			and lift._service_panel._director.active_run != null,
			"that reach opens the shared activity system")
	var run: MaintenanceActivityRun = lift._service_panel._director.active_run
	_check(str(run.activity_id) == "dumbwaiter_brake_service"
			and str(run.profile.get("historical_source", "")).contains("950,828"),
			"and the activity it opens is the authored 1910 brake, by name")

	# Drive the whole chain through the DIRECTOR, exactly as the panel does,
	# and watch the production prop answer. Nothing is stubbed.
	var seen: Array[Dictionary] = []
	lift.maintenance_completed.connect(
			func(r: Dictionary) -> void: seen.append(r))
	var was_seated: bool = lift.band_seated
	var steps: Array = run.profile.get("steps", [])
	var moved := true
	for step in steps:
		var record := step as Dictionary
		# The panel previews on every adjustment, so preview here too: this is
		# what proves the visible mechanism tracks the hand without publishing.
		lift.preview_maintenance_step(record, float(record.target))
		if str(record.verb) == "hold_release":
			moved = moved and lift._service_panel._director.submit(
					"hold_release", float(record.target),
					float(record.hold_min_seconds) + 0.4)
		else:
			moved = moved and lift._service_panel._director.submit(
					str(record.verb), float(record.target))
		if str(record.id) == "seat_band":
			_check(not lift.band_seated and not was_seated,
					"the band is still not seated with only one step left")
	_check(moved, "every authored verb lands on the production mechanism")
	_check(seen.size() == 1 and lift.band_seated
			and is_equal_approx(lift.brake_bite, DumbwaiterProp.BAND_HOME),
			"the final commit alone seats the band and reports once")
	_check(lift.rope_strain == 0.0 and lift.pawl_lift == 0.0
			and lift.car_travel == 0.0,
			"and the rope, pawl and car are left the way they were found")
	_check(not lift.control_prompt("brake").contains("Prove"),
			"the prompt now reads as a check, because the brake is holding")

	# The apparatus must not have quietly acquired ownership of anything.
	var patch: Dictionary = seen[0].get("mechanism_patch", {}) if seen.size() == 1 \
			else {}
	var leaked: Array[String] = []
	for key in patch.keys():
		if str(key) not in ["band_seated", "brake_bite", "pawl_lift",
				"rope_strain"]:
			leaked.append(str(key))
	_check(leaked.is_empty(),
			"the result patches the mechanism and nothing else (%s)"
			% ", ".join(leaked))
	_check(not seen[0].has("job_id") and not seen[0].has("case_id"),
			"it closes no job and advances no case")

	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [live dumbwaiter ok] ", label)
	else:
		failures += 1
		printerr("  [LIVE DUMBWAITER FAIL] ", label)


func _finish() -> void:
	print("MAINTENANCE DUMBWAITER LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
