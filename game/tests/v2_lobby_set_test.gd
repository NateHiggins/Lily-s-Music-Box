extends Node
## The lobby set in the V2 building (v1r_lobby_boards_20261109,
## v1r_historical_radio_b_20261109, v1r_mail_chute_20261109): the notice board
## with every V1 notice and the wireless notice, the Orison broadside, and the
## mail chute beside the mail bank. Each is mounted on a real wall, keeps V1's
## words and behaviour, and is drawn from Blender stock on catalogue finishes.
##
## The runtime root does not call the composer yet, so this test mounts the set
## onto the booted world itself, exactly as the root will.
const LobbySet := preload("res://scripts/building/orison_v2_lobby_set.gd")
const WirelessNotice := preload("res://scripts/game/historical_radio_notice.gd")
const ACTIVITY := "mail_chute_choke_clearing"

## V1's notices, recovered from art/tools/build_lobby_notices.py: key, heading,
## body, signature.
const NOTICES := [
	["rent", "NOTICE TO TENANTS", "RENT IS DUE ON THE FIRST. Payment after the fifth incurs a late charge of two dollars. Cheques to ORISON REALTY CO. only. Do not leave payment under the office door.", "ORISON REALTY CO."],
	["heat", "HEAT & HOT WATER", "The boiler is banked between 1 and 4 AM. A radiator that knocks or stays cold is to be reported in writing. Do not leave the supply valve part way: it is fully open or fully shut.", "R. MAINTENANCE"],
	["super", "SUPERINTENDENT HOURS", "Weekdays 8 AM to 6 PM. Emergencies only after hours: use the lobby telephone. Do not knock at 4B after 9 PM.", "R. MAINTENANCE"],
	["halls", "HOUSE RULES", "No loitering in the halls or on the stoop. No perambulators, bicycles or refuse to be left in the public ways. Radios and instruments silent after 10 PM.", "ORISON REALTY CO."],
	["exterm", "EXTERMINATOR", "The exterminator calls the second Tuesday of each month. Leave cupboards clear and pets secured. Tenants absent on the day will not be revisited.", "ORISON REALTY CO."],
	["roof", "ROOF ACCESS", "The roof door is to remain closed at all times. Lines may be hung on the north side only. Access is not permitted after dark under any circumstance.", "ORISON REALTY CO."],
	["elev", "ELEVATOR", "The car is out of service pending inspection. Use the stair. Posted the 3rd of March. Remove when the car is returned to service.", "ORISON REALTY CO."],
	["lost", "FOUND", "One key, brass, no tag, found on the third landing. Claim from the superintendent. Describe it first.", "R. MAINTENANCE"],
]
## The broadside's own words, top to bottom.
const ADVERT := [
	["Title", "THE ORISON"],
	["Residence", "A SIX-STORY APARTMENT RESIDENCE OF DISTINCTION"],
	["Virtues", "FIREPROOF  ·  MODERN  ·  HOMELIKE"],
	["Address", "KEW GARDENS, LONG ISLAND, QUEENS"],
	["Invitation", "COME SEE THE ORISON — IT'S THE BEGINNING OF THE FUTURE, TODAY!"],
]

var _fails := 0
var _checks := 0
var _world: Node
var _blockout: Node3D
var _eye := Vector3.ZERO
var _target := Vector3.ZERO
var _holding := false
var _completed: Array = []


class Stand extends Node:
	## Keeps the player at the viewpoint: the building lights rooms round the
	## player, and the V2 opening moves the player after startup.
	var test: Node
	func _process(_delta: float) -> void:
		if not test._holding or not is_instance_valid(test._world) or test._world.player == null:
			return
		var player: Node3D = test._world.player
		player.global_position += test._eye - player.camera.global_position
		player.camera.look_at(test._target)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(_world)
	while not _world.startup_failed and _world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not _world.startup_failed, "the V2 world starts")
	if _world.startup_failed:
		_finish()
		return
	_blockout = _world._blockout
	var mounted: Dictionary = _world.lobby_set
	_check(mounted.size() == 3, "the composer mounts three props")
	if mounted.size() != 3:
		_finish()
		return
	var board: Node3D = mounted.bulletin_board
	var advert: Node3D = mounted.advert_board
	var chute: Node3D = mounted.mail_chute
	await _settle([board, advert, chute])
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LobbySet.PLACEMENTS))

	_check_placement(board, advert, chute, plan)
	await _check_board(board, plan.bulletin)
	await _check_advert(advert, plan.advert)
	await _check_chute(chute)
	var totals := _check_surfaces([board, advert, chute])
	print("[V2 LOBBY SET] draws %d (%d of them lettering), triangles %d" % [totals.draws, totals.labels, totals.triangles])
	await _capture(board, advert, chute)
	_finish()


## The world keeps loading for some seconds after it reports ready.
func _settle(props: Array) -> void:
	var calm := 0
	var guard := 0
	while calm < 60 and guard < 3000:
		var before := Time.get_ticks_usec()
		await get_tree().process_frame
		calm = calm + 1 if Time.get_ticks_usec() - before < 250000 else 0
		guard += 1
	for i in 3:
		await get_tree().physics_frame
	for prop: Node in props:
		_check(prop.can_process(), "%s processes" % prop.name)


func _plan(node: Node3D, local: Vector3) -> Vector3:
	return node.global_transform * local


func _ray(from: Vector3, to: Vector3, areas: bool) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = areas
	query.collision_mask = 0xFFFFFFFF
	if _world.player != null:
		query.exclude = [_world.player.get_rid()]
	return get_viewport().world_3d.direct_space_state.intersect_ray(query)


func _owner_of(hit: Dictionary, prop: Node) -> bool:
	if hit.is_empty():
		return false
	var node: Node = hit.collider
	return node == prop or prop.is_ancestor_of(node)


## Solid construction lies behind the prop at `local` (x, y on its wall plane).
func _backed(prop: Node3D, local: Vector2, label: String, host: Node = null, standoff := 0.0) -> void:
	var hit := _ray(_plan(prop, Vector3(local.x, local.y, 0.30)), _plan(prop, Vector3(local.x, local.y, -0.30)), false)
	var depth := 9.0
	if not hit.is_empty():
		depth = (prop.global_transform.affine_inverse() * (hit.position as Vector3)).z
	var body := "nothing" if hit.is_empty() else str((hit.collider as Node).name)
	var ok := not hit.is_empty() and absf(depth + standoff) < 0.012
	if host != null and not hit.is_empty() and (hit.collider == host or host.is_ancestor_of(hit.collider)):
		ok = depth > 0.0 and depth < 0.06
	_check(ok, "%s: a wall stands behind it (%s at %.3f m)" % [label, body, depth])


func _check_placement(board: Node3D, advert: Node3D, chute: Node3D, plan: Dictionary) -> void:
	var inverse := _blockout.global_transform.affine_inverse()
	var spaces: Dictionary = {}
	for space: Dictionary in _world.layout.spaces:
		spaces[str(space.id)] = space
	var host := _world.adapter.resolve(str(plan.bulletin.anchor)) as Node3D
	for row: Array in [[board, "F01_LOBBY", "notice board"], [advert, str(plan.advert.space), "Orison broadside"],
			[chute, str(plan.chute.space), "mail chute"]]:
		var prop: Node3D = row[0]
		var at: Vector3 = inverse * _plan(prop, Vector3(0, 0, 0.25))
		var rect: Array = spaces[str(row[1])].rect
		_check(at.x > float(rect[0]) and at.x < float(rect[2]) and at.z > float(rect[1]) and at.z < float(rect[3]),
				"%s stands in %s (%.2f, %.2f)" % [row[2], row[1], at.x, at.z])
		_check(prop.get_parent() == _blockout, "%s is placed in the blockout's own frame" % row[2])
	# Real walls, by ray, across each prop's span.
	for x: float in [-0.40, 0.0, 0.40]:
		_backed(board, Vector2(x, 0.0), "notice board", host)
	_backed(board, Vector2(0.65, -0.05), "overflow notices")
	_backed(board, Vector2(-0.80, 0.0), "wireless notice")
	for at: Vector2 in [Vector2(-0.6, 0.8), Vector2(0.6, 0.8), Vector2(0.0, 0.0), Vector2(-0.6, -0.8), Vector2(0.6, -0.8), Vector2(0.82, 0.78)]:
		_backed(advert, at, "Orison broadside", null, float(plan.advert.wall_standoff))
	var frame_back := _extent(advert, advert.get_node("Advert__Frame_ON_wood_dark")).position.z
	_check(absf(frame_back + float(plan.advert.wall_standoff)) < 0.002, "the broadside's batten packs it out to the plaster over the wainscot (%.3f m)" % frame_back)
	for y: float in [0.80, 1.20, 2.00, 2.85]:
		_backed(chute, Vector2(0.0, y), "mail chute")
	# The chute meets the ceiling it enters, and its box clears the floor.
	var up := _ray(_plan(chute, Vector3(0.0, 2.0, 0.22)), _plan(chute, Vector3(0.0, 4.0, 0.22)), false)
	var ceiling := 0.0 if up.is_empty() else (chute.global_transform.affine_inverse() * (up.position as Vector3)).y
	var top := _extent(chute, chute.get_node("Chute__Body_ON_iron_blackened")).end.y
	_check(not up.is_empty() and absf(ceiling - top) < 0.03, "the chute runs up into the ceiling (ceiling %.3f, chute top %.3f)" % [ceiling, top])
	var down := _ray(_plan(chute, Vector3(0.0, 0.6, 0.22)), _plan(chute, Vector3(0.0, -1.0, 0.22)), false)
	var floor_y := -9.0 if down.is_empty() else (chute.global_transform.affine_inverse() * (down.position as Vector3)).y
	var door_low := _extent(chute, chute._box_door).position.y
	_check(not down.is_empty() and door_low - floor_y >= chute.BOX_DOOR_MIN,
			"the box door stands %.3f m above the floor, not less than two feet six" % (door_low - floor_y))
	# Beside the mail bank: on the bank's own wall, clear of the bank itself.
	var bank := _world.adapter.resolve("LobbyMailBank") as Node3D
	_check(bank != null, "V2 has its mail bank")
	if bank != null:
		var bank_box := _extent(chute, bank)
		var chute_box := _extent(chute, chute.get_node("Chute__Body_ON_iron_blackened"))
		var gap := maxf(bank_box.position.x - chute_box.end.x, chute_box.position.x - bank_box.end.x)
		_check(gap > 0.02 and gap < 0.60, "the chute hangs beside the mail bank (%.3f m between them)" % gap)
		_check(absf(bank_box.position.z) < 0.03, "the chute and the bank share a wall (bank back at %.3f m)" % bank_box.position.z)
	# A person standing in front of each can reach it: the player's own ray.
	for row: Array in [[board, Vector3(0.0, 0.0, 1.2), Vector3(0.0, 0.0, 0.0), "notice board"],
			[advert, Vector3(0.0, 0.1, 1.3), Vector3(0.0, 0.1, 0.0), "Orison broadside"],
			[chute, Vector3(0.0, 1.45, 1.2), Vector3(0.0, 1.26, 0.1), "mail chute"]]:
		var prop: Node3D = row[0]
		var hit := _ray(_plan(prop, row[1]), _plan(prop, row[2]), true)
		_check(_owner_of(hit, prop), "%s answers a standing reach (%s)" % [row[3], "nothing" if hit.is_empty() else str((hit.collider as Node).name)])


## Bounds of every mesh under `node`, in `frame`'s local space.
func _extent(frame: Node3D, node: Node) -> AABB:
	var found := false
	var result := AABB()
	var inverse := frame.global_transform.affine_inverse()
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var each: Node = stack.pop_back()
		stack.append_array(each.get_children())
		if each is MeshInstance3D and (each as MeshInstance3D).mesh != null:
			var box: AABB = (inverse * (each as MeshInstance3D).global_transform) * (each as MeshInstance3D).get_aabb()
			result = box if not found else result.merge(box)
			found = true
	return result


## A label's ink, in its parent's space.
func _ink_box(label: Label3D) -> AABB:
	return label.transform * label.get_aabb()


func _readable(label: Label3D, what: String, minimum_em := 0.0075) -> void:
	_check(label.font != null and not label.text.strip_edges().is_empty(), "%s is lettered" % what)
	_check(not label.double_sided and label.visible and label.shaded and label.modulate.get_luminance() < 0.2,
			"%s is single-sided dark ink lit with its paper" % what)
	_check(label.font_size * label.pixel_size >= minimum_em, "%s is large enough to read (%.1f mm em)" % [what, label.font_size * label.pixel_size * 1000.0])


func _check_board(board: Node3D, plan: Dictionary) -> void:
	_check(board.name == "LobbyBulletinBoard", "the notice board keeps its V1 name")
	var host := _world.adapter.resolve(str(plan.anchor)) as Node3D
	var hidden := true
	for child in host.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			hidden = false
	_check(hidden and host.get_meta("v2_lobby_set_visual_retired", false), "the notice board takes the place of V2's bare lobby pinboard")
	_check(board.notice_sheets.size() == 8, "eight notices hang (%d)" % board.notice_sheets.size())
	var on_cork := 0
	var on_wall := 0
	for sheet: MeshInstance3D in board.notice_sheets:
		if absf(sheet.position.x) < 0.41 and absf(sheet.position.y) < 0.30:
			on_cork += 1
		elif sheet.position.x > 0.46 + 0.07:
			on_wall += 1
	_check(on_cork == 6 and on_wall == 2, "six are pinned on the field and two overflow onto the wall, as V1's card says")
	for row: Array in NOTICES:
		var words: Dictionary = board.notice_words(str(row[0]))
		_check(words.get("head", "") == row[1], "notice %s keeps its heading" % row[0])
		_check(words.get("body", "") == row[2], "notice %s keeps its wording" % row[0])
		_check(words.get("sign", "") == row[3], "notice %s keeps its signature" % row[0])
	for sheet: MeshInstance3D in board.notice_sheets:
		var key := str(sheet.get_meta("notice_key", ""))
		var paper := sheet.get_aabb()
		for part: String in ["Head", "Body", "Sign"]:
			var label := sheet.get_node(part) as Label3D
			_readable(label, "notice %s %s" % [key, part.to_lower()], 0.008 if part != "Head" else 0.010)
			var ink := _ink_box(label)
			_check(ink.position.x > paper.position.x + 0.004 and ink.end.x < paper.end.x - 0.004
					and ink.position.y > paper.position.y + 0.004 and ink.end.y < paper.end.y - 0.004 and ink.position.z > 0.0,
					"notice %s %s lies on its sheet (%.3f..%.3f across %.3f)" % [key, part.to_lower(), ink.position.x, ink.end.x, paper.size.x])
		var head := _ink_box(sheet.get_node("Head") as Label3D).position.y
		var body := _ink_box(sheet.get_node("Body") as Label3D)
		var foot := _ink_box(sheet.get_node("Sign") as Label3D).end.y
		_check(head > body.end.y and body.position.y > foot, "notice %s reads heading, body, signature down the sheet" % key)
	var legend := board.get_node("NoticesLegend") as Label3D
	_check(legend.text == "NOTICES", "the legend plate says NOTICES")
	_check(board.pins != null and board.pins.multimesh.instance_count == 9, "nine pins hold nine sheets")

	# The historical radio notice: V1's printed text and V1's dated reading.
	var authority = WirelessNotice.new()
	var text := board.wireless_sheet.get_node("WirelessLicenseText") as Label3D
	_check(text.text == authority.printed_text() and text.text.contains("LICENSES CHANGE"), "the wireless notice prints V1's own text")
	_readable(text, "the wireless notice", 0.015)
	var sheet_box: AABB = board.wireless_sheet.get_aabb()
	var printed := _ink_box(text)
	_check(printed.position.x > sheet_box.position.x and printed.end.x < sheet_box.end.x
			and printed.position.y > sheet_box.position.y and printed.end.y < sheet_box.end.y, "the wireless notice's text lies on its sheet")
	var clock := CampaignClock.new()
	var today: Dictionary = clock.day_info()
	var copy: Dictionary = board.interact_control("wireless_notice")
	var expected: Dictionary = authority.copy_at(today)
	_check(str(copy.get("notice_phase", "")) in ["BEFORE", "AFTER"] and copy == expected,
			"read today it reports the state V1's authority reports (%s)" % str(copy.get("notice_phase", "")))
	_check(str(copy.get("card_id", "")) == str(authority.event.get("id", "-")) and str(copy.get("evidence_medium", "")) == "printed_license_notice",
			"the reading is the printed licence notice's own card")
	# Either side of the change, through the board's civil-time provider.
	var effective: Dictionary = authority.event.effective
	var before := {"valid": true, "year": int(effective.year), "month": int(effective.month),
			"day_of_month": int(effective.day_of_month), "minute_of_day": float(effective.minute_of_day) - 1.0}
	var after := before.duplicate()
	after.minute_of_day = float(effective.minute_of_day)
	board.bind_civil_time_provider(func() -> Dictionary: return before)
	_check(str(board.interact_control("wireless_notice").notice_phase) == "BEFORE", "a minute before the change it reads BEFORE")
	board.bind_civil_time_provider(func() -> Dictionary: return after)
	_check(str(board.interact_control("wireless_notice").notice_phase) == "AFTER", "at the change it reads AFTER")
	board.bind_civil_time_provider(Callable(clock, "day_info"))
	var reach := _ray(_plan(board, Vector3(float(plan.wireless.at[0]), 0.0, 1.2)), _plan(board, Vector3(float(plan.wireless.at[0]), 0.0, 0.0)), true)
	_check(not reach.is_empty() and (reach.collider as Node).name == "WirelessNoticeInspection"
			and (reach.collider as Node).call("interact_prompt") == "Read wireless tuning notice", "the wireless notice owns its own ray and prompt")

	# V1's inspection: the card, and the first sheet lifting under the hand.
	var card: Dictionary = board.interact(_world.player)
	_check(str(card.get("card_id", "")) == "notice_board" and str(card.get("condition", "")) == "NOTICES SIX PINNED / TWO OVERFLOW / BOARD CORK DRY / OLD NOTICES RETAINED",
			"the board's inspection card is V1's (%s)" % str(card.get("condition", "")))
	var rest: float = board._inspection_sheet_rest_z
	var lifted := rest
	for i in 12:
		await get_tree().process_frame
		lifted = maxf(lifted, board._inspection_sheet.position.z)
	_check(board._inspection_sheet == board.notice_sheets[0] and lifted > rest + 0.001, "the first notice lifts when the board is inspected (%.1f mm)" % ((lifted - rest) * 1000.0))
	for i in 40:
		await get_tree().process_frame
	_check(is_equal_approx(board._inspection_sheet.position.z, rest), "and settles back on the cork")


func _check_advert(advert: Node3D, plan: Dictionary) -> void:
	_check(advert.name == "OrisonOriginalSalesBoard", "the broadside keeps its V1 name")
	var sheet := advert.get_node("Advert__Sheet_ON_paper") as MeshInstance3D
	var paper: AABB = sheet.transform * sheet.get_aabb()
	var last_y := 9.0
	var boxes: Array[AABB] = []
	for row: Array in ADVERT:
		var label: Label3D = advert.lettering.get(row[0])
		_check(label != null, "the broadside carries its %s line" % row[0])
		if label == null:
			continue
		_check(label.text.replace("\n", " ") == row[1] and str(label.get_meta("advert_words")) == row[1], "the %s line is the advert's own wording" % row[0])
		_readable(label, "the broadside's %s line" % row[0], 0.012)
		var ink := _ink_box(label)
		_check(ink.position.x > paper.position.x + 0.05 and ink.end.x < paper.end.x - 0.05 and ink.position.y > paper.position.y + 0.04
				and ink.end.y < paper.end.y - 0.04 and ink.position.z > paper.end.z, "the %s line lies on the sheet inside its border" % row[0])
		_check(ink.get_center().y < last_y, "the %s line follows the one above it" % row[0])
		last_y = ink.get_center().y
		for other in boxes:
			_check(ink.end.y < other.position.y, "the %s line clears the line above" % row[0])
		boxes.append(ink)
	if boxes.size() == 5:
		_check(boxes[0].size.y > boxes[1].size.y * 0.9 and advert.lettering.Title.font_size * advert.lettering.Title.pixel_size
				> 2.0 * advert.lettering.Address.font_size * advert.lettering.Address.pixel_size, "THE ORISON is the display line")
		# The engraving stands between the title and the lines beneath it.
		var ink_mesh := advert.get_node("Advert__Ink_ON_paper") as MeshInstance3D
		_check(ink_mesh != null and boxes[0].position.y - boxes[1].end.y > 0.5, "the engraving has its panel between the title and the text (%.2f m)" % (boxes[0].position.y - boxes[1].end.y))
		# No line of type runs onto the loose corner.
		var corner_pose: Transform3D = advert.get_node("LooseCornerCrease").transform
		for box in boxes:
			var low_right: Vector3 = corner_pose.affine_inverse() * Vector3(box.end.x, box.position.y, corner_pose.origin.z)
			_check(low_right.y > 0.01, "type keeps off the loose corner")
	_check(advert._loose_corner != null and advert._loose_corner.get_parent().name == "LooseCornerCrease", "the loose corner hangs on its crease")
	# V1's slow life: the corner breathes and the chain will not hang still.
	var corner_low := 9.0
	var corner_high := -9.0
	var chain_low := 9.0
	var chain_high := -9.0
	for i in 240:
		await get_tree().process_frame
		corner_low = minf(corner_low, advert._loose_corner.rotation.x)
		corner_high = maxf(corner_high, advert._loose_corner.rotation.x)
		chain_low = minf(chain_low, advert._chain.rotation.z)
		chain_high = maxf(chain_high, advert._chain.rotation.z)
	_check(corner_high > corner_low and corner_low >= -0.0491 and corner_high <= -0.0249, "V1 moves the loose corner (%.4f..%.4f rad)" % [corner_low, corner_high])
	_check(chain_high > chain_low and chain_low >= -0.0151 and chain_high <= 0.0551, "V1 sways the pull chain (%.4f..%.4f rad)" % [chain_low, chain_high])
	var chain_top := _extent(advert, advert._chain).end.y
	_check(absf(chain_top - advert._chain.position.y) < 0.012, "the chain hangs from its pivot")
	var card: Dictionary = advert.interact(_world.player)
	_check(str(card.get("card_id", "")) == "notice_board" and str(card.get("condition", "")) == "NOTICES ORIGINAL BROADSIDE / TWO LATER SERVICE SLIPS / BOARD WARPED / FRAME FASTENED",
			"the broadside's inspection card is V1's (%s)" % str(card.get("condition", "")))
	var rest: float = advert._inspection_boss_rest_z
	var pressed := rest
	for i in 12:
		await get_tree().process_frame
		pressed = maxf(pressed, advert._inspection_boss.position.z)
	_check(pressed > rest + 0.001, "the inspection boss answers the reading (%.1f mm)" % ((pressed - rest) * 1000.0))
	for i in 40:
		await get_tree().process_frame
	_check(is_equal_approx(advert._inspection_boss.position.z, rest), "and returns to its seat")
	_check(advert.interact_prompt() == "[E]  Inspect original Orison broadside", "the broadside keeps its V1 prompt")


func _check_chute(chute: Node3D) -> void:
	_check(chute.prop_type == "mail_chute" and chute.name == "LobbyMailChute", "the chute keeps its V1 identity")
	_check(chute.marking != null and chute.marking.text == "U.S. LETTER BOX", "the box is marked U.S. LETTER BOX in lettering")
	_readable(chute.marking, "the box marking", 0.012)
	var plate := _extent(chute, chute.get_node("Chute__Brass_ON_brass"))
	var mark: AABB = _ink_box(chute.marking)
	_check(mark.position.z > 0.2140 and mark.position.z < 0.2160 and mark.size.x < 0.19, "the marking lies on the legend plate")
	_check(plate.end.z >= 0.2139, "the legend plate stands on the box head")
	# Cutler: the front at least three-quarters glass.
	var body := _extent(chute, chute.get_node("Chute__Body_ON_iron_blackened"))
	var cover_top := _extent(chute, chute._cover).end.y
	var lower := _extent(chute, chute._glass)
	var upper := _extent(chute, chute.get_node("Chute__UpperGlass_ON_glass"))
	var front := body.end.y - cover_top
	var glazed := (minf(lower.end.y, upper.position.y) - cover_top) + upper.size.y
	_check(glazed / front >= 0.75, "the chute front is %.0f%% glass, not less than three-quarters" % (100.0 * glazed / front))
	# The fault as V1 states it.
	_check(chute.arch_standing and not chute.passage_clear() and chute.box_appears_empty() and not chute.drop_reaches_box()
			and chute.cover_locked and not chute.chute_clear, "the chute starts choked, its box empty")
	_check(is_equal_approx(chute.load_on_arch(), 1.0), "the load stands on the arch")
	_check(chute.control_prompt("chute") == "[E]  The mail chute is choked", "the service point names the fault")
	_check(not chute._test_piece.visible and not chute._tray.visible and not chute._blade.visible and chute._load.visible, "only the standing mail shows")
	var card: Dictionary = chute.service_wire_card()
	_check(str(card.get("title", "")) == "MAIL CHUTE AND CHOKE" and str(card.get("body", "")).contains("An empty box downstairs is not the same thing as a clear chute."),
			"the inspection card is V1's")
	var library := MaintenanceActivityLibrary.load_default()
	_check(library.is_valid() and library.has_activity(ACTIVITY), "the chute's service is in the activity library")
	var steps: Array = library.activity(ACTIVITY).steps
	var by_id: Dictionary = {}
	for step: Dictionary in steps:
		by_id[str(step.id)] = step
	var start: Dictionary = chute.maintenance_snapshot()

	# The refusals, through the apparatus's own preview.
	chute.preview_maintenance_step(by_id.take_the_load, 0.58)
	_check(chute.balking() and is_zero_approx(chute.glass_drawn) and not chute.load_taken, "the glass will not move under a locked cover")
	chute.preview_maintenance_step(by_id.unlock_the_cover, 1.0)
	_check(not chute.cover_locked and is_equal_approx(chute._key.rotation.z, 1.30) and is_equal_approx(chute._cover.position.z, 0.146),
			"the key turns and the cover stands off")
	chute.restore_maintenance_snapshot(start)
	chute.preview_maintenance_step(by_id.unlock_the_cover, 1.0)
	chute.preview_maintenance_step(by_id.break_the_arch, 0.41)
	_check(chute.arch_standing and chute.balking() and is_zero_approx(chute.blade_set), "the arch will not be cut with the load still on it")
	chute.preview_maintenance_step(by_id.prove_the_drop, 0.88)
	_check(not chute.test_piece_landed and not chute._test_piece.visible, "a test piece hangs at a standing arch")
	chute.restore_maintenance_snapshot(start)
	_check(chute.maintenance_snapshot() == start and chute.cover_locked and is_zero_approx(chute._key.rotation.z), "the snapshot restores the apparatus")

	# The service itself, through V1's own panel and director.
	chute.maintenance_completed.connect(func(result: Dictionary) -> void: _completed.append(result))
	var hit := _ray(_plan(chute, Vector3(0.0, 1.45, 1.2)), _plan(chute, Vector3(0.0, 1.26, 0.1)), true)
	_check(not hit.is_empty() and (hit.collider as Node).name == "ChuteReach", "the player's ray finds the service point")
	_check(chute.interact_control("chute", _world.player) == true and is_instance_valid(chute._service_panel), "the service panel opens on the chute")
	if not is_instance_valid(chute._service_panel):
		return
	var panel: Node = chute._service_panel
	_check(not chute.interact_control("chute", _world.player), "a second hand is refused while the panel is open")
	for step: Dictionary in steps:
		var id := str(step.id)
		var target := float(step.target)
		_check(str(panel._director.active_run.current_step().id) == id, "the panel is on %s" % id)
		panel._adjust(target - panel._value)
		match id:
			"read_the_glass":
				_check(is_equal_approx(chute.lamp_scan, target) and is_equal_approx(chute._lamp_index.position.y, 1.06 + 1.02 * target),
						"the lamp index runs up the glass")
				_check(chute.box_appears_empty() and chute.arch_standing, "the box is empty and the chute is not clear")
			"unlock_the_cover":
				_check(not chute.cover_locked and is_equal_approx(chute._cover.position.z, 0.146), "the cover is keyed off")
			"take_the_load":
				_check(is_equal_approx(chute.glass_drawn, target) and chute.load_taken and is_zero_approx(chute.load_on_arch()),
						"the glass is drawn and the load comes off the arch")
				_check(is_equal_approx(chute._glass.position.y, 1.58 + 0.62 * target) and chute._tray.visible and not chute._load.visible
						and is_equal_approx(chute._tray.position.y, 1.20), "the glass rides up its grooves over the catch tray")
				_check(chute.arch_standing, "the arch still stands with its load off")
			"break_the_arch":
				_check(not chute.arch_standing and chute.passage_clear() and chute._blade.visible, "the blade breaks the span")
				var floor_y := _extent(chute, chute._arch_a).position.y
				var box_floor := float(chute.plan.box_floor_y)
				_check(absf(floor_y - box_floor) < 0.004 and absf(chute._arch_a.rotation.z) < 0.05,
						"the fallen letters lie on the box floor (%.3f m)" % floor_y)
				_check(chute.box_appears_empty() and not chute.chute_clear, "and still nothing is proved")
			"prove_the_drop":
				_check(is_zero_approx(chute.glass_drawn) and chute.test_piece_landed and chute._test_piece.visible and chute.drop_reaches_box()
						and not chute.box_appears_empty(), "the glass is shut and the test piece arrives in the box")
				var piece := _extent(chute, chute._test_piece)
				var shell := _extent(chute, chute.get_node("Chute__Body_ON_iron_blackened"))
				_check(piece.position.y >= float(chute.plan.box_floor_y) - 0.002 and piece.end.z < 0.212 and piece.position.x > shell.position.x,
						"the test piece rests inside the box behind the door glass")
				_check(not chute.chute_clear, "working the apparatus does not record the chute clear")
		var held := float(step.get("hold_min_seconds", 0.0)) + 0.3
		_check(panel._director.submit(str(step.verb), target, held), "%s is accepted" % id)
	_check(_completed.size() == 1 and chute.chute_clear and chute.cover_locked and is_zero_approx(chute.glass_drawn),
			"the service completes: the chute is recorded clear and locked up again")
	_check(chute.control_prompt("chute") == "[E]  Check the mail chute", "the service point no longer names a fault")
	var wait := 0
	while is_instance_valid(chute._service_panel) and wait < 600:
		await get_tree().process_frame
		wait += 1
	_check(chute._service_panel == null and not _world.player.call_locked, "the panel closes and frees the player")
	_check(is_equal_approx(chute._key.rotation.z, 0.0) and is_equal_approx(chute._cover.position.z, 0.128)
			and is_equal_approx(chute._glass.position.y, 1.58), "the apparatus is back at rest")
	# A data file cannot clear a choked chute (V1's guarded publication).
	var probe: Dictionary = chute.maintenance_snapshot()
	chute.restore_maintenance_snapshot(start)
	chute.apply_maintenance_result({"mechanism_patch": {"chute_clear": true}})
	_check(not chute.chute_clear and chute.arch_standing, "a result cannot record a standing arch clear")
	chute.restore_maintenance_snapshot(probe)
	_check(chute.chute_clear and not chute.arch_standing, "the cleared chute is as the service left it")
	# The door: hinged at one side, glazed, never a toggle.
	var door := _extent(chute, chute._box_door)
	_check(absf(chute._box_door.position.x - door.position.x) < 0.012 and chute.box_door_glass.get_parent() == chute._box_door,
			"the box door carries its glass and is hinged at its west side")
	_check(not chute.has_method("manipulation_target"), "V1 gives the door no hand action, and none is added")


## Every drawn surface: authored UVs and tangents, a registered catalogue
## finish (or the house glass), no primitive meshes.
func _check_surfaces(props: Array) -> Dictionary:
	var draws := 0
	var labels := 0
	var triangles := 0
	var parts := 0
	var maps: Dictionary = {}
	for prop: Node3D in props:
		for node in prop.find_children("*", "GeometryInstance3D", true, false):
			if node is Label3D:
				labels += 1
				draws += 1
				continue
			var mesh: Mesh = null
			var copies := 1
			if node is MeshInstance3D:
				mesh = (node as MeshInstance3D).mesh
			elif node is MultiMeshInstance3D:
				mesh = (node as MultiMeshInstance3D).multimesh.mesh
				copies = (node as MultiMeshInstance3D).multimesh.instance_count
			else:
				_check(false, "%s/%s is neither mesh nor lettering" % [prop.name, node.name])
				continue
			draws += 1
			parts += 1
			var named := "%s/%s" % [prop.name, node.name]
			_check(mesh is ArrayMesh and (node.has_meta("native_lobby_set_part")), "%s is Blender stock" % named)
			if mesh == null:
				continue
			_check(mesh.get_surface_count() == 1, "%s is one surface" % named)
			var arrays := mesh.surface_get_arrays(0)
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			_check(uvs.size() == vertices.size() and uvs.size() > 0, "%s has authored UVs" % named)
			_check(tangents.size() == vertices.size() * 4, "%s has tangents" % named)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3 * copies
			var material: Material = (node as GeometryInstance3D).material_override
			if material is ShaderMaterial:
				_check(str(node.get_meta("material_key", "glass")) == "glass" or node is MultiMeshInstance3D,
						"%s: only glass takes a shader" % named)
				_check((material as ShaderMaterial).shader != null and (material as ShaderMaterial).shader.resource_path.ends_with("lamp_glass_surface.gdshader"),
						"%s is glazed with the house glass" % named)
			else:
				var finish := material as StandardMaterial3D
				_check(finish != null and finish.albedo_texture != null and finish.roughness_texture != null and finish.normal_texture != null
						and finish.normal_enabled, "%s has albedo, roughness and normal maps" % named)
				if finish != null:
					_check(not finish.uv1_triplanar, "%s uses its authored chart, not triplanar" % named)
					_check(finish.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC, "%s samples with mipmaps" % named)
					for map: Texture2D in [finish.albedo_texture, finish.roughness_texture, finish.normal_texture]:
						if map != null:
							maps[map.resource_path] = map
	_check(parts >= 36, "the set draws its Blender parts (%d)" % parts)
	for path: String in maps:
		var image := (maps[path] as Texture2D).get_image()
		_check(path.begins_with("res://assets/building/textures/") and image != null and image.has_mipmaps(),
				"%s is a catalogue map with its mip chain" % path.get_file())
	return {"draws": draws, "labels": labels, "triangles": triangles}


func _capture(board: Node3D, advert: Node3D, chute: Node3D) -> void:
	var out := OS.get_environment("SHOT_DIR")
	if out.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(out)
	for layer in _world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	_world.player.set_physics_process(false)
	_world.player.set_lamp_enabled(false)
	if _world.service_set_carrier != null:
		_world.service_set_carrier.visible = false
	var stand := Stand.new()
	stand.test = self
	stand.process_priority = 1000
	add_child(stand)
	var bank := _world.adapter.resolve("LobbyMailBank") as Node3D
	var views := [
		["board_standing", board, Vector3(0.05, -0.27, 2.3), Vector3(0.0, -0.05, 0.0)],
		["board_notices", board, Vector3(0.0, -0.10, 0.95), Vector3(0.0, 0.0, 0.0)],
		["board_top_row", board, Vector3(0.0, 0.10, 0.42), Vector3(0.0, 0.17, 0.0)],
		["board_bottom_row", board, Vector3(0.0, -0.16, 0.42), Vector3(0.0, -0.13, 0.0)],
		["board_overflow", board, Vector3(0.60, -0.10, 0.50), Vector3(0.62, -0.05, 0.0)],
		["board_wireless", board, Vector3(-0.80, -0.10, 0.62), Vector3(-0.80, 0.0, 0.0)],
		["board_raking", board, Vector3(1.25, -0.20, 0.80), Vector3(0.0, 0.0, 0.0)],
		["advert_standing", advert, Vector3(0.0, 0.08, 2.9), Vector3(0.0, 0.0, 0.0)],
		["advert_read", advert, Vector3(0.0, 0.08, 1.55), Vector3(0.0, -0.05, 0.0)],
		["advert_text", advert, Vector3(0.0, -0.40, 0.75), Vector3(0.0, -0.47, 0.0)],
		["advert_corner", advert, Vector3(0.75, -0.45, 0.60), Vector3(0.42, -0.62, 0.05)],
		["advert_raking", advert, Vector3(1.7, 0.08, 1.4), Vector3(0.0, -0.1, 0.0)],
		["chute_standing", chute, Vector3(0.25, 1.6, 2.4), Vector3(0.0, 1.55, 0.0)],
		["chute_choke", chute, Vector3(0.18, 1.55, 0.85), Vector3(0.0, 1.32, 0.05)],
		["chute_box", chute, Vector3(0.30, 1.55, 0.95), Vector3(0.0, 0.98, 0.10)],
		["chute_ceiling", chute, Vector3(0.5, 1.6, 1.5), Vector3(0.0, 2.75, 0.05)],
	]
	for view: Array in views:
		await _shot(out, str(view[0]), _plan(view[1], view[2]), _plan(view[1], view[3]))
	if bank != null:
		# The mail bank and the chute together, from the room they share.
		var middle: Vector3 = (bank.global_position + chute.global_position) * 0.5
		var out_dir: Vector3 = chute.global_transform.basis.z
		await _shot(out, "bank_and_chute", middle + out_dir * 2.6 + Vector3.UP * 1.6, middle + Vector3.UP * 1.35)
		await _shot(out, "bank_and_chute_oblique", chute.global_position + out_dir * 1.9 + chute.global_transform.basis.x * 1.3 + Vector3.UP * 1.6,
				middle + Vector3.UP * 1.3)
	# The chute in service: glass drawn over the tray, cover keyed off.
	var rest: Dictionary = chute.maintenance_snapshot()
	chute.restore_maintenance_snapshot({"arch_standing": true, "load_taken": false, "cover_locked": false, "glass_drawn": 0.3,
			"lamp_scan": 0.72, "blade_set": 0.0, "test_piece_landed": false, "chute_clear": false})
	await _shot(out, "chute_service", _plan(chute, Vector3(0.22, 1.55, 0.80)), _plan(chute, Vector3(0.0, 1.36, 0.05)))
	chute.restore_maintenance_snapshot(rest)
	# The same close views by the player's own carried lamp, for reading.
	_world.player.set_lamp_enabled(true)
	for view: Array in views:
		if str(view[0]) in ["board_notices", "board_top_row", "board_bottom_row", "board_overflow", "board_wireless", "advert_read", "advert_text",
				"advert_corner", "chute_standing", "chute_choke", "chute_box"]:
			await _shot(out, str(view[0]) + "_lamp", _plan(view[1], view[2]), _plan(view[1], view[3]))
	if bank != null:
		var both: Vector3 = (bank.global_position + chute.global_position) * 0.5
		await _shot(out, "bank_and_chute_lamp", both + chute.global_transform.basis.z * 2.6 + Vector3.UP * 1.6, both + Vector3.UP * 1.35)
	_world.player.set_lamp_enabled(false)
	_holding = false
	stand.queue_free()


func _shot(out: String, key: String, eye: Vector3, target: Vector3) -> void:
	_eye = eye
	_target = target
	_holding = true
	for i in 60:
		await get_tree().process_frame
	for i in 10:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("lobby_set_%s.png" % key))
	print("[V2 LOBBY SET] shot ", key)


func _finish() -> void:
	var ok := _fails == 0
	print("[V2 LOBBY SET] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	_holding = false
	if is_instance_valid(_world):
		if _world.has_method("shutdown_for_tests"):
			_world.shutdown_for_tests()
		remove_child(_world)
		_world.free()
	get_tree().quit(0 if ok else 1)
