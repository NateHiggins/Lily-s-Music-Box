extends Node
## V4: what the arcade's lights are actually doing, station by station.
##
## This exists because nothing in the suite could see the defect it was built
## to find. `LightRig.stats()` reports only full/off/shadows building-wide,
## WalkTest reads that and is content, and no station in any harness stands in
## the nave — so the arcade could go entirely dark, or hold shadow maps for
## fixtures that emit nothing, and every test would still pass.
##
## The specific thing it catches: a fixture that has been switched OFF by the
## hours director still enters the rig's ranking, still wins a slot, and still
## gets shadow_enabled, because `LightFixtureProp` never implemented
## `is_locally_enabled()` — the one hook at light_rig.gd:493-496 that removes a
## fixture from the contest. `LampProp` implements it; the shop fixtures did
## not, so ten of the arcade's own lanterns lost the rank to dead bulbs.

const STATIONS := [
	{"name": "throat_reveal", "pos": Vector3(14.0, 1.68, 33.2)},
	{"name": "southbound", "pos": Vector3(14.0, 1.68, 39.5)},
	{"name": "mid_nave", "pos": Vector3(14.0, 1.68, 51.6)},
	{"name": "northbound", "pos": Vector3(14.0, 1.68, 63.6)},
]
## Every light the arcade owns, by id prefix.
const ARCADE_PREFIXES := ["PASSAGE_AISLE_LT", "SITE_SHOP_LT", "SITE_SHOP_IN",
		"SITE_SHOP_DARKROOM"]

var root: Node3D
var failures := 0
var checks := 0
var _finished := false


func _ready() -> void:
	print("[ARCADE LIGHT] START")
	_watchdog()
	if OS.get_environment("DAYNIGHT") == "":
		OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout
	var worst_dead_shadow := 0
	var worst_dead_slot := 0
	for station in STATIONS:
		var r := _survey(station)
		worst_dead_shadow = maxi(worst_dead_shadow, int(r.dead_shadow))
		worst_dead_slot = maxi(worst_dead_slot, int(r.dead_slot))
	# A slot held by a fixture that emits nothing is a slot the arcade's own
	# lanterns lost. Both of these must be zero.
	_check("no powered-off fixture holds a shadow map (worst %d)"
			% worst_dead_shadow, worst_dead_shadow == 0)
	# The two ungoverned V4 spots must EXIST, be shadowless, and be outside
	# the rig's ration -- that last part is the whole reason they can exist.
	var pass_root := root.get_node_or_null("PassageLightPass")
	var shaft := pass_root.get_node_or_null("PassageCrossingShaft") 			if pass_root else null
	var lun := pass_root.get_node_or_null("PassageLunetteKey") 			if pass_root else null
	var governed := get_tree().get_nodes_in_group("light_fixtures")
	_check("both V4 spots exist, shadowless, and ungoverned",
			shaft != null and lun != null
			and not shaft.shadow_enabled and not lun.shadow_enabled
			and not governed.has(shaft) and not governed.has(lun))
	print("  shaft energy %.2f  lunette energy %.2f"
			% [shaft.light_energy if shaft else -1.0,
			lun.light_energy if lun else -1.0])
	_finished = true
	print("ARCADE LIGHT CENSUS: %s (%d checks)" % [
			"PASS" if failures == 0 else "FAIL %d" % failures, checks])
	get_tree().quit(failures)


func _watchdog() -> void:
	await get_tree().create_timer(90.0, true, false, true).timeout
	if not _finished:
		printerr("[ARCADE LIGHT] WATCHDOG — FAIL")
		get_tree().quit(1)


func _survey(station: Dictionary) -> Dictionary:
	var eye: Vector3 = station.pos
	root.player.global_position = eye - Vector3(0.0,
			PlayerController.STANDING_EYE, 0.0)
	root.light_rig._accum = LightRig.INTERVAL
	root.light_rig._process(LightRig.INTERVAL)

	var arcade := 0
	var lit := 0
	var dark_ids: Array[String] = []
	var dead_shadow := 0
	var dead_slot := 0
	var off_count := 0
	for fixture in root.light_rig.debug_fixtures():
		var fid := str(fixture.name)
		var mine := false
		for p in ARCADE_PREFIXES:
			if fid.begins_with(p):
				mine = true
		var src: Light3D = fixture.get("light")
		if src == null:
			continue
		# "Emits nothing" is the honest test, not "is switched off": a
		# fixture can be powered with its state gain wound to zero.
		# Not every fixture class carries both fields — LampProp and
		# LightFixtureProp differ — and get() returns null for a missing one,
		# which is not a number. Absent means "no reason to think it is off",
		# so default to emitting and only narrow on real values.
		var emits := true
		var powered_v: Variant = fixture.get("powered")
		if powered_v != null:
			emits = bool(powered_v)
		var gain_v: Variant = fixture.get("_state_gain")
		if emits and gain_v != null:
			emits = float(gain_v) > 0.001
		var ranked := src.visible and src.light_energy > 0.0
		# THE PROVABLE WASTE. set_budget writes shadow_enabled from the
		# fixture's INDEX in the rig's eligible list, and only afterwards
		# zeroes the scale for an unpowered fixture -- so a dark light still
		# holding a shadow map is direct evidence it won a top-16 index that
		# a lantern with something to show could have had.
		#
		# The light-slot count is NOT measured here. It follows from the same
		# eligible-list membership, but the rig exposes no way to observe an
		# index without re-implementing its ranking, and re-implementing a
		# ranking to audit that ranking is how three confident wrong numbers
		# got into this project today.
		if not emits and src.shadow_enabled:
			dead_shadow += 1
			dead_slot += 1
		if not mine:
			continue
		arcade += 1
		if not emits:
			off_count += 1
		if ranked and emits:
			lit += 1
		elif emits:
			dark_ids.append(fid)
	print("  %-14s arcade %2d lit %2d switched-off %2d | dead slots %2d, shadowed %d"
			% [station.name, arcade, lit, off_count, dead_slot, dead_shadow])
	if not dark_ids.is_empty():
		print("      arcade fixtures wanting to emit but dropped: %s"
				% [dark_ids.slice(0, 6)])
	return {"dead_shadow": dead_shadow, "dead_slot": dead_slot}


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [arcade ok] ", label)
	else:
		failures += 1
		printerr("  [ARCADE FAIL] ", label)
