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
var _room_fixtures: Dictionary = {}

const LIGHT_KINDS := {
	"flush_dome": true, "pendant_shade": true, "sconce_globe": true,
	"kitchen_linear": true, "cage_bulb": true, "chandelier": true,
	"eye_pendant": true, "ceiling_light": true, "corridor_light": true,
}


func build(layout: Dictionary, root: Node3D) -> int:
	_layout = layout
	_map_fixtures(layout)
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
			# The click is the whole point of a switch. Without it a
			# plate is a texture you press and a room that changes
			# behind you.
			var click := AudioStreamPlayer3D.new()
			click.name = "Click"
			click.stream = PropAudio.get_stream("tick")
			click.volume_db = -6.0
			click.unit_size = 1.6
			click.max_distance = 9.0
			body.add_child(click)
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


## Which fixtures each room owns, resolved from the LAYOUT by position
## rather than from fixture names.
##
## The old rule was "every fixture whose marker id begins with the room
## id". That reached 82 of 187 fixtures. The other 105 are named for the
## thing they belong to rather than the room they hang in - `4C_LT_SCONCE`
## is in F04_C_MAIN, `B1_CORRIDOR_DOME_01` is in B1_HALL - so more than
## half the lights in the building answered to no switch at all, and a
## room whose only fixture was one of them could not be turned on.
##
## A light is in the room its position is in. That is all this needs to be.
func _map_fixtures(layout: Dictionary) -> void:
	_room_fixtures.clear()
	var homeless := 0
	for fl in layout["floors"]:
		for m in fl.get("markers", []):
			if not LIGHT_KINDS.has(str(m.get("kind", ""))):
				continue
			var pos: Array = m.get("pos", [])
			if pos.size() < 2:
				continue
			var found := ""
			for r in fl.get("rooms", []):
				var rect: Array = r["rect"]
				if float(rect[0]) <= float(pos[0]) 						and float(pos[0]) <= float(rect[2]) 						and float(rect[1]) <= float(pos[1]) 						and float(pos[1]) <= float(rect[3]):
					found = str(r["id"])
					break
			if found == "":
				# Exterior fittings - the marquee, the street lamps - hang
				# on no room and belong to no plate. Correct, not missing.
				homeless += 1
				continue
			if not _room_fixtures.has(found):
				_room_fixtures[found] = []
			_room_fixtures[found].append(str(m.get("id", "")))
	var wired := 0
	for k in _room_fixtures:
		wired += _room_fixtures[k].size()
	print("[SWITCHES] %d fixtures wired across %d rooms, %d exterior"
			% [wired, _room_fixtures.size(), homeless])


func toggle_room(room_id: String) -> bool:
	if room_id == "" or not _room_fixtures.has(room_id):
		return false
	var want: Dictionary = {}
	for n in _room_fixtures[room_id]:
		want[n] = true
	var flipped := 0
	var now_on := false
	for fixture in get_tree().get_nodes_in_group("light_fixtures"):
		if not want.has(str(fixture.name)):
			continue
		if "powered" in fixture:
			fixture.set_powered(not fixture.powered)
			now_on = fixture.powered
			flipped += 1
	if flipped > 0:
		print("[SWITCHES] %s -> %s (%d fixtures)"
				% [room_id, "on" if now_on else "off", flipped])
	return now_on
