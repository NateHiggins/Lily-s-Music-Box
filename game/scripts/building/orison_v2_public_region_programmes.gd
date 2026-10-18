extends RefCounted
## Public spatial ownership for retained modules; no simulation or save authority.
const PATH="res://data/orison_v2/exterior/public_region_programmes.json"
const Resolver=preload("res://scripts/building/orison_v2_exterior_spatial_resolver.gd")
var errors: Array[String]=[]
var _source: Dictionary={}
var _resolver: Variant
var _owners: Dictionary={}

static func read_default() -> Dictionary:
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return value if value is Dictionary else {}

static func load_default() -> Variant:
	var result=load("res://scripts/building/orison_v2_public_region_programmes.gd").new()
	return result if result.configure(Resolver.load_default()) else null

func configure(resolver: Variant,source: Dictionary={}) -> bool:
	errors.clear();_owners.clear();_source.clear();_resolver=null
	if source.is_empty():source=read_default()
	if resolver==null or not resolver.is_valid() or int(source.get("schema_version",0))!=1:return false
	var keys:=source.keys();keys.sort()
	if keys!=["bounded_instance_ids","modules","schema_version"] or source.bounded_instance_ids is not Array or source.modules is not Array:return false
	var seen: Dictionary={}
	for identity: Variant in source.bounded_instance_ids:
		if identity is not String or str(identity).is_empty() or seen.has(identity) or resolver.instance_record(identity).is_empty():return false
		seen[identity]=true
	if seen.is_empty() or source.modules.size()!=4:return false
	var regions: Dictionary={}
	for module: Variant in source.modules:
		if module is not Dictionary:return false
		keys=module.keys();keys.sort()
		if keys!=["geometry_paths","instance_id","owner_node","region_id","source_origin_m"]:return false
		var instance: Dictionary=resolver.instance_record(str(module.instance_id))
		if seen.has(str(module.instance_id)) or instance.is_empty() or str(instance.region_id)!=str(module.region_id) or regions.has(str(module.region_id)):return false
		if str(module.owner_node) not in ["StreetBoundaries","VantryArcade"] or module.geometry_paths is not Array or module.geometry_paths.is_empty():return false
		for path: Variant in module.geometry_paths:
			if path is not String or str(path).is_empty() or str(path).contains(".."):return false
		if module.source_origin_m is not Array or module.source_origin_m.size()!=3:return false
		for value: Variant in module.source_origin_m:
			if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)):return false
		regions[str(module.region_id)]=true;seen[str(module.instance_id)]=true
	if regions.keys().size()!=4 or seen.size()!=resolver.instance_ids().size():return false
	for identity: String in resolver.instance_ids():
		if not seen.has(identity):return false
	_source=source.duplicate(true);_resolver=resolver
	for owner: String in ["StreetBoundaries","VantryArcade"]:
		if not body_transform(owner).origin.is_finite():teardown();return false
	return true

func bounded_instance_ids() -> Array:
	return _source.get("bounded_instance_ids",[]).duplicate()

func body_transform(owner: String) -> Transform3D:
	var found:=false;var result:=Transform3D.IDENTITY
	for module: Dictionary in _source.get("modules",[]):
		if str(module.owner_node)!=owner:continue
		var at: Array=module.source_origin_m
		var current: Transform3D=_resolver.instance_world_transform(str(module.instance_id))*Transform3D(Basis.IDENTITY,-Vector3(at[0],at[1],at[2]))
		if not current.origin.is_finite() or (found and not result.is_equal_approx(current)):return Transform3D(Basis.IDENTITY,Vector3.INF)
		if not found:result=current
		found=true
	return result if found else Transform3D(Basis.IDENTITY,Vector3.INF)

func bind(world: Node3D) -> bool:
	_owners.clear()
	for module: Dictionary in _source.get("modules",[]):
		var owner:=world.get_node_or_null(str(module.owner_node)) as Node3D
		if owner==null or not owner.global_transform.is_equal_approx(world.global_transform*body_transform(str(module.owner_node))):return false
		for path: String in module.geometry_paths:
			var geometry:=owner.get_node_or_null(path) as Node3D
			if geometry==null or geometry.find_children("*","MeshInstance3D",true,false).is_empty():return false
		_owners[str(module.region_id)]=weakref(owner)
	return _owners.size()==_source.modules.size()

func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for module: Dictionary in _source.get("modules",[]):
		var reference: WeakRef=_owners.get(str(module.region_id))
		var owner: Node3D=reference.get_ref() as Node3D if reference!=null else null
		var resident:=owner!=null and owner.is_inside_tree()
		if resident:
			for path: String in module.geometry_paths:resident=resident and owner.has_node(path)
		result.append({"region_id":str(module.region_id),"instance_id":str(module.instance_id),"resident":resident,"owner":owner})
	return result

func route(identity: String) -> Dictionary:
	return _resolver.resolve_route(identity) if _resolver!=null else {}

func teardown() -> void:
	_owners.clear();_source.clear();_resolver=null
