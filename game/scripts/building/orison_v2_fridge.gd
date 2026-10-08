extends "res://scripts/props/fridge_prop.gd"
## The original prop continues to own inventory, randomization, sound and motion.
var native_ready := false

func _build_contents(half_w: float, shelves: Array[float]) -> void:
	var before := get_children()
	super._build_contents(half_w, shelves)
	var items: Array = LARDER.get(unit, LARDER.get("4B", []))
	var added := get_children().filter(func(child): return child not in before)
	assert(added.size() == items.size())
	for i in added.size(): added[i].set_meta("source_larder_item", items[i])

func _build_visual() -> void:
	super._build_visual()
	if has_meta("native_fridge_factory"):
		native_ready = get_meta("native_fridge_factory").install_on(self)
		remove_meta("native_fridge_factory")
