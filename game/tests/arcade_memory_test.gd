extends Node
## What a row of cabinets costs to leave switched on.
##
##     godot --headless --path game res://tests/ArcadeMemoryTest.tscn
##
## `ArcadeCabinetProp` gates rendering on a 9 m distance check, which reads like
## a budget and is not one. `boot()` is one-way: walk away and `set_live(false)`
## stops the board drawing, but the built world - entities, meshes, materials,
## the package's textures - stays in memory for the rest of the session. So the
## peak is not "how many cabinets are near the player" but **"how many cabinets
## has the player ever walked past"**, and in this building that is all twelve.
##
## Geometry says at most five can be live at once: the machines are scattered
## one or two per venue rather than standing in a row, and the densest point a
## player can occupy sees five. Rendering is therefore bounded. Memory is not.
##
## This test measured that difference, which is what bought the unload policy in
## `ArcadeCabinetProp`. It now guards both halves: the ceiling on twelve resident
## worlds, and the requirement that `unload()` genuinely gives one back and that
## a machine still boots afterwards. A saving that leaves a cabinet dark is worse
## than no saving at all.

const CATALOG_DIR := ArcadeCatalog.DIR

## Room for twelve booted worlds. Measured at 92.7 MB, so this leaves ~70% of
## headroom - a regression guard, not a target. It should catch a cabinet that
## suddenly costs double, not fail on ordinary drift.
const CEILING_MB := 160.0


func _ready() -> void:
	var catalog := ArcadeCatalog.load_catalog(CATALOG_DIR)
	if catalog == null or catalog.size() == 0:
		print("[ARCADE-MEM] FAIL no catalog at %s" % CATALOG_DIR)
		get_tree().quit(1)
		return

	var baseline := _mb()
	print("[ARCADE-MEM] baseline %.1f MB, %d cabinets to boot" % [baseline, catalog.size()])

	var machines: Array[ArcadeMachine] = []
	var first_cost := 0.0
	for i in catalog.size():
		var cabinet: Dictionary = catalog.cabinets[i]
		var machine := ArcadeMachine.new()
		add_child(machine)
		if not machine.boot(cabinet, CATALOG_DIR):
			print("[ARCADE-MEM] FAIL %s did not boot"
					% String(cabinet.get("cabinet_id", "?")))
			get_tree().quit(1)
			return
		# Exactly what walking away does today. The point of the test is that
		# this line changes nothing about the number on the right.
		machine.set_live(false)
		machines.append(machine)

		var total := _mb() - baseline
		if i == 0:
			first_cost = total
		print("[ARCADE-MEM] %2d booted  %-26s +%7.1f MB   %6.1f MB each"
				% [i + 1, String(cabinet.get("title", "?")), total, total / float(i + 1)])

	var resident := _mb() - baseline
	print("[ARCADE-MEM] %d worlds resident after set_live(false) on all of them: %.1f MB"
			% [machines.size(), resident])
	print("[ARCADE-MEM] first cabinet %.1f MB; the twelfth still costs about the same, "
			% first_cost + "so nothing is being shared that is not already shared")

	# `unload()` is what the distance gate calls when the player leaves, so it is
	# what has to come back down - not queue_free, which frees the SubViewport
	# too and is not available to a prop that must keep showing a dark screen.
	for machine in machines:
		machine.unload()
	for _i in 4:
		await get_tree().process_frame
	var after := _mb() - baseline
	var reclaimed := 100.0 * (resident - after) / maxf(resident, 0.001)
	print("[ARCADE-MEM] after unload():  %.1f MB still held (%.0f%% reclaimed)"
			% [after, reclaimed])

	# And a machine that was unloaded has to be a machine again, or the gate
	# turns a memory saving into a cabinet that never comes back on.
	var reboot := machines[0]
	var ok := reboot.boot(catalog.cabinets[0], CATALOG_DIR)
	print("[ARCADE-MEM] re-boot after unload: %s, %d entities, package=%s"
			% ["ok" if ok else "FAILED", reboot._entities.size(),
			   "bound" if reboot.package != null else "missing"])

	var failures := 0
	if resident > CEILING_MB:
		print("[ARCADE-MEM] FAIL twelve booted worlds cost %.1f MB, ceiling is %.1f"
				% [resident, CEILING_MB])
		failures += 1
	if reclaimed < 80.0:
		print("[ARCADE-MEM] FAIL unload() reclaims only %.0f%% of a world" % reclaimed)
		failures += 1
	if not ok or reboot._entities.is_empty() or reboot.package == null:
		print("[ARCADE-MEM] FAIL a machine does not come back after unload()")
		failures += 1

	print("[ARCADE-MEM] %s" % ("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(1 if failures > 0 else 0)


func _mb() -> float:
	return float(OS.get_static_memory_usage()) / 1_048_576.0
