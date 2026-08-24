class_name DreamSurfaceTransformer
extends RefCounted
## Dream Contact / Material Conversion (DREAM_TENTACLE_DIRECTION §14–15):
## where the limb touches, the creature attempts electrochemical/secretory
## communication across a synapse-like cleft. Ordinary matter cannot answer
## in its language and is instead invited into the Dream. The
## mask lives in the living field (body / trail / stain at the touch,
## attributed to the source) and every layered surface reads it: the
## `living_lux` state of `orison_surface` draws the touched matter as
## violet lacquer veined with gold, softly luminous, breathing, ornamented
## — re-authored, not slimed. Persistence is the contact profile's: the
## organism born at the touch keeps crawling, or the stain recedes.

var profile: DreamContactProfile
var field = null
var source_index := 0
var deposits := 0
var _clock := 0.0
var last_event := ""


func configure(living_field, src: int, p: DreamContactProfile) -> void:
	field = living_field
	source_index = src
	profile = p if p != null else DreamContactProfile.new()


## Called while the limb holds a surface; secretion transfer deposits on the
## profile's cadence. LivingField remains the sole downstream material owner.
func touch(contact: Vector3, contact_normal: Vector3, strength: float, delta: float) -> bool:
	last_event = ""
	if field == null or strength <= 0.05:
		return false
	_clock += delta
	if _clock < profile.deposit_every_s:
		return false
	_clock = 0.0
	var amount := profile.deposit * clampf(strength, 0.0, 1.0)
	field.deposit(contact + contact_normal * 0.08, source_index, amount)
	# The spread beyond direct contact: a ring of lighter deposits.
	var any := Vector3.UP if absf(contact_normal.y) < 0.9 else Vector3.RIGHT
	var ta := any.cross(contact_normal).normalized()
	var tb := contact_normal.cross(ta).normalized()
	for k in 4:
		var ang := float(k) * TAU / 4.0 + _clock
		var off := (ta * cos(ang) + tb * sin(ang)) * profile.spread_m
		field.deposit(contact + off + contact_normal * 0.08, source_index, amount * 0.45)
	deposits += 1
	last_event = "dream_conversion"
	return true
