class_name CampaignPace
extends RefCounted
## How fast campaign time runs. Ordinarily a second is a second. When someone
## with standing to say so reports that nothing can be done until a known
## moment, time runs faster toward that moment and comes back to its ordinary
## rate a few seconds short of it, so nobody waits out an hour of real time
## and nothing awaited is run past.
##
## It decides nothing by itself. The owner of a wait (the temporal loop) asks
## with run_to() and takes the request back with settle(). Anything that needs
## time to be ordinary for a while (a conversation, a call) takes a hold. The
## clock driver, the one writer of campaign time, asks seconds_for() each
## frame.

## No request may run the clock faster than this, whatever its data says.
const MAX_RATE := 240.0

## Campaign seconds per real second, now.
var rate := 1.0
## Who asked for the present run, and for what; empty when time is ordinary.
var reason := ""
var _goal := INF
var _top := 1.0
var _landing := 3.0
var _ramp := 2.0
var _holds: Dictionary = {}


## Run toward `elapsed_minute` (the player's own elapsed minutes) at up to
## `top_rate`, arriving at the ordinary rate. Asking again with the same
## reason only moves the goal.
func run_to(elapsed_minute: float, top_rate: float, why: String, landing_seconds := 3.0, ramp_seconds := 2.0) -> bool:
	if not is_finite(elapsed_minute) or not is_finite(top_rate) or top_rate <= 1.0 or why.is_empty():
		return false
	_goal = elapsed_minute
	_top = minf(top_rate, MAX_RATE)
	_landing = maxf(landing_seconds, 0.25)
	_ramp = maxf(ramp_seconds, 0.05)
	reason = why
	return true


## Back to the ordinary rate, at once.
func settle() -> void:
	_goal = INF
	_top = 1.0
	rate = 1.0
	reason = ""


func hold(token: String) -> void:
	_holds[token] = true
	rate = 1.0


func release(token: String) -> void:
	_holds.erase(token)


func held() -> bool:
	return not _holds.is_empty()


func running() -> bool:
	return _goal < INF and _holds.is_empty()


## The elapsed minute being run toward, or INF.
func goal() -> float:
	return _goal


## Campaign seconds to add for a frame of `delta` real seconds, given the
## player's elapsed minutes now. Never less than `delta`, never past the goal
## by more than an ordinary frame.
func seconds_for(delta: float, elapsed_now: float) -> float:
	if delta <= 0.0 or not is_finite(delta):
		return 0.0
	if _goal == INF or not _holds.is_empty():
		rate = 1.0
		return delta
	var remaining := (_goal - elapsed_now) * 60.0
	if remaining <= delta:
		settle()
		return delta
	var ceiling := clampf(remaining / _landing, 1.0, _top)
	rate = clampf(rate + (_top - 1.0) * delta / _ramp, 1.0, ceiling)
	return minf(delta * rate, remaining)
