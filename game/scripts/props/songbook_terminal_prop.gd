class_name SongbookTerminalProp
extends FunctionalProp
## The karaoke terminal in the Harukiya, and the reason any of the
## Songbook is reachable at all.
##
## Everything under scripts/songbook was written, committed and left
## INERT last session — SongResource, the procedural backing, the PA
## chain, mic capture, the version store — because nothing in the world
## referenced it. This is the thing that does: a box bolted to the wall
## by the stage that a player can walk up to and press E on.
##
## It is a rented machine, not a fixture. Every bar of this kind has one
## and none of them own it: a beige case gone the colour of tea, a CRT
## behind scratched acrylic, a numeric keypad for punching song numbers,
## and a microphone on a hook with its cable wound round the bracket by
## somebody who was not being careful. The catalogue is one song long,
## which is the joke the brief is making about folk music — there are no
## canonical words to LAST TRAIN HOME, only whatever the last person
## sang.
##
## Interact opens the Songbook panel. Everything after that is UI.

signal opened(song_id: String)

const SONG := "last_train_home"

var _screen: MeshInstance3D
var _screen_mat: StandardMaterial3D
var _glow: OmniLight3D
var _hum: AudioStreamPlayer3D
var _clunk: AudioStreamPlayer3D
var _t := 0.0
var _panel: Node


func _build_visual() -> void:
	# The case. Wall-hung, chest height, tilted back a few degrees the
	# way these always are so the screen faces someone standing.
	var body := make_box(Vector3(0.52, 0.42, 0.26), Vector3(0, 0.21, 0),
			Color(0.62, 0.58, 0.47))
	body.rotation.x = deg_to_rad(-6.0)
	var bm := body.material_override as StandardMaterial3D
	bm.roughness = 0.82
	# Screen surround in the darker functional grey, then the tube.
	make_box(Vector3(0.40, 0.30, 0.02), Vector3(0, 0.30, 0.135),
			Color(0.28, 0.27, 0.25))
	_screen = make_box(Vector3(0.34, 0.24, 0.012),
			Vector3(0, 0.30, 0.146), Color(0.08, 0.10, 0.09))
	_screen_mat = _screen.material_override as StandardMaterial3D
	_screen_mat.emission_enabled = true
	_screen_mat.emission = Color(0.18, 0.58, 0.34)
	_screen_mat.emission_energy_multiplier = 0.9
	_screen_mat.roughness = 0.30
	# Keypad: twelve keys, because a song is a number here.
	for r in 4:
		for c in 3:
			make_box(Vector3(0.032, 0.022, 0.010),
					Vector3(-0.055 + c * 0.055, 0.135 - r * 0.030, 0.138),
					Color(0.74, 0.71, 0.62))
	# The coin slot nobody has fed since the place changed hands.
	make_box(Vector3(0.09, 0.014, 0.012), Vector3(0.16, 0.075, 0.138),
			Color(0.35, 0.34, 0.32))
	# Mic on its hook, cable wound round the bracket.
	make_box(Vector3(0.03, 0.03, 0.05), Vector3(-0.30, 0.26, 0.02),
			Color(0.30, 0.29, 0.28))
	var mic := make_box(Vector3(0.035, 0.16, 0.035),
			Vector3(-0.30, 0.18, 0.05), Color(0.14, 0.14, 0.15))
	mic.rotation.z = deg_to_rad(9.0)
	make_box(Vector3(0.045, 0.045, 0.045), Vector3(-0.302, 0.262, 0.05),
			Color(0.42, 0.42, 0.44))          # the grille ball

	# A green tube in a dark room throws more light than people expect,
	# and it is the only thing lighting the corner it hangs in.
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.42, 0.92, 0.62)
	_glow.light_energy = 0.30
	_glow.omni_range = 2.4
	_glow.shadow_enabled = false
	_glow.position = Vector3(0, 0.30, 0.35)
	add_child(_glow)

	_hum = make_emitter("hum_loop", -34.0, true)
	_hum.pitch_scale = 1.65        # a small transformer, not a fridge
	_hum.max_distance = 6.0
	_clunk = make_emitter("tick", -10.0)


func _ready() -> void:
	super()
	if _hum:
		_hum.play()


func interact_prompt() -> String:
	var song := SongResource.load_song(SONG)
	if song == null:
		return "[E]  Out of order"
	return "[E]  %s  —  the songbook" % song.title


func interact(player: Node) -> void:
	var song := SongResource.load_song(SONG)
	if song == null:
		return
	if _clunk:
		_clunk.play()
	if _panel and is_instance_valid(_panel):
		return                      # already up
	var scr: GDScript = load("res://scripts/ui/songbook_panel.gd")
	_panel = scr.new()
	_panel.open(song, player, self)
	get_tree().current_scene.add_child(_panel)
	opened.emit(song.id)


## The panel calls this on the way out so the terminal knows it is free
## and the player gets their hands back.
func panel_closed() -> void:
	_panel = null


func _process(delta: float) -> void:
	_t += delta
	if _screen_mat:
		# Idle attract: the tube breathes, slightly out of step with the
		# hum, because nothing in this bar is synchronised to anything.
		var pulse := 0.78 + 0.22 * sin(_t * 1.35)
		_screen_mat.emission_energy_multiplier = pulse
	if _glow:
		_glow.light_energy = 0.24 + 0.10 * sin(_t * 1.35)
