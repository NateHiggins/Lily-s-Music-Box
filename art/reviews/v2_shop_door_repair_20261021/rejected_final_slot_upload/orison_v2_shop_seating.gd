extends RefCounted

static func mount_arcade_canopy(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/arcade_canopy.json","ArcadeCanopy","F01_retail_arcade_","arcade_canopy_part")

static func mount_arcade_throat(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/arcade_throat.json","ArcadeThroat","F01_retail_arcade_","arcade_throat_part")

static func mount_arcade_lantern(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/arcade_lantern.json","ArcadeLantern","F01_retail_arcade_","arcade_lantern_part")

static func mount_arcade_clock(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/arcade_clock.json","ArcadeClock","F01_retail_arcade_clock_","arcade_clock_part")
## Native furniture replaces only identified source box boundaries. The
## imported shop, its other triangles and its physical actors remain owners.
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/shop_seating.json","ShopSeating","F01_retail_seating_","seating_part")

static func mount_laundry(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/laundry_fittings.json","LaundryFittings","F01_retail_laundry_","laundry_part")

static func mount_laundry_apparatus(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/laundry_apparatus.json","LaundryApparatus","F01_retail_laundry_apparatus_","laundry_apparatus_part")

static func mount_shop_clerestories(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/shop_clerestories.json","ShopClerestories","F01_retail_clerestories_","shop_clerestories_part")

static func mount_shop_joinery(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/shop_joinery.json","ShopJoinery","F01_retail_shop_joinery_","shop_joinery_part")

static func mount_photo_radio_fittings(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/photo_radio_fittings.json","PhotoRadioFittings","F01_retail_photo_radio_fittings_","photo_radio_fittings_part")

static func mount_laundry_trade(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/laundry_trade.json","LaundryTrade","F01_retail_laundry_trade_","laundry_trade_part")

static func mount_locksmith(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/locksmith_fittings.json","LocksmithFittings","F01_retail_locksmith_","locksmith_part")

static func mount_cobbler(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/cobbler_fittings.json","CobblerFittings","F01_retail_cobbler_","cobbler_part")

static func mount_news(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/news_fittings.json","NewsFittings","F01_retail_news_","news_part")

static func mount_hardware_drawers(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/hardware_drawers.json","HardwareDrawers","F01_retail_hardware_drawers_","hardware_drawer_part")

static func mount_hardware_apparatus(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/hardware_apparatus.json","HardwareApparatus","F01_retail_hardware_apparatus_","hardware_apparatus_part")

static func mount_hardware_stock(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/hardware_stock.json","HardwareStock","F01_retail_hardware_stock_","hardware_stock_part")

static func mount_hardware_tools(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/hardware_tools.json","HardwareTools","F01_retail_hardware_tools_","hardware_tools_part")

static func mount_photo_cameras(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/photo_cameras.json","PhotoCameras","F01_retail_photo_cameras_","photo_cameras_part")

static func mount_diner_counter(cell: Node3D, layout: Dictionary, borrowed_materials: Dictionary = {}) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/diner_counter.json","DinerCounter","F01_retail_diner_counter_","diner_counter_part","",borrowed_materials)
static func mount_diner_till(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/diner_till.json","DinerTill","F01_retail_diner_till_","diner_till_part")
static func mount_diner_backbar(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/diner_backbar.json","DinerBackbar","F01_retail_diner_backbar_","diner_backbar_part")
static func mount_diner_urns(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/diner_urns.json","DinerUrns","F01_retail_diner_urns_","diner_urns_part")
static func mount_diner_apparatus(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/diner_apparatus.json","DinerApparatus","F01_retail_diner_apparatus_","diner_apparatus_part")
static func mount_diner_overhead(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/diner_overhead.json","DinerOverhead","F01_retail_diner_overhead_","diner_overhead_part")
static func mount_pawn_fittings(cell: Node3D, layout: Dictionary, borrowed_materials: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/pawn_fittings.json","PawnFittings","F01_retail_pawn_fittings_","pawn_fittings_part","",borrowed_materials)

static func mount_pawn_display(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/pawn_display.json","PawnDisplay","F01_retail_pawn_display_","pawn_display_part")

static func mount_pawn_clocks(cell: Node3D, layout: Dictionary, borrowed_materials: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/pawn_clocks.json","PawnClocks","F01_retail_pawn_clocks_","pawn_clocks_part","",borrowed_materials)

static func mount_photo_counter(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/photo_counter.json","PhotoCounter","F01_retail_photo_counter_","photo_counter_part")

static func mount_photo_stock(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/photo_stock.json","PhotoStock","F01_retail_photo_stock_","photo_stock_part")

static func mount_photo_enlargers(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/photo_enlargers.json","PhotoEnlargers","F01_retail_photo_enlargers_","photo_enlargers_part")

static func mount_photo_process(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/photo_process.json","PhotoProcess","F01_retail_photo_process_","photo_process_part")

static func mount_photo_portraits(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/photo_portraits.json","PhotoPortraits","F01_retail_photo_portraits_","photo_portraits_part")

static func mount_photo_glazing(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/photo_glazing.json","PhotoGlazing","F01_retail_photo_glazing_","photo_glazing_part")

static func mount_druggist_drawers(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/druggist_drawers.json","DruggistDrawers","F01_retail_druggist_drawers_","druggist_drawer_part")

static func mount_druggist_counter(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/druggist_counter.json","DruggistCounter","F01_retail_druggist_counter_","druggist_counter_part")

static func mount_druggist_mortar(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/druggist_mortar.json","DruggistMortar","F01_retail_druggist_mortar_","druggist_mortar_part")

static func mount_druggist_dispensary(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/druggist_dispensary.json","DruggistDispensary","F01_retail_druggist_dispensary_","druggist_dispensary_part")

static func mount_druggist_cupboard(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/druggist_cupboard.json","DruggistCupboard","F01_retail_druggist_cupboard_","druggist_cupboard_part")

static func mount_radio_display(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/radio_display.json","RadioDisplay","F01_retail_radio_display_","radio_display_part")

static func mount_radio_wire(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/radio_wire.json","RadioWire","F01_retail_radio_wire_","radio_wire_part")

static func mount_radio_battery(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/radio_battery.json","RadioBattery","F01_retail_radio_battery_","radio_battery_part")

static func mount_radio_stock(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/radio_stock.json","RadioStock","F01_retail_radio_stock_","radio_stock_part")

static func mount_radio_apparatus(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/radio_apparatus.json","RadioApparatus","F01_retail_radio_apparatus_","radio_apparatus_part")

static func mount_radio_bench(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/radio_bench.json","RadioBench","F01_retail_radio_bench_","radio_bench_part")

static func mount_funeral_foliage(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/funeral_foliage.json","FuneralFoliage","F01_retail_funeral_foliage_","funeral_foliage_part")

static func mount_funeral_drapes(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/funeral_drapes.json","FuneralDrapes","F01_retail_funeral_drapes_","funeral_drape_part")

static func mount_funeral(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/funeral_fittings.json","FuneralFittings","F01_retail_funeral_","funeral_part")

static func mount_druggist_fountain(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/druggist_fountain.json","DruggistFountain","F01_retail_druggist_fountain_","druggist_fountain_part")

static func mount_druggist_carboys(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/druggist_carboys.json","DruggistCarboys","F01_retail_druggist_carboys_","druggist_carboys_part")

static func mount_bar_pool(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/bar_pool.json","BarPool","F01_retail_bar_pool_","bar_pool_part","shop_bar")

static func mount_bar_stage(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/bar_stage.json","BarStage","F01_retail_bar_stage_","bar_stage_part","shop_bar")

# Immutable native scenes may be prefetched by the world. Instances duplicate
# selected meshes before assigning materials; no mesh/scene cache survives here.
const FITTING_DATA := [
	"res://data/orison_v2/arcade_canopy.json",
	"res://data/orison_v2/arcade_throat.json",
	"res://data/orison_v2/arcade_lantern.json",
	"res://data/orison_v2/arcade_clock.json",
	"res://data/orison_v2/shop_seating.json",
	"res://data/orison_v2/laundry_fittings.json",
	"res://data/orison_v2/laundry_apparatus.json",
	"res://data/orison_v2/shop_clerestories.json",
	"res://data/orison_v2/shop_joinery.json",
	"res://data/orison_v2/photo_radio_fittings.json",
	"res://data/orison_v2/laundry_trade.json",
	"res://data/orison_v2/locksmith_fittings.json",
	"res://data/orison_v2/cobbler_fittings.json",
	"res://data/orison_v2/news_fittings.json",
	"res://data/orison_v2/hardware_drawers.json",
	"res://data/orison_v2/hardware_apparatus.json",
	"res://data/orison_v2/hardware_stock.json",
	"res://data/orison_v2/hardware_tools.json",
	"res://data/orison_v2/photo_cameras.json",
	"res://data/orison_v2/diner_counter.json",
	"res://data/orison_v2/diner_till.json",
	"res://data/orison_v2/diner_backbar.json",
	"res://data/orison_v2/diner_urns.json",
	"res://data/orison_v2/diner_apparatus.json",
	"res://data/orison_v2/diner_overhead.json",
	"res://data/orison_v2/pawn_fittings.json",
	"res://data/orison_v2/pawn_display.json",
	"res://data/orison_v2/pawn_clocks.json",
	"res://data/orison_v2/photo_counter.json",
	"res://data/orison_v2/photo_stock.json",
	"res://data/orison_v2/photo_enlargers.json",
	"res://data/orison_v2/photo_process.json",
	"res://data/orison_v2/photo_portraits.json",
	"res://data/orison_v2/photo_glazing.json",
	"res://data/orison_v2/druggist_drawers.json",
	"res://data/orison_v2/druggist_counter.json",
	"res://data/orison_v2/druggist_mortar.json",
	"res://data/orison_v2/druggist_dispensary.json",
	"res://data/orison_v2/druggist_cupboard.json",
	"res://data/orison_v2/radio_display.json",
	"res://data/orison_v2/radio_wire.json",
	"res://data/orison_v2/radio_battery.json",
	"res://data/orison_v2/radio_stock.json",
	"res://data/orison_v2/radio_apparatus.json",
	"res://data/orison_v2/radio_bench.json",
	"res://data/orison_v2/funeral_foliage.json",
	"res://data/orison_v2/funeral_drapes.json",
	"res://data/orison_v2/funeral_fittings.json",
	"res://data/orison_v2/druggist_fountain.json",
	"res://data/orison_v2/druggist_carboys.json",
	"res://data/orison_v2/bar_pool.json",
	"res://data/orison_v2/bar_stage.json",
]

static func fitting_assets(cell_ids: Array = []) -> Array[String]:
	var assets: Array[String] = []
	for path: String in FITTING_DATA:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is not Dictionary or data.get("asset") is not String: return []
		var used := cell_ids.is_empty()
		for record: Dictionary in data.cells:
			if str(record.id) in cell_ids: used=true
		if used and not assets.has(str(data.asset)): assets.append(str(data.asset))
	return assets

static func mount_records(cell: Node3D, layout: Dictionary, data_path: String, model_name: String, draw_prefix: String, part_meta: String, cell_identity: String = "", borrowed_materials: Dictionary = {}) -> bool:
	var profile_start := Time.get_ticks_usec()
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if data is not Dictionary or int(data.get("schema_version",0))!=1:return false
	var matches: Array=[]
	for row: Dictionary in data.cells:
		if str(row.id)==(str(cell.name) if cell_identity.is_empty() else cell_identity):matches.append(row)
	if matches.is_empty():return true
	if matches.size()!=1 or cell.has_node(model_name):return false
	var record: Dictionary=matches[0]
	var source_rows: Dictionary={}
	for floor: Dictionary in layout.floors:
		if floor.id!="F01":continue
		for row: Dictionary in floor.furniture:source_rows[str(row.id)]=row
	var tolerance:=float(data.tolerance)
	var counts: Dictionary={};var originals: Dictionary={};var materials: Dictionary=borrowed_materials.duplicate()
	for key: Variant in materials:
		var mat: StandardMaterial3D=materials[key] as StandardMaterial3D
		if mat==null or mat.roughness_texture==null or mat.normal_texture==null:return false
		if mat.albedo_texture==null and (str(key)!="glassish" or mat.transparency not in [BaseMaterial3D.TRANSPARENCY_ALPHA,BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS] or mat.albedo_color.a<=0. or mat.albedo_color.a>=1.):return false
	for box: Dictionary in record.replace:
		if not source_rows.has(str(box.id)):return false
		var source: Dictionary=source_rows[box.id];var r: Array=source.rect
		if str(source.mat)!=str(box.key) or _v(box.low).distance_to(Vector3(r[0],source.z0,-r[3]))>tolerance or _v(box.high).distance_to(Vector3(r[2],float(source.z0)+float(source.h),-r[1]))>tolerance:return false
		counts[str(box.id)]=0
	var replacements: Dictionary={}
	for draw: MeshInstance3D in cell.find_children("*","MeshInstance3D",true,false):
		# Earlier native fittings keep their own geometry/material owner.
		# Only shipping source draws supply authored retirement boundaries.
		if draw.has_meta("material_key"):continue
		var boxes: Array[Dictionary]=[]
		for box: Dictionary in record.replace:
			if str(draw.name).trim_suffix("-col").ends_with("_"+str(box.key)):boxes.append(box)
		if boxes.is_empty():continue
		# Shipping cells quantize positions to their imported AABB. Account for
		# one encoded step while still requiring one outward source boundary.
		var extent:=draw.mesh.get_aabb().size
		var encoded_tolerance:=tolerance+maxf(maxf(extent.x,extent.y),extent.z)/65535.
		var before:=0
		for box: Dictionary in boxes:before+=int(counts[str(box.id)])
		var result:=_without_boxes(draw,boxes,encoded_tolerance,counts)
		if result==null:return false
		var after:=0
		for box: Dictionary in boxes:after+=int(counts[str(box.id)])
		# A source can contain colliding and decorative draws with the same
		# material key. Only the draw that owns a removed boundary is fitted.
		if before==after:continue
		replacements[draw]=result;originals[draw]=draw.mesh
		for box: Dictionary in boxes:
			if draw.mesh.get_surface_count()!=1:return false
			var original:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			if original==null or original.roughness_texture==null or original.normal_texture==null:return false
			# Source drawn glass deliberately carries literal color/alpha and
			# two maps. Preserve that authored optical owner without adding albedo.
			if original.albedo_texture==null and (str(box.key)!="glassish" or original.transparency not in [BaseMaterial3D.TRANSPARENCY_ALPHA,BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS] or original.albedo_color.a<=0. or original.albedo_color.a>=1.):return false
			materials[str(box.key)]=original
	for box: Dictionary in record.replace:
		if counts[str(box.id)]!=int(box.expected_triangles):
			push_error("Shop seating boundary mismatch: "+str(box.id)+" count="+str(counts[str(box.id)]));return false
	var profile_cut := Time.get_ticks_usec()
	# The loader cache is weak. The residency owner releases its prefetched
	# scenes on activation/cancellation; this fitter retains no scene cache.
	var packed:=ResourceLoader.load(str(data.asset),"PackedScene",ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	if packed==null:return false
	var profile_load := Time.get_ticks_usec()
	var model:=packed.instantiate() as Node3D
	var profile_instance := Time.get_ticks_usec()
	if model==null:return false
	model.name=model_name
	var parts: Dictionary={}
	for part: Dictionary in record.parts:
		if parts.has(str(part.name)) or float(part.tile)<=0.:model.free();return false
		if not materials.has(str(part.key)) and (not part.has("catalog_key") or not MatLib.SETS.has(str(part.catalog_key))):model.free();return false
		if part.has("tint"):
			if part.tint is not Array or part.tint.size()!=4:model.free();return false
			for component: Variant in part.tint:
				if (component is not float and component is not int) or not is_finite(float(component)) or float(component)<0. or float(component)>1.:model.free();return false
			if float(part.tint[3])!=1.:model.free();return false
		if part.has("plain_alpha") and (part.plain_alpha is not bool or str(part.key)!="glassish" or part.has("catalog_key")):model.free();return false
		parts[str(part.name)]=part
	var profile_material_us := 0
	var profile_assign_us := 0
	var profile_duplicate_us := 0
	var profile_collision_us := 0
	var profile_mesh_hash_us := 0
	var profile_face_hash_us := 0
	var profile_attach_us := 0
	var mounted: Dictionary={};var local_materials: Dictionary={}
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if not parts.has(str(draw.name)):draw.free();continue
		var material_started:=Time.get_ticks_usec()
		var part: Dictionary=parts[str(draw.name)];var key:=str(part.key)
		var material_slot:=key+"|"+str(part.get("catalog_key",""))+"|"+str(part.tile)+"|"+JSON.stringify(part.get("tint",[]))+"|"+str(part.get("plain_alpha",false))
		if not local_materials.has(material_slot):
			var mat: StandardMaterial3D
			if part.has("catalog_key"):
				var catalog_key:=str(part.catalog_key)
				if not MatLib.SETS.has(catalog_key):model.free();return false
				if absf(float(MatLib.SETS[catalog_key][3])-float(part.tile))>.000001:model.free();return false
				mat=MatLib.get_mat(catalog_key).duplicate() as StandardMaterial3D
			else:mat=materials[key].duplicate() as StandardMaterial3D
			if part.has("tint"):
				var tint: Array=part.tint
				mat.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
			if part.get("plain_alpha",false):mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.uv1_triplanar=false;mat.uv1_scale=Vector3.ONE/float(part.tile)
			local_materials[material_slot]=mat
		profile_material_us+=Time.get_ticks_usec()-material_started
		# Imported mesh buffers remain immutable even when the PackedScene was
		# shared with another cell or prefetch. Only this instance owns the slot.
		var profile_step := Time.get_ticks_usec()
		var native_mesh_source: Mesh=draw.mesh
		var native_surface_buffers: Array=[]
		if native_mesh_source is ArrayMesh and native_mesh_source.get_blend_shape_count()==0 and native_mesh_source.get_script()==null:
			# One renderer-buffer read supplies both the local copy and the exact
			# collision signature. Resource.duplicate followed by another mesh read
			# was a large measured cost for the 164-part druggist fitting.
			native_surface_buffers=native_mesh_source.get("_surfaces")
			draw.mesh=_copy_native_mesh(native_mesh_source,native_surface_buffers,local_materials[material_slot])
		else:
			draw.mesh=native_mesh_source.duplicate() as Mesh
			var assign_started:=Time.get_ticks_usec()
			draw.mesh.surface_set_material(0,local_materials[material_slot])
			profile_assign_us+=Time.get_ticks_usec()-assign_started
		profile_duplicate_us += Time.get_ticks_usec()-profile_step
		# Name retains SurfacePass's retail class and therefore its state owner.
		draw.set_meta(part_meta,str(draw.name));draw.set_meta("material_key",key)
		draw.name=draw_prefix+str(draw.name)
		profile_step = Time.get_ticks_usec()
		var collision_key := str(data.asset)+"::"+str(part.name)
		draw.set_meta("native_collision_key",collision_key)
		var collision_paths: Dictionary=cell.get_meta("native_collision_paths",{})
		if collision_paths.is_empty():
			draw.create_trimesh_collision()
		else:
			if not collision_paths.has(collision_key): model.free(); return false
			var entry: Dictionary=collision_paths[collision_key]
			var shape: ConcavePolygonShape3D = (cell.get_meta("native_collision_shapes",{}) as Dictionary).get(collision_key) as ConcavePolygonShape3D
			# Reusing acceleration data never substitutes a proxy or relaxes fit.
			# Mesh.get_faces itself builds a TriangleMesh BVH. Compare the exact
			# serialized geometry and original face hashes without rebuilding it.
			var cache := preload("res://scripts/building/orison_v2_fitting_collision_cache.gd")
			if shape==null: model.free(); return false
			var checkpoint:=Time.get_ticks_usec()
			var mesh_hash: String=cache.surfaces_signature(native_surface_buffers) if not native_surface_buffers.is_empty() else cache.mesh_signature(draw.mesh)
			profile_mesh_hash_us+=Time.get_ticks_usec()-checkpoint
			checkpoint=Time.get_ticks_usec()
			var face_hash: String=str(entry.face_hash) if int(entry.get("shape_rid",0))==shape.get_rid().get_id() else cache.face_signature(shape)
			profile_face_hash_us+=Time.get_ticks_usec()-checkpoint
			if mesh_hash!=str(entry.mesh_hash) or face_hash!=str(entry.face_hash): model.free(); return false
			checkpoint=Time.get_ticks_usec()
			var body:=StaticBody3D.new();body.name="StaticBody3D"
			var collision:=CollisionShape3D.new();collision.name="CollisionShape3D";collision.shape=shape
			body.add_child(collision);draw.add_child(body)
			profile_attach_us+=Time.get_ticks_usec()-checkpoint
		profile_collision_us += Time.get_ticks_usec()-profile_step
		mounted[str(part.name)]=true
	if mounted.size()!=parts.size():model.free();return false
	var profile_models := Time.get_ticks_usec()
	# Validate collision ownership before altering any imported draw.
	for draw: MeshInstance3D in replacements:
		var collisions:=draw.find_children("*","CollisionShape3D",true,false)
		if collisions.size()!=1 or (collisions[0] as CollisionShape3D).shape is not ConcavePolygonShape3D:model.free();return false
	for draw: MeshInstance3D in replacements:
		draw.mesh=replacements[draw]
		var collision: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
		if draw.mesh.get_surface_count()==0:
			draw.hide();collision.disabled=true
		else:
			var shape:=ConcavePolygonShape3D.new();shape.set_faces(draw.mesh.get_faces());collision.shape=shape
	model.set_meta("original_meshes",originals);model.set_meta("removed_triangles",counts)
	# Dossier slice 69: words on a fitted card or board are Label3D, never texture (RUL-008).
	for label: Variant in record.get("labels",[]):
		if label is not Dictionary or label.get("text") is not String or str(label.text).is_empty() \
				or label.get("at") is not Array or label.at.size()!=3 \
				or (label.get("yaw") is not float and label.get("yaw") is not int):
			model.free();return false
		var words:=Label3D.new()
		words.name="Words_"+str(label.get("id","label"))
		words.text=str(label.text)
		words.font_size=int(label.get("font_size",40))
		words.pixel_size=float(label.get("pixel_size",.0004))
		words.modulate=Color(.07,.06,.05)
		var colour: Variant=label.get("color")
		if colour!=null:
			if colour is not Array or colour.size()!=3:model.free();return false
			for component: Variant in colour:
				if (component is not float and component is not int) or float(component)<0. or float(component)>1.:model.free();return false
			words.modulate=Color(float(colour[0]),float(colour[1]),float(colour[2]))
		words.outline_size=0
		words.double_sided=false
		words.position=_v(label.at)
		words.rotation.y=float(label.yaw)
		model.add_child(words)
	cell.add_child(model)
	if OS.get_environment("ORISON_PROFILE_NATIVE")=="1" or OS.get_environment("ORISON_PROFILE_RESIDENCY")=="1":
		print("NATIVE_FIT_DETAIL ",JSON.stringify({"cell":str(cell.name),"data":data_path,
			"material_ms":profile_material_us/1000.0,"slot_assignment_ms":profile_assign_us/1000.0,"cut_ms":(profile_cut-profile_start)/1000.0,"duplicate_ms":profile_duplicate_us/1000.0,"collision_ms":profile_collision_us/1000.0,"mesh_hash_ms":profile_mesh_hash_us/1000.0,"face_hash_ms":profile_face_hash_us/1000.0,"attach_ms":profile_attach_us/1000.0,"load_ms":(profile_load-profile_cut)/1000.0,
			"instantiate_ms":(profile_instance-profile_load)/1000.0,"model_and_collision_ms":(profile_models-profile_instance)/1000.0,
			"publish_ms":(Time.get_ticks_usec()-profile_models)/1000.0}))
	return true

static func _without_boxes(draw: MeshInstance3D, boxes: Array[Dictionary], tolerance: float, counts: Dictionary, require_boundary := true) -> ArrayMesh:
	var result:=ArrayMesh.new()
	# These transforms and source bounds are invariant for the entire mesh.
	# Avoid inverting the same basis for every triangle corner on each reload.
	var normal_basis := draw.basis.inverse().transposed()
	var lows: Array[Vector3] = []
	var highs: Array[Vector3] = []
	for box: Dictionary in boxes:
		lows.append(_v(box.low)); highs.append(_v(box.high))
	# A source triangle contained by a replacement box has its centroid in
	# that box. Index candidate boxes by metre cell, preserving source order.
	# The exact original containment/boundary predicates still decide removal.
	var candidates := {}
	var indexed := boxes.size()>8
	var bucket_count := 0
	if indexed:
		for i in boxes.size():
			var low := Vector3i((lows[i]-Vector3.ONE*(tolerance+.00001)).floor())
			var high := Vector3i((highs[i]+Vector3.ONE*(tolerance+.00001)).floor())
			bucket_count += (high.x-low.x+1)*(high.y-low.y+1)*(high.z-low.z+1)
			if bucket_count>100000:
				indexed=false; candidates.clear(); break
			for x in range(low.x,high.x+1):
				for y in range(low.y,high.y+1):
					for z in range(low.z,high.z+1):
						var key := Vector3i(x,y,z)
						if not candidates.has(key): candidates[key]=[]
						candidates[key].append(i)
	var source_surfaces: Array=draw.mesh.get("_surfaces")
	var selected_surfaces: Array=[]
	for surface in draw.mesh.get_surface_count():
		var arrays:=draw.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		if normals.size()!=vertices.size():return null
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index in vertices.size():indices.append(index)
		var retained:=PackedInt32Array()
		for start in range(0,indices.size(),3):
			var p: Array[Vector3]=[];var n:=Vector3.ZERO
			for offset in 3:
				var index:=indices[start+offset];p.append(draw.transform*vertices[index]);n+=normal_basis*normals[index]
			if n.length_squared()<.5:return null
			n=n.normalized();var match_id:=""
			var triangle_low := p[0].min(p[1]).min(p[2])
			var triangle_high := p[0].max(p[1]).max(p[2])
			var selected: Variant = candidates.get(Vector3i(((p[0]+p[1]+p[2])/3.0).floor()),[]) if indexed else range(boxes.size())
			for box_index: int in selected:
				var box: Dictionary = boxes[box_index]
				var low := lows[box_index]; var high := highs[box_index]
				var within := triangle_low.x>=low.x-tolerance and triangle_low.y>=low.y-tolerance and triangle_low.z>=low.z-tolerance and triangle_high.x<=high.x+tolerance and triangle_high.y<=high.y+tolerance and triangle_high.z<=high.z+tolerance
				if not within:continue
				if not require_boundary:
					match_id=str(box.id);break
				var axis:=n.abs().max_axis_index()
				if absf(n[axis])<.999:continue
				var plane:=high[axis] if n[axis]>0. else low[axis]
				var boundary:=true
				for point: Vector3 in p:
					if absf(point[axis]-plane)>tolerance:boundary=false
				if not boundary:continue
				if not match_id.is_empty():return null
				match_id=str(box.id)
			if match_id.is_empty():
				for offset in 3:retained.append(indices[start+offset])
			else:counts[match_id]+=1
		if retained.is_empty():continue
		# Array reconstruction would quantize decoded normal/tangent values
		# again. Copy the serialized buffers and decoding metadata verbatim;
		# replace only their independently encoded triangle index selection.
		var packed: Dictionary=source_surfaces[surface].duplicate(true)
		var width: int=packed.index_data.size()/int(packed.index_count)
		if width!=2 and width!=4:return null
		var bytes:=PackedByteArray();bytes.resize(retained.size()*width)
		for index in retained.size():
			if width==2:bytes.encode_u16(index*width,retained[index])
			else:bytes.encode_u32(index*width,retained[index])
		packed.index_data=bytes;packed.index_count=retained.size()
		# Old generated LOD indices include the replaced boxes. The retained
		# surface therefore keeps its exact full-resolution triangles.
		packed.lods={};selected_surfaces.append(packed)
	if not selected_surfaces.is_empty():result.set("_surfaces",selected_surfaces)
	return result

static func _v(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])

static func _copy_native_mesh(source: ArrayMesh,surfaces: Array,first_material: Material=null) -> ArrayMesh:
	var native_mesh_copy:=ArrayMesh.new()
	native_mesh_copy.blend_shape_mode=source.blend_shape_mode
	native_mesh_copy.custom_aabb=source.custom_aabb
	native_mesh_copy.lightmap_size_hint=source.lightmap_size_hint
	native_mesh_copy.shadow_mesh=source.shadow_mesh
	native_mesh_copy.resource_name=source.resource_name
	native_mesh_copy.resource_local_to_scene=source.resource_local_to_scene
	for metadata_key: StringName in source.get_meta_list():native_mesh_copy.set_meta(metadata_key,source.get_meta(metadata_key))
	if first_material!=null and not surfaces.is_empty():
		# Supply the final slot before publishing buffers to RenderingServer.
		# Replacing an uploaded stock slot stalled the measured warm canopy.
		surfaces=surfaces.duplicate()
		var first_surface: Dictionary=surfaces[0].duplicate()
		first_surface["material"]=first_material;surfaces[0]=first_surface
	native_mesh_copy.set("_surfaces",surfaces)
	return native_mesh_copy
