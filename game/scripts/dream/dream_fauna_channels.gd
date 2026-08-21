class_name DreamFaunaChannels
extends RefCounted
## FA-V1: the sole CPU owner of MultiMesh fauna channel packing.
##
## INSTANCE_CUSTOM is four float32 values. R remains a full phase value; the
## other three floats each carry two exact bytes as high * 256 + low. Shader
## decoding lives beside this contract in dream_fauna_style.gdshaderinc.

const FLAG_HUSH := 1 << 0
const FLAG_COURTSHIP := 1 << 1
const FLAG_PEARL_COLONY := 1 << 2
const FLAG_CAMERA_TRACKER := 1 << 3
const FLAG_BIRTHING := 1 << 4
const FLAG_REABSORBING := 1 << 5

static func encode(identity_phase: float, nutrient: float, emergence: float,
		flags: int, activity: float, hue_jitter: float,
		pattern_jitter: float) -> Color:
	return Color(identity_phase,
			pack_pair(_unit_byte(nutrient), _unit_byte(emergence)),
			pack_pair(clampi(flags, 0, 255), _unit_byte(activity)),
			pack_pair(_unit_byte(hue_jitter), _unit_byte(pattern_jitter)))

static func decode(data: Color) -> Dictionary:
	var feed_pair := unpack_pair(data.g)
	var activity_pair := unpack_pair(data.b)
	var genome_pair := unpack_pair(data.a)
	return {
		"identity_phase": data.r,
		"nutrient": float(feed_pair.x) / 255.0,
		"emergence": float(feed_pair.y) / 255.0,
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

static func has_flag(data: Color, flag: int) -> bool:
	return (int(decode(data).flags) & flag) != 0

static func _unit_byte(value: float) -> int:
	return clampi(int(round(clampf(value, 0.0, 1.0) * 255.0)), 0, 255)
