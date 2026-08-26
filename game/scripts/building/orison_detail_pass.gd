class_name OrisonDetailPass
extends Node
## Low-overhead lived-in pass. Primitive clutter and infrastructure are
## batched into two MultiMeshes per floor; narrative paper uses one quad per
## apartment with four shared cached textures.

const STORY_ATLAS := \
	"res://assets/building/textures/story_details/resident_ephemera_atlas.png"
const INFRA_ATLAS := \
	"res://assets/building/textures/story_details/orison_infrastructure_atlas.png"
const PROFILE_PATH := "res://data/resident_story_details.json"
const MailChutePropScript := preload("res://scripts/props/mail_chute_prop.gd")
const FusePanelPropScript := preload("res://scripts/props/fuse_panel_prop.gd")
const WatchmanClockPropScript := preload(
		"res://scripts/props/watchman_clock_prop.gd")
const NightRegisterPropScript := preload(
		"res://scripts/props/night_register_prop.gd")
const WatchStationPropScript := preload(
		"res://scripts/props/watch_station_prop.gd")
const WatchStationNetworkScript := preload(
		"res://scripts/building/watch_station_network.gd")
const WatchRegisterPropScript := preload(
		"res://scripts/props/watch_register_prop.gd")
const TourKeyGuardPropScript := preload(
		"res://scripts/props/tour_key_guard_prop.gd")
const FireLineCabinetPropScript := preload(
		"res://scripts/props/fire_line_cabinet_prop.gd")
const DoorCheckCloserPropScript := preload(
		"res://scripts/props/door_check_closer_prop.gd")
const SodaAcidExtinguisherPropScript := preload(
		"res://scripts/props/soda_acid_extinguisher_prop.gd")
const DomesticRadioPassScript := preload(
		"res://scripts/building/domestic_radio_pass.gd")

## SR7-P. WHAT IS ON EACH OF THE EIGHT BACKBOARDS.
##
## The infrastructure loop below batches an identical red backboard at
## b(-2.76, -3.10) on every floor -- 0.34 wide, 0.08 deep, 0.70 tall, spanning
## z+0.70 to z+1.40. SR7-O hung one working soda-acid extinguisher on F03's.
## The other seven read as unfinished dressing, and this table is the fix.
##
## THREE PASSIVE CONDITIONS, AND THEY ARE NOT A SHUFFLE. Read the building
## upward and it is one story about a superintendent with more boards than
## vessels:
##
##   F01, F05 HUNG            The lobby floor is what anybody important walks
##                            through, and one upper floor simply still has
##                            its own. A vessel on two straps, and no tag.
##   F02, F04 EMPTY_BRACKET   The bracket is still bolted up and the vessel is
##                            gone out of it. A service card hangs on the
##                            strap where the vessel was.
##   F03      WORKING         SR7-O's apparatus. Nothing passive is drawn here.
##   B1, F06  STRIPPED        Bracket and vessel both gone: four bolt heads and
##                            the paint the straps kept clean. B1 is here
##                            because its board is in a corner of the cellar
##                            stair that NOTHING LIGHTS -- the first sheet
##                            photographed it black -- and a condition nobody
##                            can see is the wrong place to put the story. The
##                            cellar's real fire protection is elsewhere in the
##                            building anyway.
##   ROOF     STRIPPED        And for a reason the others do not have: the
##                            charge is two and a half gallons of water, and
##                            this board is on the outside of a stair bulkhead
##                            on an open deck. Nothing that freezes lives here.
##
## THE DISTRIBUTION IS DELIBERATELY NOT A RULE. Two floors kept theirs, two
## were emptied, three have nothing left, and one is inspected. A rule is
## exactly what would make seven boards read as procedural repetition again.
##
## NONE OF THESE IS A PROP. Every one is drawn as entries in the SAME per-floor
## MultiMesh batch that already draws the board, the standpipe and the pipe
## brackets: no node, no script, no material, no draw call, no Area3D, no
## collision, no light, no `_process`, no persistence. They cannot be
## interacted with and they own nothing.
##
## AND NONE OF THEM CARRIES A TAG. SR7-O's board has an inspection tag and an
## enamel charge plate on it; these have neither, because nobody has inspected
## them. A hung vessel with no tag on it is the weakest claim in the building
## -- which is the point, and is the thing that keeps an intact silhouette from
## reading as readiness.
const BOARD_CONDITIONS := {
	"B1": "stripped",
	"F01": "hung",
	"F02": "empty_bracket",
	"F03": "working",
	"F04": "empty_bracket",
	"F05": "hung",
	"F06": "stripped",
	"ROOF": "stripped",
}
## Read off the batched board itself: centred at x -2.76, front face at
## y -3.06 (being -3.10 plus half of 0.08), bottom edge at z+0.70.
const BOARD_X := -2.76
const BOARD_FACE_Y := -3.06

var detail_count := 0
var decal_count := 0
var _lockdown_layout: Dictionary = {}
var _unit_doors: Dictionary = {}

const PLAYER_UNIT := "4B"

## Ruling 2026-08-03: doors start unlocked and residents go about their
## business from boot. Flip to true to restore the sealed-building start
## (every entry locked but the player's; cases unlock their unit).
const START_LOCKED := false


## Registers every unit's entry door; when START_LOCKED, seals all but the
## player's. Residents honor their own locks by staying home (routines
## gate errands on a locked home door), and a case activating unlocks its
## resident's unit so the work can happen.
func _apply_opening_lockdown() -> void:
	var locked := 0
	for candidate in get_tree().get_nodes_in_group("apartment_doors"):
		if not candidate is DoorProp:
			continue
		var door := candidate as DoorProp
		var unit := _unit_of_door(door)
		if unit == "":
			continue
		_unit_doors[unit] = door
		if not START_LOCKED or unit == PLAYER_UNIT:
			continue
		if door.leaf_state == "closed":
			door.leaf_state = "locked"
			locked += 1
	if START_LOCKED:
		print("[LOCKDOWN] %d apartment doors locked; %s and the front door stay open"
				% [locked, PLAYER_UNIT])
	RealityCases.case_changed.connect(_unlock_for_case)


func _unlock_for_case(case_id: String, state: Dictionary) -> void:
	if str(state.get("stage", "")) not in ["active", "reopened"]:
		return
	var unit := str(RealityCases.definitions.get(case_id, {}).get("unit", ""))
	var door: DoorProp = _unit_doors.get(unit)
	if door and door.leaf_state == "locked":
		door.leaf_state = "closed"
		print("[LOCKDOWN] %s unlocked for %s" % [unit, case_id])


## The unit whose ENTRY this is. Probe half a metre either side of the
## leaf in plan space (the same discovery the nav graph uses): a door is
## an entry only when one side belongs to a unit and the other side is
## common space — corridor, hall, or unclaimed circulation. A door with
## unit rooms on both sides is interior and never locks; a resident's
## bedroom door is theirs to use.
func _unit_of_door(door: DoorProp) -> String:
	# The generator owns this classification now. Keep the geometry probe only
	# as migration cover for an old generated layout, not as a second source of
	# truth that can silently disagree with the door model.
	if door.door_kind == "apartment_entry" and door.unit != "":
		return door.unit
	var at := Vector2(door.global_position.x, -door.global_position.z)
	var fid := ""
	var best := INF
	for fl in _lockdown_layout.get("floors", []):
		var d := absf(float(fl.z) - door.global_position.y)
		if d < best:
			best = d
			fid = str(fl.id)
	for fl in _lockdown_layout.get("floors", []):
		if str(fl.id) != fid:
			continue
		var units := {}
		var common_side := false
		for off in [Vector2(0.5, 0), Vector2(-0.5, 0),
				Vector2(0, 0.5), Vector2(0, -0.5)]:
			var probe: Vector2 = at + off
			var best_area := INF
			var unit := ""
			var found := false
			for room in fl.rooms:
				var rect: Array = room.rect
				if probe.x < float(rect[0]) or probe.x > float(rect[2]) \
						or probe.y < float(rect[1]) or probe.y > float(rect[3]):
					continue
				found = true
				var area := (float(rect[2]) - float(rect[0])) \
						* (float(rect[3]) - float(rect[1]))
				if area < best_area:
					best_area = area
					unit = str(room.get("unit", ""))
			if not found or unit == "":
				common_side = true
			else:
				units[unit] = true
		if units.size() == 1 and common_side:
			return units.keys()[0]
		return ""
	return ""


func build(layout: Dictionary, floor_nodes: Dictionary) -> Dictionary:
	name = "OrisonDetailPass"
	var batches := {}
	for floor_id in floor_nodes:
		batches[floor_id] = {"boxes": [], "cylinders": []}
	_build_infrastructure(layout, floor_nodes, batches)
	_build_resident_details(layout, floor_nodes, batches)
	var radio_pass: Node = DomesticRadioPassScript.new()
	radio_pass.name = "DomesticRadioPass"
	add_child(radio_pass)
	var radio_stats: Dictionary = radio_pass.call("build", layout, floor_nodes)
	for floor_id in batches:
		var parent: Node3D = floor_nodes[floor_id]
		_emit_batch(parent, batches[floor_id].boxes, BoxMesh.new(), "trim")
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.5
		cylinder.bottom_radius = 0.5
		cylinder.height = 1.0
		cylinder.radial_segments = 10
		_emit_batch(parent, batches[floor_id].cylinders, cylinder, "metal")
	return {"details": detail_count, "decals": decal_count,
			"domestic_radios":radio_stats}


func _build_infrastructure(layout: Dictionary, floor_nodes: Dictionary,
		batches: Dictionary) -> void:
	for floor in layout.floors:
		var floor_id: String = floor.id
		if not batches.has(floor_id):
			continue
		var z := float(floor.z)
		# Continuous red standpipe, brass couplings, electrical access panel,
		# extinguisher cabinet and pipe brackets beside the stair core.
		_cylinder(batches[floor_id], [3.02, -3.02, z + 1.55],
				[0.055, 3.10, 0.055], Color(0.42, 0.055, 0.035))
		for h in [0.18, 1.55, 2.92]:
			_cylinder(batches[floor_id], [3.02, -3.02, z + h],
					[0.078, 0.045, 0.078], Color(0.52, 0.36, 0.16))
		_box(batches[floor_id], [2.73, -3.10, z + 1.30],
				[0.42, 0.08, 0.58], Color(0.30, 0.31, 0.28))
		_box(batches[floor_id], [-2.76, -3.10, z + 1.05],
				[0.34, 0.08, 0.70], Color(0.45, 0.09, 0.055))
		_build_board_condition(batches[floor_id], floor_id, z)
		for h in [0.42, 1.18, 1.94, 2.70]:
			_box(batches[floor_id], [2.15, -3.12, z + h],
					[0.035, 0.045, 0.34], Color(0.36, 0.35, 0.31))
		# Floor-specific institutional decal.
		var panel := 0
		if floor_id == "B1":
			panel = 0
		elif floor_id in ["F01", "F03", "F05"]:
			panel = 1
		elif floor_id in ["F02", "F04", "F06"]:
			panel = 2
		else:
			panel = 3
		_add_decal(floor_nodes[floor_id], INFRA_ATLAS,
				panel % 2, panel / 2,
				[2.36, -3.19, z + 1.56], 0.0, Vector2(0.48, 0.48))
	# Lobby mail corner: the functional Cutler-style bank replaces the old
	# 24 flat placeholder boxes (which were stamped straight across a
	# window). It stands on the east partition — the one clear lobby wall —
	# facing the generated wood bank across the corner. A real prop: the
	# player's 4B door opens, and mail_catalog.json arrives through it.
	if floor_nodes.has("F01"):
		# Measured against F01_LOBBY_CLOCK_01 at Blender y -8.970. The wider
		# Couch bank has only a half-metre legal centre window on this run;
		# -7.88 clears the master and keeps its north cheek off the wall end.
		const MAIL_BANK_Y := -7.88
		const POST_TRAY_FROM_BANK := 0.48
		var bank := MailBankProp.new()
		bank.name = "LobbyMailBank"
		# Centred on the lobby's east run (-9.65..-6.93) rather than jammed
		# against its south end. The ad board that used to crowd this wall
		# now lives opposite, so the bank gets the wall it was always meant
		# to have and can be walked up to square on instead of edged around.
		bank.position = GameBoot.b2g([5.24, MAIL_BANK_Y, 0.0])
		bank.rotation.y = PI * 0.5
		floor_nodes["F01"].add_child(bank)
		# The tray of unsorted post, on the ledge under the bank. The
		# wall is twenty-four doors and one of them is yours; reaching
		# for the whole wall would fight with that, so the tray is the
		# handle on the sorting.
		var tray := DeadLettersProp.new()
		tray.name = "LobbyPostTray"
		tray.prop_type = "dead_letters"
		tray.position = GameBoot.b2g(
				[5.02, MAIL_BANK_Y + POST_TRAY_FROM_BANK, 0.86])
		tray.rotation.y = PI * 0.5
		floor_nodes["F01"].add_child(tray)
		# SR7-D: the mail chute and its collection box, in the clear stretch of
		# the east wall between the post tray at y -7.40 and the porter's board
		# at y -6.20. The box is 0.34 across, so at -6.75 it spans -6.92..-6.58
		# and touches neither neighbour; walk_test's measured mail-wall
		# composition -- the 150 mm bank-to-master gap, the 4B leaf sweep and
		# the 0.70 m standing lane -- is all south of the tray and untouched.
		#
		# -PI/2, like the dumbwaiter: props on this run are authored facing
		# local +Z and the lobby lies west of the partition, so the positive
		# half-turn the mail bank and porter board still carry would point this
		# apparatus into the wall.
		var chute := MailChutePropScript.new()
		chute.name = "LobbyMailChute"
		chute.prop_type = "mail_chute"
		chute.position = GameBoot.b2g([5.24, -6.75, 0.0])
		chute.rotation.y = -PI * 0.5
		floor_nodes["F01"].add_child(chute)
		# The porter's board, further up the same wall toward the lift.
		# There has not been a porter in years, which is why it is yours.
		var board := OtisProp.new()
		board.name = "LobbyPorterBoard"
		board.prop_type = "otis"
		board.position = GameBoot.b2g([5.20, -6.20, 1.42])
		board.rotation.y = PI * 0.5
		floor_nodes["F01"].add_child(board)
		# SR7-A: the service dumbwaiter, further up the same wall toward the
		# lift, where a back-of-house hatch belongs. It is on the porter's
		# board's wall run and set at counter height so the hand rope falls
		# where a hand would reach for it. The lift shaft itself is elsewhere
		# in the lobby (x 0.85..3.0) and is untouched by this: a dumbwaiter is
		# its own small apparatus, not part of the passenger machine.
		var dumbwaiter := DumbwaiterProp.new()
		dumbwaiter.name = "LobbyServiceDumbwaiter"
		dumbwaiter.prop_type = "dumbwaiter"
		# Origin ON the partition face (x 5.24): the casing is authored
		# outward from z 0, so the whole apparatus stands in the corridor
		# rather than trying to occupy solid wall. The sill lands near 1.20.
		dumbwaiter.position = GameBoot.b2g([5.24, -4.90, 0.90])
		# NEGATIVE half-turn. Props on this run are authored with their working
		# face on local +Z, and a rotation of +PI/2 sends +Z to world +X --
		# straight into the partition at x 5.33. The corridor is on the WEST
		# side, so the face has to swing the other way. (The porter's board and
		# the mail bank above still use +PI/2 and therefore present their backs
		# to the corridor; that is a landed SR2/mail-pass issue, visible in
		# art/renders/dumbwaiter_brake_sr7a/06_wall_run.png, and is reported
		# rather than changed here.)
		dumbwaiter.rotation.y = -PI * 0.5
		floor_nodes["F01"].add_child(dumbwaiter)
		# SR7-B: the landing-door interlock, in the reveal of the F01 elevator
		# opening on its strike jamb.
		#
		# The opening runs x 1.47..2.38 in the core wall at y -6.75, and the
		# landing door panels hang inside the hoistway at y -6.675. Mounting the
		# lock case at y -6.72 puts it in the reveal on the LANDING side of
		# those panels, so the doors never occlude it at any point in their
		# travel and the player can reach it from the lobby floor. A jamb-
		# mounted lock case serviced from the landing is period practice for
		# this door type; the alternative -- burying it on the hoistway side --
		# would be unreachable through a solid wall.
		#
		# No rotation: b2g maps Blender -y to Godot +z, and the lobby lies at
		# -y from the shaft, so an unrotated prop already faces the room. The
		# apparatus is authored outward from local z 0, as SR7-A established.
		var interlock := ElevatorInterlockProp.new()
		interlock.name = "F01LandingInterlock"
		interlock.prop_type = "elevator_interlock"
		# x 2.22, not hard against the jamb: the assembly is 0.28 m across
		# (retiring cam to locked contact) and the opening ends at 2.38, so a
		# tighter placement pushes the locked-contact pair into solid wall.
		interlock.position = GameBoot.b2g([2.22, -6.72, 1.34])
		floor_nodes["F01"].add_child(interlock)
		# SR7-F: the watchman's time detector, on the clear run of the east wall
		# between the 1D and 1C entry doors.
		#
		# THE SERVICE END OF THIS WALL IS FULL, and it was measured rather than
		# assumed. Southward it carries LobbyMailBank (y -8.56..-7.20), the post
		# tray, LobbyMailChute (-6.92..-6.58), LobbyPorterBoard (-6.33..-6.07) and
		# LobbyServiceDumbwaiter (-5.32..-4.48). The porter's board is where this
		# instrument belongs by rights, but the widest gap anywhere near it is the
		# 0.75 m between the board and the dumbwaiter -- a 0.34 case hung there
		# stands 0.20 m off two neighbours and reads as clutter.
		#
		# The wall's openings are at y -3.77..-2.86 and -0.13..0.78, so the run
		# BETWEEN the two doors is 2.73 m of unbroken panelling with nothing on it.
		# The case goes in the middle of it, 1.19 m clear of one door and 1.20 m of
		# the other, which is the first place on this wall where a glazed
		# instrument can actually be walked up to and read.
		#
		# It is deliberately far from the measured mail-wall composition at the
		# south end, which walk_test prices against the Vantry master at -8.97.
		#
		# Named to the floor-prefix convention the presentation audit expects,
		# and NOT registered as a `wall_clock` marker: that marker count is a
		# hard 2 and this is not one of the building's two clocks. It keeps no
		# WorkOrders reference either -- `clock_prop.gd` is the one prop that
		# closes a job, and SR7 apparatus deliberately do not.
		#
		# -PI/2, as everything else on this run: authored facing local +Z with
		# the lobby west of the partition.
		var detector := WatchmanClockPropScript.new()
		detector.name = "F01_WATCHMAN_DETECTOR"
		detector.prop_type = "watchman_detector"
		# HEIGHT IS SET BY THE MILLWORK, not by taste. `build_orison.py` runs the
		# lobby dado to 1.32 with a 0.04 cap on top and a bullnose bead at 1.355,
		# and that cap stands about 0.035 proud of the plaster -- further out than
		# this case is deep. Hung any lower, the chair rail passes straight through
		# the glass. A clock goes ABOVE the panelling, which is where they were hung
		# anyway; the dial then centres at 1.66, a standing man's eye.
		detector.position = GameBoot.b2g([5.24, -1.50, 1.44])
		detector.rotation.y = -PI * 0.5
		floor_nodes["F01"].add_child(detector)
		# SR7-G: the night register, on the same clear run and the same mounting
		# line, immediately south of the detector.
		#
		# THE WATCHMAN STATION IS NOW TWO OBJECTS, which is what it always was in
		# a real building: an instrument that records the round and a board that
		# accounts for the keys. They share a wall on purpose.
		#
		# The run between the two entry doors is -2.86..-0.13 and the detector
		# holds -1.68..-1.32, leaving 1.18 m south of it. A 0.62 case centred on
		# -2.27 sits in the middle of that: 0.29 m clear of the door opening and
		# 0.29 m clear of the detector, symmetric, and above the 1.355 bullnose
		# bead for the same millwork reason the detector is.
		#
		# It registers NO marker kind, closes no job and owns no lock. It reads
		# WorkOrders and DoorProp.leaf_state and writes neither.
		var register := NightRegisterPropScript.new()
		register.name = "F01_NIGHT_REGISTER"
		register.prop_type = "night_register"
		register.position = GameBoot.b2g([5.24, -2.27, 1.42])
		register.rotation.y = -PI * 0.5
		floor_nodes["F01"].add_child(register)
		# The settle west of the street door is a place to actually sit.
		var bench := LobbyBenchZone.new()
		bench.position = GameBoot.b2g([-2.45, -9.30, 0.0])
		floor_nodes["F01"].add_child(bench)
	# SR7-K: the watchman's line has two ends on two different floors, so the
	# network that IS the line is built before either of them.
	var stations := WatchStationNetworkScript.new()
	stations.name = "WatchStationNetwork"
	add_child(stations)
	if floor_nodes.has("F01"):
		# SR7-K: the far end of the wire, at the lobby watchman station.
		#
		# MEASURED PLACEMENT. The east wall's clear run between the service
		# dumbwaiter's north edge (b y -4.48) and the night register's shelf
		# (-2.63) is 1.85 m of plaster with nothing on it. A 0.40 case centred
		# on -3.55 spans -3.75..-3.35: 0.73 m clear of the dumbwaiter and
		# 0.72 m clear of the register.
		#
		# NEAR the detector and the register, and MECHANICALLY DISTINCT from
		# both -- three instruments in one lane, each answering one question.
		# It hangs at the same 1.42 the rest of the station does.
		var receiver := WatchRegisterPropScript.new()
		receiver.name = "F01_SIGNAL_REGISTER"
		receiver.prop_type = "signal_register"
		receiver.position = GameBoot.b2g([5.24, -3.55, 1.42])
		receiver.rotation.y = -PI * 0.5
		floor_nodes["F01"].add_child(receiver)
		stations.attach_receiver(receiver)
		# SR7-L: the tour key's own guard, between the signal register and the
		# night register.
		#
		# MEASURED PLACEMENT. The lane's east wall now reads, north-bound:
		# dumbwaiter to -4.48, signal register -3.75..-3.35, night register
		# shelf -2.63..-1.91, detector -1.68..-1.32. The 0.72 m of plaster
		# between the receiver and the register shelf is the only gap left in
		# the lane, and a 0.16 guard centred on -2.99 sits in the middle of it
		# with 0.28 m clear on each side.
		#
		# MECHANICALLY SEPARATE FROM THE NIGHT REGISTER, and physically so: a
		# different board, a different hook, a different check number. The
		# apartment and plant keys account for rooms; this one works stations.
		var guard := TourKeyGuardPropScript.new()
		guard.name = "F01_TOUR_KEY_GUARD"
		guard.prop_type = "tour_key_guard"
		guard.position = GameBoot.b2g([5.24, -2.99, 1.42])
		guard.rotation.y = -PI * 0.5
		floor_nodes["F01"].add_child(guard)
		stations.attach_key_guard(guard)
		# SR7-N: the standpipe hose station, on the riser this file already
		# draws.
		#
		# EVERY NUMBER HERE IS DERIVED. The infrastructure loop above puts a
		# continuous red riser at b(3.02, -3.02) on every floor with brass
		# couplings at z+0.18, z+1.55 and z+2.92 -- geometry with no owner,
		# batched into a MultiMesh that has no collision and no script. This
		# apparatus is deliberately NOT a second standpipe. It hangs on that
		# one.
		#
		# THE WALL. The stair core is the atrium, and the layout gives it a
		# south wall on y -3.25 and an east wall on x 3.25, both 0.18 thick,
		# so their inner faces are y -3.16 and x 3.16. Every floor also has a
		# solid landing across the south strip, x -3.16..3.16 by y -3.16..-1.46
		# -- which is what makes this a place a man can stand.
		#
		# The south face is taken: the batched electrical panel spans x
		# 2.52..2.94, its decal 2.12..2.60, the brackets 2.15, and the riser
		# itself is jammed into the corner at 3.02 with only 0.14 to the east
		# wall. The EAST face is empty from the corner up to the first window,
		# whose opening starts at y -1.45. So the cabinet goes on x 3.16 at
		# y -2.48, facing west.
		#
		# THE 0.14 IS NOT DECORATION. The cabinet is 0.62 wide, so its south
		# cheek stands at y -2.79 and the riser's west face at -2.965: 0.175 m
		# of open wall between them, which is exactly enough for the branch to
		# be SEEN crossing. The first sheet was shot with the cabinet at -2.62,
		# where the gap is 0.035 and the connection to the riser was a claim
		# nobody could photograph. It was moved for that reason.
		#
		# THE HEIGHT IS THE CODE'S. C26-1403.0 wants the rack between five and
		# six and one-half feet above the landing; the rack pins sit at local
		# y 0.42, so the origin goes at 1.62 - 0.42 = 1.20 and the pins land at
		# 1.62 m, which is 5 ft 4 in. The riser's own coupling at 1.55 is
		# inside the same band, which is why the branch has anywhere to come
		# from.
		#
		# -PI/2, so local +z maps to building -x and the cabinet faces west
		# onto the landing; local +x then runs south, toward the riser.
		var fire_line := FireLineCabinetPropScript.new()
		fire_line.name = "F01_FIRE_LINE_STAIR"
		fire_line.prop_type = "fire_line_cabinet"
		fire_line.station_id = "F01_FIRE_LINE_STAIR"
		fire_line.position = GameBoot.b2g([3.16, -2.48,
				FireLineCabinetPropScript.RACK_ABOVE_FLOOR
				- FireLineCabinetPropScript.RACK_LOCAL_Y])
		fire_line.rotation.y = -PI * 0.5
		floor_nodes["F01"].add_child(fire_line)
	if floor_nodes.has("F02"):
		# SR7-J: the first watch station, on the way to Mina's Vantry point.
		#
		# THE ROUTE IS WHY IT IS HERE. The lift lands on the corridor ring's
		# south-east side (`LiftSheave` b(4.86, -4.73)); 2A's entry is
		# `F02_DOOR_02` on the ring's WEST wall at b(-5.33, -2.11); and the
		# Vantry point the opening report sends you to is inside that flat at
		# b(-9.20, -3.04). So the approach runs west along the south leg and
		# then NORTH up the west wall, and this box is the last thing on that
		# wall before the door -- passed on the way in, at eye level, without
		# being a waypoint anybody has to be told about.
		#
		# The wall face is x = -5.33 and the case builds outward into the
		# corridor, so it faces EAST: `rotation.y = +PI/2` (the lobby register
		# faces west off the opposite wall with -PI/2).
		#
		# F02's floor is at z 3.2 and floor nodes sit at the origin, so the
		# height passed here is ABSOLUTE: 3.2 + 1.42 = 4.62, the same 1.42 the
		# lobby apparatus hangs at and squarely in a standing eye line.
		#
		# It registers no marker kind, owns no light, no job, no case and no
		# save key, and its only body is an Area3D reach, which reports
		# overlaps and blocks nothing.
		var station := WatchStationPropScript.new()
		station.name = "F02_WATCH_STATION_01"
		station.prop_type = "watch_station"
		station.station_id = "F02_STATION_2A_LANDING"
		station.position = GameBoot.b2g([-5.33, -3.10, 4.62])
		station.rotation.y = PI * 0.5
		floor_nodes["F02"].add_child(station)
		stations.register(station)
	if floor_nodes.has("F03"):
		# SR7-O: the soda-acid extinguisher, on the backboard this file already
		# draws.
		#
		# THE BOARD IS NOT NEW AND IS NOT REDRAWN. The infrastructure loop at
		# the top of this function batches, on EVERY floor, a flat red box at
		# b(-2.76, -3.10) that is 0.34 wide, 0.08 DEEP and 0.70 tall, and the
		# comment beside it calls it an extinguisher cabinet. Eighty
		# millimetres cannot hold a vessel 230 across, so it is not a cabinet:
		# it is the painted BACKBOARD an extinguisher hangs in front of, and
		# reading it that way is what lets this apparatus bind to the authored
		# location instead of inventing a second visual family. The box stays
		# batched, exactly as it was, on all eight floors.
		#
		# THE ORIGIN IS THE BOARD. The box is centred at y -3.10 and 0.08 deep,
		# so its front face is at -3.06; it spans z+0.70 to z+1.40, so its
		# bottom edge is z+0.70. The prop's local origin is that face at that
		# edge -- b(-2.76, -3.06, z+0.70) -- and the vessel is built OUTWARD
		# from it, projecting 0.25 into the landing and reaching z+1.51 at the
		# cap. Nothing here is a free choice; every number is read off the box.
		#
		# WHY F03. The board exists on all eight floors and this hangs on one.
		# F03's core pendant `F03_ATRIUM_FRUIT_1` is 3.15 m from the board --
		# the closest any floor's core light comes to it, against 3.95 on F01
		# and worse above -- so this is the one instance a man could actually
		# read by the stair's own light. It is also two floors above SR7-N's
		# standpipe cabinet, 5.90 apart, which keeps two different fire
		# apparatus from being mistaken for one lane.
		#
		# CIRCULATION, and these are the LIVE PROOF'S numbers rather than this
		# comment's. The south strip of the well, x -3.16..3.16 by
		# y -3.16..-1.46, is a solid landing at every level. The stair doorway
		# in the south wall spans x -1.6..1.6, so the board's west edge stands
		# 0.99 clear of its jamb, out of the traffic line; the up-flight from
		# this floor runs in the WEST strip through y -1.46..1.46, well north
		# of the board. The vessel's face reaches y -2.812, leaving 1.35 of
		# landing in front of it. F03's pendant is measured at 3.18, and
		# SR7-N's cabinet at 5.90 below.
		#
		# PI, so local +z maps to building +y and the extinguisher faces north
		# off the south wall onto the landing; local +x then runs west.
		var extinguisher := SodaAcidExtinguisherPropScript.new()
		extinguisher.name = "F03_EXTINGUISHER_STAIR"
		extinguisher.prop_type = "soda_acid_extinguisher"
		extinguisher.station_id = "F03_EXTINGUISHER_STAIR"
		extinguisher.position = GameBoot.b2g([-2.76, -3.06, 6.4 + 0.70])
		extinguisher.rotation.y = PI
		floor_nodes["F03"].add_child(extinguisher)
	if floor_nodes.has("B1"):
		# SR7-M: the second watch station, at the boiler.
		#
		# WHY HERE, AND WHY IT MATTERS TO A 1928 WATCHMAN. `B1_BOILER` is a
		# real generated room with a real boiler standing in it at
		# b(9.05, 1.55), 2.05 m tall, and a real coal bunker `B1_COAL` off it
		# through `B1_DOOR_07`. A coal-fired plant is the fire risk that put a
		# watchman on the payroll in the first place: banked fires, hot ash and
		# a coal pile that can heat itself. The insurance round exists for this
		# room before it exists for anything else.
		#
		# IT CONTRASTS WITH STATION 2 IN EVERY WAY THAT MATTERS. That one is a
		# papered residential corridor at eye level on the way to a resident's
		# door; this one is the plant -- basement, machinery, heat, and a place
		# nobody lives. Two boxes, two reasons, one key.
		#
		# MEASURED PLACEMENT: the COAL BUNKER'S north wall, y 2.70, between the
		# boiler at b(9.05, 1.55) and the coal behind the wall it hangs on.
		# Both fire risks in one standing position, which is the whole reason
		# an insurer wanted a man down here.
		#
		# AND IT IS THE ONLY LIT WALL IN THE ROOM. `B1_BOILER` has exactly one
		# fixture, `B1_BOILER_LT_CAGE_BULB` at b(9.58, 4.38); the boiler-room
		# south party wall -- the first choice, on the boiler's own axis -- is
		# 5.3 m from it with the boiler itself in the way, and photographed as
		# a black rectangle. This wall is 2.4 m from that bulb. A station a
		# watchman cannot read by the room's own light is a station he cannot
		# work, and the sheet proved it before the reasoning did.
		#
		# B1's floor is at z -2.8 and floor nodes sit at the origin, so the
		# height is ABSOLUTE: -2.8 + 1.42 = -1.38, the same 1.42 above the
		# boards the rest of the apparatus hangs at.
		#
		# Facing NORTH into the room: local +z maps to world -z at rotation.y
		# = PI, where the F02 box faces east at +PI/2.
		var boiler_station := WatchStationPropScript.new()
		boiler_station.name = "B1_WATCH_STATION_01"
		boiler_station.prop_type = "watch_station"
		boiler_station.station_id = "B1_STATION_BOILER"
		boiler_station.position = GameBoot.b2g([12.00, 2.70, -1.38])
		boiler_station.rotation.y = PI
		floor_nodes["B1"].add_child(boiler_station)
		stations.register(boiler_station)
		# SR7-E: the working face of the first house panelboard.
		#
		# The electrical plant is NOT invented here. `B1_ELECTRICAL` is a real
		# generated room and `b1_panel0` is a real baked cabinet on its east
		# wall at x 13.30..13.44, y -7.2..-6.4, standing 0.9 to 1.9 above the
		# basement floor with `b1_econduit` feeding it. This apparatus stands
		# on that cabinet's own front plane at x 13.30 and builds WEST into the
		# room, so the baked box is its back and nothing is duplicated or
		# moved. `SwitchSystem` keeps every fixture it already owned.
		#
		# -PI/2, as on the lobby east run: props are authored facing local +Z
		# and the room lies west of the cabinet.
		#
		# The height is ABSOLUTE. B1 sits at -2.8 and its floor node is at the
		# origin, so a panel placed at a floor-local 0.9 would land in the
		# lobby; the live test asserts the global height for that reason.
		var fuse_panel := FusePanelPropScript.new()
		fuse_panel.name = "B1_HOUSE_PANEL"
		fuse_panel.prop_type = "fuse_panel"
		fuse_panel.position = GameBoot.b2g([13.30, -6.80, -2.8 + 0.90])
		fuse_panel.rotation.y = -PI * 0.5
		floor_nodes["B1"].add_child(fuse_panel)
	if floor_nodes.has("ROOF"):
		# SR7-C: the house-tank ball cock, on the south face of the timber
		# water tank the generator already bakes at building (-9.45, 4.95) on
		# four cast-iron legs.
		#
		# The tank is real and predates this: what it never had was a
		# mechanism, an inlet, or the overflow that `art/data/gen_layout.py`
		# already claims the roof water butt stands under. The apparatus is
		# hung on the south face near the west end so its overflow discharges
		# over that butt, and so the cock, its seat, the riser stop and the
		# lever weight all land at a standing hand's height on the deck while
		# the float rides high in its guard where it can be read.
		#
		# No rotation: b2g maps building -y to Godot +z and the open roof lies
		# at -y from the tank, so an unrotated prop already faces the deck.
		#
		# The height is ABSOLUTE, not floor-local. The F01 props above happen
		# to read either way because F01 sits at z 0; the ROOF floor node is
		# likewise at the origin and its glTF carries the 19.2 internally, so
		# a roof prop placed at a local 1.30 lands inside the basement. The
		# live test asserts the global height for exactly this reason.
		var ballcock := RoofTankBallcockProp.new()
		ballcock.name = "ROOF_TANK_BALLCOCK"
		ballcock.prop_type = "tank_ballcock"
		ballcock.position = GameBoot.b2g([-9.05, 4.90, 19.2 + 1.30])
		floor_nodes["ROOF"].add_child(ballcock)
	# Opening night: the building starts sealed. Deferred so every door
	# has finished spawning before the locks turn.
	_lockdown_layout = layout
	call_deferred("_apply_opening_lockdown")
	# SR7-Q: a door check goes on a leaf, and no leaf exists yet either.
	call_deferred("_mount_stair_door_check")


## SR7-Q: the overhead liquid door check, on the one stair-enclosure leaf this
## building has.
##
## THE AUDIT PICKED THIS DOOR, AND IT CORRECTED THE PREMISE IT WAS GIVEN.
## Sweeping every leaf in the built tree returns 113 doors, and exactly ONE of
## them stands on the stair enclosure: `ROOF_DOOR_01`, the galvanized service
## leaf at the head of the stair, measured at b(-1.330, -3.250, 19.200), 0.96
## wide, hung to swing north into the bulkhead. EVERY OTHER STAIR CORE IN THE
## ORISON OPENS THROUGH A 3.2 m CASED OPENING WITH NO LEAF IN IT AT ALL, so
## "the stair-enclosure doors" is not a thing this building has. This one is.
##
## WHY THIS LEAF EARNS A CHECK ANYWAY. It is the door between a stair shaft and
## the open roof: the one leaf in the Orison where a draught has somewhere to
## go, and the only one whose being left standing open changes the weather
## inside the stair. If any leaf here was ever fitted with a check, this is it.
##
## DEFERRED for the same reason the opening lockdown two lines above is:
## `building_root._spawn_props()` runs AFTER this pass, so at `build()` time
## there is not a single door in the tree to hang anything on.
##
## MOUNTED ON THE DOOR NODE, WHICH IS THE FRAME -- never on `HingedLeaf`, which
## is the moving body. The DoorProp node sits on the fixed hinge line, so a
## child of it is frame-fixed, which is where a spring box belongs and which
## keeps this apparatus out of the leaf's transform entirely.
##
## CLEARANCE, MEASURED, AGAINST SR7-P. The roof backboard is authored at
## b(-2.76, -3.06) and this hinge stands at x -1.330; the closer's own iron
## occupies local x 0.13..0.78 east of the hinge, which puts its NEAREST part
## at x -1.200 and its far end at x -0.550 -- 1.56 m and 2.21 m east of the
## board's centre. The live suite measures the near figure rather than trusting
## this comment. Nothing overlaps, and the board keeps every clearance SR7-P
## proved for it.
func _mount_stair_door_check() -> void:
	var root := get_parent()
	var leaf: Node = root.find_child("ROOF_DOOR_01", true, false) if root else null
	if leaf == null or leaf.get("leaf_state") == null:
		push_warning("[SR7-Q] ROOF_DOOR_01 absent; no door check mounted")
		return
	var check := DoorCheckCloserPropScript.new()
	check.name = "ROOF_DOOR_CHECK"
	check.prop_type = "door_check_closer"
	# The leaf authority is this node's own parent, and the only thing this
	# apparatus is ever allowed to ask.
	check.door_path = NodePath("..")
	leaf.add_child(check)


## SR7-P: whatever is on this floor's backboard, drawn into the batch the board
## itself lives in.
##
## THE VOCABULARY IS SHAPE, NOT TONE, and that was a measurement rather than a
## preference. The first sheet photographed all eight boards from the same
## standing place and the light across them runs from near-black in the B1
## stair core to open daylight on the roof bulkhead. A dust shadow a few per
## cent lighter than the board would have been invisible on half the floors, so
## every condition here is something with an edge that catches light and throws
## a shadow.
func _build_board_condition(batch: Dictionary, floor_id: String,
		z: float) -> void:
	var condition := str(BOARD_CONDITIONS.get(floor_id, ""))
	if condition == "" or condition == "working":
		return
	# The batch's shared metal material darkens vertex colour as much as the
	# trim one lifts it: 0.60 copper photographed as a black mass against the
	# board. Measured up until the vessel reads as metal rather than shadow.
	var copper := Color(0.880, 0.505, 0.262)
	var brass := Color(0.905, 0.720, 0.330)
	# The batch's shared trim material lifts vertex colour considerably: the
	# first sheet rendered 0.255 grey as bone-coloured and the straps read as
	# wood. Measured back down until they read as painted iron.
	var iron := Color(0.088, 0.084, 0.080)
	# The rectangle the bracket kept clean. A shade LIGHTER than the board and
	# standing 6 mm proud of it, so it reads by its own edge and its own small
	# shadow rather than by being a slightly different red.
	var kept := Color(0.605, 0.150, 0.096)
	var card := Color(0.760, 0.742, 0.668)
	var vessel_y := BOARD_FACE_Y + 0.115

	if condition == "stripped":
		# Bracket and vessel both gone. What is left is the paint the STRAPS
		# kept clean -- two bands and a foot, in the bracket's own shape rather
		# than one anonymous rectangle, because the shape is what says a
		# bracket was bolted here and taken off again.
		for band_z in [z + 0.86, z + 1.18]:
			_box(batch, [BOARD_X, BOARD_FACE_Y + 0.003, band_z],
					[0.300, 0.006, 0.062], kept)
		_box(batch, [BOARD_X, BOARD_FACE_Y + 0.003, z + 0.755],
				[0.300, 0.006, 0.048], kept)
		for bolt in [[-0.138, 0.86], [0.138, 0.86], [-0.138, 1.18],
				[0.138, 1.18]]:
			_cylinder(batch, [BOARD_X + bolt[0], BOARD_FACE_Y + 0.011,
					z + bolt[1]], [0.010, 0.014, 0.010], iron)
		return

	# Both remaining conditions keep the bracket: two straps and a foot rest,
	# bolted through the board.
	for strap_z in [z + 0.86, z + 1.18]:
		_box(batch, [BOARD_X, vessel_y + 0.126, strap_z],
				[0.300, 0.024, 0.026], iron)
		for side in [-0.138, 0.138]:
			_box(batch, [BOARD_X + side, vessel_y + 0.010, strap_z],
					[0.024, 0.270, 0.026], iron)
	_box(batch, [BOARD_X, BOARD_FACE_Y + 0.088, z + 0.745],
			[0.300, 0.170, 0.020], iron)

	if condition == "empty_bracket":
		# The bracket is still bolted up and there is nothing in it. Through the
		# straps you see the board, and the paint the vessel used to keep clean.
		_box(batch, [BOARD_X, BOARD_FACE_Y + 0.003, z + 1.02],
				[0.208, 0.006, 0.430], kept)
		# The card the man who took it away hung on the strap. It says nothing
		# this file knows; it is a piece of pasteboard on a wire, and it is here
		# because a bracket with a card on it is a bracket somebody emptied on
		# purpose rather than a bracket that was never filled.
		_cylinder(batch, [BOARD_X + 0.086, vessel_y + 0.126, z + 1.128],
				[0.0016, 0.070, 0.0016], iron)
		_box(batch, [BOARD_X + 0.086, vessel_y + 0.126, z + 1.062],
				[0.086, 0.004, 0.062], card)
		return

	# hung: a complete vessel, and deliberately plainer than SR7-O's. It has no
	# cage, no cap knurl, no hose, no charge plate and NO TAG, because nothing
	# here has been inspected. It is a copper pot on two straps.
	_cylinder(batch, [BOARD_X, vessel_y, z + 1.020],
			[0.113, 0.520, 0.113], copper)
	_cylinder(batch, [BOARD_X, vessel_y, z + 0.775],
			[0.117, 0.030, 0.117], brass)
	_cylinder(batch, [BOARD_X, vessel_y, z + 1.322],
			[0.074, 0.086, 0.074], copper)
	_cylinder(batch, [BOARD_X, vessel_y, z + 1.396],
			[0.054, 0.062, 0.054], brass)


func _build_resident_details(layout: Dictionary, floor_nodes: Dictionary,
		batches: Dictionary) -> void:
	var rehung := 0
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		push_warning("resident story-detail catalog missing")
		return
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	for profile in catalog.residents:
		var unit: String = profile.unit
		var floor_id := "F0" + unit.left(1)
		if not floor_nodes.has(floor_id):
			continue
		var floor: Dictionary = {}
		for candidate in layout.floors:
			if candidate.id == floor_id:
				floor = candidate
				break
		var room := _living_room(floor, unit)
		if room.is_empty():
			continue
		var rect: Array = room.rect
		var seed := absi(str(profile.resident).hash())
		var slot := float(profile.get("slot", 0))
		var u := clampf(0.20 + float(seed % 17) * 0.012 + slot * 0.10,
				0.14, 0.42)
		var v := clampf(0.22 + float((seed >> 5) % 19) * 0.010,
				0.18, 0.42)
		var x := lerpf(float(rect[0]), float(rect[2]), u)
		var y := lerpf(float(rect[1]), float(rect[3]), v)
		var z := float(floor.z)
		var color_data: Array = profile.accent
		var accent := Color(float(color_data[0]), float(color_data[1]),
				float(color_data[2]))
		# A tiny authored still life: document/archive box, vessel, and paper
		# stack. Transform and color vary per resident while meshes are shared.
		_box(batches[floor_id], [x, y, z + 0.13],
				[0.42, 0.32, 0.24], accent)
		_box(batches[floor_id], [x + 0.28, y + 0.08, z + 0.055],
				[0.30, 0.22, 0.075], Color(0.68, 0.61, 0.47))
		_cylinder(batches[floor_id], [x - 0.27, y + 0.04, z + 0.16],
				[0.09, 0.30, 0.09], accent.lightened(0.18))
		var panel := int(profile.panel)
		# A named layout backing owns the coordinate. Lena's collage used to
		# infer an east wall from the living-room rectangle, but 2B's east edge
		# is occupied by its bathroom; the quad consequently floated on shower
		# glass. The generator now supplies a real cork board and this pass only
		# adds its paper face, keeping Blender and runtime on one authored hook.
		var backing_id := str(profile.get("backing", ""))
		if backing_id != "":
			var backing: Dictionary = {}
			for item in floor.get("furniture", []):
				if str(item.get("id", "")) == backing_id:
					backing = item
					break
			if backing.is_empty():
				push_error("resident story backing missing: " + backing_id)
				continue
			var board_at: Array = backing.at
			var board_yaw := deg_to_rad(float(backing.get("yaw", 0.0)))
			var front := Vector2(-sin(board_yaw), cos(board_yaw))
			var board_z := float(backing.get("z0", 1.0)) \
					+ float(backing.get("H", 0.66)) * 0.5
			var mounted := _add_decal(floor_nodes[floor_id], STORY_ATLAS,
					panel % 2, panel / 2,
					[float(board_at[0]) + front.x * 0.033,
					float(board_at[1]) + front.y * 0.033, z + board_z],
					board_yaw, Vector2(0.54, 0.54))
			mounted.name = "ResidentStory_" + unit
			continue
		var wall_west := seed % 2 == 0
		var wall_x := float(rect[0]) + 0.105 if wall_west \
				else float(rect[2]) - 0.105
		var wall_y := lerpf(float(rect[1]), float(rect[3]),
				clampf(0.30 + slot * 0.16, 0.18, 0.78))
		# A LIVING RECT CONTAINS ITS OWN BATHROOM. The bath is carved out of
		# the living room but the rect is never subtracted, so "0.105 inside
		# my east wall" is a point inside the bath wherever the two share
		# that edge — and eight residents' stories were pinned to the far
		# side of a bathroom wall. Try the other hand, then decline: this
		# pass has no fallback ladder, and an unhung story beats one hung in
		# the neighbour's shower.
		if WallArtLaw.nested_room_blocks(floor, room, wall_x, wall_y):
			rehung += 1
			wall_west = not wall_west
			wall_x = float(rect[0]) + 0.105 if wall_west \
					else float(rect[2]) - 0.105
			if WallArtLaw.nested_room_blocks(floor, room, wall_x, wall_y):
				push_warning("no living-room wall for %s's story" % unit)
				continue
		_add_decal(floor_nodes[floor_id], STORY_ATLAS,
				panel % 2, panel / 2,
				[wall_x, wall_y, z + 1.34],
				PI * 0.5 if wall_west else -PI * 0.5,
				Vector2(0.54, 0.54))


	if rehung > 0:
		print("[BUILDING] %d resident stories rehung off a bathroom wall"
				% rehung)


func _living_room(floor: Dictionary, unit: String) -> Dictionary:
	for room in floor.get("rooms", []):
		if room.get("unit", "") == unit \
				and room.get("kind", "") == "living":
			return room
	for room in floor.get("rooms", []):
		if room.get("unit", "") == unit:
			return room
	return {}


func _box(batch: Dictionary, position_b: Array, size_b: Array,
		color: Color) -> void:
	batch.boxes.append({
		"transform": Transform3D(
			Basis.IDENTITY.scaled(Vector3(size_b[0], size_b[2], size_b[1])),
			GameBoot.b2g(position_b)),
		"color": color,
	})
	detail_count += 1


func _cylinder(batch: Dictionary, position_b: Array, size_b: Array,
		color: Color) -> void:
	batch.cylinders.append({
		"transform": Transform3D(
			Basis.IDENTITY.scaled(Vector3(size_b[0] * 2.0, size_b[1],
					size_b[2] * 2.0)),
			GameBoot.b2g(position_b)),
		"color": color,
	})
	detail_count += 1


func _emit_batch(parent: Node3D, entries: Array, mesh: PrimitiveMesh,
		material_key: String) -> void:
	if entries.is_empty():
		return
	var material := MatLib.get_mat(material_key).duplicate()
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = entries.size()
	for index in entries.size():
		multimesh.set_instance_transform(index, entries[index].transform)
		multimesh.set_instance_color(index, entries[index].color)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)


func _add_decal(parent: Node3D, atlas: String, col: int, row: int,
		position_b: Array, yaw: float, size: Vector2) -> StoryDecal:
	var decal := StoryDecal.new()
	decal.setup(atlas, col, row, size)
	decal.position = GameBoot.b2g(position_b)
	decal.rotation.y = yaw
	parent.add_child(decal)
	decal_count += 1
	return decal
