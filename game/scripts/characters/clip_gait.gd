class_name ClipGait
extends RefCounted
## Distance matching for in-place locomotion clips (NPC repair pilot, order w3473eaaf58a9).
##
## A walking clip is authored in place: the planted foot travels backward under the body while the route moves the
## body forward. The foot only stays put on the ground if the clip plays at the rate whose planted-foot speed equals
## the body's speed at that moment. A single speed scale cannot do that, because generated clips do not move the
## planted foot at an even speed (Mina's walk: 0.61-0.89 m/s between quartiles at 1x). So the gait is measured once
## per body and clip: the lower toe's backward speed through the cycle, smoothed, as a table. Each frame the player's
## speed scale is set so that the clip covers ground at the body's speed at its current point in the cycle.
##
## Measured on the body, after the clip library has re-based the clip to it, so a longer-legged body gets its own
## longer stride. Read-only on the player: it seeks to measure and restores nothing, so measure before the first
## play. Cached by body id and clip.

const RATE := 60.0
## The window over which the planted foot's speed is averaged: about a third of a step.
const SMOOTH_SECONDS := 0.18
## Playback bounds. Outside them the clip would look sped up or frozen; the foot slides there instead. The top is
## set by Mina's stair clips, generated slow: at 3x the climb is about 1.8 steps a second, a person's cadence.
const MIN_SCALE := 0.5
const MAX_SCALE := 3.0
## On stairs the long-legged (male base) shared walk may slow to a third, so its planted foot keeps up with the
## stair pace (Lily's ruling npc_male_stair_slide_20261125). Its steps read slower and heavier there; level walking
## keeps MIN_SCALE.
const STAIR_MIN_SCALE := 1.0 / 3.0

static var _cache := {}

var clip := ""
var length := 0.0
var cycle_metres := 0.0
var _rates := PackedFloat32Array()


## Measures `clip` on `skeleton` through `player`. Returns null when the clip does not travel (less than 5 cm a
## cycle), so idles and turns keep the plain speed scale.
static func measure(player: AnimationPlayer, skeleton: Skeleton3D, clip_name: String, body_id: String) -> ClipGait:
	var key := "%s/%s" % [body_id, clip_name]
	if _cache.has(key):
		return _cache[key]
	var gait: ClipGait = null
	if player != null and skeleton != null and player.has_animation(clip_name):
		gait = ClipGait.new()
		if not gait._measure(player, skeleton, clip_name):
			gait = null
	_cache[key] = gait
	return gait


static func clear_cache() -> void:
	_cache.clear()


func _measure(player: AnimationPlayer, skeleton: Skeleton3D, clip_name: String) -> bool:
	var left := skeleton.find_bone("LeftToeBase")
	var right := skeleton.find_bone("RightToeBase")
	if left == -1 or right == -1:
		return false
	clip = clip_name
	length = player.get_animation(clip_name).length
	var count := maxi(int(round(length * RATE)), 8)
	var was := player.current_animation
	var was_speed := player.speed_scale
	player.play(clip_name)
	# Per sample: the forward position of each toe (model +Z is forward).
	var lz := PackedFloat32Array()
	var rz := PackedFloat32Array()
	for i in count + 1:
		player.seek(length * i / count, true)
		skeleton.force_update_all_bone_transforms()
		lz.append(skeleton.get_bone_global_pose(left).origin.z)
		rz.append(skeleton.get_bone_global_pose(right).origin.z)
	if not was.is_empty():
		player.play(was)
	player.speed_scale = was_speed
	# The planted foot is the one travelling backward under the body (the swing foot comes forward). Its speed is
	# the ground speed. Height does not tell them apart: going downstairs the swing foot is the lower one.
	var raw := PackedFloat32Array()
	raw.resize(count)
	for i in count:
		var back := -minf(lz[i + 1] - lz[i], rz[i + 1] - rz[i]) * count / length
		raw[i] = maxf(back, 0.0)
	var travelled := 0.0
	for v in raw:
		travelled += v * length / count
	cycle_metres = travelled
	if cycle_metres < 0.05:
		return false
	# Circular moving average.
	var half := maxi(int(round(SMOOTH_SECONDS * RATE * 0.5)), 1)
	_rates.resize(count)
	for i in count:
		var sum := 0.0
		for k in range(-half, half + 1):
			sum += raw[posmod(i + k, count)]
		_rates[i] = sum / (2 * half + 1)
	# Floor: a stalled stretch would ask for an endless speed-up; give it the cycle mean's fifth instead.
	var mean := cycle_metres / length
	for i in count:
		_rates[i] = maxf(_rates[i], mean * 0.2)
	return true


## The clip's own ground speed (m/s at 1x) at time `t` in the cycle.
func rate_at(t: float) -> float:
	if _rates.is_empty() or length <= 0.0:
		return 0.0
	var x := fposmod(t, length) / length * _rates.size()
	var i := int(x) % _rates.size()
	var j := (i + 1) % _rates.size()
	return lerpf(_rates[i], _rates[j], x - floorf(x))


## The mean ground speed of the clip at 1x.
func mean_rate() -> float:
	return cycle_metres / length if length > 0.0 else 0.0


## The speed scale at which the clip, now at `t`, covers ground at `metres_per_second`.
func scale_for(t: float, metres_per_second: float, min_scale: float = MIN_SCALE) -> float:
	var rate := rate_at(t)
	if rate <= 0.0:
		return 1.0
	return clampf(metres_per_second / rate, min_scale, MAX_SCALE)
