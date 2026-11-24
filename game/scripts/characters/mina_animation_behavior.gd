class_name MinaAnimationBehavior
extends RefCounted
## Batch one uses only Mina's own Gray Resolve clips. Routes own translation;
## this owner chooses poses, playback type and transitions. No donor fallback.
const CLIPS := {
	"mina_idle_calm": true, "mina_walk": true, "mina_walk_hurried": true,
	"mina_turn_around": false, "mina_stairs_up": true, "mina_stairs_down": true,
	"mina_door_push_open": false, "mina_door_pull_open": false,
	"mina_talk_measured": true, "mina_strained": false, "mina_recognition": false,
	"mina_quiet_thanks": false, "mina_walk_start": false, "mina_walk_stop": false,
	"mina_door_close": false, "mina_door_lock": false, "mina_lift_wait": true,
	"mina_idle_tired": true, "mina_run_builtin": true, "mina_walk_builtin": true,
}
const ROLES := {
	"idle": "mina_idle_calm", "tired": "mina_idle_tired", "walk": "mina_walk",
	"hurried": "mina_walk_hurried", "stairs_up": "mina_stairs_up", "stairs_down": "mina_stairs_down",
	"talk": "mina_talk_measured", "strained": "mina_strained", "recognition": "mina_recognition",
	"quiet_thanks": "mina_quiet_thanks", "wait": "mina_lift_wait", "turn": "mina_turn_around",
	"push": "mina_door_push_open", "pull": "mina_door_pull_open",
	"close": "mina_door_close", "lock": "mina_door_lock",
}
var player: AnimationPlayer
var moving := false
var conversation_active := false
var route_busy := false
var idle_role := "idle"
var motion_role := "walk"
var motion_speed := 1.0
var _one_shot := ""
var _elapsed := 0.0
var _duration := 0.0
## Distance matching (ClipGait), measured on the body at install: travelling clips play at the rate whose planted
## foot keeps pace with the route, frame by frame. Empty for a body without a skeleton handed in (the old shell).
const TRAVELLING := ["mina_walk", "mina_walk_hurried", "mina_stairs_up", "mina_stairs_down", "mina_walk_start"]
var gaits := {}
var ground_speed := 0.0

static func configure(animation_player: AnimationPlayer) -> bool:
	if animation_player == null: return false
	for clip: String in CLIPS:
		if not animation_player.has_animation(clip): return false
		animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if CLIPS[clip] else Animation.LOOP_NONE
	return true

func install(animation_player: AnimationPlayer, skeleton: Skeleton3D = null, body_id := "") -> bool:
	if not configure(animation_player): return false
	player = animation_player
	if skeleton != null:
		for clip: String in TRAVELLING:
			var gait := ClipGait.measure(player, skeleton, clip, body_id)
			if gait != null: gaits[clip] = gait
	_play(ROLES.idle)
	return true

func update(delta: float) -> void:
	_match_ground()
	if _one_shot.is_empty(): return
	# Clip time, not wall time: a distance-matched one-shot (the walk start) plays faster or slower than 1x.
	_elapsed += delta * player.speed_scale
	if _elapsed < _duration: return
	_one_shot = ""
	route_busy = false
	_resume()

func set_motion(on: bool, slope := 0.0, metres_per_second := 1.05) -> void:
	motion_role = "stairs_up" if slope > .08 else "stairs_down" if slope < -.08 else "hurried" if metres_per_second > 1.35 else "walk"
	# Four generated walking steps travel 3.49 m over 3.97 s in the source.
	# The route supplies real speed; stair timing follows the installed ramps.
	var source_speed := .91 if motion_role == "hurried" else .88
	motion_speed = clampf(metres_per_second / source_speed, .65, 1.8) if motion_role in ["walk", "hurried"] else 1.0
	ground_speed = metres_per_second if on else 0.0
	var gait: ClipGait = gaits.get(ROLES[motion_role])
	if gait != null:
		motion_speed = clampf(metres_per_second / gait.mean_rate(), ClipGait.MIN_SCALE, ClipGait.MAX_SCALE)
	var changed := moving != on
	moving = on
	if conversation_active or route_busy: return
	if changed and not on and gaits.has("mina_walk"):
		# The stop clip walks on for 3.7 s, but the route has already stopped the body: on a measured body its
		# feet would slide the whole time. Settle straight into the idle instead.
		_one_shot = ""
		_resume()
	elif changed:
		_once("mina_walk_start" if on else "mina_walk_stop")
	elif _one_shot.is_empty():
		_resume()

func set_idle_context(tired: bool) -> void:
	idle_role = "tired" if tired else "idle"
	if not moving and not conversation_active and _one_shot.is_empty(): _resume()

func speak(role: String) -> bool:
	if role == "idle":
		conversation_active = false
		_one_shot = ""
		route_busy = false
		_resume()
		return true
	var clip: String = ROLES.get(role, "")
	if clip.is_empty(): return false
	conversation_active = true
	route_busy = false
	if CLIPS[clip]:
		_one_shot = ""
		_play(clip)
	else:
		_once(clip)
	return true

func route_action(role: String) -> bool:
	if conversation_active or route_busy: return false
	var clip: String = ROLES.get(role, "")
	if clip.is_empty() or CLIPS[clip]: return false
	route_busy = true
	_once(clip)
	return true

func finish_conversation(thanks: bool) -> void:
	conversation_active = false
	moving = false
	route_busy = thanks
	_one_shot = ""
	if thanks: _once("mina_quiet_thanks")
	else: _resume()

func action_contact_ready() -> bool:
	return route_busy and _one_shot.begins_with("mina_door_") and _elapsed >= _duration * .22

func cancel_route_action() -> void:
	if not route_busy: return
	route_busy = false
	_one_shot = ""
	_resume()

func _once(clip: String) -> void:
	_one_shot = clip
	_elapsed = 0.0
	_duration = player.get_animation(clip).length
	_play(clip)

## While she travels in a measured clip, hold its planted foot to the ground: the speed scale follows the clip's
## own ground speed at its current point in the cycle.
func _match_ground() -> void:
	if not moving or ground_speed <= 0.0 or conversation_active or player == null:
		return
	if not _one_shot.is_empty() and not gaits.has(_one_shot):
		return
	var gait: ClipGait = gaits.get(str(player.current_animation))
	if gait != null:
		player.speed_scale = gait.scale_for(player.current_animation_position, ground_speed)

func _resume() -> void:
	if conversation_active:
		_play(ROLES.talk)
	elif moving:
		_play(ROLES[motion_role], motion_speed)
	else:
		_play(ROLES[idle_role])

func _play(clip: String, speed := 1.0) -> void:
	if player.current_animation == clip and player.is_playing():
		# A travelling clip already under way keeps its distance-matched rate; the route calls in every frame.
		var gait: ClipGait = gaits.get(clip)
		if gait != null and moving and ground_speed > 0.0 and not conversation_active:
			speed = gait.scale_for(player.current_animation_position, ground_speed)
		player.speed_scale = speed
		return
	player.speed_scale = speed
	player.play(clip, .22)
