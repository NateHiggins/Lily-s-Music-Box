class_name SodaAcidExtinguisherProp
extends FunctionalProp
## A 2 1/2 gallon soda-acid extinguisher on the bracket the building already
## drew: copper vessel, brass cap, wire cage, acid bottle, and one loose cap
## that is not loose.
##
## SR7-O. THE SEAL IS NOT THE CHARGE.
##
## THE AUDIT CAME FIRST, AND IT DECIDED WHERE THIS HANGS.
##
## The Orison contains exactly ONE extinguisher object, and it is not an
## extinguisher. `orison_detail_pass.gd` batches, on every floor beside the
## stair core, a flat red box 0.34 wide by 0.08 DEEP by 0.70 tall at building
## (-2.76, -3.10), and its own comment calls it an "extinguisher cabinet". At
## 80 mm deep it cannot be a cabinet: a 2 1/2 gallon vessel is 230 mm across.
## It is a BACKBOARD -- the painted plate an extinguisher hangs in front of --
## and reading it that way is what lets this apparatus bind to the authored
## location instead of inventing a second visual family. Nothing is superseded
## and nothing is redrawn; the board stays exactly as batched and the
## extinguisher hangs on it.
##
## Everything else in the lane is empty: no extinguisher prop, no data record,
## no job, no activity, no case, no inventory item, no save fact, no signal, no
## fire owner. Searched by vocabulary across every .gd, .tscn, .json and .py --
## the only other hits are SR7-N's header quoting that same comment, and the
## Dream's unrelated business of extinguishing lamps.
##
## THE TRUTH THIS TEACHES, and it is a NON-IMPLICATION rather than a list:
##
##     sealed()    = cap_on AND seal_wired          <- what an inspection sees
##     charged()   = acid_present AND bottle_seated <- what a recharge leaves
##     will_lift() = loose_cap_free                 <- what makes it work
##
##     sealed() AND charged()  DOES NOT IMPLY  usable()
##
## AS FOUND, sealed() is true and charged() is TRUE AS WELL, and will_lift() is
## false. The lead-and-wire seal is unbroken, the tag is hanging, the bottle is
## in its cage, there are
## four ounces of oil of vitriol in it, there is a pound and a half of
## bicarbonate in two and a half gallons of water underneath, and the thing
## weighs exactly what a sound one weighs. It cannot work.
##
## THE FAULT IS THAT THE LOOSE CAP IS NOT LOOSE. In this family the acid bottle
## is closed by a cap that is merely LAID ON -- retained against falling out,
## never fastened -- because the whole operating principle is that inverting
## the vessel lets gravity take that cap off the neck and pour the acid into
## the soda solution. A cap seized by years of fume, or a tight one fitted in
## place of the loose one at the last recharge, leaves an extinguisher that is
## charged, sealed, tagged, correctly heavy, and inert.
##
## WEIGHT CANNOT SEE IT, AND NOT APPROXIMATELY. Nothing is missing. The hefted
## gross of this extinguisher in its faulted state is not close to the sound
## figure, it is THE SAME FLOAT, and the focused proof asserts that equality
## rather than a tolerance. A fault that removes something can be weighed. This
## one removes nothing.
##
## HOW IT IS FOUND, AND IT IS BY HAND. Cut the seal, unscrew the cap -- the
## cage and the bottle come up with it, which is what the cage is for -- draw
## the bottle out of its clips, and lift at its cap. IF THE BOTTLE COMES UP
## WITH THE CAP, that is the whole diagnosis, and it is a photograph rather
## than a sentence. Nothing in this apparatus tells the player what is wrong.
##
## AND THERE IS NO TEST. `invert()` refuses, always. Turning a soda-acid
## extinguisher over is not a test of it, it IS it: the cap lifts, the acid
## goes into the soda, and you are holding a spent vessel over a wet landing.
## The one action that would prove it works is the one that uses it up. There
## is no pressure gauge to read because there is no pressure until you commit,
## and this apparatus does not invent one.
##
## HISTORICAL BASIS -- DOCUMENTED, PRE-1928.
##   * J. M. MILLER of Chicago, US 883,326, "Acid-bottle cage for
##     fire-extinguishers", filed 30 April 1906, patented 31 March 1908. The
##     cage is spring clips "formed of resilient wire ... so as to provide a
##     cage for confining an acid bottle"; the bottle "is inserted into the
##     cage by passing the same downward through the ring 5 and pushing it down
##     until the clips 8' engage its shoulder and hold it firmly in position";
##     the clips "extend over the shoulder 11 of the bottle and support the
##     same when the casing is inverted"; and -- the sentence this whole
##     apparatus turns on -- "The usual LOOSE CAP 12 is provided for closing
##     the neck of the bottle and has the shank 13 which extends into said neck
##     to prevent the cap from falling out of place when the extinguisher is
##     inverted." Loose, and merely retained. That is the mechanism, and its
##     failure mode is written into its own description.
##   * H. M. McCASLIN, assigned to AMERICAN LA FRANCE FIRE ENGINE COMPANY,
##     Elmira, New York, US 1,182,186, "Fire-Extinguisher", filed 25 February
##     1916, patented 9 May 1916 -- twelve years before the Orison's 1928, from
##     a manufacturer that actually built these. It states the arrangement
##     plainly: "an alkaline solution carried by a tank and a quantity of acid
##     carried in a separate smaller receptacle in the tank, so as to be mixed
##     with the alkaline solution for creating a gas for forcing liquid through
##     a suitable discharge opening."
##   * A. M. GRANGER of Boston, US 258,293, "Bottle-breaking fire-extinguisher",
##     filed 15 September 1881, patented 23 May 1882 -- the American origin of
##     the soda-acid extinguisher, cited for the family rather than for this
##     unit's mechanism, since Granger's breaks the bottle by "a torsional
##     strain" where this one lifts a cap off it.
##
## HISTORICAL BASIS -- LATER CORROBORATION, CITED AS LATER.
##   * The commercial charge proportions -- about one and one-half pounds of
##     bicarbonate of soda to two and one-half gallons of water, with an eight-
##     ounce bottle half filled with sulphuric acid in a cage under the cap --
##     are as described for commercial soda-acid extinguishers in the later
##     patent record (US 2,554,727, 1951) and in retrospective accounts. The
##     PROPORTIONS are used here for the weight arithmetic; the FIGURES are not
##     claimed as a verified 1928 specification.
##   * The "lead and wire" seal -- soft wire through the lugs with its ends
##     buried in a lead pellet, so that it cannot be undone and re-made without
##     showing -- is described in retrospective accounts of the period hardware
##     rather than in a source I could verify from before 1928.
##
## WHAT I DELIBERATELY DO NOT CLAIM. I could not verify a pre-1928 rule
## requiring annual recharge or a dated inspection interval, so THIS APPARATUS
## ASSERTS NO SCHEDULE. It has no due date, no interval, no overdue state and
## no calendar. The tag records a condition found at an hour, and nothing about
## when anybody should come back. Projecting a modern inspection cadence onto
## 1928 would have been the easiest sentence in this file and it is not here.
##
## ORISON-SPECIFIC INFERENCE, stated plainly: that the batched red plate is a
## backboard rather than a cabinet; that this building hangs its extinguisher
## on the F03 stair landing; the enamel charge plate beside it; and the pencil
## on its tag. AUTHORED FAULT: that this particular unit's loose cap was seized
## at some past recharge. Nobody in the building knows that, including this
## script's own prompts, until a hand lifts it.
##
## OWNERSHIP. This apparatus owns its own condition and nothing else. It is not
## an extension of SR7-N: that is a fixed standpipe hose station on F01's east
## wall, a wet line made of joints, and this is a portable chemical vessel on
## F03's south wall whose lesson is a non-implication. They share a lane and
## nothing else -- no file, no signal, no predicate, no record, no term.
##
## AUTHORING RULE. Local z = 0 is the FRONT FACE of the authored backboard and
## the extinguisher is built OUTWARD along +z into the landing. Local y = 0 is
## the board's bottom edge.

## The one neutral fact this apparatus publishes. Nothing subscribes to it.
signal extinguisher_inspected(record: Dictionary)

const ControlArea = preload("res://scripts/props/prop_control_area.gd")

## What an inspection can see from outside.
const SEAL_TERMS := ["cap_on", "seal_wired"]
## What a recharge leaves behind.
const CHARGE_TERMS := ["acid_present", "bottle_seated"]
## What makes it an extinguisher. One term, and it is in neither list above.
const LIFT_TERMS := ["loose_cap_free"]
## The closed vocabulary of an inspection record. Every field is something a
## hand at this bracket can establish; there is no field for who, for when it
## is next due, or for anything the iron cannot know.
const RECORD_FIELDS := ["station_id", "at_minute", "gross_pounds",
		"acid_present", "bottle_seated", "loose_cap_free", "cap_on",
		"seal_wired", "sealed", "charged", "usable"]

## 2 1/2 US gallons of water is 20.86 lb; the charge adds about 1 1/2 lb of
## bicarbonate; four fluid ounces of oil of vitriol at 1.84 is about 0.48 lb;
## the copper vessel, cap, cage, hose and nozzle are the rest. The figure is
## a constant ON PURPOSE: the fault this apparatus carries removes nothing, so
## a sound unit and a dead one weigh the same, and `heft()` cannot tell them
## apart no matter how good the scale is.
const GROSS_POUNDS := 32.0
const CHARGE_LEGEND := "CHARGE 1 1/2 LB. SODA"
const CHARGE_LEGEND_2 := "2 1/2 GALS. WATER"
const TAG_BLANK := "- - -"

@export var station_id := "F03_EXTINGUISHER_STAIR"

# --- the facts this apparatus owns -------------------------------------------

## Four ounces of oil of vitriol, in the bottle, from the first frame to the
## last. It is true throughout and it never once helps.
var acid_present := true
var bottle_seated := true
var cap_on := true
var seal_wired := true
## THE FAULT. Everything above is right and this is not.
var loose_cap_free := false
## Whether a hand has actually lifted at that cap this inspection.
var cap_tested := false
var bottle_drawn := false
var tag_signed := false
var tag_line := TAG_BLANK

var _vessel: Node3D
var _body: MeshInstance3D
var _cap: Node3D
var _cage: Node3D
var _bottle: Node3D
var _acid_band: MeshInstance3D
var _loose_cap: MeshInstance3D
var _seal: Node3D
var _tag: Node3D
var _tag_label: Label3D
var _hooks: Node3D
var _knock: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D

var _balk_left := 0.0
var _balk_focus := ""
var _last_record: Dictionary = {}
var _clock_source: Node = null


# --- the three predicates, and the gap between them --------------------------

## What the outside of the vessel says.
func sealed() -> bool:
	for term in SEAL_TERMS:
		if not bool(get(term)):
			return false
	return true


## What the last recharge left in it.
func charged() -> bool:
	for term in CHARGE_TERMS:
		if not bool(get(term)):
			return false
	return true


## Whether the little cap will come off the neck when the vessel goes over --
## which is the whole of what makes this an extinguisher rather than a copper
## pot. Deliberately its own predicate, reading exactly one fact, so that
## nothing can quietly fold the seal or the charge into it.
##
## It is not called `free`, because `Object.free` already is.
func will_lift() -> bool:
	return loose_cap_free


func usable() -> bool:
	return will_lift() and charged() and sealed()


## The hefted gross. It does not consult a single owned fact, because the fault
## this unit carries takes nothing out of it.
func heft_pounds() -> float:
	return GROSS_POUNDS


## You may not certify a cap you have not lifted.
func certifiable() -> bool:
	return usable() and cap_tested and not tag_signed


func faults() -> Array[String]:
	var missing: Array[String] = []
	for term in SEAL_TERMS + CHARGE_TERMS + LIFT_TERMS:
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
	return 180.0


func last_record() -> Dictionary:
	return _last_record.duplicate(true)


func tag_reads() -> String:
	return tag_line


func balking() -> bool:
	return _balk_left > 0.0


func balk_focus() -> String:
	return _balk_focus


# --- the hand work -----------------------------------------------------------

## Take its weight on the bracket. Always available, always correct, and it
## settles nothing.
func heft() -> float:
	if _click != null:
		_click.play()
	return heft_pounds()


## Cut the lead-and-wire seal. The cap cannot turn until this is done, because
## the wire passes through the lugs.
func cut_seal() -> bool:
	if not seal_wired:
		_balk(1.4, "seal")
		return false
	seal_wired = false
	if _knock != null:
		_knock.play()
	_refresh_extinguisher()
	return true


func wire_seal() -> bool:
	if seal_wired:
		_balk(1.4, "seal")
		return false
	if not cap_on:
		_balk(1.6, "cap")
		return false
	seal_wired = true
	if _click != null:
		_click.play()
	_refresh_extinguisher()
	return true


## Unscrew the cap. The cage and whatever is in it come up with it.
func unscrew_cap() -> bool:
	if not cap_on:
		_balk(1.4, "cap")
		return false
	if seal_wired:
		_balk(1.8, "seal")
		return false
	cap_on = false
	if _knock != null:
		_knock.play()
	_refresh_extinguisher()
	return true


## Screw it back down. PERMITTED with the bottle still out on the shelf: an
## empty cage screws down as sweetly as a full one, which is a second way for
## this thing to look finished and not be.
func screw_cap() -> bool:
	if cap_on:
		_balk(1.4, "cap")
		return false
	cap_on = true
	if _knock != null:
		_knock.play()
	_refresh_extinguisher()
	return true


func draw_bottle() -> bool:
	if cap_on:
		_balk(1.8, "bottle")
		return false
	if bottle_drawn:
		_balk(1.4, "bottle")
		return false
	bottle_drawn = true
	bottle_seated = false
	if _knock != null:
		_knock.play()
	_refresh_extinguisher()
	return true


func seat_bottle() -> bool:
	if not bottle_drawn:
		_balk(1.4, "bottle")
		return false
	if cap_on:
		_balk(1.8, "bottle")
		return false
	bottle_drawn = false
	bottle_seated = true
	if _click != null:
		_click.play()
	_refresh_extinguisher()
	return true


## Lift at the loose cap. This is the entire diagnosis and it is done by hand:
## a cap that is loose comes off the neck, and a cap that is not brings the
## bottle with it.
func try_loose_cap() -> bool:
	if not bottle_drawn:
		_balk(1.6, "bottle")
		return false
	cap_tested = true
	if not loose_cap_free:
		_balk(2.0, "loose")
		_refresh_extinguisher()
		return false
	if _click != null:
		_click.play()
	_refresh_extinguisher()
	return true


## Work it free with the fingers -- or, which is the same repair, put a proper
## loose cap on in place of whatever is on there now.
func free_loose_cap() -> bool:
	if not bottle_drawn:
		_balk(1.6, "bottle")
		return false
	if loose_cap_free:
		_balk(1.4, "loose")
		return false
	loose_cap_free = true
	cap_tested = true
	if _knock != null:
		_knock.play()
	_refresh_extinguisher()
	return true


## There is no path through this that ends in the extinguisher being turned
## over. Inverting it is not a test of the mechanism, it is the mechanism.
func invert() -> bool:
	_balk(2.2, "invert")
	return false


func sign_tag() -> bool:
	if tag_signed:
		_balk(1.6, "tag")
		return false
	if not cap_on:
		_balk(1.8, "cap")
		return false
	if not seal_wired:
		_balk(1.8, "seal")
		return false
	if not bottle_seated:
		_balk(2.0, "cage")
		return false
	if not cap_tested:
		_balk(2.0, "bottle")
		return false
	if not loose_cap_free:
		_balk(2.2, "loose")
		return false
	if not acid_present:
		_balk(2.0, "acid")
		return false
	tag_signed = true
	tag_line = "%02d.%02d  IN ORDER" % [int(house_minute()) / 60 % 24,
			int(house_minute()) % 60]
	_last_record = _record()
	if _click != null:
		_click.play()
	_refresh_extinguisher()
	extinguisher_inspected.emit(_last_record.duplicate(true))
	return true


func _record() -> Dictionary:
	return {
		"station_id": station_id,
		"at_minute": house_minute(),
		"gross_pounds": heft_pounds(),
		"acid_present": acid_present,
		"bottle_seated": bottle_seated,
		"loose_cap_free": loose_cap_free,
		"cap_on": cap_on,
		"seal_wired": seal_wired,
		"sealed": sealed(),
		"charged": charged(),
		"usable": usable(),
	}


# --- the shared maintenance contract -----------------------------------------

func maintenance_snapshot() -> Dictionary:
	return {
		"acid_present": acid_present,
		"bottle_seated": bottle_seated,
		"cap_on": cap_on,
		"seal_wired": seal_wired,
		"loose_cap_free": loose_cap_free,
		"cap_tested": cap_tested,
		"bottle_drawn": bottle_drawn,
		"tag_signed": tag_signed,
		"tag_line": tag_line,
	}


## Abort restores every fact this apparatus owns. It cannot retract a record
## already published, and does not pretend to.
func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	acid_present = bool(snapshot.get("acid_present", true))
	bottle_seated = bool(snapshot.get("bottle_seated", true))
	cap_on = bool(snapshot.get("cap_on", true))
	seal_wired = bool(snapshot.get("seal_wired", true))
	loose_cap_free = bool(snapshot.get("loose_cap_free", false))
	cap_tested = bool(snapshot.get("cap_tested", false))
	bottle_drawn = bool(snapshot.get("bottle_drawn", false))
	tag_signed = bool(snapshot.get("tag_signed", false))
	tag_line = str(snapshot.get("tag_line", TAG_BLANK))
	_balk_left = 0.0
	_balk_focus = ""
	_refresh_extinguisher()


# --- interaction -------------------------------------------------------------

func control_prompt(control_id: String) -> String:
	match control_id:
		"body":
			return "[E]  Take its weight  (%.0f lb)" % heft_pounds()
		"hooks":
			return "[E]  Turn it over"
		"seal":
			if seal_wired:
				return "[E]  Cut the lead-and-wire seal"
			if not cap_on:
				return "[E]  The cap is off"
			return "[E]  Wire a fresh seal through the lugs"
		"cap":
			if cap_on:
				if seal_wired:
					return "[E]  The seal wires the cap to the neck"
				return "[E]  Unscrew the cap (the cage comes up with it)"
			return "[E]  Screw the cap back down"
		"bottle":
			if cap_on:
				return "[E]  The bottle is under the cap, in its cage"
			if bottle_drawn:
				return "[E]  Put the bottle back in the clips"
			return "[E]  Draw the acid bottle out of the cage"
		"loose":
			if not bottle_drawn:
				return "[E]  The bottle is in the cage"
			if loose_cap_free:
				return "[E]  The cap lifts off the neck"
			if cap_tested:
				return "[E]  Work the cap loose"
			return "[E]  Lift at the bottle's cap"
		"tag":
			if tag_signed:
				return "[E]  The tag reads  %s" % tag_line
			return "[E]  Sign the tag"
	return ""


func interact_control(control_id: String, _player: Node) -> bool:
	match control_id:
		"body":
			heft()
			return true
		"hooks":
			return invert()
		"seal":
			return cut_seal() if seal_wired else wire_seal()
		"cap":
			return screw_cap() if not cap_on else unscrew_cap()
		"bottle":
			return seat_bottle() if bottle_drawn else draw_bottle()
		"loose":
			if bottle_drawn and cap_tested and not loose_cap_free:
				return free_loose_cap()
			return try_loose_cap()
		"tag":
			return sign_tag()
	return false


## The answer to a player looking straight at it. Without this the interaction
## inventory does not count the apparatus at all -- the lesson SR7-N paid for.
func interact_prompt() -> String:
	return control_prompt("body")


func interact(_player: Node) -> void:
	heft()


# --- pose --------------------------------------------------------------------

func _balk(seconds: float, focus := "") -> void:
	var already := _balk_left > 0.0
	_balk_focus = focus
	_balk_left = maxf(_balk_left, clampf(seconds, 0.0, 3.0))
	if not already and _knock != null:
		_knock.play()
	# Applied HERE and not left to `_process`, because a frozen sheet does not
	# tick and a refusal nobody can photograph is not a refusal.
	_refresh_extinguisher()


func _process(delta: float) -> void:
	if _balk_left <= 0.0:
		return
	_balk_left = maxf(0.0, _balk_left - delta)
	if _balk_left <= 0.0:
		_balk_focus = ""
		_refresh_extinguisher()


## Every owned fact, put back onto the metal. Rest poses are written before the
## balk block returns, so a refusal never inherits the last refusal's pose.
func _refresh_extinguisher() -> void:
	if _vessel != null:
		_vessel.rotation = Vector3.ZERO
		_vessel.position = Vector3(0.0, 0.128, 0.135)
	if _cap != null:
		if cap_on:
			_cap.position = Vector3(0.0, 0.632, 0.0)
			_cap.rotation = Vector3.ZERO
		else:
			# Set across the shoulder, cage and bottle swung clear.
			_cap.position = Vector3(0.128, 0.694, 0.015)
			_cap.rotation = Vector3(0.0, 0.0, -0.42)
	if _cage != null:
		_cage.visible = true
	if _bottle != null:
		_bottle.visible = true
		if bottle_drawn:
			_bottle.position = Vector3(-0.192, 0.126, 0.150)
			_bottle.rotation = Vector3.ZERO
		elif cap_on:
			_bottle.position = Vector3(0.0, 0.664, 0.135)
			_bottle.rotation = Vector3.ZERO
		else:
			# Still in the cage, and the cage is on the cap.
			_bottle.position = Vector3(0.167, 0.730, 0.150)
			_bottle.rotation = Vector3(0.0, 0.0, -0.42)
	if _acid_band != null:
		_acid_band.visible = acid_present
	if _loose_cap != null:
		# A cap worked free rides a little proud of the neck, which is how you
		# can see at a glance that somebody has been at it.
		_loose_cap.position = Vector3(0.0, 0.0655
				+ (0.026 if loose_cap_free and bottle_drawn else 0.0), 0.0)
		_loose_cap.rotation = Vector3.ZERO
	if _seal != null:
		_seal.visible = seal_wired
		_seal.position = Vector3(0.0, 0.632, 0.0)
	if _tag != null:
		_tag.rotation = Vector3.ZERO
	if _tag_label != null:
		_tag_label.text = tag_line.replace("  ", "\n")
	if _balk_left <= 0.0:
		return
	# --- refusals, each one a different photograph ---------------------------
	match _balk_focus:
		"seal":
			# The wire takes the pull and holds. The cap lifts the width of the
			# seal and stops.
			if _cap != null:
				_cap.position.y += 0.016
			if _seal != null:
				_seal.visible = seal_wired
				_seal.position = Vector3(0.0, 0.642, 0.010)
		"cap":
			if _cap != null:
				_cap.rotation.y += 0.55
				_cap.position.z += 0.016
		"bottle":
			if _bottle != null:
				_bottle.position.z += 0.042
				_bottle.rotation.x += 0.26
		"cage":
			# The empty clips rattled: the cage is on the cap, so this is the
			# cap jogged with nothing riding in it.
			if _cap != null:
				_cap.rotation.z += 0.20
				_cap.position.y += 0.020
		"loose":
			# THE DIAGNOSIS. You lift at the cap and the bottle comes with it.
			if _bottle != null:
				_bottle.position.y += 0.078
				_bottle.rotation.z += 0.24
		"acid":
			if _acid_band != null:
				_acid_band.visible = true
		"invert":
			# It tips on its hooks and it does not come off them. The pivot is
			# the vessel's foot, so cap and seal go with it -- and so does the
			# bottle, which is why its tipped place is written out below rather
			# than left standing upright inside a cage that moved.
			if _vessel != null:
				_vessel.rotation.z = 0.20
			if _bottle != null and cap_on and not bottle_drawn:
				_bottle.position = Vector3(-0.1065, 0.6533, 0.135)
				_bottle.rotation = Vector3(0.0, 0.0, 0.20)
		"tag":
			if _tag != null:
				_tag.rotation = Vector3(-0.58, 0.0, 0.26)


# --- build -------------------------------------------------------------------

func _build_visual() -> void:
	_build_bracket()
	_build_vessel()
	_build_hose()
	_build_cap_and_cage()
	_build_bottle()
	_build_tag()
	_build_reaches()
	_knock = make_emitter("knock", -14.0)
	_click = make_emitter("pop", -19.0)
	_refresh_extinguisher()


## The straps and the shelf. The BOARD is not drawn here: the building already
## batches it at (-2.76, -3.10) and this hangs in front of it.
func _build_bracket() -> void:
	var iron := Color(0.255, 0.245, 0.230)
	var brass := Color(0.72, 0.56, 0.24)
	_hooks = Node3D.new()
	_hooks.name = "Bracket"
	add_child(_hooks)
	for strap_y in [0.215, 0.520]:
		var ring := make_ring(0.122, 0.011, Vector3(0.0, strap_y, 0.135), iron,
				0.55, 0.35, _hooks)
		ring.rotation.x = PI * 0.5
		_move(make_box(Vector3(0.052, 0.016, 0.030), Vector3.ZERO, iron),
				_hooks, Vector3(0.0, strap_y, 0.016))
	# The shelf the drawn bottle stands on, and the vessel's foot rests in. It
	# runs EAST, toward the stair doorway: the west wall of the core is only
	# 0.38 from the board, so a reader standing to the west would be standing
	# in it, and the sheet's own camera would be inside plaster.
	_move(make_box(Vector3(0.330, 0.018, 0.150), Vector3.ZERO, iron), _hooks,
			Vector3(-0.030, 0.070, 0.088))
	_move(make_box(Vector3(0.026, 0.070, 0.026), Vector3.ZERO, iron), _hooks,
			Vector3(-0.030, 0.036, 0.030))
	# The enamel charge plate, on the board above the shelf.
	make_box(Vector3(0.150, 0.062, 0.010), Vector3(-0.196, 0.588, 0.010),
			Color(0.115, 0.110, 0.105))
	_letter("ChargeLegend", CHARGE_LEGEND, Vector3(-0.196, 0.601, 0.017),
			0.0148, Color(0.90, 0.88, 0.83))
	_letter("ChargeLegend2", CHARGE_LEGEND_2, Vector3(-0.196, 0.577, 0.017),
			0.0148, Color(0.84, 0.82, 0.77))
	for pin_x in [-0.258, -0.134]:
		make_cyl(0.0045, 0.0045, 0.014, Vector3(pin_x, 0.588, 0.018), brass,
				0.32, 0.80).rotation.x = PI * 0.5


## Everything that hangs in the straps rides on ONE pivot at the vessel's foot,
## so that the refusal for turning it over can tip the vessel, its cap and its
## seal as the single object they are.
func _build_vessel() -> void:
	var copper := Color(0.660, 0.375, 0.195)
	var brass := Color(0.72, 0.56, 0.24)
	_vessel = Node3D.new()
	_vessel.name = "VesselPivot"
	_vessel.position = Vector3(0.0, 0.128, 0.135)
	add_child(_vessel)
	_body = make_cyl(0.113, 0.113, 0.520, Vector3(0.0, 0.244, 0.0), copper,
			0.30, 0.82, _vessel)
	_body.name = "Vessel"
	make_cyl(0.117, 0.117, 0.032, Vector3(0.0, -0.244, 0.0), brass, 0.34,
			0.78, _body)
	make_cyl(0.056, 0.113, 0.080, Vector3(0.0, 0.300, 0.0), copper, 0.30, 0.82,
			_body)
	make_cyl(0.050, 0.050, 0.046, Vector3(0.0, 0.381, 0.0), brass, 0.32, 0.80,
			_body)
	# Two lugs on the neck: the wire seal passes through these and the cap's.
	for side in [-1.0, 1.0]:
		_move(make_box(Vector3(0.014, 0.020, 0.032), Vector3.ZERO, brass),
				_body, Vector3(0.056 * side, 0.376, 0.0))
	# The lead-and-wire seal itself.
	_seal = Node3D.new()
	_seal.name = "LeadAndWireSeal"
	_seal.position = Vector3(0.0, 0.632, 0.0)
	_vessel.add_child(_seal)
	for side in [-1.0, 1.0]:
		var wire := make_cyl(0.0016, 0.0016, 0.046,
				Vector3(0.052 * side, -0.010, 0.0),
				Color(0.56, 0.55, 0.52), 0.5, 0.55, _seal)
		wire.rotation.z = 0.16 * side
	var span := make_cyl(0.0016, 0.0016, 0.104, Vector3(0.0, -0.028, 0.010),
			Color(0.56, 0.55, 0.52), 0.5, 0.55, _seal)
	span.rotation.z = PI * 0.5
	make_cyl(0.0072, 0.0072, 0.009, Vector3(0.0, -0.028, 0.022),
			Color(0.50, 0.50, 0.53), 0.62, 0.55, _seal)


## Rubber hose and brass play-pipe, clipped to the bracket. Geometry, not a
## term: this apparatus has one fault and it is not here.
func _build_hose() -> void:
	var rubber := Color(0.125, 0.118, 0.115)
	var brass := Color(0.72, 0.56, 0.24)
	var run := make_cyl(0.0145, 0.0145, 0.215, Vector3(0.082, 0.572, 0.185),
			rubber, 0.88, 0.0)
	run.rotation.z = -0.66
	var down := make_cyl(0.0145, 0.0145, 0.250, Vector3(0.158, 0.408, 0.176),
			rubber, 0.88, 0.0)
	down.rotation.z = -0.14
	var tip := make_cyl(0.008, 0.016, 0.092, Vector3(0.180, 0.252, 0.172),
			brass, 0.32, 0.80)
	tip.rotation.z = -0.18
	make_box(Vector3(0.020, 0.028, 0.044), Vector3(0.172, 0.300, 0.118), brass)


## Per Miller: the cage rides with the cap, so unscrewing the cap lifts the
## bottle into daylight. That is the only reason any of this is inspectable.
func _build_cap_and_cage() -> void:
	var brass := Color(0.72, 0.56, 0.24)
	_cap = Node3D.new()
	_cap.name = "Cap"
	_vessel.add_child(_cap)
	make_cyl(0.060, 0.060, 0.050, Vector3(0.0, 0.026, 0.0), brass, 0.30, 0.82,
			_cap)
	make_cyl(0.064, 0.064, 0.011, Vector3(0.0, 0.048, 0.0), brass, 0.28, 0.84,
			_cap)
	for knurl_index in 8:
		var rib := make_box(Vector3(0.008, 0.048, 0.126), Vector3.ZERO, brass)
		_move(rib, _cap, Vector3(0.0, 0.026, 0.0))
		rib.rotation.y = float(knurl_index) * PI / 8.0
	for side in [-1.0, 1.0]:
		_move(make_box(Vector3(0.014, 0.018, 0.030), Vector3.ZERO, brass), _cap,
				Vector3(0.056 * side, 0.006, 0.0))
	_cage = Node3D.new()
	_cage.name = "AcidBottleCage"
	_cap.add_child(_cage)
	# Miller's resilient-wire clips, bent inward near the top to take the
	# bottle's shoulder.
	for clip_index in 4:
		var angle := float(clip_index) * PI * 0.5 + PI * 0.25
		var upright := make_cyl(0.0018, 0.0018, 0.132, Vector3.ZERO,
				Color(0.62, 0.60, 0.56), 0.5, 0.60, _cage)
		upright.position = Vector3(sin(angle) * 0.031, -0.068,
				cos(angle) * 0.031)
	make_ring(0.031, 0.0022, Vector3(0.0, -0.130, 0.0),
			Color(0.62, 0.60, 0.56), 0.5, 0.60, _cage)
	make_ring(0.031, 0.0022, Vector3(0.0, -0.014, 0.0),
			Color(0.62, 0.60, 0.56), 0.5, 0.60, _cage)


## The eight-ounce bottle, half filled. Its own node on the prop rather than on
## the cage, because the whole diagnosis is a frame in which it goes where the
## cage did not put it.
func _build_bottle() -> void:
	var glass := Color(0.725, 0.555, 0.290)
	var acid := Color(0.185, 0.128, 0.048)
	var lead := Color(0.665, 0.655, 0.665)
	_bottle = Node3D.new()
	_bottle.name = "AcidBottle"
	add_child(_bottle)
	make_cyl(0.0245, 0.0275, 0.112, Vector3(0.0, 0.0, 0.0), glass, 0.20, 0.0,
			_bottle)
	make_cyl(0.0155, 0.0245, 0.020, Vector3(0.0, 0.066, 0.0), glass, 0.20, 0.0,
			_bottle)
	# The level, read through the glass: half an eight-ounce bottle.
	_acid_band = make_cyl(0.0281, 0.0281, 0.054, Vector3(0.0, -0.028, 0.0),
			acid, 0.16, 0.0, _bottle)
	_acid_band.name = "AcidLevel"
	_loose_cap = make_cyl(0.0215, 0.0215, 0.021, Vector3(0.0, 0.0655, 0.0),
			lead, 0.44, 0.60, _bottle)
	_loose_cap.name = "LooseCap"


func _build_tag() -> void:
	_tag = Node3D.new()
	_tag.name = "InspectionTag"
	_tag.position = Vector3(-0.182, 0.470, 0.108)
	add_child(_tag)
	var wire := make_cyl(0.0014, 0.0014, 0.132, Vector3(0.036, 0.082, -0.016),
			Color(0.52, 0.50, 0.46), 0.6, 0.55, _tag)
	wire.rotation.z = 0.44
	_move(make_box(Vector3(0.094, 0.055, 0.002), Vector3.ZERO,
			Color(0.875, 0.850, 0.770)), _tag, Vector3.ZERO)
	_tag_label = _letter("TagLine", TAG_BLANK, Vector3(0.0, 0.002, 0.003),
			0.0102, Color(0.13, 0.12, 0.11), _tag)


## `make_box` hangs its mesh on the prop; this moves one onto a sub-pivot
## without going through `reparent`.
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


## Seven places to put a hand, one per thing that is actually there. The only
## order between them is the order the metal imposes: a wired seal stops the
## cap, a shut cap stops the bottle, and a bottle in the cage stops the fingers
## reaching its own little cap. No authored sequence gates any of them.
func _build_reaches() -> void:
	var reaches := {
		"body": [Vector3(0.0, 0.372, 0.140), Vector3(0.24, 0.30, 0.24)],
		"hooks": [Vector3(0.0, 0.180, 0.150), Vector3(0.28, 0.10, 0.26)],
		"cap": [Vector3(0.0, 0.790, 0.140), Vector3(0.16, 0.10, 0.18)],
		"seal": [Vector3(0.0, 0.712, 0.140), Vector3(0.17, 0.06, 0.18)],
		"bottle": [Vector3(-0.192, 0.148, 0.150), Vector3(0.11, 0.15, 0.14)],
		"loose": [Vector3(-0.192, 0.262, 0.150), Vector3(0.11, 0.06, 0.14)],
		"tag": [Vector3(-0.182, 0.470, 0.110), Vector3(0.11, 0.08, 0.10)],
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
		"title": "SODA ACID EXTINGUISHER",
		"body": "AN UNBROKEN SEAL RECORDS THAT NOBODY OPENED IT STOP "
				+ "IT DOES NOT RECORD THAT IT WORKS STOP",
		"condition": "SEALED %s / CHARGED %s / USABLE %s" % [
				"YES" if sealed() else "NO", "YES" if charged() else "NO",
				"YES" if usable() else "NO"],
		"stamp": "EXTINGUISHER",
	}
