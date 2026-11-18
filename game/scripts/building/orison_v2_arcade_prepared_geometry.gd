extends RefCounted
const RuntimeBundle := preload("res://scripts/building/orison_v2_arcade_runtime_bundle.gd")
## Build the replacement cells off-tree. The caller owns the detached donors,
## registered region transform, actor/save lifetime, and final publication.
const Fabric := preload("res://scripts/building/orison_v2_arcade_fabric.gd")
const Shell := preload("res://scripts/building/orison_v2_arcade_plaza_shell.gd")
const Frame := preload("res://scripts/building/orison_v2_arcade_native_carrier.gd")
const Public := preload("res://scripts/building/orison_v2_arcade_public_fittings.gd")
const Threshold := preload("res://scripts/building/orison_v2_arcade_entry_threshold.gd")
const Millwork := preload("res://scripts/building/orison_v2_shop_millwork.gd")
const Cobbler := preload("res://scripts/building/orison_v2_arcade_cobbler_field.gd")
const Door := preload("res://scripts/building/orison_v2_arcade_shop_door.gd")
const Finishes := preload("res://scripts/building/orison_v2_owner_finishes.gd")
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
const STREAMED_FITTINGS := [
	"hardware_drawers", "hardware_stock", "druggist_drawers", "laundry_fittings",
	"cobbler_fittings", "locksmith_fittings", "funeral_foliage", "druggist_carboys",
	"druggist_dispensary", "photo_stock",
]

const CACHED_FITS := {
	"funeral_foliage": ["shop_funeral_parlour", "FuneralFoliage"],
	"druggist_carboys": ["shop_otis_son", "DruggistCarboys"],
	"druggist_dispensary": ["shop_otis_son", "DruggistDispensary"],
	"photo_stock": ["shop_photo_supplies", "PhotoStock"],
}

const PENDANTS := "res://data/orison_v2/arcade_aisle_pendants.json"
const PENDANT_ASSET := "res://assets/props/arcade_aisle_pendants.glb"
var errors: Array[String] = []

enum Setup { SHELL, MILLWORK, STOREFRONT, PUBLIC_FITTINGS, CLOCK, PENDANTS, READY }

# One preparation instance owns one detached build until take_build or cancel.
var _build_root: Node3D
var _setup := Setup.READY
var _shell_contract: Dictionary
var _door_frames: Array
var _build_donor: Node3D
var _build_carrier: Frame
var collision_cache: RefCounted
var _fit_job: RefCounted
var _build_layout: Dictionary
var _atlas: RefCounted
var _shops: Array[Dictionary] = []
var _raw_shops := {}
var _shop_index := 0
var _taken_shops := 0
var _passage_taken := false
var _mount_index := 0
var aisle_markers: Array[Dictionary] = []

func begin_build(layout: Dictionary, bundle: Dictionary, atlas: RefCounted) -> bool:
	if _setup != Setup.READY or _build_root != null: return false
	errors.clear()
	if bundle.get("shell") is not Dictionary or bundle.get("frames") is not Array \
		or bundle.get("native") is not Array or bundle.get("raw") is not Array:
		return _abort_build("Missing prepared arcade declaration")
	_shell_contract = bundle.shell
	_door_frames = bundle.frames
	_build_layout = layout
	_build_carrier = Frame.new(true)
	_atlas = atlas
	_shop_index = 0
	_mount_index = 0
	if bundle.native.size() != 11 or bundle.raw.size() != 11:
		return _abort_build("Incomplete original shop donor inventory")
	for row: Dictionary in bundle.raw:
		var identity := str(row.get("cell",""))
		if _raw_shops.has(identity): return _abort_build("Duplicate raw donor " + identity)
		_raw_shops[identity] = row
	var seen := {}
	for row: Dictionary in bundle.native:
		var identity := str(row.get("cell",""))
		var expected_path := "res://assets/building/floor_01_cells/" + identity + ".gltf"
		if seen.has(identity) or not identity.begins_with("shop_") \
			or not _raw_shops.has(identity) \
			or row.get("cell_source") != expected_path or _raw_shops[identity].get("cell_source") != expected_path \
			or row.get("mounts") is not Array or row.mounts.is_empty():
			return _abort_build("Invalid prepared shop donor " + identity)
		seen[identity] = true
		_shops.append(row)
	_build_carrier.start_asset_digests(_shops)
	_setup = Setup.SHELL
	return true

func _prepare_clock() -> bool:
	var packed := load("res://assets/building/orison_v2/passage/passage.gltf") as PackedScene
	if packed == null: return false
	var donor := packed.instantiate() as Node3D
	if donor == null: return false
	donor.name = "passage"
	var accepted := Fabric.mount_clock(donor,_build_layout) and admit_clock(_build_root,donor)
	donor.free()
	return accepted

func _advance_setup() -> Error:
	var accepted := false
	match _setup:
		Setup.SHELL:
			_build_root = _prepare_shell()
			accepted = _build_root != null
			if accepted:
				for shop: Dictionary in _shops:
					if not _build_root.has_node(NodePath(str(shop.cell))):
						accepted = false
						break
		Setup.MILLWORK:
			accepted = Millwork.mount_prepared(_build_root,_shell_contract,_door_frames)
		Setup.STOREFRONT:
			accepted = _prepare_storefront(_build_root)
		Setup.PUBLIC_FITTINGS:
			accepted = _prepare_public_fittings(_build_root)
		Setup.CLOCK:
			accepted = _prepare_clock()
		Setup.PENDANTS:
			aisle_markers = admit_pendants(_build_root,_build_layout)
			accepted = aisle_markers.size() == 8
	if not accepted:
		_abort_build("Prepared arcade setup refused: " + next_build_step())
		return ERR_INVALID_DATA
	_setup = (_setup + 1) as Setup
	return ERR_BUSY

## Describe the next operation for the residency profiler without advancing it.
func next_build_step() -> String:
	if _setup != Setup.READY: return "setup/" + str(Setup.keys()[_setup]).to_lower()
	if _shop_index >= _shops.size(): return "finish"
	var shop := _shops[_shop_index]
	if _mount_index == shop.mounts.size(): return str(shop.cell) + "/admit"
	var step := "instantiate+" if _build_donor == null else ""
	return "%s/%s%s" % [shop.cell, step, shop.mounts[_mount_index].family]

## One bounded fitting operation. Returns ERR_BUSY while detached work remains,
## OK once the same result can be taken by startup or residency.
func advance_build(fit_budget_usec := 0) -> Error:
	if _setup != Setup.READY: return _advance_setup()
	if _build_root == null: return ERR_UNCONFIGURED
	if _shop_index == _shops.size(): return OK
	var spec := _shops[_shop_index]
	if _build_donor == null:
		var packed := load(str(spec.cell_source)) as PackedScene
		if packed == null:
			_abort_build("Original shop carrier missing " + str(spec.cell))
			return ERR_CANT_OPEN
		_build_donor = packed.instantiate() as Node3D
		if _build_donor == null:
			_abort_build("Original shop carrier root missing " + str(spec.cell))
			return ERR_INVALID_DATA
		_build_donor.name = str(spec.cell)
	if _mount_index < spec.mounts.size():
		var mount: Dictionary = spec.mounts[_mount_index]
		var fit := _advance_prepared_fitting(mount,fit_budget_usec)
		if fit == ERR_BUSY: return ERR_BUSY
		if fit != OK:
			_abort_build("Original fitting refused: %s/%s" % [spec.cell, mount.get("family","")])
			return fit
		_mount_index += 1
		return ERR_BUSY
	if not _build_carrier.finish_asset_digests(fit_budget_usec <= 0): return ERR_BUSY
	if not admit_shop(_build_root,_build_donor,spec,_raw_shops[str(spec.cell)],_build_carrier):
		_abort_build("Shop transfer refused: %s/%s" % [spec.cell,str(errors)])
		return ERR_INVALID_DATA
	_build_carrier.clear_fitted_collision_witnesses()
	_build_donor.free()
	_build_donor = null
	_mount_index = 0
	_shop_index += 1
	return OK if _shop_index == _shops.size() else ERR_BUSY

## The original wrapper consumes the fitter's one-use result and still owns
## the uncached path and any finishing work. Only detached donors are touched.
func _advance_prepared_fitting(mount: Dictionary, budget_usec: int) -> Error:
	if budget_usec <= 0 or mount.get("family", "") not in STREAMED_FITTINGS:
		return OK if _fit_prepared_donor(mount) else ERR_INVALID_DATA
	if _fit_job == null:
		if collision_cache != null and mount.get("family", "") in CACHED_FITS:
			_build_donor.set_meta("native_collision_paths", collision_cache.paths)
			_build_donor.set_meta("native_collision_shapes", collision_cache.shapes)
		# The original wrapper checks this one-use request against its own recipe.
		_fit_job = Seating.begin_records(_build_donor, _build_layout, str(mount.sidecar),
			str(mount.name), str(mount.draw_prefix), str(mount.part_meta))
	_fit_job.advance(budget_usec)
	if not _fit_job.done: return ERR_BUSY
	if not _fit_job.ok: return ERR_INVALID_DATA
	if not _fit_job.skipped: _build_donor.set_meta("prepared_native_fit",_fit_job)
	var mounted := _fit_prepared_donor(mount)
	if mounted and _build_donor.has_meta("native_collision_paths"):
		var fitted: Node3D = _build_donor.get_node(NodePath(str(mount.name)))
		for draw: MeshInstance3D in fitted.find_children("*", "MeshInstance3D", true, false):
			_build_carrier.remember_fitted_collision(draw, collision_cache)
	_fit_job = null
	if _build_donor.has_meta("native_collision_paths"):
		_build_donor.remove_meta("native_collision_paths")
		_build_donor.remove_meta("native_collision_shapes")
	if _build_donor.has_meta("prepared_native_fit"):
		_build_donor.remove_meta("prepared_native_fit")
		return ERR_INVALID_DATA
	return OK if mounted else ERR_INVALID_DATA

func _fit_prepared_donor(mount: Dictionary) -> bool:
	var path := str(mount.get("wrapper",""))
	var method := str(mount.get("method",""))
	if not path.begins_with("res://scripts/building/orison_v2_") \
		or not path.ends_with(".gd") or method != "mount_cell":
		return false
	var wrapper := load(path) as GDScript
	if wrapper == null or not wrapper.has_method(method): return false
	var args: Array = []
	for argument: String in mount.arguments:
		match argument:
			"cell": args.append(_build_donor)
			"original_layout": args.append(_build_layout)
			"portrait_atlas_cache": args.append(_atlas)
			_: return false
	return bool(wrapper.callv(method,args))

func take_build() -> Node3D:
	if _build_root == null or _shop_index != _shops.size(): return null
	var result := _build_root
	_build_root = null
	var original_markers := aisle_markers
	cancel_build()
	aisle_markers = original_markers
	return result

## Reload can register finished cells behind the loading guard while detached
## work continues. Startup still takes the intact build in one operation.
func take_completed_cell() -> Node3D:
	if _setup != Setup.READY or _build_root == null: return null
	var identity: String
	if not _passage_taken:
		identity = "passage"
		_passage_taken = true
	elif _taken_shops < _shop_index:
		identity = str(_shops[_taken_shops].cell)
		_taken_shops += 1
	else:
		return null
	var cell := _build_root.get_node_or_null(NodePath(identity)) as Node3D
	if cell != null: _build_root.remove_child(cell)
	return cell

func cancel_build() -> void:
	if _fit_job != null:
		_fit_job.cancel()
		_fit_job = null
	if is_instance_valid(_build_donor): _build_donor.free()
	if is_instance_valid(_build_root): _build_root.free()
	_build_donor = null
	_build_root = null
	_setup = Setup.READY
	_shell_contract = {}
	_door_frames = []
	_build_layout = {}
	collision_cache = null
	if _build_carrier != null:
		_build_carrier.cancel_asset_digests()
		_build_carrier.clear_fitted_collision_witnesses()
	_build_carrier = null
	_atlas = null
	_shops.clear()
	_raw_shops.clear()
	_taken_shops = 0
	_passage_taken = false
	aisle_markers = []

func _abort_build(message: String) -> bool:
	errors.append(message)
	cancel_build()
	return false

func _declaration(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func _refuse(message: String, root: Node3D = null) -> Node3D:
	errors.append(message)
	if root != null:
		root.free()
	return null

func prepare(shell_contract: Dictionary, frames: Array) -> Node3D:
	errors.clear()
	var root := _prepare_shell()
	if root == null: return null
	if not Millwork.mount_prepared(root,shell_contract,frames):
		return _refuse("Prepared shell millwork",root)
	if not _prepare_storefront(root) or not _prepare_public_fittings(root):
		root.free()
		return null
	return root

func _prepare_shell() -> Node3D:
	var shell_loader := Shell.new()
	var root := shell_loader.prepare(_declaration(Shell.DATA))
	if root == null:
		return _refuse("Prepared shell: " + str(shell_loader.errors))
	root.name = "ResidentGeometry"
	return root

func _prepare_storefront(root: Node3D) -> bool:
	var shell_loader := Shell.new()
	var frontage := shell_loader.prepare_storefront(_declaration(Shell.STOREFRONT_DATA))
	if frontage == null:
		errors.append("Prepared storefront: " + str(shell_loader.errors))
		return false
	for shop: Node3D in frontage.get_children():
		var receiver := root.get_node_or_null(NodePath(str(shop.name))) as Node3D
		if receiver == null:
			frontage.free()
			errors.append("Unregistered storefront cell")
			return false
		for draw: Node3D in shop.get_children():
			shop.remove_child(draw)
			receiver.add_child(draw)
	frontage.free()
	return true

func _prepare_public_fittings(root: Node3D) -> bool:
	var passage := root.get_node("passage") as Node3D
	var public_fittings := Public.new()
	var hatches := public_fittings.prepare_hatches(_declaration(Public.DATA))
	if hatches == null:
		errors.append("Prepared pavement hatches: " + str(public_fittings.errors))
		return false
	passage.add_child(hatches)
	var entry := Threshold.prepare()
	if entry == null:
		errors.append("Prepared entrance threshold")
		return false
	passage.add_child(entry)
	return true

## These doors outlive the geometry root. Keep registered storefront IDs
## separate from new stock doors so callers can bind the existing save owners.
func prepare_doors(layout: Dictionary, frames: Array, cells: Dictionary) -> Dictionary:
	errors.clear()
	var original := {}
	for floor: Dictionary in layout.floors:
		if floor.id != "F01":
			continue
		for marker: Dictionary in floor.markers:
			var identity := str(marker.id)
			if marker.kind == "door" and marker.get("zone") == "PASSAGE" \
				and identity.begins_with("SITE_SHOP_DOOR_"):
				if original.has(identity):
					errors.append("Duplicate storefront actor: " + identity)
					return {}
				original[identity] = marker
	if original.size() != 11 or cells.size() != 11 or frames.size() != 22:
		errors.append("Incomplete storefront inventory: %d originals, %d cells, %d frames" % [original.size(),cells.size(),frames.size()])
		return {}
	var carrier := Frame.new()
	var seen := {}
	var pairs := {}
	var singles := {}
	for row: Dictionary in frames:
		var identity := str(row.get("id", ""))
		var cell := str(row.get("cell", ""))
		var pose := carrier._matrix(row.get("frame_transform"))
		var paired: bool = row.get("paired", false) == true
		var owned := pairs if paired else singles
		if identity.is_empty() or seen.has(identity) or not cells.has(cell) or owned.has(cell) \
			or not carrier._rigid(pose) or not pose.basis.y.is_equal_approx(Vector3.UP) \
			or row.get("width") != (2.0 if paired else 1.0) or row.get("height") != 2.30:
			errors.append("Invalid prepared door frame: " + identity)
			return {}
		if paired:
			var source_cell := "shop_" + identity.trim_prefix("SITE_SHOP_DOOR_").replace("___","_").to_lower()
			if row.get("frame_kind") != "front_pair" or cell != source_cell or not original.has(identity) \
				or row.get("source_marker_id") != identity or row.get("source_marker") != original[identity] \
				or original[identity].get("swing", "") == "out":
				errors.append("Storefront door authority changed: " + identity)
				return {}
		elif row.get("frame_kind") != "stock_single" or original.has(identity) \
			or identity != "ARCADE_STOCK_DOOR_" + cell.trim_prefix("shop_").to_upper():
			errors.append("Invalid independent stock door: " + identity)
			return {}
		seen[identity] = true
		owned[cell] = row
	if pairs.size() != original.size() or singles.size() != cells.size():
		errors.append("Each prepared cell requires one storefront pair and one stock door")
		return {}
	var root := Node3D.new()
	root.name = "ArcadeDoors"
	var storefronts := {}
	var stock_doors := {}
	for row: Dictionary in frames:
		var door := Door.from_frame(row)
		if row.paired:
			var marker: Dictionary = original[str(door.name)]
			door.leaf_state = str(marker.leaf)
			door.door_kind = str(marker.get("subtype", "storefront"))
			door.unit = str(marker.get("unit", ""))
			door.finish_variant = int(marker.get("finish_variant", 0))
			storefronts[str(door.name)] = door
		else:
			stock_doors[str(door.name)] = door
		root.add_child(door)
	return {"root": root, "storefronts": storefronts, "stock_doors": stock_doors}

## The brass and iron stay with the geometry; the existing light actors
## remain under the passage actor owner. Return their original records with
## only position projected.
func admit_pendants(root: Node3D, layout: Dictionary) -> Array[Dictionary]:
	errors.clear()
	var passage := root.get_node_or_null("passage") as Node3D
	var spec := _declaration(PENDANTS)
	if root.is_inside_tree() or passage == null or passage.has_node("ArcadeAislePendants") \
		or spec.get("schema") != "orison.v2.arcade-pendants.v1" \
		or spec.get("fixtures") is not Array or spec.fixtures.size() != 8 \
		or spec.get("parts") is not Array or spec.parts.size() != 16 \
		or FileAccess.get_sha256(PENDANT_ASSET) != spec.get("asset_sha256") \
		or root.get_meta("arcade_shell_asset_sha256", "") != spec.get("shell_sha256") \
		or Frame.new()._hash_lf(Public.SOURCE) != spec.get("fabrication_sha256_lf"):
		return _pendants_refused("Arcade pendant or receiving shell source changed")
	var settings := ConfigFile.new()
	if settings.load(RuntimeBundle.source_path(PENDANT_ASSET + ".import")) != OK \
		or settings.get_value("params","meshes/force_disable_compression",false) != true:
		return _pendants_refused("Arcade pendants require authored import precision")
	var projected := project_pendant_markers(layout)
	if projected.is_empty(): return []
	var part_materials := {}
	for marker: Dictionary in projected:
		var suffix := str(marker.id).trim_prefix("PASSAGE_AISLE_LT_")
		part_materials["site_aisle_pendant_" + suffix] = "cast_iron"
		part_materials["site_passage_aisle_pendant_canopy_" + suffix] = "brass_dull"
	var parts := {}
	for row: Dictionary in spec.parts:
		var identity := str(row.get("name", ""))
		if parts.has(identity) or not part_materials.has(identity) \
			or part_materials[identity] != row.get("material") or int(row.get("triangles",0)) <= 0:
			return _pendants_refused("Invalid original suspension stock: " + identity)
		parts[identity] = row
	var packed := load(PENDANT_ASSET) as PackedScene
	if packed == null: return _pendants_refused("Arcade pendant import missing")
	var model := packed.instantiate() as Node3D
	var draws := {}
	var frame := Frame.new()
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var identity := str(draw.name)
		if draws.has(identity) or not parts.has(identity) or draw.mesh == null \
			or draw.mesh.get_surface_count() != 1 or not frame._same(frame._relative(draw,model),Transform3D.IDENTITY) \
			or draw.mesh.get_faces().size() != int(parts[identity].triangles)*3:
			return _pendants_refused("Arcade suspension native geometry changed: " + identity,model)
		draws[identity] = draw
	if draws.size() != parts.size():
		return _pendants_refused("Arcade suspension native inventory incomplete",model)
	var finishes := {}
	for key: String in ["cast_iron","brass_dull"]:
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE / float(MatLib.SETS[key][3])
		material.normal_scale = .18
		finishes[key] = preload("res://scripts/building/surface_pass.gd").surface_for(material,{"uv_mode":0})
	for identity: String in draws:
		var draw: MeshInstance3D = draws[identity]
		var key: String = part_materials[identity]
		draw.material_override = finishes[key]
		draw.set_meta("material_key",key)
	model.name = "ArcadeAislePendants"
	passage.add_child(model)
	return projected

## Both startup paths mount the same original fixture actors. The bake
## contains their suspension geometry, while these records own their position.
func project_pendant_markers(layout: Dictionary) -> Array[Dictionary]:
	var spec := _declaration(PENDANTS)
	if spec.get("schema") != "orison.v2.arcade-pendants.v1" \
			or spec.get("fixtures") is not Array or spec.fixtures.size() != 8:
		return _pendants_refused("Arcade pendant fixtures missing")
	var originals := {}
	for floor: Dictionary in layout.floors:
		if floor.id != "F01": continue
		for marker: Dictionary in floor.markers:
			if str(marker.id).begins_with("PASSAGE_AISLE_LT_"):
				originals[str(marker.id)] = marker
	var projected: Array[Dictionary] = []
	var seen := {}
	var frame := Frame.new()
	for row: Dictionary in spec.fixtures:
		var identity := str(row.get("id", ""))
		var original: Dictionary = originals.get(identity, {})
		if original.get("kind") != "cage_bulb" or original.get("zone") != "PASSAGE" \
				or seen.has(identity) or not frame._point(row.get("pos")).is_finite():
			return _pendants_refused("Invalid original aisle light: " + identity)
		var marker := original.duplicate(true)
		marker.pos = row.pos.duplicate()
		projected.append(marker)
		seen[identity] = true
	return projected


func _pendants_refused(message: String, model: Node3D = null) -> Array[Dictionary]:
	_refuse(message,model)
	return []

func admit_clock(root: Node3D, donor: Node3D) -> bool:
	errors.clear()
	var passage := root.get_node_or_null("passage") as Node3D
	if root.is_inside_tree() or passage == null or passage.has_node("ArcadePublicClock"):
		errors.append("Clock requires a detached replacement passage without a clock")
		return false
	var helper := Public.new()
	var clock := helper.extract_clock(donor,_declaration(Public.DATA))
	if clock == null:
		errors.append_array(helper.errors)
		return false
	passage.add_child(clock)
	return true

func admit_shop(root: Node3D, donor: Node3D, native_spec: Dictionary, raw_spec: Dictionary, helper: Frame = null) -> bool:
	errors.clear()
	var cell := root.get_node_or_null(NodePath(str(native_spec.get("cell","")))) as Node3D
	if root.is_inside_tree() or donor.is_inside_tree() or cell == null \
		or cell.name != donor.name or cell.has_meta("arcade_retained_shop_admitted") \
		or native_spec.get("cell") != raw_spec.get("cell"):
		errors.append("Shop carrier requires matching detached cells and fresh custody")
		return false
	if helper == null: helper = Frame.new()
	var cobbler: Node3D
	if cell.name == "shop_shoe_rebuilding":
		var field := Cobbler.new()
		cobbler = field.prepare(_declaration(Cobbler.DATA),donor,native_spec)
		if cobbler == null:
			errors.append_array(field.errors)
			return false
	var native := helper.extract_native(donor,native_spec)
	if native == null:
		if cobbler != null:
			cobbler.free()
		errors.append_array(helper.errors)
		return false
	var raw := helper.extract_raw(donor,raw_spec)
	if raw == null:
		# Keep the extracted native parts in detached donor custody. Leave
		# the receiving cell untouched so no partial shop can be published.
		donor.add_child(native)
		if cobbler != null:
			cobbler.free()
		errors.append_array(helper.errors)
		return false
	Finishes.new().apply_shop_cell(native)
	cell.add_child(native)
	cell.add_child(raw)
	if cobbler != null:
		cell.add_child(cobbler)
	cell.set_meta("arcade_retained_shop_admitted", true)
	return true
