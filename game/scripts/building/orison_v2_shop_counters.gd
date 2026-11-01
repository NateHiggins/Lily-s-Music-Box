extends RefCounted
## Puts the shared sale point on each shop's real counter. Hardware keeps its fire
## and capsule kit at the south end, so this one takes the clear run north of the
## ledger. News keeps its rack and takes the strip along the customer edge of its top. The Bodega's point
## sits on the counter its service already owns.

const SalePoint := preload("res://scripts/props/shop_sale_point.gd")
## The terminal's lettering faces local -Z, toward whoever is buying.
const KEYS_ROW := "storm_shop_keys_cut_counter_top"
const PHOTO_ROW := "storm_shop_photo_supplies_counter_top"
const PHOTO_ALONG := -60.75
const CUTTER_ROW := "storm_shop_keys_cut_cutter_vise0"
const KEYS_ALONG := -51.1
const PAWN_ROW := "storm_shop_pawnbroker_grille_top"
## On the customer side of the grille, clear of the ledger and balance.
const PAWN_ACROSS := 21.3
const PAWN_ALONG := -54.2
## Metres along the counter's length, clear of what stands there already.
const HARDWARE_ROW := "storm_shop_hardware_paint_counter_top"
const HARDWARE_ALONG := -55.75
const NEWS_ROW := "storm_shop_news_cigars_counter_top"
## The news top is full across its depth except the customer-side strip.
const NEWS_ALONG := 18.45
const NEWS_ACROSS := -49.47
const BODEGA_INSET := Vector3(0.35, 0.0, 0.1)
const OTIS_ROW := "storm_shop_otis___son_counter_top"
## Clear of the telephone and ledger at the counter's other end.
const OTIS_ACROSS := 21.2
const OTIS_ALONG := -47.95
const OTIS_FOUNTAIN_ROW := "storm_shop_otis___son_fount_top"
## The stool side of the marble, past the three taps.
const OTIS_FOUNTAIN_ACROSS := 20.85
const OTIS_FOUNTAIN_ALONG := -45.25
## The empty cup waits on the first catch tray, under the first nozzle.
const OTIS_CUP := [19.805, -45.055, 1.105]
const LUNCHEONETTE_ROW := "storm_shop_luncheonette_counter_top"
## The customer edge of the top, down the far end from the register and ledger.
const LUNCHEONETTE_ACROSS := 19.05
const LUNCHEONETTE_ALONG := -42.58
const LUNCHEONETTE_SERVED_ALONG := -43.05


static func mount(world: Node3D) -> Dictionary:
	var points := {}
	var passage: Node3D = world.passage_region
	var hardware := _row(passage, HARDWARE_ROW)
	var news := _row(passage, NEWS_ROW)
	if hardware.is_empty() or news.is_empty():
		return {}
	var hardware_top := float(hardware.z0) + float(hardware.h)
	var hardware_x := (float(hardware.rect[0]) + float(hardware.rect[2])) * 0.5
	points["hardware_paint"] = _place(world, "hardware_paint", passage.transaction_actor_root(),
			passage.global_transform * Transform3D(Basis(Vector3.UP, PI * 0.5),
			GameBoot.b2g([hardware_x, HARDWARE_ALONG, hardware_top])))
	var news_top := float(news.z0) + float(news.h)
	points["news_cigars"] = _place(world, "news_cigars", passage.transaction_actor_root(),
			passage.global_transform * Transform3D(Basis(Vector3.UP, PI), GameBoot.b2g([NEWS_ALONG, NEWS_ACROSS, news_top])))
	var keys := _row(passage, KEYS_ROW)
	if keys.is_empty():
		return {}
	var keys_top := float(keys.z0) + float(keys.h)
	var keys_x := (float(keys.rect[0]) + float(keys.rect[2])) * 0.5
	points["keys_cut"] = _place(world, "keys_cut", passage.transaction_actor_root(),
			passage.global_transform * Transform3D(Basis(Vector3.UP, PI * 0.5),
			GameBoot.b2g([keys_x, KEYS_ALONG, keys_top])))
	var pawn := _row(passage, PAWN_ROW)
	if pawn.is_empty():
		return {}
	var pawn_top := float(pawn.z0) + float(pawn.h)
	points["pawnbroker"] = _place(world, "pawnbroker", passage.transaction_actor_root(),
			passage.global_transform * Transform3D(Basis(Vector3.UP, PI * 0.5),
			GameBoot.b2g([PAWN_ACROSS, PAWN_ALONG, pawn_top])))
	var photo := _row(passage, PHOTO_ROW)
	if photo.is_empty():
		return {}
	var photo_top := float(photo.z0) + float(photo.h)
	points["photo_supplies"] = _place(world, "photo_supplies", passage.transaction_actor_root(),
			passage.global_transform * Transform3D(Basis(Vector3.UP, -PI * 0.5),
			GameBoot.b2g([18.42, PHOTO_ALONG, photo_top])))
	var otis := _row(passage, OTIS_ROW)
	var otis_fount := _row(passage, OTIS_FOUNTAIN_ROW)
	if otis.is_empty() or otis_fount.is_empty():
		return {}
	points["otis_son"] = _place(world, "otis_son", passage.transaction_actor_root(),
			passage.global_transform * Transform3D(Basis.IDENTITY,
			GameBoot.b2g([OTIS_ACROSS, OTIS_ALONG, float(otis.z0) + float(otis.h)])), [], ["fountain"])
	points["otis_fountain"] = _place(world, "otis_son", passage.transaction_actor_root(),
			passage.global_transform * Transform3D(Basis(Vector3.UP, PI),
			GameBoot.b2g([OTIS_FOUNTAIN_ACROSS, OTIS_FOUNTAIN_ALONG, float(otis_fount.z0) + float(otis_fount.h)])), ["fountain"], [], "ShopSalePoint_otis_fountain")
	var luncheonette := _row(passage, LUNCHEONETTE_ROW)
	if luncheonette.is_empty():
		return {}
	var luncheonette_top := float(luncheonette.z0) + float(luncheonette.h)
	points["luncheonette"] = _place(world, "luncheonette", passage.transaction_actor_root(),
			passage.global_transform * Transform3D(Basis(Vector3.UP, PI * 0.5),
			GameBoot.b2g([LUNCHEONETTE_ACROSS, LUNCHEONETTE_ALONG, luncheonette_top])))
	var bodega_counter: Node3D = world.exterior_cell.service_counter("SHOP_BODEGA")
	if bodega_counter != null:
		# The service area's origin sits on the shop-side edge of the counter top.
		var turned := bodega_counter.global_basis * Basis(Vector3.UP, -PI * 0.5)
		points["bodega"] = _place(world, "bodega", world, Transform3D(turned,
				bodega_counter.global_position + bodega_counter.global_basis * BODEGA_INSET))
	for shop_id: String in points:
		if points[shop_id] == null:
			return {}
	return points


## The carriage stands on the cutter's vises, worked from the shop floor side.
static func mount_cutter(world: Node3D) -> Node3D:
	var passage: Node3D = world.passage_region
	var vise := _row(passage, CUTTER_ROW)
	if vise.is_empty():
		return null
	var cutter: Node3D = preload("res://scripts/props/key_cutter_carriage.gd").new()
	cutter.name = "KeyCutterCarriage"
	passage.transaction_actor_root().add_child(cutter)
	var top := float(vise.z0) + float(vise.h)
	var at: Vector3 = GameBoot.b2g([(float(vise.rect[0]) + float(vise.rect[2])) * 0.5 - 0.06, -51.0, top])
	cutter.global_transform = passage.global_transform * Transform3D(Basis(Vector3.UP, PI), at)
	if not cutter.configure(passage.finish.hours_director):
		cutter.free()
		return null
	return cutter


## What was ordered comes up beside the sale point, in reach from behind the stools.
static func mount_luncheonette(world: Node3D) -> Node3D:
	var passage: Node3D = world.passage_region
	var top := _row(passage, LUNCHEONETTE_ROW)
	var counter: Node3D = preload("res://scripts/props/luncheonette_counter.gd").new()
	counter.name = "LuncheonetteCounter"
	passage.transaction_actor_root().add_child(counter)
	counter.global_transform = passage.global_transform * Transform3D(Basis.IDENTITY,
			GameBoot.b2g([LUNCHEONETTE_ACROSS, LUNCHEONETTE_SERVED_ALONG, float(top.z0) + float(top.h)]))
	if not counter.configure(world, world.shop_counters.luncheonette, world.conversations):
		counter.free()
		return null
	return counter


static func mount_otis_fountain(world: Node3D) -> Node3D:
	var passage: Node3D = world.passage_region
	var fountain: Node3D = preload("res://scripts/props/otis_fountain.gd").new()
	fountain.name = "OtisFountain"
	passage.transaction_actor_root().add_child(fountain)
	fountain.global_transform = passage.global_transform * Transform3D(Basis.IDENTITY, GameBoot.b2g(OTIS_CUP))
	if not fountain.configure(world, world.shop_counters.otis_fountain):
		fountain.free()
		return null
	return fountain


static func _row(passage: Node3D, identity: String) -> Dictionary:
	for floor: Dictionary in passage.source_layout.floors:
		if str(floor.id) != "F01":
			continue
		for row: Dictionary in floor.furniture:
			if str(row.id) == identity:
				return row
	return {}


static func _place(world: Node3D, shop_id: String, parent: Node3D, at: Transform3D, only: Array[String] = [], skip: Array[String] = [], point_name := "") -> Node3D:
	var point: Node3D = SalePoint.new()
	point.name = point_name if point_name != "" else "ShopSalePoint_" + shop_id
	parent.add_child(point)
	point.global_transform = at
	var sales: ShopSales
	if shop_id == "keys_cut":
		sales = KeysSales.new(shop_id, world.shop_catalogue, world.shop_stock, world.shop_clearing)
	elif shop_id == "photo_supplies":
		sales = PhotoSales.new(shop_id, world.shop_catalogue, world.shop_stock, world.shop_clearing)
	elif shop_id == "pawnbroker":
		sales = PawnSales.new(world.shop_catalogue, world.shop_stock, world.shop_clearing, world.get_node("CaretakerEconomy"))
	else:
		sales = ShopSales.new(shop_id, world.shop_catalogue, world.shop_stock, world.shop_clearing)
	sales.only_groups = only
	sales.skip_groups = skip
	if not point.configure(sales, sales.listing()):
		point.free()
		return null
	return point
