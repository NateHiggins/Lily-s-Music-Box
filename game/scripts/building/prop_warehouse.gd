class_name PropWarehouse
extends Node3D
## A lit shed, 400 metres east of the Orison, containing one of everything.
##
## Props are authored in a dark building at night, which is the worst place
## to judge them: half of what is wrong with a blockout is invisible under a
## torch, and the only way to compare two of them is to walk between two
## floors. So every prop type gets instanced once here, on a labelled grid,
## under flat even light, at a spacing that lets you orbit any of them.
##
## It is deliberately unreachable rather than hidden. There is no door, no
## navigation link and no floor between here and the building - the only way
## in is the debug panel's teleport, so nothing about it can leak into play.
## Built only in DEBUG launch mode; a shipped game never pays for it.
##
## What it is for, in order of how often it earns its keep:
##   - seeing a prop at all, lit, without hunting for the room it lives in
##   - comparing the whole family side by side, which is how you notice
##     that three of them share a silhouette
##   - checking scale against the 1 m grid painted on the floor
##   - watching possession and interaction animations somewhere they are
##     not competing with the building's own noise

## Far enough east that no streaming volume, nav mesh or occlusion query
## will ever reach it, and on a round number so poses are easy to read.
const ORIGIN := Vector3(400.0, 0.0, 0.0)
# Large wall-backed props were only 0.73 m apart at 2.6 m centres. Their
# inspection backers then hid the next row's appliance before the appliance
# itself entered frame — the refrigerator looked like a blank wall from the
# viewing aisle. Four-metre bays leave a person-width route around every
# plinth and let the silhouette be judged against the one-metre floor grid.
const CELL := 4.0           # metres between plinth centres
const COLS := 6
const HALL_H := 5.0
## Where a ceiling fixture and a wall fixture are put so they read in the
## pose they ship in, rather than face down on the plinth.
const SOFFIT_Y := 2.62
const WALL_Y := 1.45

var _built := 0
var _hall := Vector2(12.0, 12.0)   # inside dimensions, set at build


func build(prop_scripts: Dictionary) -> int:
	name = "PropWarehouse"
	position = ORIGIN
	var kinds: Array = prop_scripts.keys()
	kinds.sort()
	# Most kinds own one silhouette. A few are a real family behind one
	# marker kind — the fridge marker can mean an oak icebox or a monitor-
	# top — and displaying only the default let the second model escape the
	# very comparison this room exists to make.
	var displays: Array[Dictionary] = []
	for kind in kinds:
		var script: GDScript = prop_scripts[kind]
		var probe: FunctionalProp = script.new()
		# A shared script can branch variants by marker kind (tap_prop is both
		# sink and shower). It must know that kind before inspection or both
		# catalog entries expand to the default sink family and duplicate it.
		probe.prop_type = String(kind)
		var variants: Array[Dictionary] = probe.warehouse_variants()
		probe.free()
		if variants.is_empty():
			variants = [{}]
		# A family is a comparison, so never wrap its variants across the aisle.
		# Kettle happened to begin in column six and put nickel and copper four
		# metres apart on different rows — both existed, but not side by side.
		if variants.size() > 1 \
				and displays.size() % COLS + variants.size() > COLS:
			while displays.size() % COLS != 0:
				displays.append({"spacer": true})
		for variant in variants:
			displays.append({"kind": String(kind), "script": script,
					"variant": variant})
	var rows := int(ceil(float(displays.size()) / COLS))
	_build_shell(rows)
	for i in displays.size():
		var col := i % COLS
		var row := i / COLS
		var at := Vector3((col - (COLS - 1) * 0.5) * CELL, 0.0,
				(row - (rows - 1) * 0.5) * CELL)
		var entry: Dictionary = displays[i]
		if entry.get("spacer", false):
			continue
		var variant: Dictionary = entry.variant
		_plinth(at, String(variant.get("label", entry.kind)))
		var script: GDScript = entry.script
		var prop: Node3D = script.new()
		prop.name = "WH_%s_%02d" % [entry.kind, i]
		if "prop_type" in prop:
			prop.set("prop_type", String(entry.kind))
		# Before add_child, because `_ready()` is the constructor for every
		# FunctionalProp. Setting monitor_top one frame later builds an icebox
		# and merely renames it a monitor-top.
		for key in variant.get("properties", {}):
			if key in prop:
				prop.set(key, variant.properties[key])
		add_child(prop)
		prop.rotation.y = prop.warehouse_rotation_y()
		# Stand it the way it hangs.
		#
		# Every prop used to be dropped on the plinth top, which is only
		# correct for the ones that stand on a floor. A pendant, a dome,
		# a chandelier and a sconce all build DOWNWARD or OUTWARD from an
		# anchor they expect the building to provide, so on a plinth they
		# collapsed into a speck at ankle height or vanished under it -
		# the fixtures most worth inspecting were the ones you could not
		# see. Rather than keep a list of which kind mounts how, and
		# re-file every kind added later, ask the prop: it is already
		# built by the time add_child returns, so its own bounds say
		# whether it hangs below its origin or straddles it.
		var box := _content_bounds(prop)
		var lift := 0.12
		if box.size.length_squared() > 0.0:
			if box.end.y <= 0.10:                    # hangs below: ceiling
				lift = SOFFIT_Y
				_soffit(at)
			elif box.position.y < -0.12:             # straddles: wall
				lift = WALL_Y
				_stub_wall(at)
		prop.position = at + Vector3(0, lift, 0)
		_built += 1
	print("[WAREHOUSE] %d prop displays from %d kinds, %d rows" % [
			_built, kinds.size(), rows])
	return _built


## Bare shed: slab, four walls, a roof, and a one-metre grid painted on the
## floor so scale can be read off directly instead of guessed.
func _build_shell(rows: int) -> void:
	var w: float = (COLS + 1) * CELL
	var d: float = (rows + 1) * CELL
	_hall = Vector2(w, d)
	var pale := StandardMaterial3D.new()
	# Mid grey, not white: a lightbox that blows out tells you nothing
	# about the thing standing in it.
	pale.albedo_color = Color(0.26, 0.265, 0.28)
	pale.roughness = 0.94
	var line := StandardMaterial3D.new()
	line.albedo_color = Color(0.50, 0.52, 0.55)
	line.roughness = 0.9

	_slab(Vector3(w, 0.2, d), Vector3(0, -0.1, 0), pale)
	# The shed was authored for the free camera, which flies - so nothing
	# here ever had collision, and the debug teleport dropped a PHYSICAL
	# player straight through the visual floor into the void. The button
	# was never broken; the ground was. Floor plus four walls, so the one
	# way in is also a place you can stand.
	var phys := StaticBody3D.new()
	phys.name = "ShellCollision"
	add_child(phys)
	# (GDScript has no tuple unpacking in for loops - the first version
	# of this was Python that happened to be cached past one session.)
	for entry in [
		[Vector3(w, 0.2, d), Vector3(0, -0.1, 0)],
		[Vector3(0.2, HALL_H, d), Vector3(-w * 0.5, HALL_H * 0.5, 0)],
		[Vector3(0.2, HALL_H, d), Vector3(w * 0.5, HALL_H * 0.5, 0)],
		[Vector3(w, HALL_H, 0.2), Vector3(0, HALL_H * 0.5, -d * 0.5)],
		[Vector3(w, HALL_H, 0.2), Vector3(0, HALL_H * 0.5, d * 0.5)],
	]:
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = entry[0]
		cs.shape = bx
		cs.position = entry[1]
		phys.add_child(cs)
	_slab(Vector3(w, 0.1, d), Vector3(0, HALL_H, 0), pale)
	for sx in [-1.0, 1.0]:
		_slab(Vector3(0.2, HALL_H, d), Vector3(sx * w * 0.5, HALL_H * 0.5, 0),
				pale)
		_slab(Vector3(w, HALL_H, 0.2), Vector3(0, HALL_H * 0.5, sx * d * 0.5),
				pale)
	# the metre grid
	var nx := int(w)
	var nz := int(d)
	for i in nx + 1:
		_slab(Vector3(0.02, 0.004, d), Vector3(-w * 0.5 + i, 0.002, 0), line)
	for i in nz + 1:
		_slab(Vector3(w, 0.004, 0.02), Vector3(0, 0.002, -d * 0.5 + i), line)

	# Flat, even, shadowless: this is a lightbox, not a room. Anything that
	# only looks right under the building's grade is not right.
	for cx in [-w * 0.25, w * 0.25]:
		for cz in [-d * 0.25, d * 0.25]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(cx, HALL_H - 0.9, cz)
			lamp.light_energy = 2.6
			lamp.light_color = Color(1.0, 0.985, 0.96)
			lamp.omni_range = maxf(w, d) * 1.1
			lamp.omni_attenuation = 0.55
			lamp.shadow_enabled = false
			add_child(lamp)


func _plinth(at: Vector3, label_text: String) -> void:
	var plinth := StandardMaterial3D.new()
	plinth.albedo_color = Color(0.20, 0.21, 0.23)
	plinth.roughness = 0.88
	_slab(Vector3(CELL * 0.72, 0.12, CELL * 0.72), at + Vector3(0, 0.06, 0),
			plinth)
	var label := Label3D.new()
	label.text = label_text
	label.font_size = 64
	# Family labels carry useful qualifiers (the fridge has two eras), but
	# the old scale made those honest names wider than a four-metre bay and
	# hid the neighbouring silhouette. Keep type readable from the aisle
	# without letting typography become another prop in the comparison.
	label.pixel_size = 0.0025
	label.modulate = Color(0.92, 0.93, 0.95)
	label.outline_size = 8
	label.outline_modulate = Color(0.05, 0.05, 0.06, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at + Vector3(0, 0.20, CELL * 0.42)
	add_child(label)


func _slab(size: Vector3, at: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	add_child(mi)


## Where the debug panel drops you: eye height, backed up against the near
## wall INSIDE the shed, facing the whole floor. The first version put the
## stand at 0.6 x the hall's width along z, which is past the wall - you
## arrived outside the building looking at its blank elevation.
## The hall as a volume, for whoever needs to know standing here is
## legitimate (the SafetyNet, chiefly).
func hall_aabb() -> AABB:
	return AABB(ORIGIN - Vector3(_hall.x * 0.5 + 1.0, 1.5,
			_hall.y * 0.5 + 1.0),
			Vector3(_hall.x + 2.0, HALL_H + 3.0, _hall.y + 2.0))


func viewing_stand() -> Vector3:
	return ORIGIN + Vector3(0.0, 1.7, _hall.y * 0.5 - 1.4)


## Combined bounds of everything the prop actually drew, in its own
## space. Empty AABB if it drew nothing.
func _content_bounds(root: Node3D) -> AABB:
	var found := false
	var out := AABB()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D and n.mesh != null:
			var a: AABB = n.get_aabb()
			a = (root.global_transform.affine_inverse()
					* n.global_transform) * a
			out = a if not found else out.merge(a)
			found = true
	return out if found else AABB()


## A stub of ceiling for the things that hang off one.
func _soffit(at: Vector3) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.30, 0.31)
	m.roughness = 0.92
	_slab(Vector3(CELL * 0.72, 0.10, CELL * 0.72),
			at + Vector3(0, SOFFIT_Y + 0.05, 0), m)


## A stub of wall for the things that hang off one. It stands at the back
## of the cell so the fixture still faces the aisle.
func _stub_wall(at: Vector3) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.34, 0.33, 0.31)
	m.roughness = 0.90
	_slab(Vector3(CELL * 0.72, 2.10, 0.10),
			at + Vector3(0, 1.17, -CELL * 0.31), m)
