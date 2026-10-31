extends RefCounted
## Puts the shared sale point on each shop's real counter. Hardware keeps its fire
## and capsule kit at the south end, so this one takes the clear run north of the
## ledger. News keeps its rack and takes the strip along the customer edge of its top. The Bodega's point
## sits on the counter its service already owns.

const SalePoint := preload("res://scripts/props/shop_sale_point.gd")
## The terminal's lettering faces local -Z, toward whoever is buying.
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
	var pawn := _row(passage, PAWN_ROW)
	if pawn.is_empty():
		return {}
	var pawn_top := float(pawn.z0) + float(pawn.h)
	points["pawnbroker"] = _place(world, "pawnbroker", passage.transaction_actor_root(),
			passage.global_transform * Transform3D(Basis(Vector3.UP, PI * 0.5),
			GameBoot.b2g([PAWN_ACROSS, PAWN_ALONG, pawn_top])))
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


static func _row(passage: Node3D, identity: String) -> Dictionary:
	for floor: Dictionary in passage.source_layout.floors:
		if str(floor.id) != "F01":
			continue
		for row: Dictionary in floor.furniture:
			if str(row.id) == identity:
				return row
	return {}


static func _place(world: Node3D, shop_id: String, parent: Node3D, at: Transform3D) -> Node3D:
	var point: Node3D = SalePoint.new()
	point.name = "ShopSalePoint_" + shop_id
	parent.add_child(point)
	point.global_transform = at
	var sales: ShopSales
	if shop_id == "pawnbroker":
		sales = PawnSales.new(world.shop_catalogue, world.shop_stock, world.shop_clearing, world.get_node("CaretakerEconomy"))
	else:
		sales = ShopSales.new(shop_id, world.shop_catalogue, world.shop_stock, world.shop_clearing)
	if not point.configure(sales, sales.listing()):
		point.free()
		return null
	return point
