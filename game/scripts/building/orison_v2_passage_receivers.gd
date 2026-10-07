extends ArcadeRow
## Receiving props retain the catalogue, mechanisms and authored chassis poses.
## Their actors persist with doors while the imported shop geometry streams.

var _mounted := false
var _enabled := true

func mount(layout: Dictionary, actors: Node3D, batches: Array, enabled: bool = true) -> bool:
	if actors == null or _mounted or not cabinets.is_empty(): return false
	_mounted = true
	_enabled = enabled
	if not enabled: return true
	_catalog = ArcadeCatalog.load_catalog()
	if _catalog == null or _catalog.size() == 0: return false
	var order := _catalog.spread()
	if order.is_empty(): return false
	var source_order := 0
	var identities := {}
	# Walk the complete original row, including the basement and bar. Filtering
	# shops must not reset the catalogue index or give a cabinet another card.
	for floor: Dictionary in layout.floors:
		for furniture: Dictionary in floor.get("furniture", []):
			if str(furniture.get("asm", "")) != ASM: continue
			var card: Dictionary = order[source_order % order.size()]
			var card_order := source_order
			source_order += 1
			if str(floor.id) != "F01" or str(furniture.get("batch", "")) not in batches: continue
			var identity := str(furniture.id)
			if identities.has(identity) or actors.has_node("Arcade_" + identity): return false
			identities[identity] = true
			var prop := ArcadeCabinetProp.new()
			prop.name = "Arcade_" + identity
			prop.prop_type = "monitor"
			prop.configure(card, int(furniture.get("variant", 0)))
			var at: Array = furniture.at
			prop.position = GameBoot.b2g([float(at[0]), float(at[1]),
				float(floor.z) + float(furniture.get("z0", 0.0))])
			prop.rotation.y = deg_to_rad(float(furniture.get("yaw", 0))) + PI
			prop.set_meta("receiving_source_id", identity)
			prop.set_meta("receiving_source_order", card_order)
			actors.add_child(prop)
			cabinets.append(prop)
	return not cabinets.is_empty()

func bind_registered_graph() -> bool:
	# The bar registers its retained graph mouths after the passage mounts.
	# Resolve only after both regions occupy their final shared world frame.
	if _mounted and not _enabled: return cabinets.is_empty()
	for prop in cabinets:
		prop.graph_node_id = _nearest_graph_node(prop.global_position)
		if prop.graph_node_id.is_empty(): return false
	return not cabinets.is_empty()

func has_focused_panel() -> bool:
	for prop in cabinets:
		if prop._playing(): return true
	return false

func suspend() -> void:
	for prop in cabinets: prop.suspend_receiving()

func shutdown() -> void:
	for prop in cabinets:
		if prop._playing(): prop._panel_ui.close()
		prop.process_mode = Node.PROCESS_MODE_DISABLED
	suspend()
