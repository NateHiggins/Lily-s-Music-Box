extends Node
## LC-3B / LC-4B — the eight stages and the first death stain, proved on the
## production submission path in the production Dream maze root.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/DreamFaunaVisibleTest.tscn `
##         -ProjectPath <checkout>/game
##
## This suite asserts what the SUBMISSION carries, not what a frame looks like.
## The rendered proof lives in `art/renders/dream_fauna_lifecycle_lc4b/`; a
## packed byte arriving intact is necessary for legibility and is not the same
## claim as legibility, so the two are kept apart on purpose.
##
## Everything is constructed and driven. A life is 45 to 150 seconds, so
## waiting for a stage would assert how long the test ran rather than what the
## owner does.

const Lifecycle = preload("res://scripts/dream/dream_organelle_lifecycle.gd")

var checks := 0
var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous = false
	root.configure_dream({"case_id": "mina_caption_crisis",
			"profile_id": "mina_release_print", "window": {},
			"seed_hex": "f123456789abcdef", "maze_revision": 1,
			"outcome": "", "night_index": 1, "spawn_anchor": 1})
	add_child(root)
	await get_tree().process_frame
	root.set_physics_process(false)
	var fauna = root.fauna
	fauna.set_physics_process(false)
	fauna.refresh()

	var plan_before := var_to_bytes(root.plan)
	var save_before := var_to_bytes(RealityState.data)
	var hazards_before := _hazard_signature(root.hazards)
	var nodes_before: int = fauna.find_children("*", "", true, false).size()

	_pristine(fauna)
	_stage_stream()
	_stage_reaches_submission(fauna)
	_determinism(fauna)
	await _stain(fauna, root)
	_fresh_director()
	_invariants(fauna, root, plan_before, save_before, hazards_before,
			nodes_before)
	_finish()


# --- LC-3B: the packed stage ------------------------------------------------

## Before anything has been driven, nothing has died and nothing is marked.
## Asserted here rather than later because sweeping the room clock across a
## wrap genuinely completes lives -- that is the mechanism working, not a leak.
func _pristine(fauna) -> void:
	var room_key := ""
	for key in fauna.get("_densities"):
		room_key = str(key)
		break
	_check("no stain is submitted before anything has died",
			int(fauna.census().stain_marks) == 0
			and fauna.stain_presentation(room_key).is_empty()
			and int(fauna.stain_census().total) == 0)


func _stage_stream() -> void:
	# Every stage must survive the only bits the GPU keeps exactly. The flag
	# byte is a HIGH byte; bits 6-7 are the sub-index inside the group that
	# BIRTHING/REABSORBING already select.
	var bijective := true
	var bytes := {}
	for stage in 8:
		var byte: int = DreamFaunaDirector.stage_stream_flags(stage)
		bytes[stage] = byte
		bijective = bijective \
				and DreamFaunaDirector.stage_from_stream(byte) == stage \
				and byte >= 0 and byte <= 255
	_check("all eight stages round-trip the packed flag byte %s"
			% [bytes.values()], bijective and bytes.values().size() == 8)

	# The landed semantic grouping is untouched: the stream bits ride beside
	# `stage_flags`, they do not replace it.
	var group_held := true
	for stage in 8:
		var byte: int = DreamFaunaDirector.stage_stream_flags(stage)
		group_held = group_held \
				and (byte & DreamFaunaDirector.stage_flags(stage)) \
						== DreamFaunaDirector.stage_flags(stage)
	_check("the stream byte preserves the landed BIRTHING/REABSORBING groups",
			group_held
			and DreamFaunaDirector.stage_flags(Lifecycle.Stage.BUD)
					== DreamFaunaChannels.FLAG_BIRTHING
			and DreamFaunaDirector.stage_flags(Lifecycle.Stage.STAIN)
					== DreamFaunaChannels.FLAG_REABSORBING)

	# The byte must not collide with the six named flags.
	var no_collision := true
	for stage in 8:
		var bits: int = DreamFaunaDirector.stage_stream_bits(stage)
		no_collision = no_collision \
				and (bits & DreamFaunaDirector.STAGE_STREAM_MASK) == bits
	_check("the stage sub-index never touches a named flag bit", no_collision)


func _stage_reaches_submission(fauna) -> void:
	# Drive the room clock across a whole life and watch the PRODUCTION
	# submission. Every stage must arrive at the packed byte a real instance
	# carries, and every stage must keep full anatomy.
	var densities: Dictionary = fauna.get("_densities")
	var room_key := ""
	for key in densities:
		room_key = str(key)
		break
	var state: Dictionary = densities[room_key]
	var life: Dictionary = state.lifecycle
	var seen := {}
	var min_scale := 9999.0
	var finite := true
	for step in 60:
		life.progress = float(step) / 60.0
		state.lifecycle = life
		fauna.refresh()
		for batch_name in ["GildersButtons", "Tessellates", "WineAnemones",
				"Ribbonettes", "TheLoupe"]:
			var rows: Dictionary = fauna.get("_records").get(batch_name, {})
			var xforms: Array = rows.get("xforms", [])
			var custom: Array = rows.get("custom", [])
			for i in custom.size():
				var decoded: Dictionary = DreamFaunaChannels.decode(custom[i])
				seen[DreamFaunaDirector.stage_from_stream(
						int(decoded.flags))] = true
				var scale: Vector3 = (xforms[i] as Transform3D).basis.get_scale()
				min_scale = minf(min_scale, minf(scale.x,
						minf(scale.y, scale.z)))
				finite = finite and _finite_color(custom[i]) \
						and _finite_vec(scale) \
						and _finite_vec((xforms[i] as Transform3D).origin)
	_check("all eight stages reach the production submission path (%d/8)"
			% seen.size(), seen.size() == 8)
	_check("every stage keeps full nonzero anatomy (smallest axis %.4f)"
			% min_scale, min_scale > 0.001)
	_check("no submitted transform or packed channel is NaN or INF", finite)


func _determinism(fauna) -> void:
	# The same cohort must present identically across a refresh: same packed
	# byte, same transform, same address.
	var before := _presentation_snapshot(fauna)
	fauna.refresh()
	var after := _presentation_snapshot(fauna)
	_check("the same cohort presents identical data after refresh",
			before == after and not before.is_empty())

	# Reproduction mode may move the cosmetic genome and nothing else.
	var densities: Dictionary = fauna.get("_densities")
	var room_key := ""
	for key in densities:
		room_key = str(key)
		break
	var base: Dictionary = (densities[room_key] as Dictionary).lifecycle
	var cosmetic_only := true
	for mode in [Lifecycle.Reproduction.ASEXUAL, Lifecycle.Reproduction.SEXUAL,
			Lifecycle.Reproduction.PANSEXUAL]:
		var probe: Dictionary = base.duplicate(true)
		probe.reproduction = mode
		for motif in 5:
			var a: Dictionary = DreamFaunaDirector.cohort_state(probe, motif, 3)
			var b: Dictionary = DreamFaunaDirector.cohort_state(base, motif, 3)
			cosmetic_only = cosmetic_only \
					and int(a.stage) == int(b.stage) \
					and int(a.stream_flags) == int(b.stream_flags) \
					and int(a.generation) == int(b.generation) \
					and float(a.anatomy_scale) == 1.0
	_check("reproduction changes cosmetic genome only, never the stage stream",
			cosmetic_only)


# --- LC-4B: the stain -------------------------------------------------------

func _stain(fauna, root) -> void:
	var densities: Dictionary = fauna.get("_densities")
	var room_key := ""
	for key in densities:
		room_key = str(key)
		break
	var buttons_before: int = int(fauna.census().buttons)
	var marks_before: int = int(fauna.census().stain_marks)
	var state: Dictionary = densities[room_key]
	var life: Dictionary = state.lifecycle
	life.generation = int(life.generation) + 1
	state.lifecycle = life
	fauna.refresh()

	var marks: int = int(fauna.census().stain_marks)
	var rows: Dictionary = fauna.get("_records").get("GildersButtons", {})
	var custom: Array = rows.get("custom", [])
	var addresses: Array = rows.get("addresses", [])
	var lives: Array = rows.get("life", [])
	var stain_rows := 0
	var stain_shape := true
	for i in custom.size():
		if not bool((lives[i] as Dictionary).get("stain", false)):
			continue
		stain_rows += 1
		var decoded: Dictionary = DreamFaunaChannels.decode(custom[i])
		stain_shape = stain_shape \
				and DreamFaunaDirector.stage_from_stream(int(decoded.flags)) \
						== Lifecycle.Stage.STAIN \
				and (int(decoded.flags) & DreamFaunaChannels.FLAG_REABSORBING) != 0 \
				and float(decoded.activity) == 0.0 \
				and str(addresses[i]).ends_with("@stain") \
				and _finite_color(custom[i])
	_check("a witnessed death submits a stain through GildersButtons "
			+ "(%d marks, %d rows)" % [marks, stain_rows],
			marks > 0 and stain_rows == marks and stain_shape
			and marks >= marks_before)
	# The stage sweep above already completed generations, so marks did not
	# start at zero here. What must hold is that every mark spends exactly one
	# button and no batch appears: buttons move by the same amount marks do.
	_check("each stain spends exactly one Gilder instance and adds no batch "
			+ "(buttons %d->%d, marks %d->%d)"
			% [buttons_before, int(fauna.census().buttons), marks_before, marks],
			fauna.find_children("*", "MultiMeshInstance3D", false,
					false).size() == 5
			and int(fauna.census().buttons) - buttons_before
					== marks - marks_before)
	# A stain must not be mistaken for living tissue by the cohort queries.
	var stain_address := ""
	for i in addresses.size():
		if str(addresses[i]).ends_with("@stain"):
			stain_address = str(addresses[i])
			break
	_check("a stain address exists and resolves to no living cohort (%s)"
			% stain_address,
			not stain_address.is_empty()
			and fauna.cohort_at(stain_address).is_empty()
			and DreamFaunaDirector.parse_cohort_address(stain_address).is_empty())

	# COALESCE. Many more deaths on the same lineages must not spend more
	# instances.
	for _round in 10:
		var s2: Dictionary = densities[room_key]
		var l2: Dictionary = s2.lifecycle
		l2.generation = int(l2.generation) + 1
		s2.lifecycle = l2
		fauna.refresh()
	_check("repeated lineage deaths coalesce rather than spending instances "
			+ "(%d marks, still %d batches)"
			% [int(fauna.census().stain_marks),
			fauna.find_children("*", "MultiMeshInstance3D", false, false).size()],
			int(fauna.census().stain_marks) == marks
			and _total(fauna.census()) <= 96)
	_check("submitted marks never exceed the declared per-room ceiling",
			fauna.stain_presentation(room_key).size()
					<= DreamFaunaDirector.STAIN_SUBMIT_PER_ROOM)

	# SURVIVES STREAMING, IDENTICALLY — and that needs a real round trip.
	# Walk to a named room, let a generation finish there, walk away, walk
	# BACK to the same room, and require the same impressions in the same
	# order still being submitted.
	var architecture := root.get("_architecture") as Node3D
	var path_home := PackedInt32Array([2, 3, 1, 2, 0, 3])
	var path_away := PackedInt32Array([1, 3, 2, 1, 3, 2])
	var key_home := DreamRoomBuilder.key_of(path_home)

	root.rooms.advance(architecture, path_home)
	await get_tree().process_frame
	fauna.refresh()
	var home: Dictionary = fauna.get("_densities")
	if home.has(key_home):
		var st: Dictionary = home[key_home]
		var lf: Dictionary = st.lifecycle
		lf.generation = int(lf.generation) + 1
		st.lifecycle = lf
		fauna.refresh()
	var kept := var_to_bytes(fauna.stain_presentation(key_home))
	var kept_rows := _stain_snapshot(fauna).size()

	root.rooms.advance(architecture, path_away)
	await get_tree().process_frame
	fauna.refresh()
	var while_away: int = fauna.stain_presentation(key_home).size()

	root.rooms.advance(architecture, path_home)
	await get_tree().process_frame
	fauna.refresh()
	_check("stain presentation survives streaming and a real revisit "
			+ "identically (%d impressions, %d rows, %d remembered while away)"
			% [fauna.stain_presentation(key_home).size(), kept_rows, while_away],
			var_to_bytes(fauna.stain_presentation(key_home)) == kept
			and kept_rows > 0 and while_away > 0
			and _stain_snapshot(fauna).size() > 0)


func _fresh_director() -> void:
	var fresh = DreamFaunaDirector.new()
	_check("a new director submits no stain presentation",
			fresh.stain_presentation("anything").is_empty()
			and int(fresh.stain_census().total) == 0)
	fresh.free()


# --- invariants -------------------------------------------------------------

func _invariants(fauna, root, plan_before: PackedByteArray,
		save_before: PackedByteArray, hazards_before: String,
		nodes_before: int) -> void:
	var forbidden := 0
	for node in fauna.find_children("*", "", true, false):
		if node is CollisionObject3D or node is Light3D:
			forbidden += 1
	_check("stages and stains add no node, collision object or light",
			fauna.find_children("*", "", true, false).size() == nodes_before
			and forbidden == 0)
	_check("five batches and the 96 ceiling are unchanged",
			fauna.find_children("*", "MultiMeshInstance3D", false,
					false).size() == 5
			and _total(fauna.census()) <= 96)
	_check("no plan, hazard or RealityState byte moved",
			var_to_bytes(root.plan) == plan_before
			and _hazard_signature(root.hazards) == hazards_before
			and var_to_bytes(RealityState.data) == save_before
			and RealityState.persistence_enabled == false)
	# The closed ether ledger is a landed invariant this pass must not disturb.
	var ledger_closed := true
	for room_key in fauna.density_snapshot():
		var state: Dictionary = fauna.density_snapshot()[room_key]
		ledger_closed = ledger_closed and absf(Lifecycle.cycle_total(
				state.ether_cycle) - 1.0) < 0.00001
	_check("the closed ether ledger is undisturbed", ledger_closed)
	# The inspection report must still render with the new keys present.
	var report: Dictionary = fauna.nearest_to(Vector3.ZERO, "GildersButtons")
	var text := DreamFaunaDirector.inspection_text(report)
	_check("the inspection report is stable and names the stage",
			(report.is_empty() and text == "fauna: none under the crosshair")
			or (text.begins_with("FAUNA") and report.has("life")
					and report.has("address")))


# --- helpers ----------------------------------------------------------------

func _presentation_snapshot(fauna) -> Array:
	var out: Array = []
	for batch_name in ["GildersButtons", "Tessellates", "WineAnemones",
			"Ribbonettes", "TheLoupe"]:
		var rows: Dictionary = fauna.get("_records").get(batch_name, {})
		var xforms: Array = rows.get("xforms", [])
		var custom: Array = rows.get("custom", [])
		var addresses: Array = rows.get("addresses", [])
		for i in custom.size():
			out.append("%s|%s|%s|%s" % [batch_name, xforms[i], custom[i],
					addresses[i] if i < addresses.size() else ""])
	return out


func _stain_snapshot(fauna) -> Array:
	var out: Array = []
	var rows: Dictionary = fauna.get("_records").get("GildersButtons", {})
	var custom: Array = rows.get("custom", [])
	var xforms: Array = rows.get("xforms", [])
	var lives: Array = rows.get("life", [])
	for i in custom.size():
		if i >= lives.size():
			continue
		if not bool((lives[i] as Dictionary).get("stain", false)):
			continue
		out.append("%s|%s" % [xforms[i], custom[i]])
	out.sort()
	return out


func _finite_color(c: Color) -> bool:
	for v in [c.r, c.g, c.b, c.a]:
		if is_nan(float(v)) or is_inf(float(v)):
			return false
	return true


func _finite_vec(v: Vector3) -> bool:
	return not (is_nan(v.x) or is_nan(v.y) or is_nan(v.z)
			or is_inf(v.x) or is_inf(v.y) or is_inf(v.z))


func _hazard_signature(field: DreamHazardField) -> String:
	var rows: Array[String] = []
	for hazard in field.hazards:
		rows.append("%s:%s:%s:%s" % [hazard.id, hazard.tell_started_s,
				hazard.contacted, hazard.contact_s])
	return "|".join(rows)


func _total(c: Dictionary) -> int:
	return int(c.buttons) + int(c.tessellates) + int(c.anemones) \
			+ int(c.ribbonettes) + int(c.loupe)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[VISIBLE FAIL] " + label)
	else:
		print("[visible ok] " + label)


func _finish() -> void:
	print("DREAM FAUNA VISIBLE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
