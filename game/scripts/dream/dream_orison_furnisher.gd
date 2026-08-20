class_name DreamOrisonFurnisher
extends Node3D
## THE REAL ORISON, REMEMBERED AS CONTENT RATHER THAN AS EMPTY DIMENSIONS.
##
## Dream modules already inherit exact waking-room measurements.  This pass
## borrows the production procedural prop models as well, extracts only their
## finished meshes, and places a restrained set around each room's perimeter.
## It does not instance the functional owners: no refrigerator, boiler or
## lamp can publish an E verb, occupy the light budget or answer a waking
## signal from inside the Tenant's body.

const RadiatorScript := preload("res://scripts/props/radiator_prop.gd")
const BookshelfScript := preload("res://scripts/props/bookshelf_prop.gd")
const FridgeScript := preload("res://scripts/props/fridge_prop.gd")
const WasherScript := preload("res://scripts/props/washer_prop.gd")
const BoilerScript := preload("res://scripts/props/boiler_prop.gd")
const AirerScript := preload("res://scripts/props/laundry_airer_prop.gd")
const MedicineCabinetScript := preload(
		"res://scripts/props/medicine_cabinet_prop.gd")
const SignalTerminalScript := preload(
		"res://scripts/props/signal_terminal_prop.gd")
const FixtureScript := preload("res://scripts/props/light_fixture_prop.gd")

const CLEAR_CEILING_M := 3.015

const SOURCE_PROPS := {
	"D00_4B_THRESHOLD": [
		{"script": RadiatorScript, "properties": {"unit": "4B"}},
		{"script": FixtureScript, "mount": "ceiling",
				"properties": {"prop_type": "cage_bulb"}},
	],
	"D01_F04_LONG_HALL": [
		{"script": RadiatorScript, "properties": {"unit": "4B"}},
		{"script": BookshelfScript, "properties": {"owner_name": "Mina Vale",
				"unit": "2A", "case_style": "repaired"}},
		{"script": FixtureScript, "mount": "ceiling",
				"properties": {"prop_type": "chandelier"}},
	],
	"D02_DOGLEG_STAIR": [
		{"script": FixtureScript, "mount": "ceiling",
				"properties": {"prop_type": "cage_bulb"}},
	],
	"D03_LIFT_VOID": [
		{"script": RadiatorScript, "properties": {"unit": "LOBBY"}},
		{"script": FixtureScript, "mount": "ceiling",
				"properties": {"prop_type": "flush_dome"}},
	],
	"D04_BATHROOM_PROCESSION": [
		{"script": MedicineCabinetScript, "mount": "wall",
				"properties": {"prop_type": "mirror"}},
		{"script": RadiatorScript, "properties": {"unit": "2A"}},
		{"script": FixtureScript, "mount": "ceiling",
				"properties": {"prop_type": "sconce_globe"}},
	],
	"D05_SERVICE_RISER": [
		{"script": SignalTerminalScript,
				"properties": {"prop_type": "signal_terminal"}},
		{"script": RadiatorScript, "properties": {"unit": "2A"}},
		{"script": FixtureScript, "mount": "ceiling",
				"properties": {"prop_type": "cage_bulb"}},
	],
	"D06_LAUNDRY_BOILER": [
		{"script": WasherScript, "properties": {"prop_type": "washer"}},
		{"script": BoilerScript, "properties": {"prop_type": "boiler"}},
		{"script": AirerScript,
				"properties": {"prop_type": "laundry_airer"}},
		{"script": FixtureScript, "mount": "ceiling",
				"properties": {"prop_type": "cage_bulb"}},
	],
	"D07_LIGHT_COURT_WALK": [
		{"script": FixtureScript, "mount": "ceiling",
				"properties": {"prop_type": "pendant_shade"}},
	],
	"D08_CASE_ECHO": [
		{"script": BookshelfScript, "properties": {"owner_name": "Mina Vale",
				"unit": "2A", "case_style": "repaired",
				"canonical_book": "prospectus"}},
		{"script": FridgeScript, "properties": {"unit": "2A",
				"monitor_top": true, "prop_type": "fridge"}},
		{"script": RadiatorScript, "properties": {"unit": "2A"}},
		{"script": FixtureScript, "mount": "ceiling",
				"properties": {"prop_type": "chandelier"}},
	],
	"D09_RETURN_HALL": [
		{"script": RadiatorScript, "properties": {"unit": "4B"}},
		{"script": FixtureScript, "mount": "ceiling",
				"properties": {"prop_type": "flush_dome"}},
	],
}


func configure(room: Dictionary) -> void:
	name = "OrisonFurnishing"
	add_to_group("dream_orison_furnishing")
	set_meta("room_key", str(room.get("key", "")))
	set_meta("source_module", str(room.get("source", "")))
	set_meta("visual_only", true)
	if bool(room.get("blank", false)):
		set_meta("production_prop_count", 0)
		return
	var rect: Array = room.get("rect", [])
	if rect.size() < 4:
		set_meta("production_prop_count", 0)
		return
	var source := str(room.get("source", ""))
	var specs: Array = SOURCE_PROPS.get(source, [])
	var candidates := _perimeter_candidates(rect, room.get("doors", []),
			room.get("hazards", []))
	var built := 0
	for spec_value in specs:
		var spec: Dictionary = spec_value
		var mount := str(spec.get("mount", "floor"))
		var pose: Dictionary = {}
		if mount == "ceiling":
			pose = {"position": Vector3(
					(float(rect[0]) + float(rect[2])) * 0.5,
					CLEAR_CEILING_M - 0.01,
					(float(rect[1]) + float(rect[3])) * 0.5), "yaw": 0.0}
		elif candidates.is_empty():
			continue
		else:
			pose = candidates.pop_front()
			if mount == "wall":
				var wall_position: Vector3 = pose.position
				wall_position.y = 1.47
				pose["position"] = wall_position
		var visual := _extract_visual(spec)
		if visual == null or visual.get_child_count() == 0:
			if visual != null:
				visual.free()
			continue
		visual.name = "DreamFurnish_%s_%02d" % [source, built + 1]
		visual.position = pose.position
		visual.rotation.y = float(pose.yaw)
		visual.set_meta("source_script",
				(spec.script as GDScript).resource_path)
		visual.set_meta("source_module", source)
		add_child(visual)
		built += 1
	set_meta("production_prop_count", built)


## Let the production prop complete its ordinary constructor while parented to
## this already-live staging node, copy only its rendered result, then free the
## owner before returning. Several real props correctly require a SceneTree
## while authoring sound emitters or world-space decals; calling their private
## builder off-tree produced engine errors even though the meshes appeared.
## The staged owner therefore exists for one synchronous constructor only: no
## interaction Area, sound, light or per-frame script survives this function.
func _extract_visual(spec: Dictionary) -> Node3D:
	var script: GDScript = spec.script
	var source := script.new() as Node3D
	if source == null:
		return null
	for property in spec.get("properties", {}):
		if property in source:
			source.set(property, spec.properties[property])
	source.name = "DreamFurnishSource"
	add_child(source)
	var visual := Node3D.new()
	_clone_meshes(source, visual, Transform3D.IDENTITY)
	remove_child(source)
	source.free()
	return visual


func _clone_meshes(source: Node, target: Node3D,
		parent_transform: Transform3D) -> void:
	for child in source.get_children():
		var child_transform := parent_transform
		if child is Node3D:
			child_transform = parent_transform * (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var old := child as MeshInstance3D
			var clone := MeshInstance3D.new()
			clone.name = old.name
			clone.mesh = old.mesh
			clone.material_override = old.material_override
			clone.cast_shadow = old.cast_shadow
			clone.visibility_range_end = old.visibility_range_end
			clone.transform = child_transform
			target.add_child(clone)
		_clone_meshes(child, target, child_transform)


func _perimeter_candidates(rect: Array, doors: Array,
		hazards: Array) -> Array[Dictionary]:
	var x0 := float(rect[0])
	var z0 := float(rect[1])
	var x1 := float(rect[2])
	var z1 := float(rect[3])
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var margin := 0.34
	var candidates: Array[Dictionary] = [
		{"position": Vector3(lerpf(x0, x1, 0.22), 0.0, z0 + margin),
				"yaw": 0.0},
		{"position": Vector3(lerpf(x0, x1, 0.78), 0.0, z1 - margin),
				"yaw": PI},
		{"position": Vector3(x0 + margin, 0.0, lerpf(z0, z1, 0.72)),
				"yaw": -PI * 0.5},
		{"position": Vector3(x1 - margin, 0.0, lerpf(z0, z1, 0.28)),
				"yaw": PI * 0.5},
		{"position": Vector3(cx, 0.0, z0 + margin), "yaw": 0.0},
		{"position": Vector3(cx, 0.0, z1 - margin), "yaw": PI},
	]
	for candidate in candidates:
		candidate["score"] = _clearance_score(candidate.position, doors,
				hazards)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.score) > float(b.score))
	return candidates


func _clearance_score(position: Vector3, doors: Array, hazards: Array) -> float:
	var score := 99.0
	for door in doors:
		var aperture: Array = door.get("aperture", [])
		if aperture.size() < 4:
			continue
		var p := Vector2((float(aperture[0]) + float(aperture[2])) * 0.5,
				(float(aperture[1]) + float(aperture[3])) * 0.5)
		score = minf(score, p.distance_to(Vector2(position.x, position.z)))
	for hazard in hazards:
		var hp: Array = hazard.get("position", [])
		if hp.size() < 2:
			continue
		score = minf(score, Vector2(float(hp[0]), float(hp[1])).distance_to(
				Vector2(position.x, position.z)))
	return score
