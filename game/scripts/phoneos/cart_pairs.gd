class_name CartPairs
extends RefCounted
## PAIRS — the Gilded Moth memory-match, ported off HTML.
##
## The original is a 367-line canvas game: a grid of cards, match two
## and they dissolve, and what they dissolve to reveal is an image from
## a gallery the player fills themselves. Its own hint text says it —
## "each match melts the veil".
##
## The port changes exactly one thing, and it is the reason this was
## the first of the three to do: the gallery is the HANDSET'S CAMERA
## ROLL. Photograph the Orison, and the thing under the cards is
## somewhere you have been. A corridor you walked at 3 a.m. comes back
## as a puzzle you have to take apart to see. Nothing is uploaded and
## nothing is bundled — the roll is forty frames the player took, on
## their own machine, which is the same BYO contract the web build has
## and a better fit for a game about a building.
##
## Drawn in pixels rather than characters. The OS is a terminal, but a
## cartridge is a cartridge, so it gets the panel and the grid supplies
## only a status line — the same arrangement the camera app uses, where
## anything the OS leaves as a blank cell is a hole the picture shows
## through.

const COLS := 4
const ROWS := 4
const PAIRS := COLS * ROWS / 2

## Card faces. The web build used emoji; a 2011 handset has no colour
## font, so these are the same shapes the OS already draws with.
const FACES := ["/\\", "><", "()", "[]", "{}", "~~", "**", "##"]
const FACE_COLS := [Color("31e0f0"), Color("f03cc8"), Color("5cf07a"),
	Color("d4af5e"), Color("c4788a"), Color("4a6cf0"), Color("efe3d0"),
	Color("b8761e")]

enum State { DEAL, PLAY, PEEK, WON }

var deck: Array[int] = []          # face index per cell
var revealed: Array[bool] = []     # permanently gone (matched)
var facing: Array[bool] = []       # currently turned up
var cursor := 0
var moves := 0
var matched := 0
var state: int = State.DEAL
var reveal_tex: Texture2D
var _first := -1
var _peek_until := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


## `roll` is PhoneCamera.roll. With nothing photographed yet the game is
## still playable — it just has nothing behind the cards, and says so.
func start(roll: Array, loader: Callable) -> void:
	_rng.randomize()
	deck.clear()
	revealed.clear()
	facing.clear()
	var faces: Array[int] = []
	for i in PAIRS:
		faces.append(i)
		faces.append(i)
	faces.shuffle()
	for f in faces:
		deck.append(f)
		revealed.append(false)
		facing.append(false)
	cursor = 0
	moves = 0
	matched = 0
	_first = -1
	state = State.PLAY
	reveal_tex = null
	if roll.size() > 0:
		reveal_tex = loader.call(str(roll[_rng.randi() % roll.size()]))


func tick(delta: float) -> void:
	_t += delta
	if state == State.PEEK and _t >= _peek_until:
		# The pair did not match; turn them back down.
		for i in facing.size():
			if facing[i] and not revealed[i]:
				facing[i] = false
		_first = -1
		state = State.PLAY


func key(action: String) -> void:
	if state == State.WON:
		if action == "ok":
			start([], func(_p): return null)
		return
	if state != State.PLAY:
		return
	match action:
		"left": cursor = (cursor - 1 + deck.size()) % deck.size()
		"right": cursor = (cursor + 1) % deck.size()
		"up": cursor = (cursor - COLS + deck.size()) % deck.size()
		"down": cursor = (cursor + COLS) % deck.size()
		"ok": _flip(cursor)


func _flip(i: int) -> void:
	if revealed[i] or facing[i]:
		return
	facing[i] = true
	if _first < 0:
		_first = i
		return
	moves += 1
	if deck[_first] == deck[i]:
		revealed[_first] = true
		revealed[i] = true
		matched += 1
		_first = -1
		if matched >= PAIRS:
			state = State.WON
	else:
		# Hold both up long enough to actually be read, then flip back.
		state = State.PEEK
		_peek_until = _t + 0.85


## The picture sits under everything; matched cards simply stop being
## drawn over it, so the image is uncovered rather than faded in.
func draw(ci: CanvasItem, rect: Rect2, font: Font) -> void:
	if reveal_tex:
		ci.draw_texture_rect(reveal_tex, rect, false)
	else:
		ci.draw_rect(rect, Color("1a1020"))
	var cw := rect.size.x / float(COLS)
	var ch := rect.size.y / float(ROWS)
	for i in deck.size():
		if revealed[i]:
			continue
		var cx := rect.position.x + (i % COLS) * cw
		var cy := rect.position.y + (i / COLS) * ch
		var card := Rect2(cx + 2, cy + 2, cw - 4, ch - 4)
		if facing[i]:
			ci.draw_rect(card, Color("2a1220"))
			var f: int = deck[i]
			ci.draw_string(font, Vector2(cx + cw * 0.5 - 8,
					cy + ch * 0.5 + 6), FACES[f],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 18, FACE_COLS[f])
		else:
			# Face down: the veil. Gold hatch on plum, per house palette.
			ci.draw_rect(card, Color("120810"))
			ci.draw_rect(Rect2(card.position + Vector2(3, 3),
					card.size - Vector2(6, 6)), Color("2a1220"))
			ci.draw_string(font, Vector2(cx + cw * 0.5 - 6,
					cy + ch * 0.5 + 5), "//",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
					Color(0.55, 0.44, 0.24))
		if i == cursor and state == State.PLAY:
			var blink: bool = fmod(_t, 0.8) < 0.5
			ci.draw_rect(card, Color("d4af5e") if blink
					else Color("efe3d0"), false, 2.0)


## The status the OS grid writes around the picture.
func status() -> String:
	match state:
		State.WON:
			return "the veil is gone.  %d moves.  enter: again" % moves
		_:
			if reveal_tex == null:
				return "%d/%d  ..  nothing behind these yet" % [matched, PAIRS]
			return "%d/%d matched   %d moves" % [matched, PAIRS, moves]
