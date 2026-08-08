class_name TermGrid
extends RefCounted
## A character cell grid, because this phone genuinely is a terminal.
##
## The whole OS draws through this: boot log, home screen, every app. It
## is 60x24 cells of 8x16 pixels, which is 480x384 - a hair taller than
## the 480x360 the handset it is modelled on actually had, and chosen so
## the cells come out as whole pixels. Nothing here anti-aliases and
## nothing here is subpixel-positioned; the SubViewport is rendered at
## exactly this size and scaled up with nearest-neighbour, so what you
## see is real pixels rather than a filter pretending to be some.
##
## If you know curses, you already know this class. put() writes a
## string at a cell, box() draws a frame in single-line glyphs, and the
## OS composes a screen every frame rather than retaining widgets.
## Immediate mode is the right shape here: an OS that redraws its whole
## screen 30 times a second is exactly what a 2011 handset did.

const COLS := 60
const ROWS := 24
const CW := 8
const CH := 16

# Two palettes on one screen, and the split is the whole idea.
#
# The house colours are the SYSTEM: plum ground, gold text, ivory
# highlights. That is the company's software and it looks like a
# terminal because it is one.
#
# The neons are the SKIN. op@nightdesk did not just strip this Linux,
# they decorated it, in 1995, with the taste of somebody who had seen
# exactly one film about computers and loved it unreservedly. Cyan,
# magenta and acid green over the top of a beige corporate handset is
# not an accident of art direction; it is a character detail.
const BG := Color("120810")
const BG_ALT := Color("2a1220")
const FG := Color("d4af5e")        # gold - body text
const HI := Color("efe3d0")        # ivory - selection, headings
const WARN := Color("c4788a")      # rose - errors, and bad news
const DIM := Color(0.55, 0.44, 0.24)
const CYAN := Color("31e0f0")
const MAGENTA := Color("f03cc8")
const GREEN := Color("5cf07a")
const BLUE := Color("4a6cf0")
const NEON := [CYAN, MAGENTA, GREEN, BLUE]

## 3x5 block glyphs for banner text. Enough of an alphabet to shout.
const GLYPHS := {
	"A": ["010", "101", "111", "101", "101"],
	"B": ["110", "101", "110", "101", "110"],
	"C": ["011", "100", "100", "100", "011"],
	"D": ["110", "101", "101", "101", "110"],
	"E": ["111", "100", "110", "100", "111"],
	"F": ["111", "100", "110", "100", "100"],
	"G": ["011", "100", "101", "101", "011"],
	"H": ["101", "101", "111", "101", "101"],
	"I": ["111", "010", "010", "010", "111"],
	"J": ["001", "001", "001", "101", "010"],
	"K": ["101", "110", "100", "110", "101"],
	"L": ["100", "100", "100", "100", "111"],
	"M": ["101", "111", "111", "101", "101"],
	"N": ["101", "111", "111", "111", "101"],
	"O": ["010", "101", "101", "101", "010"],
	"P": ["110", "101", "110", "100", "100"],
	"Q": ["010", "101", "101", "111", "011"],
	"R": ["110", "101", "110", "101", "101"],
	"S": ["011", "100", "010", "001", "110"],
	"T": ["111", "010", "010", "010", "010"],
	"U": ["101", "101", "101", "101", "011"],
	"V": ["101", "101", "101", "101", "010"],
	"W": ["101", "101", "111", "111", "101"],
	"X": ["101", "101", "010", "101", "101"],
	"Y": ["101", "101", "010", "010", "010"],
	"Z": ["111", "001", "010", "100", "111"],
	"0": ["111", "101", "101", "101", "111"],
	"1": ["010", "110", "010", "010", "111"],
	"2": ["110", "001", "010", "100", "111"],
	"3": ["110", "001", "010", "001", "110"],
	"4": ["101", "101", "111", "001", "001"],
	"5": ["111", "100", "110", "001", "110"],
	"6": ["011", "100", "111", "101", "111"],
	"7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"],
	"9": ["111", "101", "111", "001", "110"],
	" ": ["000", "000", "000", "000", "000"],
	".": ["000", "000", "000", "000", "010"],
	"!": ["010", "010", "010", "000", "010"],
}

var _chars: PackedStringArray
var _fg: PackedColorArray
var _bg: PackedColorArray


func _init() -> void:
	clear()


func clear(bg := BG) -> void:
	_chars = PackedStringArray()
	_fg = PackedColorArray()
	_bg = PackedColorArray()
	_chars.resize(COLS * ROWS)
	_fg.resize(COLS * ROWS)
	_bg.resize(COLS * ROWS)
	for i in COLS * ROWS:
		_chars[i] = " "
		_fg[i] = FG
		_bg[i] = bg


func put(x: int, y: int, text: String, fg := FG, bg := Color.TRANSPARENT) -> void:
	if y < 0 or y >= ROWS:
		return
	for i in text.length():
		var cx := x + i
		if cx < 0 or cx >= COLS:
			continue
		var idx := y * COLS + cx
		_chars[idx] = text[i]
		_fg[idx] = fg
		if bg.a > 0.0:
			_bg[idx] = bg


## Centred on the full width, which is most of what a 60-column screen
## ever needs.
func put_centre(y: int, text: String, fg := FG, bg := Color.TRANSPARENT) -> void:
	put((COLS - text.length()) / 2, y, text, fg, bg)


func fill_row(y: int, bg: Color) -> void:
	put(0, y, " ".repeat(COLS), FG, bg)


func box(x: int, y: int, w: int, h: int, fg := DIM) -> void:
	put(x, y, "+" + "-".repeat(maxi(0, w - 2)) + "+", fg)
	put(x, y + h - 1, "+" + "-".repeat(maxi(0, w - 2)) + "+", fg)
	for r in range(y + 1, y + h - 1):
		put(x, r, "|", fg)
		put(x + w - 1, r, "|", fg)


## Banner text in 3x5 blocks. `cycle` shifts the neon per column so a
## word reads as a spectrum sweep rather than a flat colour - the film's
## single most repeated trick, and it costs one modulo.
func banner(x: int, y: int, text: String, cycle := 0,
		solid := "#") -> void:
	var cx := x
	for i in text.length():
		var ch := text[i].to_upper()
		if not GLYPHS.has(ch):
			cx += 4
			continue
		var rows: Array = GLYPHS[ch]
		for r in rows.size():
			var bits: String = rows[r]
			for c in bits.length():
				if bits[c] == "1":
					var col: Color = NEON[(cx + c + cycle) % NEON.size()]
					put(cx + c, y + r, solid, col)
		cx += 4


## A column of scrolling nonsense hex. The film's screens are never
## still; something is always falling somewhere in the frame.
func data_column(x: int, seed_i: int, t: float, fg := DIM) -> void:
	for y in ROWS:
		var n := (seed_i * 7919 + y * 131 + int(t * 9.0) * 17) % 251
		if n % 5 == 0:
			continue
		put(x, y, "%X" % (n % 16), fg)


func draw(ci: CanvasItem, font: Font) -> void:
	for y in ROWS:
		for x in COLS:
			var idx := y * COLS + x
			var bg: Color = _bg[idx]
			if bg != BG:
				ci.draw_rect(Rect2(x * CW, y * CH, CW, CH), bg)
			var ch: String = _chars[idx]
			if ch == " ":
				continue
			# Baseline sits 12 px down in a 16 px cell: the descenders on
			# g, y and p need the remaining four or they clip.
			ci.draw_string(font, Vector2(x * CW, y * CH + 12),
					ch, HORIZONTAL_ALIGNMENT_LEFT, -1, CH - 3, _fg[idx])


## One monospace face, hinted and aliased into hard pixels. Built in
## code rather than shipped as an asset so the phone has no import step
## and no licence question.
static func make_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
			"Consolas", "Courier New", "DejaVu Sans Mono",
			"Liberation Mono", "monospace"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.multichannel_signed_distance_field = false
	return f
