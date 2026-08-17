extends Node
## Where does a ceiling go missing, and why does one arcade station see sky?
##
##     SHOT_DIR=<abs> godot --path game res://tests/CeilingStreamingAudit.tscn
##
## Two owner reports arrived pointing at the same number and nobody had
## pointed a camera at either:
##
##   1. "Ceilings sometimes don't render." The offered hypothesis was the
##      seven atrium half-landings, on the reasoning that a body 2.0 m up
##      fails `absf(p.y - z) < 1.75` and hides the floor that owns the
##      ceiling overhead.
##   2. VantryDepthShot's "06_south_gable_lunette_UNRESOLVED" returns night
##      sky from three aisle placements, which was read as the vault not
##      roofing that end of the hall.
##
## This audit measures the rule rather than re-deriving it: it drives the
## REAL `BuildingRoot` streaming path through `view_override` and then reads
## `is_visible_in_tree()` off the REAL nodes. Nothing here re-implements
## `_visibility_signature`, because a re-implemented rule that agrees with
## itself is how this project has produced confident wrong numbers before.
##
## Exit code is the number of findings, so a fix has something to move.

## The rule under test, quoted from building_root.gd so a drift shows up as a
## disagreement between this constant and the measured flip height.
const STREAM_HALF_WINDOW := 1.75
## PlayerController: origin at the FEET, camera STANDING_EYE above it. The
## distinction is the whole audit — the rule is calibrated for one and shot
## harnesses supply the other.
const STANDING_EYE := 1.41

var root: Node3D
var probe: Node3D
var cam: Camera3D
var findings := 0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout
	_hide_capture_ui(get_tree().root)
	# Mid-day, matching VantryDepthShot, so the arcade comparison is against
	# the same circuit and grille state that shot recorded.
	if root.passage_finish != null:
		root.passage_finish.hours_director.apply_for_minute(750.0)
		await get_tree().create_timer(0.5).timeout
	cam = Camera3D.new()
	cam.fov = 66.0
	add_child(cam)
	cam.make_current()
	# The streaming eye and the rendering eye must be the same node, or this
	# measures one position and photographs another. perf_probe.gd records
	# that exact trap.
	probe = cam
	root.view_override = probe
	if root.street_traffic != null:
		root.street_traffic.set_process(false)

	_report_parentage()
	await _sweep_arcade_station()
	_audit_half_landings()
	_audit_every_ceiling()
	_audit_atrium_gallery()
	_audit_ceiling_holes()
	await _captures()

	print("\n[CEILING AUDIT] %d findings" % findings)
	get_tree().quit(findings)


## Establishes the load-bearing structural fact before anything is measured:
## the arcade is not a sibling of the apartment stack, it is PARENTED INTO
## F01. Godot visibility is hierarchical, so hiding F01 hides the arcade
## whatever each arcade node's own `visible` flag says.
func _report_parentage() -> void:
	print("\n=== PARENTAGE ===")
	var f01: Node = root.floor_nodes.get("F01")
	print("F01 node: %s" % f01.get_path())
	print("passage interior draws: %d   shell draws: %d   foreign F01: %d" % [
			root.passage_interior_nodes.size(),
			root.passage_shell_nodes.size(),
			root.passage_foreign_f01_nodes.size()])
	var under := 0
	for g in root.passage_shell_nodes:
		if is_instance_valid(g) and f01.is_ancestor_of(g):
			under += 1
	print("shell draws parented under F01: %d of %d" % [
			under, root.passage_shell_nodes.size()])
	var ceilings := 0
	for fid in root.floor_nodes:
		for c in root.floor_nodes[fid].find_children(
				"*ceiling*", "GeometryInstance3D", true, false):
			ceilings += 1
	print("ceiling draws parented under floor nodes: %d" % ceilings)


## The arcade station, swept through the threshold. VantryDepthShot places
## five working stations at Blender z 1.50-1.62 and the one broken station at
## 2.00. If the flip lands between them, the vault was never the problem.
func _sweep_arcade_station() -> void:
	print("\n=== ARCADE STATION 06, HEIGHT SWEEP ===")
	print("Blender eye [14.0, -60.2, z] looking at the south gable.")
	print("%6s %9s %8s %7s %9s %12s" %
			["z", "in_pass", "in_eye", "F01 vis", "shell vis", "verdict"])
	var flip := -1.0
	var prev := true
	var z := 1.30
	while z <= 2.4001:
		var p: Vector3 = GameBoot.b2g([14.0, -60.2, z])
		probe.global_position = p
		root._update_floor_visibility()
		await get_tree().process_frame
		var f01_visible: bool = root.floor_nodes["F01"].visible
		var shell_visible := 0
		for g in root.passage_shell_nodes:
			if is_instance_valid(g) and g.is_visible_in_tree():
				shell_visible += 1
		print("%6.2f %9s %8s %7s %9d %12s" % [
				z, root._point_is_in_passage(p),
				absf(p.x) < 3.7 and p.z > -3.7 and p.z < 6.9,
				f01_visible, shell_visible,
				"" if f01_visible else "ARCADE GONE"])
		if prev and not f01_visible and flip < 0.0:
			flip = z
		prev = f01_visible
		z += 0.05
	if flip > 0.0:
		print("REGRESSION: F01 disappears at Blender z = %.2f (window %.2f)."
				% [flip, STREAM_HALF_WINDOW])
		print("The Passage is parented into F01, so this culls the whole "
				+ "arcade out from under a camera that is still inside it.")
		print("The floor rule has lost its `in_passage and fid == F01` term.")
		findings += 1
	else:
		print("PASS: F01 survives the full 1.30..2.40 sweep, %d shell draws "
				% _visible_shell_count()
				+ "held throughout.")
		print("This is the guard for the fix of 2026-08-17. Before it, F01 "
				+ "culled at exactly 1.75 and station 06 saw night sky.")


func _visible_shell_count() -> int:
	var n := 0
	for g in root.passage_shell_nodes:
		if is_instance_valid(g) and g.is_visible_in_tree():
			n += 1
	return n


## The offered hypothesis, closed with numbers. Landing heights come from the
## generated layout, never from a constant retyped here.
func _audit_half_landings() -> void:
	print("\n=== THE SEVEN HALF-LANDINGS ===")
	var levels: Dictionary = root.layout["meta"]["levels"]
	var landings: Array = []
	for st in root.layout.get("stairs", []):
		for part in st.get("parts", []):
			if part.get("kind") != "landing":
				continue
			var lz: float = part["z"]
			var is_storey := false
			for fid in levels:
				if absf(float(levels[fid]) - lz) < 0.001:
					is_storey = true
			if not is_storey:
				landings.append(part)
	print("half-landings found in the generated layout: %d" % landings.size())
	print("%8s %8s %9s %8s %s" %
			["landing", "feet y", "in_eye", "hidden", "note"])
	for part in landings:
		var r: Array = part["rect"]
		var cx: float = (float(r[0]) + float(r[2])) * 0.5
		var cy: float = (float(r[1]) + float(r[3])) * 0.5
		# A body STANDS on the landing: PlayerController's origin is its feet.
		var p: Vector3 = GameBoot.b2g([cx, cy, float(part["z"])])
		probe.global_position = p
		root._update_floor_visibility()
		var in_eye: bool = absf(p.x) < 3.7 and p.z > -3.7 and p.z < 6.9
		var hidden: Array[String] = []
		for fid in root.floor_nodes:
			if not root.floor_nodes[fid].visible:
				hidden.append(fid)
		var note := ""
		if in_eye and hidden.is_empty():
			note = "in_eye keeps the whole stack"
		elif not hidden.is_empty():
			note = "HIDES " + ", ".join(hidden)
			findings += 1
		print("%8.2f %8.2f %9s %8d %s" %
				[float(part["z"]), p.y, in_eye, hidden.size(), note])


## The general question the hypothesis was one guess at: over every authored
## ceiling face in the building, can a legal eye beneath it hide the floor
## that owns it? Checked at the feet height a body really has, and at the
## eye height a shot camera really gets parked at.
func _audit_every_ceiling() -> void:
	print("\n=== EVERY CEILING FACE, FROM BENEATH ===")
	var levels: Dictionary = root.layout["meta"]["levels"]
	var total := 0
	var lost_standing := 0
	var lost_at_eye := 0
	var examples: Array[String] = []
	for fl in root.layout.get("floors", []):
		var fid: String = fl["id"]
		if not root.floor_nodes.has(fid):
			continue
		var level: float = float(levels[fid])
		for c in fl.get("ceilings", []):
			total += 1
			var r: Array = c["rect"]
			var cx: float = (float(r[0]) + float(r[2])) * 0.5
			var cy: float = (float(r[1]) + float(r[3])) * 0.5
			# Feet on this floor's slab -- what a player actually supplies.
			probe.global_position = GameBoot.b2g([cx, cy, level])
			root._update_floor_visibility()
			if not root.floor_nodes[fid].visible:
				lost_standing += 1
				if examples.size() < 8:
					examples.append("%s standing" % c["id"])
			# A free camera at eye height -- what every shot harness supplies.
			probe.global_position = GameBoot.b2g([cx, cy, level + STANDING_EYE])
			root._update_floor_visibility()
			if not root.floor_nodes[fid].visible:
				lost_at_eye += 1
				if examples.size() < 8:
					examples.append("%s at eye height" % c["id"])
	print("ceiling faces audited: %d" % total)
	print("owner floor hidden with FEET on its own slab : %d" % lost_standing)
	print("owner floor hidden at EYE height (%.2f m up)  : %d" %
			[STANDING_EYE, lost_at_eye])
	for e in examples:
		print("   e.g. %s" % e)
	if lost_standing > 0:
		findings += 1
		print("A STANDING PLAYER LOSES A CEILING. This is the reported bug.")
	elif lost_at_eye > 0:
		print("No standing player loses a ceiling; only a raised eye does. "
				+ "That makes this a harness-placement rule, not a play bug.")


## A ceiling is the UNDERSIDE OF THE SLAB ABOVE IT. So it has to be cut by
## the openings in THAT slab -- not by the openings in the floor it is filed
## under. `ceiling_pass()` subtracts `fl["slabs"][0]["holes"]`, which is the
## storey's own floor, and the two sets are not the same set.
##
## Everywhere from F01 up they happen to be identical -- atrium well, lift
## shaft and flue run through every storey -- so the mistake is invisible and
## has been since the pass was written. B1 is where they differ: B1's own slab
## is the ground and carries no holes at all, while F01's slab above it carries
## all three. So B1's ceiling seals every one of them.
##
## Nothing streaming-related. This is a data defect, and it survived because
## the streaming question was the one being asked.
func _audit_ceiling_holes() -> void:
	print("\n=== CEILINGS AGAINST THE SLAB ABOVE THEM ===")
	var order := ["B1", "F01", "F02", "F03", "F04", "F05", "F06", "ROOF"]
	var by_id := {}
	for fl in root.layout.get("floors", []):
		by_id[fl["id"]] = fl
	var sealed := 0
	var sealed_area := 0.0
	for i in order.size() - 1:
		var fid: String = order[i]
		var above: String = order[i + 1]
		if not by_id.has(fid) or not by_id.has(above):
			continue
		var holes: Array = []
		for s in by_id[above].get("slabs", []):
			for h in s.get("holes", []):
				holes.append(h)
		for c in by_id[fid].get("ceilings", []):
			for h in holes:
				var a := _overlap_area(c["rect"], h)
				if a <= 0.01:
					continue
				sealed += 1
				sealed_area += a
				print("   %s SEALS %.2f m2 of an opening in %s's slab (%s)" %
						[c["id"], a, above, c["mat"]])
	if sealed > 0:
		findings += 1
		print("%d ceiling faces, %.2f m2, cap a real opening overhead." %
				[sealed, sealed_area])
		print("The atrium stair descends B1 -> F01 through that plane.")
		print("Fix belongs in gen_layout.ceiling_pass(): subtract the holes "
				+ "of the storey ABOVE, not the storey's own.")
	else:
		print("PASS: no ceiling face caps an opening in the slab above it.")


func _overlap_area(a: Array, b: Array) -> float:
	var x0: float = maxf(float(a[0]), float(b[0]))
	var y0: float = maxf(float(a[1]), float(b[1]))
	var x1: float = minf(float(a[2]), float(b[2]))
	var y1: float = minf(float(a[3]), float(b[3]))
	if x1 <= x0 or y1 <= y0:
		return 0.0
	return (x1 - x0) * (y1 - y0)


## Where the `in_eye` exemption ends, recorded because it is the one edge in
## the streaming rule that a person could walk across.
##
## Read this table for what it is. It reports that the exemption stops at
## x = 3.7 while the well only reaches +-3.16, so it ends 0.54 m past the
## well edge and everything beyond loses the other storeys. That is true.
##
## It is NOT, on its own, evidence of a defect, and an earlier draft of this
## function said it was. The light court is ENCLOSED -- the well is flush with
## the court wall faces at +-3.16, and the court is glazed with 0.90 x 1.15
## WIN_COURT openings rather than opening onto a gallery. So a body at x >= 3.7
## is behind masonry, not at a rail, and the storeys it loses were already
## occluded. building_root.gd's own note at the top of `view_override` records
## that the court-window sightline was solved separately, by giving each
## imported floor the opposite wall at its own height.
##
## Kept because the edge is real and cheap to watch: if the court is ever
## opened onto a gallery, this table is where that becomes a bug.
func _audit_atrium_gallery() -> void:
	print("\n=== WHERE in_eye ENDS (court is walled; see note) ===")
	print("well reaches +-3.16; in_eye box is |x|<3.7, -3.7<z<6.9")
	print("%6s %8s %8s %8s %s" % ["floor", "x", "in_eye", "hidden", "note"])
	var levels: Dictionary = root.layout["meta"]["levels"]
	for fid in ["F02", "F04", "F06"]:
		if not root.floor_nodes.has(fid):
			continue
		var level: float = float(levels[fid])
		var x := 2.60
		while x <= 5.6001:
			# Walking away from the well along +x, feet on the slab, level
			# with the gallery. Blender y held at 0 so the sample stays on
			# the well's own centre line.
			var p: Vector3 = GameBoot.b2g([x, 0.0, level])
			probe.global_position = p
			root._update_floor_visibility()
			var in_eye: bool = absf(p.x) < 3.7 and p.z > -3.7 and p.z < 6.9
			var hidden: Array[String] = []
			for other in root.floor_nodes:
				if not root.floor_nodes[other].visible:
					hidden.append(other)
			var note := ""
			if not in_eye and not hidden.is_empty():
				note = "%d storeys culled (behind the court wall)" \
						% hidden.size()
			print("%6s %8.2f %8s %8d %s" %
					[fid, x, in_eye, hidden.size(), note])
			x += 0.30
	print("The exemption ends 0.54 m past the well edge. Benign while the "
			+ "court stays enclosed; watch this if it is ever opened up.")


## Two frames at the same station, differing only in height. If they differ,
## the picture is the argument.
func _captures() -> void:
	var out_dir := OS.get_environment("SHOT_DIR")
	if out_dir == "":
		print("\n(SHOT_DIR unset; skipping captures)")
		return
	await _capture(out_dir, "arcade_station06_z2.00_reported",
			[14.0, -60.2, 2.00], [14.0, -64.5, 6.20])
	await _capture(out_dir, "arcade_station06_z1.60_under_threshold",
			[14.0, -60.2, 1.60], [14.0, -64.5, 6.20])
	# The same gable from the same height the five working stations use,
	# aimed to put the lunette in frame rather than the horizon.
	await _capture(out_dir, "arcade_south_gable_z1.60",
			[14.0, -58.0, 1.60], [14.0, -64.5, 5.80])
	# A half-landing, looking up, because the hypothesis deserves a frame
	# even though the numbers already answered it.
	await _capture(out_dir, "half_landing_z1.60_looking_up",
			[0.0, 2.3, 1.60 + STANDING_EYE], [0.4, 2.3, 6.0])
	# The B1 atrium, looking straight up the well. The stair arrives here from
	# F01, so the shaft has to be open. Before 2026-08-17 a 39.94 m2 plane of
	# pressed tin sat at z -0.185 instead and the stair climbed into a lid. In
	# the atrium centre `in_eye` is true and every storey is visible, so
	# nothing streaming-related can be blamed for this frame either way.
	await _capture(out_dir, "b1_atrium_looking_up",
			[0.0, 0.0, -2.80 + STANDING_EYE], [0.6, 0.0, 4.0])
	# No atrium pair. Two frames were attempted either side of the in_eye
	# edge and both came back solid: at x 3.40 and 4.30 the camera is inside
	# the court wall, because the well is flush with its faces at +-3.16.
	# There is no gallery there to stand on and nothing to photograph, which
	# is itself the answer to whether that edge matters. Left as a comment so
	# the next person does not spend the same two renders finding out.


func _capture(out_dir: String, label: String,
		blender_eye: Array, blender_target: Array) -> void:
	cam.global_position = GameBoot.b2g(blender_eye)
	cam.look_at(GameBoot.b2g(blender_target))
	root._update_floor_visibility()
	await get_tree().create_timer(1.25).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	print("   saved %s" % label)


func _hide_capture_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for child in node.get_children():
		_hide_capture_ui(child)
