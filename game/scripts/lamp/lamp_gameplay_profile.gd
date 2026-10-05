extends RefCounted
## Shared useful output for the service lamp. Electrical transients and the
## optical field multiply/observe this value; they do not own another light.
## Matched settled-output renders preserve close wall detail at this rating
## while still revealing the dark roof and basement with room fixtures off.
const BASE_ENERGY := 4.2
const WAKING_RANGE := 16.0
const WAKING_ATTENUATION := .5
## A work-light reflector covers nearby controls despite the carried lens's
## below-right offset. The optical observation reads the delivered cone.
const WAKING_CONE_SCALE := 1.45
## Near-field inspection and emissive Dream tissue need less incident energy
## than a dark basement. Both still inject their actual delivered light.
const DREAM_ENERGY := 8.4
const INSPECTION_ENERGY := 4.2
