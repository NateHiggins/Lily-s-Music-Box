extends Node
## LC-6D production ownership proof: the real Orison LivingField classifies
## its existing life and pushes it through existing layered storey materials.

const Lifecycle := preload("res://scripts/dream/dream_organelle_lifecycle.gd")

var checks := 0
var failures := 0
var root: Node3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("ENCROACH_FORCE", "mina:0.9")
	OS.set_environment("LIVING_ALL", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(8.0).timeout
	var enc = root.get("apartment_encroachment")
	_check("production owns the encroachment and F02 architecture field",
			enc != null and enc.fields.has("F02"))
	if enc == null or not enc.fields.has("F02"):
		return _finish()
	enc.set_physics_process(false)
	var field: LivingField = enc.fields["F02"]
	var materials: Array = enc.storey_materials.get("F02", [])
	_check("the production field already binds the storey's layered surfaces",
			not materials.is_empty())
	if materials.is_empty():
		return _finish()
	var cases_before := var_to_bytes(RealityState.data.get("cases", {}))
	var nodes_before := _node_count(root)
	var collisions_before := root.find_children("*", "CollisionObject3D", true, false).size()
	var lights_before := root.find_children("*", "Light3D", true, false).size()
	var material_count := materials.size()

	field.vascular_relays.clear()
	for source in field.sources:
		source.intensity = 0.0
	field._agents_pos.clear()
	field._agents_dir.clear()
	field._agents_starve.clear()
	field._agents_src.clear()
	field.body.fill(0.0)
	field.stain.fill(0.0)
	field.stain[0] = 0.92
	enc._push_living_lifecycle("F02", field)
	var first := materials[0] as ShaderMaterial
	_check("a production death memory reaches the existing material as stain",
			field.lifecycle_stage() == Lifecycle.Stage.STAIN
			and is_equal_approx(float(first.get_shader_parameter(
					"living_lifecycle_stage")), float(Lifecycle.Stage.STAIN)))

	field.stain.fill(0.0)
	field.body[0] = 0.92
	field.sources[0].intensity = 0.8
	field.vascular_relays.append({"at": field.origin, "src": 0,
			"strength": 0.8, "age": 0.0, "radius": 0.5, "limit": 1.2})
	enc._push_living_lifecycle("F02", field)
	_check("a production vascular answer reaches the same material as exchange",
			field.lifecycle_stage() == Lifecycle.Stage.EXCHANGE
			and is_equal_approx(float(first.get_shader_parameter(
					"living_lifecycle_stage")), float(Lifecycle.Stage.EXCHANGE)))
	_check("classification adds no node, collision, light or material owner",
			_node_count(root) == nodes_before
			and root.find_children("*", "CollisionObject3D", true, false).size()
			== collisions_before
			and root.find_children("*", "Light3D", true, false).size() == lights_before
			and materials.size() == material_count)
	_check("architecture stages change no waking case or save owner",
			cases_before == var_to_bytes(RealityState.data.get("cases", {}))
			and not RealityState.persistence_enabled)
	_finish()


func _node_count(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _node_count(child)
	return total


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("[LC6D LIVE] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _finish() -> void:
	print("[LC6D LIVE] %d/%d PASS" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
