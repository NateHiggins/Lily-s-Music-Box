class_name DreamContactProfile
extends Resource
## How a touch converts matter (DREAM_TENTACLE_DIRECTION §14–15): the Dream
## does not ruin matter, it reveals a more extravagant state it could
## occupy. Read by DreamSurfaceTransformer; the living field carries the
## mask and the layered surface draws the state.

## Strength written into the field per deposit (body / trail / stain).
@export_range(0.0, 1.0) var deposit := 0.6
@export var deposit_every_s := 0.35
## Radius of the touch beyond direct contact, metres.
@export var spread_m := 0.18
## After the limb leaves: 0 recedes over minutes, 1 remains, >1 keeps crawling
## (agents born at the touch).
@export_range(0.0, 2.0) var persistence := 1.0
## The lacquer look's amounts on the surface (orison_surface `living_lux`).
@export_range(0.0, 1.0) var lacquer := 1.0
@export_range(0.0, 1.0) var gold_veins := 0.8
@export_range(0.0, 1.0) var ornament := 0.6
@export_range(0.0, 1.0) var luminance := 0.5
