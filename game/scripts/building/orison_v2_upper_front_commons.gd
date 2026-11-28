extends RefCounted
## Window-side shared uses. All positions are in the building's local frame.
## Stock stays at the street wall, beyond the east-west and lift approach routes.

const FURNITURE := {
	"F02": [
		["ParcelTable", "2B_din_t", Vector3(3.8, 0.0, -11.45), 0.0],
	],
	"F03": [
		["ReadingTable", "2A_din_t", Vector3(-0.4, 0.0, -11.22), 0.0],
		["ReadingChairWest", "2A_din_dc1", Vector3(-1.24, 0.0, -11.22), PI / 2],
		["ReadingChairEast", "2A_din_dc1", Vector3(0.44, 0.0, -11.22), -PI / 2],
	],
	"F04": [
		["LiftWaitingSettee", "2A_sofa", Vector3(0.0, 0.0, -11.76), PI],
	],
	"F05": [
		["MendingChair", "2A_din_dc1", Vector3(3.6, 0.0, -11.0), PI],
	],
	"F06": [
		["RoofWaitingSettee", "2A_sofa", Vector3(-3.4, 0.0, -11.76), PI],
	],
}

const OBJECTS := {
	"F02": [
		["ParcelCrate", "3B_partscrate", Vector3(4.52, 0.0, -11.76), 0.12],
	],
	"F03": [
		["SharedReadingStack", "5A_floorstack", Vector3(-0.54, 0.74, -11.44), -0.15],
	],
	"F05": [
		["MendingMachine", "2B_sewing_machine", Vector3(3.6, 0.0, -11.64), PI],
	],
	"F06": [
		["RoofBootTray", "4B_hall_boots", Vector3(-1.8, 0.0, -11.78), 0.0],
	],
}


static func mount(blockout: Node3D, layout: Dictionary) -> bool:
	var furnishing: RefCounted = blockout.get_meta("v2_native_domestic_factory", null)
	var objects: RefCounted = blockout.get_meta("v2_native_object_factory", null)
	if furnishing == null or objects == null:
		return false
	var commons := Node3D.new()
	commons.name = "UpperFrontCommons"
	for level: Dictionary in layout.levels:
		var identity := str(level.id)
		if not FURNITURE.has(identity):
			continue
		var bay := Node3D.new()
		bay.name = identity
		bay.position.y = float(level.y)
		commons.add_child(bay)
		if not _mount_stock(bay, furnishing, FURNITURE[identity]) 				or not _mount_stock(bay, objects, OBJECTS.get(identity, [])):
			commons.free()
			return false
	blockout.add_child(commons)
	return true


static func _mount_stock(bay: Node3D, factory: RefCounted, rows: Array) -> bool:
	for row: Array in rows:
		var body := StaticBody3D.new()
		body.name = str(row[0])
		body.position = row[2]
		body.rotation.y = float(row[3])
		if not factory.call("mount_on", body, str(row[1])):
			body.free()
			return false
		bay.add_child(body)
	return true
