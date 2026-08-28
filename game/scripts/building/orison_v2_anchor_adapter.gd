class_name OrisonV2AnchorAdapter
extends RefCounted

const REQUIRED: Array[String] = [
	"F01_DOOR_06", "F02_DOOR_02", "F04_DOOR_03",
	"F02_A_MAIN_VANTRY_POINT", "F02_A_MONITOR_01", "F04_B_MONITOR_01",
	"F04_B_BED", "F04_B_BEDSIDE_RETURN", "LobbyMailBank",
	"LobbyPorterBoard", "F01_HOUSE_TELEPHONE_BOARD", "LobbyServiceDumbwaiter"]

var root: Node
var _acoustic_originals := {}

func _init(selected_root: Node) -> void:
	root = selected_root

func resolve(identity: String) -> Node:
	if root == null:
		return null
	var matches := root.find_children(identity, "", true, false)
	return matches[0] if matches.size() == 1 else null

func resolves_required_uniquely() -> bool:
	for identity in REQUIRED:
		if resolve(identity) == null:
			return false
	return true

func explicit_bed() -> Node3D:
	return resolve("F04_B_BED") as Node3D

func anonymous_bed_fallback(production_layout: Dictionary) -> Dictionary:
	for floor: Dictionary in production_layout.get("floors", []):
		if str(floor.get("id", "")) != "F04":
			continue
		for record: Dictionary in floor.get("furniture", []):
			if str(record.get("id", "")) == "bed":
				return record
	return {}

func install_acoustic_overrides(ids: Array) -> bool:
	for value: Variant in ids:
		var identity := str(value)
		var anchor := resolve(identity) as Node3D
		if anchor == null or not AcousticGraphData.nodes.has(identity):
			restore_acoustic_overrides()
			return false
		var record: Dictionary = AcousticGraphData.nodes[identity]
		_acoustic_originals[identity] = record.duplicate(true)
		record.pos = [anchor.global_position.x, -anchor.global_position.z,
				anchor.global_position.y]
		AcousticGraphData.nodes[identity] = record
	return true

func restore_acoustic_overrides() -> void:
	for identity: String in _acoustic_originals:
		AcousticGraphData.nodes[identity] = _acoustic_originals[identity]
	_acoustic_originals.clear()
