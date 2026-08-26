class_name FireLineCabinetProp
extends FunctionalProp
## A standpipe hose station: wired-glass cabinet, linen hose on a rack, and
## four joints, only one of which you can see.
##
## SR7-N. THE HOSE IS NOT WATER.
##
## THE AUDIT CAME FIRST, AND IT CHANGED WHERE THIS HANGS.
##
## The Orison already draws a fire-protection APPEARANCE and owns no fire
## protection at all. `orison_detail_pass.gd` batches, on every floor beside
## the stair core, a continuous red riser 0.11 m across at building
## (3.02, -3.02) with brass couplings at z+0.18, z+1.55 and z+2.92, a flat red
## "extinguisher cabinet" at (-2.76, -3.10), and pipe brackets. All of it is
## MultiMesh: no collision, no script, no owner, no mechanism. The roof deck
## even carries a piece of hose -- `roof_hose`, a 2 m strip of `soot` furniture
## lying beside the water tank -- which is the joke this increment is named
## after, sitting in the layout file since before any of this.
##
## So the honest move was NOT to invent a second standpipe. This apparatus
## hangs on the riser the building already draws, at the coupling the building
## already draws, at the height the building already chose: z+1.55, which lands
## inside the code band for a hose rack by accident and is kept by design.
##
## THE TRUTH THIS TEACHES, and it is arithmetic rather than a slogan:
##
##     line_made_up() = gasket_seated
##                  AND coupling_made_up
##                  AND nozzle_coupled
##                  AND nozzle_shut
##
## `hose_racked` IS NOT A TERM. Fifty feet of sound flax line, folded on its
## rack behind clear wired glass, contributes exactly nothing to whether there
## is a line. The cabinet can be full and correct and photograph beautifully
## and still be an ornament.
##
## And the glass is the second half of it. Section C26-1404.0 glazes the door
## so the hose can be seen without opening it -- which means the one fact the
## glass is designed to deliver is the one fact that does not matter. THE GLASS
## SHOWS THE HOSE. IT DOES NOT SHOW THE JOINT.
##
## AS FOUND, three of the four terms are false, and only one of them is
## visible:
##
##   * The coupling is MADE UP to the outlet valve and there is NO GASKET in
##     it. Hand-tight, square, correct-looking, and it would blow past under
##     any pressure at all. Nothing outside the joint can report this. The only
##     way to learn it is to break the joint and look, which is why signing the
##     tag requires `gasket_seen` and not merely `gasket_seated`: YOU MAY NOT
##     CERTIFY A JOINT YOU HAVE NOT OPENED.
##   * The play-pipe is not coupled. It lies loose in the rack. In the rack
##     patents the nozzle is also the KEEPER -- pull it and the folds pay out --
##     so an uncoupled nozzle is two failures wearing one coat.
##   * Its control valve is open, left that way after whatever last happened
##     here.
##
## AND ONE HONEST DUTY THAT IS NOT A TERM. Unlined linen must be unracked,
## looked at and re-racked on a DIFFERENT fold, or it cracks along the crease
## it has been sitting in. That is real, documented maintenance; the folds here
## are set; refolding them is correct work; and it moves `line_made_up()` not
## one bit. There are two ways to hold a hose and not have water, and doing
## good work on the wrong one is the second.
##
## THE VALVE IS NOT A VERB. There is no control that opens it. A watchman who
## opened a house standpipe valve to see whether there was water would flood
## the stair hall and soak fifty feet of linen that is extremely difficult to
## dry -- which is precisely why unlined hose is exempted from the pressure
## test that every other hose gets. The refusal is the lesson: THE ONE ACTION
## THAT WOULD PROVE THERE IS WATER IS THE ONE ACTION YOU MUST NOT TAKE. This
## apparatus proves a line dry, by its joints, or not at all.
##
## HISTORICAL BASIS -- documented mechanism.
##   * J. H. STILLWAGGON, US 1,150,075, "Hose-rack", filed 5 February 1915,
##     patented 17 August 1915. The hose rides in loops on pivoting arms and
##     the NOZZLE IS THE CATCH: pull it out and "the weight of the loops of
##     hose on arms is free to turn the trough member and the arms on their
##     common axis, and the result is the precipitation of the hose to the
##     floor, uncoiled." The rack is a mechanism, not a shelf, and the nozzle
##     is part of it.
##   * J. M. BAKER of Providence, Rhode Island, US 1,132,899, "Play-pipe for
##     use with fire-hose", filed 13 August 1914, patented 23 March 1915. The
##     play-pipe carries its own "control-valve adapted to prevent the force of
##     the water passing therethrough from causing the pipe to kick or pull
##     back", for "easier and more convenient manipulation in turning on and
##     shutting off the water". The far end of the line has a valve on it, and
##     the state of that valve is a fact about the line.
##   * J. J. BOWES, Jr., of Pensacola, Florida, US 1,093,528, "Hose-coupling",
##     filed 18 July 1913, patented 14 April 1914: a pocket "into which is
##     fitted a substantially U-shaped gasket or washer 11, the latter serving
##     to prevent leakage when the female member A receives the male member B".
##     A. BENZINGER of Cincinnati, assigned to Walter M. Schoenle,
##     US 1,257,785, "Hose or pipe coupling", filed 18 August 1917, granted
##     26 February 1918, does the same work with gaskets "in series in
##     hindering leakage". THE THREAD IS NOT THE SEAL. The seal is a separate
##     part sitting in a pocket, and the thread hides it.
##
## HISTORICAL BASIS -- codified later, cited as later.
##   * NEW YORK CITY BUILDING CODE 1938, Subarticle 5. C26-1398.0: "flax line,"
##     unlined linen fire hose, FACTORY COUPLED, 1 1/2 in. permitted in office
##     buildings and hotels, not more than 125 ft at any outlet valve.
##     C26-1400.0: 1 1/2 in. hose "shall be provided with a five-eighth inch
##     smooth bore nozzle". C26-1403.0: "The hose at each outlet shall be kept
##     upon an approved hose rack, firmly supported and placed between five and
##     six and one-half feet above the landing or floor." C26-1404.0: a single
##     swinging door "which shall have a large panel of clear wired glass", and
##     "All hose cabinets shall be permanently marked across the door panel
##     'FIRE HOSE' in red letters at least two and one-half inches in height."
##     This text is ten years after the Orison's 1928 and is cited as the
##     earliest verifiable wording for an arrangement that was already ordinary
##     -- the NFPA Committee on Standpipe and Hose Systems reported in 1912,
##     was amended in 1914, adopted in 1915, and had revisions adopted in 1926
##     and 1927, so a national standard was current in the year this building
##     is played in.
##   * 29 CFR 1910.158, modern and quoted as modern, preserves both halves of
##     the lesson in the regulator's own words: (c)(3)(i) requires every
##     1 1/2 in. or smaller outlet to be "equipped with hose CONNECTED and
##     ready for use", and (e)(2)(v) requires hemp or linen hose to be
##     "unracked, physically inspected for deterioration, and reracked using a
##     different fold pattern at least annually".
##
## ORISON-SPECIFIC INFERENCE, stated plainly. That this riser is fed from the
## Orison's own roof gravity tank is inference: the tank is real production
## geometry and SR7-C gave it a ball cock, but no pipe joins them and none is
## modelled here. This cabinet, its corner, its lettering, the pencil on its
## tag and the particular three faults it was found with are authored. The
## grimed glass is authored too, and argued for above.
##
## OWNERSHIP. This apparatus owns its own condition and nothing else. It issues
## no work order, closes no job, activates no case, writes no save key, joins
## no watch line and adds nothing to any round. It publishes one neutral fact,
## `line_inspected`, which nothing subscribes to.
##
## AUTHORING RULE. Local z = 0 is the mounting plane on the stair core's east
## wall and the cabinet is built OUTWARD along +z, onto the landing.

## The one neutral fact this apparatus publishes.
signal line_inspected(record: Dictionary)

const ControlArea = preload("res://scripts/props/prop_control_area.gd")

## The four facts that make a line. Note what is absent.
const LINE_TERMS := ["gasket_seated", "coupling_made_up", "nozzle_coupled",
		"nozzle_shut"]
## What an inspection record may contain. `hose_racked` is in here so that the
## record can say, in writing, that the hose was present and it did not help.
const RECORD_FIELDS := ["station_id", "at_minute", "hose_racked", "folds_fresh",
		"gasket_seated", "coupling_made_up", "nozzle_coupled", "nozzle_shut",
		"line_made_up"]
## C26-1398.0 permits 1 1/2 in. flax line; C26-1400.0 gives it a 5/8 in. tip.
const HOSE_LEGEND := "1 1/2 IN. FLAX LINE  50 FT"
const NOZZLE_LEGEND := "5/8 IN. SMOOTH BORE"
const DOOR_LEGEND := "FIRE HOSE"
const VALVE_LEGEND := "DO NOT OPEN EXCEPT FOR FIRE"
const TAG_BLANK := "- - -"
## C26-1403.0 puts the rack between five and six and one-half feet above the
## landing. The rack pins sit 1.62 m up, and the placement in
## `orison_detail_pass.gd` is derived from this constant rather than guessed.
const RACK_ABOVE_FLOOR := 1.62
const RACK_LOCAL_Y := 0.42
## The hour the tag reads with no day/night owner in the tree: the same
## canonical 03:00 the rest of SR7 tests and renders at.
const CANONICAL_MINUTE := 180.0
## C26-1404.0: red letters at least two and one-half inches high.
const DOOR_LETTER_M := 0.066

@export var station_id := "F01_FIRE_LINE_STAIR"

# --- the facts this apparatus owns -------------------------------------------

## Fifty feet of sound flax line, on its rack, from the first frame to the
## last. It is never false and it is never a term.
var hose_racked := true
var door_open := false
## Set in the crease it has been sitting in. Correctable, correct to correct,
## and irrelevant to the line.
var folds_fresh := false
## The gasket. Absent, inside a joint that is made up over it.
var gasket_seated := false
## Whether anybody has broken the joint and looked this inspection.
var gasket_seen := false
var coupling_made_up := true
var nozzle_coupled := false
var nozzle_shut := false
var tag_signed := false
var tag_line := TAG_BLANK

var _door_pivot: Node3D
var _coupling: Node3D
var _gasket_ring: MeshInstance3D
var _empty_pocket: MeshInstance3D
var _spare_gasket: MeshInstance3D
var _play_pipe: Node3D
var _lever: Node3D
var _folds: Node3D
var _fold_leaves: Array[MeshInstance3D] = []
var _fold_turns: Array[MeshInstance3D] = []
var _valve_wheel: Node3D
var _tag: Node3D
var _tag_label: Label3D
var _knock: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D

var _balk_left := 0.0
var _balk_focus := ""
var _last_record: Dictionary = {}
var _clock_source: Node = null


# --- what a line is ----------------------------------------------------------

## The whole thesis, in four terms and one absence.
func line_made_up() -> bool:
	for term in LINE_TERMS:
		if not bool(get(term)):
			return false
	return true


## Deliberately its own predicate, so that nothing can quietly fold it into the
## one above.
func hose_present() -> bool:
	return hose_racked


## You may not certify a joint you have not opened, and you may not certify a
## cabinet you have not opened either.
func certifiable() -> bool:
	return door_open and gasket_seen and line_made_up()


func line_faults() -> Array[String]:
	var missing: Array[String] = []
	for term in LINE_TERMS:
		if not bool(get(term)):
			missing.append(str(term))
	return missing


func house_minute() -> float:
	if _clock_source == null or not is_instance_valid(_clock_source):
		var node: Node = self
		while node != null:
			if node.get("day_night_director") != null:
				_clock_source = node.get("day_night_director")
				break
			node = node.get_parent()
	if _clock_source != null and _clock_source.has_method("_minute_now"):
		return float(_clock_source.call("_minute_now"))
	return CANONICAL_MINUTE


func last_record() -> Dictionary:
	return _last_record.duplicate(true)


func tag_reads() -> String:
	return tag_line


func balking() -> bool:
	return _balk_left > 0.0


func balk_focus() -> String:
	return _balk_focus


# --- the hand work -----------------------------------------------------------

func open_door() -> bool:
	if door_open:
		_balk(1.4, "door")
		return false
	door_open = true
	if _click != null:
		_click.play()
	_refresh_cabinet()
	return true


func close_door() -> bool:
	if not door_open:
		_balk(1.4, "door")
		return false
	door_open = false
	if _click != null:
		_click.play()
	_refresh_cabinet()
	return true


## Break the joint at the outlet. This is the only way anything in the building
## learns what is or is not inside it.
func break_joint() -> bool:
	if not door_open:
		_balk(1.6, "door")
		return false
	if not coupling_made_up:
		_balk(1.6, "joint")
		return false
	coupling_made_up = false
	gasket_seen = true
	if _knock != null:
		_knock.play()
	_refresh_cabinet()
	return true


## Fit the gasket from its tin into the coupling's pocket. Impossible through a
## made-up joint, which is the whole reason the fault could sit here for years.
func seat_gasket() -> bool:
	if not door_open:
		_balk(1.6, "door")
		return false
	if coupling_made_up:
		_balk(1.8, "gasket")
		return false
	if gasket_seated:
		_balk(1.4, "gasket")
		return false
	gasket_seated = true
	gasket_seen = true
	if _click != null:
		_click.play()
	_refresh_cabinet()
	return true


## Make the hose up to the outlet. Permitted with the pocket empty, because
## that is exactly how this one was found: a coupling will go up square and
## hand-tight over nothing at all.
func make_up_coupling() -> bool:
	if not door_open:
		_balk(1.6, "door")
		return false
	if coupling_made_up:
		_balk(1.6, "joint")
		return false
	coupling_made_up = true
	if _knock != null:
		_knock.play()
	_refresh_cabinet()
	return true


func couple_nozzle() -> bool:
	if not door_open:
		_balk(1.6, "door")
		return false
	if nozzle_coupled:
		_balk(1.4, "nozzle")
		return false
	nozzle_coupled = true
	if _knock != null:
		_knock.play()
	_refresh_cabinet()
	return true


func shut_nozzle() -> bool:
	if not door_open:
		_balk(1.6, "door")
		return false
	if nozzle_shut:
		_balk(1.4, "lever")
		return false
	nozzle_shut = true
	if _click != null:
		_click.play()
	_refresh_cabinet()
	return true


## Unrack, look at it, rack it again on a different fold. Correct work. It
## makes no line.
func refold_hose() -> bool:
	if not door_open:
		_balk(1.6, "door")
		return false
	if folds_fresh:
		_balk(1.4, "folds")
		return false
	folds_fresh = true
	if _click != null:
		_click.play()
	_refresh_cabinet()
	return true


## There is no path through this that ends in the valve opening.
func try_open_valve() -> bool:
	_balk(2.0, "valve")
	return false


## Write the date on the tag wired to the valve. Publishes one neutral fact and
## claims nothing else.
func sign_tag() -> bool:
	if not door_open:
		_balk(1.8, "tag")
		return false
	if tag_signed:
		_balk(1.6, "tag")
		return false
	if not gasket_seen:
		_balk(2.0, "joint")
		return false
	if not line_made_up():
		_balk(2.0, _focus_for_fault())
		return false
	tag_signed = true
	# What a pencil fits on a tag: the hour, and the one word it is entitled to
	# say. Not "tested" -- nothing here was tested. Made up.
	tag_line = "%02d.%02d  MADE UP" % [int(house_minute()) / 60 % 24,
			int(house_minute()) % 60]
	_last_record = _record()
	if _click != null:
		_click.play()
	_refresh_cabinet()
	line_inspected.emit(_last_record.duplicate(true))
	return true


## A refusal has to point at the thing that refused, or two refusals in one
## cabinet come back as the same photograph.
func _focus_for_fault() -> String:
	if not gasket_seated:
		return "gasket"
	if not coupling_made_up:
		return "joint"
	if not nozzle_coupled:
		return "nozzle"
	if not nozzle_shut:
		return "lever"
	return "tag"


func _record() -> Dictionary:
	return {
		"station_id": station_id,
		"at_minute": house_minute(),
		"hose_racked": hose_racked,
		"folds_fresh": folds_fresh,
		"gasket_seated": gasket_seated,
		"coupling_made_up": coupling_made_up,
		"nozzle_coupled": nozzle_coupled,
		"nozzle_shut": nozzle_shut,
		"line_made_up": line_made_up(),
	}


# --- the shared maintenance contract -----------------------------------------

func maintenance_snapshot() -> Dictionary:
	return {
		"door_open": door_open,
		"hose_racked": hose_racked,
		"folds_fresh": folds_fresh,
		"gasket_seated": gasket_seated,
		"gasket_seen": gasket_seen,
		"coupling_made_up": coupling_made_up,
		"nozzle_coupled": nozzle_coupled,
		"nozzle_shut": nozzle_shut,
		"tag_signed": tag_signed,
		"tag_line": tag_line,
	}


## Abort restores every fact this apparatus owns. It cannot retract a record
## already published, and does not pretend to.
func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	door_open = bool(snapshot.get("door_open", false))
	hose_racked = bool(snapshot.get("hose_racked", true))
	folds_fresh = bool(snapshot.get("folds_fresh", false))
	gasket_seated = bool(snapshot.get("gasket_seated", false))
	gasket_seen = bool(snapshot.get("gasket_seen", false))
	coupling_made_up = bool(snapshot.get("coupling_made_up", true))
	nozzle_coupled = bool(snapshot.get("nozzle_coupled", false))
	nozzle_shut = bool(snapshot.get("nozzle_shut", false))
	tag_signed = bool(snapshot.get("tag_signed", false))
	tag_line = str(snapshot.get("tag_line", TAG_BLANK))
	_balk_left = 0.0
	_balk_focus = ""
	_refresh_cabinet()


# --- interaction -------------------------------------------------------------

func control_prompt(control_id: String) -> String:
	match control_id:
		"door":
			if door_open:
				return "[E]  Shut the cabinet"
			return "[E]  %s -- fifty feet behind the glass" % DOOR_LEGEND
		"joint":
			if not door_open:
				return "[E]  The glass shows the hose, not the joint"
			if coupling_made_up:
				if gasket_seen:
					return "[E]  Break the joint again"
				return "[E]  Made up -- break it and look inside"
			return "[E]  Make the hose up to the outlet"
		"gasket":
			if not door_open:
				return "[E]  The gasket tin is inside"
			if gasket_seated:
				return "[E]  The gasket is in the pocket"
			if coupling_made_up:
				return "[E]  You cannot reach the pocket through a made-up joint"
			return "[E]  Fit the gasket into the coupling"
		"nozzle":
			if not door_open:
				return "[E]  The play-pipe is inside"
			if not nozzle_coupled:
				return "[E]  Couple the play-pipe to the hose"
			return "[E]  %s, coupled" % NOZZLE_LEGEND
		"lever":
			if not door_open:
				return "[E]  The play-pipe is inside"
			if nozzle_shut:
				return "[E]  The control valve is shut"
			return "[E]  Shut the play-pipe's control valve"
		"folds":
			if not door_open:
				return "[E]  %s, behind wired glass" % HOSE_LEGEND
			if folds_fresh:
				return "[E]  Re-racked on a fresh fold"
			return "[E]  Unrack and re-rack it on a different fold"
		"valve":
			return "[E]  %s" % VALVE_LEGEND
		"tag":
			if tag_signed:
				return "[E]  The tag reads  %s" % tag_line
			if not door_open:
				return "[E]  The inspection tag, behind the glass"
			if not gasket_seen:
				return "[E]  Sign the tag (the joint has not been opened)"
			if not line_made_up():
				return "[E]  Sign the tag (%d of 4 joints)" % \
						(LINE_TERMS.size() - line_faults().size())
			return "[E]  Sign the tag -- line made up"
	return ""


func interact_control(control_id: String, _player: Node) -> bool:
	match control_id:
		"door":
			return close_door() if door_open else open_door()
		"joint":
			return make_up_coupling() if not coupling_made_up else break_joint()
		"gasket":
			return seat_gasket()
		"nozzle":
			return couple_nozzle()
		"lever":
			return shut_nozzle()
		"folds":
			return refold_hose()
		"valve":
			return try_open_valve()
		"tag":
			return sign_tag()
	return false


## The prompt for the apparatus as a whole, which is the door. Without this the
## interaction inventory does not count the cabinet at all and a player looking
## straight at it is told nothing -- caught by `InteractionInventory`, which
## listed thirty-five functional families and none of them this one.
func interact_prompt() -> String:
	return control_prompt("door")


func interact(_player: Node) -> void:
	if door_open:
		close_door()
	else:
		open_door()


# --- pose --------------------------------------------------------------------

func _balk(seconds: float, focus := "") -> void:
	var already := _balk_left > 0.0
	_balk_focus = focus
	_balk_left = maxf(_balk_left, clampf(seconds, 0.0, 3.0))
	if not already and _knock != null:
		_knock.play()
	# The pose is applied HERE and not left to `_process`, because a frozen
	# sheet does not tick and a refusal nobody can photograph is not a refusal.
	_refresh_cabinet()


func _process(delta: float) -> void:
	if _balk_left <= 0.0:
		return
	_balk_left = maxf(0.0, _balk_left - delta)
	if _balk_left <= 0.0:
		_balk_focus = ""
		_refresh_cabinet()


## Every owned fact, put back onto the iron. Rest poses are written before the
## balk block returns, so a refusal never inherits the last refusal's pose.
func _refresh_cabinet() -> void:
	if _door_pivot != null:
		_door_pivot.rotation.y = 1.78 if door_open else 0.0
	if _coupling != null:
		if coupling_made_up:
			_coupling.position = Vector3(0.17, 0.520, 0.098)
			_coupling.rotation = Vector3.ZERO
		else:
			_coupling.position = Vector3(0.17, 0.430, 0.126)
			_coupling.rotation = Vector3(0.92, 0.0, 0.30)
	if _gasket_ring != null:
		_gasket_ring.visible = gasket_seated and not coupling_made_up
	if _empty_pocket != null:
		_empty_pocket.visible = not gasket_seated and not coupling_made_up
	if _spare_gasket != null:
		_spare_gasket.visible = not gasket_seated
		_spare_gasket.position = Vector3(-0.248, 0.165, 0.096)
	if _play_pipe != null:
		if nozzle_coupled:
			_play_pipe.position = Vector3(0.045, 0.205, 0.120)
			_play_pipe.rotation = Vector3(0.0, 0.0, 2.42)
		else:
			_play_pipe.position = Vector3(-0.060, 0.068, 0.112)
			_play_pipe.rotation = Vector3(0.0, 0.0, 1.5708)
	if _lever != null:
		_lever.rotation.z = 0.0 if nozzle_shut else -0.95
	if _folds != null:
		_folds.position = Vector3.ZERO
		var pitch := 0.0295
		for index in _fold_leaves.size():
			var leaf := _fold_leaves[index]
			var x := -0.255 + float(index) * pitch
			if folds_fresh:
				x += pitch * 0.5
			# A re-racked hose does not come back on the same crease, and the
			# stack does not come back the same length either.
			var drop := 0.0
			if folds_fresh:
				drop = 0.016 if index % 2 == 1 else 0.004
			leaf.position.x = x
			leaf.position.y = RACK_LOCAL_Y - 0.140 - drop
			if index < _fold_turns.size():
				_fold_turns[index].position.x = x
				_fold_turns[index].position.y = RACK_LOCAL_Y - 0.271 - drop
	if _valve_wheel != null:
		_valve_wheel.rotation = Vector3.ZERO
	if _tag != null:
		_tag.rotation = Vector3.ZERO
	if _tag_label != null:
		# A pencilled tag is two short lines, not one long one: the hour over
		# the words. `tag_line` itself stays flat, because that is what the
		# record and the prompt read.
		_tag_label.text = tag_line.replace("  ", "\n")
	if _balk_left <= 0.0:
		return
	# --- refusals, each one a different photograph ---------------------------
	match _balk_focus:
		"door":
			if _door_pivot != null:
				_door_pivot.rotation.y += -0.10 if door_open else 0.13
		"joint":
			if _coupling != null:
				_coupling.rotation.z += 0.26
				_coupling.position.z += 0.028
		"gasket":
			if _spare_gasket != null:
				_spare_gasket.visible = true
				_spare_gasket.position = Vector3(0.170, 0.474, 0.176)
		"nozzle":
			if _play_pipe != null:
				_play_pipe.position.z += 0.055
				_play_pipe.rotation.x += 0.30
		"lever":
			if _lever != null:
				_lever.rotation.z += -0.34 if nozzle_shut else 0.30
		"folds":
			if _folds != null:
				_folds.position = Vector3(0.0, -0.020, 0.042)
		"valve":
			# The wheel takes your weight and does not come round.
			if _valve_wheel != null:
				_valve_wheel.rotation = Vector3(0.075, 0.36, 0.0)
		"tag":
			if _tag != null:
				_tag.rotation = Vector3(-0.62, 0.0, 0.22)


# --- build -------------------------------------------------------------------

func _build_visual() -> void:
	_build_riser_branch()
	_build_case()
	_build_valve()
	_build_rack()
	_build_play_pipe()
	_build_gasket_tin()
	_build_door()
	_build_reaches()
	_knock = make_emitter("knock", -14.0)
	_click = make_emitter("pop", -19.0)
	_refresh_cabinet()


## The elbow off the riser production already draws, and every number in it is
## derived rather than picked.
##
## The riser stands at building (3.02, -3.02) and carries a brass coupling at
## z+1.55. This cabinet hangs at (3.16, -2.48) with its origin 1.20 m up, so in
## local terms that coupling is at:
##
##     x = -(-3.02 - -2.48) = 0.540     (local +x is building south)
##     y =   1.55 - 1.20    = 0.350     (local +y is height)
##     z =   3.16 -  3.02   = 0.140     (local +z is building west)
##
## The take-off is drawn at z 0.098 rather than 0.140, which is 42 mm shy of
## the riser's centre line and therefore INSIDE a pipe 0.055 in radius. The
## branch touches the iron the building already had; it does not float beside
## it.
##
## And it runs HORIZONTALLY, at the coupling's own height, across the 0.175 m
## of open wall between the riser and the cabinet's south cheek -- because a
## branch nobody can see is a claim rather than a connection.
func _build_riser_branch() -> void:
	var pipe := Color(0.46, 0.10, 0.065)
	var brass := Color(0.72, 0.56, 0.24)
	# The take-off boss, on the riser's own coupling at building z+1.55.
	make_cyl(0.031, 0.031, 0.058, Vector3(0.540, 0.350, 0.098), brass, 0.34,
			0.78)
	# West into the cabinet, in the open, at that height.
	var run := make_cyl(0.024, 0.024, 0.290, Vector3(0.400, 0.350, 0.098),
			pipe, 0.62, 0.30)
	run.name = "BranchRun"
	run.rotation.z = PI * 0.5
	make_cyl(0.029, 0.029, 0.046, Vector3(0.255, 0.350, 0.098), brass, 0.34,
			0.78)
	# And up the inside of the case to the valve, clear of the coupling.
	var rise := make_cyl(0.022, 0.022, 0.262, Vector3(0.255, 0.481, 0.098),
			pipe, 0.62, 0.30)
	rise.name = "BranchRise"
	var into := make_cyl(0.021, 0.021, 0.062, Vector3(0.224, 0.612, 0.098),
			pipe, 0.62, 0.30)
	into.rotation.z = PI * 0.5
	# The 2 1/2 in. department outlet on the riser, capped. Modelled and given
	# no verb: an engine company's connection is not a watchman's business, and
	# it never becomes one here.
	var nipple := make_cyl(0.038, 0.038, 0.075, Vector3(0.540, 0.480, 0.148),
			brass, 0.34, 0.78)
	nipple.rotation.x = PI * 0.5
	var cap := make_cyl(0.044, 0.044, 0.028, Vector3(0.540, 0.480, 0.198),
			brass, 0.30, 0.80)
	cap.name = "DepartmentCap"
	cap.rotation.x = PI * 0.5


func _build_case() -> void:
	var red := Color(0.520, 0.130, 0.088)
	# A PALE LINING. Cabinet interiors were painted light on purpose -- a box
	# whose contents cannot be read is a box nobody inspects -- and it is the
	# same fix SR7-J's cast-iron station needed for the same reason.
	var lining := Color(0.735, 0.715, 0.665)
	make_box(Vector3(0.620, 0.780, 0.018), Vector3(0.0, 0.390, 0.009), lining)
	make_box(Vector3(0.022, 0.780, 0.200), Vector3(-0.299, 0.390, 0.110), red)
	make_box(Vector3(0.022, 0.780, 0.200), Vector3(0.299, 0.390, 0.110), red)
	make_box(Vector3(0.620, 0.022, 0.200), Vector3(0.0, 0.769, 0.110), red)
	make_box(Vector3(0.620, 0.022, 0.200), Vector3(0.0, 0.011, 0.110), red)
	make_box(Vector3(0.010, 0.760, 0.190), Vector3(-0.283, 0.390, 0.108),
			lining)
	make_box(Vector3(0.010, 0.760, 0.190), Vector3(0.283, 0.390, 0.108),
			lining)
	make_box(Vector3(0.566, 0.010, 0.190), Vector3(0.0, 0.753, 0.108), lining)
	make_box(Vector3(0.566, 0.010, 0.190), Vector3(0.0, 0.027, 0.108), lining)
	# A raised bead round the opening: the thing that keeps a painted steel box
	# from reading as a slab.
	for edge in [Vector3(0.0, 0.775, 0.196), Vector3(0.0, 0.005, 0.196)]:
		make_box(Vector3(0.640, 0.016, 0.016), edge, red)
	for edge in [Vector3(-0.305, 0.390, 0.196), Vector3(0.305, 0.390, 0.196)]:
		make_box(Vector3(0.016, 0.796, 0.016), edge, red)
	# The stencilled instruction plate on the inside back, above the rack.
	_letter("HoseLegend", HOSE_LEGEND, Vector3(-0.108, 0.582, 0.021), 0.0195,
			Color(0.135, 0.125, 0.115))
	_letter("HoseLegend2", "RACK 5 FT 4 IN. ABOVE LANDING",
			Vector3(-0.108, 0.552, 0.021), 0.0165,
			Color(0.245, 0.230, 0.215))


func _build_valve() -> void:
	var brass := Color(0.72, 0.56, 0.24)
	var iron := Color(0.30, 0.295, 0.280)
	var red := Color(0.520, 0.130, 0.088)
	make_box(Vector3(0.072, 0.086, 0.072), Vector3(0.17, 0.612, 0.098), brass)
	make_cyl(0.012, 0.012, 0.048, Vector3(0.17, 0.672, 0.098), iron, 0.45, 0.70)
	_valve_wheel = Node3D.new()
	_valve_wheel.name = "ValveWheel"
	_valve_wheel.position = Vector3(0.17, 0.696, 0.098)
	add_child(_valve_wheel)
	make_ring(0.046, 0.008, Vector3.ZERO, red, 0.55, 0.25, _valve_wheel)
	for spoke_index in 3:
		var spoke := _move(make_box(Vector3(0.092, 0.010, 0.010),
				Vector3.ZERO, red), _valve_wheel, Vector3.ZERO)
		spoke.rotation.y = float(spoke_index) * PI / 3.0
	make_cyl(0.018, 0.018, 0.046, Vector3(0.17, 0.556, 0.098), brass, 0.34,
			0.78)
	# The coupling. Everything about the fault lives on this pivot, so the
	# broken pose has to turn the mouth of it toward whoever is looking --
	# a pocket photographed edge-on teaches nothing.
	_coupling = Node3D.new()
	_coupling.name = "Coupling"
	add_child(_coupling)
	make_cyl(0.032, 0.032, 0.050, Vector3.ZERO, brass, 0.32, 0.80, _coupling)
	make_cyl(0.036, 0.036, 0.010, Vector3(0.0, 0.022, 0.0), brass, 0.30, 0.82,
			_coupling)
	make_cyl(0.021, 0.021, 0.052, Vector3(0.0, -0.048, 0.0),
			Color(0.80, 0.75, 0.60), 0.72, 0.0, _coupling)
	_gasket_ring = make_ring(0.0205, 0.0085, Vector3(0.0, 0.030, 0.0),
			Color(0.255, 0.165, 0.130), 0.90, 0.0, _coupling)
	_gasket_ring.name = "Gasket"
	_empty_pocket = make_cyl(0.024, 0.024, 0.008, Vector3(0.0, 0.024, 0.0),
			Color(0.045, 0.042, 0.040), 0.92, 0.0, _coupling)
	_empty_pocket.name = "EmptyPocket"
	# The inspection tag, wired to the valve stem and hanging forward against
	# the glass, where the only writing on this apparatus that ever changes can
	# be read the moment the door swings.
	_tag = Node3D.new()
	_tag.name = "InspectionTag"
	_tag.position = Vector3(0.248, 0.520, 0.152)
	add_child(_tag)
	var wire := make_cyl(0.0015, 0.0015, 0.130, Vector3(-0.038, 0.078, -0.022),
			Color(0.50, 0.47, 0.42), 0.6, 0.55, _tag)
	wire.rotation.z = -0.52
	_move(make_box(Vector3(0.100, 0.058, 0.002), Vector3.ZERO,
			Color(0.88, 0.855, 0.775)), _tag, Vector3.ZERO)
	_tag_label = _letter("TagLine", TAG_BLANK, Vector3(0.0, 0.002, 0.003),
			0.0105, Color(0.13, 0.12, 0.11), _tag)


func _build_rack() -> void:
	var brass := Color(0.72, 0.56, 0.24)
	var linen := Color(0.815, 0.760, 0.605)
	# Two pins, per the rack patents: the hose rides in loops over them.
	for pin_x in [-0.245, 0.020]:
		var pin := make_cyl(0.009, 0.009, 0.150,
				Vector3(pin_x, RACK_LOCAL_Y, 0.100), brass, 0.42, 0.70)
		pin.rotation.x = PI * 0.5
	make_box(Vector3(0.300, 0.014, 0.014),
			Vector3(-0.112, RACK_LOCAL_Y + 0.016, 0.030), brass)
	_folds = Node3D.new()
	_folds.name = "HoseFolds"
	add_child(_folds)
	_fold_leaves.clear()
	# Ten folds, butted, EACH WITH ITS OWN TURN at the bottom. A row of flat
	# leaves photographs as a radiator; what makes it read as one flattened
	# hose doubled back on itself is the scalloped edge where each fold turns.
	for leaf_index in 10:
		var leaf := make_box(Vector3(0.0285, 0.262, 0.118), Vector3.ZERO,
				linen)
		leaf.name = "Fold_%02d" % leaf_index
		_move(leaf, _folds, Vector3(0.0, 0.0, 0.100))
		_fold_leaves.append(leaf)
		var turn := make_cyl(0.0145, 0.0145, 0.118, Vector3.ZERO, linen, 0.80,
				0.0)
		turn.name = "Turn_%02d" % leaf_index
		turn.rotation.x = PI * 0.5
		_move(turn, _folds, Vector3(0.0, 0.0, 0.100))
		_fold_turns.append(turn)
	# The crown over the pins, where the hose comes over the rack.
	var crown := make_cyl(0.021, 0.021, 0.300,
			Vector3(-0.112, RACK_LOCAL_Y + 0.006, 0.100), linen, 0.80, 0.0)
	crown.rotation.z = PI * 0.5
	# The run from the rack across to the outlet coupling.
	var lead := make_cyl(0.021, 0.021, 0.160, Vector3(0.098, 0.348, 0.100),
			linen, 0.78, 0.0)
	lead.rotation.z = -0.66


func _build_play_pipe() -> void:
	var brass := Color(0.72, 0.56, 0.24)
	_play_pipe = Node3D.new()
	_play_pipe.name = "PlayPipe"
	add_child(_play_pipe)
	make_cyl(0.011, 0.021, 0.170, Vector3(0.0, 0.085, 0.0), brass, 0.30, 0.80,
			_play_pipe)
	make_cyl(0.028, 0.028, 0.032, Vector3(0.0, -0.012, 0.0), brass, 0.34, 0.76,
			_play_pipe)
	_lever = Node3D.new()
	_lever.name = "PlayPipeLever"
	_lever.position = Vector3(0.0, 0.044, 0.0)
	_play_pipe.add_child(_lever)
	var arm := make_cyl(0.006, 0.006, 0.092, Vector3(0.042, 0.0, 0.0),
			Color(0.38, 0.36, 0.33), 0.5, 0.65, _lever)
	arm.rotation.z = PI * 0.5


func _build_gasket_tin() -> void:
	var brass := Color(0.66, 0.51, 0.23)
	make_box(Vector3(0.068, 0.022, 0.068), Vector3(-0.248, 0.150, 0.096), brass)
	make_box(Vector3(0.010, 0.052, 0.010), Vector3(-0.248, 0.188, 0.070),
			Color(0.42, 0.40, 0.37))
	_spare_gasket = make_ring(0.0205, 0.0085, Vector3(-0.248, 0.165, 0.096),
			Color(0.255, 0.165, 0.130), 0.90, 0.0)
	_spare_gasket.name = "SpareGasket"


## C26-1404.0's door: one swinging leaf, a large panel of clear wired glass,
## and FIRE HOSE across THE PANEL in red letters at least two and one-half
## inches high. The section says the panel, so the letters go on the glass and
## not on the rail below it -- which is also the only place on a red box where
## red letters can be read. Hinged on the +x edge, which is south, so the leaf
## never swings between a reader on the landing and the joint they came to
## look at.
func _build_door() -> void:
	var red := Color(0.520, 0.130, 0.088)
	var brass := Color(0.72, 0.56, 0.24)
	# Aged, grimed wired glass: opaque on purpose, and argued for in the
	# header. What it shows you is the shape of a full cabinet.
	var glass := Color(0.545, 0.575, 0.545)
	_door_pivot = Node3D.new()
	_door_pivot.name = "CabinetDoor"
	_door_pivot.position = Vector3(0.305, 0.390, 0.206)
	add_child(_door_pivot)
	var parts := [
		[Vector3(0.048, 0.780, 0.024), Vector3(-0.024, 0.0, 0.0), red],
		[Vector3(0.048, 0.780, 0.024), Vector3(-0.586, 0.0, 0.0), red],
		[Vector3(0.610, 0.052, 0.024), Vector3(-0.305, 0.364, 0.0), red],
		[Vector3(0.610, 0.150, 0.024), Vector3(-0.305, -0.315, 0.0), red],
	]
	for part in parts:
		_move(make_box(part[0], Vector3.ZERO, part[2]), _door_pivot, part[1])
	var pane := _move(make_box(Vector3(0.516, 0.610, 0.009), Vector3.ZERO,
			glass), _door_pivot, Vector3(-0.305, 0.055, 0.005))
	(pane.material_override as StandardMaterial3D).roughness = 0.22
	# The wire in the wired glass: what makes it wired glass and not a pane.
	for wire_index in 5:
		_move(make_box(Vector3(0.0035, 0.610, 0.004), Vector3.ZERO,
				Color(0.30, 0.265, 0.175)), _door_pivot,
				Vector3(-0.497 + float(wire_index) * 0.096, 0.055, 0.011))
	for wire_index in 6:
		_move(make_box(Vector3(0.516, 0.0035, 0.004), Vector3.ZERO,
				Color(0.30, 0.265, 0.175)), _door_pivot,
				Vector3(-0.305, -0.190 + float(wire_index) * 0.096, 0.011))
	var handle := make_cyl(0.011, 0.011, 0.058, Vector3.ZERO, brass, 0.34, 0.78)
	remove_child(handle)
	_door_pivot.add_child(handle)
	handle.position = Vector3(-0.578, 0.0, 0.034)
	handle.rotation.x = PI * 0.5
	_letter("DoorLegend", DOOR_LEGEND, Vector3(-0.305, -0.148, 0.014),
			DOOR_LETTER_M, Color(0.70, 0.085, 0.055), _door_pivot)


## `make_box` hangs its mesh on the prop; this moves one onto a sub-pivot
## without going through `reparent`, whose tree-order semantics are more than
## a static mesh needs.
func _move(mesh: MeshInstance3D, parent: Node3D, at: Vector3) -> MeshInstance3D:
	remove_child(mesh)
	parent.add_child(mesh)
	mesh.position = at
	return mesh


func _letter(node_name: String, text: String, at: Vector3, em: float,
		tint: Color, parent: Node3D = null) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.font_size = 64
	label.pixel_size = em / 64.0
	label.modulate = tint
	label.outline_size = 0
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.shaded = true
	label.double_sided = false
	(parent if parent != null else self).add_child(label)
	return label


## Seven places to put a hand, one per thing that is actually there. There is
## no order between them beyond what the iron itself imposes, and there is no
## place to put a hand that opens the valve.
func _build_reaches() -> void:
	var reaches := {
		"door": [Vector3(-0.170, 0.390, 0.215), Vector3(0.30, 0.62, 0.14)],
		"valve": [Vector3(0.170, 0.696, 0.098), Vector3(0.16, 0.11, 0.16)],
		"tag": [Vector3(0.248, 0.520, 0.155), Vector3(0.09, 0.10, 0.09)],
		"joint": [Vector3(0.138, 0.505, 0.110), Vector3(0.12, 0.12, 0.14)],
		"folds": [Vector3(-0.112, 0.310, 0.110), Vector3(0.34, 0.26, 0.16)],
		"nozzle": [Vector3(-0.050, 0.085, 0.110), Vector3(0.26, 0.10, 0.16)],
		"gasket": [Vector3(-0.250, 0.155, 0.100), Vector3(0.12, 0.14, 0.16)],
	}
	for control_id in reaches.keys():
		var reach := ControlArea.new()
		reach.name = "Reach_%s" % str(control_id)
		reach.configure(str(control_id))
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = reaches[control_id][1]
		shape_node.shape = shape
		shape_node.position = reaches[control_id][0]
		reach.add_child(shape_node)
		add_child(reach)


func service_wire_card() -> Dictionary:
	return {
		"title": "STANDPIPE HOSE STATION",
		"body": "FIFTY FEET OF LINEN PROVES POSSESSION NOT SUPPLY STOP "
				+ "THE LINE IS ITS JOINTS STOP",
		"condition": "LINE %s / HOSE RACKED" % ("MADE UP" if line_made_up()\
				else "NOT MADE UP"),
		"stamp": "FIRE LINE",
	}
