extends "res://scripts/props/fridge_prop.gd"
## The original prop continues to own inventory, randomization, sound and motion.
var native_ready := false
var _native_factory: Variant
var _contents_args: Array = []

func _build_contents(half_w: float, shelves: Array[float]) -> void:
	_contents_args = [half_w, shelves]
	var before := get_children()
	super._build_contents(half_w, shelves)
	var items: Array = larder_items if larder_bound else LARDER.get(unit, LARDER.get("4B", []))
	var added := get_children().filter(func(child): return child not in before)
	assert(added.size() == items.size())
	for i in added.size(): added[i].set_meta("source_larder_item", items[i])

func _build_visual() -> void:
	super._build_visual()
	if has_meta("native_fridge_factory"):
		_native_factory = get_meta("native_fridge_factory")
		native_ready = _native_factory.install_on(self)
		remove_meta("native_fridge_factory")

## Restock the shelves from the household larder: the old food leaves, the
## rows given are built and dressed in their native food stock.
func show_larder(items: Array) -> bool:
	if _contents_args.is_empty() or (larder_bound and items == larder_items):
		return native_ready
	for child: Node in get_children():
		if child.has_meta("source_larder_item"):
			remove_child(child)
			child.queue_free()
	larder_items = items.duplicate(true)
	larder_bound = true
	_build_contents(float(_contents_args[0]), _contents_args[1])
	if _native_factory != null:
		native_ready = _native_factory.install_foods(self)
	return native_ready
