extends Node
## §12 STEPS 8 AND 9, PHOTOGRAPHED — THE FINE CILIA, AND THE TASK COMPLETING.
##
##     SHOT_DIR=<abs path> ./Godot_v4.7.1-stable_win64_console.exe \
##             --path game res://tests/DreamStep12CiliaShot.tscn
##
## §12's canonical sequence is twelve steps. Ten of them were built; steps 8
## and 9 were not, and the reason they were not is visible in the renderer:
## `palp_matter.w` has carried an individual's cilia fraction since the
## morphology existed and it drove a four-millimetre tremor in GDScript. There
## was no cilia GEOMETRY on a palp at all.
##
## So this asks the two questions a photograph can settle and a test cannot.
##
##   ARE THEY ANATOMY, OR ARE THEY AN EFFECT? The governing sentence of §12 is
##   "never spawn a branch by scaling a cylinder from zero", and it applies to
##   cilia exactly as it applies to branches. A hair that fades in, or grows
##   out, or is a puff of light on the shaft, has failed. So the sheet holds
##   the hairs BEFORE they deploy -- lying along the shaft, full length, in
##   their sockets -- beside the same hairs erect. If those are the same
##   hairs at the same size the claim is true, and if they are not it is a
##   spawn effect wearing the right numbers.
##
##   IS THE ORDER LEGIBLE? Not "did the state machine run in order" -- the
##   contract test settles that -- but whether a person watching can tell
##   investigating from deploying from finishing from putting away.
##
## AND IT IS AN A/A CONTROL, not a before-and-after. The steps 2-4 crease proof
## learned this the expensive way: live motion, the breathing term and the
## surface's own noise move enough between two takes that two frames of the
## same organ at different moments differ for reasons that have nothing to do
## with the feature. So `_control_row` holds FOUR IDENTICAL BRANCHES -- same
## morphology, same seed, same pose, same lamp, same frame -- in four different
## states of the sequence. Everything that differs between them is the state.
##
## The last section prices it. The claim being made about the cilia is that
## they cost geometry and not SUBMISSIONS, and the frame is submission-bound
## (`design/DT4_PERFORMANCE_REAUDIT.md`), so that claim is the whole reason
## they live in the batch. It is measured against a control mesh built to the
## pre-change vertex layout, in the same process at the same camera.

const StageScript := preload("res://tests/dream_stage.gd")
const MorphologyScript := preload("res://scripts/dream/margin/dream_palp_morphology.gd")
const BehaviorScript := preload("res://scripts/dream/margin/dream_palp_behavior.gd")

## Where the row of hosts stands on the hero's wall, and which way it faces.
## Well clear of `dream_stage.hero_at` so the creature is never in shot.
const ROW_AT := Vector3(-2.95, 1.30, -1.20)
const ROW_N := Vector3(1.0, 0.0, 0.0)
const ROW_SPACING := 0.34

## Frame deltas per configuration in the pricing section, and how many frames
## to throw away first while the pipeline settles.
const PERF_SAMPLES := 240
const PERF_WARMUP := 45

var stage
var _dir := ""
var _frames := 0
var _log: Array[String] = []


func _ready() -> void:
	stage = StageScript.new()
	add_child(stage)
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = "user://dream_ecology_step12_cilia"
	DirAccess.make_dir_recursive_absolute(_dir)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	call_deferred("_run")


func _run() -> void:
	# Enough for the field to have live lobes to raise a margin against.
	await get_tree().create_timer(2.5).timeout
	# NOBODY ELSE MOVES. The hero and the critters are running their own lives
	# a metre and a half away and every one of these frames is a macro shot of
	# a two-centimetre structure; an animal wandering through it is noise in
	# the one measurement the sheet exists to make.
	for who in [stage.hero, stage.critters, stage.director, stage.residue]:
		if who != null:
			who.set_process(false)
			who.set_physics_process(false)
	stage.margin.frozen = true
	# AND THE SOCIETY IS NOT INVITED TO A COMPARISON SHEET. §10's avoidance
	# pushes crowded tips apart and the hero broadcast pulls them toward the
	# creature -- both correct, and both fatal to a row of four organs meant to
	# differ in exactly one thing. The first sheet came out with its four
	# branches scattered over a metre of wall in three axes. Put back before
	# the pricing section, which wants a real population.
	stage.margin.hero = null
	stage.margin.critters = null
	# The player's lamp is 5.5 at the lens, which is right for a room and
	# clips a shaft to flat white at half a metre. Dimmed for the macro work
	# only; it is still the player's own lamp from the player's own position.
	stage.lamp.light_energy = 1.15
	stage.lamp.spot_angle = 34.0

	await _control_row()
	await _sequence_ladder()
	await _price_it()

	var readme := FileAccess.open(_dir.path_join("README.md"), FileAccess.WRITE)
	if readme != null:
		readme.store_string(_readme())
		readme.close()
	print("[step12] DONE %d frames -> %s" % [_frames, _dir])
	get_tree().quit(0)


# ---------------------------------------------------------------------------
# THE A/A CONTROL: ONE FRAME, FOUR STATES, IDENTICAL ANATOMY
# ---------------------------------------------------------------------------

## Four hosts of one archetype in a row, one branch each, every branch given
## the SAME morphology from one seed -- so the four are the same organ, and
## the only thing that differs between them is where in §12's sequence they
## are. Left to right: investigating with the cilia still folded, deploying
## mid-wave, fully deployed, and the completion beat.
func _control_row() -> Array:
	var margin = stage.margin
	margin.palps.clear()
	var side := Vector3.UP.cross(ROW_N).normalized()
	var states := [
		{"out": 0.0, "beat": 0.0, "name": "investigating"},
		{"out": 0.40, "beat": 0.0, "name": "deploying"},
		{"out": 1.0, "beat": 0.0, "name": "deployed"},
		{"out": 1.0, "beat": 1.0, "name": "completing"},
	]
	var branches: Array = []
	for i in states.size():
		var at: Vector3 = ROW_AT + side * (float(i) - 1.5) * ROW_SPACING
		margin._birth_specific(margin.TIER_PRIMARY, at, ROW_N,
				MorphologyScript.Kind.SOFT_PALP)
		var host: Dictionary = margin.palps[margin.palps.size() - 1]
		# THE HOSTS MATCH AS WELL. They are the same archetype but four
		# different individuals, and §6 varies length, taper, stiffness and
		# mineral inside an archetype -- so four differently proportioned
		# parents hold their branches at four different angles and the sheet
		# compares poses as much as states.
		host.morph = _host_morph()
		# §12 step 1: it branches because it found something.
		#
		# And it BRACES on it. §9's brace is the one primitive that does not
		# move at all, and a branch's base and aim are taken from its parent's
		# pose every frame -- so an unplanted host means four organs drifting to
		# four different places and a comparison sheet that compares poses. The
		# ladder plants its host for the same reason.
		host.target = at + ROW_N * float(host.morph.length) * 0.95
		host.act = BehaviorScript.Act.BRACE
		margin.try_branch(int(host.id))
		# One branch each. Siblings are correct anatomy and wrong for a
		# comparison sheet: four organs with two or three branches apiece is
		# a thicket, and the question is what ONE branch's cilia look like.
		var mine: Array = []
		for p in margin.palps:
			if int(p.parent) == int(host.id):
				mine.append(p)
		for extra in range(1, mine.size()):
			margin.palps.erase(mine[extra])
		if mine.is_empty():
			continue
		branches.append(mine[0])
	# THE SAME ORGAN FOUR TIMES. A branch takes its archetype from a roll, and
	# a crystal feeler beside a soft palp differs in section, taper and mineral
	# before anything about cilia is considered. One morphology, one seed.
	var shared = _branch_morph()
	for b in branches:
		b.morph = shared
		b.cilia_band = 0.62
		b.spread = 0.0
		b.life = 900.0
	# Lay them out: unfolding happens in `_think`, and a branch that has not
	# been stepped is still lying inside its parent. The hosts are held ON
	# their targets while it happens -- a braced tip still gets a shove from
	# the social pass every time it runs, and four organs a hand-span apart
	# shove each other hard.
	var hosts: Array = []
	for p in margin.palps:
		if int(p.parent) < 0:
			hosts.append(p)
	for _s in 60:
		for h in hosts:
			h.tip = h.target
		margin._think(0.05)
	for i in branches.size():
		var b: Dictionary = branches[i]
		b.unfold = 1.0
		b.cilia_out = float(states[i]["out"])
		b.task_left = DreamMarginController.TASK_S * 0.5 \
				if float(states[i]["beat"]) > 0.0 else 0.0
		b.act = BehaviorScript.Act.BRACE
	# One more step so the spine and the tip settle against the forced unfold.
	margin._think(0.02)
	for i in branches.size():
		branches[i].unfold = 1.0
		branches[i].cilia_out = float(states[i]["out"])
		branches[i].task_left = DreamMarginController.TASK_S * 0.5 \
				if float(states[i]["beat"]) > 0.0 else 0.0

	var mid := Vector3.ZERO
	for b in branches:
		mid += (b.anchor as Vector3).lerp(b.tip, 0.6)
	mid /= maxf(1.0, float(branches.size()))
	print("[step12] control row: %d palps, %d branches, renderer %s"
			% [margin.palps.size(), branches.size(), stage.palps.census()])
	for b in branches:
		print("[step12]   branch %d anchor %s tip %s unfold %.2f cilia %.2f"
				% [int(b.id), b.anchor, b.tip, float(b.unfold),
				float(b.cilia_out)])
	# AN ESTABLISHING FRAME FIRST. If the row is not in this one the macro
	# frames below are photographs of a wall, and it took a wall to work that
	# out the first time.
	var wide: Dictionary = stage.wide_stand()
	await _stand(wide.eye, mid)
	await _shot("0a_establishing")
	_note("0a_establishing.png — the row in the room, so the macro frames"
			+ " below can be located.")
	# THIS FRAME IS CONTEXT, AND IT IS NOT WHERE THE FINE DETAIL LIVES. Pushed
	# in to read a hair, the near organs foreshorten into the lens and the row
	# stops being a row -- so it stands off far enough to hold all four states
	# side by side, and 01 to 04 below carry the anatomy at macro distance from
	# the same four individuals.
	stage.lamp.light_energy = 0.90
	await _stand(mid + ROW_N * 0.85 + Vector3.UP * 0.06, mid)
	await _shot("00_control_row_four_states")
	_note("00_control_row_four_states.png — four IDENTICAL branches, one frame."
			+ " Left to right: investigating (cilia folded along the shaft),"
			+ " deploying (the wave part way down the band), deployed, and the"
			+ " completion beat. Same morphology, same seed, same lamp.")
	# CLOSER, because the whole question is whether the folded hairs are the
	# same hairs at the same length as the erect ones, and at row distance a
	# two-centimetre hair is a few pixels.
	#
	# `01` is the strongest frame on the sheet and it is not a pair at all:
	# mid-deployment the wave is PART WAY down the band, so one organ in one
	# frame carries erect hairs at its proximal end and the same hairs still
	# lying flat at its distal end. Nothing differs between the two ends --
	# not the lamp, not the moment, not the individual -- except how far
	# through step 8 that part of the band is.
	#
	# `02` and `03` are then the conventional A/A: folded and deployed, same
	# distance, same offset, same lamp, same organ in two states.
	if branches.size() >= 4:
		await _macro(branches[1], "01_wave_on_one_organ",
				"mid-deployment on ONE organ: the wave runs down the band, so the"
				+ " proximal hairs are erect while the distal ones are still lying"
				+ " along the shaft. Same hairs, same length, different angle --"
				+ " which is the whole claim, inside a single frame.")
		await _macro(branches[0], "02_macro_folded",
				"folded. The cilia are ON the organ, at full length, lying along"
				+ " the shaft as fine longitudinal relief.")
		await _macro(branches[2], "03_macro_deployed",
				"deployed, at the same distance and offset as 02. The same hairs,"
				+ " stood off the surface. Nothing was created and nothing grew.")
		await _macro(branches[3], "04_macro_completing",
				"§12 step 9, at the same stand again: the band closes forward"
				+ " together onto the finished target, and the tissue under it"
				+ " floods the way the crease floods at step 2.")
	stage.lamp.light_energy = 1.15
	return branches


## One branch, close, from ACROSS its shaft -- end-on, a shaft hides every hair
## on it, which is the same mistake the hero emergence ladder had to be moved
## for. The stand is derived from the branch's own axis, so every macro frame
## is the same offset from its subject and they compare directly.
func _macro(b: Dictionary, file: String, note: String) -> void:
	var mid: Vector3 = (b.anchor as Vector3).lerp(b.tip, 0.62)
	var along: Vector3 = ((b.tip as Vector3) - (b.anchor as Vector3)).normalized()
	var across: Vector3 = along.cross(Vector3.UP).normalized()
	if across.dot(ROW_N) < 0.0:
		across = -across
	# ONE PAIR IN THE FRAME. The row is four hosts a hand-span apart and at
	# macro distance the neighbours cross the shot at every angle -- the first
	# version of this frame had four organs in it and no way to tell which one
	# was the subject. The others are held at grow 0 for the exposure, which
	# collapses them in the vertex stage, and put back straight afterwards.
	var pid: int = int(b.parent)
	var hidden: Array = []
	for p2 in stage.margin.palps:
		if p2 == b or int(p2.id) == pid:
			continue
		hidden.append([p2, float(p2.grow)])
		p2.grow = 0.0
	# The player's lamp rides the lens and this stand is a couple of hand-widths
	# from a two-centimetre structure. At 1.15 it is a white hole. This is the
	# only place the lamp goes below what a room needs, and it is the same value
	# for every macro frame so they stay comparable.
	stage.lamp.light_energy = 0.55
	await _stand(mid + across * 0.22 + Vector3.UP * 0.035, mid)
	await _shot(file)
	for row in hidden:
		row[0].grow = float(row[1])
	_note("%s.png — %s" % [file, note])


# ---------------------------------------------------------------------------
# THE LADDER: ONE BRANCH, STEPPED THROUGH THE SEQUENCE
# ---------------------------------------------------------------------------

## The same branch photographed at each named beat of §12's steps 7 to 11,
## driven by hand. Physics frames are a poor clock -- the margin is one node in
## a loaded building and does not step on every one of them -- and driving it
## directly is also what stops the population growing underneath the shot.
func _sequence_ladder() -> void:
	var margin = stage.margin
	margin.palps.clear()
	margin._birth_specific(margin.TIER_PRIMARY, ROW_AT, ROW_N,
			MorphologyScript.Kind.SOFT_PALP)
	var host: Dictionary = margin.palps[0]
	# The same host and branch anatomy the control sheet used, so the ladder
	# and the sheet are photographs of one organ.
	host.morph = _host_morph()
	host.target = ROW_AT + ROW_N * float(host.morph.length) * 0.95
	host.act = BehaviorScript.Act.BRACE
	host.life = 900.0
	margin.try_branch(int(host.id))
	var kid: Dictionary = {}
	for p in margin.palps:
		if int(p.parent) == int(host.id):
			kid = p
			break
	if kid.is_empty():
		push_warning("[step12] no branch for the ladder")
		return
	var kid_id: int = int(kid.id)
	kid.morph = _branch_morph()
	kid.cilia_band = 0.62
	kid.spread = 0.0
	kid.life = 30.0

	# GET IT OUT OF ITS PARENT FIRST, so the stand can be composed on where the
	# branch actually is rather than on where it started -- but hold step 8 off
	# while that happens. Unfolding takes 1.33 s and deployment begins 0.55 s
	# after investigation does, which lands INSIDE this loop: the first version
	# composed its camera, started the ladder, and found the branch already
	# past the frame it was waiting for.
	# `_age` RUNS IN HERE TOO. A branch is created at grow 1.0 and `_age` then
	# ramps it up from 0 over its first 0.9 s -- entirely while it is still
	# folded inside its parent, so none of that is visible in play. But a
	# pre-loop that steps `_think` without `_age` leaves the branch at unfold
	# 1.0 and grow 0.04, and the first rung of the ladder came out as a
	# photograph of the parent with nothing on it.
	for _s in 45:
		kid.investigate = 0.0
		_plant(host, kid)
		margin._think(0.04)
		margin._age(0.04)
	kid.investigate = 0.0
	# ACROSS THE BRANCH, NOT UP IT, and at the same macro stand the control
	# frames use, so the ladder and the sheet are the same photograph.
	var look: Vector3 = (kid.anchor as Vector3).lerp(kid.tip, 0.62)
	var along: Vector3 = ((kid.tip as Vector3) - (kid.anchor as Vector3)).normalized()
	var across: Vector3 = along.cross(Vector3.UP).normalized()
	if across.dot(ROW_N) < 0.0:
		across = -across
	stage.lamp.light_energy = 0.55
	await _stand(look + across * 0.20 + Vector3.UP * 0.035, look)

	var want := [
		{"file": "10_investigating", "note": "step 7 -- the branch is out and"
				+ " working a target of its own. Its cilia are on it, folded"
				+ " along the shaft, and have not been asked for yet."},
		{"file": "11_deploy_early", "note": "step 8 beginning. Deployment runs"
				+ " DOWN the band from the proximal end, so the near hairs are"
				+ " up while the far ones are still lying down."},
		{"file": "12_deploy_late", "note": "step 8, the wave most of the way"
				+ " along the band."},
		{"file": "13_deployed", "note": "step 8 complete -- the whole band"
				+ " erect. Same hairs, same length as frame 10."},
		{"file": "14_completing", "note": "step 9, the completion beat: the"
				+ " branch plants, the band closes forward together, and the"
				+ " tissue under it floods the way the crease floods at step"
				+ " 2. It has a real duration, it is not an edge."},
		{"file": "15_retracting", "note": "step 10 -- the fine anatomy going"
				+ " back in. The branch is still out and still full size."},
		{"file": "16_folding", "note": "step 11 -- and only NOW does the"
				+ " branch begin to fold. The cilia are already in."},
		{"file": "17_simple_again", "note": "step 12 -- the parent back to"
				+ " simpler topology, carrying no evidence of any of it."},
	]
	var stage_i := 0
	var was_full := false
	for _step in 700:
		_plant(host, kid)
		margin._think(0.04)
		margin._age(0.04)
		var alive := false
		for p in margin.palps:
			if int(p.id) == kid_id:
				alive = true
				break
		var out_at: float = float(kid.cilia_out)
		if out_at >= 0.999:
			was_full = true
		var hit := -1
		# `not was_full` matters: "unfolded, and no cilia out" is true both
		# before step 8 and after step 10, and without it the first rung waits
		# for the beginning and photographs the end.
		if stage_i == 0 and float(kid.unfold) >= 0.99 and out_at <= 0.0 				and not was_full:
			hit = 0
		elif stage_i == 1 and out_at > 0.20 and out_at < 0.45:
			hit = 1
		elif stage_i == 2 and out_at > 0.70 and out_at < 0.95:
			hit = 2
		elif stage_i == 3 and out_at >= 0.999 and float(kid.task_left) <= 0.0:
			hit = 3
		elif stage_i == 4 and float(kid.task_left) > 0.0:
			hit = 4
		elif stage_i == 5 and was_full and out_at < 0.75 and alive \
				and not bool(kid.folding):
			hit = 5
		elif stage_i == 6 and bool(kid.folding):
			hit = 6
		elif stage_i == 7 and not alive:
			hit = 7
		if hit < 0:
			continue
		var row: Dictionary = want[hit]
		await _shot("%s" % row["file"])
		_note("%s.png — %s" % [row["file"], row["note"]])
		print("[step12] %s: unfold %.2f cilia %.2f beat %.2f folding %s"
				% [row["file"], float(kid.unfold), out_at,
				float(kid.task_left), bool(kid.folding)])
		stage_i += 1
		if stage_i >= want.size():
			break
	if stage_i < want.size():
		push_warning("[step12] ladder stopped at %d of %d"
				% [stage_i, want.size()])


# ---------------------------------------------------------------------------
# WHAT IT COSTS
# ---------------------------------------------------------------------------

## The pre-change vertex layout, rebuilt here as a control.
##
## This is a copy of `DreamPalpRenderer._build_mesh` WITHOUT the cilia run,
## and it exists so the price of the new anatomy is measured against the mesh
## it replaced rather than against an opinion. Same camera, same population,
## same process, one mesh swapped.
func _body_only_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for p in DreamPalpRenderer.MAX_PALPS:
		var base := verts.size()
		for r in DreamPalpRenderer.RINGS:
			var v := pow(float(r) / float(DreamPalpRenderer.RINGS - 1), 1.5)
			for s in DreamPalpRenderer.SEGS:
				var u := float(s) / float(DreamPalpRenderer.SEGS - 1)
				var a := u * TAU
				verts.append(Vector3(cos(a), sin(a), v))
				normals.append(Vector3(cos(a), sin(a), 0.0))
				uvs.append(Vector2(u, v))
				uv2.append(Vector2(float(p), 0.0))
		for r in DreamPalpRenderer.RINGS - 1:
			for s in DreamPalpRenderer.SEGS - 1:
				var a0 := base + r * DreamPalpRenderer.SEGS + s
				indices.append(a0)
				indices.append(a0 + DreamPalpRenderer.SEGS)
				indices.append(a0 + 1)
				indices.append(a0 + 1)
				indices.append(a0 + DreamPalpRenderer.SEGS)
				indices.append(a0 + DreamPalpRenderer.SEGS + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	return mesh


func _price_it() -> void:
	var margin = stage.margin
	var renderer = stage.palps
	# The full ecology again: the price has to be the price of a real margin.
	margin.hero = stage.hero
	margin.critters = stage.critters
	stage.critters.set_process(true)
	stage.critters.set_physics_process(true)
	# A REAL POPULATION, not the four-organ sheet. Let it fill the room from
	# the wide stand, which is where a player stands.
	margin.palps.clear()
	margin.frozen = false
	var stand: Dictionary = stage.wide_stand()
	stage.camera.global_position = stand.eye
	stage.camera.look_at(stand.look, Vector3.UP)
	stage.lamp.light_energy = 5.5
	stage.lamp.spot_angle = 46.0
	await get_tree().create_timer(12.0).timeout
	margin.frozen = true
	var live: int = margin.palps.size()
	var with_cilia: Mesh = renderer.mesh_instance.mesh

	print("\n[step12] WHAT THE FINE ANATOMY COSTS")
	print("[step12] %d appendages live, %d drawn, renderer %s"
			% [live, renderer.drawn, renderer.census()])
	print("%-34s %7s %7s %9s %8s %8s %8s %8s" % ["configuration", "objects",
			"calls", "prims", "median", "p05", "p95", "wall"])
	var rows: Array = []
	# WORST CASE FIRST AND LAST IS THE CONTROL, so any drift in the machine
	# over the run shows up as the two cilia rows disagreeing with each other.
	rows.append(await _time_it("cilia folded (cilia_out 0)",
			func(): _set_all_cilia(0.0, 0.0)))
	rows.append(await _time_it("cilia deployed on EVERY palp",
			func(): _set_all_cilia(1.0, 0.0)))
	rows.append(await _time_it("deployed + completion beat",
			func(): _set_all_cilia(1.0, DreamMarginController.TASK_S * 0.5)))
	renderer.mesh_instance.mesh = _body_only_mesh()
	rows.append(await _time_it("CONTROL: pre-change mesh, no cilia",
			func(): _set_all_cilia(0.0, 0.0)))
	renderer.mesh_instance.mesh = with_cilia
	rows.append(await _time_it("cilia folded again (drift check)",
			func(): _set_all_cilia(0.0, 0.0)))

	var control: Dictionary = rows[3]
	var folded: Dictionary = rows[0]
	var deployed: Dictionary = rows[1]
	print("\n[step12] draw calls: control %d, with cilia %d — %s"
			% [int(control.calls), int(folded.calls),
			"UNCHANGED" if int(control.calls) == int(folded.calls)
			else "CHANGED, which is the one thing this must not do"])
	print("[step12] frame, against the pre-change mesh at the same camera:")
	print("[step12]   folded   %+.3f ms (%.2f -> %.2f wall)"
			% [float(folded.wall) - float(control.wall), float(control.wall),
			float(folded.wall)])
	print("[step12]   deployed %+.3f ms (%.2f -> %.2f wall)"
			% [float(deployed.wall) - float(control.wall), float(control.wall),
			float(deployed.wall)])
	print("[step12] and the two folded runs differed by %.3f ms, which is the"
			% absf(float(folded.wall) - float(rows[4].wall))
			+ " noise floor any claim above has to clear.")
	_note("")
	_note("PRICE (measured, same process, same camera, %d appendages):" % live)
	for r in rows:
		_note("  %-34s calls %d  median %.2f ms  wall %.2f ms"
				% [r.name, int(r.calls), float(r.median), float(r.wall)])


func _set_all_cilia(out_at: float, beat: float) -> void:
	for p in stage.margin.palps:
		p.cilia_out = out_at
		p.cilia_band = 0.62
		p.task_left = beat


## MEASURE THE FRAME, NOT THE FPS COUNTER. `1000.0 / Performance.TIME_FPS` is
## an integer inverted and it has lied in this project before -- 21 and 22 fps
## are 47.6 ms and 45.5 ms with nothing between them. Frame deltas, a median
## with p05-p95 beside it because the mean of this distribution is decided by
## its outliers, and wall clock over the window as ground truth.
func _time_it(label: String, apply: Callable) -> Dictionary:
	for i in PERF_WARMUP:
		apply.call()
		await get_tree().process_frame
	var samples: Array[float] = []
	var t0 := Time.get_ticks_usec()
	for i in PERF_SAMPLES:
		apply.call()
		await get_tree().process_frame
		samples.append(get_process_delta_time() * 1000.0)
	var wall := float(Time.get_ticks_usec() - t0) / 1000.0 / float(PERF_SAMPLES)
	samples.sort()
	var median: float = samples[PERF_SAMPLES / 2]
	var p05: float = samples[int(PERF_SAMPLES * 0.05)]
	var p95: float = samples[int(PERF_SAMPLES * 0.95)]
	var objs := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var calls := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("%-34s %7d %7d %9d %8.2f %8.2f %8.2f %8.2f"
			% [label, objs, calls, prims, median, p05, p95, wall])
	return {"name": label, "objects": objs, "calls": calls, "prims": prims,
			"median": median, "p05": p05, "p95": p95, "wall": wall}


# ---------------------------------------------------------------------------

## ONE HOST ANATOMY AND ONE BRANCH ANATOMY, FOR THE WHOLE SHEET.
##
## §6 varies proportion inside an archetype and §12 rolls a branch's archetype,
## so left to itself a row of four is four different organs and the comparison
## is worthless. Both come from one seed here, at the same scaling `_birth` and
## `try_branch` apply, so what is photographed is a real appendage and a real
## branch -- just the SAME one four times.
func _host_morph():
	var m = MorphologyScript.generate(MorphologyScript.Kind.SOFT_PALP, 4477)
	m.length *= DreamMarginController.TIER_SCALE[0]
	m.base_radius *= DreamMarginController.TIER_SCALE[0]
	return m


func _branch_morph():
	var m = MorphologyScript.generate(MorphologyScript.Kind.SOFT_PALP, 8191)
	m.length *= 0.42
	m.base_radius *= 0.5
	return m


## HOLD THE POSE. Eight rungs of a ladder are only a ladder if the only thing
## changing between them is the step of the sequence. §9's brace plants a tip
## and stops moving it, which is exactly what is wanted -- and it has to be
## re-asserted every tick because `next_act` will hand the organ something else
## to do the moment its act timer runs down. Step 9 sets BRACE itself, so this
## agrees with the feature rather than fighting it.
func _plant(host: Dictionary, kid: Dictionary) -> void:
	for p in [host, kid]:
		if int(p.act) != BehaviorScript.Act.BRACE:
			p.act = BehaviorScript.Act.BRACE
			p.act_clock = 0.0
		p.act_left = 9.0


func _stand(eye: Vector3, look: Vector3) -> void:
	stage.camera.global_position = eye
	stage.camera.look_at(look, Vector3.UP)
	await get_tree().process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
			_dir.path_join("%s.png" % file))
	_frames += 1


func _note(line: String) -> void:
	_log.append(line)


func _readme() -> String:
	var out := "# §12 STEPS 8 AND 9 — FINE CILIA, AND THE TASK COMPLETING\n\n"
	out += "Ecology architecture §12. Captured by\n"
	out += "`game/tests/dream_step12_cilia_shot.gd`.\n\n"
	out += "The canonical sequence is twelve steps. Steps 1-7 and 10-12 were\n"
	out += "built; 8 and 9 were not, because there was no cilia GEOMETRY on a\n"
	out += "palp anywhere -- `palp_matter.w` carried the individual's cilia\n"
	out += "fraction and drove a four-millimetre tremor in GDScript.\n\n"
	out += "The rule these frames have to satisfy is the governing sentence of\n"
	out += "§12: **never spawn a branch by scaling a cylinder from zero.** It\n"
	out += "applies to a hair as much as to a branch. So the cilia are full\n"
	out += "length at every moment, seated in the shaft's own surface, and\n"
	out += "deployment turns them through an angle.\n\n"
	out += "`00` is the A/A control: four IDENTICAL branches -- one host\n"
	out += "morphology, one branch morphology, one seed, one lamp -- side by\n"
	out += "side in one frame, differing only in how far through the sequence\n"
	out += "each one is. `01` makes the same case inside a SINGLE organ,\n"
	out += "which is stronger still: mid-deployment the wave has reached the\n"
	out += "proximal half of the band and not the distal half, so one frame\n"
	out += "holds the same hairs erect and lying flat with nothing else\n"
	out += "differing at all. `02` and `03` are the pair at macro distance\n"
	out += "from one stand.\n\n"
	for line in _log:
		if line.is_empty():
			out += "\n"
		elif line.begins_with(" ") or line.ends_with(":"):
			# The pricing rows are a table, not a list of pictures.
			out += "    " + line.strip_edges(true, false) + "\n"
		else:
			out += "- " + line + "\n"
	return out
