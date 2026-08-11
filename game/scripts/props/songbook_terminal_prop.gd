class_name SongbookTerminalProp
extends FunctionalProp
## The phonautograph in the Harukiya, and the reason any of the Songbook is
## reachable at all. See ORISON_BIBLE III.2.
##
## Scott de Martinville, Paris, patented March 1857 - twenty years before
## Edison. A horn gathers the sound, a diaphragm at its throat carries a stiff
## bristle, and the bristle scratches a line into soot on a hand-cranked
## cylinder. **It records and it cannot play back.** Not badly: at all. Scott
## was a printer and expected people would learn to READ sound the way they read
## writing. Nobody could, and his 1860 recording was not heard by anyone until
## 2008, when researchers scanned the paper optically - a hundred and forty-eight
## years between the singing and the listening.
##
## So this machine never emits recorded audio. If a trace is ever heard in this
## room it is not the machine, and that is the Tenant. Playback belongs to the
## basement studio, which is the only thing in the world that can read one back.
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

var _cylinder: MeshInstance3D
var _diaphragm: MeshInstance3D
var _stylus: MeshInstance3D
var _crank_hub: MeshInstance3D
var _crank_arm: MeshInstance3D
var _crank_knob: MeshInstance3D
var _hum: AudioStreamPlayer3D
var _clunk: AudioStreamPlayer3D
var _t := 0.0
var _panel: Node


func _build_visual() -> void:
	var walnut := Color(0.235, 0.150, 0.090)
	var brass := Color(0.52, 0.41, 0.19)
	var iron := Color(0.175, 0.180, 0.186)
	var soot := Color(0.035, 0.033, 0.032)

	# The plinth. A cabinetmaker's box with a moulded lip, because in 1857 a
	# scientific instrument was furniture before it was equipment.
	var base := make_box(Vector3(0.62, 0.10, 0.34), Vector3(0, 0.05, 0), walnut)
	(base.material_override as StandardMaterial3D).roughness = 0.55
	make_box(Vector3(0.66, 0.022, 0.38), Vector3(0, 0.104, 0),
			walnut.lightened(0.10))
	for sx in [-0.26, 0.26]:
		make_cyl(0.028, 0.028, 0.05, Vector3(sx, 0.02, 0), iron, 0.6)

	# THE BARREL. Scott's was a section of a barrel - the horn is literally a
	# cooper's cone, which is why the machine looks like something from a
	# cellar rather than a laboratory.
	var horn := make_cyl(0.145, 0.052, 0.30, Vector3(-0.16, 0.30, 0.0),
			walnut.darkened(0.10), 0.62)
	horn.rotation.z = deg_to_rad(90.0)
	# Hoops, the way a barrel is held together.
	for hx in [-0.27, -0.18, -0.08]:
		var hoop := make_cyl(0.146 - absf(hx + 0.16) * 0.30,
				0.146 - absf(hx + 0.16) * 0.30, 0.012,
				Vector3(hx, 0.30, 0.0), iron, 0.5)
		hoop.rotation.z = deg_to_rad(90.0)
	# The throat, and the diaphragm across it.
	make_cyl(0.055, 0.055, 0.030, Vector3(-0.008, 0.30, 0.0), brass, 0.32)
	_diaphragm = make_cyl(0.047, 0.047, 0.004, Vector3(0.010, 0.30, 0.0),
			Color(0.72, 0.68, 0.58), 0.45)
	_diaphragm.rotation.z = deg_to_rad(90.0)

	# The bristle. A hog's bristle on a lever, and the entire reason any of
	# this works - it is also the smallest and most fragile thing in the room.
	_stylus = make_box(Vector3(0.075, 0.004, 0.004),
			Vector3(0.055, 0.298, 0.0), Color(0.62, 0.58, 0.44))

	# THE CYLINDER, under soot. Lampblack over paper, and the line the bristle
	# leaves is the only record that will ever exist of anything sung here.
	_cylinder = make_cyl(0.075, 0.075, 0.22, Vector3(0.155, 0.30, 0.0), soot, 0.92)
	_cylinder.rotation.x = deg_to_rad(90.0)
	make_cyl(0.020, 0.020, 0.30, Vector3(0.155, 0.30, 0.0), brass, 0.35).rotation.x = deg_to_rad(90.0)
	# Carriage and lead screw: the cylinder travels as it turns, or the line
	# would close a circle and write over itself.
	make_box(Vector3(0.30, 0.020, 0.020), Vector3(0.155, 0.175, 0.09), iron)
	make_cyl(0.010, 0.010, 0.28, Vector3(0.155, 0.175, -0.09), brass, 0.4).rotation.z = deg_to_rad(90.0)

	# The crank. Hand-turned, because there is no motor in 1857 and the speed
	# of the recording is however steadily the person turning it can turn.
	_crank_hub = make_cyl(0.022, 0.022, 0.030, Vector3(0.155, 0.30, 0.175),
			brass, 0.35)
	_crank_hub.rotation.x = deg_to_rad(90.0)
	var arm := make_box(Vector3(0.016, 0.090, 0.016),
			Vector3(0.155, 0.345, 0.190), iron)
	_crank_arm = arm
	_crank_knob = make_cyl(0.014, 0.014, 0.040,
			Vector3(0.155, 0.390, 0.190), walnut, 0.5)
	_crank_knob.rotation.x = deg_to_rad(90.0)

	# The maker's plate. Scott sold these through Rudolph Koenig in Paris, and
	# an instrument of this date says so in engraved brass.
	make_box(Vector3(0.10, 0.035, 0.004), Vector3(-0.16, 0.135, 0.172), brass)

	# No screen, no keypad, no coin slot, and no green glow: this machine has
	# no electricity in it at all. The only light it gets is the room's.
	_hum = make_emitter("hum_loop", -46.0, true)
	_hum.pitch_scale = 0.55
	_hum.max_distance = 3.0
	_clunk = make_emitter("tick", -12.0)


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
	# Nothing breathes here. The old terminal had a tube that pulsed on idle
	# and a green glow to light its corner; this machine has no electricity in
	# it at all, so at rest it is simply a wooden box in whatever light the bar
	# is giving it. The only thing that ever moves is the cylinder, and only
	# while somebody is turning the crank.
	if _panel == null:
		return
	var turn := delta * 1.9
	if _cylinder:
		_cylinder.rotate_object_local(Vector3.UP, turn)
	if _crank_hub:
		_crank_hub.rotate_object_local(Vector3.UP, turn)
	if _crank_arm:
		# The arm and knob orbit the hub rather than spinning in place, which
		# is the difference between a crank and a knob somebody is fiddling.
		var a := _t * 1.9
		var r := 0.045
		_crank_arm.position = Vector3(0.155, 0.30 + cos(a) * r * 0.5,
				0.190 + sin(a) * r * 0.5)
		_crank_arm.rotation.z = -a
		if _crank_knob:
			_crank_knob.position = Vector3(0.155, 0.30 + cos(a) * r,
					0.190 + sin(a) * r)
