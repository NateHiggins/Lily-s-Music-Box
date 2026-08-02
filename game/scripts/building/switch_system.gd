class_name SwitchSystem
extends Node3D
## Makes the 202 moulded wall switches real. The plates are merged furniture
## geometry; this hangs a small interact skin at each one, and flipping it
## cuts or restores power to the fixtures of the room the switch serves.
##
## A switch serves the room its wall face opens INTO — the plate sits beside
## a doorway on a specific face (its yaw), so step a hand-span along that
## facing and whatever room you are in is the room being switched. Off is
## off: the fixture's `powered` flag outranks the LightRig budget, and the
## moonlight fill (moon_fill.gd) is what keeps a switched-off room readable
## rather than void-black.

const PLATE := Vector3(0.16, 0.24, 0.06)

var switches := 0

var _layout: Dictionary = {}


func build(layout: Dictionary, root: Node3D) -> int:
	_layout = layout
	for fl in layout["floors"]:
		var z: float = float(fl["z"])
		for fu in fl.get("furniture", []):
			if str(fu.get("asm", "")) != "switch":
				continue
			var at: Array = fu["at"]
			var yaw := deg_to_rad(float(fu.get("yaw", 0)))
			var body := StaticBody3D.new()
			body.name = "SW_" + str(fu.get("id", switches))
			body.position = GameBoot.b2g([float(at[0]), float(at[1]),
					z + float(fu.get("z0", 1.12))])
			body.rotation.y = yaw
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = PLATE
			shape.shape = box
			# Proud of the plate the way the TV skin is proud of its
			# cabinet, so the interact ray meets it first.
			shape.position = Vector3(0, 0, -0.05)
			body.add_child(shape)
			var room_id := _room_served(fl, at, yaw)
			body.set_meta("room_id", room_id)
			body.set_script(preload("res://scripts/building/switch_plate.gd"))
			body.system = self
			add_child(body)
			switches += 1
	print("[SWITCHES] %d live plates" % switches)
	return switches


## The room a hand-span along the switch's facing. Blender yaw: the plate
## face normal points (sin, cos) at yaw 0 north — matching the door pass.
func _room_served(fl: Dictionary, at: Array, yaw: float) -> String:
	var probe := Vector2(float(at[0]), float(at[1])) \
			+ Vector2(sin(yaw), cos(yaw)) * 0.45
	var best := ""
	var best_area := INF
	for r in fl.get("rooms", []):
		var rect: Array = r["rect"]
		if probe.x < float(rect[0]) or probe.x > float(rect[2]) \
				or probe.y < float(rect[1]) or probe.y > float(rect[3]):
			continue
		var area := (float(rect[2]) - float(rect[0])) \
				* (float(rect[3]) - float(rect[1]))
		if area < best_area:
			best_area = area
			best = str(r["id"])
	return best


## Every fixture whose marker id begins with the room id — the generator
## names them `<ROOM>_LT_<KIND>`, so the binding is the same one the
## lighting pass authored.
func toggle_room(room_id: String) -> bool:
	if room_id == "":
		return false
	var flipped := 0
	var now_on := false
	for fixture in get_tree().get_nodes_in_group("light_fixtures"):
		if not str(fixture.name).begins_with(room_id + "_LT"):
			continue
		if "powered" in fixture:
			fixture.set_powered(not fixture.powered)
			now_on = fixture.powered
			flipped += 1
	if flipped > 0:
		print("[SWITCHES] %s -> %s (%d fixtures)"
				% [room_id, "on" if now_on else "off", flipped])
	return flipped > 0
