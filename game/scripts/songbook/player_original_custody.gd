extends RefCounted
## Physical custody only. The private recording store verifies the edition on KEEP
## or explicit import. This campaign retains its two local IDs and its location.
const CaseGrid := preload("res://scripts/game/carried_case.gd")


static func item_id(id: String) -> String:
	return "" if CaseGrid.recorded_song_id(id).is_empty() else CaseGrid.RECORDED_TRACE_PREFIX + id


static func id_from_item(item: String) -> String:
	if not item.begins_with(CaseGrid.RECORDED_TRACE_PREFIX):
		return ""
	var id := item.trim_prefix(CaseGrid.RECORDED_TRACE_PREFIX)
	return "" if CaseGrid.recorded_song_id(id).is_empty() else id


static func _book() -> Dictionary:
	return RealityState.data.get(CaseGrid.KEY, {})


static func song_id(id: String) -> String:
	return _book().get(CaseGrid.RECORDED_ORIGINALS, {}).get("editions", {}).get(id, "")


static func tray_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(_book().get(CaseGrid.RECORDED_ORIGINALS, {}).get("tray", []))
	return result


static func top_id() -> String:
	var tray: Array = _book().get(CaseGrid.RECORDED_ORIGINALS, {}).get("tray", [])
	return "" if tray.is_empty() else tray.back()


## A restored household validates its incoming case, which need not be the live case.
static func case_contains(grid: Variant, id: String) -> bool:
	var item := item_id(id)
	if item.is_empty() or grid is not Dictionary or grid.get("places") is not Dictionary:
		return false
	var originals: Variant = grid.get(CaseGrid.RECORDED_ORIGINALS)
	var place: Variant = grid.places.get(item)
	return originals is Dictionary and originals.get("editions") is Dictionary \
			and originals.editions.get(id) == CaseGrid.recorded_song_id(id) \
			and originals.get("tray") is Array and not originals.tray.has(id) \
			and place is Dictionary and place.get("form") == CaseGrid.FOUND_TRACE_FORM


static func is_packed(id: String) -> bool:
	return case_contains(_book(), id)


static func packed_ids() -> Array[String]:
	var ids: Array[String] = []
	for item: String in _book().get("places", {}):
		var id := id_from_item(item)
		if not id.is_empty():
			ids.append(id)
	return ids


## An acknowledged retry must never put an already packed or returned sheet back
## on top. The caller supplies a verified receipt. No private media is enumerated.
static func admit(edition: Dictionary) -> bool:
	var id: Variant = edition.get("version_id")
	var song: Variant = edition.get("base_song_id")
	if edition.get("publish") != "PRIVATE" or id is not String or song is not String \
			or song.is_empty() or CaseGrid.recorded_song_id(id) != song:
		return false
	if not song_id(id).is_empty():
		return song_id(id) == song
	var prepare := func(document: Dictionary) -> bool:
		var grid: Dictionary = document.get_or_add(CaseGrid.KEY, {"version": 1, "places": {}})
		if not CaseGrid.valid(grid):
			return false
		var originals: Dictionary = grid.get_or_add(CaseGrid.RECORDED_ORIGINALS, {"editions": {}, "tray": []})
		if originals.editions.has(id):
			return false
		originals.editions[id] = song
		originals.tray.append(id)
		return true
	return RealityState.commit_case_and_household(prepare)


static func take(id: String) -> bool:
	if id.is_empty() or top_id() != id:
		return false
	var prepare := func(document: Dictionary) -> bool:
		var grid: Dictionary = document.get(CaseGrid.KEY, {})
		if not CaseGrid.valid(grid) or not grid.has(CaseGrid.RECORDED_ORIGINALS):
			return false
		var tray: Array = grid[CaseGrid.RECORDED_ORIGINALS].tray
		if tray.is_empty() or tray.back() != id:
			return false
		var item := item_id(id)
		var place := CaseGrid.first_fit(item, CaseGrid.FOUND_TRACE_FORM, grid.places)
		if place.is_empty():
			return false
		grid.places[item] = place
		tray.pop_back()
		return true
	return RealityState.commit_case_and_household(prepare)


static func return_to_tray(id: String) -> bool:
	var item := item_id(id)
	if item.is_empty() or CaseGrid.hand() != item:
		return false
	var prepare := func(document: Dictionary) -> bool:
		var grid: Dictionary = document.get(CaseGrid.KEY, {})
		if not CaseGrid.valid(grid) or CaseGrid.hand(document) != item or not grid.places.has(item):
			return false
		grid.places.erase(item)
		grid[CaseGrid.RECORDED_ORIGINALS].tray.append(id)
		grid[CaseGrid.HAND] = ""
		return true
	return RealityState.commit_case_and_household(prepare)
