extends Node
## Resolver projection only; immutable measured receipt is the independent oracle.
const Resolver := preload("res://scripts/building/orison_v2_exterior_spatial_resolver.gd")
const RECEIPT_SHA := "b114b92409efd8f25ac1d19fa3cca91f124a515ec9b56d5eedf3bb1cc6c6220e"
const NAMES := ["wait_front","wait_rear","access_front","access_rear","service_turn","entry_turn","overflow","overflow_approach"]
const SOURCES := ["res://tests/bodega_resident_placement_resolver_test.gd", "res://tests/BodegaResidentPlacementResolverTest.tscn",
	"res://data/orison_v2/exterior/regions.json", "res://scripts/building/orison_v2_exterior_spatial_resolver.gd",
	"res://scripts/building/orison_v2_frame_contract.gd", "res://data/orison_v2_shared_frames.json",
	"res://scripts/building/orison_v2_street_frame.gd", "res://data/orison_v2/exterior/street_frame.json",
	"res://scripts/reality/corruption_lineage_registry.gd", "res://data/corruption_lineages.json", "res://tests/guide_bell_error_capture.gd"]
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var rows: Array[Dictionary] = []
func _check(ok: bool, label: String) -> bool:
	checks.append({"ok":ok,"label":label})
	if not ok: failures.append(label); push_error("BODEGA RESOLVER: "+label)
	return ok
func _hashes() -> Dictionary:
	var result := {}
	for path: String in SOURCES:
		result[path]=FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text() if FileAccess.file_exists(path) else ""
	return result
func _vector(raw: Variant) -> Vector3:
	var bits:=str(raw).trim_prefix("(").trim_suffix(")").split(",")
	if bits.size()!=3: return Vector3.INF
	for bit: String in bits:
		if not bit.strip_edges().is_valid_float(): return Vector3.INF
	return Vector3(float(bits[0]),float(bits[1]),float(bits[2]))
func _ready() -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory)!=OK: get_tree().quit(2); return
	var logger:=preload("res://tests/guide_bell_error_capture.gd").new(); OS.add_logger(logger)
	var inputs:=_hashes()
	for path: String in SOURCES: _check(not str(inputs[path]).is_empty(),"bound source exists "+path)
	var reference_path:=OS.get_environment("ORISON_BODEGA_GEOMETRY_RECEIPT")
	var reference_ok:=not reference_path.is_empty() and FileAccess.file_exists(reference_path) and FileAccess.get_sha256(reference_path)==RECEIPT_SHA
	_check(reference_ok,"exact preserved waiting_geometry_01 receipt supplied")
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(reference_path)) if reference_ok else {}
	_check(receipt is Dictionary and receipt.get("status")=="PASS" and receipt.get("failures",["missing"]).is_empty(),"independent geometry receipt passed")
	var resolver: Variant=Resolver.load_default()
	if _check(resolver!=null and resolver.is_valid(),"real installed source resolver loads") and reference_ok:
		var frame: Transform3D=resolver.instance_world_transform("SHOP_BODEGA")
		var measurements: Dictionary={}
		for row: Dictionary in receipt.get("details",{}).get("candidate_standing",[]): measurements[str(row.id)]=row
		for name: String in NAMES:
			if not _check(measurements.has(name),"original measured candidate exists "+name): continue
			var resolved: Dictionary=resolver.resolve_placement("SHOP_BODEGA","resident_"+name)
			if not _check(not resolved.is_empty(),"actual registered placement resolves "+name): continue
			var expected: Dictionary=measurements[name]; var local: Vector3=frame.affine_inverse()*resolved.position
			var local_error:=local.distance_to(_vector(expected.local)); var world_error: float=resolved.position.distance_to(_vector(expected.authored))
			var feet:=_vector(expected.feet); var xz_error:=Vector2(resolved.position.x-feet.x,resolved.position.z-feet.z).length()
			_check(local_error<.00001 and world_error<.00001 and xz_error<.00001 and resolved.surface_id=="floor","real local/world projection matches measured record "+name)
			rows.append({"id":"resident_"+name,"actual":resolved,"local":local,"measured":expected,"local_error":local_error,
				"world_error":world_error,"floor_projected_xz_error":xz_error,"authored_minus_measured_floor_y":resolved.position.y-feet.y})
	_check(rows.size()==8,"all eight real placements compared")
	_check(inputs==_hashes() and (not reference_ok or FileAccess.get_sha256(reference_path)==RECEIPT_SHA),"sources/reference stable")
	var errors: Array=[]
	for error: String in logger.errors:
		if not error.contains("BODEGA RESOLVER:"): errors.append(error)
	_check(errors.is_empty(),"no unexpected engine errors"); OS.remove_logger(logger)
	var result: Dictionary={"schema_version":2,"evidence_kind":"diagnostic","production_runtime":false,"status":"PASS" if failures.is_empty() else "FAIL",
		"scope":"real resolver only; projection against preserved measured receipt, no physics/motor/admission proof; independent motor02 is a separate receipt",
		"reference_sha256":RECEIPT_SHA,"source_hashes":inputs,"rows":rows,"checks":checks,"failures":failures,"engine_errors":errors}
	var file:=FileAccess.open(directory.path_join("placement_resolver.json"),FileAccess.WRITE)
	if file==null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result,"\t")); file.flush(); var written:=file.get_error()==OK; file.close()
	get_tree().quit(0 if failures.is_empty() and written else 1)
