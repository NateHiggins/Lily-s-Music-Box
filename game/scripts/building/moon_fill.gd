class_name MoonFill
extends OmniLight3D
## Moonlight through the window: the reason a switched-off apartment is
## dim, not void. One cool fill that follows the player between rooms and
## only exists in rooms that have a window for the moon to come through —
## which is also why the basement stays properly dark.
##
## ONE light, deliberately. A baked fill per room would be two dozen extra
## omnis per storey; a single roamer costs what one lamp costs and nobody
## can see two rooms' fills at once through 1927 masonry anyway.
##
## (2026-08-16: this used to justify itself with "a 16-per-object cap that
## is already rationed". The cap is 128 now and LightRig takes UNLIMITED on
## desktop, so that argument is dead. The decision is not: mobile still
## rations, two dozen omnis per storey is a submission cost on the side of
## the frame that is actually bottlenecked, and the masonry argument never
## depended on a renderer setting at all.)

const ENERGY := 0.16
## Day/night: the director dims the window pools toward daylight, when
## moonlight through glass stops being the story.
var energy_scale := 1.0
const TINT := Color(0.62, 0.70, 0.86)

var _layout: Dictionary = {}
var _player: Node3D
## The building, read live for its `view_override`. A tool sets that AFTER the
## root has built, so copying it once here would always copy a null.
##
## Without this the moon follows the player, the player stays in the lobby, and
## every screenshot tool photographs rooms the fill has never visited - a
## switched-off bedroom renders 97% black. That is not what the room looks like
## in the game, and it cost an afternoon to be sure of.
var _root: Node3D = null


func _anchor() -> Node3D:
	if _root != null and _root.view_override != null:
		return _root.view_override
	return _player
var _windowed: Array = []      # [floor_z, rect] rooms with exterior glass
var _accum := 0.0


func build(layout: Dictionary, player: Node3D) -> void:
	_layout = layout
	_player = player
	light_color = TINT
	light_energy = 0.0
	omni_range = 6.5
	shadow_enabled = false
	# Rooms touching the facade envelope get moon; interior rooms and B1
	# do not. The facade test is geometric — a room whose rect reaches
	# within a wall's thickness of the exterior at ±13.65 / ±9.65 has
	# window wall.
	for fl in layout["floors"]:
		if str(fl["id"]) in ["B1"]:
			continue
		var z: float = float(fl["z"])
		for r in fl.get("rooms", []):
			var rect: Array = r["rect"]
			if float(rect[0]) < -13.0 or float(rect[2]) > 13.0 \
					or float(rect[1]) < -9.0 or float(rect[3]) > 9.0:
				_windowed.append([z, rect])
	print("[MOON] %d windowed rooms" % _windowed.size())


func _process(delta: float) -> void:
	_accum += delta
	var eye := _anchor()
	if _accum < 0.3 or eye == null:
		return
	_accum = 0.0
	var p := eye.global_position
	var bl := Vector3(p.x, -p.z, p.y)          # godot -> blender
	var lit := false
	for entry in _windowed:
		if absf(bl.z - float(entry[0])) > 2.2:
			continue
		var rect: Array = entry[1]
		if bl.x >= float(rect[0]) and bl.x <= float(rect[2]) \
				and bl.y >= float(rect[1]) and bl.y <= float(rect[3]):
			lit = true
			break
	# Hangs above head height so the fill reads as coming from the room,
	# not from the player's pocket.
	global_position = p + Vector3(0, 1.6, 0)
	light_energy = lerpf(light_energy, ENERGY * energy_scale if lit else 0.0, 0.25)
	visible = light_energy > 0.01
