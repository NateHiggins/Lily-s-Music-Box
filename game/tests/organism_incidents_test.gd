extends Node
## LF-3 contract: a resident reports another case's organism in their flat,
## the report may bring a fixable condition, and the fix drives it out.
##     godot --headless --path game res://tests/OrganismIncidentsTest.tscn
var checks := 0
var failures := 0
var root: Node3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("ENCROACH_FORCE", "mina:0.9")
	OS.set_environment("LIVING_ALL", "1")
	OS.set_environment("ORGANISM_CONDITION", "1")
	OS.set_environment("ORGANISM_FAST", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	# The props build a second after the building; the sweep indexes them.
	await get_tree().create_timer(3.0).timeout
	var enc: Node = root.get("apartment_encroachment")
	var inc: Node = root.get("organism_incidents")
	var spine: WorkOrders = root.get("work_orders")
	_check("BuildingRoot owns one OrganismIncidents", inc != null and inc.name == "OrganismIncidents")
	if inc == null or enc == null or spine == null:
		return _finish()
	_check("every occupied flat on a living storey can report", inc.flats.size() >= 6
			and inc.flats.has("2C") and inc.flats.has("2A"))
	_check("the appliances are indexed per flat", inc.props_indexed
			and (inc.flat_props.get("2C", []) as Array).size() >= 1)
	print("[incidents] 2C appliances: %d" % (inc.flat_props.get("2C", []) as Array).size())
	var field = enc.fields.get("F02")
	var mina_src := int(enc.field_source["mina_caption_crisis"])
	var rect_2c: Vector4 = inc.flats["2C"].rect
	var rect_2a: Vector4 = inc.flats["2A"].rect
	# Fresh: nothing to report.
	await get_tree().create_timer(1.5).timeout
	_check("no report while no organism is in a foreign flat", inc.reports_filed == 0
			and RealityState.data.organism_incidents.is_empty())
	# Mina's organism in Mina's own flat: Mina never reports herself.
	field.plant(rect_2a, mina_src, 0.9, 40)
	await get_tree().create_timer(4.0).timeout
	_check("a resident never reports their own organism",
			not RealityState.data.organism_incidents.has("2A"))
	# Mina's organism arrives in 2C: Juno reports it.
	field.plant(rect_2c, mina_src, 0.9, 60)
	var survey: Array = field.survey(rect_2c)
	_check("the survey sees whose body is in 2C", int(survey[mina_src].count) >= 6)
	await get_tree().create_timer(4.0).timeout
	var record: Dictionary = RealityState.data.organism_incidents.get("2C", {})
	_check("Juno reports Mina's organism in 2C", inc.reports_filed >= 1
			and str(record.get("case_id", "")) == "mina_caption_crisis")
	var order_id := str(record.get("order_id", ""))
	var order: Dictionary = RealityState.data.work_orders.get(order_id, {})
	_check("the report is a work order on the spine, active, in Juno's voice",
			spine.is_active(order_id) and str(order.get("title", "")).begins_with("2C — JUNO KELLS")
			and str(order.get("objective", "")).contains("patch cables"))
	# The chance lands (forced): a fixable condition in the area.
	_check("the report brings a condition: an appliance in 2C is held",
			not str(record.get("condition", "")).is_empty() and inc.census().held >= 1)
	var prop: Node = root.get_node_or_null(str(record.get("prop", "")))
	var point: Node = prop.get_node_or_null("OrganismConditionPoint") if prop else null
	_check("the held appliance is a FunctionalProp in 2C in FAULT with a service point on it",
			prop is FunctionalProp and prop.state == FunctionalProp.PState.FAULT and point != null
			and point.interact_prompt().begins_with("[E]"))
	var p: Vector3 = (prop as Node3D).global_position if prop else Vector3.ZERO
	_check("the condition is inside Juno's flat", prop != null and p.x >= rect_2c.x and p.x <= rect_2c.z
			and p.z >= rect_2c.y and p.z <= rect_2c.w)
	# The ledger is a save key that restores: drop the point, re-arm, it is back.
	if point:
		point.free()
	(prop as FunctionalProp).state = FunctionalProp.PState.IDLE
	inc.attach_props()
	var again: Node = prop.get_node_or_null("OrganismConditionPoint") if prop else null
	_check("an unfixed condition re-arms from the ledger", again != null
			and prop.state == FunctionalProp.PState.FAULT)
	# The fix: the appliance runs, the order closes, the organism withdraws.
	var before := int(field.survey(rect_2c)[mina_src].count)
	if again:
		again.interact()
	await get_tree().create_timer(1.0).timeout
	var after := int(field.survey(rect_2c)[mina_src].count)
	record = RealityState.data.organism_incidents.get("2C", {})
	_check("fixing restores the appliance and closes the order", prop.state == FunctionalProp.PState.IDLE
			and bool(record.get("fixed", false)) and spine.status(order_id) == "closed")
	_check("the fix drives the organism out of the flat (%d -> %d live voxels)" % [before, after],
			before >= 6 and after < 6)
	var stained := 0
	var x0 := int((rect_2c.x - field.origin.x) / 0.5) + 1
	var z0 := int((rect_2c.y - field.origin.z) / 0.5) + 1
	for y in field.ny:
		stained += 1 if field.stain[(y * field.nz + z0) * field.nx + x0] > 0.8 else 0
	_check("the flat keeps a repellent stain after the fix", stained >= field.ny - 1)
	_check("the condition point is gone", not is_instance_valid(again) or again.is_queued_for_deletion())
	# Cooldown: the same flat is not re-reported at once.
	field.plant(rect_2c, mina_src, 0.9, 60)
	await get_tree().create_timer(4.0).timeout
	_check("a fixed flat is not re-reported during the cooldown",
			int(RealityState.data.organism_incidents["2C"].count) == 1
			and bool(RealityState.data.organism_incidents["2C"].closed))
	_check("the ledger is the only save key", RealityState.data.has("organism_incidents")
			and int(RealityState.data.organism_incidents["2C"].count) == 1)
	_finish()


func _finish() -> void:
	print("ORGANISM INCIDENTS TEST: %s (%d/%d)" % ["PASS" if failures == 0 else "FAIL",
			checks - failures, checks])
	get_tree().quit(failures)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("[incidents ok] " + label)
	else:
		failures += 1
		printerr("[INCIDENTS FAIL] " + label)
