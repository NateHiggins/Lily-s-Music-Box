extends Node


func _ready() -> void:
	await get_tree().process_frame
	var failures: Array[String] = []
	var identities := {}
	for case_id in PoltergeistLibrary.ids():
		var grammar := PoltergeistLibrary.propagation(case_id)
		if grammar.is_empty():
			failures.append("%s has no propagation grammar" % case_id)
			continue
		var identity := "%s:%s" % [grammar.get("carrier", ""),
				grammar.get("pattern", "")]
		if identities.has(identity):
			failures.append("%s duplicates %s (%s)" % [case_id,
					identities[identity], identity])
		identities[identity] = case_id
		var definition := RealityCases.definition(case_id)
		var origin: String = definition.get("origin_node", "")
		if origin.is_empty():
			var unit: String = definition.get("unit", "")
			origin = "F0%s_%s_RADIATOR_01" % [unit.left(1), unit.substr(1, 1)]
		var route := AcousticGraphData.debug_reality_plan(origin, case_id)
		if route.size() < 2:
			failures.append("%s route has only %d nodes from %s" %
					[case_id, route.size(), origin])
		var rules: Dictionary = RealityRules.definitions.get(case_id, {})
		if rules.is_empty():
			failures.append("%s has no physical reality rule" % case_id)
	if failures.is_empty():
		print("[PROPAGATION TEST] PASS: 18 unique grammars, routes, and prop rules")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[PROPAGATION TEST] " + failure)
		get_tree().quit(1)
