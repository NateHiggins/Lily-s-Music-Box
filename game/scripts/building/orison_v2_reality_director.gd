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
