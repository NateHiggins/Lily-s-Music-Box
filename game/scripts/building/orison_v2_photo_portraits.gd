extends RefCounted
## Seven source-owned unclaimed cards; the shared wall law owns their hooks.
const DATA := "res://data/orison_v2/photo_portraits.json"
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")

class Reservations extends RefCounted:
	var bands: Dictionary = {}
	func _notification(what: int) -> void:
		if what != NOTIFICATION_PREDELETE:return
		for key: String in bands:
			if not WallArtLaw._reserved.has(key):continue
			for band: Dictionary in bands[key]:WallArtLaw._reserved[key].erase(band)
			if WallArtLaw._reserved[key].is_empty():WallArtLaw._reserved.erase(key)

static func mount_cell(cell: Node3D, layout: Dictionary, atlas_cache: AtlasCache=null) -> bool:
	if str(cell.name)!="shop_photo_supplies":return true
	var profile_start:=Time.get_ticks_usec()
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var ctx:=context(layout)
	var profile_context:=Time.get_ticks_usec()
	if data is not Dictionary or ctx.is_empty() or cell.has_node("PhotoPortraits"):return _refuse("portrait data/context/model preflight")
	if data.portraits.size()!=7 or data.image_parts.size()!=7 or data.cells.size()!=1:return _refuse("portrait/card/region cardinality")
	var ink: Dictionary=data.image_content
	if str(ink.catalog_role)!="art" or str(ink.substrate_role)!="paper":return _refuse("registered artwork/substrate roles")
	var registry: Dictionary=ink.catalog_binding
	if str(registry.catalog_key)!="art" or str(registry.catalog_mapping)!="ai_materials/art" or FileAccess.get_sha256(str(registry.shipping_albedo))!=str(registry.shipping_albedo_sha256):return _refuse("existing artwork shipping registry/hash")
	var profile_registry:=Time.get_ticks_usec()
	if ink.dimensions is not Array or ink.dimensions.size()!=2 or float(ink.dimensions[0])!=1024. or float(ink.dimensions[1])!=1536. or int(ink.columns)!=2 or int(ink.rows)!=2 or float(ink.roughness)!=.82 or float(ink.uv_inset)!=.005:return _refuse("atlas dimensional/matte preflight")
	var cache: AtlasCache=atlas_cache if atlas_cache!=null else AtlasCache.new()
	var texture:=cache.load_checked(str(ink.resource),str(ink.sha256))
	if not cache.last_source_valid:return _refuse("generated atlas raw hash")
	if cache.last_error=="changed_during_load":return _refuse("atlas import changed during load")
	if texture==null or texture.get_width()!=1024 or texture.get_height()!=1536:return _refuse("imported atlas dimensions")
	var profile_texture:=Time.get_ticks_usec()
	var before:=WallArtLaw._reserved.duplicate(true);var ids: Dictionary={}
	for picture: Dictionary in data.portraits:
		var id:=str(picture.id)
		if ids.has(id) or not ctx.rows.has(id) or str(ctx.rows[id].mat)!="paper" or str(picture.wall)!="east":WallArtLaw._reserved=before;return _refuse("original print identity and backing wall")
		if float(picture.width)!=.160 or float(picture.height)!=.250 or int(picture.atlas_cell)!=ids.size()%4:WallArtLaw._reserved=before;return _refuse("declared print dimensions and four-cell order")
		var position: Array=picture.position
		if position.size()!=3:WallArtLaw._reserved=before;return _refuse("print position arity")
		for value: Variant in position:
			if not is_finite(float(value)):WallArtLaw._reserved=before;return _refuse("finite print pose")
		var height:=float(position[2])-float(ctx.datum);var half_height:=.130
		if height-half_height<float(ctx.lowest) or height+half_height>float(ctx.highest):WallArtLaw._reserved=before;return _refuse("actual backing height envelope")
		var r: Array=ctx.room.rect;var along:=(float(position[1])-float(r[1]))/(float(r[3])-float(r[1]))
		var pose:=WallArtLaw.legal_spot(ctx.proxy,ctx.room,"east",along,height,Callable(),.080,half_height)
		if not bool(pose.get("ok",false)) or Vector3(float(pose.x),float(pose.y),float(pose.height)+float(ctx.datum)).distance_to(Vector3(position[0],position[1],position[2]))>.000003 or absf(angle_difference(float(pose.yaw),float(picture.yaw)))>.000003:WallArtLaw._reserved=before;return _refuse("exact shared wall law returned pose")
		ids[id]=picture
	var profile_wall:=Time.get_ticks_usec()
	if not Seating.mount_photo_portraits(cell,layout):WallArtLaw._reserved=before;return _refuse("shared original-source fitting preflight")
	var profile_generic:=Time.get_ticks_usec()
	var model: Node3D=cell.get_node("PhotoPortraits");var mounted:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var name:=str(draw.get_meta("photo_portraits_part"))
		if name not in data.image_parts:continue
		var paper:=draw.mesh.surface_get_material(0) as StandardMaterial3D
		var art:=paper.duplicate() as StandardMaterial3D
		art.resource_name="LocalUnclaimedPortraitInk";art.albedo_texture=texture;art.albedo_color=Color.WHITE
		var stock:=MatLib.get_mat("paper")
		art.metallic=0.;art.roughness_texture=stock.roughness_texture;art.roughness=float(ink.roughness);art.normal_enabled=true;art.normal_texture=stock.normal_texture;art.normal_scale=.035
		art.uv1_triplanar=false;art.uv1_scale=Vector3.ONE;art.uv1_offset=Vector3.ZERO
		draw.mesh.surface_set_material(0,art);draw.set_meta("material_key","art");draw.set_meta("portrait_content_sha256",str(ink.sha256));mounted+=1
	var profile_materials:=Time.get_ticks_usec()
	assert(mounted==7)
	var reservations:=Reservations.new()
	for key: String in WallArtLaw._reserved:
		var added: Array=WallArtLaw._reserved[key].slice(before.get(key,[]).size())
		if not added.is_empty():reservations.bands[key]=added.duplicate(true)
	model.set_meta("picture_reservations",reservations);model.set_meta("portraits",ids)
	if OS.get_environment("ORISON_PROFILE_NATIVE")=="1" or OS.get_environment("ORISON_PROFILE_RESIDENCY")=="1":
		print("PORTRAIT_FIT_DETAIL ",JSON.stringify({"context_ms":(profile_context-profile_start)/1000.0,"registry_ms":(profile_registry-profile_context)/1000.0,"atlas_hash_ms":cache.last_hash_us/1000.0,"import_guard_ms":cache.last_guard_us/1000.0,"texture_load_ms":cache.last_load_us/1000.0,"atlas_cache":cache.snapshot(),"wall_ms":(profile_wall-profile_texture)/1000.0,"generic_ms":(profile_generic-profile_wall)/1000.0,"materials_ms":(profile_materials-profile_generic)/1000.0,"reservations_ms":(Time.get_ticks_usec()-profile_materials)/1000.0,"total_ms":(Time.get_ticks_usec()-profile_start)/1000.0}))
	return true

static func context(layout: Dictionary) -> Dictionary:
	var floors: Array=layout.get("floors",[]).filter(func(row):return str(row.id)=="F01")
	if floors.size()!=1:return {}
	var rows: Dictionary={}
	for row: Dictionary in floors[0].furniture:rows[str(row.id)]=row
	var prefix:="storm_shop_photo_supplies_"
	for suffix: String in ["floor","back_lo","back_hi","borrowed_glass","db","portrait_rail"]:
		if not rows.has(prefix+suffix):return {}
	var slab: Dictionary=rows[prefix+"floor"];var back: Dictionary=rows[prefix+"back_lo"];var glass: Dictionary=rows[prefix+"borrowed_glass"];var dado: Dictionary=rows[prefix+"db"]
	var datum:=float(slab.z0)+float(slab.h);var r: Array=back.rect;var sr: Array=slab.rect
	var room:={"id":"RETAINED_PHOTO_PORTRAITS","kind":"shop","rect":[sr[0],sr[1],r[0],sr[3]]}
	var proxy:={"z":datum,"rooms":[room],"walls":[{"id":prefix+"back_lo","a":[(r[0]+r[2])*.5,r[1]],"b":[(r[0]+r[2])*.5,r[3]],"t":float(r[2])-float(r[0]),"openings":[{"at":(float(glass.rect[1])+float(glass.rect[3]))*.5-float(r[1]),"w":float(glass.rect[3])-float(glass.rect[1]),"sill":float(glass.z0)-datum,"h":float(glass.h)}]}],"furniture":[]}
	for row: Dictionary in floors[0].furniture:
		var id:=str(row.id)
		if not id.begins_with(prefix) or id.begins_with(prefix+"portrait"):continue
		if id in [prefix+"floor",prefix+"ceil"] or id.begins_with(prefix+"back_"):continue
		var copy:=row.duplicate(true);copy.z0=float(row.get("z0",datum))-datum;proxy.furniture.append(copy)
	return {"rows":rows,"room":room,"proxy":proxy,"datum":datum,"lowest":float(dado.z0)+float(dado.h)-datum+.06,"highest":float(back.z0)+float(back.h)-datum-.10}

static func _refuse(reason: String) -> bool:
	push_error("V2 unclaimed portraits: "+reason)
	return false

class AtlasCache extends RefCounted:
	## One world-owned atlas. Every use rechecks source/import/payload bytes.
	var hits:=0
	var misses:=0
	var invalidations:=0
	var last_hash_us:=0
	var last_guard_us:=0
	var last_load_us:=0
	var last_source_valid:=false
	var last_error:=""
	var _texture: Texture2D
	var _signature: Dictionary={}
	var _dirty:=false
	var _watcher: Callable
	var _loader: Callable

	func _init(loader: Callable=Callable()) -> void:
		_loader=loader

	func load_checked(path: String,expected_sha: String) -> Texture2D:
		last_hash_us=0;last_guard_us=0;last_load_us=0;last_error=""
		var started:=Time.get_ticks_usec()
		var actual:=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		last_hash_us=Time.get_ticks_usec()-started
		last_source_valid=not actual.is_empty() and actual==expected_sha
		if not last_source_valid:
			last_error="source_hash";_invalidate();return null
		started=Time.get_ticks_usec()
		var signature:=_import_signature(path,actual)
		last_guard_us=Time.get_ticks_usec()-started
		if _texture!=null and not _dirty and not signature.is_empty() and signature==_signature:
			hits+=1;return _texture
		_invalidate();misses+=1
		started=Time.get_ticks_usec()
		var texture: Texture2D=_loader.call(path) as Texture2D if _loader.is_valid() else ResourceLoader.load(path,"Texture2D",ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		last_load_us=Time.get_ticks_usec()-started
		if texture==null or texture.get_width()!=1024 or texture.get_height()!=1536:
			last_error="texture_dimensions";return null
		# A first load may overlap an import. Never cache a mixed generation.
		started=Time.get_ticks_usec()
		var after_sha:=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		var after:=_import_signature(path,after_sha)
		last_guard_us+=Time.get_ticks_usec()-started
		if after_sha!=actual or after!=signature:
			last_source_valid=after_sha==expected_sha
			last_error="changed_during_load";return null
		if not signature.is_empty():
			_texture=texture;_signature=signature;_dirty=false
			_watcher=_mark_dirty.bind(weakref(self));_texture.changed.connect(_watcher)
		return texture

	func _invalidate() -> void:
		if _texture!=null:invalidations+=1
		clear()

	func clear() -> void:
		if _texture!=null and _watcher.is_valid() and _texture.changed.is_connected(_watcher):_texture.changed.disconnect(_watcher)
		_texture=null;_signature={};_dirty=false;_watcher=Callable()

	func snapshot() -> Dictionary:
		return {"hits":hits,"misses":misses,"invalidations":invalidations,"textures_kept":1 if _texture!=null else 0,"dirty":_dirty}

	static func _mark_dirty(reference: WeakRef) -> void:
		var cache: RefCounted=reference.get_ref()
		if cache!=null:cache._dirty=true

	func _notification(what: int) -> void:
		if what==NOTIFICATION_PREDELETE:
			# Avoid method calls on self after RefCounted reaches zero.
			if _texture!=null and _watcher.is_valid() and _texture.changed.is_connected(_watcher):_texture.changed.disconnect(_watcher)

	static func _import_signature(path: String,source_sha: String) -> Dictionary:
		var sidecar:=path+".import"
		if not FileAccess.file_exists(sidecar):return {}
		var text:=FileAccess.get_file_as_string(sidecar).replace("\r\n","\n")
		var config:=ConfigFile.new()
		if config.parse(text)!=OK or not config.has_section("remap") or not config.has_section("deps"):return {}
		if str(config.get_value("deps","source_file",""))!=path:return {}
		var paths: Array[String]=[]
		for key: String in config.get_section_keys("remap"):
			if key!="path" and not key.begins_with("path."):continue
			var value: Variant=config.get_value("remap",key)
			if value is not String:return {}
			if value not in paths:paths.append(value)
		var destinations: Variant=config.get_value("deps","dest_files",[])
		if destinations is not Array and destinations is not PackedStringArray:return {}
		for value: Variant in destinations:
			if value is not String:return {}
			if value not in paths:paths.append(value)
		if paths.is_empty():return {}
		var payloads: Dictionary={}
		for payload: String in paths:
			if not FileAccess.file_exists(payload):return {}
			var digest:=FileAccess.get_sha256(payload)
			if digest.is_empty():return {}
			payloads[payload]=digest
		return {"source":path,"source_sha":source_sha,"import_sha":text.sha256_text(),"payloads":payloads}
