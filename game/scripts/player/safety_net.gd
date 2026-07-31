class_name SafetyNet
extends Node
## Catches the player when the world stops holding them.
##
## The building deliberately lies about its own geometry — chaos mode folds
## the floor you are standing on, reality thresholds teleport you through
## paired doorways, room-local gravity points sideways, and a poltergeist can
## be moving furniture out from under you. Every one of those is a supported
## state, and any of them can drop a capsule out of the world. A horror game
## is allowed to terrify the player; it is not allowed to lose them.
##
## So this watches, silently, and does the least dramatic thing that works:
## it remembers the last place the player was genuinely standing on real
## floor, and puts them back there if they leave the world. No message, no
## fade, no score. If the player never falls they will never know it exists,
## which is the point — a visible safety net is an admission that the floor
## cannot be trusted, and the floor not being trustworthy is the horror.

signal recovered(from_position: Vector3, to_position: Vector3)

## How far below the basement slab counts as "no longer in the building".
## B1 sits at -2.8, so this is roughly two storeys of empty air below the
## lowest thing anyone can legitimately stand on.
const FLOOR_OF_THE_WORLD := -12.0
## The site is ±112 x ±82 m of road. Past this you are not falling off the
## building, you are somewhere the level does not exist at all.
const SITE_LIMIT := 240.0
## Sampling the anchor every frame is wasted work; the player cannot get
## anywhere interesting in a fifth of a second.
const SAMPLE_INTERVAL := 0.2
## Never trust an anchor recorded during a distortion — the whole point of
## chaos mode is that the floor you are standing on is not where it looks.
## A short quarantine after any distortion clears keeps a folded-floor
## position from becoming the place we rescue people to.
const DISTORTION_QUARANTINE := 1.5

var player: CharacterBody3D
## Where to put someone back. Seeded with the lobby so the very first frames
## are covered too — falls during load are the ones with no anchor yet.
var anchor := Vector3(0.0, 0.2, 6.0)
var recoveries := 0
var enabled := true

var _accum := 0.0
var _quarantine := 0.0
var _distortion: Node = null


func setup(body: CharacterBody3D, distortion_lab: Node = null) -> void:
	player = body
	_distortion = distortion_lab


func _physics_process(delta: float) -> void:
	if not enabled or player == null:
		return
	if _distorting():
		_quarantine = DISTORTION_QUARANTINE
	else:
		_quarantine = maxf(0.0, _quarantine - delta)
	var here := player.global_position
	if _lost(here):
		_rescue(here)
		return
	_accum += delta
	if _accum < SAMPLE_INTERVAL:
		return
	_accum = 0.0
	# Only somewhere you are actually standing, upright, and still becomes an
	# anchor. Mid-air, mid-fall and mid-distortion positions are exactly the
	# ones that would rescue a player back into the hole they just fell down.
	if _quarantine <= 0.0 and player.is_on_floor() \
			and absf(player.velocity.y) < 1.0 and here.y > FLOOR_OF_THE_WORLD:
		anchor = here


## Non-finite first: a NaN position fails every comparison silently, so a
## player whose transform has been corrupted would otherwise fall forever
## while all the range checks politely returned false.
func _lost(p: Vector3) -> bool:
	if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
		return true
	if p.y < FLOOR_OF_THE_WORLD:
		return true
	return absf(p.x) > SITE_LIMIT or absf(p.z) > SITE_LIMIT


func _rescue(from: Vector3) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = anchor
	recoveries += 1
	# Printed, not shown. Someone reading a log should be able to find out
	# that the world dropped a player and where; the player should not.
	print("[SAFETY NET] recovered from %s to %s (%d this session)"
			% [from, anchor, recoveries])
	recovered.emit(from, anchor)


func _distorting() -> bool:
	if _distortion == null:
		return false
	if "chaos_enabled" in _distortion and _distortion.chaos_enabled:
		return true
	return "mode" in _distortion and str(_distortion.mode) != "none"


## Test hook: prove the net catches without waiting for a real fall.
func drop_test() -> void:
	if player:
		player.global_position = Vector3(0.0, FLOOR_OF_THE_WORLD - 50.0, 0.0)
