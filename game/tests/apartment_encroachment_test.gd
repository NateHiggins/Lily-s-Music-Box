extends Node
## WK-1 contract: the dream's plates reach a case's flat as presentation only.
##     godot --headless --path game res://tests/ApartmentEncroachmentTest.tscn
var checks := 0
var failures := 0
var root: Node3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("ENCROACH_FORCE", "")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(0.8).timeout
	var enc: Node = root.get("apartment_encroachment")
	_check("BuildingRoot owns one ApartmentEncroachment", enc != null and enc.name == "ApartmentEncroachment")
	if enc == null:
		return _finish()
	var surfaces: Dictionary = enc.surfaces
	_check("Mina's flat has encroachable finish surfaces", surfaces.has("mina_caption_crisis")
			and (surfaces["mina_caption_crisis"] as Array).size() >= 1)
	_check("every shipped case with a flat is registered", surfaces.size() == 6)
	# Surfaces are overrides on existing quads, never new geometry.
	var all_overrides := true
	var unit_rects_ok := true
	for case_id in surfaces:
		for row in surfaces[case_id]:
			var mi: MeshInstance3D = row.mesh
			all_overrides = all_overrides and mi.get_surface_override_material(int(row.surface)) == row.material
			var rect: Vector4 = (row.material as ShaderMaterial).get_shader_parameter("unit_rect")
			unit_rects_ok = unit_rects_ok and rect.z > rect.x and rect.w > rect.y
	_check("encroachment is a material override on existing finish quads", all_overrides)
	_check("every override is clipped to a real unit rect", unit_rects_ok)
	# Fresh campaign: every case unseen, every intensity 0.
	var all_zero := true
	for case_id in surfaces:
		all_zero = all_zero and float(enc.intensity_for(case_id)) == 0.0
		for row in surfaces[case_id]:
			all_zero = all_zero and float((row.material as ShaderMaterial).get_shader_parameter("intensity")) == 0.0
	_check("a fresh campaign shows no encroachment anywhere", all_zero)
	# Mina's case advances: only Mina's flat follows, through the state signal.
	var mina: Dictionary = RealityState.data.cases["mina_caption_crisis"]
	mina.stage = "recognized"
	RealityState.commit()
	var mina_value := float(enc.intensity_for("mina_caption_crisis"))
	var mina_pushed := true
	for row in surfaces["mina_caption_crisis"]:
		mina_pushed = mina_pushed and is_equal_approx(float((row.material as ShaderMaterial).get_shader_parameter("intensity")), mina_value)
	var others_zero := true
	for case_id in surfaces:
		if case_id == "mina_caption_crisis":
			continue
		for row in surfaces[case_id]:
			others_zero = others_zero and float((row.material as ShaderMaterial).get_shader_parameter("intensity")) == 0.0
	_check("a recognised case raises its own flat to the stage value (0.6)",
			is_equal_approx(mina_value, 0.6) and mina_pushed)
	_check("no other flat moves", others_zero)
	# Manifestation lifts above the stage floor; resolution settles to residue.
	mina.manifestation_intensity = 1.0
	RealityState.commit()
	var lifted := float(enc.intensity_for("mina_caption_crisis"))
	mina.stage = "resolved"
	mina.resolved = true
	mina.manifestation_intensity = 1.0
	RealityState.commit()
	var settled := float(enc.intensity_for("mina_caption_crisis"))
	_check("manifestation lifts the intensity above the stage floor", lifted > 0.6 and lifted <= 1.0)
	_check("a resolved case settles to the residue", is_equal_approx(settled, 0.2))
	# The beachhead: Mina's intercom takes the first plate past the threshold.
	mina.stage = "recognized"
	mina.resolved = false
	RealityState.commit()
	var beach: Dictionary = enc.beachheads
	var has_beach := beach.has("mina_caption_crisis")
	var body_textured := false
	if has_beach:
		var node: Node = beach["mina_caption_crisis"].node
		for child in node.find_children("*", "MeshInstance3D", true, false):
			var m := (child as MeshInstance3D).material_override as StandardMaterial3D
			if m != null and m.albedo_texture != null and str(m.albedo_texture.resource_path).contains("mina"):
				body_textured = true
	_check("Mina's intercom is the beachhead and wears her first plate when recognised", has_beach and body_textured)
	mina.stage = "unseen"
	mina.manifestation_intensity = 0.0
	RealityState.commit()
	var body_restored := true
	if has_beach:
		var node: Node = beach["mina_caption_crisis"].node
		for child in node.find_children("*", "MeshInstance3D", true, false):
			var m := (child as MeshInstance3D).material_override as StandardMaterial3D
			if m != null and m.albedo_texture != null and str(m.albedo_texture.resource_path).contains("mina"):
				body_restored = false
	_check("dropping back below the threshold restores the prop", body_restored)
	# Nothing here is a save fact.
	_check("encroachment writes no save key", not RealityState.data.has("encroachment")
			and not mina.has("encroachment"))
	_finish()


func _finish() -> void:
	print("APARTMENT ENCROACHMENT TEST: %s (%d/%d)" % ["PASS" if failures == 0 else "FAIL",
			checks - failures, checks])
	get_tree().quit(failures)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("[encroach ok] " + label)
	else:
		failures += 1
		printerr("[ENCROACH FAIL] " + label)
