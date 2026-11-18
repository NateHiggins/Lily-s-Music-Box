extends Node3D
## Lily's strips on the Harukiya's bar (Lily, 2026-11-07): a short pile of the days
## that have come, beside the counter glass. The player's hand draws the top strip
## off toward the customer's side; drawn far enough, it is bought, a penny, and goes
## into the case's comics pocket. Released, the top sheet slides back onto the pile.
##
## The catalogue (game/data/lily_strips.json, through PaperPocket) owns which strips
## exist and which are kept; the Harukiya's ShopSales owns the penny, the stock and
## the hours, so a refused sale leaves money, stock and the pocket as they were.
## RUL-013: the sheet is grabbed, moved and released; there is no menu.

const SHOP := "harukiya"
## Source metres: on the bar top a hand's width west of the counter glass.
const HOME := [0.66, -30.22]
const TOP_Z := -1.72
const SHEET := Vector3(0.24, 0.004, 0.10)
const PER_SHEET := 0.0018
const CARD := Vector3(0.20, 0.09, 0.003)
const SLIDE := 0.16
const DRAWN_AT := 0.9
const SLIDE_PIXELS := 160.0
const RETURN_SPEED := 0.6
const NOTICE_SECONDS := 3.5
const NONE_LEFT := "No new strip on the bar."
const REFUSED := {
	"insufficient_funds": "Not enough cash for a penny strip.",
	"terminal_unavailable": "The bar is closed.",
	"out_of_stock": "The strips are all gone tonight.",
	"no_carrier": "The till's radio carrier is down.",
	"save_unavailable": "The till can't take it just now.",
}
const MetreUV := preload("res://scripts/building/v2_metre_box_uv.gd")

var world: Node3D
var sales: ShopSales
var pile: MeshInstance3D
var top: MeshInstance3D
var card: Label3D
var card_board: MeshInstance3D
var notice: Label
var _slide := 0.0
var _held := false
var _drawn := false
var _notice_left := 0.0
var _shown := -1
var _poll := 0.0
var _rustle: AudioStreamPlayer3D


func configure(runtime: Node3D, region: Node3D, shop_sales: ShopSales, shared_notice: Label) -> bool:
	world = runtime
	sales = shop_sales
	notice = shared_notice
	if region == null or sales == null or notice == null:
		return false
	region.get("actors").add_child(self)
	position = GameBoot.b2g([HOME[0], HOME[1], TOP_Z])
	var paper := MatLib.get_mat("paper").duplicate() as StandardMaterial3D
	paper.uv1_triplanar = false
	paper.uv1_scale = Vector3.ONE / float(MatLib.SETS["paper"][3])
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	pile = MeshInstance3D.new()
	pile.name = "StripPile"
	add_child(pile)
	top = MeshInstance3D.new()
	top.name = "TopStrip"
	var box := BoxMesh.new()
	box.size = SHEET
	box.material = paper
	top.mesh = MetreUV.chart(box)
	add_child(top)
	pile.set_meta("paper", paper)
	# A small card stood up behind the pile, facing the customer; its lettering is Label3D (RUL-008).
	card_board = MeshInstance3D.new()
	card_board.name = "StripCardBoard"
	var board := BoxMesh.new()
	board.size = CARD
	board.material = paper
	card_board.mesh = MetreUV.chart(board)
	add_child(card_board)
	card = Label3D.new()
	card.name = "StripCard"
	card.text = "LILY'S STRIP\nA PENNY"
	card.pixel_size = 0.0010
	card.font_size = 30
	card.modulate = Color(0.12, 0.09, 0.07)
	card.outline_size = 0
	card_board.add_child(card)
	card.position = Vector3(0, 0, CARD.z * 0.5 + 0.0008)
	_rustle = AudioStreamPlayer3D.new()
	_rustle.stream = PropAudio.get_stream("tick")
	_rustle.unit_size = 2.0
	add_child(_rustle)
	_refresh(true)
	preload("res://scripts/props/manipulation_area.gd").install(top, _grip)
	return true


## Toward the customer: source south, away from the back bar.
func toward() -> Vector3:
	return (GameBoot.b2g([0.0, -1.0, 0.0]) - GameBoot.b2g([0.0, 0.0, 0.0])).normalized()


func today() -> String:
	var catalog := get_tree().get_first_node_in_group("newspaper_catalog") as NewspaperCatalog
	return catalog.today() if catalog != null else ""


## The strips on the pile tonight, newest first: their day has come and the case does not hold them.
func on_pile() -> Array:
	var date := today()
	return [] if date == "" else PaperPocket.strips_on_sale(date)


func _grip() -> Dictionary:
	return {"owner": self, "part": top, "frame": self, "kind": "slide", "axis": toward(),
		"minimum": 0.0, "maximum": SLIDE, "gesture_travel_px": SLIDE_PIXELS,
		"gesture_screen_axis": Vector2.DOWN,
		"read": func(): return _slide,
		"write": func(value: float):
			if _held:
				_slide = value
				_pose()
				if _slide >= SLIDE * DRAWN_AT and not _drawn:
					_drawn = true
					_draw_top(),
		"owns": func(): return _held,
		"begin": func():
			if _held or not top.visible:
				return false
			_held = true
			_drawn = false
			return true,
		"end": func():
			_held = false}


func _pose() -> void:
	top.position = Vector3(0, _pile_height() + SHEET.y * 0.5, 0) + toward() * _slide


func _pile_height() -> float:
	return maxf(on_pile().size() - 1, 0) * PER_SHEET


## The top strip has come off the pile: it is bought, or the bar says why not.
func _draw_top() -> void:
	_rustle.play()
	var strips := on_pile()
	if strips.is_empty():
		_say(NONE_LEFT)
		return
	var found: Dictionary = strips[0]
	var id := str(found.id)
	var sold := sales.transact_delivering(PaperPocket.strip_item(), SHOP, func(): return PaperPocket.tuck_strip(id))
	if not sold:
		_say(REFUSED.get(sales.transaction_status(PaperPocket.strip_item()), "The bar can't sell it just now."))
		return
	# The strip is in the case: the hand lets go of it.
	var player := get_tree().get_first_node_in_group("player_controller")
	if player != null and player.has_method("cancel_manipulation"):
		player.cancel_manipulation()
	_held = false
	_slide = 0.0
	_say("Lily's strip, \"%s\". A penny, into the case." % str(found.get("title", "")))
	_refresh(true)


func _say(text: String) -> void:
	notice.text = text
	_notice_left = NOTICE_SECONDS


## The pile's height follows the strips left on it; with none, only the card stays.
func _refresh(force := false) -> void:
	var count := on_pile().size()
	if count == _shown and not force:
		return
	_shown = count
	var height := maxf(count - 1, 0) * PER_SHEET
	if height > 0.0:
		var box := BoxMesh.new()
		box.size = Vector3(SHEET.x, height, SHEET.z)
		box.material = pile.get_meta("paper")
		pile.mesh = MetreUV.chart(box)
		pile.position = Vector3(0, height * 0.5, 0)
	else:
		pile.mesh = null
	top.visible = count > 0
	_pose()
	card_board.basis = Basis.looking_at(-toward(), Vector3.UP)
	card_board.position = Vector3(0, CARD.y * 0.5, 0) + toward() * -(SHEET.z * 0.5 + 0.02)


func _process(delta: float) -> void:
	if not _held and _slide > 0.0:
		_slide = maxf(_slide - RETURN_SPEED * delta, 0.0)
		_pose()
	_poll -= delta
	if _poll <= 0.0 and not _held:
		_poll = 1.0
		_refresh()
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			notice.text = ""
