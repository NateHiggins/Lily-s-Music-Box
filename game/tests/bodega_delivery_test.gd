extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## Cam's dawn restock (cam_restock_run_20261124): every bodega delivery lands at
## 04:00, the stock calendar adds it then, and the handcart in the back alcove holds
## the load until the shelves are filled at 07:00. Real composed world and clock.
const Delivery := preload("res://scripts/building/orison_v2_bodega_delivery.gd")

func _init() -> void:
	route_label = "BODEGA DELIVERY"


func _route() -> void:
	var groups: Dictionary = world.shop_catalogue.shops.bodega.groups
	var at_four := true
	for group: String in groups:
		at_four = at_four and is_equal_approx(float(groups[group].delivery.at_minute), Delivery.DELIVERED)
	_require(groups.size() == 3 and at_four, "every bodega delivery lands at 04:00")
	# The calendar adds the icebox delivery on the 04:00 boundary and not before.
	var icebox: Dictionary = groups.icebox
	var day_start := 1440.0 * 10.0
	var before := ShopStock.advanced_units(10.0, icebox, day_start, day_start + 239.0)
	var after := ShopStock.advanced_units(10.0, icebox, day_start, day_start + 241.0)
	_require(after > before + float(icebox.delivery.units) * 0.9, "the icebox delivery arrives at 04:00: %.2f -> %.2f" % [before, after])
	var shop: Node3D = world.exterior_cell.instance_node("SHOP_BODEGA")
	var delivery: Node3D = shop.get_node_or_null("BodegaDeliveryLoad")
	if not _require(delivery != null and delivery.load_node.get_child_count() == 3, "the handcart load is mounted"):
		return
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for canvas: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		canvas.hide()
	var camera: Camera3D = world.player.camera
	camera.global_position = shop.to_global(Vector3(0.6, 1.6, -7.3))
	camera.look_at(shop.to_global(Vector3(-0.76, 0.55, -9.4)))
	camera.make_current()
	for target: float in [270.0, 480.0]:
		var clock: CampaignClock = world.campaign_clock
		var ahead := fposmod(target - clock.minute_of_day(), 1440.0)
		_require(clock.advance_to(clock.elapsed_minutes() + ahead), "the clock reaches %02d:%02d" % [floori(target / 60.0), floori(fmod(target, 60.0))])
		delivery.refresh()
		for frame in 20:
			await RenderingServer.frame_post_draw
		var loaded: bool = delivery.load_node.visible
		_require(loaded == Delivery.loaded_at(target) and loaded == (target < Delivery.UNPACKED),
				"at %02d:%02d the handcart is %s" % [floori(target / 60.0), floori(fmod(target, 60.0)), "loaded" if loaded else "empty"])
		await _capture_interaction("bodega_delivery_%04d" % int(target))
	# Produce thins through the day: full at dawn, thin by midday, sparse by night;
	# a thin pantry puts out a thinner display. No new nodes: visibility only.
	var Produce: Dictionary = Delivery.Produce
	_require(Delivery.produce_at(300.0, ShopStock.FULL) == Produce.FULL
			and Delivery.produce_at(720.0, ShopStock.FULL) == Produce.THIN
			and Delivery.produce_at(1200.0, ShopStock.FULL) == Produce.SPARSE
			and Delivery.produce_at(300.0, ShopStock.THIN) == Produce.THIN
			and Delivery.produce_at(120.0, ShopStock.FULL) == Produce.SPARSE,
			"the produce curve: full at 05:00, thin at 12:00, sparse at 20:00 and before dawn; a thin pantry starts thin")
	while world.shop_stock.level("bodega", "pantry") != ShopStock.FULL:
		world.shop_stock.put_back("bodega", "pantry")
	var aisle_1 := preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(shop, "stock_aisle_1_top_03")
	var aisle_2 := preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(shop, "stock_aisle_2_top_03")
	var window := preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(shop, "stock_right_window_baskets")
	if not _require(aisle_1 != null and aisle_2 != null and window != null, "the three produce displays are found"):
		return
	camera.global_position = shop.to_global(Vector3(0.0, 1.75, -2.6))
	camera.look_at(shop.to_global(Vector3(0.0, 1.0, -6.0)))
	var expected := {300.0: [true, true], 720.0: [true, false], 1200.0: [false, false]}
	for target: float in expected:
		var clock: CampaignClock = world.campaign_clock
		var ahead := fposmod(target - clock.minute_of_day(), 1440.0)
		clock.advance_to(clock.elapsed_minutes() + ahead)
		delivery.refresh()
		world.exterior_cell.refresh_shop_presentation()
		for frame in 10:
			await RenderingServer.frame_post_draw
		var want: Array = expected[target]
		_require(window.visible and aisle_1.visible == bool(want[0]) and aisle_2.visible == bool(want[1]),
				"at %02d:%02d the produce shows window %s, aisle one %s, aisle two %s" % [floori(target / 60.0), floori(fmod(target, 60.0)), window.visible, aisle_1.visible, aisle_2.visible])
		await _capture_interaction("bodega_produce_%04d" % int(target))
	# An empty pantry shows no produce, even while the icebox keeps the shop stocked.
	_require(Delivery.produce_at(300.0, ShopStock.OUT) == Produce.NONE, "an empty pantry puts out no produce")
	# Bring the stock cursor up to the jumped clock first, so no catch-up moves
	# these levels under the check.
	world.shop_stock.advance_to(world.campaign_clock.absolute_minutes(), world.shop_stock._today())
	var groups_state: Dictionary = RealityState.data[ShopStock.KEY].groups.bodega
	var kept_pantry := float(groups_state.pantry)
	while world.shop_stock.level("bodega", "icebox") == ShopStock.OUT:
		world.shop_stock.put_back("bodega", "icebox")
	groups_state.pantry = 0.0
	var other := preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(shop, "stock_aisle_1_top_01")
	delivery.refresh()
	world.exterior_cell.refresh_shop_presentation()
	print("[DELIVERY] pantry ", world.shop_stock.level("bodega", "pantry"), " icebox ", world.shop_stock.level("bodega", "icebox"), " notions ", world.shop_stock.level("bodega", "notions"))
	_require(world.shop_stock.level("bodega", "pantry") == ShopStock.OUT and world.shop_stock.level("bodega", "icebox") != ShopStock.OUT
			and not window.visible and not aisle_1.visible and not aisle_2.visible and other != null and other.visible,
			"pantry out, icebox stocked: no produce shows (window %s, aisles %s/%s) and other stock stays (%s)" % [window.visible, aisle_1.visible, aisle_2.visible, other.visible if other != null else "missing"])
	for frame in 10:
		await RenderingServer.frame_post_draw
	await _capture_interaction("bodega_produce_pantry_out")
	groups_state.pantry = kept_pantry
	delivery.refresh()
	world.exterior_cell.refresh_shop_presentation()
	_require(delivery.get_child_count() >= 2 and delivery.find_children("*", "Timer", false, false).size() == 1
			and not delivery.is_processing() and not delivery.is_physics_processing(),
			"the load is polled by a slow timer, not every frame")
