extends "res://scripts/characters/cast_model_presentation.gd"
## Same staff presentation actor with a source-bound sampled standing column.
## No physics body or route; readers retain the existing timed squeeze policy.
## Root calls bind_standing_profiles AFTER actual load/dressing/grounding succeeds.
const ProfileBinding := preload("res://scripts/characters/harukiya_staff_profile_binding.gd")
const PROFILE_PATH := "res://data/characters/harukiya_staff_standing_columns.json"

func load_standing_profiles() -> bool:
	var text := FileAccess.get_file_as_string(PROFILE_PATH).replace("\r\n", "\n")
	if text.sha256_text() != ProfileBinding.PROFILE_SHA256:return false
	var document: Variant = JSON.parse_string(text)
	return document is Dictionary and bind_standing_profiles(document)

var resident_id: String:
	get: return person_id
var _standing_profiles: Array[Dictionary] = []

func _same_parts(a: Array, b: Array) -> bool:
	var left:=a.duplicate(); var right:=b.duplicate(); left.sort(); right.sort()
	return left==right

func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _source_matches(path: String, binding: Dictionary) -> bool:
	if not path.begins_with("res://") or not FileAccess.file_exists(path): return false
	var signature: String
	if binding.get("kind","")=="raw": signature=FileAccess.get_sha256(path)
	else:
		var text:=FileAccess.get_file_as_string(path).replace("\r\n","\n")
		if binding.get("kind","")=="params_lf":
			if text.count("[params]")!=1:return false
			text=text.get_slice("[params]",1)
		elif binding.get("kind","")!="lf": return false
		signature=text.sha256_text()
	return signature==str(binding.get("sha256",""))

func bind_standing_profiles(document: Dictionary) -> bool:
	# Direct callers must bind the same sealed shipped document as the loader;
	# an export must never accept an arbitrary replacement radius/wardrobe.
	var canonical := FileAccess.get_file_as_string(PROFILE_PATH).replace("\r\n", "\n")
	if canonical.sha256_text() != ProfileBinding.PROFILE_SHA256 or JSON.parse_string(canonical) != document:return false
	if not _standing_profiles.is_empty() or not ready_ok or person_id not in ["stacy","lily","adela_voss"]: return false
	if document.get("schema_version",0)!=1 or document.get("shape","")!="standing_column" or document.get("units","")!="metres": return false
	if not document.get("profiles") is Array:return false
	for candidate in document.profiles:
		if not candidate is Dictionary:return false
	var rows: Array[Dictionary]=[]
	var checked: Dictionary={}
	for row: Dictionary in document.get("profiles",[]):
		if row.get("person","")!=person_id:continue
		if row.get("model","")!=_source_model or row.get("stand_pose","")!=_pose_name:return false
		var base: Variant=row.get("base_local")
		if not base is Array or base.size()!=3:return false
		for value in base:
			if not _finite_number(value):return false
		if not _finite_number(row.get("radius")) or float(row.radius)<=0.0:return false
		if not _finite_number(row.get("height")) or float(row.height)<=0.0:return false
		if not row.get("parts") is Array or row.parts.is_empty():return false
		for part in row.parts:
			if not part is String:return false
		for previous: Dictionary in rows:
			if _same_parts(previous.parts,row.parts):return false
		if not row.get("source_bindings") is Array or row.source_bindings.is_empty():return false
		var model_bound := false
		var row_paths: Dictionary = {}
		for entry in row.source_bindings:
			if not entry is Dictionary or not entry.get("path") is String:return false
			var path: String = entry.path
			if row_paths.has(path):return false
			row_paths[path] = true
			model_bound = model_bound or path == _source_model
			var binding: Dictionary = {"kind":entry.get("kind", ""),"sha256":entry.get("sha256", "")}
			if checked.has(path):
				if checked[path]!=binding:return false
			# Export templates read the compiled binding validated by the export
			# preflight; source .gd/glTF/.import files are stripped from packs.
			elif not OS.has_feature("template") and not _source_matches(path,binding):return false
			checked[path]=binding
		if not model_bound:return false
		rows.append(row.duplicate(true))
	if rows.size()!=(1 if person_id=="adela_voss" else 2):return false
	_standing_profiles=rows
	if _profile_for(worn_parts()).is_empty():_standing_profiles.clear();return false
	_sync_occupancy_group()
	return true

func _profile_for(parts: Array) -> Dictionary:
	for row: Dictionary in _standing_profiles:
		if row.model==_source_model and row.stand_pose==_pose_name and _same_parts(row.parts,parts):return row
	return {}

func standing_occupancy() -> Dictionary:
	if not ready_ok or not _active or not is_inside_tree() or not is_visible_in_tree() or clip_driven:return {}
	var row:=_profile_for(worn_parts())
	if row.is_empty():return {}
	# These reviewed columns are world-vertical under unit yaw/translation only.
	if not global_transform.is_finite() or not global_basis.is_equal_approx(global_basis.orthonormalized()) or global_basis.determinant()<=0.0 or not global_basis.y.is_equal_approx(Vector3.UP):return {}
	var b: Array=row.base_local
	return {"base":global_transform*Vector3(float(b[0]),float(b[1]),float(b[2])),"radius":float(row.radius),"height":float(row.height)}

func _sync_occupancy_group() -> void:
	# Once bound, an unexpected active mismatch stays discoverable so the shared
	# reader sees {} as INVALID instead of silently losing a visible person's body.
	var should_join:=ready_ok and _active and not _standing_profiles.is_empty() and is_inside_tree()
	if should_join and not is_in_group("animated_residents"):add_to_group("animated_residents")
	elif not should_join and is_in_group("animated_residents"):remove_from_group("animated_residents")

func set_active(enabled: bool) -> void:
	super.set_active(enabled)
	_sync_occupancy_group()

func wear(parts: Array) -> bool:
	if not _standing_profiles.is_empty() and _profile_for(parts).is_empty():
		last_refusal="No measured standing-column family for requested outfit"
		return false
	var changed:=super.wear(parts)
	_sync_occupancy_group()
	return changed

func _fail(message: String) -> void:
	super._fail(message)
	_sync_occupancy_group()

func _exit_tree() -> void:
	if is_in_group("animated_residents"):remove_from_group("animated_residents")
