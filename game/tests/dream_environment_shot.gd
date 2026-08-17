extends Node
## What the dream actually looks like to a player, with nothing borrowed.
##
##     SHOT_DIR=<abs> godot --path game res://tests/DreamEnvironmentShot.tscn
##     SHOT_DIR=<abs> DREAM_ENV_CONTROL=1 godot --path game \
##             res://tests/DreamEnvironmentShot.tscn
##
## WHY THIS EXISTS. `dream_pursuit_shot.gd` — the harness behind N6's proof
## frames — builds three light sources of its own before it photographs
## anything: a `WorldEnvironment` with 0.18 ambient, an OmniLight3D named
## `RecedingOrientationControl`, and another named `NearestFloorBlackLevelControl`.
## Its comment is honest about what they are for: "the ruled light-off state is
## navigable darkness, not a black video file."
##
## None of the three exists in production. `building_root.gd` builds a
## WorldEnvironment for the WAKING world; `CampaignShell` frees that world when
## it swaps in `DreamMazeRoot`, which builds none, and `project.godot` sets no
## `default_environment` to fall back on. So the frames that demonstrate
## navigable darkness demonstrate it in a scene the player never enters.
##
## This harness adds NOTHING. Whatever the dream ships with is what it
## photographs. `DREAM_ENV_CONTROL=1` strips the environment back out again, so
## the pair is one build apart rather than one memory apart.

const SEED_HEX := "f123456789abcdef"

var _root: DreamMazeRoot
var _out := ""
var _findings := 0


func _ready() -> void:
	_out = OS.get_environment("SHOT_DIR")
	if _out == "":
		_out = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_out)
	await _build()
	# DIAGNOSTIC: strip the carried beam's screen-space mask. It is a
	# CanvasLayer that multiplies over the whole frame, and the owner suspects
	# it of laying a rectangle across these shots.
	if OS.get_environment("DREAM_NO_MASK") == "1":
		var stripped := 0
		for m in _root.player.find_children("*", "Control", true, false):
			m.visible = false
			stripped += 1
		for cl in _root.player.find_children("*", "CanvasLayer", true, false):
			cl.visible = false
			stripped += 1
		print("[DREAM ENV] MASK CONTROL: %d overlay nodes hidden" % stripped)
	# DIAGNOSTIC: suppress the receding practicals. They are omni lights bright
	# enough to light a whole wall segment now that no ambient competes.
	if OS.get_environment("DREAM_NO_PRACTICAL") == "1":
		for pr in _root._practicals:
			pr.visible = false
		_root.set_physics_process(false)
		print("[DREAM ENV] PRACTICAL CONTROL: %d suppressed"
				% _root._practicals.size())
	var control := OS.get_environment("DREAM_ENV_CONTROL") == "1"
	if control:
		_strip_environment()
	var tag := "_CONTROL" if control else ""
	await _capture("01_hall_lamp_on" + tag, true)
	await _capture("02_hall_lamp_off" + tag, false)
	# The threshold, looking down the chain: this is the frame the receding
	# practical is supposed to own, and the first thing a player ever sees.
	_stage_threshold()
	await _capture("03_threshold_lamp_on" + tag, true)
	await _capture("04_threshold_lamp_off" + tag, false)
	print("[DREAM ENVIRONMENT SHOT] 4 frames%s" %
			("  (CONTROL: environment stripped)" if control else ""))
	if not control:
		_audit_shader_compiled()
		await _audit_practical()
	print("[DREAM ENVIRONMENT SHOT] %d findings" % _findings)
	get_tree().quit(_findings)


## A SHADER THAT FAILS TO COMPILE DOES NOT SAY SO, IT JUST DISAPPEARS.
##
## Godot logs SHADER ERROR to stderr and then renders the FALLBACK material --
## a plain lit surface that looks like a lighting problem rather than a missing
## shader. On 2026-08-17 the Klimt shader carried two compile errors (a forward
## reference to hash21, and a `const` with no type) and this harness went on
## reporting "4 frames saved" for several passes while photographing the
## fallback. Real tuning decisions were made against an image the shader was
## not drawing.
##
## So the harness now asks the question directly. `get_shader_uniform_list()`
## returns the uniforms the compiled shader actually exposes; on a shader that
## failed to build it comes back empty, which is a fact a render cannot hide.
func _audit_shader_compiled() -> void:
	print("
=== SHADER COMPILED? ===")
	var checked := 0
	var broken := 0
	for node in _root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if geometry == null:
			continue
		var material := geometry.material_override as ShaderMaterial
		if material == null or material.shader == null:
			continue
		checked += 1
		var uniforms: Array = material.shader.get_shader_uniform_list()
		if uniforms.is_empty():
			broken += 1
			printerr("   FAILED TO COMPILE: %s on %s"
					% [material.shader.resource_path, geometry.name])
	print("shader materials checked : %d" % checked)
	print("failed to compile        : %d" % broken)
	if checked == 0:
		_findings += 1
		print("FAIL: no ShaderMaterial found at all -- the Klimt pass is not "
				+ "reaching the geometry.")
	elif broken > 0:
		_findings += 1
		print("FAIL: the frames above are the FALLBACK material, not the "
				+ "shader. Do not tune against them.")
	else:
		print("PASS: every Klimt material compiled and is what was "
				+ "photographed.")


## THE RULE THAT IS EASY TO WRITE AND EASY TO BREAK.
##
## "It never slides away in view; the lit fixture changes only while a wall or
## closing door occludes it." Two invariants fall out of that, and neither is
## visible in a still frame, so they are walked here instead.
##
##   1. At most one practical is ever burning. Two lit fixtures is a corridor
##      with two suns and no reading of which way is forward.
##   2. A handover never happens while the outgoing fixture is in view. This
##      is the one with teeth: the implementation defers, and a deferral that
##      silently stopped deferring would look completely normal in every
##      screenshot ever taken of it.
func _audit_practical() -> void:
	print("\n=== THE RECEDING PRACTICAL, WALKED ===")
	var modules: Array = _root.plan.modules
	var seen_lit := -1
	var switches := 0
	var in_view_switches := 0
	var multi_lit := 0
	# Step along the chain in small increments rather than teleporting module
	# to module: a handover deferred until the body is deep inside the next
	# room is still correct, and only a fine walk can tell that apart from a
	# handover that never waited at all.
	for i in modules.size():
		var rect: Array = modules[i].rect
		for t in 9:
			var f := float(t) / 8.0
			var p := Vector3(
					lerpf(float(rect[0]) + 0.6, float(rect[2]) - 0.6, f), 0.0,
					(float(rect[1]) + float(rect[3])) * 0.5)
			_root.player.global_position = p
			# Face the burning fixture before asking whether it can be seen.
			# That is deliberately the WORST case for the rule: a player who
			# happens to be looking away cannot witness a handover no matter
			# how badly it is implemented, so testing under an arbitrary
			# heading would pass a broken deferral. Aiming straight at the
			# thing makes the question "could this EVER be seen from here".
			if seen_lit >= 0:
				var to_light := _root._practicals[seen_lit].global_position - p
				to_light.y = 0.0
				if to_light.length() > 0.01:
					_root.player.rotation.y = atan2(to_light.x, -to_light.z)
			await get_tree().physics_frame
			# Was the burning fixture visible immediately BEFORE the update?
			var was_visible := seen_lit >= 0 \
					and _root._practical_is_visible(seen_lit)
			await get_tree().physics_frame
			await get_tree().physics_frame
			var lit := 0
			for practical in _root._practicals:
				if practical.visible:
					lit += 1
			if lit > 1:
				multi_lit += 1
			if _root._lit_practical != seen_lit:
				switches += 1
				if was_visible:
					in_view_switches += 1
					print("   IN-VIEW HANDOVER at module %d: %d -> %d"
							% [i, seen_lit, _root._lit_practical])
				seen_lit = _root._lit_practical
	print("modules walked      : %d" % modules.size())
	print("practicals          : %d" % _root._practicals.size())
	print("handovers           : %d" % switches)
	print("frames with 2+ lit  : %d" % multi_lit)
	print("handovers in view   : %d" % in_view_switches)
	if multi_lit > 0 or in_view_switches > 0:
		_findings += 1
		print("FAIL: the practical broke a ruled invariant.")
	else:
		print("PASS: one fixture at a time, and every handover waited for a "
				+ "wall.")


func _build() -> void:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	_root = scene.instantiate() as DreamMazeRoot
	# Not autonomous: the run clock and the terminal fold are not what this
	# frame is about, and a capture at 28 s would photograph the fold.
	_root.autonomous = false
	_root.configure_dream({
		"case_id": "mina_caption_crisis",
		"profile_id": "mina_release_print", "window": {},
		"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": "",
	})
	add_child(_root)
	await get_tree().process_frame
	_root.player.set_physics_process(false)
	# Same staging as the N6 frames so the two are comparable: inside D01,
	# against its solid east end wall, on the hall's long axis.
	var d01: Array = []
	for entry in _root.plan.modules:
		if str(entry.id) == "D01_F04_LONG_HALL":
			d01 = entry.rect
	var hall_z: float = (d01[1] + d01[3]) * 0.5
	var wall_x: float = d01[2]
	_root.player.position = Vector3(wall_x - 2.6, 0.0, hall_z)
	_root.player.rotation.y = -PI / 2.0
	_root.pursuer.reset_run(Vector3(wall_x - 1.2, 0.0, hall_z))
	_root.player.camera.make_current()


## Stand at the authored entrance and look the way the chain actually runs.
##
## The heading is DERIVED from the first connector, not typed. An earlier
## version set `rotation.y = 0.0` and photographed the threshold facing -Z
## while the chain leaves D00 along +X, so the receding practical sat off the
## right-hand edge of frame and the frame it was built to prove showed a wall.
func _stage_threshold() -> void:
	var spawn: Array = _root.plan.spawn_player
	var here := Vector3(spawn[0], 0.0, spawn[1])
	_root.player.position = here
	var aperture: Array = _root.plan.doors[0].aperture
	var mouth := Vector3(
			(float(aperture[0]) + float(aperture[2])) * 0.5, 0.0,
			(float(aperture[1]) + float(aperture[3])) * 0.5)
	var forward := mouth - here
	forward.y = 0.0
	if forward.length() > 0.01:
		# Godot's -Z is forward, so the yaw that aims at the doorway is
		# atan2 of the vector's x against its NEGATED z.
		_root.player.rotation.y = atan2(forward.x, -forward.z)
	_root.player.camera.make_current()


## Reproduce the pre-2026-08-17 production state: no environment of any kind.
func _strip_environment() -> void:
	var n := 0
	for child in _root.find_children("*", "WorldEnvironment", true, false):
		child.queue_free()
		n += 1
	print("[DREAM ENVIRONMENT SHOT] CONTROL: %d WorldEnvironment freed" % n)


func _capture(file_name: String, lamp_on: bool) -> void:
	_root.player.set_lamp_enabled(lamp_on)
	for _frame in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out.path_join(file_name + ".png"))
	var pose: Dictionary = _root.player.lamp_pose()
	print("   saved %-30s origin=%s dir=%s cam_fwd=%s" % [file_name,
			str(pose.get("origin", Vector3.ZERO)).pad_decimals(2),
			str(pose.get("dir", Vector3.ZERO)),
			str(-_root.player.camera.global_transform.basis.z)])
