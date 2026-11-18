extends RefCounted
## Spatial patches only. The immutable fabrication data and all non-spatial
## transaction, publication, hour, light and inventory fields retain authority.
const DATA := "res://data/orison_v2/arcade_actor_projection.json"
const SOURCE := "res://data/building_layout.json"
var errors: Array[String] = []

func _fail(message: String) -> Dictionary:
	errors.append(message)
	return {}

func prepare(spec: Dictionary) -> Dictionary:
	errors.clear()
	if spec.get("schema") != "orison.v2.arcade-actor-projection.v1" or spec.get("markers") is not Array or spec.get("anchors") is not Array:
		return _fail("invalid actor projection declaration")
	var text := FileAccess.get_file_as_string(SOURCE).replace("\r\n","\n")
	if text.sha256_text() != str(spec.get("source_sha256_lf", "")):
		return _fail("actor fabrication source changed")
	var layout: Dictionary = JSON.parse_string(text)
	var source_markers := {}
	var source_anchors := {}
	for floor: Dictionary in layout.floors:
		if floor.id != "F01": continue
		for marker: Dictionary in floor.markers:
			if str(marker.get("zone","")) == "PASSAGE" and str(marker.kind) in ["passage_shop_hours","shop_sign","cage_bulb"] and str(marker.id).begins_with("SITE_SHOP_"):
				source_markers[str(marker.id)] = marker
		for record: Dictionary in floor.furniture:
			if str(record.id) in ["storm_shop_hardware_paint_counter_top","storm_shop_news_cigars_counter_top"]: source_anchors[str(record.id)] = record
	if source_markers.size() != 61 or source_anchors.size() != 2 or spec.markers.size() != 61 or spec.anchors.size() != 2:
		return _fail("incomplete original shop actor/anchor coverage")
	var seen := {}
	for row: Dictionary in spec.markers:
		var identity := str(row.get("id",""))
		if seen.has(identity) or not source_markers.has(identity) or row.get("patch") is not Dictionary:
			return _fail("unknown/duplicate shop actor patch")
		var original: Dictionary = source_markers[identity]
		if str(row.get("kind","")) != str(original.kind): return _fail("shop actor kind changed")
		var allowed := ["pos","yaw_deg"]
		if original.kind == "passage_shop_hours": allowed.append("w")
		if original.kind == "shop_sign": allowed.append_array(["half_width","blade_dx"])
		if row.patch.size() != allowed.size(): return _fail("incomplete/spurious actor spatial fields")
		for key: String in row.patch:
			if key not in allowed: return _fail("non-spatial actor authority change")
			var value: Variant = row.patch[key]
			if key == "pos":
				if value is not Array or value.size()!=3: return _fail("invalid actor position")
				for component: Variant in value:
					if typeof(component) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(component)): return _fail("nonfinite actor position")
			elif typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)):
				return _fail("invalid spatial scalar")
			elif key in ["w","half_width"] and float(value)<=0: return _fail("nonpositive actor extent")
		seen[identity]=true
		original.merge(row.patch.duplicate(true),true)
	seen.clear()
	for row: Dictionary in spec.anchors:
		var identity := str(row.get("id",""))
		if seen.has(identity) or not source_anchors.has(identity) or row.get("patch") is not Dictionary: return _fail("unknown/duplicate transaction anchor")
		if row.patch.size()!=2 or not row.patch.has("rect") or not row.patch.has("z0"): return _fail("non-spatial transaction authority change")
		var rect: Variant = row.patch.rect
		if rect is not Array or rect.size()!=4: return _fail("invalid transaction rectangle")
		for component: Variant in rect:
			if typeof(component) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(component)): return _fail("nonfinite transaction rectangle")
		if float(rect[2])<=float(rect[0]) or float(rect[3])<=float(rect[1]) or typeof(row.patch.z0) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(row.patch.z0)): return _fail("invalid transaction bounds")
		var original: Dictionary = source_anchors[identity]
		original.merge(row.patch.duplicate(true),true)
		seen[identity]=true
	return layout
