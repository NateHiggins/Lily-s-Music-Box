extends "res://scripts/props/domestic_radio_prop.gd"
## V2 presentation over the existing household receiver's controls, event
## gating and audio lifetime. The source radio family remains authoritative.
## A switched-on set joins the house broadcast (OrisonV2Broadcast) at its live
## position instead of the old programme murmur.
const Broadcast := preload("res://scripts/audio/orison_v2_broadcast.gd")
const BROADCAST_DB := -18.0
var native_visuals: RefCounted

func _build_visual() -> void:
	super._build_visual()
	var speaker := str(radio_profile.get("speaker", "cone"))
	# The legacy horn floated above its supporting surface: give it a foot and a
	# short pedestal. The cone speaker now carries its own japanned foot and rear
	# strut (dossier slice 42), so it takes no second stand here.
	if speaker.contains("horn"):
		make_box(Vector3(.18,.028,.15), Vector3(.37,.014,0), DARK_WOOD)
		make_box(Vector3(.035,.12,.035), Vector3(.37,.074,0), BRASS)
	retexture(self, [
		[WOOD, "wood_dark", Color.WHITE],
		[DARK_WOOD, "wood_dark", Color(.55,.55,.55)],
		[BLACK, "bakelite_black", Color.WHITE],
		[BRASS, "brass", Color.WHITE],
		[CLOTH, "linen", Color.WHITE],
		[PAPER, "paper", Color.WHITE],
		[Color(.085,.09,.09), "cast_iron", Color.WHITE],
		[Color(.36,.22,.10), "wood_dark", Color.WHITE],
		[Color(.085,.055,.035), "linen", Color(.24,.16,.10)]])
	if family == "atwater_kent_44":
		# This family's first mesh is its pressed-metal chassis, while its
		# knobs share the legacy black palette. Preserve that distinction.
		var chassis := get_child(0) as MeshInstance3D
		chassis.material_override = MatLib.get_mat("enamel_appliance", Color(.14,.15,.15))

	if family == "crystal_set":
		var base := get_child(0) as MeshInstance3D
		base.material_override = MatLib.get_mat("oak_quartered")
		# The passive set is heard at its headphones, without a room speaker.
		_programme.max_distance = 1.6
		_programme.unit_size = .35
	if native_visuals == null:
		native_visuals = preload("res://scripts/building/orison_v2_native_active_radios.gd").new()
		if not native_visuals.prepare():
			push_error("V2 receiver stock refused: " + unit); return
	if not native_visuals.mount_on(self):
		push_error("V2 receiver native visual mount refused: " + unit)

func interact(actor: Node = null) -> Dictionary:
	var result := super.interact(actor)
	if powered:
		Broadcast.join(_programme, BROADCAST_DB)
	else:
		Broadcast.leave(_programme)
	_tune_storm(powered)
	result.on_air = Broadcast.on_air(_programme)
	return result

func _perform_synced_event(index: int, accent: float, pitch: float) -> void:
	super._perform_synced_event(index, accent, pitch)
	# The tuning knob may drift with the house; a record is never pitched by it.
	if _programme != null and _programme.has_meta("broadcast_record"):
		_programme.pitch_scale = 1.0

func _exit_tree() -> void:
	Broadcast.restore_carrier(_programme)
	super._exit_tree()

func interact_prompt() -> String:
	if family == "crystal_set":
		var resident := str(radio_profile.get("resident", unit)).split(" ")[0]
		return "Stop listening" if powered else "Listen through %s's headphones" % resident
	return super.interact_prompt()

func public_state() -> Dictionary:
	var result := super.public_state()
	if family == "crystal_set": result.reach = 1.6
	result.on_air = Broadcast.on_air(_programme)
	return result

func service_wire_card() -> Dictionary:
	var resident := str(radio_profile.get("resident", unit)).split(" ")[0]
	var title := "Your wireless" if resident == "Player" else "%s's wireless" % resident
	var body := "Wireless switched off."
	if family == "crystal_set":
		body = "Listening through the headphones." if powered else "Headphones set down."
	elif powered:
		var record := Broadcast.on_air(_programme)
		body = "The wireless is playing %s." % record if not record.is_empty() else "The wireless is playing."
	return {"title":title,"body":body,"condition":"PLAYING" if powered else "SILENT","stamp":"WIRELESS"}


## On the aurora nights a switched-on set picks up the storm (Lily's sun_storms
## ruling, 2026-11-04; v1r_geomagnetic_static_20261109). The static is heard at
## the set, on its programme's bus, and goes when the set is switched off.
func _tune_storm(on: bool) -> void:
	var storm := get_node_or_null("GeomagneticStatic")
	if on and storm == null and _programme != null:
		storm = preload("res://scripts/audio/geomagnetic_static.gd").new()
		storm.name = "GeomagneticStatic"
		storm.bus_name = _programme.bus
		storm.max_distance = _programme.max_distance
		_programme.add_sibling(storm)
		storm.position = _programme.position
	elif not on and storm != null:
		storm.queue_free()
