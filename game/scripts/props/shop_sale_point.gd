extends Node3D
## One item on a shop counter: the settlement terminal with its lever, printed
## card and status flag. The stroke is radio_sale_terminal's, so the hand and the
## refusals match the hardware counter. Placement belongs to the shop's owner.

signal sold(item_id: String)

const Terminal := preload("res://scripts/props/radio_sale_terminal.gd")
const Library := preload("res://scripts/props/fire_maintenance_stock_library.gd")
const FONT := preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
const FLAGS := {"paid": "SETTLED", "no_carrier": "NO CARRIER", "insufficient_funds": "NO CREDIT",
	"out_of_stock": "NONE LEFT", "case_full": "CASE FULL", "save_unavailable": "RECORD FAULT",
	"terminal_unavailable": "LINE CLOSED"}

var sales: ShopSales
var item_id := ""
var terminal: Node3D
var flag: Label3D


func configure(shop_sales: ShopSales, identity: String) -> bool:
	var record := shop_sales.stock_record(identity) if shop_sales != null else {}
	var stock := Library.new()
	if record.is_empty() or not stock.load_stock():
		return false
	sales = shop_sales
	item_id = identity
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
	if not terminal.configure(sales, identity, lever):
		return false
	terminal.sale_result.connect(_on_sale)
	_letter("Merchant", "QUEENS MUTUAL", Vector3(0, .056, -.038), .0065, true)
	_letter("Price", "%d CENTS" % int(record.price_cents), Vector3(0, .035, -.038), .0075, true)
	flag = _letter("Status", "", Vector3(0, .022, -.038), .0042, true)
	_letter("Product", str(record.display_name), Vector3(0, .014, -.074), .003, false)
	return true


func _letter(label: String, text: String, at: Vector3, em: float, dark: bool) -> Label3D:
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
	terminal.add_child(result)
	return result


func _on_sale(accepted: bool) -> void:
	flag.text = FLAGS.get(terminal.last_status, "REFUSED")
	var player := get_tree().get_first_node_in_group("player_controller") as PlayerController
	if player != null:
		var record := sales.stock_record(item_id)
		player.present_service_note(terminal, {"title": "QUEENS MUTUAL / SETTLEMENT",
			"body": "%s / %d CENTS" % [str(record.display_name).to_upper(), int(record.price_cents)],
			"condition": flag.text, "stamp": "COUNTER COPY"})
	if accepted:
		sold.emit(item_id)
