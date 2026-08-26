extends Node

const DirectorScript := preload("res://scripts/building/day_night_director.gd")


func _ready() -> void:
	var prior := bool(GameBoot.settings.reduce_flashing)
	var director = DirectorScript.new()
	GameBoot.settings.reduce_flashing = false
	var ordinary: float = director.visible_weather_flash(0.78)
	GameBoot.settings.reduce_flashing = true
	var reduced: float = director.visible_weather_flash(0.78)
	GameBoot.settings.reduce_flashing = prior
	var ok := is_equal_approx(ordinary, 0.78) and is_zero_approx(reduced)
	print("[WEATHER FLASH ACCESS] RESULT: %s 2/2" % (
			"PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
