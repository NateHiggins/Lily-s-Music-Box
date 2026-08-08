class_name DeadLetters
extends RefCounted
## DEAD LETTERS — sorting the mail bank in the lobby.
##
## A tray of post and forty-odd brass boxes. Most of it is obvious. Some
## of it is a surname with no unit, and this building has five surnames
## living on two floors each — two Vales, two Bells, two Reeds, two
## Prices, two Ortizes — so the envelope has to be read rather than
## glanced at. A conservatory writes to Mina, not Teresa. A union local
## writes to Omar, not Iris. The ambiguity is not invented for the game;
## it is the resident roster the building already had.
##
## AND SOME OF IT CANNOT BE FILED. Letters for people who moved out, or
## died, or never lived here at all, and one addressed to a post rather
## than a person. Spotting those is worth more than filing the easy
## ones, because it is the only part that asks you to know the building
## rather than read an envelope.
##
## MISFILING IS NOT A FAIL STATE. It is recorded and handed back, so a
## letter put in the wrong box is a letter that can surface in somebody
## else's story later. Nothing here punishes you; it just remembers.

const DATA := "res://data/dead_letters.json"
const DEAD := "dead"

var boxes: Array = []            # [{unit, names}]
var gone: Array = []             # who the dead letters are for
var letters: Array = []          # the whole deck
var scoring: Dictionary = {}

var tray: Array = []             # this session's letters, in order
var at := 0                      # which one is in your hand
var score := 0
var filed := 0
var missed := 0
var misfiled: Array = []         # [{to, went_to, belonged, why}]
var history: Array = []
var _rng := RandomNumberGenerator.new()


func load_deck() -> bool:
	var f := FileAccess.open(DATA, FileAccess.READ)
	if f == null:
		push_warning("dead letters: no deck at " + DATA)
		return false
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		push_error("dead letters: unparseable deck")
		return false
	boxes = d.get("boxes", [])
	gone = d.get("gone", [])
	letters = d.get("letters", [])
	scoring = d.get("scoring", {})
	return boxes.size() > 0 and letters.size() > 0


func units() -> Array:
	var u: Array = []
	for b in boxes:
		u.append(str(b.get("unit", "")))
	return u


func names_at(unit: String) -> Array:
	for b in boxes:
		if str(b.get("unit", "")) == unit:
			return b.get("names", [])
	return []


func start(seed_value := 0) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	var pool: Array = letters.duplicate()
	# Shuffle, then take a tray. A tray is short on purpose: this is a
	# thing you do at the start of a shift, not a career.
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	var want := int(scoring.get("tray", 8))
	tray = pool.slice(0, mini(want, pool.size()))
	at = 0
	score = 0
	filed = 0
	missed = 0
	misfiled = []
	history = []


func current() -> Dictionary:
	if at < 0 or at >= tray.size():
		return {}
	return tray[at]


func done() -> bool:
	return at >= tray.size()


## File the letter in your hand. `unit` is a box, or DEAD for the
## dead-letter drawer. Returns what happened and why.
func file_into(unit: String) -> Dictionary:
	var L := current()
	if L.is_empty():
		return {}
	var belongs := str(L.get("answer", ""))
	var right: bool = unit == belongs
	var pts := 0
	if right:
		pts = int(scoring.get("dead_letter", 2)) if belongs == DEAD \
				else int(scoring.get("filed", 1))
		filed += 1
	else:
		missed += 1
		misfiled.append({"to": str(L.get("to", "")), "went_to": unit,
			"belonged": belongs, "why": str(L.get("why", ""))})
	score += pts
	var out := {"to": str(L.get("to", "")), "right": right,
		"belonged": belongs, "went_to": unit, "points": pts,
		"why": str(L.get("why", ""))}
	history.append(out)
	at += 1
	return out


## Who a dead letter was for, if the building remembers them.
func note_for(name: String) -> String:
	for g in gone:
		if str(g.get("name", "")) == name:
			return str(g.get("note", ""))
	return ""


## Everything the envelope shows you, as lines.
func face_of(L: Dictionary) -> Array:
	var lines: Array = []
	lines.append(str(L.get("to", "")))
	var u := str(L.get("unit", ""))
	lines.append(u if u != "" else "(no unit)")
	for c in L.get("clues", []):
		lines.append(str(c))
	return lines
