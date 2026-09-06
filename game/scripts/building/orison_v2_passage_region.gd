class_name OrisonV2PassageRegion
extends Node3D
## Authored arcade cells registered at the same front-door origin as V2.
## Geometry streams at interior boundaries; physical actors and shop authority
## retain their identities while the imported geometry is dormant.

const Surface := preload("res://scripts/building/surface_pass.gd")
const Finish := preload("res://scripts/building/passage_finish_pass.gd")
const Residency := preload("res://scripts/building/orison_v2_passage_residency.gd")
const CELLS := ["passage", "shop_model_laundry", "shop_shoe_rebuilding",
	"shop_keys_cut", "shop_hardware_paint", "shop_funeral_parlour",
	"shop_photo_supplies", "shop_radio_service", "shop_pawnbroker",
	"shop_news_cigars", "shop_otis_son", "shop_luncheonette"]

var startup_failed := false
var shop_service: MaintenanceShopService
var source_layout: Dictionary
var cell_nodes: Dictionary = {}
var doors: Dictionary = {}
var surface_pass: RefCounted
var finish: PassageFinishPass
var _signs: Array[ShopSignProp] = []
var _counter_ids: Array[String] = []
var _geometry_root: Node3D
var _actors: Node3D
var residency: Node

func configure(service: MaintenanceShopService) -> bool:
	if is_inside_tree() or service == null:
		return false
	shop_service = service
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	if decoded is not Dictionary:
		return false
	source_layout = decoded
	var entries: Array[Dictionary] = []
	for floor: Dictionary in source_layout.floors:
		if floor.id != "F01": continue
		for marker: Dictionary in floor.markers:
			if marker.id == "F01_DOOR_06": entries.append(marker)
	if entries.size() != 1 or float(entries[0].yaw_deg) != 0.0:
		return false
	var entry: Dictionary = entries[0]
	var center := GameBoot.b2g(entry.pos) + Vector3.RIGHT * float(entry.w) * 0.5
	position = -center
	return true

func _ready() -> void:
	if source_layout.is_empty() or shop_service == null:
		_fail("unconfigured Passage region")
		return
	if not _mount_scene("gateway", "res://assets/building/orison_v2/exterior/passage_gateway.gltf"):
		return
	_geometry_root = Node3D.new()
	_geometry_root.name = "ResidentGeometry"
	add_child(_geometry_root)
	for identity: String in CELLS:
		if not _mount_scene(identity, "res://assets/building/floor_01_cells/%s.gltf" % identity):
			return
	surface_pass = Surface.new()
	surface_pass.apply(cell_nodes)
	_actors = Node3D.new()
	_actors.name = "PassageActors"
	add_child(_actors)
	_mount_markers()
	finish = Finish.new()
	_actors.add_child(finish)
	finish.build(source_layout)
	for sign_prop: ShopSignProp in _signs:
		sign_prop.bind_hours_director(finish.hours_director)
	_mount_counters()
	add_to_group("orison_v2_passage_region")
	print("[V2 PASSAGE] ", cell_nodes.size(), " resident cells; ", doors.size(), " doors; ", _counter_ids.size(), " shared-service counters")

func _mount_scene(identity: String, path: String) -> bool:
	var packed := load(path) as PackedScene
	if packed == null:
		_fail("missing imported cell: " + identity)
		return false
	var cell := packed.instantiate() as Node3D
	if cell == null:
		_fail("non-spatial cell: " + identity)
		return false
	cell.name = identity
	if identity == "gateway": add_child(cell)
	else: _geometry_root.add_child(cell)
	cell_nodes[identity] = cell
	return true

func _mount_markers() -> void:
	for floor: Dictionary in source_layout.floors:
		if floor.id != "F01": continue
		for marker: Dictionary in floor.markers:
			var identity := str(marker.id)
			if str(marker.get("zone", "")) != "PASSAGE" and not identity.begins_with("PASSAGE_PORTAL_LT_"):
				continue
			var prop: Node3D
			if marker.kind == "door":
				var door := DoorProp.new()
				door.width = float(marker.w)
				door.height = float(marker.h)
				door.leaf_state = str(marker.leaf)
				door.swing_out = str(marker.get("swing", "")) == "out"
				door.door_kind = str(marker.get("subtype", "storefront"))
				door.unit = str(marker.get("unit", ""))
				door.finish_variant = int(marker.get("finish_variant", 0))
				doors[identity] = door
				prop = door
			elif marker.kind == "shop_sign":
				var sign_prop := ShopSignProp.new()
				sign_prop.prop_type = "shop_sign"
				sign_prop.sign_text = str(marker.get("text", "SHOP"))
				sign_prop.shop_name = str(marker.get("shop_name", sign_prop.sign_text))
				sign_prop.trade = str(marker.get("trade", ""))
				sign_prop.sub_text = str(marker.get("sub", ""))
				sign_prop.blade_text = str(marker.get("blade_text", ""))
				sign_prop.blade_dx = float(marker.get("blade_dx", 0.0))
				sign_prop.half_width = float(marker.get("half_width", 2.4))
				sign_prop.compact = bool(marker.get("compact", false))
				var tint: Array = marker.get("tint", [0.9, 0.86, 0.74])
				sign_prop.tint = Color(float(tint[0]), float(tint[1]), float(tint[2]))
				_signs.append(sign_prop)
				prop = sign_prop
			elif LightFixtureProp.TONE.has(str(marker.kind)):
				var fixture := LightFixtureProp.new()
				fixture.prop_type = str(marker.kind)
				fixture.range_clamp = float(marker.get("range", 0.0))
				fixture.energy_scale = float(marker.get("energy", 1.0))
				fixture.standby_scale = float(marker.get("standby", 0.0))
				fixture.navigation_light = bool(marker.get("navigation", false))
				# The nave is one tall room, regardless of the fixture's height.
				fixture.set_meta("vertical_zone", "PASSAGE")
				prop = fixture
			else:
				continue
			prop.name = identity
			prop.position = GameBoot.b2g(marker.pos)
			prop.rotation.y = deg_to_rad(-float(marker.get("yaw_deg", 0.0)))
			_actors.add_child(prop)

func _mount_counters() -> void:
	for item_id: String in shop_service.stock_ids():
		var record := shop_service.stock_record(item_id)
		var anchor_id := str(record.counter_anchor_id)
		var matches: Array[Dictionary] = []
		for floor: Dictionary in source_layout.floors:
			if floor.id != "F01": continue
			for furniture: Dictionary in floor.get("furniture", []):
				if str(furniture.id) == anchor_id: matches.append(furniture)
		if matches.size() != 1:
			_fail("ambiguous or absent counter anchor: " + anchor_id)
			return
		var anchor: Dictionary = matches[0]
		var rect: Array = anchor.rect
		var top := float(anchor.get("z0", 0.0)) + float(anchor.get("h", 0.0))
		var local_position := GameBoot.b2g([(float(rect[0])+float(rect[2]))*0.5,
			(float(rect[1])+float(rect[3]))*0.5, top+MaintenanceShopService.REACH_H*0.5])
		var size := Vector3(absf(float(rect[2])-float(rect[0])), MaintenanceShopService.REACH_H,
			absf(float(rect[3])-float(rect[1])))
		# Keep the production stock's explicit legacy transaction identity.
		# No duplicate inventory, implicit namespace conversion or free part.
		var identity := str(record.shop_id)
		if identity in _counter_ids: continue
		var counter := shop_service.mount_counter(identity, Transform3D(Basis.IDENTITY, to_global(local_position)), size, "hardware counter")
		if counter == null:
			_fail("counter mount refused: " + identity)
			return
		_counter_ids.append(identity)

func shutdown() -> void:
	if is_instance_valid(residency):
		residency.shutdown()
	if is_instance_valid(shop_service):
		for identity: String in _counter_ids:
			shop_service.unmount_counter(identity)
	_counter_ids.clear()
	for identity: String in doors:
		AudioPolicy.release_source(StringName(identity))
	doors.clear()
	_signs.clear()
	cell_nodes.clear()
	surface_pass = null
	shop_service = null

func enable_residency(player: PlayerController, frame: Node3D, layout: Dictionary) -> bool:
	if residency != null or startup_failed:
		return false
	residency = Residency.new()
	if not residency.configure(self, player, frame, layout):
		residency.free()
		residency = null
		return false
	add_child(residency)
	return true

func suspend_geometry() -> WeakRef:
	for identity: String in _counter_ids:
		shop_service.unmount_counter(identity)
	_counter_ids.clear()
	finish.hours_director.set_passage_active(false)
	for cart: PassagePushcart in finish.pushcarts:
		cart.set_passage_active(false)
	_actors.visible = false
	_actors.process_mode = Node.PROCESS_MODE_DISABLED
	var retired: WeakRef = weakref(_geometry_root)
	remove_child(_geometry_root)
	_geometry_root.queue_free()
	_geometry_root = null
	for identity: String in CELLS:
		cell_nodes.erase(identity)
	surface_pass = null
	return retired

func activate_geometry(geometry: Node3D, cells: Dictionary, surfaces: RefCounted) -> void:
	_geometry_root = geometry
	_geometry_root.name = "ResidentGeometry"
	add_child(_geometry_root)
	cell_nodes.merge(cells)
	surface_pass = surfaces
	_actors.process_mode = Node.PROCESS_MODE_INHERIT
	_actors.visible = true
	finish.hours_director.set_passage_active(true)
	finish.hours_director.apply_for_minute(ScheduleDirector.minute_now())
	for cart: PassagePushcart in finish.pushcarts:
		cart.set_passage_active(true)
	_mount_counters()

func _exit_tree() -> void:
	shutdown()

func _fail(reason: String) -> void:
	startup_failed = true
	push_error("V2 PASSAGE: " + reason)
