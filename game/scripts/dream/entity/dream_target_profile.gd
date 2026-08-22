class_name DreamTargetProfile
extends Resource
## What an interesting object tells the Dream about touching it
## (DREAM_TENTACLE_DIRECTION §13): where to make contact, what edge to
## trace, how strongly it answers, whether it may be transformed.

## Preferred first contact, in the object's local space.
@export var contact_local := Vector3(0.0, 0.5, 0.0)
## The edge to trace: a local axis and a half-length either side of the
## contact; zero length means hover-and-figure-eight only.
@export var trace_axis_local := Vector3.RIGHT
@export var trace_half_length := 0.3
## The surface normal at the contact, local (the tip approaches along it).
@export var contact_normal_local := Vector3.UP
## How much the object answers (light, sound hooks, conversion spread).
@export_range(0.0, 2.0) var response_strength := 1.0
## May the Dream's conversion spread on it.
@export var transformation_eligible := true
## A word for the material, for the contact profile to read.
@export var material_word := "iron"
