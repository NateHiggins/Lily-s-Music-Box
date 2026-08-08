extends Node
## Dead Letters: is every envelope actually filable, and does the
## building agree with itself about who lives in it?
##
## The load-bearing check here is CONSISTENCY WITH THE ROSTER. The whole
## game is made of the building's real residents — five surnames living
## on two floors each is what makes a surname-only envelope a puzzle
## instead of a lookup — so the moment somebody moves a resident in
## building_root and not in the deck, a letter starts having the wrong
## answer and nothing complains. The player just quietly loses points
## for being right.
##
## After that: every letter must have a box that exists (or be a dead
## letter on purpose), and a wrong answer must never be a dead end,
## because misfiling is meant to be remembered rather than punished.

const ROSTER := [
	["1A", "Evelyn Marsh"], ["1D", "Teresa Vale"], ["2A", "Mina Vale"],
	["2B", "Lena Ortiz"], ["2C", "Juno Kells"], ["3A", "Malcolm Reed"],
	["3B", "Omar Bell"], ["3D", "Rhea Sato"], ["4A", "Peter Wren"],
	["4C", "Cam Ortiz"], ["4C", "Noel Price"], ["4D", "Transient Guests"],
	["5A", "Nadia Quell"], ["5B", "Cal Dwyer"], ["5C", "Iris Bell"],
	["6A", "Sacha Reed"], ["6B", "Jonah Price"], ["6C", "Mae Kessler"],
]

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	_run()


func _run() -> void:
	var g := DeadLetters.new()
	_check("the tray loads", g.load_deck())
	if g.boxes.is_empty():
		print("[LETTERS] RESULT: FAIL (1 failures)")
		get_tree().quit(1)
		return
	print("      %d boxes, %d letters" % [g.boxes.size(), g.letters.size()])

	# ---- THE BUILDING AGREES WITH ITSELF ----------------------------
	var missing := []
	for r in ROSTER:
		var names: Array = g.names_at(str(r[0]))
		if not names.has(str(r[1])):
			missing.append("%s %s" % [r[0], r[1]])
	_check("every resident has their own box", missing.is_empty())
	if not missing.is_empty():
		print("      not in the deck: %s" % [missing])
	_check("4C holds two people, as it does upstairs",
			g.names_at("4C").size() == 2)

	# The five shared surnames are the whole puzzle. If somebody ever
	# renames one of these, the surname-only letters stop being
	# ambiguous and the game quietly becomes a lookup.
	var surnames := {}
	for r in ROSTER:
		var parts := str(r[1]).split(" ")
		var last := str(parts[parts.size() - 1])
		surnames[last] = int(surnames.get(last, 0)) + 1
	var shared := 0
	for s in surnames:
		if int(surnames[s]) > 1:
			shared += 1
	_check("five surnames are shared across floors (%d)" % shared,
			shared >= 5)

	# ---- EVERY LETTER IS FILABLE ------------------------------------
	var bad := []
	var no_why := 0
	var dead_count := 0
	for L in g.letters:
		var ans := str(L.get("answer", ""))
		if ans == DeadLetters.DEAD:
			dead_count += 1
		elif not g.units().has(ans):
			bad.append(str(L.get("to", "?")))
		if str(L.get("why", "")).strip_edges() == "":
			no_why += 1
	_check("every letter has a box that exists", bad.is_empty())
	if not bad.is_empty():
		print("      unfilable: %s" % [bad])
	_check("every letter explains itself afterwards", no_why == 0)
	_check("there are dead letters to catch (%d)" % dead_count,
			dead_count >= 3)

	# A surname-only letter must actually be ambiguous on its face —
	# otherwise the clues are decoration.
	var ambiguous := 0
	for L in g.letters:
		var to := str(L.get("to", ""))
		if str(L.get("unit", "")) != "":
			continue
		if to.contains("."):
			continue                       # has an initial
		for s in surnames:
			if to == s and int(surnames[s]) > 1:
				ambiguous += 1
	_check("some letters are a bare shared surname (%d)" % ambiguous,
			ambiguous >= 3)

	# ---- PLAYING IT --------------------------------------------------
	g.start(4471)
	_check("a tray comes out (%d)" % g.tray.size(),
			g.tray.size() == mini(int(g.scoring.get("tray", 8)),
					g.letters.size()))
	_check("there is a letter in your hand", not g.current().is_empty())
	var face := g.face_of(g.current())
	_check("the envelope shows something to read (%d lines)" % face.size(),
			face.size() >= 2)

	# File the whole tray correctly and it should score every one.
	var perfect := DeadLetters.new()
	perfect.load_deck()
	perfect.start(99)
	var expect := 0
	while not perfect.done():
		var want := str(perfect.current().get("answer", ""))
		expect += int(perfect.scoring.get("dead_letter", 2)) \
				if want == DeadLetters.DEAD \
				else int(perfect.scoring.get("filed", 1))
		perfect.file_into(want)
	_check("a clean tray scores everything (%d of %d)"
			% [perfect.score, expect], perfect.score == expect)
	_check("and nothing went astray", perfect.misfiled.is_empty())
	_check("the tray is finished", perfect.done())

	# A dead letter is worth more than an easy one, because spotting it
	# asks you to know the building rather than read an envelope.
	_check("a dead letter pays more than a filing",
			int(g.scoring.get("dead_letter", 2))
			> int(g.scoring.get("filed", 1)))

	# ---- MISFILING REMEMBERS ----------------------------------------
	var sloppy := DeadLetters.new()
	sloppy.load_deck()
	sloppy.start(7)
	var wrong_box := "6C"
	var first_to := str(sloppy.current().get("to", ""))
	var belonged := str(sloppy.current().get("answer", ""))
	if belonged == wrong_box:
		wrong_box = "2B"
	var res := sloppy.file_into(wrong_box)
	_check("putting it in the wrong box scores nothing",
			int(res["points"]) == 0 and not bool(res["right"]))
	_check("but the letter is REMEMBERED, not lost",
			sloppy.misfiled.size() == 1
			and str(sloppy.misfiled[0]["to"]) == first_to
			and str(sloppy.misfiled[0]["went_to"]) == wrong_box)
	_check("and it knows where it should have gone",
			str(sloppy.misfiled[0]["belonged"]) == belonged)
	_check("a misfile still moves you on", sloppy.at == 1)

	# The building remembers its dead.
	_check("it knows who Dorothy Ash was",
			g.note_for("Dorothy Ash").length() > 10)

	print("[LETTERS] RESULT: %s (%d failures)"
			% ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
