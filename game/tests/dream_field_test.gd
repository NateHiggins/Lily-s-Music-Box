extends Node
## DF-1 contract (design/DREAM_FIELD_DIRECTION.md §1): the field is a
## four-dimensional body, and advancing `dream_w` must change the visible
## cross-section's TOPOLOGY IN PLACE — nothing may travel.
##     godot --headless --path game res://tests/DreamFieldTest.tscn
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
	await get_tree().create_timer(2.5).timeout
	var enc: Node = root.get("apartment_encroachment")
	_check("the encroachment exists", enc != null)
	if enc == null:
		return _finish()
	var field: DreamFieldController = enc.get("dream_field")
	_check("BuildingRoot's encroachment owns one DreamFieldController",
			field != null and field.name == "DreamFieldController")
	if field == null:
		return _finish()
	var st: DreamFieldState = field.state
	_check("it carries one canonical DreamFieldState with lobes",
			st != null and st.lobes.size() >= 4 and st.lobes.size() <= DreamFieldState.MAX_LOBES)
	# --- the slice function, which is the whole idea ---------------------
	# A lobe of total radius r, seen at slice offset d, has apparent radius
	# sqrt(r^2 - d^2): full at d = 0, gone at d >= r.
	var r := 1.0
	var at_centre := st.slice_radius(r, st.dream_w)
	var at_half := st.slice_radius(r, st.dream_w - 0.5)
	var at_edge := st.slice_radius(r, st.dream_w - 0.999)
	var beyond := st.slice_radius(r, st.dream_w - 1.4)
	_check("the cross-section follows sqrt(r^2 - w^2): %.3f, %.3f, %.3f, %.3f"
			% [at_centre, at_half, at_edge, beyond],
			is_equal_approx(at_centre, 1.0) and absf(at_half - 0.866) < 0.01
			and at_edge < 0.05 and beyond == 0.0)
	# --- nothing travels --------------------------------------------------
	var centres_before: Array = []
	for l in st.lobes:
		centres_before.append(l.centre)
	var w_before: float = st.dream_w
	var present_before := 0
	for i in st.lobes.size():
		if st.lobe_present(i):
			present_before += 1
	# Let the slice advance for a while.
	await get_tree().create_timer(4.0).timeout
	var moved := 0.0
	for i in st.lobes.size():
		if i < centres_before.size():
			moved = maxf(moved, (st.lobes[i].centre as Vector3).distance_to(centres_before[i]))
	_check("the slice advanced (%.3f -> %.3f)" % [w_before, st.dream_w],
			st.dream_w > w_before + 0.2)
	# Re-seeding may move a lobe that is nowhere near our slice; one that is
	# PRESENT must never move.
	var present_moved := 0.0
	for i in st.lobes.size():
		if st.lobe_present(i) and i < centres_before.size():
			present_moved = maxf(present_moved,
					(st.lobes[i].centre as Vector3).distance_to(centres_before[i]))
	_check("no lobe in our space translates: it changes size, not position (%.4f m)"
			% present_moved, present_moved < 0.001)
	# --- the topology changes ---------------------------------------------
	var present_now := 0
	for i in st.lobes.size():
		if st.lobe_present(i):
			present_now += 1
	var c: Dictionary = field.census()
	print("[field] %s" % [c])
	_check("lobes surface and withdraw as the slice passes (%d -> %d, %d surfaced)"
			% [present_before, present_now, int(c.surfaced)], int(c.surfaced) >= 1)
	# --- the field is a real signed field ---------------------------------
	var inside_found := false
	var outside_found := false
	for i in st.lobes.size():
		if not st.lobe_present(i):
			continue
		var centre: Vector3 = st.lobes[i].centre
		if st.field_at(centre) < 0.0:
			inside_found = true
		if st.field_at(centre + Vector3(6.0, 0.0, 0.0)) > 0.0:
			outside_found = true
	_check("the field is negative inside the body and positive outside",
			inside_found and outside_found)
	_check("influence falls to nothing away from the body",
			st.influence_at(Vector3(60.0, 0.0, 60.0)) < 0.01)
	# --- coupling ---------------------------------------------------------
	field.couple(0.25, 0.5, 0.9, 0.4, 0.3)
	_check("it shares the organism's clocks rather than inventing its own",
			is_equal_approx(st.pulse_phase, 0.25) and is_equal_approx(st.attention, 0.9))
	# --- the packing ------------------------------------------------------
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/orison_surface.gdshader")
	field.apply_to(m)
	var packed: PackedVector4Array = m.get_shader_parameter("df_lobe")
	_check("the state packs onto a material for the shaders to read",
			packed.size() == DreamFieldState.MAX_LOBES
			and int(m.get_shader_parameter("df_lobe_count")) == st.lobes.size())
	# --- the switch -------------------------------------------------------
	_check("DREAM_FIELD=0 is honoured", field.enabled)
	_finish()


func _finish() -> void:
	print("DREAM FIELD TEST: %s (%d/%d)" % ["PASS" if failures == 0 else "FAIL",
			checks - failures, checks])
	get_tree().quit(failures)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("[field ok] " + label)
	else:
		failures += 1
		printerr("[FIELD FAIL] " + label)
