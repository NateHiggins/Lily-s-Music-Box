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
	_require(delivery.get_child_count() >= 2 and delivery.find_children("*", "Timer", false, false).size() == 1
			and not delivery.is_processing() and not delivery.is_physics_processing(),
			"the load is polled by a slow timer, not every frame")
