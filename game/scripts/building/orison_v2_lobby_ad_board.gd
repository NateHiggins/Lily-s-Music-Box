extends "res://scripts/props/lobby_orison_ad_board.gd"
## V2 presentation of the original Orison broadside. V1 keeps the inspection
## owner and card, the boss that answers a reading, and the slow life of the
## loose corner and the pull chain. Here the frame, backing, sheet, ink,
## slips, bosses, chain, ledge and debris are Blender stock on catalogue
## finishes; the broadside's words are authored Label3D in the advert's own
## layout and its engraving is ruled ink geometry. The title render that V1
## sampled is not used as a surface (RUL-008).
const Native := preload("res://scripts/building/orison_v2_native_lobby_set.gd")

var native: RefCounted
## The "advert" block of res://data/orison_v2/lobby_set_placements.json.
var plan: Dictionary = {}
var lettering: Dictionary = {}


func _build_board() -> void:
	if native == null or plan.is_empty():
		push_error("V2 Orison broadside: native stock or plan not supplied")
		return
	native.mount_static(self, "Advert")
	# The loose corner turns about its crease: V1 drives the flap's rotation.x,
	# so the flap hangs from a pivot laid along the crease.
	var crease := Node3D.new()
	crease.name = "LooseCornerCrease"
	crease.transform = native.pose("Advert__LooseCorner_ON_paper")
	add_child(crease)
	_loose_corner = native.draw("Advert__LooseCorner_ON_paper")
	_loose_corner.name = "LoosePaperCorner"
	_loose_corner.transform = Transform3D.IDENTITY
	crease.add_child(_loose_corner)
	_chain = native.draw("Advert__Chain_ON_brass")
	_chain.name = "DisobedientPullChain"
	add_child(_chain)
	_inspection_boss = native.draw("Advert__InspectionBoss_ON_brass")
	_inspection_boss.name = "InspectionBoss"
	add_child(_inspection_boss)
	_inspection_boss_rest_z = _inspection_boss.position.z
	for row: Dictionary in plan.lettering:
		var lines: Array = row.lines
		var words := "\n".join(PackedStringArray(lines))
		if " ".join(PackedStringArray(lines)) != str(row.text):
			push_error("V2 Orison broadside: line breaks change the wording of " + str(row.name))
			continue
		var size := Native.fit(words, str(row.font), int(row.font_size), float(row.fit_width))
		var text := Native.lettering(words, str(row.font), int(row.font_size), size,
				Color(float(row.ink[0]), float(row.ink[1]), float(row.ink[2])),
				Vector3(float(row.at[0]), float(row.at[1]), float(plan.lettering_z)))
		text.name = str(row.name)
		text.line_spacing = float(row.get("line_spacing_px", 0.0))
		text.visibility_range_end = float(plan.label_range)
		text.set_meta("advert_words", str(row.text))
		add_child(text)
		lettering[str(row.name)] = text
