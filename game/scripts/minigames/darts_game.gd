class_name DartsGame
extends RefCounted
## 301, three darts a turn, straight in and straight out.
##
## The scoring is a real board, not a made-up one, because everybody who
## has thrown a dart knows where 20 is and would notice. Twenty radial
## beds in the standard order, a treble ring at 99..107 mm from the
## bull, a double ring at 162..170, an outer bull at 15.9 and an inner
## at 6.35. Outside 170 is the surround and scores nothing.
##
## SEPARATE FROM THE AIMING ON PURPOSE. Everything here takes a point on
## the board in millimetres and returns a score, so the whole ruleset
## can be tested without a camera, a hand or a frame — and when the
## throwing feel gets tuned later, none of it is at risk.

## Clockwise from the top. This order is the one thing about a dartboard
## that cannot be derived: it exists to punish a near miss, so 20 sits
## between 1 and 5, and getting it wrong makes the board feel arbitrary
## in a way players notice immediately.
const BEDS := [20, 1, 18, 4, 13, 6, 10, 15, 2, 17,
	3, 19, 7, 16, 8, 11, 14, 9, 12, 5]

const R_INNER_BULL := 6.35
const R_OUTER_BULL := 15.9
const R_TREBLE_IN := 99.0
const R_TREBLE_OUT := 107.0
const R_DOUBLE_IN := 162.0
const R_DOUBLE_OUT := 170.0

const START := 301
const DARTS_PER_TURN := 3

enum State { THROWING, TURN_OVER, WON }

var score := START
var darts_left := DARTS_PER_TURN
var state: int = State.THROWING
var turn_hits: Array = []          # this turn's [{value, label}]
var history: Array = []            # every dart, for the scoreboard
var turns := 0
var _turn_start := START


## Where a dart landed, in millimetres from the bull. Returns
## {value, mult, bed, label}.
static func score_at(dx: float, dy: float) -> Dictionary:
	var r := sqrt(dx * dx + dy * dy)
	if r <= R_INNER_BULL:
		return {"value": 50, "mult": 2, "bed": 25, "label": "BULL"}
	if r <= R_OUTER_BULL:
		return {"value": 25, "mult": 1, "bed": 25, "label": "25"}
	if r > R_DOUBLE_OUT:
		return {"value": 0, "mult": 0, "bed": 0, "label": "OFF"}
	# Which bed. Zero degrees is the top of the board and beds run
	# clockwise, each 18 degrees wide, with 20 straddling the top — so
	# the sector boundary is offset by half a bed.
	var ang := rad_to_deg(atan2(dx, dy))
	if ang < 0.0:
		ang += 360.0
	var idx := int(floor(fposmod(ang + 9.0, 360.0) / 18.0)) % BEDS.size()
	var bed: int = BEDS[idx]
	if r >= R_TREBLE_IN and r <= R_TREBLE_OUT:
		return {"value": bed * 3, "mult": 3, "bed": bed,
			"label": "T%d" % bed}
	if r >= R_DOUBLE_IN:
		return {"value": bed * 2, "mult": 2, "bed": bed,
			"label": "D%d" % bed}
	return {"value": bed, "mult": 1, "bed": bed, "label": str(bed)}


func reset() -> void:
	score = START
	darts_left = DARTS_PER_TURN
	state = State.THROWING
	turn_hits = []
	history = []
	turns = 0
	_turn_start = START


## Land a dart. `dx`/`dy` are millimetres from the bull.
func throw_at(dx: float, dy: float) -> Dictionary:
	if state == State.WON:
		return {}
	if state == State.TURN_OVER:
		next_turn()
	var hit := score_at(dx, dy)
	darts_left -= 1
	turn_hits.append(hit)
	history.append(hit)
	var after: int = score - int(hit.value)
	# BUST. Overshooting does not go negative and does not end on one —
	# the whole turn is thrown away and the score goes back to what it
	# was when you stepped up. It is the rule that makes the last
	# hundred points the hard part.
	if after < 0 or after == 1:
		hit["bust"] = true
		score = _turn_start
		darts_left = 0
		state = State.TURN_OVER
		return hit
	score = after
	if score == 0:
		state = State.WON
		return hit
	if darts_left <= 0:
		state = State.TURN_OVER
	return hit


func next_turn() -> void:
	if state == State.WON:
		return
	turns += 1
	darts_left = DARTS_PER_TURN
	turn_hits = []
	_turn_start = score
	state = State.THROWING


## What the player needs, phrased the way a scorer would say it.
func call_out() -> String:
	if state == State.WON:
		return "game shot."
	if score > 180:
		return "%d" % score
	# The obvious finish, if there is one in a single dart.
	if score <= 50 and score % 2 == 0:
		return "%d  —  D%d for it" % [score, score / 2]
	if score <= 60:
		return "%d  —  needs %d" % [score, score]
	return "%d" % score


func turn_total() -> int:
	var t := 0
	for h in turn_hits:
		t += int(h.value)
	return t
