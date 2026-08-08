class_name TriviaDarts
extends RefCounted
## THE RAINBOW ROUND — the game the Harukiya actually plays on its
## dartboard.
##
## The board is not a scoring board any more. It is seven rainbow
## slices, and a deck of questions whose answer is always a colour. A
## question is read out, everybody throws, and you score for landing on
## the colour the answer was.
##
## What makes it a bar game rather than a quiz is HOW the answer is a
## colour. Some of them just are one — a banana is yellow. Some hide the
## colour in a name: Kind of Blue, the Red Baron, green with envy. And
## some make you go sideways for it, and those are worth the most,
## because arriving at "orange" from a sodium lamp is a better moment
## than knowing what colour a bus is.
##
## THE DECK IS DATA. game/data/trivia_darts.json — questions, answers,
## kinds, bonuses and the line that explains the link. Adding a card, or
## retuning what a pun is worth, is never a code change, because these
## will be rewritten constantly and half the fun is arguing about them.

const DATA := "res://data/trivia_darts.json"

## Rainbow order, clockwise from the top. Seven slices of 360/7.
var colours: Array = []
var deck: Array = []
var kinds: Dictionary = {}
var scoring: Dictionary = {}

var players: Array = []
var card: Dictionary = {}
var round_no := 0
var thrown: Dictionary = {}      # player index -> {colour, ring, points}
var _order: Array = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func load_deck() -> bool:
	var f := FileAccess.open(DATA, FileAccess.READ)
	if f == null:
		push_warning("trivia darts: no deck at " + DATA)
		return false
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		push_error("trivia darts: unparseable deck")
		return false
	colours = d.get("colours", [])
	deck = d.get("deck", [])
	kinds = d.get("kinds", {})
	scoring = d.get("scoring", {})
	return colours.size() > 0 and deck.size() > 0


## Which slice a point lands in. `dx`/`dy` are millimetres from the
## bull, y up. Returns {colour, ring, mult, on}.
func slice_at(dx: float, dy: float) -> Dictionary:
	var r := sqrt(dx * dx + dy * dy)
	if r > DartsGame.R_DOUBLE_OUT:
		return {"colour": "", "ring": "off", "mult": 0, "on": false}
	if r <= DartsGame.R_OUTER_BULL:
		# The bull is wild: it is the smallest thing on the board and
		# hitting it should never be a punishment.
		return {"colour": "*", "ring": "bull", "mult": 1, "on": true}
	var n := colours.size()
	var ang := rad_to_deg(atan2(dx, dy))
	if ang < 0.0:
		ang += 360.0
	var span := 360.0 / float(n)
	var idx := int(floor(fposmod(ang + span * 0.5, 360.0) / span)) % n
	var ring := "single"
	var mult := 1
	if r >= DartsGame.R_TREBLE_IN and r <= DartsGame.R_TREBLE_OUT:
		ring = "treble"
		mult = int(scoring.get("treble", 3))
	elif r >= DartsGame.R_DOUBLE_IN:
		ring = "double"
		mult = int(scoring.get("double", 2))
	return {"colour": str(colours[idx]), "ring": ring, "mult": mult,
		"on": true}


func start(names: Array, seed_value := 0) -> void:
	players = []
	for n in names:
		players.append({"name": str(n.get("name", "?")), "score": 0,
			"npc": bool(n.get("npc", false))})
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_order = []
	for i in deck.size():
		_order.append(i)
	# Shuffled once, then dealt through — so a session never repeats a
	# card before it has used the rest, which a random draw would.
	for i in range(_order.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var t = _order[i]
		_order[i] = _order[j]
		_order[j] = t
	_next = 0
	round_no = 0
	deal()


func deal() -> void:
	if deck.is_empty():
		return
	card = deck[_order[_next % _order.size()]]
	_next += 1
	round_no += 1
	thrown = {}


func bonus_for(kind: String) -> int:
	var k: Dictionary = kinds.get(kind, {})
	return int(k.get("bonus", 0))


## Land player `who`'s dart. Returns what it was worth and why.
func throw_for(who: int, dx: float, dy: float) -> Dictionary:
	var hit := slice_at(dx, dy)
	var want := str(card.get("a", ""))
	var kind := str(card.get("kind", "plain"))
	var right: bool = hit["on"] and (hit["colour"] == want
			or (hit["colour"] == "*"
				and bool(scoring.get("bull_is_wild", true))))
	var pts := 0
	if right:
		pts = int(scoring.get("hit", 2)) * int(hit["mult"])
		pts += bonus_for(kind)
	var result := {"colour": hit["colour"], "ring": hit["ring"],
		"right": right, "points": pts, "kind": kind,
		"wanted": want, "why": str(card.get("why", ""))}
	thrown[who] = result
	if who >= 0 and who < players.size():
		players[who]["score"] = int(players[who]["score"]) + pts
	return result


func everyone_thrown() -> bool:
	return thrown.size() >= players.size()


func leader() -> Dictionary:
	var best: Dictionary = {}
	for p in players:
		if best.is_empty() or int(p["score"]) > int(best["score"]):
			best = p
	return best


## What an opponent aims at: the colour it believes, which is usually
## but not always the right one. `sureness` 0..1 — how often it knows.
func npc_pick(sureness := 0.62) -> String:
	if colours.is_empty():
		return ""
	if _rng.randf() < sureness:
		return str(card.get("a", colours[0]))
	# Wrong, but plausibly wrong: an adjacent colour, the way a person
	# guesses when they nearly know it.
	var want := str(card.get("a", ""))
	var i := colours.find(want)
	if i < 0:
		i = 0
	var step: int = 1 if _rng.randf() < 0.5 else -1
	return str(colours[(i + step + colours.size()) % colours.size()])


## The centre of a colour's slice, in millimetres, at a comfortable
## radius — what an opponent actually aims the dart at.
func aim_point(colour: String, radius := 130.0) -> Vector2:
	var i := colours.find(colour)
	if i < 0:
		return Vector2.ZERO
	var span := 360.0 / float(colours.size())
	var ang := deg_to_rad(i * span)
	return Vector2(sin(ang), cos(ang)) * radius
