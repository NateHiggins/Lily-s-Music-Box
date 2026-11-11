extends Node
## The house office in V2's common room B: the dead-letters sorting desk is
## worked through the grips the hand uses (take, slide, lift, let go) with V1's
## DeadLetters giving every verdict, and the maintenance headquarters shows
## V1's tools and trophies as cases are resolved through RealityCases. With
## SHOT_DIR and a window it also takes review captures (not runtime proof).
const Office := preload("res://scripts/building/orison_v2_house_office.gd")

var _fails := 0
var _checks := 0
var world: Node3D
var blockout: Node3D
var desk: Node3D
var hq: Node3D
var _feet := Vector3.ZERO
var _look := Vector3.ZERO
var _pinned := false


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _settle(node: Node) -> void:
	var began := Time.get_ticks_msec()
	var quiet := 0
	while (quiet < 60 or not node.can_process()) and Time.get_ticks_msec() - began < 90000:
		var before := Time.get_ticks_msec()
		await get_tree().process_frame
		quiet = quiet + 1 if Time.get_ticks_msec() - before < 250 else 0


func _process(_delta: float) -> void:
	if not _pinned or world == null or not is_instance_valid(world.player):
		return
	world.player.global_position = _feet
	world.player.camera.look_at(_look)
	var companion: Variant = world.get("service_set_carrier")
	if companion is Node3D:
		(companion as Node3D).visible = false


## Feet and look are in the blockout's own plan metres.
func _snap(label: String, feet: Vector3, look: Vector3) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(directory)
	_feet = blockout.to_global(feet)
	_look = blockout.to_global(look)
	_pinned = true
	for index in 60:
		await get_tree().process_frame
	for index in 10:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	print("HOUSE OFFICE SHOT: ", label)
	_pinned = false


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var excluded: Array[RID] = []
	for owner_node: Node3D in [desk, hq]:
		for body: Node in owner_node.find_children("*", "CollisionObject3D", true, false):
			excluded.append((body as CollisionObject3D).get_rid())
	query.exclude = excluded
	return world.get_world_3d().direct_space_state.intersect_ray(query)


## What the hand is offered on a part: the project's manipulation contract.
func _offer(part: Node) -> Dictionary:
	var area := part.get_node_or_null("ManipulationTarget")
	if area == null:
		return {}
	var offered: Dictionary = area.call("manipulation_target", {})
	return offered


## Take hold, move to `value` in steps as a hand would, let go.
func _work(part: Node, value: float) -> bool:
	var hold := _offer(part)
	if hold.is_empty() or not bool(hold.begin.call()):
		return false
	var from: float = hold.read.call()
	for index in 6:
		hold.write.call(lerpf(from, value, float(index + 1) / 6.0))
	if not bool(hold.owns.call()):
		return false
	hold.end.call()
	return true


## Slide the letter in hand to `stop`, lift it before `unit`, let go.
func _file_by_hand(stop: int, unit: String) -> bool:
	var letter: Node3D = desk.in_hand()
	if letter == null or not _work(letter, desk.stop_position(stop)) or desk.stop != stop:
		return false
	var lift: float = desk.lift_for(stop, unit)
	return lift >= 0.0 and _work(letter, lift)


## The stop whose stack holds `unit`.
func _stop_of(unit: String) -> int:
	for stop in range(1, 6):
		if desk.lift_for(stop, unit) >= 0.0:
			return stop
	return -1


func _surfaces(owner_node: Node3D, title: String) -> int:
	var count := 0
	var sound := true
	var why := ""
	for draw: MeshInstance3D in owner_node.find_children("*", "MeshInstance3D", true, false):
		for surface in draw.mesh.get_surface_count():
			count += 1
			var arrays := draw.mesh.surface_get_arrays(surface)
			var material := draw.material_override as StandardMaterial3D
			var ok: bool = arrays[Mesh.ARRAY_TEX_UV] != null and (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() > 0 \
					and arrays[Mesh.ARRAY_TANGENT] != null and (arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() > 0 \
					and material != null and material.albedo_texture != null and material.roughness_texture != null \
					and material.normal_enabled and material.normal_texture != null and not material.uv1_triplanar \
					and draw.visibility_range_end > 0.0
			if not ok:
				sound = false
				why = draw.name
	_check(sound and count > 0, "%s: every surface has UVs, tangents, a catalogue finish and a visibility range (%d surfaces) %s" % [title, count, why])
	return count


func _ready() -> void:
	process_priority = 1000
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not world.startup_failed, "the V2 world starts")
	if world.startup_failed:
		_finish()
		return
	blockout = world.get("_blockout")
	var office: Dictionary = Office.mount(world, blockout, world.layout, world.adapter)
	_check((office.errors as Array).is_empty(), "the house office mounts (%s)" % str(office.errors))
	desk = office.dead_letters
	hq = office.headquarters
	_check(desk != null and hq != null, "the desk and the headquarters are in the building")
	if desk == null or hq == null:
		_finish()
		return
	_check(Office.mount(world, blockout, world.layout, world.adapter).dead_letters == desk, "mounting twice gives the same office")
	await _settle(desk)
	await get_tree().physics_frame
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for canvas: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		canvas.hide()

	# Where they stand.
	var pieces := {"the sorting desk": [desk, 0.95], "the workbench": [hq.bench, 1.15], "the trophy wall": [hq.trophy_wall, 1.19]}
	var door := Vector3.ZERO
	for row: Dictionary in world.layout.doors:
		if str(row.id) == "F01_PACKAGE_COMMON_DOOR":
			door = Vector3(float(row.center[0]), 0.0, float(row.center[1]))
	var phones := world.adapter.resolve("F01_HOUSE_TELEPHONE_BOARD") as Node3D
	var phones_here: bool = phones != null and world.room_at_world(phones.global_position) == "F01_COMMON_B"
	print("HOUSE OFFICE: telephone board in the room: ", phones_here)
	for title: String in pieces:
		var piece: Node3D = pieces[title][0]
		var half: float = pieces[title][1]
		_check(world.room_at_world(piece.global_position + Vector3.UP * 0.3 + piece.global_basis.z * 0.3) == "F01_COMMON_B",
				"%s is in common room B (%s)" % [title, world.room_at_world(piece.global_position + Vector3.UP * 0.3 + piece.global_basis.z * 0.3)])
		var out: Vector3 = piece.global_basis.z
		var high: Vector3 = piece.global_position + Vector3.UP * 2.3 + out * 0.5
		var behind := _ray(high, high - out * 1.0)
		var gap: float = 9.0 if behind.is_empty() else high.distance_to(behind.position) - 0.5
		_check(absf(gap) < 0.06, "%s has the wall at its back (%.3f m)" % [title, gap])
		# Looking back at it from the room: nothing of V2's stands in its place or before it.
		for side: float in [-half * 0.85, 0.0, half * 0.85]:
			for height: float in [0.35, 1.25]:
				var from: Vector3 = piece.global_position + Vector3.UP * height + out * 1.65 + piece.global_basis.x * side
				var met := _ray(from, from - out * 1.8)
				var reach: float = 0.0 if met.is_empty() else from.distance_to(met.position)
				_check(reach > 1.55, "%s has its place to itself and clear floor in front (%.1f, %.2f: %.2f m to %s)" % [
						title, side, height, reach, "nothing" if met.is_empty() else str((met.collider as Node).get_parent().name)])
		var here: Vector3 = blockout.to_local(piece.global_position)
		_check(Vector2(here.x, here.z).distance_to(Vector2(door.x, door.z)) > half + 1.6,
				"%s is clear of the door's swing (%.2f m)" % [title, Vector2(here.x, here.z).distance_to(Vector2(door.x, door.z))])
		# The telephone board's place on the east wall under the first-floor ruling,
		# measured from the board itself once it has been moved into the room.
		var board := Vector3(-9.35, 0.0, -1.3)
		if phones_here:
			board = blockout.to_local(phones.global_position)
		if true:
			_check(Vector2(here.x, here.z).distance_to(Vector2(board.x, board.z)) > half + 1.0,
					"%s is clear of the telephone board's place (%.2f m)" % [title, Vector2(here.x, here.z).distance_to(Vector2(board.x, board.z))])
	var draws := _surfaces(desk, "the sorting desk") + _surfaces(hq, "the headquarters")
	print("HOUSE OFFICE: %d mesh surfaces mounted" % draws)

	# Dead letters. A tray with a dead letter in it, neither first nor second.
	var game: DeadLetters = desk.game
	var seed_value := 1928
	var dead_at := -1
	while dead_at < 2:
		seed_value += 1
		desk.deal(seed_value)
		dead_at = -1
		for index in game.tray.size():
			if str(game.tray[index].answer) == DeadLetters.DEAD and dead_at < 0:
				dead_at = index
		if str(game.tray[0].answer) == DeadLetters.DEAD or str(game.tray[1].answer) == DeadLetters.DEAD:
			dead_at = -1
	print("HOUSE OFFICE: tray seed %d, first dead letter at %d" % [seed_value, dead_at])
	_check(game.tray.size() == int(game.scoring.tray) and desk.letters.size() == game.tray.size(), "the tray holds V1's eight letters")
	var first: Node3D = desk.in_hand()
	var face: Array = game.face_of(game.current())
	var address: Label3D = desk._address
	_check(address.get_parent() == first and address.text == "%s\n%s" % [str(face[0]), str(face[1])] and address.font != null and not address.double_sided,
			"the top letter's face is the address exactly as V1's deck has it (%s)" % address.text.replace("\n", " / "))
	var clue_text: String = desk._clues.text
	var clues_whole := true
	for clue: String in game.current().clues:
		clues_whole = clues_whole and clue_text.contains(clue)
	_check(clues_whole, "and V1's clues are on it")
	_check(_offer(desk.letters[1]).is_empty(), "only the top letter answers the hand")
	_check(_offer(desk.carriage).is_empty(), "the clip is not offered while the letter lies in the tray")
	var lying: Vector3 = first.position
	# Taken a little way and let go, it goes back to the tray.
	_check(_work(first, 0.06) and desk.stop == 0 and first.position.distance_to(lying) < 0.001 and game.at == 0, "let go just off the tray, the letter goes back to it")
	# Slid to a stack, it stands in the clip.
	var right_unit := str(game.current().answer)
	var right_stop := _stop_of(right_unit)
	var wrong_stop := 1 if right_stop != 1 else 2
	var wrong_unit := str(game.boxes[(6 - 1 - 3) * 4 + wrong_stop - 1].unit)
	_check(_work(first, desk.stop_position(wrong_stop) + 0.05) and desk.stop == wrong_stop and first.basis.is_equal_approx(Basis())
			and absf(first.position.x - desk.carriage.position.x) < 0.001, "slid along the rail and let go near stack %d, it stands in the clip there" % wrong_stop)
	_check(game.at == 0 and game.history.is_empty(), "standing at a stack files nothing")
	await _snap("desk_letter_on_rail", Vector3(-12.9, 0.0, -2.75), Vector3(-13.15, 1.0, -3.6))
	var other_stop := wrong_stop + 1
	_check(_work(desk.carriage, desk.stop_position(other_stop)) and desk.stop == other_stop and absf(first.position.x - desk.carriage.position.x) < 0.001,
			"the clip slides the standing letter to another stack")
	_check(_work(desk.carriage, desk.stop_position(wrong_stop)) and desk.stop == wrong_stop, "and back")
	_check(_work(first, float(desk.stock.rows[0]) * 0.3) and desk.lift == 0.0 and game.at == 0, "lifted a little and let go, it sinks back to the rail and nothing is filed")
	var hold := _offer(first)
	_check(not hold.is_empty() and bool(hold.begin.call()), "the hand takes the standing letter")
	hold.write.call(desk.lift_for(wrong_stop, wrong_unit))
	_check(desk.unit_before() == wrong_unit and _offer(desk.carriage).is_empty(), "lifted, it stands before %s" % wrong_unit)
	await _snap("desk_letter_lifted", Vector3(-12.9, 0.0, -2.75), Vector3(-13.15, 1.15, -3.6))
	hold.end.call()
	_check(game.at == 1 and game.missed == 1 and game.filed == 0 and game.score == 0 and not bool(desk.reveal.right)
			and str(desk.reveal.went_to) == wrong_unit and str(desk.reveal.belonged) == right_unit and (game.misfiled as Array).size() == 1,
			"let go at %s, V1 judges it astray and records it (belonged %s)" % [wrong_unit, right_unit])
	_check(first.get_parent() == desk.tray and first.get_node_or_null("ManipulationTarget") == null, "and it is handed back to the tray, out of the round")
	_check(str(desk.tally.text).contains("ASTRAY") and str(desk.tally.text).contains(str(desk.reveal.why)), "the tally slip gives V1's verdict and its reason")
	# The next letter, filed right.
	var second: Node3D = desk.in_hand()
	_check(second == desk.letters[1] and desk._address.get_parent() == second, "the next letter is on top, its face showing")
	right_unit = str(game.current().answer)
	_check(_file_by_hand(_stop_of(right_unit), right_unit), "the second letter is slid to its stack and lifted to its floor")
	_check(game.at == 2 and game.filed == 1 and game.score == int(game.scoring.filed) and bool(desk.reveal.right), "V1 judges it right and scores it")
	var kept: Vector3 = second.position
	_check(second.get_parent() == desk and kept.z < desk.stock.rail.z - 0.05 and second.basis.is_equal_approx(desk.LYING)
			and str(second.get_meta("dead_letters_went_to")) == right_unit, "and it stays in the hole for %s" % right_unit)
	# The rest of the tray, each to where V1 says it belongs; the dead letter to the dead-letter box.
	var expected: int = int(game.scoring.filed)
	var dead_node: Node3D
	while not game.done():
		var index: int = game.at
		var unit := str(game.current().answer)
		var to := str(game.current().to)
		if unit == DeadLetters.DEAD:
			dead_node = desk.in_hand()
			_check(_stop_of(unit) == 5, "a dead letter (%s) belongs to no stack, only the box at the end of the rail" % to)
		expected += int(game.scoring.dead_letter) if unit == DeadLetters.DEAD else int(game.scoring.filed)
		if not _file_by_hand(_stop_of(unit), unit) or game.at != index + 1 or not bool(desk.reveal.right):
			_check(false, "letter %d (%s) could not be filed to %s" % [index, to, unit])
			break
	_check(dead_node != null and str(dead_node.get_meta("dead_letters_went_to", "")) == DeadLetters.DEAD and dead_node.get_parent() == desk
			and absf(dead_node.position.x - (desk.stock.rail.x + desk.stock.dead_stop)) < 0.001, "the dead letter lies in the dead-letter box")
	_check(second.position.is_equal_approx(kept), "the letter filed earlier has not moved")
	_check(game.done() and game.filed == 7 and game.missed == 1 and game.score == expected and desk.in_hand() == null,
			"the round finishes as V1's does: seven filed, one astray, score %d (%d)" % [expected, game.score])
	var slip := str(desk.tally.text)
	_check(slip.contains("TRAY EMPTY") and slip.contains("7 filed, 1 gone astray.") and slip.contains("went to %s — should have been" % wrong_unit)
			and slip.contains("nothing here is undone; a letter in the wrong box is just somewhere else now."), "the tally slip reads as V1's finished panel did")
	await _snap("desk_round_done", Vector3(-12.7, 0.0, -1.9), Vector3(-13.0, 1.15, -3.775))
	await _snap("desk_tally_close", Vector3(-12.3, 0.0, -2.9), Vector3(-12.28, 0.76, -3.25))
	# The empty tray's handle draws a fresh tray.
	var handle: Node
	for draw: MeshInstance3D in desk.tray.find_children("*", "MeshInstance3D", true, false):
		if draw.get_node_or_null("ManipulationTarget") != null:
			handle = draw
	_check(handle != null and _work(handle, 0.04) and game.done(), "the tray's handle drawn a little and let go changes nothing")
	_check(_work(handle, 0.10) and not game.done() and game.at == 0 and game.filed == 0 and desk.letters.size() == 8 and desk.in_hand() != null,
			"drawn right out, the tray comes back full and the round begins again")
	_check(_offer(handle).is_empty(), "and the handle is ordinary iron again while there is post in the tray")
	_check(desk.interact_prompt() == "" and world.find_children("*", "CanvasLayer", true, false).filter(
			func(layer: Node) -> bool: return layer.get_script() != null and str(layer.get_script().resource_path).ends_with("dead_letters_panel.gd")).is_empty(),
			"there is no panel: the desk is worked by hand")
	await _snap("desk_standing", Vector3(-12.7, 0.0, -1.9), Vector3(-13.0, 1.15, -3.775))
	await _snap("desk_tray_close", Vector3(-13.76, 0.0, -2.95), Vector3(-13.76, 0.76, -3.4))

	# The headquarters.
	var ids: Array = RealityCases.definitions.keys()
	ids.sort()
	_check(hq.is_in_group("maintenance_headquarters") and hq.trophy_slot_count() == ids.size() and ids.size() == 18, "the trophy wall has a socket for each of the eighteen resident cases")
	_check(hq.resolved_trophy_count() == 0 and hq.unlocked_gear_count() == 1, "with nothing resolved, only the inspection light is issued")
	var gear: Array = hq.GEAR
	var shown := true
	for index in gear.size():
		shown = shown and (hq._gear_visuals[index] as Node3D).visible == (int(gear[index].threshold) == 0)
		shown = shown and (hq.gear_cards[index] as Label3D).text == str(gear[index].name)
	_check(shown and gear.size() == 6, "each of V1's six tools has its own place and its V1 name; only the first is on the board")
	var title: Label3D = hq.plaque.find_children("*", "Label3D", true, false)[0]
	_check(title.text == "REALITY MAINTENANCE" and not title.double_sided, "the plaque is lettered with V1's words")
	await _snap("hq_bench_first_day", Vector3(-13.85, 0.0, 0.6), Vector3(-15.575, 1.45, 1.0))
	var steps := true
	for count in range(1, 13):
		var case_id: String = ids[count - 1]
		var opened: bool = RealityCases.activate_case(case_id)
		var state: Dictionary = RealityState.case_state(case_id)
		if not opened or state.is_empty():
			steps = false
			print("  case would not open: ", case_id)
			continue
		state.stage = "integration_ready"
		state.repair_count = int(RealityCases.definition(case_id).get("repairs_required", 2))
		var resolved: bool = RealityCases.resolve_case(case_id)
		var want := 0
		for spec: Dictionary in gear:
			want += 1 if count >= int(spec.threshold) else 0
		var seen := 0
		for holder: Node3D in hq._gear_visuals:
			seen += 1 if holder.visible else 0
		var tokens := 0
		for token: Node3D in hq._trophies.values():
			tokens += 1 if token.visible else 0
		if not resolved or hq.resolved_trophy_count() != count or seen != want or hq.unlocked_gear_count() != want or tokens != count \
				or not (hq._trophies[case_id] as Node3D).visible:
			steps = false
			print("  headquarters at %d resolved: resolved=%s count=%d tools=%d want=%d tokens=%d" % [count, resolved, hq.resolved_trophy_count(), seen, want, tokens])
		if count == 5:
			_check(seen == 4 and not (hq._gear_visuals[4] as Node3D).visible, "at five resolved cases the seam stapler is issued and the prism is not")
	_check(steps and hq.unlocked_gear_count() == 6, "resolved one at a time through RealityCases, tokens and tools appear at V1's thresholds (0, 1, 3, 5, 8, 12)")
	_check(str(hq._status.text) == "CASE RESIDUE  12/18   TOOLS  06/06", "the wall's inventory reads as V1 wrote it (%s)" % str(hq._status.text))
	var card: Dictionary = hq.interact(world.player)
	_check(str(card).contains("12/18 RESIDUE TOKENS SET") and hq.interact_prompt().contains("12/18 resolved, 6/6 tools issued"), "inspecting it gives V1's card and prompt")
	var target := hq.get_node_or_null("TrophyWallInspection") as Area3D
	_check(target != null and world.room_at_world(target.global_position) == "F01_COMMON_B"
			and target.global_position.distance_to(hq.trophy_wall.global_position + Vector3.UP * 1.45) < 0.2, "the inspection target is on the trophy wall")
	await _snap("hq_bench_issued", Vector3(-13.85, 0.0, 0.6), Vector3(-15.575, 1.45, 1.0))
	await _snap("hq_tools_close", Vector3(-14.55, 0.0, 1.0), Vector3(-15.575, 1.58, 1.0))
	await _snap("hq_trophy_wall", Vector3(-10.3, 0.0, -1.4), Vector3(-10.6, 1.45, -3.772))
	await _snap("hq_tokens_close", Vector3(-11.1, 0.0, -2.8), Vector3(-11.35, 1.2, -3.772))
	await _snap("office_west", Vector3(-10.6, 0.0, 1.0), Vector3(-15.6, 1.3, 1.0))
	await _snap("office_south", Vector3(-12.0, 0.0, -0.2), Vector3(-11.9, 1.1, -3.8))
	_finish()


func _finish() -> void:
	print("[V2 HOUSE OFFICE] RESULT: %s (%d checks, %d failures)" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	await get_tree().process_frame
	if world != null:
		world.shutdown_for_tests()
		remove_child(world)
		world.free()
	get_tree().quit(0 if _fails == 0 else 1)
