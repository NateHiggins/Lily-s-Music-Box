class_name HarukiyaStateDirector
extends Node
## The bar learns its hours: OPEN, AFTER-HOURS, CLOSED (brief #52 P5).
##
## Three looks for the Harukiya, keyed to the same minute-of-day the sky
## and the resident schedules already read (ScheduleDirector.minute_now,
## so DAYNIGHT_FORCE pins it for renders). The fixtures are every SITE
## light gen_layout authors under the F01_BAR_LT_ prefix — sixteen of
## them as of the relighting — plus the facade signage and the stage
## sign, which are still found by id because there is exactly one of
## each and they are not lights.
##
## OPEN        19:00-02:00  everything lit, neon full — the roster hours
##                          (Fri/Sat crowd 21:30-02:00, Lena's early
##                          Saturday drink 19:30).
## AFTER-HOURS 02:00-04:30  neon dead, one canopy light left for the
##                          cleanup, the stair bulb dimmed to a glow.
## CLOSED      04:30-19:00  neon dead glass, the room dark, the stair
##                          bulb at a caretaker's minimum — the descent
##                          is never absolute black.
##
## Inert under DAYNIGHT=0: the canonical 03:00 test building keeps its
## pre-state look byte for byte, same convention as the other directors.

## THE ROOM IS DISCOVERED, NOT LISTED. Every fixture whose name starts
## with PREFIX is picked up off the tree; this table only says what the
## ones with opinions do, and anything not named here takes DEFAULT.
##
## It used to be a closed list, and the list went stale the moment the
## room was rebuilt: it named TAB4 and TAB6, which stopped existing when
## the table count went from eight to three, and it did not name DECK1 or
## either WEST sconce, which were added when the west half of the bar
## turned out to have no lighting in it at all. So it warned about two
## fixtures that were gone and silently left three new ones burning at
## full through a closed bar. A prefix scan cannot drift: a fixture that
## is in the room is in the system, by construction.
##
## fixture id -> [OPEN gain, AFTER_HOURS gain, CLOSED gain]; 0 = off.
const PREFIX := "F01_BAR_LT_"
## Lit for business and dark otherwise, which is nearly everything.
const DEFAULT := [1.0, 0.0, 0.0]
const FIXTURE_STATES := {
	# The stair is never fully dark: it is the way out of a basement, and
	# a caretaker's minimum on it is the difference between a closed bar
	# and a hole in the pavement.
	"F01_BAR_LT_STAIR": [1.0, 0.6, 0.35],
	# What somebody actually cleans up under after two: one end of the
	# counter, one table, and enough of the lounge to find the glasses.
	"F01_BAR_LT_CAN0": [1.0, 0.45, 0.0],
	"F01_BAR_LT_TAB0": [1.0, 0.5, 0.0],
	"F01_BAR_LT_DECK0": [1.0, 0.35, 0.0],
	# The restroom stays on through the clean-up for the obvious reason.
	"F01_BAR_LT_WC": [1.0, 0.40, 0.0],
}
const SIGNAGE := "F01_BAR_SIGNAGE"
## The lit word over the stage, which keeps the facade's hours.
const STAGE_SIGN := "F01_BAR_STAGE_SIGN"
enum BarState { OPEN, AFTER_HOURS, CLOSED }

var _root: Node3D
var _accum := 9.0               # apply on the first tick
var _state := -1
var enabled := true


func setup(root: Node3D) -> void:
	_root = root
	enabled = OS.get_environment("DAYNIGHT") != "0" \
			or OS.get_environment("SCHEDULE") == "1"
	# The bar spans street to basement in one venue, but its fixtures are
	# named F01_ while a body standing in the room reads as B1 to the
	# LightRig's storey gate - so the room's own lights switched OFF the
	# moment anyone was in it. Tag them as a vertical zone (the same
	# exemption the stair and atrium fixtures ride) and the gate defers
	# to plain distance ranking, which does the right thing here.
	for fixture in _fixtures():
		fixture.set_meta("vertical_zone", true)


## Every light in the bar, by name. Cheap enough to re-walk on the rare
## state change, and it is the only thing keeping this director and
## gen_layout in agreement — so it is deliberately not cached against
## some future pass that adds a fixture after _ready.
func _fixtures() -> Array:
	var found: Array = []
	if _root == null:
		return found
	for child in _root.get_children():
		if child is LightFixtureProp and str(child.name).begins_with(PREFIX):
			found.append(child)
	return found


static func state_for(minute: float) -> BarState:
	if minute >= 1140.0 or minute < 120.0:
		return BarState.OPEN
	if minute < 270.0:
		return BarState.AFTER_HOURS
	return BarState.CLOSED


func _process(delta: float) -> void:
	if not enabled or _root == null:
		return
	_accum += delta
	if _accum < 7.0:
		return
	_accum = 0.0
	var next := state_for(ScheduleDirector.minute_now())
	if int(next) == _state:
		return
	_state = int(next)
	_apply(next)


func _apply(bar_state: BarState) -> void:
	var missing := 0
	var fixtures := _fixtures()
	# A bar with no lights in it is the failure this is really watching
	# for — a renamed prefix, a regeneration that dropped the block, a
	# scene where the room was never built. One fixture missing is not
	# findable any more (there is no list to be missing from); zero of
	# them is, and it is the case that actually matters.
	if fixtures.is_empty():
		push_warning("harukiya states: no '%s' fixtures in the tree" % PREFIX)
	for fixture in fixtures:
		var gain: float = FIXTURE_STATES.get(
				str(fixture.name), DEFAULT)[int(bar_state)]
		fixture.set_state_gain(gain)
		fixture.set_powered(gain > 0.0)
	var sign := _root.get_node_or_null(NodePath(SIGNAGE)) \
			as HarukiyaSignageProp
	if sign == null:
		missing += 1
	else:
		sign.set_bar_state(int(bar_state))
	var stage_sign := _root.get_node_or_null(NodePath(STAGE_SIGN)) \
			as NeonSignProp
	if stage_sign == null:
		missing += 1
	else:
		stage_sign.set_lit(bar_state == BarState.OPEN)
	if missing > 0:
		push_warning("harukiya states: %d signs not found" % missing)
	print("[HARUKIYA] %s, %d fixtures" % [
			BarState.keys()[int(bar_state)], fixtures.size()])
