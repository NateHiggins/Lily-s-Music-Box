extends Node
## Framegrabs of the handset at each stage, so the interface is judged
## by looking at it rather than by reading the code that drew it.
##
##   SHOT_DIR=<abs windows path> godot --path game \
##       res://tests/PhoneOSShots.tscn
##
## Needs a real window like every other shot pass here: _snap awaits
## frame_post_draw, which never fires under --headless.

const STAGES := [
	{"name": "p_01_boot", "at": 1.3, "screen": PhoneOS.Screen.BOOT},
	{"name": "p_02_motd", "at": 2.4, "screen": PhoneOS.Screen.MOTD},
	{"name": "p_03_home", "at": 0.6, "screen": PhoneOS.Screen.HOME},
	{"name": "p_04_term", "at": 0.6, "screen": PhoneOS.Screen.APP,
	 "app": "term"},
	{"name": "p_05_radio", "at": 0.9, "screen": PhoneOS.Screen.APP,
	 "app": "radio"},
	{"name": "p_06_cartridge", "at": 0.4, "screen": PhoneOS.Screen.APP,
	 "app": "maze"},
]

var _dir := ""
var _phone: PhoneDevice


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	var bg := ColorRect.new()
	bg.color = Color("0a060c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	_phone = PhoneDevice.new()
	host.add_child(_phone)
	_phone.fit_into(Vector2(get_viewport().get_visible_rect().size))
	_run()


func _run() -> void:
	await get_tree().create_timer(0.4).timeout
	var failures := 0
	for stage in STAGES:
		# Drive the OS straight to the state rather than waiting out the
		# boot for every frame: these are documentation stills, not a
		# timing test.
		_phone.os_sim.screen = stage.screen
		_phone.os_sim.t = float(stage.at)
		if stage.has("app"):
			_phone.os_sim.app_id = str(stage.app)
			if str(stage.app) == "term":
				_phone.os_sim._run_command("cat shift.txt")
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [_dir, stage.name]
		if img.save_png(path) != OK:
			print("[PHONE] FAILED to write %s" % path)
			failures += 1
		else:
			print("[PHONE] saved %s" % path)
	print("[PHONE] RESULT: %s" % ["PASS" if failures == 0 else "FAIL"])
	get_tree().quit(failures)
