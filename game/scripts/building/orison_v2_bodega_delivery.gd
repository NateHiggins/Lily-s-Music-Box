extends Node3D
## The bodega's day, shown: the morning's delivery on the back-alcove handcart, and
## the produce on display thinning as it sells.
##
## The morning's delivery on the bodega's handcart in the back alcove. Lily's ruling
## cam_restock_run_20261124: Cam brings the day's delivery by handcart at dawn and
## every delivery lands at 04:00 (on the Triangle fire date a carter brings it
## unseen). The load stands on the handcart from the delivery until the shop has
## unpacked it. Presentation only: ShopStock keeps the units and the calendar, and
## this owner never changes them. A slow timer, not a per-frame poll.

## Minutes of the local day: the delivery lands, then the shelves are filled.
const DELIVERED := 240.0
const UNPACKED := 420.0
const POLL_SECONDS := 5.0
## Shop-local crates on the handcart bed (the authored base's top is at y 0.34).
const CRATES := [
	[Vector3(0.50, 0.30, 0.40), Vector3(-0.76, 0.49, -9.55)],
	[Vector3(0.48, 0.28, 0.38), Vector3(-0.76, 0.48, -9.12)],
	[Vector3(0.44, 0.24, 0.36), Vector3(-0.76, 0.76, -9.56)],
]
const MetreUV := preload("res://scripts/building/v2_metre_box_uv.gd")
## Produce goes out with the 04:00 delivery and sells through to 22:00. The shop
## proposal (section 5): "Produce thins out through the day." Three states, no new
## nodes: an aisle crate sells through, then the other, and the window baskets last.
const SELLING_UNTIL := 1320.0
const PRODUCE_THIN := ["stock_aisle_2_top_03"]
const PRODUCE_SPARSE := ["stock_aisle_2_top_03", "stock_aisle_1_top_03"]
enum Produce { FULL, THIN, SPARSE }

var load_node: Node3D
var _clock := CampaignClock.new()
var _timer: Timer
var _exterior: Node
var _stock: ShopStock
var produce := Produce.FULL


static func loaded_at(minute_of_day: float) -> bool:
	return minute_of_day >= DELIVERED and minute_of_day < UNPACKED


## How much of the day's produce is left: time since it went out, scaled by the
## pantry's real level (a thin pantry puts out a thin display).
static func produce_at(minute_of_day: float, pantry_level: String) -> int:
	var selling := SELLING_UNTIL - DELIVERED
	var since := fposmod(minute_of_day - DELIVERED, 1440.0)
	var left := clampf(1.0 - since / selling, 0.15, 1.0)
	if pantry_level == ShopStock.THIN:
		left *= 0.6
	if left >= 0.66:
		return Produce.FULL
	if left >= 0.33:
		return Produce.THIN
	return Produce.SPARSE


## The runtime root binds the real exterior refresh and stock once they exist.
func bind_display(exterior: Node, stock: ShopStock) -> void:
	_exterior = exterior
	_stock = stock
	refresh()
	if is_instance_valid(_exterior) and _exterior.get("stock_visual_filter") is Callable:
		_exterior.set("stock_visual_filter", produce_shown)
		_exterior.call("refresh_shop_presentation")


func produce_shown(shop_id: String, record_id: String) -> bool:
	if not shop_id.contains("BODEGA"):
		return true
	var hidden: Array = []
	if produce == Produce.THIN:
		hidden = PRODUCE_THIN
	elif produce == Produce.SPARSE:
		hidden = PRODUCE_SPARSE
	return record_id not in hidden


func _ready() -> void:
	load_node = Node3D.new()
	load_node.name = "DeliveryLoad"
	add_child(load_node)
	var timber := MatLib.get_mat("timber").duplicate() as StandardMaterial3D
	timber.uv1_triplanar = false
	timber.uv1_scale = Vector3.ONE / float(MatLib.SETS["timber"][3])
	for row: Array in CRATES:
		var box := BoxMesh.new()
		box.size = row[0]
		var draw := MeshInstance3D.new()
		draw.name = "Crate"
		draw.mesh = MetreUV.chart(box)
		draw.material_override = timber
		draw.position = row[1]
		load_node.add_child(draw)
	_timer = Timer.new()
	_timer.wait_time = POLL_SECONDS
	_timer.autostart = true
	_timer.timeout.connect(refresh)
	add_child(_timer)
	refresh()


func refresh() -> void:
	if load_node == null:
		return
	var bound := _clock.bind_state()
	load_node.visible = bound and loaded_at(_clock.minute_of_day())
	if not bound or _stock == null:
		return
	var state := produce_at(_clock.minute_of_day(), _stock.level("bodega", "pantry"))
	if state != produce:
		produce = state
		if is_instance_valid(_exterior):
			_exterior.call("refresh_shop_presentation")
