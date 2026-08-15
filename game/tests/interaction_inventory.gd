extends Node
## I1 production census. This does not classify design intent: it records the
## live owners and source families that the ruled matrix must account for.

const FLOORS := ["B1", "F01", "F02", "F03", "F04", "F05", "F06", "ROOF"]
const SET_SYSTEM_SCRIPTS := [
	"res://scripts/building/street_traffic.gd",
	"res://scripts/building/weather_fx.gd",
	"res://scripts/device/service_set_prop.gd",
]

var root: Node3D
var _functional: Dictionary = {}
var _nonfunctional: Dictionary = {}
var _scripted_visuals: Dictionary = {}
var _set_systems: Dictionary = {}


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	_scan(root)
	var layout := _load_json("res://data/building_layout.json")
	var report := {
		"schema": 1,
		"generated_utc": Time.get_datetime_string_from_system(true),
		"scene": "res://scenes/building/orison_root.tscn",
		"summary": _summary(),
		"functional_interactions": _sorted_rows(_functional),
		"nonfunctional_interactions": _sorted_rows(_nonfunctional),
		"scripted_visuals_without_interaction": _sorted_rows(_scripted_visuals),
		"scripted_set_systems": _sorted_rows(_set_systems),
		"layout_marker_kinds": _marker_kinds(layout),
		"layout_assemblies": _assembly_kinds(layout),
		"layout_render_batches": _render_batches(layout),
	}
	var path := OS.get_environment("INTERACTION_INVENTORY_OUT")
	if path == "":
		path = OS.get_user_data_dir().path_join("interaction_inventory.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("InteractionInventory cannot write %s" % path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t", false) + "\n")
	file.close()
	print(("[INTERACTION INVENTORY] functional=%d/%d nonfunctional=%d/%d " \
			+ "scripted_visual_families=%d set_systems=%d markers=%d " \
			+ "assemblies=%d batches=%d") % [
			int(report.summary.functional_instances),
			int(report.summary.functional_families),
			int(report.summary.nonfunctional_instances),
			int(report.summary.nonfunctional_families),
			_scripted_visuals.size(), _set_systems.size(),
			report.layout_marker_kinds.size(),
			report.layout_assemblies.size(), report.layout_render_batches.size()])
	print("[INTERACTION INVENTORY] wrote %s" % path)
	get_tree().quit(0)


func _scan(node: Node) -> void:
	var script_path := _script_path(node)
	var is_interaction := node.has_method("interact_prompt") \
			and (node.has_method("interact") or node.has_method("interact_area"))
	if node is FunctionalProp and is_interaction:
		_record_owner(_functional, node, script_path, true)
	elif is_interaction:
		_record_owner(_nonfunctional, node, script_path, false)
	elif script_path.begins_with("res://scripts/props/") \
			and _geometry_count(node) > 0:
		_record_visual(_scripted_visuals, node, script_path)
	elif script_path in SET_SYSTEM_SCRIPTS and _geometry_count(node) > 0:
		_record_visual(_set_systems, node, script_path)
	for child in node.get_children():
		_scan(child)


func _record_owner(book: Dictionary, node: Node, script_path: String,
		functional: bool) -> void:
	var key := script_path if script_path != "" else node.get_class()
	if functional:
		key += "::%s" % str(node.get("prop_type"))
	if not book.has(key):
		book[key] = {
			"key": key,
			"class": _script_class(node),
			"script": script_path,
			"prop_type": str(node.get("prop_type")) if functional else "",
			"instances": 0,
			"names": [],
			"floors": [],
			"prompts": [],
			"interaction_entry": "interact_area" if node.has_method(
					"interact_area") else "interact",
			"area_shapes": 0,
			"audio_players": 0,
			"audio_streams": [],
			"service_wire_cards": 0,
			"prompting_instances": 0,
			"persistence": _script_contains(script_path,
					["RealityState", "serialize", "restore"]),
			"dependencies": _dependencies(script_path),
		}
	var row: Dictionary = book[key]
	row.instances = int(row.instances) + 1
	_append_unique(row.names, str(node.name), 10)
	_append_unique(row.floors, _floor_owner(node), 16)
	var prompt := ""
	if node.has_method("interact_prompt"):
		prompt = str(node.call("interact_prompt"))
	_append_unique(row.prompts, prompt, 8)
	if prompt.strip_edges() != "":
		row.prompting_instances = int(row.prompting_instances) + 1
	row.area_shapes = int(row.area_shapes) + _interaction_shape_count(node)
	var audio := _audio_census(node)
	row.audio_players = int(row.audio_players) + int(audio.players)
	for stream in audio.streams:
		_append_unique(row.audio_streams, str(stream), 16)
	if node.has_method("service_wire_card"):
		var card: Variant = node.call("service_wire_card")
		if card is Dictionary and str(card.get("body", "")).strip_edges() != "":
			row.service_wire_cards = int(row.service_wire_cards) + 1
	elif node is InspectableZone:
		# InspectableZone deliberately returns its card as the interaction result;
		# calling interact() here would mutate its sequence cursor.
		row.service_wire_cards = int(row.service_wire_cards) + 1
	book[key] = row


func _record_visual(book: Dictionary, node: Node, script_path: String) -> void:
	if not book.has(script_path):
		book[script_path] = {
			"key": script_path,
			"class": _script_class(node),
			"script": script_path,
			"instances": 0,
			"names": [],
			"floors": [],
			"geometry": 0,
			"audio_players": 0,
			"audio_streams": [],
			"persistence": _script_contains(script_path,
					["RealityState", "serialize", "restore"]),
			"dependencies": _dependencies(script_path),
		}
	var row: Dictionary = book[script_path]
	row.instances = int(row.instances) + 1
	row.geometry = int(row.geometry) + _geometry_count(node)
	_append_unique(row.names, str(node.name), 10)
	_append_unique(row.floors, _floor_owner(node), 16)
	var audio := _audio_census(node)
	row.audio_players = int(row.audio_players) + int(audio.players)
	for stream in audio.streams:
		_append_unique(row.audio_streams, str(stream), 16)
	book[script_path] = row


func _summary() -> Dictionary:
	return {
		"functional_instances": _sum_instances(_functional),
		"functional_families": _functional.size(),
		"nonfunctional_instances": _sum_instances(_nonfunctional),
		"nonfunctional_families": _nonfunctional.size(),
		"functional_with_cards": _sum_field(_functional,
				"service_wire_cards"),
		"nonfunctional_with_cards": _sum_field(_nonfunctional,
				"service_wire_cards"),
		"functional_prompting_instances": _sum_field(_functional,
				"prompting_instances"),
		"nonfunctional_prompting_instances": _sum_field(_nonfunctional,
				"prompting_instances"),
	}


func _marker_kinds(layout: Dictionary) -> Array:
	var rows: Dictionary = {}
	for floor in layout.get("floors", []):
		for marker in floor.get("markers", []):
			_count_source(rows, str(marker.get("kind", "(none)")),
					str(floor.get("id", "?")), str(marker.get("id", "")))
	return _sorted_rows(rows)


func _assembly_kinds(layout: Dictionary) -> Array:
	var rows: Dictionary = {}
	for floor in layout.get("floors", []):
		for record in floor.get("furniture", []):
			var assembly := str(record.get("asm", ""))
			if assembly == "":
				continue
			_count_source(rows, assembly, str(floor.get("id", "?")),
					str(record.get("id", "")))
	return _sorted_rows(rows)


func _render_batches(layout: Dictionary) -> Array:
	var rows: Dictionary = {}
	for floor in layout.get("floors", []):
		for record in floor.get("furniture", []):
			# Current generated records use `batch`; accept the older diagnostic
			# spelling as well so the census remains usable across stored layouts.
			var batch := str(record.get("batch",
					record.get("render_batch", "")))
			if batch == "":
				continue
			_count_source(rows, batch, str(floor.get("id", "?")),
					str(record.get("id", "")))
	return _sorted_rows(rows)


func _count_source(book: Dictionary, key: String, floor: String,
		example: String) -> void:
	if not book.has(key):
		book[key] = {"key": key, "instances": 0, "floors": [], "examples": []}
	var row: Dictionary = book[key]
	row.instances = int(row.instances) + 1
	_append_unique(row.floors, floor, 16)
	_append_unique(row.examples, example, 8)
	book[key] = row


func _audio_census(node: Node) -> Dictionary:
	var players := 0
	var streams: Array = []
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)
		if current is AudioStreamPlayer or current is AudioStreamPlayer3D:
			players += 1
			var stream: AudioStream = current.stream
			if stream != null:
				_append_unique(streams, stream.resource_path, 16)
	return {"players": players, "streams": streams}


func _interaction_shape_count(node: Node) -> int:
	var count := 0
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)
		if current is CollisionShape3D and current.shape != null \
				and current.get_parent() is CollisionObject3D:
			count += 1
	return count


func _geometry_count(node: Node) -> int:
	var count := 0
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)
		if current is GeometryInstance3D:
			count += 1
	return count


func _floor_owner(node: Node) -> String:
	var current: Node = node
	while current != null:
		if str(current.name) in FLOORS:
			return str(current.name)
		current = current.get_parent()
	if node is Node3D:
		var y := (node as Node3D).global_position.y
		var best := "ROOT"
		var error := INF
		var heights := {"B1": -2.8, "F01": 0.0, "F02": 3.2,
			"F03": 6.4, "F04": 9.6, "F05": 12.8, "F06": 16.0,
			"ROOF": 19.2}
		for floor in heights:
			var distance: float = absf(y - float(heights[floor]))
			if distance < error:
				error = distance
				best = floor
		return best if error < 1.7 else "ROOT"
	return "ROOT"


func _dependencies(script_path: String) -> Array:
	var found: Array = []
	var pairs := {
		"WorkOrders": "work_orders",
		"RealityState": "reality_state",
		"RealityCase": "reality_cases",
		"MaintenanceInventory": "maintenance_inventory",
		"Conductor": "conductor",
		"AcousticGraphData": "acoustic_graph",
		"call_locked": "protected_ui",
	}
	for needle in pairs:
		if _script_contains(script_path, [needle]):
			found.append(pairs[needle])
	return found


func _script_contains(script_path: String, needles: Array) -> bool:
	if script_path == "":
		return false
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return false
	var source := file.get_as_text()
	for needle in needles:
		if source.contains(str(needle)):
			return true
	return false


func _script_path(node: Node) -> String:
	var script: Script = node.get_script()
	return script.resource_path if script != null else ""


func _script_class(node: Node) -> String:
	var script: Script = node.get_script()
	if script != null and script.get_global_name() != "":
		return script.get_global_name()
	return node.get_class()


func _append_unique(values: Array, value: Variant, limit: int) -> void:
	if value == null or str(value) == "" or value in values:
		return
	if values.size() < limit:
		values.append(value)


func _sum_instances(book: Dictionary) -> int:
	return _sum_field(book, "instances")


func _sum_field(book: Dictionary, field: String) -> int:
	var total := 0
	for row in book.values():
		total += int(row.get(field, 0))
	return total


func _sorted_rows(book: Dictionary) -> Array:
	var keys: Array = book.keys()
	keys.sort()
	var rows: Array = []
	for key in keys:
		rows.append(book[key])
	return rows


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
