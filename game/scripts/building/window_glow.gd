class_name OrisonWindowGlow
extends Node3D
## "Emissive interiors visible from the street at night" — the last piece
## of the target's glass-and-light paragraph that was still missing.
##
## From the sidewalk the Orison read as derelict: lighting is gated to the
## storey the camera occupies, so at most one floor's windows showed
## anything and the other five were black holes in a brick wall. Real
## fixtures for all of them is not an option — that is exactly the
## per-object light cap the LightRig exists to ration.
##
## So the glow is not a light. Each exterior window gets one unshaded
## emissive quad standing just inside the opening, facing OUT. It costs a
## draw and lights nothing. It is single-sided on purpose: from inside a
## room you are looking at its back face, which is culled, so the window
## still shows the night sky and the real fixtures still own the interior.
##
## What each window shows is read from the room behind it, so the building
## tells the truth about itself: 2D has been sealed since 1927 and 5D
## burned, so they stay black; the vacant 3C and the landlord's crate
## store in 6D are unlit; kitchens run cooler than living rooms; and about
## a third of the rest are dark because it is night and people are asleep
## or out.

const SEALED_UNITS := ["2D", "3C", "5D", "6D"]
## Rooms nobody lights from within at this hour.
const DARK_KINDS := ["closet", "storage", "storage_cages", "coal"]
const EXTERIOR_MATS := ["face_brick", "common_brick"]

## Warm tungsten by room use; kitchens keep the greener fluorescent cast
## the fixture family already uses.
const TONES := {
	"living": Color(1.00, 0.79, 0.52),
	"bedroom": Color(1.00, 0.74, 0.46),
	"alcove": Color(1.00, 0.74, 0.46),
	"kitchen": Color(0.96, 0.93, 0.78),
	"bathroom": Color(1.00, 0.86, 0.66),
	"office": Color(1.00, 0.84, 0.60),
	"common": Color(1.00, 0.82, 0.58),
	"lobby": Color(1.00, 0.80, 0.55),
	"corridor": Color(0.98, 0.85, 0.62),
	"hall": Color(0.98, 0.85, 0.62),
	"utility": Color(0.90, 0.92, 0.85),
	"laundry": Color(0.92, 0.94, 0.86),
	"boiler": Color(1.00, 0.72, 0.42),
}

var _lit := 0
var _dark := 0


func build(layout: Dictionary) -> int:
	for fl in layout["floors"]:
		var rooms: Array = fl["rooms"]
		for w in fl["walls"]:
			if not (w["mat"] in EXTERIOR_MATS):
				continue
			for o in w.get("openings", []):
				if o.get("type", "") != "window":
					continue
				_window(fl, rooms, w, o)
	return _lit


func _window(fl: Dictionary, rooms: Array, w: Dictionary,
		o: Dictionary) -> void:
	var ax: float = float(w["a"][0])
	var ay: float = float(w["a"][1])
	var bx: float = float(w["b"][0])
	var by: float = float(w["b"][1])
	var horizontal: bool = absf(by - ay) < 1e-6
	var start: float = minf(ax, bx) if horizontal else minf(ay, by)
	var along: float = start + float(o["at"])
	var cross: float = ay if horizontal else ax
	var z: float = float(fl["z"]) + float(o.get("sill", 0.0)) \
			+ float(o["h"]) * 0.5

	# Inward is toward the building's axis. The quad sits just behind the
	# glazing rather than deep in the room: every unit's windows carry
	# venetian blinds a hand's width inside the reveal, and a glow placed
	# behind those is a glow nobody ever sees.
	var inward: float = -signf(cross)
	var depth: float = float(w["t"]) * 0.5 + 0.04
	var wx: float = along if horizontal else cross + inward * depth
	var wy: float = cross + inward * depth if horizontal else along

	# Ask which room is behind the window from a point properly inside it.
	# Sampling at the glass lands in the wall's own thickness, where no
	# room matches and every window silently goes dark.
	var probe: float = float(w["t"]) * 0.5 + 0.9
	var room: Variant = _room_at(rooms,
			along if horizontal else cross + inward * probe,
			cross + inward * probe if horizontal else along)
	var seed_id: String = "%s_%.2f_%.2f" % [fl["id"], wx, wy]
	if not _is_lit(room, seed_id):
		_dark += 1
		return

	var kind: String = room.get("kind", "living") if room else "living"
	var tone: Color = TONES.get(kind, Color(1.0, 0.80, 0.55))
	# per-window variation: no two rooms sit at the same brightness, and
	# a curtained window is dimmer than a bare one
	var h: float = float(hash(seed_id) % 1000) / 1000.0
	# Bright enough to carry through the glazing and the night grade; the
	# spread is what stops a facade reading as a uniform grid of panels.
	var energy: float = 1.6 + h * 1.9

	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(float(o["w"]) * 0.92, float(o["h"]) * 0.92)
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tone
	mat.emission_enabled = true
	mat.emission = tone
	mat.emission_energy_multiplier = energy
	# Single-sided and facing out: invisible from inside the room, so it
	# never fights the real fixtures or shows up as a floating panel.
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var at: Vector3 = GameBoot.b2g([wx, wy, z])
	# look_at aims a node's -Z at its target and QuadMesh's face is +Z, so
	# the target is a point further INSIDE the room: that leaves the lit
	# face pointing out of the facade, where it is meant to be seen.
	var toward: Array = [wx, wy + inward, z] if horizontal \
			else [wx + inward, wy, z]
	mi.look_at_from_position(at, GameBoot.b2g(toward), Vector3.UP)
	add_child(mi)
	_lit += 1


## The room whose footprint contains the point just inside the glass.
func _room_at(rooms: Array, x: float, y: float) -> Variant:
	var best: Variant = null
	var best_area := INF
	for r in rooms:
		var rect: Array = r["rect"]
		if x < float(rect[0]) or x > float(rect[2]) \
				or y < float(rect[1]) or y > float(rect[3]):
			continue
		# rooms nest (a bath sits inside its unit's envelope): the
		# smallest match is the one actually behind the window
		var area := (float(rect[2]) - float(rect[0])) \
				* (float(rect[3]) - float(rect[1]))
		if area < best_area:
			best_area = area
			best = r
	return best


func _is_lit(room: Variant, seed_id: String) -> bool:
	if room == null:
		return false
	if str(room.get("unit", "")) in SEALED_UNITS:
		return false
	if str(room.get("kind", "")) in DARK_KINDS:
		return false
	# It is the middle of the night: roughly a third of the occupied rooms
	# are dark. Seeded, so the building looks the same every run.
	return hash(seed_id + "occupied") % 100 >= 34


func stats() -> Dictionary:
	return {"lit": _lit, "dark": _dark}
