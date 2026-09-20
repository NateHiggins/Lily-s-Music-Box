extends "res://scripts/props/domestic_radio_prop.gd"
## V2 presentation over the existing household receiver's controls, event
## gating and audio lifetime. The source radio family remains authoritative.

func _build_visual() -> void:
	super._build_visual()
	var speaker := str(radio_profile.get("speaker", "cone"))
	# The legacy speaker cones floated above their supporting surface. Give
	# these separate speakers a foot and short pedestal on the radio table.
	if speaker.contains("cone"):
		make_box(Vector3(.18,.028,.13), Vector3(-.38,.014,0), DARK_WOOD)
		make_box(Vector3(.035,.10,.035), Vector3(-.38,.064,0), BRASS)
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

func interact_prompt() -> String:
	if family == "crystal_set":
		var resident := str(radio_profile.get("resident", unit)).split(" ")[0]
		return "Stop listening" if powered else "Listen through %s's headphones" % resident
	return super.interact_prompt()

func public_state() -> Dictionary:
	var result := super.public_state()
	if family == "crystal_set": result.reach = 1.6
	return result

func service_wire_card() -> Dictionary:
	var resident := str(radio_profile.get("resident", unit)).split(" ")[0]
	var title := "Your wireless" if resident == "Player" else "%s's wireless" % resident
	var body := "Wireless switched off."
	if family == "crystal_set":
		body = "Listening through the headphones." if powered else "Headphones set down."
	elif powered:
		body = "The wireless is playing."
	return {"title":title,"body":body,"condition":"PLAYING" if powered else "SILENT","stamp":"WIRELESS"}
