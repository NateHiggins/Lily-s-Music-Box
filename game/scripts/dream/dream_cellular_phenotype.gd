class_name DreamCellularPhenotype
extends RefCounted
## Deterministic visual profiles. Values describe presentation, never ecology.

enum Kind { PIONEER, MOSS, TENDING, TACTILE, CHEMICAL, THERMAL, VIBRATIONAL,
		OPTICAL, ELECTRICAL, FOLD_CRAB, CRYSTAL_LISTENER, OCULAR, STAIN }

const PROFILES := {
	Kind.PIONEER: Vector4(0.18, 0.82, 0.12, 0.74),
	Kind.MOSS: Vector4(0.78, 0.48, 0.88, 0.42),
	Kind.TENDING: Vector4(0.62, 0.32, 0.72, 0.55),
	Kind.TACTILE: Vector4(0.55, 0.60, 0.46, 0.52),
	Kind.CHEMICAL: Vector4(0.42, 0.88, 0.66, 0.62),
	Kind.THERMAL: Vector4(0.70, 0.34, 0.38, 0.76),
	Kind.VIBRATIONAL: Vector4(0.84, 0.22, 0.52, 0.48),
	Kind.OPTICAL: Vector4(0.66, 0.38, 0.92, 0.40),
	Kind.ELECTRICAL: Vector4(0.72, 0.28, 0.78, 0.46),
	Kind.FOLD_CRAB: Vector4(0.82, 0.42, 0.58, 0.32),
	Kind.CRYSTAL_LISTENER: Vector4(0.74, 0.18, 0.64, 0.70),
	Kind.OCULAR: Vector4(0.58, 0.36, 0.86, 0.56),
	Kind.STAIN: Vector4(0.90, 0.08, 0.18, 0.24),
}


static func profile(kind: int, stable_seed: int) -> Dictionary:
	var base: Vector4 = PROFILES.get(kind, PROFILES[Kind.MOSS])
	var rng := RandomNumberGenerator.new()
	rng.seed = stable_seed
	return {
		"kind": clampi(kind, 0, Kind.size() - 1),
		"seed": stable_seed,
		"organization": clampf(base.x + rng.randf_range(-0.035, 0.035), 0.0, 1.0),
		"windows": clampf(base.y + rng.randf_range(-0.025, 0.025), 0.0, 1.0),
		"proteins": clampf(base.z + rng.randf_range(-0.035, 0.035), 0.0, 1.0),
		"refractive": clampf(base.w + rng.randf_range(-0.025, 0.025), 0.0, 1.0),
	}
