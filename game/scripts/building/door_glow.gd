class_name OrisonDoorGlow
extends Node3D
## Light leaking out of the apartments into the corridors.
##
## A corridor at night is not uniformly dark. Under every closed door there
## is a gap, and behind some of those doors somebody is awake — so the floor
## carries a bar of warm light, and the door itself is outlined by a hairline
## where the leaf does not quite meet its frame. It is the single strongest
## cue that a corridor is a place where people live, and until now the
## Orison's corridors had none of it: every door read as a painted rectangle
## on a wall.
##
## Built the same way the window glow is, and for the same reason. The
## Compatibility renderer caps lights per OBJECT and each floor's walls are
## one merged mesh, so a real light per door would starve the corridor
## fixtures the LightRig works hard to protect. These are unshaded quads —
## a picture of spill, not spill — batched into ONE mesh for the whole
## building with the brightness carried in vertex colour.
##
## Crucially it asks `OrisonWindowGlow` which rooms are awake rather than
## deciding for itself. A unit whose windows are lit from the street has
## light under its door in the corridor, and a unit that is dark is dark from
## both sides. Two independent guesses would have contradicted each other
## somewhere, and the building would have been caught lying.
##
## What is NOT here: transom spill. 1927 blocks did put transom lights over
## apartment doors, but this building's geometry has no transom openings, and
## a glowing rectangle on solid plaster is a worse artefact than an absent
## one. If transoms are ever cut into the door openings, this is where their
## glow belongs.

## The bar of light on the corridor floor: how far it reaches out from the
## threshold. Any deeper and it stops reading as a gap under a door and
## starts reading as an open door.
const SPILL_DEPTH := 0.155
## Hairline around the leaf. Real, but only just.
const SEAM := 0.009
## Corridors carry a 12 mm terrazzo finish laid ON TOP of the slab, so a bar
## of light at slab level is a bar of light underneath the floor. Sit above
## the finish, not above the structure.
const FLOOR_CLEAR := 0.018
## Corridor-side offset from the door's own position. Door markers sit on the
## wall CENTRELINE, and a corridor wall is 180 mm thick — so anything less
## than 90 mm here is buried inside the masonry, which is exactly where the
## first version of this put every bar of light. Past the face, past the
## casing, and no further.
const CLEAR := 0.125
const TONE_WARM := Color(1.0, 0.79, 0.52)
const TONE_COOL := Color(0.76, 0.85, 0.97)
## Rooms that read cooler at night: a kitchen light is a different lamp from
## a living-room one, and the corridor should be able to tell.
const COOL_KINDS := ["kitchen", "bathroom"]

var _doors := 0
var _lit := 0
var _skips := {"no_circulation": 0, "asleep": 0}


## `glow` is the window pass, used as the single authority on which rooms are
## awake. Returns how many doors ended up spilling.
func build(layout: Dictionary, glow: OrisonWindowGlow) -> int:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for fl in layout["floors"]:
		var rooms: Array = fl.get("rooms", [])
		var z: float = float(fl["z"])
		for m in fl.get("markers", []):
			if str(m.get("kind", "")) != "door":
				continue
			if bool(m.get("cabinet", false)):
				continue
			# An open doorway has no gap to leak through.
			if str(m.get("leaf", "")) not in ["closed", "locked"]:
				continue
			_doors += 1
			if _door(st, rooms, m, z, glow):
				any = true
	if not any:
		return 0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	var mi := MeshInstance3D.new()
	mi.name = "DoorSpill"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	print("[DOOR GLOW] %d closed doors, %d leaking light (skipped: %s)"
			% [_doors, _lit, _skips])
	return _lit


## One door. Returns true if it leaked.
func _door(st: SurfaceTool, rooms: Array, m: Dictionary, z: float,
		glow: OrisonWindowGlow) -> bool:
	var pos: Array = m["pos"]
	var px: float = float(pos[0])
	var py: float = float(pos[1])
	var width: float = float(m.get("w", 0.91))
	var height: float = float(m.get("h", 2.03))
	# Which way the wall runs, from the door's own yaw. The SIGN of the
	# facing is deliberately not trusted — the two sides are sampled and the
	# corridor is whichever one is not somebody's room, which is robust
	# against every yaw convention in the data.
	var yaw := deg_to_rad(float(m.get("yaw_deg", 0)))
	var across_x: bool = absf(sin(yaw)) > 0.5
	var probe := 0.62
	var near_room: Variant = glow._room_at(rooms,
			px - (probe if across_x else 0.0), py - (0.0 if across_x else probe))
	var far_room: Variant = glow._room_at(rooms,
			px + (probe if across_x else 0.0), py + (0.0 if across_x else probe))
	var inside: Variant = null
	var outward := 0.0
	if _is_circulation(far_room) and not _is_circulation(near_room):
		inside = near_room
		outward = 1.0
	elif _is_circulation(near_room) and not _is_circulation(far_room):
		inside = far_room
		outward = -1.0
	else:
		_skips.no_circulation += 1
		return false          # cupboard-to-cupboard, or two corridors
	if inside == null:
		_skips.no_circulation += 1
		return false
	var room_id := str(inside.get("id", ""))
	if not glow._is_lit(inside, room_id):
		_skips.asleep += 1
		return false
	_lit += 1
	if OS.get_environment("DOOR_GLOW_DEBUG") == "1":
		print("[DOOR GLOW] lit %s at (%.2f, %.2f, %.2f)"
				% [str(m.get("id", "?")), px, py, z])
	# Steady per door, so the corridor looks the same every run — and dimmer
	# than a window, because this is a gap under a door and not a pane.
	var strength := 0.46 + 0.26 * (float(hash(room_id + "spill") % 100) / 100.0)
	var tone: Color = TONE_COOL if str(inside.get("kind", "")) in COOL_KINDS \
			else TONE_WARM
	var tint := Color(tone.r * strength, tone.g * strength,
			tone.b * strength, 1.0)

	var nx := (outward if across_x else 0.0)
	var ny := (0.0 if across_x else outward)
	var ax := (0.0 if across_x else 1.0)         # along the wall
	var ay := (1.0 if across_x else 0.0)
	var face_x := px + nx * CLEAR
	var face_y := py + ny * CLEAR

	# The bar on the floor. Lies flat, faces up, and fades with distance
	# from the threshold — a hard-edged rectangle of light reads as a decal,
	# and this has to read as a gap.
	var half := width * 0.5
	for step in 3:
		var t0 := float(step) / 3.0
		var t1 := float(step + 1) / 3.0
		var c0 := Color(tint.r * (1.0 - t0), tint.g * (1.0 - t0),
				tint.b * (1.0 - t0), 1.0)
		var c1 := Color(tint.r * (1.0 - t1), tint.g * (1.0 - t1),
				tint.b * (1.0 - t1), 1.0)
		var d0 := SPILL_DEPTH * t0
		var d1 := SPILL_DEPTH * t1
		_strip(st,
				Vector3(face_x + nx * d0 - ax * half,
						z + FLOOR_CLEAR, face_y + ny * d0 - ay * half),
				Vector3(face_x + nx * d0 + ax * half,
						z + FLOOR_CLEAR, face_y + ny * d0 + ay * half),
				Vector3(face_x + nx * d1 + ax * half,
						z + FLOOR_CLEAR, face_y + ny * d1 + ay * half),
				Vector3(face_x + nx * d1 - ax * half,
						z + FLOOR_CLEAR, face_y + ny * d1 - ay * half),
				c0, c1, Vector3.UP)

	# Hairline down both jambs and across the head: the leaf never quite
	# meets its frame, and that outline is what makes a closed door read as
	# closed rather than as wall.
	var seam := Color(tint.r * 0.75, tint.g * 0.75, tint.b * 0.75, 1.0)
	var normal := Vector3(nx, 0.0, ny)
	for entry in [-1.0, 1.0]:
		var side: float = entry
		var ox: float = ax * half * side
		var oy: float = ay * half * side
		_strip(st,
				Vector3(face_x + ox, z + 0.02, face_y + oy),
				Vector3(face_x + ox + ax * SEAM * side, z + 0.02,
						face_y + oy + ay * SEAM * side),
				Vector3(face_x + ox + ax * SEAM * side, z + height,
						face_y + oy + ay * SEAM * side),
				Vector3(face_x + ox, z + height, face_y + oy),
				seam, seam, normal)
	_strip(st,
			Vector3(face_x - ax * half, z + height, face_y - ay * half),
			Vector3(face_x + ax * half, z + height, face_y + ay * half),
			Vector3(face_x + ax * half, z + height + SEAM,
					face_y + ay * half),
			Vector3(face_x - ax * half, z + height + SEAM,
					face_y - ay * half),
			seam, seam, normal)
	return true


## Blender XY comes in as (x, y); the world is Godot, so every vertex is
## converted on the way in. Colours are per-edge so a strip can fade.
func _strip(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		c_ab: Color, c_cd: Color, normal: Vector3) -> void:
	var pa := GameBoot.b2g([a.x, a.z, a.y])
	var pb := GameBoot.b2g([b.x, b.z, b.y])
	var pc := GameBoot.b2g([c.x, c.z, c.y])
	var pd := GameBoot.b2g([d.x, d.z, d.y])
	for entry in [[pa, c_ab], [pc, c_cd], [pb, c_ab],
			[pa, c_ab], [pd, c_cd], [pc, c_cd]]:
		st.set_color(entry[1])
		st.set_normal(normal)
		st.add_vertex(entry[0])


func _is_circulation(room: Variant) -> bool:
	if room == null:
		return false
	return str(room.get("kind", "")) in ["corridor", "hall", "lobby",
			"atrium", "vestibule", "utility", "storage"]


func stats() -> Dictionary:
	return {"doors": _doors, "lit": _lit}
