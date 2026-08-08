class_name PhoneCarrier
extends Node3D
## The handset, carried. Bottom-right of frame, in the hand that was
## already holding the torch.
##
## The fiction was here first: player_controller calls its torch "a
## phone held low in the hand" and carries an invisible `_hand` node at
## the player's right. This puts the object where that fiction always
## said it was.
##
## TWO HOLDS, and the reason is legibility rather than taste. A 66 mm
## handset held at arm's length inside a 72-degree camera covers about
## a seventh of the screen width, which turns a 480-pixel OS into 190
## pixels and makes every line of it unreadable. So:
##
##   CARRIED - low, right, angled away, moving with the walk. Not meant
##             to be read. It is a light source, a colour, and a thing
##             in your hand.
##   RAISED  - brought up and turned toward the eye, close enough that
##             the OS is genuinely readable.
##
## Games have solved this by making the held object oversized since
## about 1996. This does it by moving the object instead, because the
## phone is a real size in a real building and a comically large one
## would be the only object in the Orison not measured from life.

## The screen quad's normal is the phone's local +Z, and the camera
## looks down its own -Z, so a phone with no rotation faces the eye
## squarely. Carried, it lies back roughly 58 degrees - held at the hip
## with the face tilted up the way anyone actually carries one - and
## that pitch is the whole difference between seeing the screen and
## seeing the phone's edge, which is how the first framegrab came out.
const CARRY_POS := Vector3(0.135, -0.150, -0.315)
const CARRY_ROT := Vector3(-49.0, -13.0, 5.0)
const RAISE_POS := Vector3(0.055, -0.075, -0.165)
const RAISE_ROT := Vector3(-10.0, -5.0, 1.0)
const RAISE_SPEED := 6.5

var phone: Phone3D
var raised := false

var _blend := 0.0            # 0 carried, 1 raised
var _bob := 0.0
var _sway := Vector2.ZERO
var _player: Node3D


func setup(player: Node3D, camera: Camera3D) -> void:
	_player = player
	camera.add_child(self)
	phone = Phone3D.new()
	add_child(phone)
	# A small fill so the body is never a silhouette. The building is
	# dark on purpose and the screen only lights its own face; without
	# this the phone reads as a hole in the bottom corner.
	var fill := OmniLight3D.new()
	fill.light_color = Color("8fa4c8")
	# Barely there. At 0.22 it washed the casing to near-white and the
	# handset read as a sheet of paper; the screen is meant to be the
	# brightest thing on the object by a wide margin.
	fill.light_energy = 0.07
	fill.omni_range = 0.45
	fill.shadow_enabled = false
	fill.position = Vector3(0.06, 0.12, 0.12)
	add_child(fill)
	# The lens has to share the player's World3D or the viewfinder shows
	# a correctly-lit void. Deferred because the carrier is parented to
	# the camera during the building's own _ready, and get_viewport()
	# only answers once we are actually in the tree.
	call_deferred("_bind_lens_world")
	set_process(true)


func _bind_lens_world() -> void:
	if phone and phone.cam and is_inside_tree():
		phone.cam.bind_world(get_viewport())


func toggle_raise() -> void:
	raised = not raised
	if phone:
		phone.punch_glitch(0.5)


## Look-lag: the hand trails the view by a few degrees and catches up.
## It is the cheapest trick in first-person animation and the one that
## does the most, because a held object that tracks the camera exactly
## reads as painted on the lens.
func apply_look(rel: Vector2) -> void:
	_sway.x = clampf(_sway.x - rel.x * 0.020, -7.0, 7.0)
	_sway.y = clampf(_sway.y - rel.y * 0.016, -5.0, 5.0)


func _process(delta: float) -> void:
	_blend = move_toward(_blend, 1.0 if raised else 0.0,
			delta * RAISE_SPEED)
	var eased: float = _blend * _blend * (3.0 - 2.0 * _blend)
	# Walk bob, taken from the player's own speed so a stroll and a
	# hurry do not look the same.
	var speed := 0.0
	if _player and "velocity" in _player:
		speed = Vector3(_player.velocity.x, 0.0,
				_player.velocity.z).length()
	_bob += delta * (2.2 + speed * 2.4)
	var amp: float = (0.0035 + speed * 0.0022) * (1.0 - eased * 0.6)
	var bob := Vector3(sin(_bob * 1.6) * amp,
			sin(_bob * 3.2) * amp * 0.8, 0.0)
	_sway = _sway.lerp(Vector2.ZERO, minf(1.0, delta * 5.0))
	position = CARRY_POS.lerp(RAISE_POS, eased) + bob
	var rot := CARRY_ROT.lerp(RAISE_ROT, eased)
	rotation_degrees = rot + Vector3(_sway.y, _sway.x, 0.0)


func key(action: String, typed := "") -> void:
	if phone:
		phone.key(action, typed)
