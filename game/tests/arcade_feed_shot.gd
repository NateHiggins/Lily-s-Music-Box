extends Node
## Photographs what a cabinet's board is actually putting out, with no cabinet,
## no CRT shader and no room lighting in the way.
##
##     SHOT_DIR=... godot --path game res://tests/ArcadeFeedShot.tscn
##
## When a screen in the world looks wrong, this says whether the fault is in the
## feed or in everything downstream of it.

const CATALOG_DIR := ArcadeCatalog.DIR


func _ready() -> void:
	_run()


func _run() -> void:
	var catalog := ArcadeCatalog.load_catalog(CATALOG_DIR)
	if catalog == null or catalog.size() == 0:
		print("[FEED] no catalog")
		get_tree().quit(1)
		return

	var directory := OS.get_environment("SHOT_DIR")
	if directory == "":
		directory = OS.get_user_data_dir()

	for index in mini(6, catalog.size()):
		var entry := catalog.spread()[index]
		var machine := ArcadeMachine.new()
		add_child(machine)
		if not machine.boot(entry, CATALOG_DIR):
			print("[FEED] %s did not boot" % String(entry.get("cabinet_id", "?")))
			continue
		machine.set_live(true)
		# Played, not attracting: the object in the player's hands is the most
		# looked-at surface in the game and attract mode does not show it.
		machine.begin_play()
		await get_tree().create_timer(1.2).timeout
		# One shot, so the projectile is in frame. The hit already resolved when
		# this was called; what flies is decoration chasing it.
		if machine.player.weapon != null:
			machine.player.weapon.try_fire()
		await get_tree().create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		var stem := "feed_%s" % String(entry.get("cabinet_id", "cab"))
		machine.get_texture().get_image().save_png("%s/%s.png" % [directory, stem])

		# The same board with the skin taken off. Six machines that looked like
		# six different games land on one room, which is the reveal the whole
		# arcade is built around - so it is photographed, not asserted.
		machine.degrade = 1.0
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		machine.get_texture().get_image().save_png("%s/%s_graybox.png" % [directory, stem])
		print("[FEED] %s: %s (%s) -> %s.png" % [
			stem,
			String(entry.get("title", "")),
			String(entry.get("claimed_genre", "")),
			stem,
		])
		machine.queue_free()

	get_tree().quit(0)
