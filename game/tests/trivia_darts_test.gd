extends Node
## The Rainbow Round: does the board read colours, and does the deck
## hold together?
##
## Two different kinds of check here and they matter for different
## reasons. The BOARD ones are geometry — seven slices have to cover the
## circle exactly once with no seam and no overlap, which is the sort of
## thing that is off by half a slice for a week before anyone notices.
##
## The DECK ones are content, and they are the ones that will actually
## fire during play: every card has to name a colour the board can
## actually show, and a kind the scoring table knows how to price. A
## card answering "white" would be silently unhittable, and a card with
## a typo'd kind would silently score zero bonus forever.

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	_run()


func _run() -> void:
	var g := TriviaDarts.new()
	_check("the deck loads", g.load_deck())
	if g.colours.is_empty():
		print("[TRIVIA] RESULT: FAIL (1 failures)")
		get_tree().quit(1)
		return
	_check("seven colours of the rainbow (%d)" % g.colours.size(),
			g.colours.size() == 7)
	print("      %d cards" % g.deck.size())

	# ---- THE BOARD ---------------------------------------------------
	# Sweep the whole circle at playing radius: every degree must land
	# in some colour, and the slices must come round exactly once.
	var seen := {}
	var gaps := 0
	for deg in 720:
		var a := deg * 0.5
		var p := Vector2(sin(deg_to_rad(a)), cos(deg_to_rad(a))) * 130.0
		var s := g.slice_at(p.x, p.y)
		if not s["on"] or str(s["colour"]) == "":
			gaps += 1
		else:
			seen[str(s["colour"])] = int(seen.get(str(s["colour"]), 0)) + 1
	_check("no gaps between slices", gaps == 0)
	_check("all seven appear (%d)" % seen.size(), seen.size() == 7)
	# Each slice should own the same share of the circle, within a
	# sample's worth of rounding.
	var even := true
	for c in seen:
		if absf(float(seen[c]) - 720.0 / 7.0) > 6.0:
			even = false
	_check("the slices are equal", even)

	# The first colour straddles the top, the way 20 does on a real
	# board — so a dart at twelve o'clock is unambiguous.
	var top := g.slice_at(0.0, 130.0)
	_check("the first colour is at the top (%s)" % str(top["colour"]),
			str(top["colour"]) == str(g.colours[0]))

	# Rings.
	var tre := g.slice_at(0.0, 103.0)
	var dbl := g.slice_at(0.0, 166.0)
	_check("there is a treble ring (%s x%d)"
			% [str(tre["ring"]), int(tre["mult"])],
			str(tre["ring"]) == "treble" and int(tre["mult"]) == 3)
	_check("and a double ring (%s x%d)"
			% [str(dbl["ring"]), int(dbl["mult"])],
			str(dbl["ring"]) == "double" and int(dbl["mult"]) == 2)
	_check("the bull is wild",
			str(g.slice_at(0.0, 4.0)["colour"]) == "*")
	_check("off the board is off the board",
			not g.slice_at(0.0, 300.0)["on"])

	# ---- THE DECK ----------------------------------------------------
	# Every card must be playable: a colour the board can show, and a
	# kind the scoring table prices. Both fail SILENTLY otherwise.
	var bad_colour := []
	var bad_kind := []
	for c in g.deck:
		if not g.colours.has(str(c.get("a", ""))):
			bad_colour.append(str(c.get("q", "?")).substr(0, 34))
		if not g.kinds.has(str(c.get("kind", ""))):
			bad_kind.append(str(c.get("q", "?")).substr(0, 34))
	_check("every answer is a colour on the board", bad_colour.is_empty())
	if not bad_colour.is_empty():
		print("      unhittable: %s" % [bad_colour])
	_check("every card has a kind the scoring knows", bad_kind.is_empty())
	if not bad_kind.is_empty():
		print("      unpriced: %s" % [bad_kind])
	var no_why := 0
	for c in g.deck:
		if str(c.get("why", "")).strip_edges() == "":
			no_why += 1
	_check("every card explains itself afterwards", no_why == 0)
	var kinds_used := {}
	for c in g.deck:
		kinds_used[str(c.get("kind", ""))] = true
	_check("the deck uses more than one kind (%d)" % kinds_used.size(),
			kinds_used.size() >= 3)

	# ---- SCORING -----------------------------------------------------
	g.start([{"name": "you"}, {"name": "Cam", "npc": true}], 4471)
	_check("a card is on the table", not g.card.is_empty())
	# Force a known card so the arithmetic is checkable.
	g.card = {"q": "test", "a": "green", "kind": "pun", "why": "-"}
	var green_at: Vector2 = g.aim_point("green", 130.0)
	var r1 := g.throw_for(0, green_at.x, green_at.y)
	_check("hitting the right colour scores (%d)" % int(r1["points"]),
			bool(r1["right"]) and int(r1["points"]) > 0)
	_check("a pun pays the bonus on top",
			int(r1["points"]) == int(g.scoring.get("hit", 2))
			+ g.bonus_for("pun"))
	var red_at: Vector2 = g.aim_point("red", 130.0)
	var r2 := g.throw_for(1, red_at.x, red_at.y)
	_check("the wrong colour scores nothing",
			not bool(r2["right"]) and int(r2["points"]) == 0)
	# A treble on the right colour should beat a single on it.
	g.thrown = {}
	var g2 := TriviaDarts.new()
	g2.load_deck()
	g2.start([{"name": "solo"}], 1610)
	g2.card = {"q": "t", "a": "red", "kind": "plain", "why": "-"}
	var single := g2.throw_for(0, 0.0, 130.0)
	g2.thrown = {}
	var treble := g2.throw_for(0, 0.0, 103.0)
	_check("a treble on the colour beats a single (%d vs %d)"
			% [int(treble["points"]), int(single["points"])],
			int(treble["points"]) > int(single["points"]))
	_check("the bull counts for whatever the answer was",
			bool(g2.throw_for(0, 0.0, 3.0)["right"]))

	# ---- DEALING -----------------------------------------------------
	# Shuffled once and dealt through, so a session cannot repeat a card
	# before it has used the others.
	var g3 := TriviaDarts.new()
	g3.load_deck()
	g3.start([{"name": "a"}], 99)
	var first := str(g3.card.get("q", ""))
	var repeats := 0
	var qs := {}
	for i in g3.deck.size():
		var q := str(g3.card.get("q", ""))
		if qs.has(q):
			repeats += 1
		qs[q] = true
		g3.deal()
	_check("a full pass deals every card once (%d repeats)" % repeats,
			repeats == 0)
	_check("and it comes back round after that",
			str(g3.card.get("q", "")) == first)

	# ---- THE OPPONENT ------------------------------------------------
	var g4 := TriviaDarts.new()
	g4.load_deck()
	g4.start([{"name": "you"}, {"name": "Cam", "npc": true}], 7)
	g4.card = {"q": "t", "a": "blue", "kind": "plain", "why": "-"}
	var knew := 0
	for i in 400:
		if g4.npc_pick(0.62) == "blue":
			knew += 1
	_check("the opponent knows some and not all (%d/400)" % knew,
			knew > 150 and knew < 360)
	var wrong_ok := true
	for i in 200:
		var pick := g4.npc_pick(0.0)
		if pick == "blue":
			wrong_ok = false
		if not g4.colours.has(pick):
			wrong_ok = false
	_check("and when it is wrong it is plausibly wrong", wrong_ok)

	print("[TRIVIA] RESULT: %s (%d failures)"
			% ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
