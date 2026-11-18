class_name OrisonV2PassageRegion
extends Node3D
## Authored arcade cells registered at the same front-door origin as V2.
## Geometry streams at interior boundaries; physical actors and shop authority
## retain their identities while the imported geometry is dormant.

const Prepared := preload("res://scripts/building/orison_v2_arcade_prepared_geometry.gd")
const Surface := preload("res://scripts/building/surface_pass.gd")
const Finish := preload("res://scripts/building/passage_finish_pass.gd")
const Residency := preload("res://scripts/building/orison_v2_passage_residency.gd")
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
const ArcadeFabric := preload("res://scripts/building/orison_v2_arcade_fabric.gd")
const Laundry := preload("res://scripts/building/orison_v2_laundry_fittings.gd")
const LaundryApparatus := preload("res://scripts/building/orison_v2_laundry_apparatus.gd")
const ShopClerestories := preload("res://scripts/building/orison_v2_shop_clerestories.gd")
const PhotoRadioFittings := preload("res://scripts/building/orison_v2_photo_radio_fittings.gd")
const PhotoDarkroomLight := preload("res://scripts/props/photo_darkroom_light.gd")
const ShopJoinery := preload("res://scripts/building/orison_v2_shop_joinery.gd")
const LaundryTrade := preload("res://scripts/building/orison_v2_laundry_trade.gd")
const CobblerFittings := preload("res://scripts/building/orison_v2_cobbler_fittings.gd")
const NewsFittings := preload("res://scripts/building/orison_v2_news_fittings.gd")
const HardwareDrawers := preload("res://scripts/building/orison_v2_hardware_drawers.gd")
const HardwareTools := preload("res://scripts/building/orison_v2_hardware_tools.gd")
const PhotoCameras := preload("res://scripts/building/orison_v2_photo_cameras.gd")
const PhotoProcess := preload("res://scripts/building/orison_v2_photo_process.gd")
const PhotoPortraits := preload("res://scripts/building/orison_v2_photo_portraits.gd")
const PhotoGlazing := preload("res://scripts/building/orison_v2_photo_glazing.gd")
const DruggistDrawers := preload("res://scripts/building/orison_v2_druggist_drawers.gd")
const DruggistCounter := preload("res://scripts/building/orison_v2_druggist_counter.gd")
const DruggistMortar := preload("res://scripts/building/orison_v2_druggist_mortar.gd")
const DruggistDispensary := preload("res://scripts/building/orison_v2_druggist_dispensary.gd")
const DruggistCupboard := preload("res://scripts/building/orison_v2_druggist_cupboard.gd")
const DruggistCarboys := preload("res://scripts/building/orison_v2_druggist_carboys.gd")
const DruggistFountain := preload("res://scripts/building/orison_v2_druggist_fountain.gd")
const FuneralFittings := preload("res://scripts/building/orison_v2_funeral_fittings.gd")
const FuneralDrapes := preload("res://scripts/building/orison_v2_funeral_drapes.gd")
const FuneralFoliage := preload("res://scripts/building/orison_v2_funeral_foliage.gd")
const RadioBench := preload("res://scripts/building/orison_v2_radio_bench.gd")
const RadioApparatus := preload("res://scripts/building/orison_v2_radio_apparatus.gd")
const RadioStock := preload("res://scripts/building/orison_v2_radio_stock.gd")
const RadioBattery := preload("res://scripts/building/orison_v2_radio_battery.gd")
const RadioWire := preload("res://scripts/building/orison_v2_radio_wire.gd")
const RadioDisplay := preload("res://scripts/building/orison_v2_radio_display.gd")
const RadioReceiving := preload("res://scripts/building/orison_v2_radio_receiving.gd")
const LaundryReceiving := preload("res://scripts/building/orison_v2_laundry_receiving.gd")
const PhotoReceiving := preload("res://scripts/building/orison_v2_photo_receiving.gd")
const NewsReceiving := preload("res://scripts/building/orison_v2_news_receiving.gd")
const PawnReceiving := preload("res://scripts/building/orison_v2_pawn_receiving.gd")
const PawnClocks := preload("res://scripts/building/orison_v2_pawn_clocks.gd")
const PawnFittings := preload("res://scripts/building/orison_v2_pawn_fittings.gd")
const PawnDisplay := preload("res://scripts/building/orison_v2_pawn_display.gd")
const DinerReceiving := preload("res://scripts/building/orison_v2_diner_receiving.gd")
const Receivers := preload("res://scripts/building/orison_v2_passage_receivers.gd")
const PhotoEnlargers := preload("res://scripts/building/orison_v2_photo_enlargers.gd")
const PhotoStock := preload("res://scripts/building/orison_v2_photo_stock.gd")
const DinerCounter := preload("res://scripts/building/orison_v2_diner_counter.gd")
const DinerTill := preload("res://scripts/building/orison_v2_diner_till.gd")
const DinerBackbar := preload("res://scripts/building/orison_v2_diner_backbar.gd")
const DinerUrns := preload("res://scripts/building/orison_v2_diner_urns.gd")
const DinerApparatus := preload("res://scripts/building/orison_v2_diner_apparatus.gd")
const DinerOverhead := preload("res://scripts/building/orison_v2_diner_overhead.gd")
const PhotoCounter := preload("res://scripts/building/orison_v2_photo_counter.gd")
const HardwareStock := preload("res://scripts/building/orison_v2_hardware_stock.gd")
const HardwareApparatus := preload("res://scripts/building/orison_v2_hardware_apparatus.gd")
const LocksmithFittings := preload("res://scripts/building/orison_v2_locksmith_fittings.gd")
const CELLS := ["passage", "shop_model_laundry", "shop_shoe_rebuilding",
	"shop_keys_cut", "shop_hardware_paint", "shop_funeral_parlour",
	"shop_photo_supplies", "shop_radio_service", "shop_pawnbroker",
	"shop_news_cigars", "shop_otis_son", "shop_luncheonette"]

var startup_failed := false
var started_from_bake := false
var shop_service: MaintenanceShopService
var source_layout: Dictionary
var _actor_layout: Dictionary
var _prepared_bundle: Dictionary
var _allow_baked_startup := false
var _native_fittings: Dictionary
var cell_nodes: Dictionary = {}
var doors: Dictionary = {}
var surface_pass: RefCounted
var finish: PassageFinishPass
var _signs: Array[ShopSignProp] = []
var _counter_ids: Array[String] = []
var _geometry_root: Node3D
var _actors: Node3D
var residency: Node
var portrait_atlas_cache := PhotoPortraits.AtlasCache.new()
var receiving_row: Receivers
## Temporarily absent by owner request. Read once so streaming keeps the same policy.
var cabinets_enabled := false
var _acoustic_originals: Dictionary = {}
var _residency_clients: Array[WeakRef] = []

func register_residency_client(client: Node) -> bool:
	if client==null or not client.has_method("wants_passage_geometry") \
			or not client.has_method("passage_geometry_dormant") or not client.has_method("passage_geometry_active"):return false
	for reference: WeakRef in _residency_clients:
		if reference.get_ref()==client:return true
	_residency_clients.append(weakref(client));return true

func geometry_required_by_stock() -> bool:
	for reference: WeakRef in _residency_clients:
		var client: Node=reference.get_ref()
		if client!=null and bool(client.wants_passage_geometry()):return true
	return false

func _notify_stock_residency(active: bool) -> void:
	for reference: WeakRef in _residency_clients:
		var client: Node=reference.get_ref()
		if client!=null:
			if active:client.passage_geometry_active()
			else:client.passage_geometry_dormant()

static func cell_path(identity: String) -> String:
	if identity == "passage":
		return "res://assets/building/orison_v2/passage/passage.gltf"
	return "res://assets/building/floor_01_cells/%s.gltf" % identity

func configure(service: MaintenanceShopService, programmes: Variant=null) -> bool:
	if is_inside_tree() or service == null:
		return false
	shop_service = service
	# Owner retired all arcade cabinets from play pending a complete revamp.
	# Historical opt-in fixtures cannot turn them back on in the live world.
	cabinets_enabled = false
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	if decoded is not Dictionary:
		return false
	source_layout = decoded
	if programmes==null:programmes=preload("res://scripts/building/orison_v2_public_region_programmes.gd").load_default()
	if programmes==null:return false
	var registered: Transform3D=programmes.body_transform("VantryArcade")
	if not registered.origin.is_finite():return false
	transform=registered
	return true

## Supply the frozen prepared sources before mounting the candidate region.
## The original selection remains active until routes and public fabric qualify.
func configure_prepared(bundle: Dictionary, allow_baked_startup := false) -> bool:
	if is_inside_tree() or bundle.is_empty() or bundle.get("placement") is not Dictionary \
		or bundle.placement.is_empty():
		return false
	_prepared_bundle = bundle.duplicate(true)
	_allow_baked_startup = allow_baked_startup
	return true

## A seat uses its admitted native draw, including offsets baked into the mesh.
func native_seat_socket(part_id: String) -> Dictionary:
	var fitting: Dictionary = _native_fittings.get(part_id,{})
	if fitting.is_empty(): return {}
	var model := shop_fitting(fitting.cell,fitting.model)
	if model == null: return {}
	var draw := model.get_node_or_null(NodePath(fitting.draw)) as MeshInstance3D
	if draw == null: return {}
	var box := draw.mesh.get_aabb()
	var top := Vector3(box.get_center().x,box.end.y,box.get_center().z)
	return {"cell":fitting.cell,"position":to_local(draw.to_global(top))}

func prepared_shop_contains(cell_id: String, position_in_world: Vector3) -> bool:
	if not uses_prepared_geometry(): return false
	var origin: Array = _prepared_bundle.shell.source_origin_blender_m
	var local := to_local(position_in_world)
	if local.y < -.15 or local.y >= 3.30: return false
	var plan_position := Vector2(local.x - float(origin[0]), local.z + float(origin[1]))
	for shop: Dictionary in _prepared_bundle.shell.shops:
		if shop.id != cell_id: continue
		var rect: Array = shop.rect_m
		return Rect2(rect[0],rect[1],rect[2]-rect[0],rect[3]-rect[1]).has_point(plan_position)
	return false

## Reuse the exact rigid relocation already checked on each native fitting.
func native_fixture_pose(part_id: String, original: Transform3D) -> Transform3D:
	var fitting: Dictionary = _native_fittings.get(part_id,{})
	if uses_prepared_geometry() and fitting.is_empty():
		_fail("missing prepared fixture support " + part_id)
	var move: Transform3D = fitting.get("move",Transform3D.IDENTITY)
	return global_transform * move * original

func shop_fitting(cell_id: String, model: String) -> Node3D:
	var cell := cell_nodes.get(cell_id) as Node3D
	if cell == null: return null
	return cell.get_node_or_null(NodePath(cell_id + "/" + model if uses_prepared_geometry() else model)) as Node3D

func uses_prepared_geometry() -> bool:
	return not _prepared_bundle.is_empty()

func begin_prepared_geometry() -> RefCounted:
	var build := Prepared.new()
	if not build.begin_build(source_layout,_prepared_bundle,portrait_atlas_cache):
		_fail("prepared arcade source refused: " + str(build.errors))
		return null
	return build

func _ready_prepared() -> void:
	var build := Prepared.new()
	var geometry: Node3D
	if _allow_baked_startup:
		var cell_order := ["passage"]
		cell_order.append_array(_prepared_bundle.shell.cells)
		geometry = Residency.BakedStream.load_initial(cell_order)
	var aisle_markers: Array[Dictionary] = []
	if geometry != null:
		aisle_markers = build.project_pendant_markers(source_layout)
		if aisle_markers.size() != 8:
			geometry.free()
			geometry = null
	started_from_bake = geometry != null
	if not started_from_bake:
		build = begin_prepared_geometry()
		if build == null: return
		var result: Error = build.advance_build()
		while result == ERR_BUSY:
			result = build.advance_build()
		if result != OK:
			_fail("prepared arcade fitting refused: " + str(build.errors))
			return
		geometry = build.take_build()
		aisle_markers = build.aisle_markers
	var frame := Prepared.Frame.new()
	for cell: Dictionary in _prepared_bundle.native:
		for part: Dictionary in cell.entries:
			_native_fittings[str(part.part_id)] = {"move":frame._matrix(part.delta_transform),
				"cell":str(cell.cell),"model":str(part.model),"draw":str(part.target_name)}
	var shops := {}
	for cell: Node3D in geometry.get_children():
		if cell.name != "passage": shops[str(cell.name)] = true
	var door_set: Dictionary = build.prepare_doors(source_layout,_prepared_bundle.frames,shops)
	if door_set.is_empty():
		geometry.free()
		_fail("prepared arcade doors refused: " + str(build.errors))
		return
	var placement: Dictionary = _prepared_bundle.placement.duplicate(true)
	var markers := {}
	for marker: Dictionary in aisle_markers:
		markers[str(marker.id)] = marker
	for floor: Dictionary in placement.floors:
		if floor.id != "F01": continue
		for i: int in floor.markers.size():
			var identity := str(floor.markers[i].id)
			if markers.has(identity): floor.markers[i] = markers[identity]
	_geometry_root = geometry
	add_child(_geometry_root)
	for cell: Node3D in geometry.get_children():
		cell_nodes[str(cell.name)] = cell
		preload("res://scripts/building/orison_v2_owner_finishes.gd").apply_shop_wear(cell)
	if not _mount_actors(placement,door_set): return
	add_to_group("orison_v2_passage_region")

func _ready() -> void:
	if source_layout.is_empty() or shop_service == null:
		_fail("unconfigured Passage region")
		return
	if not _mount_scene("gateway", "res://assets/building/orison_v2/exterior/passage_gateway.gltf"):
		return
	if uses_prepared_geometry():
		_ready_prepared()
		return
	_geometry_root = Node3D.new()
	_geometry_root.name = "ResidentGeometry"
	add_child(_geometry_root)
	for identity: String in CELLS:
		if not _mount_scene(identity, cell_path(identity)):
			return
	surface_pass = Surface.new()
	for identity: String in CELLS:
		if not Seating.mount_cell(cell_nodes[identity],source_layout):
			_fail("native seating fit refused: "+identity)
			return
		if not Laundry.mount_cell(cell_nodes[identity],source_layout):
			_fail("native laundry fit refused: "+identity)
			return
		if not LaundryApparatus.mount_cell(cell_nodes[identity],source_layout):
			_fail("native laundry apparatus fit refused: "+identity)
			return
		if not LaundryTrade.mount_cell(cell_nodes[identity],source_layout):
			_fail("native laundry trade furniture fit refused: "+identity)
			return
		if not ShopClerestories.mount_cell(cell_nodes[identity],source_layout):
			_fail("native borrowed-light fit refused: "+identity)
			return
		if not ShopJoinery.mount_cell(cell_nodes[identity],source_layout):
			_fail("native closed shop joinery fit refused: "+identity)
			return
		if not PhotoRadioFittings.mount_cell(cell_nodes[identity],source_layout):
			_fail("native Photo/Radio fit refused: "+identity)
			return
		if not LocksmithFittings.mount_cell(cell_nodes[identity],source_layout):
			_fail("native locksmith fit refused: "+identity)
			return
		if not CobblerFittings.mount_cell(cell_nodes[identity],source_layout):
			_fail("native cobbler fit refused: "+identity)
			return
		if not NewsFittings.mount_cell(cell_nodes[identity],source_layout):
			_fail("native news fit refused: "+identity)
			return
		if not HardwareDrawers.mount_cell(cell_nodes[identity],source_layout):
			_fail("native hardware drawer fit refused: "+identity)
			return
		if not HardwareApparatus.mount_cell(cell_nodes[identity],source_layout):
			_fail("native hardware apparatus fit refused: "+identity)
			return
		if not HardwareStock.mount_cell(cell_nodes[identity],source_layout):
			_fail("native hardware stock fit refused: "+identity)
			return
		if not HardwareTools.mount_cell(cell_nodes[identity],source_layout):
			_fail("native hardware tools fit refused: "+identity)
			return
		if not PhotoCameras.mount_cell(cell_nodes[identity],source_layout):
			_fail("native photography display fit refused: "+identity)
			return
		if not DinerCounter.mount_cell(cell_nodes[identity],source_layout):
			_fail("native Diner counter fit refused: "+identity)
			return
		if not DinerTill.mount_cell(cell_nodes[identity],source_layout):
			_fail("native Diner register/display fit refused: "+identity)
			return
		if not DinerBackbar.mount_cell(cell_nodes[identity],source_layout):
			_fail("native Diner rear bench/shelves fit refused: "+identity)
			return
		if not DinerUrns.mount_cell(cell_nodes[identity],source_layout):
			_fail("native Diner urns/pie display fit refused: "+identity)
			return
		if not DinerApparatus.mount_cell(cell_nodes[identity],source_layout):
			_fail("native Diner apparatus/pie display fit refused: "+identity)
			return
		if not DinerOverhead.mount_cell(cell_nodes[identity],source_layout):
			_fail("native Diner menu board/fan fit refused: "+identity)
			return
		if not PhotoCounter.mount_cell(cell_nodes[identity],source_layout):
			_fail("native photography counter fit refused: "+identity)
			return
		if not PhotoStock.mount_cell(cell_nodes[identity],source_layout):
			_fail("native photography supply shelving fit refused: "+identity)
			return
		if not PhotoEnlargers.mount_cell(cell_nodes[identity],source_layout):
			_fail("native photography enlarger fit refused: "+identity)
			return
		if not PhotoProcess.mount_cell(cell_nodes[identity],source_layout):
			_fail("native photography process fit refused: "+identity)
			return
		if not PhotoPortraits.mount_cell(cell_nodes[identity],source_layout,portrait_atlas_cache):
			_fail("native unclaimed portrait fit refused: "+identity)
			return
		if not PhotoGlazing.mount_cell(cell_nodes[identity],source_layout):
			_fail("native fixed photographic glazing refused: "+identity)
			return
		if not DruggistDrawers.mount_cell(cell_nodes[identity],source_layout):
			_fail("native druggist drawer/counter fit refused: "+identity)
			return
		if not DruggistCounter.mount_cell(cell_nodes[identity],source_layout):
			_fail("native druggist counter objects refused: "+identity)
			return
		if not DruggistMortar.mount_cell(cell_nodes[identity],source_layout):
			_fail("native druggist marble objects refused: "+identity)
			return
		if not DruggistDispensary.mount_cell(cell_nodes[identity],source_layout):
			_fail("native composed dispensary refused: "+identity)
			return
		if not DruggistCupboard.mount_cell(cell_nodes[identity],source_layout):
			_fail("native druggist cupboard refused: "+identity)
			return
		if not DruggistCarboys.mount_cell(cell_nodes[identity],source_layout):
			_fail("native druggist display carboys refused: "+identity)
			return
		if not DruggistFountain.mount_cell(cell_nodes[identity],source_layout):
			_fail("native unused druggist fountain refused: "+identity)
			return
		if not FuneralFittings.mount_cell(cell_nodes[identity],source_layout):
			_fail("native funeral lectern and empty bier refused: "+identity)
			return
		if not FuneralDrapes.mount_cell(cell_nodes[identity],source_layout):
			_fail("native fixed funeral curtains refused: "+identity)
			return
		if not FuneralFoliage.mount_cell(cell_nodes[identity],source_layout):
			_fail("native funeral foliage refused: "+identity)
			return
		if not RadioBench.mount_cell(cell_nodes[identity],source_layout):
			_fail("native radio alignment bench refused: "+identity)
			return
		if not RadioApparatus.mount_cell(cell_nodes[identity],source_layout):
			_fail("native radio test instruments refused: "+identity)
			return
		if not RadioStock.mount_cell(cell_nodes[identity],source_layout):
			_fail("native stored radio valves refused: "+identity)
			return
		if not RadioBattery.mount_cell(cell_nodes[identity],source_layout):
			_fail("native charging display refused: "+identity)
			return
		if not RadioWire.mount_cell(cell_nodes[identity],source_layout):
			_fail("native passive wire/ring stock refused: "+identity)
			return
		if not RadioDisplay.mount_cell(cell_nodes[identity],source_layout):
			_fail("native fitted counter/display refused: "+identity)
			return
		if not RadioReceiving.mount_cell(cell_nodes[identity],source_layout,cabinets_enabled):
			_fail("native period receiving chassis refused: "+identity)
			return
		if not LaundryReceiving.mount_cell(cell_nodes[identity],source_layout,cabinets_enabled):
			_fail("native Laundry receiving chassis refused: "+identity)
			return
		if not PhotoReceiving.mount_cell(cell_nodes[identity],source_layout,cabinets_enabled):
			_fail("native Photo Supplies receiving chassis refused: "+identity)
			return
		if not NewsReceiving.mount_cell(cell_nodes[identity],source_layout,cabinets_enabled):
			_fail("native News Cigars receiving chassis refused: "+identity)
			return
		if not PawnReceiving.mount_cell(cell_nodes[identity],source_layout,cabinets_enabled):
			_fail("native Pawn Shop receiving chassis refused: "+identity)
			return
		if not PawnDisplay.mount_cell(cell_nodes[identity],source_layout):
			_fail("native Pawn Shop display refused: "+identity)
			return
		if not PawnClocks.mount_cell(cell_nodes[identity],source_layout):
			_fail("native Pawn Shop clocks refused: "+identity)
			return
		if not PawnFittings.mount_cell(cell_nodes[identity],source_layout):
			_fail("native Pawn Shop fittings refused: "+identity)
			return
		if not DinerReceiving.mount_cell(cell_nodes[identity],source_layout,cabinets_enabled):
			_fail("native Diner receiving pair refused: "+identity)
			return
	var owner_finishes := preload("res://scripts/building/orison_v2_owner_finishes.gd").new()
	for cell: Node3D in cell_nodes.values():
		if not preload("res://scripts/building/orison_v2_shop_millwork.gd").mount_cell(cell,source_layout):
			_fail("standard wall millwork fit refused: "+str(cell.name)); return
	if not ArcadeFabric.mount_cell(cell_nodes.passage, source_layout):
		_fail("source-fitted arcade fabric refused"); return
	for cell: Node3D in cell_nodes.values(): owner_finishes.apply_shop_cell(cell)
	for cell: Node3D in cell_nodes.values(): owner_finishes.apply_shop_wear(cell)
	surface_pass.apply(cell_nodes)
	if not _mount_actors(): return
	preload("res://scripts/building/v2_legacy_material_stock.gd").apply(self)
	add_to_group("orison_v2_passage_region")
	print("[V2 PASSAGE] ", cell_nodes.size(), " resident cells; ", doors.size(), " doors; ", _counter_ids.size(), " shared-service counters")


## Fabrication continues to read source_layout. Placement may instead be a
## validated spatial projection, built with the replacement geometry.
func _mount_actors(placement: Dictionary = {}, door_set: Dictionary = {}) -> bool:
	var prepared := not placement.is_empty()
	if is_instance_valid(_actors) or prepared != not door_set.is_empty():
		_fail("invalid or repeated passage actor mount")
		return false
	_actor_layout = placement if prepared else source_layout
	_actors = Node3D.new()
	_actors.name = "PassageActors"
	add_child(_actors)
	if prepared:
		doors = door_set.storefronts
		_actors.add_child(door_set.root)
	_mount_markers(placement,[],prepared)
	receiving_row = Receivers.new()
	receiving_row.name = "PassageReceivingRow"
	_actors.add_child(receiving_row)
	if not receiving_row.mount(source_layout, _actors, CELLS, cabinets_enabled):
		_fail("source-owned passage receivers refused")
		return false
	finish = Finish.new()
	_actors.add_child(finish)
	finish.build(_actor_layout,door_set.get("storefronts",{}),_prepared_bundle.get("shell",{}))
	for sign_prop: ShopSignProp in _signs:
		sign_prop.bind_hours_director(finish.hours_director)
	_mount_counters()
	return not startup_failed and _mount_news_stand()


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

func _mount_markers(marker_layout: Dictionary = {}, only_ids: PackedStringArray = [], prepared_doors := false) -> void:
	var active_layout := source_layout if marker_layout.is_empty() else marker_layout
	var original_safelight: Dictionary = {}
	if not marker_layout.is_empty():
		var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
		for floor: Dictionary in authored.floors:
			if floor.id != "F01": continue
			for marker: Dictionary in floor.markers:
				if marker.id == "SITE_SHOP_DARKROOM_PHOTO_SUPPLIES": original_safelight = marker
	for floor: Dictionary in active_layout.floors:
		if floor.id != "F01": continue
		for marker: Dictionary in floor.markers:
			var identity := str(marker.id)
			if not only_ids.is_empty() and identity not in only_ids: continue
			if str(marker.get("zone", "")) != "PASSAGE" and not identity.begins_with("PASSAGE_PORTAL_LT_"):
				continue
			var prop: Node3D
			if marker.kind == "door":
				if prepared_doors: continue
				var door := preload("res://scripts/building/orison_v2_passage_shop_door.gd").new()
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
				var fixture: LightFixtureProp
				if identity == "SITE_SHOP_DARKROOM_PHOTO_SUPPLIES":
					var native := PhotoDarkroomLight.new()
					if not marker_layout.is_empty(): native.rebase_from_source_marker(original_safelight)
					fixture = native
				else: fixture = LightFixtureProp.new()
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
			if prop is FunctionalProp and AcousticGraphData.nodes.has(identity):
				prop.graph_node_id = identity
				_acoustic_originals[identity] = AcousticGraphData.nodes[identity].duplicate(true)
				var graph_record: Dictionary = AcousticGraphData.nodes[identity].duplicate(true)
				var mouth := to_global(prop.position)
				graph_record.pos = [mouth.x, -mouth.z, mouth.y]
				AcousticGraphData.nodes[identity] = graph_record
			_actors.add_child(prop)
			if prop is LightFixtureProp and identity in ["PASSAGE_PORTAL_LT_W", "PASSAGE_PORTAL_LT_E"]:
				preload("res://scripts/building/orison_v2_native_service_work_lights.gd").configure_exterior_shadow_distance(prop.light)

func _mount_counters() -> void:
	for item_id: String in shop_service.stock_ids():
		var record := shop_service.stock_record(item_id)
		var anchor_id := str(record.counter_anchor_id)
		var matches: Array[Dictionary] = []
		for floor: Dictionary in (_actor_layout if not _actor_layout.is_empty() else source_layout).floors:
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

func transaction_actor_root() -> Node3D:
	return _actors

func transaction_counter_available(shop_id: String) -> bool:
	return not startup_failed and shop_id in _counter_ids and shop_service!=null \
			and is_instance_valid(shop_service.counter(shop_id))


## News & Cigars sells over its counter (design/ORISON_NEWSPAPERS_2026-10-23.md
## section 6): the papers control sits on the authored counter top.
func _mount_news_stand() -> bool:
	var rows: Dictionary = {}
	for floor: Dictionary in (_actor_layout if not _actor_layout.is_empty() else source_layout).floors:
		if floor.id != "F01": continue
		for item: Dictionary in floor.furniture:
			if str(item.id) == "storm_shop_news_cigars_counter_top":
				rows[str(item.id)] = item
	if rows.size() != 1:
		_fail("news stand sources missing")
		return false
	var top: Dictionary = rows.storm_shop_news_cigars_counter_top
	var rect: Array = top.rect
	var stand := NewsRackProp.new()
	stand.name = "NewsStand"
	stand.hours = finish.hours_director
	# The customer-side strip of the top is the shop's sale point.
	var rack_front: float = float(rect[1]) + 0.18
	stand.setup("counter", Vector3(absf(float(rect[2]) - float(rect[0])), 0.3,
			absf(float(rect[3]) - rack_front)))
	stand.position = GameBoot.b2g([(float(rect[0]) + float(rect[2])) * 0.5,
			(rack_front + float(rect[3])) * 0.5, float(top.z0) + float(top.h) + 0.15])
	_actors.add_child(stand)
	return true

func shutdown() -> void:
	if is_instance_valid(receiving_row):
		receiving_row.shutdown()
	for identity: String in _acoustic_originals:
		AcousticGraphData.nodes[identity] = _acoustic_originals[identity]
	_acoustic_originals.clear()
	if is_instance_valid(residency):
		residency.shutdown()
	portrait_atlas_cache.clear()
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
	var retirement_started:=Time.get_ticks_usec()
	_notify_stock_residency(false)
	for identity: String in _counter_ids:
		shop_service.unmount_counter(identity)
	_counter_ids.clear()
	finish.hours_director.set_passage_active(false)
	for cart: PassagePushcart in finish.pushcarts:
		cart.set_passage_active(false)
	receiving_row.suspend()
	_actors.visible = false
	_actors.process_mode = Node.PROCESS_MODE_DISABLED
	var retirement_actors_done:=Time.get_ticks_usec()
	var retired: WeakRef = weakref(_geometry_root)
	remove_child(_geometry_root)
	var retirement_detached:=Time.get_ticks_usec()
	_geometry_root.queue_free()
	_geometry_root = null
	for identity: String in CELLS:
		cell_nodes.erase(identity)
	surface_pass = null
	if OS.get_environment("ORISON_PROFILE_RESIDENCY")=="1":
		print("PASSAGE_RETIRE_DETAIL ",JSON.stringify({"actors_ms":(retirement_actors_done-retirement_started)/1000.,"detach_ms":(retirement_detached-retirement_actors_done)/1000.,"enqueue_release_ms":(Time.get_ticks_usec()-retirement_detached)/1000.}))
	return retired

func activate_geometry(geometry: Node3D, cells: Dictionary, surfaces: RefCounted) -> void:
	_geometry_root = geometry
	_geometry_root.name = "ResidentGeometry"
	if _geometry_root.get_parent() == null: add_child(_geometry_root)
	_geometry_root.process_mode = Node.PROCESS_MODE_INHERIT
	_geometry_root.visible = true
	cell_nodes.merge(cells)
	for cell: Node3D in cells.values(): preload("res://scripts/building/orison_v2_owner_finishes.gd").apply_shop_wear(cell)
	surface_pass = surfaces
	_actors.process_mode = Node.PROCESS_MODE_INHERIT
	_actors.visible = true
	finish.hours_director.set_passage_active(true)
	finish.hours_director.apply_for_minute(ScheduleDirector.minute_now())
	for cart: PassagePushcart in finish.pushcarts:
		cart.set_passage_active(true)
	_mount_counters()
	_notify_stock_residency(true)

func _exit_tree() -> void:
	shutdown()

func _fail(reason: String) -> void:
	startup_failed = true
	push_error("V2 PASSAGE: " + reason)
