extends RefCounted
## Source-owned News/Cigars fittings; existing transactions and locks retain authority.
const COUNTER_TOP := "storm_shop_news_cigars_counter_top"

static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if not preload("res://scripts/building/orison_v2_shop_seating.gd").mount_news(cell,layout): return false
	return mount_rack(cell,layout)


## The papers control on the counter top (design/ORISON_NEWSPAPERS_2026-10-23.md
## §6), placed from the authored counter record; no newsprint is drawn here.
static func mount_rack(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name) != "shop_news_cigars": return true
	if cell.has_node("NewsRack"): return true
	for floor: Dictionary in layout.get("floors", []):
		if str(floor.get("id", "")) != "F01": continue
		for row: Dictionary in floor.get("furniture", []):
			if str(row.get("id", "")) != COUNTER_TOP: continue
			var rect: Array = row.get("rect", [])
			if rect.size() != 4: return false
			var rack := NewsRackProp.new()
			rack.name = "NewsRack"
			rack.setup("counter", Vector3(absf(float(rect[2]) - float(rect[0])), 0.3, 0.7))
			cell.add_child(rack)
			var centre := GameBoot.b2g([(float(rect[0]) + float(rect[2])) * 0.5,
					(float(rect[1]) + float(rect[3])) * 0.5, 1.0])
			rack.position = cell.to_local(centre) if cell.is_inside_tree() else centre
			return true
	return false
