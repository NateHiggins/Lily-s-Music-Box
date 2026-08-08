class_name HarukiyaStateDirector
extends Node
## The bar learns its hours: OPEN, AFTER-HOURS, CLOSED (brief #52 P5).
##
## Three looks for the Harukiya, keyed to the same minute-of-day the sky
## and the resident schedules already read (ScheduleDirector.minute_now,
## so DAYNIGHT_FORCE pins it for renders). The fixtures are the six SITE
## lights gen_layout authors for the bar plus the two facade neons; all
## are found by their marker ids, so a regenerated building keeps working
## or fails loudly here.
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

## fixture id -> [OPEN gain, AFTER_HOURS gain, CLOSED gain]; 0 = off.
const FIXTURE_STATES := {
	"F01_BAR_LT_LOBBY": [1.0, 0.0, 0.0],
	"F01_BAR_LT_STAIR": [1.0, 0.6, 0.35],
	"F01_BAR_LT_CAN0": [1.0, 0.45, 0.0],
	"F01_BAR_LT_CAN1": [1.0, 0.0, 0.0],
	"F01_BAR_LT_POOL": [1.0, 0.0, 0.0],
	"F01_BAR_LT_WC": [1.0, 0.0, 0.0],
	# The Belchi Lorente rebuild's own fixtures. The table pendants are
	# what the room is actually lit by, so one of them survives into
	# after-hours as the light somebody wipes down under.
	"F01_BAR_LT_TAB0": [1.0, 0.5, 0.0],
	"F01_BAR_LT_TAB2": [1.0, 0.0, 0.0],
	"F01_BAR_LT_TAB4": [1.0, 0.0, 0.0],
	"F01_BAR_LT_TAB6": [1.0, 0.0, 0.0],
	"F01_BAR_LT_STAGE0": [1.0, 0.0, 0.0],
	"F01_BAR_LT_STAGE1": [1.0, 0.0, 0.0],
	"F01_BAR_LT_DECK": [1.0, 0.35, 0.0],
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
	for id in FIXTURE_STATES:
		var fixture := root.get_node_or_null(NodePath(id))
		if fixture:
			fixture.set_meta("vertical_zone", true)


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
	for id in FIXTURE_STATES:
		var fixture := _root.get_node_or_null(NodePath(id)) \
				as LightFixtureProp
		if fixture == null:
			missing += 1
			continue
		var gain: float = FIXTURE_STATES[id][int(bar_state)]
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
		push_warning("harukiya states: %d bar fixtures not found" % missing)
	print("[HARUKIYA] %s" % BarState.keys()[int(bar_state)])
