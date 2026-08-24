class_name DreamFaunaChannels
extends RefCounted
## FA-V1: the sole CPU owner of MultiMesh fauna channel packing.
##
## INSTANCE_CUSTOM is four float32 values. R remains a full phase value; the
## other three floats each carry two exact bytes as high * 256 + low. Shader
## decoding lives beside this contract in dream_fauna_style.gdshaderinc.
##
## MEASURED 2026-08-21 (FA-V4): on the Compatibility renderer the GPU never
## sees float32 here. GLES3 MeshStorage packs instance custom data as four
## half-floats and `Math::make_half_float` TRUNCATES the mantissa, so what
## the shader decodes is `compatibility_half()` of what was set. The HIGH
## byte of every pair survives exactly (a multiple of 256 is representable
## and truncation never crosses below it); the LOW byte is quantized to steps
## of 8–32 depending on the high byte. Phase keeps ~11 bits. Only
## presentation-side low bytes (emergence, activity, pattern_jitter) are
## affected; the CPU owner keeps full precision. DreamWalk's F key shows both.

const FLAG_HUSH := 1 << 0
const FLAG_SIGNALLING := 1 << 1
const FLAG_PEARL_COLONY := 1 << 2
const FLAG_CAMERA_TRACKER := 1 << 3
const FLAG_BIRTHING := 1 << 4
const FLAG_REABSORBING := 1 << 5
## Bit order is the readable order. FA-V4 inspection prints these; nothing
## in the shader or the director reads them.
##
## DO-1: bit 1 was COURTSHIP, which described two separate animals displaying
## to each other. It carries the same bit for the same instances; what it
## names now is the organelle function -- a ribbonette signalling across the
## body it belongs to.
const FLAG_NAMES := [
	[FLAG_HUSH, "HUSH"], [FLAG_SIGNALLING, "SIGNALLING"],
	[FLAG_PEARL_COLONY, "PEARL_COLONY"], [FLAG_CAMERA_TRACKER, "CAMERA_TRACKER"],
	[FLAG_BIRTHING, "BIRTHING"], [FLAG_REABSORBING, "REABSORBING"],
]

static func encode(identity_phase: float, allocation: float,
		emergence: float, flags: int, activity: float, hue_jitter: float,
		pattern_jitter: float) -> Color:
	return Color(identity_phase,
			pack_pair(_unit_byte(allocation), _unit_byte(emergence)),
			pack_pair(clampi(flags, 0, 255), _unit_byte(activity)),
			pack_pair(_unit_byte(hue_jitter), _unit_byte(pattern_jitter)))

static func decode(data: Color) -> Dictionary:
	var allocation_pair := unpack_pair(data.g)
	var activity_pair := unpack_pair(data.b)
	var genome_pair := unpack_pair(data.a)
	return {
		"identity_phase": data.r,
		"allocation": float(allocation_pair.x) / 255.0,
		"emergence": float(allocation_pair.y) / 255.0,
		"flags": activity_pair.x,
		"activity": float(activity_pair.y) / 255.0,
		"hue_jitter": float(genome_pair.x) / 255.0,
		"pattern_jitter": float(genome_pair.y) / 255.0,
	}

static func pack_pair(high_byte: int, low_byte: int) -> float:
	return float(clampi(high_byte, 0, 255) * 256 + clampi(low_byte, 0, 255))

static func unpack_pair(packed: float) -> Vector2i:
	var exact := clampi(int(round(packed)), 0, 65535)
	return Vector2i(exact / 256, exact % 256)

static func flag_names(flags: int) -> PackedStringArray:
	var names := PackedStringArray()
	for entry in FLAG_NAMES:
		if (flags & int(entry[0])) != 0:
			names.append(str(entry[1]))
	return names

## What a float32 becomes after the Compatibility renderer's half-float
## truncation (mantissa cut to 10 bits, toward zero). Normal range only; the
## packed channels never leave it.
static func compatibility_half(value: float) -> float:
	if value == 0.0 or is_nan(value) or is_inf(value):
		return value
	var magnitude := absf(value)
	var exponent := floorf(log(magnitude) / log(2.0))
	var spacing := pow(2.0, exponent - 10.0)
	return signf(value) * floorf(magnitude / spacing) * spacing

static func compatibility_half_color(data: Color) -> Color:
	return Color(compatibility_half(data.r), compatibility_half(data.g),
			compatibility_half(data.b), compatibility_half(data.a))

static func has_flag(data: Color, flag: int) -> bool:
	return (int(decode(data).flags) & flag) != 0

static func _unit_byte(value: float) -> int:
	return clampi(int(round(clampf(value, 0.0, 1.0) * 255.0)), 0, 255)
