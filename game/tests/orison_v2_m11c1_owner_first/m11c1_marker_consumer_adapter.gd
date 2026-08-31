extends Node3D
## Test-only extraction of BuildingRoot's marker-door composition seam. This
## exercises the unchanged production DoorProp class and reproduces the exact
## marker properties/group tracking used by BuildingRoot._spawn_props(), but it
## is deliberately receipted as an adapter rather than a BuildingRoot run.
## Markers are selected by durable semantic identity and explicit source owner;
## the production DoorProp implementation and public interaction API are used
## unchanged.

var doors: Dictionary = {}
var doors_by_floor: Dictionary = {}
var passage_runtime_nodes: Array[Node3D] = []
var receipts: Array[Dictionary] = []


func mount_doors(layout: Dictionary, semantic_index: Dictionary,
		identities: Array[String], active_cells: Array[String]) -> Dictionary:
	var marker_index := _marker_index(layout)
	var failures: Array[String] = []
	for identity: String in identities:
		var semantic: Dictionary = semantic_index.get(identity, {})
		var owners: Array = semantic.get("owner_cells", [])
		if owners.size() != 1:
			failures.append("%s has no unique source semantic owner" % identity)
			continue
		var owner := str(owners[0])
		if owner not in active_cells:
			failures.append("%s owner %s is not in the active seam set" % [
					identity, owner])
			continue
		if not marker_index.has(identity):
			failures.append("%s has no exact unchanged layout marker" % identity)
			continue
		var marker: Dictionary = marker_index[identity]
		if str(marker.get("kind", "")) != "door":
			failures.append("%s source marker is not a door" % identity)
			continue
		var door: DoorProp = LandmarkEntryDoor.new() \
				if identity == "F01_DOOR_06" else DoorProp.new()
		door.width = float(marker.get("w", 0.0))
		door.height = float(marker.get("h", 0.0))
		door.leaf_state = str(marker.get("leaf", "closed"))
		door.swing_out = str(marker.get("swing", "")) == "out"
		door.door_kind = str(marker.get("subtype", "apartment_interior"))
		door.unit = str(marker.get("unit", ""))
		door.finish_variant = int(marker.get("finish_variant", 0))
		door.name = identity
		door.position = GameBoot.b2g(marker.get("pos", [0.0, 0.0, 0.0]))
		door.rotation.y = deg_to_rad(-float(marker.get("yaw_deg", 0.0)))
		door.set_meta(&"m11c1_owner_cell", owner)
		door.set_meta(&"m11c1_semantic_identity", identity)
		add_child(door)
		var floor_id := str(marker.get("floor_id", "F01"))
		if not doors_by_floor.has(floor_id):
			doors_by_floor[floor_id] = []
		(doors_by_floor[floor_id] as Array).append(door)
		var passage_tracked := str(marker.get("zone", "")) == "PASSAGE"
		if passage_tracked:
			door.add_to_group("passage_runtime")
			passage_runtime_nodes.append(door)
		doors[identity] = door
		receipts.append({
			"identity":identity,
			"source_id":semantic.get("source_id", ""),
			"owner_cell":owner,
			"production_class":"LandmarkEntryDoor" if identity == "F01_DOOR_06" \
					else "DoorProp",
			"leaf_state":door.leaf_state,
			"door_kind":door.door_kind,
			"source_selection":"exact durable marker identity",
			"floor_tracking":floor_id,
			"passage_runtime_group":passage_tracked,
			"spatial_inference":false,
		})
	return {
		"status":"PASS" if failures.is_empty() else "FAIL",
		"doors":receipts.duplicate(true),
		"failures":failures,
	}


func door(identity: String) -> DoorProp:
	return doors.get(identity) as DoorProp


func public_teardown() -> Dictionary:
	var queued: Array[int] = []
	var released_audio_sources: Array[Dictionary] = []
	for raw_identity: Variant in doors:
		var identity := str(raw_identity)
		var value: DoorProp = doors[raw_identity] as DoorProp
		var released := AudioPolicy.release_source(StringName(identity))
		released_audio_sources.append({"identity":identity,
				"released_voice_count":released})
		if is_instance_valid(value):
			queued.append(value.get_instance_id())
			value.queue_free()
	doors.clear()
	doors_by_floor.clear()
	passage_runtime_nodes.clear()
	receipts.clear()
	return {
		"api":"M11C1MarkerConsumerAdapter.public_teardown",
		"queued_instance_ids":queued,
		"released_audio_sources":released_audio_sources,
		"retained_strong_references":doors.size() + receipts.size(),
		"building_root_execution":false,
		"adapter_scope":"exact marker DoorProp construction/group seam only",
		"production_door_script_modified":false,
		"spatial_inference":false,
	}


func _marker_index(layout: Dictionary) -> Dictionary:
	var result := {}
	for floor_raw: Variant in layout.get("floors", []):
		if floor_raw is not Dictionary:
			continue
		for marker_raw: Variant in floor_raw.get("markers", []):
			if marker_raw is Dictionary:
				var identity := str(marker_raw.get("id", ""))
				if not identity.is_empty():
					var marker := (marker_raw as Dictionary).duplicate(true)
					marker["floor_id"] = str(floor_raw.get("id", ""))
					result[identity] = marker
	return result
