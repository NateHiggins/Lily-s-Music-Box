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
## CARRIED IS A TORCH POSE, and it used to be a looking-at-it pose.
##
## The handset lay pitched 49 degrees down, screen flat to the ceiling,
## while the beam it supposedly casts pointed level out of the air
## beside it — two unrelated things that happened to be near each other.
## The lamp is on the BACK, so the pitch is now what a hand actually
## does with a phone it is using to see: tipped down far enough to throw
## light on the floor ahead and glance at the screen, not so far that
## the beam lands at your feet.
##
## The small yaw is the other half of the same argument. The phone is
## carried right of centre; turning it slightly inward points the screen
## a little toward the eye and puts the beam a little right of where you
## are looking, which is where a torch in one hand actually goes.
const CARRY_ROT := Vector3(-22.0, -8.0, 5.0)
## RAISED IS SQUARE-ON AND CLOSE, and both halves of that matter.
##
## Square-on: the screen quad's normal is the phone's local +Z and the
## camera looks down its own -Z, so a rotation of exactly zero puts the
## panel parallel to the view plane. Any tilt at all foreshortens the
## text, and foreshortened 8-pixel glyphs are the difference between
## reading the OS and squinting at it.
##
## Close: legibility is pure arithmetic here. The panel is 52 mm wide;
## at distance d inside a 72-degree camera it covers
## 0.052 / (2 d tan 36) of the frame. To land the 480-pixel OS at about
## 1:1 on a 1280-wide frame it has to cover ~38%, which is d = 0.122 m
## with the handset scaled 1.3x. Further away and the OS is downscaled
## and mushy; nearer and the body starts clipping the near plane.
const RAISE_POS := Vector3(0.040, -0.028, -0.122)
const RAISE_ROT := Vector3.ZERO
const RAISE_SCALE := 1.30
const RAISE_SPEED := 6.5
## The shape the carry and raise poses were posed against. Everything
## horizontal in them is a fraction of this frame, not a distance.
const REF_ASPECT := 16.0 / 9.0

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
	# The lens has to share the player's World3D or the viewfinder shows
	# a correctly-lit void. Deferred because the carrier is parented to
	# the camera during the building's own _ready, and get_viewport()
	# only answers once we are actually in the tree.
	call_deferred("_bind_lens_world")
	call_deferred("_build_overlay_pass", camera)
	set_process(true)


## RENDER THE HANDSET SEPARATELY.
##
## Culling it out of the torch fixed the lighting, but the beam mask is
## a screen-space multiply over the whole frame, and the phone sits in
## the bottom right where that mask is darkest - so the thing the
## player is holding was being dimmed by the beam it is casting. A held
## object should not be shaded by a post effect describing the room.
##
## So it gets its own pass: a SubViewport sharing the world (for the
## room's own light to still fall across it) with a camera culled to
## the handset layer alone, composited on a CanvasLayer ABOVE the mask.
## The main camera stops drawing layer 2, so nothing renders twice.
##
## This also buys the other thing a separate pass always buys: the
## phone can no longer clip through a door frame, because it is not in
## the same depth buffer as the building.
## The lamp's pose in CAMERA space, republished every frame for whoever
## is actually carrying the light. See _process.
var beam_xform := Transform3D()
var beam_aim := Vector2.ZERO      # degrees off axis, for the mask
var beam_valid := false

var _life := 0.0
var _tilt := Vector3.ZERO
var _pass_view: SubViewport
var _pass_cam: Camera3D
var _pass_src: Camera3D


func _build_overlay_pass(camera: Camera3D) -> void:
	if not is_inside_tree():
		return
	_pass_src = camera
	var size := get_viewport().get_visible_rect().size
	_pass_view = SubViewport.new()
	_pass_view.size = Vector2i(maxi(2, int(size.x)), maxi(2, int(size.y)))
	# Follow the window. Sized once, the pass keeps the resolution it was
	# born at and the TextureRect scales it to fit — so resizing the
	# window, or shipping to a handset whose screen is not the shape of
	# the desktop it was tuned on, stretches the phone.
	get_viewport().size_changed.connect(_match_viewport)
	_pass_view.transparent_bg = true
	_pass_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pass_view.handle_input_locally = false
	# ITS OWN WORLD, and this is the fix.
	#
	# Sharing the building's World3D and culling by light mask did not
	# work: the handset rendered near-black however loud its lamps were,
	# and moving them around changed nothing. Rather than keep guessing
	# at why a cull mask is not honoured here, the pass gets a world of
	# its own containing exactly three things - the phone, two lights
	# and a scrap of ambient. Nothing can reach in and nothing leaks
	# out, which is how every game that has ever drawn a weapon in a
	# hand does it.
	#
	# The cost is real and worth naming: the room's own light no longer
	# falls across the phone, so walking past a lit doorway will not
	# warm it. That is a loss. A phone you cannot see at all is worse.
	_pass_view.world_3d = World3D.new()
	add_child(_pass_view)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a3f52")
	# The casing is near-black soft-touch, so the pass needs a lot
	# more ambient than a room would. It leaks nowhere: this world
	# contains the phone and nothing else.
	env.ambient_light_energy = 1.60
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_pass_view.add_child(we)

	_pass_cam = Camera3D.new()
	_pass_cam.cull_mask = 1 << (Phone3D.PHONE_LAYER - 1)
	_pass_cam.current = true
	_pass_cam.near = 0.02
	_pass_cam.fov = camera.fov
	_pass_view.add_child(_pass_cam)

	# The handset moves INTO that world. It is no longer a child of the
	# player's camera, so the carry transform is applied to it directly
	# each frame instead of to this node.
	if phone.get_parent():
		phone.get_parent().remove_child(phone)
	_pass_view.add_child(phone)

	# Key from above-left, cold kicker from below-right, both close.
	var key := OmniLight3D.new()
	key.light_color = Color("cfd8ee")
	key.light_energy = 5.5
	key.omni_range = 0.9
	key.shadow_enabled = false
	key.position = Vector3(-0.16, 0.20, -0.10)
	_pass_view.add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color("6f7fa8")
	rim.light_energy = 2.6
	rim.omni_range = 0.8
	rim.shadow_enabled = false
	rim.position = Vector3(0.26, -0.18, -0.04)
	_pass_view.add_child(rim)

	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	var rect := TextureRect.new()
	rect.texture = _pass_view.get_texture()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	camera.cull_mask = camera.cull_mask & ~(1 << (Phone3D.PHONE_LAYER - 1))
	get_viewport().size_changed.connect(_resize_pass)


func _resize_pass() -> void:
	if _pass_view == null:
		return
	var size := get_viewport().get_visible_rect().size
	_pass_view.size = Vector2i(maxi(2, int(size.x)), maxi(2, int(size.y)))


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


## The pass renders at the window's resolution, so it has to be told
## when that changes.
func _match_viewport() -> void:
	if _pass_view == null or not is_inside_tree():
		return
	var s := get_viewport().get_visible_rect().size
	_pass_view.size = Vector2i(maxi(2, int(s.x)), maxi(2, int(s.y)))


## How much wider the frame is than the 16:9 it was posed against. The
## poses were authored at 1280x720 and every offset in them is relative
## to that shape.
func _aspect_shift() -> float:
	if not is_inside_tree():
		return 1.0
	var s := get_viewport().get_visible_rect().size
	if s.y <= 0.0:
		return 1.0
	return (s.x / s.y) / REF_ASPECT


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
	_life += delta
	# A raised phone is being READ, so the hand steadies against it. Not
	# to zero: a completely still object in a first-person view stops
	# reading as held and starts reading as painted on the lens.
	var calm: float = 1.0 - eased * 0.72

	# TRANSLATION, at three scales, because a hand is never doing only
	# one thing. Stride is the walk, two beats to a step. Breath is
	# always underneath it and slower than anything else. Tremor is the
	# hand simply not being a tripod — tiny, fast, and on frequencies
	# with no common multiple so the loop never becomes audible to the
	# eye.
	var stride: float = (0.0016 + speed * 0.0026) * calm
	var breath := 0.0011 * calm
	var tremor: float = (0.00055 + speed * 0.00030) * calm
	var bob := Vector3(
			sin(_bob * 1.6) * stride
			+ sin(_life * 1.13) * breath * 0.5
			+ (sin(_life * 11.3) + sin(_life * 17.7) * 0.6) * tremor,
			sin(_bob * 3.2) * stride * 0.8
			+ sin(_life * 0.74) * breath
			+ (sin(_life * 13.9) + sin(_life * 21.1) * 0.5) * tremor,
			sin(_life * 0.53) * breath * 0.7
			+ sin(_bob * 1.6) * stride * 0.35)

	# ROTATION, in degrees, and this is the half the BEAM notices. Seven
	# and a half metres out, one degree walks the pool of light thirteen
	# centimetres — so these stay under about two degrees all told, and
	# the light still never sits quite still on a wall.
	var wob: float = calm * (0.55 + speed * 0.42)
	_tilt = Vector3(
			sin(_life * 0.83) * 0.42 + sin(_bob * 3.2) * 0.30
			+ sin(_life * 12.7) * 0.06,
			sin(_life * 0.61) * 0.55 + sin(_bob * 1.6) * 0.34
			+ sin(_life * 15.1) * 0.05,
			sin(_life * 0.47) * 0.60 + sin(_bob * 1.6) * 0.26) * wob
	_sway = _sway.lerp(Vector2.ZERO, minf(1.0, delta * 5.0))
	# The pass camera stays at its own origin: the handset is carried in
	# camera space anyway, so there is nothing for it to follow.
	if _pass_cam and _pass_src:
		_pass_cam.fov = _pass_src.fov
	# Applied to the handset, which now lives in the pass world, rather
	# than to this node, which stays on the camera purely to do the maths.
	var target: Node3D = phone if phone else self
	var pose := CARRY_POS.lerp(RAISE_POS, eased)
	# Hold the phone's place ON SCREEN, not in space. Godot keeps the
	# VERTICAL fov fixed as the aspect changes, so a fixed offset holds
	# its height at any shape of window but drifts horizontally: on a
	# 21.6:9 handset the carried phone had wandered from the bottom-right
	# corner to about 60% across, which is the middle of the frame and
	# not where a hand is. Scaling x by the aspect puts it back.
	pose.x *= _aspect_shift()
	target.position = pose + bob
	var rot := CARRY_ROT.lerp(RAISE_ROT, eased)
	# Sway is damped out as the phone comes up: a readable screen must
	# not be a moving one, and the hand-lag that sells the carry is
	# exactly what makes small text unreadable when you are trying to
	# use it.
	var settle: float = 1.0 - eased * 0.88
	target.rotation_degrees = rot + _tilt 			+ Vector3(_sway.y, _sway.x, 0.0) * settle
	target.scale = Vector3.ONE.lerp(Vector3.ONE * RAISE_SCALE, eased)

	# WHERE THE LIGHT COMES FROM. The torch is a spotlight out in the
	# building's world — it cannot be a child of a handset that lives in
	# its own — so the phone publishes the lamp's pose in camera space
	# each frame and the player hangs the beam on it. Orientation only:
	# the raise scales the model up, and a scaled basis would stretch the
	# cone with it.
	var aim := Basis.from_euler(target.rotation)
	beam_xform = Transform3D(aim, target.position + aim * Phone3D.FLASH_AT)
	beam_valid = true
	# The screen-space mask has to agree with the 3D beam or the two
	# drift apart and the whole effect reads as a texture sliding over
	# the picture. Same numbers, different consumer.
	beam_aim = Vector2(_tilt.y, _tilt.x)


func key(action: String, typed := "") -> void:
	if phone:
		phone.key(action, typed)
