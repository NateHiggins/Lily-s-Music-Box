extends "res://scripts/characters/orison_v2_resident_route.gd"
## V2 route ownership for Mina: the shared resident route owner with Mina's
## own animation behaviour (door gestures, tired idle) and her late hurry to
## the bodega before it shuts its night window.
const SOURCE := MINA_ROUTE

func _init() -> void:
	source_path = SOURCE
	resident = "mina_vale"

## Mina's file is Mina's: another resident cannot reuse its route.
static func valid_source_header(source: Variant) -> bool:
	return valid_route_header(source, "mina_vale")

func setup(root: Node3D) -> bool:
	return super.setup(root) and preload("res://scripts/characters/mina_idle_animation.gd").install(actor)

func _select_destination() -> void:
	super._select_destination()
	if actor and actor.mina_animation:
		var minute: float = world.campaign_clock.minute_of_day()
		actor.mina_animation.set_idle_context(minute < 360 or minute >= 1380)

func _speed() -> float:
	return 1.42 if destination == "bodega" and world.campaign_clock.minute_of_day() >= 1420 else 1.05
