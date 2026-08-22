class_name DreamBehaviorProfile
extends Resource
## Timings and zones for DreamTentacleBehavior (DREAM_TENTACLE_DIRECTION
## §12–§18). Data, so the encounter can be tuned without touching code.

@export var membrane_bulge_s := 2.2
@export var emerge_s := 3.4
@export var orient_s := 1.6
@export var hover_s := 2.4
@export var touch_s := 1.2
@export var caress_s := 14.0
@export var taste_s := 2.6
@export var rest_s := 2.0
@export var watch_player_s := 3.0
@export var flinch_s := 1.1
@export var resume_s := 1.4
@export var withdraw_s := 2.6
## Approach slows inside this distance; hover holds this far off.
@export var slow_radius_m := 0.10
@export var hover_off_m := 0.06
## Player zones (§18).
@export var zone_near_m := 2.6
@export var zone_reach_m := 1.1
@export var rush_speed_mps := 2.2
## Reach and body.
@export var reach_m := 1.45
@export var length_m := 1.6
## Tremor (§12): distal only, 5–7 Hz, low amplitude, while sampling.
@export var tremor_hz := 6.0
@export var tremor_m := 0.0035
