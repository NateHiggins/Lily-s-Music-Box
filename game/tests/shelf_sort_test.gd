extends Node
## The bookshelves: does each scheme sort the way that person would?
##
## The trap this file exists for is SORTING NUMBERS AS TEXT. Dewey 25.4
## must come before 133.12, and a naive string compare puts "25.4"
## after "133.12" because "2" > "1". Heights and years have the same
## problem. It is the single most likely way a shelf goes quietly wrong,
## it looks fine at a glance, and only an archivist would ever notice —
## which in this building is exactly who owns that shelf.
##
## After that: every scheme has to be a DIFFERENT order, or the whole
## conceit (that a shelf is a character study) is decoration. And the
## drift has to be gentle — a shelf nobody has touched wants tidying,
## not rebuilding.

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	_run()


func _sorted_by(g: ShelfSort, ids: Array, by: String) -> bool:
	var s := g.correct_order(ids, by)
	for i in range(1, s.size()):
		if g.key_of(str(s[i - 1]), by) > g.key_of(str(s[i]), by):
			return false
	return true


func _run() -> void:
	var g := ShelfSort.new()
	_check("the library loads", g.load_library())
	if g.books.is_empty():
		print("[SHELVES] RESULT: FAIL (1 failures)")
		get_tree().quit(1)
		return
	print("      %d books, %d shelves, %d schemes"
			% [g.books.size(), g.shelves.size(), g.schemes.size()])

	# ---- THE BOOKS ARE PROPERLY IDENTIFIED --------------------------
	# Every sort needs every field. A book missing its Dewey is
	# unsortable on one shelf and fine on six others, which is the sort
	# of hole that shows up months later in one flat.
	var incomplete: Array = []
	for id in g.books:
		var b: Dictionary = g.books[id]
		for f in ["title", "author", "subject", "dewey", "hue",
				"height", "year", "note"]:
			if not b.has(f):
				incomplete.append("%s:%s" % [id, f])
	_check("every book carries every field a scheme needs",
			incomplete.is_empty())
	if not incomplete.is_empty():
		print("      missing: %s" % [incomplete.slice(0, 6)])

	# ---- NUMBERS SORT AS NUMBERS ------------------------------------
	# The one that bites: 25.4 before 133.12.
	var low := g.key_of("sorting", "dewey")        # 25.4
	var high := g.key_of("walls", "dewey")         # 133.12
	_check("Dewey 25.4 sorts before 133.12 (%s < %s)" % [low, high],
			low < high)
	var tall := g.key_of("atlas", "size")          # 285 mm
	var short := g.key_of("interborough", "size")  # 132 mm
	_check("tallest comes first (%s < %s)" % [tall, short], tall < short)
	var old := g.key_of("flowers", "acquired")     # 1899
	var new := g.key_of("onefinger", "acquired")   # 1927
	_check("oldest arrives first (%s < %s)" % [old, new], old < new)

	# Every scheme actually produces a sorted list under its own key.
	var all: Array = g.books.keys()
	for by in g.schemes:
		if str(g.schemes[by].get("key", "")) == "":
			continue
		_check("sorts correctly %s" % g.label_of(str(by)),
				_sorted_by(g, all, str(by)))

	# The article is ignored, or "The Orison" files under T forever.
	var t := g.correct_order(["prospectus", "atlas", "walls"], "title")
	_check("titles ignore the article (%s)" % [t],
			str(t[0]) == "prospectus")     # "Orison" beats "Queens"/"What"

	# ---- EACH PERSON'S SHELF IS THEIR OWN ---------------------------
	# If two schemes give the same order the conceit is decoration.
	var sample: Array = ["prospectus", "nurse", "radio", "walls",
			"flowers", "atlas"]
	var seen: Dictionary = {}
	var distinct := 0
	for by in g.schemes:
		if str(g.schemes[by].get("key", "")) == "":
			continue
		var sig := "|".join(PackedStringArray(
				g.correct_order(sample, str(by))))
		if not seen.has(sig):
			seen[sig] = true
			distinct += 1
	_check("the schemes disagree with each other (%d orders)" % distinct,
			distinct >= 5)

	# ---- A SHELF IS ALWAYS THE SAME SHELF ---------------------------
	var a := ShelfSort.new()
	a.load_library()
	a.begin("Mae Kessler", 0.0, 1)
	var b2 := ShelfSort.new()
	b2.load_library()
	b2.begin("Mae Kessler", 0.0, 2)
	_check("the same person always owns the same books",
			"|".join(PackedStringArray(a.order))
			== "|".join(PackedStringArray(b2.order)))
	_check("and undisturbed it is already in order", a.is_tidy())

	# Malcolm's shelf has no order, so it can never be wrong.
	var m := ShelfSort.new()
	m.load_library()
	m.begin("Malcolm Reed", 1.0, 3)
	_check("a shelf with no system is never untidy", m.is_tidy())

	# ---- DRIFT IS GENTLE --------------------------------------------
	var d := ShelfSort.new()
	d.load_library()
	d.begin("Peter Wren", 0.0, 5)
	var before := d.rightness()
	d.drift(0.5)
	var after := d.rightness()
	_check("neglect disturbs a shelf (%.2f -> %.2f)" % [before, after],
			after < before)
	_check("but does not empty it", d.order.size() > 0)
	# A week of neglect should want tidying, not rebuilding: most of the
	# shelf is still roughly where it belongs.
	var worst := 1.0
	for i in 24:
		var w := ShelfSort.new()
		w.load_library()
		w.begin("Peter Wren", 0.5, 100 + i)
		worst = minf(worst, w.rightness())
	_check("a neglected shelf still resembles itself (worst %.2f)"
			% worst, worst > 0.15)

	# ---- PUTTING ONE BACK -------------------------------------------
	var p := ShelfSort.new()
	p.load_library()
	p.begin("Iris Bell", 0.6, 7)
	var n0 := p.order.size()
	p.touch(0)
	_check("you can take a book down", p.held == 0)
	p.touch(3)
	_check("and put it back somewhere else", p.held == -1)
	_check("without losing it", p.order.size() == n0)
	_check("and it counts as a move", p.moves == 1)

	# Sorting it by hand finishes it — the shelf is always solvable.
	var q := ShelfSort.new()
	q.load_library()
	q.begin("Mae Kessler", 0.8, 9)
	q.order = q.correct_order(q.order, q.scheme)
	_check("a shelf put right reads as tidy", q.is_tidy())

	# ---- EVERY SHELF IS SOMEBODY'S ----------------------------------
	var no_note := 0
	for s in g.shelves:
		if str(s.get("note", "")).strip_edges() == "":
			no_note += 1
		if not g.schemes.has(str(s.get("scheme", ""))):
			_check("shelf %s has a real scheme" % str(s.get("owner", "?")),
					false)
	_check("every shelf says something about its owner", no_note == 0)

	print("[SHELVES] RESULT: %s (%d failures)"
			% ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
