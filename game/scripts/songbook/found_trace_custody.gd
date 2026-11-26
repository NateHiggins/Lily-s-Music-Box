extends RefCounted
## An original is at its fixed deposit until the player's case contains its id.
## Listing traces at the reader must never initialize or change a campaign save.

const CaseGrid := preload("res://scripts/game/carried_case.gd")
const Forge := preload("res://scripts/songbook/phonautogram_forge.gd")


static func item_id(trace_id: String) -> String:
	return CaseGrid.FOUND_TRACE_PREFIX + trace_id if Forge.FOUND.has(trace_id) else ""


static func is_packed(trace_id: String) -> bool:
	var item := item_id(trace_id)
	var grid: Variant = RealityState.data.get(CaseGrid.KEY)
	if item.is_empty() or grid is not Dictionary or grid.get("places") is not Dictionary:
		return false
	var place: Variant = grid.places.get(item)
	return place is Dictionary and place.get("form") == CaseGrid.FOUND_TRACE_FORM


static func held_ids() -> Array[String]:
	var ids: Array[String] = []
	for trace_id: String in Forge.FOUND:
		if is_packed(trace_id):
			ids.append(trace_id)
	return ids


static func take(trace_id: String) -> bool:
	return _transfer(trace_id, true)


static func return_to_source(trace_id: String) -> bool:
	return _transfer(trace_id, false)


static func _transfer(trace_id: String, packing: bool) -> bool:
	var item := item_id(trace_id)
	if item.is_empty() or is_packed(trace_id) == packing:
		return false
	var prepare := func(document: Dictionary) -> bool:
		var grid: Variant = document.get_or_add(CaseGrid.KEY, {"version": 1, "places": {}})
		if not CaseGrid.valid(grid) or grid.places.has(item) == packing:
			return false
		if packing:
			var place := CaseGrid.first_fit(item, CaseGrid.FOUND_TRACE_FORM, grid.places)
			if place.is_empty():
				return false
			grid.places[item] = place
		else:
			grid.places.erase(item)
			if grid.get(CaseGrid.HAND) == item:
				grid[CaseGrid.HAND] = ""
		return true
	return RealityState.commit_case_and_household(prepare)
