extends Node3D
## A shop's counter: the settlement terminal, a selector slide that walks the
## shop's list one stop at a time, and a printed card. The hand moves the selector
## to a stop and then strokes the lever, as at the hardware counter, and the stroke
## and its refusals are radio_sale_terminal's. Placement belongs to the shop's owner.

signal sold(item_id: String)

const Terminal := preload("res://scripts/props/radio_sale_terminal.gd")
const Library := preload("res://scripts/props/fire_maintenance_stock_library.gd")
const Manipulation := preload("res://scripts/props/manipulation_area.gd")
const FONT := preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
const FLAGS := {"paid": "SETTLED", "no_carrier": "NO CARRIER", "insufficient_funds": "NO CREDIT",
	"out_of_stock": "NONE LEFT", "case_full": "CASE FULL", "no_coupon": "NO COUPON", "already_posted": "ALREADY POSTED", "save_unavailable": "RECORD FAULT",
	"terminal_unavailable": "LINE CLOSED"}
const SELECTOR_TRAVEL := 0.10
const SELECTOR_AT := Vector3(-0.26, 0.0, 0.0)
const PIXELS_PER_STOP := 16.0
const MIN_GESTURE_PIXELS := 120.0

var sales: ShopSales
var item_ids: Array[String] = []
var selected := 0
var terminal: Node3D
var selector: Node3D
var flag: Label3D
var _price: Label3D
var _product: Label3D
var _selector_held := false
var _selector_travel := 0.0
var _quoted := {}


func configure(shop_sales: ShopSales, identities: Array[String]) -> bool:
	var stock := Library.new()
	if shop_sales == null or identities.is_empty() or not stock.load_stock():
		return false
	for identity in identities:
		if shop_sales.stock_record(identity).is_empty():
			return false
	sales = shop_sales
	item_ids = identities
	terminal = Terminal.new()
	terminal.name = "RadioSale"
	add_child(terminal)
	var housing := StaticBody3D.new()
	housing.name = "TerminalHousing"
	terminal.add_child(housing)
	for key: String in ["TerminalShell", "TerminalMetal"]:
		var draw: MeshInstance3D = stock.draw(housing, key)
		var collision := CollisionShape3D.new()
		collision.shape = draw.mesh.create_trimesh_shape()
		housing.add_child(collision)
	var lever := Node3D.new()
	lever.name = "SettlementLever"
	terminal.add_child(lever)
	stock.draw(lever, "TerminalLever")
	if not terminal.configure(sales, item_ids[0], lever):
		return false
	terminal.sale_result.connect(_on_sale)
	selector = Node3D.new()
	selector.name = "Selector"
	selector.position = SELECTOR_AT
	add_child(selector)
	stock.draw(selector, "TerminalLever")
	Manipulation.install(selector, _selector_grip)
	_letter(terminal, "Merchant", "QUEENS MUTUAL", Vector3(0, .056, -.038), .0065, true)
	_price = _letter(terminal, "Price", "", Vector3(0, .035, -.038), .0075, true)
	flag = _letter(terminal, "Status", "", Vector3(0, .022, -.038), .0042, true)
	# Readable from where a customer stands. Its own card is still to be modelled.
	_product = _letter(terminal, "Product", "", Vector3(0, .125, -.03), .016, false)
	_product.outline_size = 8
	_product.outline_modulate = Color(.04, .025, .015)
	_show_selection()
	return true


func _letter(parent: Node3D, label: String, text: String, at: Vector3, em: float, dark: bool) -> Label3D:
	var result := Label3D.new()
	result.name = label
	result.text = text
	result.font = FONT
	result.font_size = 40
	result.pixel_size = em / 40.0
	result.position = at
	result.rotation.y = PI
	result.outline_size = 0
	result.modulate = Color(.055, .035, .02) if dark else Color(.84, .8, .68)
	result.double_sided = false
	result.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	parent.add_child(result)
	return result


func _selector_grip() -> Dictionary:
	if selector == null or item_ids.size() < 2:
		return {}
	return {"owner": self, "part": selector, "frame": self, "kind": "slide", "axis": Vector3.RIGHT,
		"minimum": 0.0, "maximum": SELECTOR_TRAVEL,
		"gesture_travel_px": maxf(MIN_GESTURE_PIXELS, PIXELS_PER_STOP * item_ids.size()),
		"gesture_screen_axis": Vector2.LEFT,
		"read": func(): return _selector_travel,
		"write": func(value: float): _move_selector(value),
		"begin": func():
			if _selector_held:
				return false
			refresh_list()
			_selector_held = true
			return true,
		"owns": func(): return _selector_held,
		"end": func():
			_selector_held = false
			_seat_selector()}


func _stop_travel(index: int) -> float:
	return SELECTOR_TRAVEL * float(index) / float(maxi(1, item_ids.size() - 1))


func _move_selector(value: float) -> void:
	if not is_finite(value):
		return
	_selector_travel = clampf(value, 0.0, SELECTOR_TRAVEL)
	selector.position = SELECTOR_AT + Vector3.RIGHT * _selector_travel
	var index := roundi(_selector_travel / SELECTOR_TRAVEL * float(item_ids.size() - 1))
	if index != selected:
		select(index)


## The slide comes to rest on the stop it is nearest.
func _seat_selector() -> void:
	_selector_travel = _stop_travel(selected)
	selector.position = SELECTOR_AT + Vector3.RIGHT * _selector_travel


func select(index: int) -> void:
	selected = clampi(index, 0, item_ids.size() - 1)
	flag.text = ""
	_show_selection()


## A shop whose list changes, like a pawn shelf, asks for this after any change.
func refresh_list() -> void:
	var current := selected_item()
	item_ids = sales.listing()
	selected = maxi(0, item_ids.find(current))
	flag.text = ""
	_show_selection()
	_seat_selector()


func selected_item() -> String:
	return item_ids[selected]


func _show_selection() -> void:
	terminal.item_id = selected_item()
	var record := sales.stock_record(selected_item())
	# A pawn ticket ends with its own sale, so the slip reads this copy of the quote.
	_quoted = record
	_price.text = "%d CENTS" % int(record.price_cents)
	_product.text = str(record.display_name)


func _on_sale(accepted: bool) -> void:
	flag.text = FLAGS.get(terminal.last_status, "REFUSED")
	var player := get_tree().get_first_node_in_group("player_controller") as PlayerController
	if player != null:
		player.present_service_note(terminal, {"title": "QUEENS MUTUAL / SETTLEMENT",
			"body": "%s / %d CENTS" % [str(_quoted.display_name).to_upper(), int(_quoted.price_cents)],
			"condition": flag.text, "stamp": "COUNTER COPY"})
	if accepted:
		sold.emit(selected_item())
		var kept_flag := flag.text
		refresh_list()
		flag.text = kept_flag
