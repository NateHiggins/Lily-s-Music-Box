extends Node

var failures := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	await get_tree().process_frame
	_check(RealityRules.definitions.size() == 3,
			"three vertical-slice rule profiles loaded")
	_check(RealityCases.activate_case("mina_caption_crisis"),
			"Mina case activates")
	var mina := RealityRules.effect_for("mina_caption_crisis")
	_check(mina.active and "labels" in mina.rule_types,
			"case state becomes a live label rule")
	_check("wrong_color" in RealityRules.prop_verbs_for(
			"mina_caption_crisis"), "Mina publishes prop verbs")

	var controller := ApartmentRealityController.new()
	controller.setup("cam_tilted_room", "4C",
			Vector3(-2, 0, -2), Vector3(2, 3, 2))
	add_child(controller)
	var subject := Node3D.new()
	subject.position = Vector3(0.5, 0.5, 0)
	controller.add_child(subject)
	controller.register_node(subject)
	_check(RealityCases.activate_case("cam_tilted_room"),
			"Cam case activates")
	var tilted := controller.gravity_at(Vector3.ZERO)
	_check(tilted.x > 0.05 and tilted.y < -0.5,
			"Cam controller supplies room-local tilted gravity")
	subject.position = Vector3(1.5, 2.0, 1.0)
	_check(RealityCases.stabilize_case("cam_tilted_room"),
			"Cam case stabilizes")
	_check(subject.position.is_equal_approx(Vector3(0.5, 0.5, 0)),
			"stabilization restores registered canonical transform")
	_check(controller.gravity_at(Vector3.ZERO).is_equal_approx(Vector3.DOWN),
			"ordinary gravity returns after stabilization")

	var first := RealityThreshold.new()
	var second := RealityThreshold.new()
	add_child(first)
	add_child(second)
	first.pair_with(second)
	_check(first.destination == second and second.destination == first,
			"non-Euclidean thresholds pair bidirectionally")
	first.queue_free()
	second.queue_free()
	controller.queue_free()
	await get_tree().process_frame

	print("REALITY RULE TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [rule ok] ", label)
	else:
		failures += 1
		printerr("  [RULE FAIL] ", label)
