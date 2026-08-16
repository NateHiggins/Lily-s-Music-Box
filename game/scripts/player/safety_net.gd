class_name SafetyNet
extends Node
## Catches the player when the world stops holding them.
##
## The building lies about itself in several supported ways — reality
## thresholds teleport you through paired doorways, room-local gravity
## points sideways, a poltergeist can move furniture out from under you —
## and any of them can drop a capsule out of the world. A horror game is
## allowed to terrify the player; it is not allowed to lose them.
##
## It no longer folds its own floors. Chaos mode did exactly that and is
## gone (2026-08-06): it moved wall and floor MESHES while their collision
## stayed put, so the net was catching a fall the building itself had
## caused, every time. Deleting the cause is better than catching it.
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

## Volumes that are legitimately outside the site: the prop warehouse
## is 400 m east BY DESIGN, and the net's rescue was silently undoing
## the debug teleport every time - the button worked, the arrival was
## cancelled within a frame, and from the panel it read as a dead
## button. Anything that builds real floor outside SITE_LIMIT registers
## itself here.
var exempt_zones: Array[AABB] = []
## Sampling the anchor every frame is wasted work; the player cannot get
## anywhere interesting in a fifth of a second.
const SAMPLE_INTERVAL := 0.2
## Kept at zero effect now that nothing distorts the building, but the
## quarantine machinery stays: reality thresholds and sideways gravity can
## still hand us a position that looks like solid floor and is not, and
## this is where that would be excluded from becoming an anchor.
const DISTORTION_QUARANTINE := 1.5

var player: CharacterBody3D
## Where to put someone back. Seeded with the lobby so the very first frames
## are covered too — falls during load are the ones with no anchor yet.
var anchor := Vector3(0.0, 0.2, 6.0)
var recoveries := 0
var enabled := true

var _accum := 0.0
var _quarantine := 0.0


func setup(body: CharacterBody3D) -> void:
	player = body
	# Run before everything else in the physics step. The net is added to the
	# tree after the player, so at default priority the player got a whole
	# frame with the broken position first — and a controller handed a
	# non-finite transform spends that frame trying to normalise NaN, which
	# floods the log and can take the run down with it. Catching the fall
	# before anyone reads the position is the only ordering that works.
	process_physics_priority = -100


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
	for zone in exempt_zones:
		if zone.has_point(p):
			return false
	return absf(p.x) > SITE_LIMIT or absf(p.z) > SITE_LIMIT


func _rescue(from: Vector3) -> void:
	# A rescue from a position the player was genuinely STANDING at is not a
	# fall — it is almost certainly a playable volume outside SITE_LIMIT that
	# never registered in exempt_zones. Left silent, that failure reads as a
	# dead teleport button (the prop warehouse found this the hard way; see
	# the comment on exempt_zones). Name the cause loudly instead.
	if player.is_on_floor() and from.y > FLOOR_OF_THE_WORLD \
			and is_finite(from.x) and is_finite(from.y) and is_finite(from.z):
		push_error("[SAFETY NET] rescued a player standing on real floor at "
				+ "%s - an off-site volume is probably missing from " % from
				+ "exempt_zones")
	player.velocity = Vector3.ZERO
	player.global_position = anchor
	recoveries += 1
	# Printed, not shown. Someone reading a log should be able to find out
	# that the world dropped a player and where; the player should not.
	print("[SAFETY NET] recovered from %s to %s (%d this session)"
			% [from, anchor, recoveries])
	recovered.emit(from, anchor)


## Was: "is the map being distorted right now, in which case do not
## count this fall". The building does not distort any more, so a fall is
## always a fall and the net always catches it.
func _distorting() -> bool:
	return false


## Test hook: prove the net catches without waiting for a real fall.
func drop_test() -> void:
	if player:
		player.global_position = Vector3(0.0, FLOOR_OF_THE_WORLD - 50.0, 0.0)
