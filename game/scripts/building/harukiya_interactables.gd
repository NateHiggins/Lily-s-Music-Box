class_name HarukiyaInteractables
extends Node3D
## The bar's hands-on layer (brief #52 P6): Inspectables on the pictures,
## the barrels and the pool table, and seat sockets on the four couch
## modules. Coordinates are the same Blender-space numbers gen_layout
## authors the geometry from (b2g at spawn), so a regenerated bar moves
## these with it or fails visibly in the room, not silently in data.

const FLR := -2.80              # bar floor, Blender z


func build(root: Node3D) -> int:
	var count := 0
	# -- three of the gallery wall's frames, on the north run above the
	# backbar. The rest of the wall is scatter; these are the ones worth
	# stopping at.
	#
	# RE-DATED 2026-08-16 (ledger amendment A0.5). These read 1948 and
	# 1962 -- stale copy from before the 1928 pinning, which had the bar
	# telling the player its history in the wrong century. They are NOT
	# the same case as the jukebox's 1999-2008 records: a signal arriving
	# from a year that has not happened is the Rule of Signal doing its
	# job (see WORS 1610, broadcasting 1962-1999 with the transmitter
	# never found), but a framed PHOTOGRAPH of it is just an error, and
	# promoting an error to canon is not the same as authoring one.
	# 1913 is the year after the Orison went up; 1919 is the bar under
	# its first name, before the 1927 demolition it survived.
	var pictures := [
		[-3.55, -1.10, "the framed block",
			["A framed photograph: this block in 1913, the Orison a year old in it. The bar is not in the picture. The stairs down to it are.",
			"Someone has inked a small x on one window of the tower. Fourth floor."]],
		[0.35, -1.25, "the opening-night photo",
			["The bar under its first name, 1919 - work jackets around the pool table. The felt was green then.",
			"Nobody in the photograph is looking at the camera. Everyone is looking at the door."]],
		[2.65, -0.70, "the signed portrait",
			["A signed publicity photo of a singer nobody can place. The signature has outlived the name.",
			"The frame is the only one on the wall without dust on its top edge."]],
	]
	for spec in pictures:
		var zone := InspectableZone.new()
		zone.name = "BAR_PIC_%d" % count
		zone.setup(str(spec[2]), spec[3], Vector3(0.7, 0.6, 0.3))
		root.add_child(zone)
		zone.global_position = GameBoot.b2g([float(spec[0]), -28.90,
				float(spec[1])])
		count += 1
	# -- the rope-bound barrels over the backbar
	var barrels := [
		[-2.95, "the west barrel",
			["Rope-bound sake barrels, decorative for decades. Knock: this one answers full."]],
		[-0.75, "the east barrel",
			["The stencilled brewery mark has worn to a ghost. The rope is newer than the barrel."]],
	]
	for spec in barrels:
		var zone := InspectableZone.new()
		zone.name = "BAR_BARREL_%s" % str(count)
		zone.setup(str(spec[1]), spec[2], Vector3(1.0, 0.8, 0.5))
		root.add_child(zone)
		zone.global_position = GameBoot.b2g([float(spec[0]), -28.95, -0.72])
		count += 1
	# -- the pool table, now in the west aisle
	var pool := InspectableZone.new()
	pool.name = "BAR_POOL_TABLE"
	pool.setup("the pool table",
			["Violet felt, five mismatched balls, one cue. The house rules are chalked on the underside of the rail, where nobody can read them.",
			"The cue leans where somebody left it mid-game. The balls have not moved since."],
			Vector3(2.0, 0.5, 1.3))
	root.add_child(pool)
	pool.global_position = GameBoot.b2g([-3.70, -33.95, FLR + 0.85])
	count += 1
	# -- seat sockets on the three banquettes of the raised lounge, which
	# face west off the east wall (yaw 270 in the generator). The deck
	# stands 180 mm proud of the floor, so these sit at DECK, not FLR.
	var deck := FLR + 0.18
	var seats := [
		[3.30, -37.10, -PI * 0.5], [3.30, -35.30, -PI * 0.5],
		[3.30, -33.40, -PI * 0.5],
	]
	for i in seats.size():
		var spec: Array = seats[i]
		var seat := BarSeatZone.new()
		seat.name = "BAR_SEAT_%d" % i
		seat.setup()
		root.add_child(seat)
		seat.global_position = GameBoot.b2g([float(spec[0]), float(spec[1]),
				deck + 0.42])
		seat.rotation.y = float(spec[2])
		count += 1
	print("[HARUKIYA] %d interactables placed" % count)
	return count
