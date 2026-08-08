class_name ArcadeRow
extends Node
## Puts a game in every arcade cabinet the layout owns.
##
## `asm_arcade_cab` already builds the carcass, the coin door, the vents and the
## feet into the merged floor mesh, in one of four silhouettes, and leaves the
## screen as flat dark glass because - as its own comment says - the glow is the
## Godot prop's job. This walks the layout for those entries and hangs an
## `ArcadeCabinetProp` on each one, exactly the way BroadcastDirector hangs a
## TVProp on every `tv`.
##
## Which game goes in which cabinet comes from `arcade_cabinets.json`, a build
## output of the world compiler. The row is assigned in layout order, so adding a
## cabinet to gen_layout.py gets the next title in the catalog and nothing here
## has to change.
##
## The catalog carries twelve titles across ten genres and twenty-five years of
## claimed vintage. All twelve are the same shooter. The compiler refuses to
## write the catalog unless `worldc invariance` proves it.

const ASM := "arcade_cab"

var cabinets: Array[ArcadeCabinetProp] = []

var _catalog: ArcadeCatalog = null


## `floor_nodes` maps floor id -> the Node3D that floor's content hangs under, so
## a cabinet is hidden by the same streaming that hides the room around it.
func install(layout: Dictionary, floor_nodes: Dictionary,
		catalog_dir := ArcadeCatalog.DIR) -> int:
	_catalog = ArcadeCatalog.load_catalog(catalog_dir)
	if _catalog == null or _catalog.size() == 0:
		print("[ARCADE] no catalog; cabinets left dark")
		return 0

	# Genre-first rather than catalog order, so a bar with two machines gets two
	# obviously different products instead of the first two entries by id.
	var order := _catalog.spread()
	var index := 0
	for floor_data in layout["floors"]:
		var floor_id := str(floor_data["id"])
		if not floor_nodes.has(floor_id):
			continue
		for furniture in floor_data.get("furniture", []):
			if str(furniture.get("asm", "")) != ASM:
				continue
			var prop := ArcadeCabinetProp.new()
			prop.name = "Arcade_" + str(furniture.get("id", "cab"))
			prop.prop_type = "monitor"
			prop.configure(
				order[index % order.size()],
				int(furniture.get("variant", 0)),
				catalog_dir
			)
			var at: Array = furniture["at"]
			# z0 is not optional: a cabinet in a basement bar sits well below its
			# floor's own entry, and ignoring it spawns the machine inside infill.
			prop.position = GameBoot.b2g([
				float(at[0]),
				float(at[1]),
				float(floor_data["z"]) + float(furniture.get("z0", 0.0)),
			])
			# +PI for the same reason the televisions turn: an assembly's authored
			# yaw faces its BACK into the room.
			prop.rotation.y = deg_to_rad(float(furniture.get("yaw", 0))) + PI
			# Bind to the acoustic graph, or the cabinet never hears the building.
			#
			# `building_root._spawn_props` sets `graph_node_id` from a marker's own
			# id, but cabinets come from `furniture` and have no marker - so without
			# this they are spawned unbound, `FunctionalProp._on_reality_event`
			# returns on its first line, and the whole "the machines start admitting
			# it" escalation is wired to nothing. Nearest node is the right rule:
			# a cabinet belongs to the room it is standing in.
			prop.graph_node_id = _nearest_graph_node(prop.position)
			floor_nodes[floor_id].add_child(prop)
			cabinets.append(prop)
			index += 1

	if cabinets.is_empty():
		return 0
	var claims := PackedStringArray()
	for prop in cabinets:
		claims.append("%s (%s)" % [
			String(prop.cabinet.get("title", "?")),
			String(prop.cabinet.get("claimed_genre", "?")),
		])
	print("[ARCADE] %d cabinet(s) from a catalog of %d: %s"
			% [cabinets.size(), _catalog.size(), ", ".join(claims)])
	print("[ARCADE] all of them are running %s" % _catalog.scene_id)
	var unbound := 0
	for prop in cabinets:
		if prop.graph_node_id == "":
			unbound += 1
	if unbound > 0:
		# Worth saying: an unbound cabinet plays fine and simply never reacts to
		# the building, which looks like the infection system being broken.
		push_warning(
			("[ARCADE] %d cabinet(s) found no acoustic graph node; they "
			+ "will not react to reality events") % unbound
		)
	return cabinets.size()


## The acoustic-graph node a cabinet at `at` should answer to, or "" if the graph
## has nothing near enough to be plausible.
##
## Capped at 14 m: a machine in the bar responding to something happening two
## floors up is worse than one that stays quiet.
func _nearest_graph_node(at: Vector3, limit := 14.0) -> String:
	var best := ""
	var best_distance := limit
	for node_id in AcousticGraphData.nodes:
		var distance := AcousticGraphData.node_pos(node_id).distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = String(node_id)
	return best


## Every cabinet on the row, for a director that wants to push the whole arcade
## at once rather than one machine at a time.
func set_infection(strength: float) -> void:
	for prop in cabinets:
		prop._infection = clampf(strength, 0.0, 1.0)
		prop._apply_infection()
