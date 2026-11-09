extends RefCounted
## The invisible director in V2 (Lily, v1r_sanity_layer_20261109: "Import it,
## rebuilt on V2 anchors").
##
## The director, its intrusions, the building's personality and the fourth-wall
## layer are the same scripts V1 ran; this composer only binds them to the V2
## runtime root. The root answers the two questions V1 answered from its own
## shape: which apartment a point is in (`unit_at_world`, from V2 room
## footprints) and which props an intrusion may touch (`intrusion_props`, the
## FunctionalProp nodes wherever they are nested). There is still no meter.


static func mount(root: Node3D, player: Node3D) -> Dictionary:
	var fourth_wall := FourthWallLayer.new()
	fourth_wall.name = "FourthWall"
	root.add_child(fourth_wall)
	var intrusions := Intrusions.new()
	intrusions.name = "Intrusions"
	root.add_child(intrusions)
	intrusions.setup(root, player, fourth_wall)
	var sanity := SanityDirector.new()
	sanity.name = "SanityDirector"
	root.add_child(sanity)
	sanity.setup(root, player, intrusions, fourth_wall)
	var personality := BuildingPersonalityDirector.new()
	personality.name = "BuildingPersonalityDirector"
	root.add_child(personality)
	personality.setup(root, player, intrusions)
	sanity.bind_personality(personality)
	return {"fourth_wall": fourth_wall, "intrusions": intrusions,
		"sanity": sanity, "personality": personality}


## V2 decision: its fittings are mounted. An intrusion may fault them or set
## them off, but never turn, drift, drop or hide a door, tap, radiator, flue,
## sign or panel. Only free-standing things move.
const FIXED := ["DoorProp", "LandmarkEntryDoor", "TapProp", "FlueBreastProp",
	"RadiatorProp", "BoilerProp", "MailBankProp", "MedicineCabinetProp",
	"ShopSignProp", "NeonSignProp", "BodegaSignageProp", "HarukiyaSignageProp",
	"FusePanelProp", "HouseSwitchboardProp", "OtisProp", "DumbwaiterProp",
	"RoofTankBallcockProp", "WatchmanClockProp", "WatchRegisterProp",
	"NightRegisterProp", "TourKeyGuardProp", "VantryPointProp",
	"SongbookTerminalProp", "ExhaustFanProp", "FireLineCabinetProp",
	"WatchStationProp", "SignalTerminalProp"]


## Every FunctionalProp under the root, wherever it is nested, split into
## the free-standing ones an intrusion may move and the ones that can have a
## fit (possess_fit). Light fixtures have their own group and acts.
static func collect_props(root: Node) -> Dictionary:
	var movable: Array = []
	var fits: Array = []
	for node in root.find_children("*", "", true, false):
		if not node is FunctionalProp or node is LightFixtureProp:
			continue
		if node.has_method("possess_fit"):
			fits.append(node)
		if not is_fixed(node):
			movable.append(node)
	return {"movable": movable, "fits": fits}


static func is_fixed(node: Node) -> bool:
	var script: Script = node.get_script()
	while script != null:
		if script.get_global_name() in FIXED:
			return true
		script = script.get_base_script()
	return false


## Case presentation (v1r_case_presentation_20261109): one reality controller
## per case flat, sized to the flat's MAIN room in V2's own layout, as V1 fell
## back to when a flat had no living room. The controller bends gravity and
## builds the loop thresholds while the case's rule is live, and restores what
## it registered when the case stabilises. Returns case_id -> controller.
static func mount_controllers(root: Node3D, blockout: Node3D, layout: Dictionary) -> Dictionary:
	var levels: Dictionary = {}
	for row: Dictionary in layout.get("levels", []):
		levels[str(row.id)] = float(row.y)
	var spaces: Dictionary = {}
	for space: Dictionary in layout.get("spaces", []):
		spaces[str(space.id)] = space
	var storey := float(layout.get("dimensions", {}).get("floor_to_floor", 3.2))
	var to_root := root.global_transform.affine_inverse() * blockout.global_transform
	var controllers: Dictionary = {}
	for case_id: String in RealityCases.definitions:
		var unit := str(RealityCases.definition(case_id).get("unit", ""))
		if unit.length() < 2:
			continue
		var space_id := "F0%s_%s_MAIN" % [unit.left(1), unit.substr(1)]
		if not spaces.has(space_id):
			push_warning("V2 reality controller: no %s for %s" % [space_id, case_id])
			continue
		var space: Dictionary = spaces[space_id]
		var r: Array = space.rect
		var y := float(levels.get(str(space.level), 0.0))
		var low := Vector3.INF
		var high := -Vector3.INF
		for corner in 8:
			var local := Vector3(float(r[2]) if corner & 1 else float(r[0]),
				y + (storey - 0.15 if corner & 2 else 0.0),
				float(r[3]) if corner & 4 else float(r[1]))
			var point := to_root * local
			low = low.min(point)
			high = high.max(point)
		var controller := ApartmentRealityController.new()
		controller.setup(case_id, unit, low, high)
		root.add_child(controller)
		controllers[case_id] = controller
	return controllers
