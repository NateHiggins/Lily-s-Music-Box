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
	# -- pictures on the north wall (bar_pic0..2 in gen_layout)
	var pictures := [
		[-3.84, -1.10, "the framed block",
			["A framed photograph: this block in 1948, the Orison already old in it. The bar is not in the picture. The stairs down to it are.",
			"Someone has inked a small x on one window of the tower. Fourth floor."]],
		[1.86, -1.25, "the opening-night photo",
			["The bar under its first name, 1962 - work jackets around the pool table. The felt was green then.",
			"Nobody in the photograph is looking at the camera. Everyone is looking at the door."]],
		[3.21, -0.70, "the signed portrait",
			["A signed publicity photo of a singer nobody can place. The signature has outlived the name.",
			"The frame is the only one of the three without dust on its top edge."]],
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
	# -- the pool table
	var pool := InspectableZone.new()
	pool.name = "BAR_POOL_TABLE"
	pool.setup("the pool table",
			["Violet felt, five mismatched balls, one cue. The house rules are chalked on the underside of the rail, where nobody can read them.",
			"The cue leans where somebody left it mid-game. The balls have not moved since."],
			Vector3(2.3, 0.5, 1.3))
	root.add_child(pool)
	pool.global_position = GameBoot.b2g([-0.75, -32.20, FLR + 0.85])
	count += 1
	# -- seat sockets on the four couch modules (bar_couch0..3).
	# Couches 0/1 stand on the south wall facing north into the room;
	# couches 2/3 are the strip facing the bar, yaw 180 in the generator.
	var seats := [
		[-2.65, -34.80, 0.0], [-1.05, -34.80, 0.0],
		[3.22, -29.30, PI], [-4.35, -29.30, PI],
	]
	for i in seats.size():
		var spec: Array = seats[i]
		var seat := BarSeatZone.new()
		seat.name = "BAR_SEAT_%d" % i
		seat.setup()
		root.add_child(seat)
		seat.global_position = GameBoot.b2g([float(spec[0]), float(spec[1]),
				FLR + 0.42])
		seat.rotation.y = float(spec[2])
		count += 1
	print("[HARUKIYA] %d interactables placed" % count)
	return count
