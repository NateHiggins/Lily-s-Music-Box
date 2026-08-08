class_name ShelfSort
extends RefCounted
## THE BOOKSHELVES — one small game per shelf, and the game is somebody
## else's idea of order.
##
## Every shelf in the building belongs to a person, and every person has
## a scheme. Mae the archivist sorts by Dewey and keeps a card index in
## a shoebox. Iris runs a gallery and sorts by the colour of the spine,
## which is useless for finding anything and she can find anything
## anyway. Peter sorts by author because anything else is an opinion.
## Jonah keeps them in the order they came to him and can tell you who
## gave him each one. Malcolm's shelf has no order at all, and he would
## like it on record that this is also a system.
##
## So the puzzle is never "sort these books". It is "sort these books
## the way THIS PERSON would", and the only way to know is to have paid
## attention to them — which makes a bookshelf a character study you can
## be wrong about.
##
## SHELVES FALL OUT OF ORDER ON THEIR OWN. Books get pulled out and put
## back near enough, and near enough accumulates. drift() is that, and
## it is deliberately gentle: a shelf nobody touches for a week wants
## tidying, not rebuilding.
##
## No camera, no input, no frame. Pure data in, pure data out.

const DATA := "res://data/library.json"

var books: Dictionary = {}       # id -> book
var schemes: Dictionary = {}
var shelves: Array = []

## Live shelf being worked on.
var owner_name := ""
var scheme := "none"
var order: Array = []            # book ids, left to right
var held := -1                   # index of the book in your hand, or -1
var moves := 0
var _rng := RandomNumberGenerator.new()


func load_library() -> bool:
	var f := FileAccess.open(DATA, FileAccess.READ)
	if f == null:
		push_warning("shelves: no library at " + DATA)
		return false
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		push_error("shelves: unparseable library")
		return false
	books = {}
	for b in d.get("books", []):
		books[str(b.get("id", ""))] = b
	schemes = d.get("schemes", {})
	shelves = d.get("shelves", [])
	return books.size() > 0 and shelves.size() > 0


func shelf_of(owner: String) -> Dictionary:
	for s in shelves:
		if str(s.get("owner", "")) == owner:
			return s
	return {}


## The sortable value for a book under a scheme. Everything comes back
## as a string so one comparison serves them all — numbers are padded so
## "9" does not sort after "10", which is the classic way a Dewey shelf
## goes quietly wrong.
func key_of(book_id: String, by: String) -> String:
	var b: Dictionary = books.get(book_id, {})
	if b.is_empty():
		return ""
	var sc: Dictionary = schemes.get(by, {})
	var field := str(sc.get("key", ""))
	match field:
		"":
			return ""
		"dewey":
			return "%010.3f" % float(b.get("dewey", 0.0))
		"height":
			# Tallest first, so the key counts down.
			return "%06d" % (99999 - int(b.get("height", 0)))
		"hue":
			return "%04d" % int(b.get("hue", 0))
		"year":
			return "%05d" % int(b.get("year", 0))
		"title":
			return _title_key(str(b.get("title", "")))
		_:
			return str(b.get(field, "")).to_lower()


## Alphabetical by title IGNORES THE ARTICLE, which is how a library
## does it and how at least one argument in this building started.
func _title_key(t: String) -> String:
	var s := t.to_lower().strip_edges()
	for a in ["the ", "a ", "an "]:
		if s.begins_with(a):
			s = s.substr(a.length())
			break
	return s


## The shelf as its owner would have it.
func correct_order(ids: Array, by: String) -> Array:
	var sc: Dictionary = schemes.get(by, {})
	if str(sc.get("key", "")) == "":
		return ids.duplicate()       # no order: everything is correct
	# Keys are computed once and sorted alongside their ids, rather than
	# recomputed inside a comparator — fewer calls, and no lambda that
	# has to fit on one line to parse.
	var pairs: Array = []
	for id in ids:
		pairs.append([key_of(str(id), by), str(id)])
	pairs.sort_custom(func(x, y): return x[0] < y[0])
	var out: Array = []
	for p in pairs:
		out.append(p[1])
	return out


## Start a shelf, already in whatever state neglect has left it.
func begin(owner: String, disorder := 0.5, seed_value := 0) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	var sh := shelf_of(owner)
	owner_name = owner
	scheme = str(sh.get("scheme", "none"))
	var want := int(sh.get("size", 8))
	# Deal this shelf its own books, deterministically per owner so a
	# shelf is the same shelf every time you walk past it.
	var pool: Array = books.keys()
	pool.sort()
	var pick := RandomNumberGenerator.new()
	pick.seed = hash("shelf:" + owner)
	var chosen: Array = []
	while chosen.size() < mini(want, pool.size()):
		var c: String = str(pool[pick.randi() % pool.size()])
		if not chosen.has(c):
			chosen.append(c)
	order = correct_order(chosen, scheme)
	drift(disorder)
	held = -1
	moves = 0


## Neglect. Books come out and go back near enough, and near enough
## adds up — so this is short local displacements rather than a shuffle.
## A shelf nobody has touched for a week wants tidying, not rebuilding.
func drift(amount := 0.5) -> void:
	if order.size() < 2:
		return
	var n := int(round(clampf(amount, 0.0, 1.0) * order.size() * 0.9))
	for i in n:
		var a := _rng.randi() % order.size()
		var reach: int = 1 + (_rng.randi() % 2)
		var b: int = clampi(a + (reach if _rng.randf() < 0.5 else -reach),
				0, order.size() - 1)
		var t = order[a]
		order[a] = order[b]
		order[b] = t


## How nearly the shelf is in its owner's order, measured as the share
## of NEIGHBOURING PAIRS that read the right way round.
##
## Counting exact positions instead is far too harsh and models the
## wrong thing: put one book back a place early and every book after it
## is "wrong", so a shelf with a single misplacement scores like a shelf
## somebody has thrown at a wall. Two neighbours the wrong way round is
## one small untidiness, and this says so. It still only reaches 1.0
## when the whole shelf is sorted, which is what is_tidy needs.
func rightness() -> float:
	if order.size() < 2:
		return 1.0
	if str((schemes.get(scheme, {}) as Dictionary).get("key", "")) == "":
		return 1.0                   # no system: nothing can be wrong
	var good := 0
	for i in range(1, order.size()):
		if key_of(str(order[i - 1]), scheme) <= key_of(str(order[i]),
				scheme):
			good += 1
	return float(good) / float(order.size() - 1)


func is_tidy() -> bool:
	return rightness() >= 0.999


## Pick a book up, or put the one you are holding down here.
func touch(i: int) -> void:
	if i < 0 or i >= order.size():
		return
	if held < 0:
		held = i
		return
	if held == i:
		held = -1
		return
	# Lift it out and slot it in, shuffling the rest along — which is
	# what a shelf does. A straight swap would let you sort by teleport.
	var b = order[held]
	order.remove_at(held)
	var to: int = i if i < held else i
	order.insert(clampi(to, 0, order.size()), b)
	held = -1
	moves += 1


func label_of(by: String) -> String:
	var sc: Dictionary = schemes.get(by, {})
	return str(sc.get("label", by))


func note_of(by: String) -> String:
	var sc: Dictionary = schemes.get(by, {})
	return str(sc.get("note", ""))


func book(id: String) -> Dictionary:
	return books.get(id, {})
