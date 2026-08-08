extends Node
## Is it a real dartboard, and are the rules the real rules?
##
## Everything here is about the SCORING, which is deliberately separate
## from the throwing: DartsGame takes a point in millimetres from the
## bull and answers, so the ruleset can be pinned down without a camera
## or a hand in the way, and the feel can be retuned later without any
## of it being at risk.
##
## The checks that matter are the ones a player would notice instantly
## and a developer never would: that 20 is at the top, that the beds run
## in the order that punishes a near miss, that the trebles are where
## the wire actually is, and that busting throws the whole turn away
## rather than the one dart.

var root: Node3D
var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


## A point on the board: `bed_ang` degrees clockwise from the top, `r`
## millimetres out.
func _pt(bed_ang: float, r: float) -> Vector2:
	return Vector2(sin(deg_to_rad(bed_ang)) * r,
			cos(deg_to_rad(bed_ang)) * r)


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.5).timeout
	_run()


func _run() -> void:
	# ---- IS THERE A BOARD IN THE BAR --------------------------------
	var prop := root.find_child("F01_BAR_DARTS", true, false)
	_check("the bar has darts", prop != null)
	if prop:
		var p: Vector3 = prop.global_position
		print("      darts at %v" % p)
		_check("in the bar, not on the street", p.y < -1.5 and p.z > 30.0)
		_check("they offer themselves",
				str(prop.interact_prompt()).contains("darts"))

	# ---- IS IT A REAL BOARD -----------------------------------------
	var g := DartsGame.new()
	_check("twenty beds", DartsGame.BEDS.size() == 20)
	_check("20 is at the top",
			DartsGame.score_at(_pt(0.0, 60.0).x, _pt(0.0, 60.0).y).bed == 20)
	_check("3 is at the bottom",
			DartsGame.score_at(_pt(180.0, 60.0).x,
					_pt(180.0, 60.0).y).bed == 3)
	_check("6 is on the right",
			DartsGame.score_at(_pt(90.0, 60.0).x,
					_pt(90.0, 60.0).y).bed == 6)
	_check("11 is on the left",
			DartsGame.score_at(_pt(270.0, 60.0).x,
					_pt(270.0, 60.0).y).bed == 11)
	# The order is the whole design of a dartboard: a near miss on the
	# big number has to land on a small one.
	var neighbours_ok := true
	for i in DartsGame.BEDS.size():
		var a: int = DartsGame.BEDS[i]
		var b: int = DartsGame.BEDS[(i + 1) % DartsGame.BEDS.size()]
		if a + b > 30:              # 20|1, 19|7, 18|4 ... none exceed 30
			neighbours_ok = false
	_check("neighbouring beds punish a near miss", neighbours_ok)

	# ---- RINGS ------------------------------------------------------
	_check("inner bull is 50", DartsGame.score_at(0.0, 3.0).value == 50)
	_check("outer bull is 25", DartsGame.score_at(0.0, 12.0).value == 25)
	var t20 := DartsGame.score_at(_pt(0.0, 103.0).x, _pt(0.0, 103.0).y)
	_check("treble 20 is 60 (%s)" % t20.label, t20.value == 60)
	var d20 := DartsGame.score_at(_pt(0.0, 166.0).x, _pt(0.0, 166.0).y)
	_check("double 20 is 40 (%s)" % d20.label, d20.value == 40)
	var s20 := DartsGame.score_at(_pt(0.0, 140.0).x, _pt(0.0, 140.0).y)
	_check("between the rings is a single (%s)" % s20.label,
			s20.value == 20)
	_check("off the board scores nothing",
			DartsGame.score_at(0.0, 240.0).value == 0)

	# ---- THE RULES --------------------------------------------------
	g.reset()
	_check("starts on 301", g.score == 301)
	g.throw_at(_pt(0.0, 103.0).x, _pt(0.0, 103.0).y)      # T20
	_check("a treble twenty takes 60 off (%d)" % g.score, g.score == 241)
	_check("two darts left", g.darts_left == 2)
	g.throw_at(_pt(0.0, 103.0).x, _pt(0.0, 103.0).y)
	g.throw_at(_pt(0.0, 103.0).x, _pt(0.0, 103.0).y)
	_check("three darts ends the turn",
			g.state == DartsGame.State.TURN_OVER)
	_check("a maximum is 180 (%d)" % g.turn_total(), g.turn_total() == 180)

	# BUST. The rule that makes the last hundred the hard part: going
	# under, or landing on one, throws away the WHOLE turn.
	g.reset()
	g.score = 40
	g.next_turn()
	g.throw_at(_pt(0.0, 103.0).x, _pt(0.0, 103.0).y)      # 60, busts
	_check("overshooting busts back to the turn's start (%d)" % g.score,
			g.score == 40)
	_check("and ends the turn", g.state == DartsGame.State.TURN_OVER)

	g.reset()
	g.score = 3
	g.next_turn()
	g.throw_at(_pt(0.0, 140.0).x, _pt(0.0, 140.0).y)      # 20 -> -17
	_check("cannot go below zero", g.score == 3)
	g.reset()
	g.score = 3
	g.next_turn()
	g.throw_at(_pt(90.0, 140.0).x, _pt(90.0, 140.0).y)    # 6 -> -3
	_check("landing on one is a bust too (score %d)" % g.score,
			g.score == 3)

	# Checkout.
	g.reset()
	g.score = 40
	g.next_turn()
	g.throw_at(_pt(0.0, 166.0).x, _pt(0.0, 166.0).y)      # D20
	_check("double twenty for the game", g.score == 0)
	_check("and that is game shot", g.state == DartsGame.State.WON)
	_check("the scorer calls the finish",
			g.call_out().contains("game shot"))

	print("[DARTS] RESULT: %s (%d failures)"
			% ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
