extends Node3D
## Development-only Orison v2 gray-box. One semantic JSON record owns spaces,
## doors, stairs, risers and anchors; every visible/collision node derives from it.

@export_file("*.json") var layout_path := "res://data/orison_v2_blockout.json"
@export var show_ceilings := true
@export var show_clearance_anchors := true
@export var hold_route_doors_open := true

var layout: Dictionary = {}
var level_y: Dictionary = {}
var materials: Dictionary = {}
var failures: Array[String] = []
const SemanticAnchor := preload("res://scripts/building/orison_v2_semantic_anchor.gd")
## Matches the tolerance the committed suite already used for overlaps.
const OVERLAP_TOLERANCE_M2 := 0.0001

func _ready() -> void:
	layout = _load_layout(layout_path)
	if layout.is_empty():
		return
	_validate_layout()
	if not failures.is_empty():
		for failure in failures:
			push_error("ORISON V2: " + failure)
		push_error("ORISON V2 BLOCKOUT REFUSED: %d validation failure(s) in %s;"
				% [failures.size(), layout_path]
				+ " no geometry was built and the selector group was not joined.")
		return
	_build_palette()
	_build_spaces()
	_build_single_owner_opening_frames()
	_build_doors()
	_build_windows()
	_build_envelopes()
	_build_fixtures()
	_build_platforms()
	_build_lift_landings()
	_build_stairs()
	_build_risers()
	_build_anchors()
	add_to_group("orison_v2_blockout")
	print("ORISON V2 BLOCKOUT: %d spaces / %d doors / %d anchors" % [
		layout.spaces.size(), layout.doors.size(), layout.anchors.size()])

func _load_layout(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("ORISON V2 layout missing: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("ORISON V2 layout is not a JSON object")
		return {}
	return parsed

func _validate_layout() -> void:
	if int(layout.get("schema_version", 0)) != 1:
		failures.append("unsupported schema_version")
	if bool(layout.get("production_default", true)):
		failures.append("development blockout may not be production_default")
	var ids := {}
	for level: Dictionary in layout.get("levels", []):
		var ident := str(level.get("id", ""))
		if ident.is_empty() or level_y.has(ident):
			failures.append("invalid or duplicate level id: " + ident)
		level_y[ident] = float(level.get("y", 0.0))
	for table in ["spaces", "doors", "openings", "windows", "envelopes", "fixtures", "platforms",
			"lift_landings",
			"anchors", "capsule_stations", "stairs", "risers", "route_edges",
			"service_connections"]:
		for record: Dictionary in layout.get(table, []):
			var ident := str(record.get("id", ""))
			if ident.is_empty() or ids.has(ident):
				failures.append("invalid or duplicate id: " + ident)
			ids[ident] = table
			if record.has("level") and not level_y.has(str(record.level)):
				failures.append("%s references missing level %s" % [ident, record.level])
	for space: Dictionary in layout.get("spaces", []):
		if not _valid_rect(space.get("rect", [])):
			failures.append("invalid space rect: " + str(space.get("id", "?")))
	for riser: Dictionary in layout.get("risers", []):
		if not _valid_rect(riser.get("rect", [])):
			failures.append("invalid riser rect: " + str(riser.get("id", "?")))
	for envelope: Dictionary in layout.get("envelopes", []):
		if not _valid_rect(envelope.get("rect", [])):
			failures.append("invalid envelope rect: " + str(envelope.get("id", "?")))
	for platform: Dictionary in layout.get("platforms", []):
		if not _valid_rect(platform.get("rect", [])):
			failures.append("invalid platform rect: " + str(platform.get("id", "?")))
	_validate_references(ids)
	_validate_room_overlaps()
	_validate_single_owner_openings()
	for required in ["F01_DOOR_06", "F02_DOOR_02", "F04_DOOR_03",
			"F02_A_MAIN_VANTRY_POINT", "F04_B_MONITOR_01", "F04_B_BED",
			"F01_WATCHMAN_DETECTOR", "F01_NIGHT_REGISTER",
			"F01_SIGNAL_REGISTER", "F01_TOUR_KEY_GUARD",
			"F02_B_RADIATOR_01", "B1_BOILER_01"]:
		if not ids.has(required):
			failures.append("required compatibility id missing: " + required)

## Every cross-record reference must name a record the layout declares.
## Nothing checked them before, and both failure modes were silent: a leaf
## whose `connects` named a missing space built as a frame against the solid
## wall it should have pierced, and a stair whose `from` named a missing
## level threw inside _build_u_stair - which aborts only that one call, so
## the build continued, printed its success census, joined the selector
## group and exited 0 with the stair simply absent.
func _validate_references(ids: Dictionary) -> void:
	for door: Dictionary in layout.get("doors", []):
		for target: Variant in door.get("connects", []):
			_require_record(ids, str(door.get("id", "?")), str(target),
					"spaces", "door connects")
	for opening: Dictionary in layout.get("openings", []):
		for target: Variant in opening.get("connects", []):
			_require_record(ids, str(opening.get("id", "?")), str(target),
					"spaces", "opening connects")
	for window: Dictionary in layout.get("windows", []):
		_require_record(ids, str(window.get("id", "?")),
				str(window.get("space", "")), "spaces", "window space")
	for landing: Dictionary in layout.get("lift_landings", []):
		_require_record(ids, str(landing.get("id", "?")),
				str(landing.get("shaft", "")), "risers", "lift landing shaft")
	for stair: Dictionary in layout.get("stairs", []):
		for key: String in ["from", "to"]:
			_require_level(str(stair.get("id", "?")), str(stair.get(key, "")),
					"stair " + key)
	for edge: Dictionary in layout.get("route_edges", []):
		for key: String in ["from", "to", "via"]:
			_require_record(ids, str(edge.get("id", "?")), str(edge.get(key, "")),
					"", "route edge " + key)
	for connection: Dictionary in layout.get("service_connections", []):
		for key: String in ["from", "to"]:
			_require_record(ids, str(connection.get("id", "?")),
					str(connection.get(key, "")), "", "service connection " + key)

## `table` empty means "any declared record"; otherwise the reference must
## also come from that table, so a door cannot connect to a riser.
func _require_record(ids: Dictionary, owner: String, value: String,
		table: String, what: String) -> void:
	if value.is_empty():
		failures.append("%s has an empty %s reference" % [owner, what])
	elif not ids.has(value):
		failures.append("%s %s references undeclared record %s"
				% [owner, what, value])
	elif not table.is_empty() and str(ids[value]) != table:
		failures.append("%s %s must name a %s record, but %s is declared in %s"
				% [owner, what, table, value, ids[value]])

func _require_level(owner: String, value: String, what: String) -> void:
	if value.is_empty():
		failures.append("%s has an empty %s reference" % [owner, what])
	elif not level_y.has(value):
		failures.append("%s %s references missing level %s" % [owner, what, value])

## Two rooms on one level may not interpenetrate. Overlap used to be checked
## only in the test suite and only for hardcoded id prefixes (F04_B_*, and
## B1_*/F02_B_*), so a newly built floor got no check at all.
##
## Spaces conflict only when BOTH of them build walls. An `open_shell` space
## builds no enclosure (see _build_spaces): it is a declared zone, and the
## street/rear aprons and the F02/F04 landing decision zones deliberately lie
## inside a core. Marking a room open_shell to dodge this check is not a free
## pass - the completeness ledger reports an open_shell space as SHELL_ONLY,
## which blocks structural readiness for its floor and its unit.
func _validate_room_overlaps() -> void:
	var walled: Array[Dictionary] = []
	for space: Dictionary in layout.get("spaces", []):
		if bool(space.get("open_shell", false)):
			continue
		if _valid_rect(space.get("rect", [])):
			walled.append(space)
	for i in walled.size():
		for j in range(i + 1, walled.size()):
			var a: Dictionary = walled[i]
			var b: Dictionary = walled[j]
			if str(a.get("level", "")) != str(b.get("level", "")):
				continue
			var overlap := _rect_overlap_area(a.rect, b.rect)
			if overlap > OVERLAP_TOLERANCE_M2:
				failures.append("%s overlaps %s on level %s by %.3f m2"
						% [str(a.id), str(b.id), str(a.get("level", "?")), overlap])

## A `shared_wall_owner` opening is a single-partition contract. Adjacent room
## shells may each describe their full perimeter, but only the named owner may
## construct the shared overlap and subtract the aperture. The other shell
## omits only that shared interval; its wall beyond the shared boundary remains.
## This lets a second floor use the same data path without duplicating a wall,
## guessing a cut, or erasing an unrelated run of enclosure.
func _validate_single_owner_openings() -> void:
	var spaces := {}
	var contracts := {}
	for space: Dictionary in layout.get("spaces", []):
		spaces[str(space.get("id", ""))] = space
	for opening: Dictionary in layout.get("openings", []):
		if not opening.has("shared_wall_owner"):
			continue
		var ident := str(opening.get("id", "?"))
		var connects: Array = opening.get("connects", [])
		if connects.size() != 2:
			failures.append("%s single-owner opening must connect exactly two spaces" % ident)
			continue
		var a_id := str(connects[0])
		var b_id := str(connects[1])
		if not spaces.has(a_id) or not spaces.has(b_id):
			# Missing endpoints are already reported by _validate_references.
			continue
		var a: Dictionary = spaces[a_id]
		var b: Dictionary = spaces[b_id]
		var owner := str(opening.get("shared_wall_owner", ""))
		if owner not in [a_id, b_id]:
			failures.append("%s shared_wall_owner must name one connected space" % ident)
			continue
		var pair := [a_id, b_id]
		pair.sort()
		var contract_key := "%s:%s:%s" % [str(opening.get("level", "")),
				str(pair[0]), str(pair[1])]
		if contracts.has(contract_key):
			var prior: Dictionary = contracts[contract_key]
			if str(prior.owner) != owner:
				failures.append("%s conflicts with %s shared-wall owner" % [
						ident, str(prior.ident)])
		else:
			contracts[contract_key] = {"ident": ident, "owner": owner,
					"endpoint_ids": pair, "intervals": []}
		if str(a.get("level", "")) != str(opening.get("level", "")) \
				or str(b.get("level", "")) != str(opening.get("level", "")):
			failures.append("%s endpoints must share its declared level" % ident)
		var boundary := _shared_boundary(a, b)
		if boundary.is_empty():
			failures.append("%s endpoints do not share a positive-length wall" % ident)
			continue
		if str(opening.get("axis", "")) != str(boundary.axis):
			failures.append("%s axis does not match its shared wall" % ident)
		var center: Array = opening.get("center", [])
		if center.size() != 2:
			failures.append("%s has no valid center" % ident)
			continue
		var fixed := float(center[1] if str(boundary.axis) == "x" else center[0])
		var along := float(center[0] if str(boundary.axis) == "x" else center[1])
		var width := float(opening.get("width", 0.0))
		var height := float(opening.get("height", 0.0))
		if not is_equal_approx(fixed, float(boundary.fixed)):
			failures.append("%s is not on its endpoints' shared wall" % ident)
		if width < 0.91 or height < 2.13:
			failures.append("%s is smaller than the maintenance-route minimum" % ident)
		if height > float(layout.dimensions.clear_height) + 0.001:
			failures.append("%s exceeds the clear storey height" % ident)
		if along - width * 0.5 < float(boundary.start) - 0.001 \
				or along + width * 0.5 > float(boundary.finish) + 0.001:
			failures.append("%s does not lie entirely on the shared boundary" % ident)
		var contract: Dictionary = contracts[contract_key]
		var interval := Vector2(along - width * 0.5, along + width * 0.5)
		for prior_interval: Vector2 in contract.intervals:
			if minf(interval.y, prior_interval.y) \
					- maxf(interval.x, prior_interval.x) > 0.001:
				failures.append("%s overlaps another single-owner aperture" % ident)
		contract.intervals.append(interval)
		var owner_space: Dictionary = spaces[owner]
		var owner_side := str(boundary.a_side if owner == a_id else boundary.b_side)
		if not _space_owns_side(owner_space, owner_side):
			failures.append("%s named owner does not author the shared wall side" % ident)
	_validate_single_owner_partition_apertures(contracts, spaces)

func _validate_single_owner_partition_apertures(contracts: Dictionary,
		spaces: Dictionary) -> void:
	for key: String in contracts:
		var contract: Dictionary = contracts[key]
		var endpoint_ids: Array = contract.endpoint_ids
		var boundary := _shared_boundary(spaces[str(endpoint_ids[0])],
				spaces[str(endpoint_ids[1])])
		if boundary.is_empty():
			continue
		for door: Dictionary in layout.get("doors", []):
			if _record_cuts_contract_partition(door, endpoint_ids, boundary):
				failures.append("%s conflicts with %s single-owner partition" % [
						str(door.get("id", "?")), str(contract.ident)])
		for opening: Dictionary in layout.get("openings", []):
			if opening.has("shared_wall_owner"):
				continue
			if _record_cuts_contract_partition(opening, endpoint_ids, boundary):
				failures.append("%s conflicts with %s single-owner partition" % [
						str(opening.get("id", "?")), str(contract.ident)])
		for window: Dictionary in layout.get("windows", []):
			if str(window.get("space", "")) not in endpoint_ids:
				continue
			if _record_on_boundary(window, boundary):
				failures.append("%s conflicts with %s single-owner partition" % [
						str(window.get("id", "?")), str(contract.ident)])

func _record_cuts_contract_partition(record: Dictionary, endpoint_ids: Array,
		boundary: Dictionary) -> bool:
	var connects: Array = record.get("connects", [])
	if not connects.any(func(endpoint: Variant) -> bool:
			return str(endpoint) in endpoint_ids):
		return false
	return _record_on_boundary(record, boundary)

func _record_on_boundary(record: Dictionary, boundary: Dictionary) -> bool:
	var center: Array = record.get("center", [])
	if center.size() != 2:
		return false
	if record.has("axis") and str(record.get("axis", "")) != str(boundary.axis):
		return false
	var fixed := float(center[1] if str(boundary.axis) == "x" else center[0])
	if not is_equal_approx(fixed, float(boundary.fixed)):
		return false
	var along := float(center[0] if str(boundary.axis) == "x" else center[1])
	var half_width := float(record.get("width", 0.0)) * 0.5
	return minf(along + half_width, float(boundary.finish)) \
			- maxf(along - half_width, float(boundary.start)) > 0.001

func _space_owns_side(space: Dictionary, side: String) -> bool:
	return not bool(space.get("open_shell", false)) \
			and side in space.get("wall_sides", ["south", "north", "west", "east"])

func _shared_boundary(a: Dictionary, b: Dictionary) -> Dictionary:
	var ar: Array = a.get("rect", [])
	var br: Array = b.get("rect", [])
	if not _valid_rect(ar) or not _valid_rect(br):
		return {}
	var z_start := maxf(float(ar[1]), float(br[1]))
	var z_finish := minf(float(ar[3]), float(br[3]))
	if z_finish - z_start > 0.001 and is_equal_approx(float(ar[2]), float(br[0])):
		return {"a_side": "east", "b_side": "west", "axis": "z",
				"fixed": float(ar[2]), "start": z_start, "finish": z_finish}
	if z_finish - z_start > 0.001 and is_equal_approx(float(ar[0]), float(br[2])):
		return {"a_side": "west", "b_side": "east", "axis": "z",
				"fixed": float(ar[0]), "start": z_start, "finish": z_finish}
	var x_start := maxf(float(ar[0]), float(br[0]))
	var x_finish := minf(float(ar[2]), float(br[2]))
	if x_finish - x_start > 0.001 and is_equal_approx(float(ar[3]), float(br[1])):
		return {"a_side": "north", "b_side": "south", "axis": "x",
				"fixed": float(ar[3]), "start": x_start, "finish": x_finish}
	if x_finish - x_start > 0.001 and is_equal_approx(float(ar[1]), float(br[3])):
		return {"a_side": "south", "b_side": "north", "axis": "x",
				"fixed": float(ar[1]), "start": x_start, "finish": x_finish}
	return {}

func _rect_overlap_area(a: Array, b: Array) -> float:
	var across := minf(float(a[2]), float(b[2])) - maxf(float(a[0]), float(b[0]))
	var deep := minf(float(a[3]), float(b[3])) - maxf(float(a[1]), float(b[1]))
	return maxf(0.0, across) * maxf(0.0, deep)

func _valid_rect(value: Variant) -> bool:
	return value is Array and value.size() == 4 \
			and float(value[0]) < float(value[2]) and float(value[1]) < float(value[3])

func _build_palette() -> void:
	for key: String in layout.get("palette", {}):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.html(str(layout.palette[key]))
		mat.roughness = 0.9
		if key in ["clearance", "interaction", "unresolved"]:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.32
		materials[key] = mat

func _build_spaces() -> void:
	var dims: Dictionary = layout.dimensions
	var clear_h := float(dims.clear_height)
	var slab_t := float(dims.slab_thickness)
	for space: Dictionary in layout.spaces:
		var rect: Array = space.rect
		var y := float(level_y[space.level])
		var cls := str(space.get("class", "unresolved"))
		var parent := Node3D.new()
		parent.name = str(space.id)
		parent.set_meta("purpose", str(space.get("purpose", "")))
		parent.set_meta("room_id", str(space.id))
		add_child(parent)
		if not bool(space.get("no_floor", false)):
			_box(parent, "Floor", _rect_center(rect, y - slab_t * 0.5),
					Vector3(_rect_w(rect), slab_t, _rect_d(rect)), cls, true)
		if show_ceilings and not bool(space.get("no_ceiling", false)):
			_box(parent, "Ceiling", _rect_center(rect, y + clear_h + slab_t * 0.5),
					Vector3(_rect_w(rect), slab_t, _rect_d(rect)), cls, false)
		if not bool(space.get("open_shell", false)):
			_build_space_outline(parent, str(space.id), rect, y, clear_h, cls,
					space.get("wall_sides", ["south", "north", "west", "east"]))

func _build_space_outline(parent: Node3D, space_id: String, rect: Array, y: float,
		height: float, cls: String, sides: Array) -> void:
	var t := float(layout.dimensions.partition_wall)
	if "south" in sides:
		_wall_with_openings(parent, space_id, "South", "x", float(rect[1]),
				float(rect[0]), float(rect[2]), y, height, t, cls)
	if "north" in sides:
		_wall_with_openings(parent, space_id, "North", "x", float(rect[3]),
				float(rect[0]), float(rect[2]), y, height, t, cls)
	if "west" in sides:
		_wall_with_openings(parent, space_id, "West", "z", float(rect[0]),
				float(rect[1]), float(rect[3]), y, height, t, cls)
	if "east" in sides:
		_wall_with_openings(parent, space_id, "East", "z", float(rect[2]),
				float(rect[1]), float(rect[3]), y, height, t, cls)

func _wall_with_openings(parent: Node3D, space_id: String, label: String,
		axis: String, fixed: float, start: float, finish: float, y: float,
		height: float, thickness: float, cls: String) -> void:
	var openings: Array[Dictionary] = []
	for door: Dictionary in layout.doors:
		if not space_id in door.connects:
			continue
		var on_wall := (is_equal_approx(float(door.center[1]), fixed) if axis == "x"
				else is_equal_approx(float(door.center[0]), fixed))
		if on_wall:
			openings.append({"center": float(door.center[0] if axis == "x" else door.center[1]),
					"width": float(door.width), "height": float(door.height), "sill": 0.0})
	var omitted_shared_walls := {}
	for opening: Dictionary in layout.get("openings", []):
		if not space_id in opening.connects or str(opening.axis) != axis:
			continue
		if opening.has("shared_wall_owner") \
				and str(opening.shared_wall_owner) != space_id:
			var omission := _shared_wall_omission(opening, space_id, axis, fixed)
			if not omission.is_empty():
				var omission_key := "%s:%.4f:%.4f" % [axis,
						float(omission.center), float(omission.width)]
				if not omitted_shared_walls.has(omission_key):
					openings.append(omission)
					omitted_shared_walls[omission_key] = true
			continue
		var fixed_value := float(opening.center[1] if axis == "x" else opening.center[0])
		if is_equal_approx(fixed_value, fixed):
			openings.append({"center": float(opening.center[0] if axis == "x" else opening.center[1]),
					"width": float(opening.width), "height": float(opening.height), "sill": 0.0})
	for window: Dictionary in layout.get("windows", []):
		if str(window.space) != space_id or str(window.axis) != axis:
			continue
		var fixed_value := float(window.center[1] if axis == "x" else window.center[0])
		if is_equal_approx(fixed_value, fixed):
			openings.append({"center": float(window.center[0] if axis == "x" else window.center[1]),
					"width": float(window.width), "height": float(window.height),
					"sill": float(window.sill)})
	openings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.center) < float(b.center))
	var cursor := start
	var part := 0
	for opening: Dictionary in openings:
		var lo := maxf(start, float(opening.center) - float(opening.width) * 0.5)
		var hi := minf(finish, float(opening.center) + float(opening.width) * 0.5)
		if lo > cursor + 0.001:
			_wall_segment(parent, "Wall%s_%02d" % [label, part], axis, fixed,
					cursor, lo, y, height, thickness, cls)
			part += 1
		var sill := float(opening.get("sill", 0.0))
		if sill > 0.001:
			_wall_segment(parent, "Wall%s_Sill%02d" % [label, part], axis, fixed,
					lo, hi, y, sill, thickness, cls)
			part += 1
		var head_base := sill + float(opening.height)
		var head_h := height - head_base
		if head_h > 0.001:
			_wall_segment(parent, "Wall%s_Head%02d" % [label, part], axis, fixed,
					lo, hi, y + head_base, head_h, thickness, cls)
			part += 1
		cursor = maxf(cursor, hi)
	if cursor < finish - 0.001:
		_wall_segment(parent, "Wall%s_%02d" % [label, part], axis, fixed,
				cursor, finish, y, height, thickness, cls)

func _shared_wall_omission(opening: Dictionary, space_id: String,
		axis: String, fixed: float) -> Dictionary:
	var connects: Array = opening.get("connects", [])
	if connects.size() != 2:
		return {}
	var other_id := str(connects[1] if str(connects[0]) == space_id else connects[0])
	var here := _space_by_id(space_id)
	var other := _space_by_id(other_id)
	if here.is_empty() or other.is_empty():
		return {}
	var boundary := _shared_boundary(here, other)
	if boundary.is_empty() or str(boundary.axis) != axis \
			or not is_equal_approx(float(boundary.fixed), fixed):
		return {}
	return {"center": (float(boundary.start) + float(boundary.finish)) * 0.5,
			"width": float(boundary.finish) - float(boundary.start),
			"height": float(layout.dimensions.clear_height), "sill": 0.0}

func _space_by_id(space_id: String) -> Dictionary:
	for space: Dictionary in layout.get("spaces", []):
		if str(space.get("id", "")) == space_id:
			return space
	return {}

## A leafless maintenance opening still needs to read as a deliberate cased
## connection. These three non-colliding reveal pieces are derived from the
## same generic record that cuts the owner wall; they add no second collision
## authority and cannot narrow the declared clear aperture.
func _build_single_owner_opening_frames() -> void:
	var wall_depth := float(layout.dimensions.partition_wall) + 0.04
	var reveal_width := 0.09
	for opening: Dictionary in layout.get("openings", []):
		if not opening.has("shared_wall_owner"):
			continue
		var parent := Node3D.new()
		parent.name = str(opening.id)
		parent.position = Vector3(float(opening.center[0]),
				float(level_y[opening.level]), float(opening.center[1]))
		parent.set_meta("connects", opening.connects)
		parent.set_meta("shared_wall_owner", str(opening.shared_wall_owner))
		parent.set_meta("non_colliding_reveal", true)
		add_child(parent)
		var width := float(opening.width)
		var height := float(opening.height)
		if str(opening.axis) == "x":
			_box(parent, "RevealA", Vector3(-width * 0.5 - reveal_width * 0.5,
					height * 0.5, 0.0), Vector3(reveal_width, height, wall_depth),
					"opening", false)
			_box(parent, "RevealB", Vector3(width * 0.5 + reveal_width * 0.5,
					height * 0.5, 0.0), Vector3(reveal_width, height, wall_depth),
					"opening", false)
			_box(parent, "RevealHead", Vector3(0.0, height + reveal_width * 0.5,
					0.0), Vector3(width + reveal_width * 2.0, reveal_width,
					wall_depth), "opening", false)
		else:
			_box(parent, "RevealA", Vector3(0.0, height * 0.5,
					-width * 0.5 - reveal_width * 0.5),
					Vector3(wall_depth, height, reveal_width), "opening", false)
			_box(parent, "RevealB", Vector3(0.0, height * 0.5,
					width * 0.5 + reveal_width * 0.5),
					Vector3(wall_depth, height, reveal_width), "opening", false)
			_box(parent, "RevealHead", Vector3(0.0, height + reveal_width * 0.5,
					0.0), Vector3(wall_depth, reveal_width,
					width + reveal_width * 2.0), "opening", false)
		_build_service_opening_practical(parent, opening)

## A source-owned bulkhead practical makes a leafless service connection read
## as maintained circulation in the actual blockout, not only in a capture.
## It is derived for every single-owner opening and carries no collision.
func _build_service_opening_practical(parent: Node3D,
		opening: Dictionary) -> void:
	var practical := Node3D.new()
	practical.name = "ServicePractical"
	practical.position.y = minf(float(opening.height) + 0.16,
			float(layout.dimensions.clear_height) - 0.16)
	practical.set_meta("source_owned_service_practical", true)
	parent.add_child(practical)
	var wall_axis := str(opening.axis)
	var backplate_size := Vector3(0.12, 0.20, 0.46) \
			if wall_axis == "z" else Vector3(0.46, 0.20, 0.12)
	var lens_size := Vector3(0.18, 0.12, 0.30) \
			if wall_axis == "z" else Vector3(0.30, 0.12, 0.18)
	_box(practical, "Backplate", Vector3.ZERO, backplate_size,
			"service", false)
	var lens := _box(practical, "OpalLens", Vector3(0.0, -0.12, 0.0),
			lens_size, "opening", false)
	var lens_material := StandardMaterial3D.new()
	lens_material.albedo_color = Color(0.92, 0.72, 0.46)
	lens_material.roughness = 0.72
	lens_material.emission_enabled = true
	lens_material.emission = Color(1.0, 0.62, 0.30)
	lens_material.emission_energy_multiplier = 1.5
	(lens.mesh as BoxMesh).material = lens_material
	var light := OmniLight3D.new()
	light.name = "WarmServiceLight"
	light.position = Vector3(0.0, -0.22, 0.0)
	light.light_color = Color(1.0, 0.72, 0.45)
	light.light_energy = 3.2
	light.omni_range = 4.8
	light.omni_attenuation = 1.25
	light.shadow_enabled = true
	practical.add_child(light)

func _wall_segment(parent: Node3D, node_name: String, axis: String, fixed: float,
		start: float, finish: float, y: float, height: float, thickness: float,
		cls: String) -> void:
	var center := (start + finish) * 0.5
	if axis == "x":
		_box(parent, node_name, Vector3(center, y + height * 0.5, fixed),
				Vector3(finish - start, height, thickness), cls, true)
	else:
		_box(parent, node_name, Vector3(fixed, y + height * 0.5, center),
				Vector3(thickness, height, finish - start), cls, true)

func _build_doors() -> void:
	for door: Dictionary in layout.doors:
		var parent := Node3D.new()
		parent.name = str(door.id)
		parent.set_meta("connects", door.connects)
		parent.set_meta("hinge", str(door.hinge))
		parent.set_meta("swing", str(door.swing))
		var y := float(level_y[door.level])
		parent.position = Vector3(float(door.center[0]), y, float(door.center[1]))
		parent.rotation.y = float(door.yaw)
		add_child(parent)
		var width := float(door.width)
		var height := float(door.height)
		var hinge := Node3D.new()
		hinge.name = "Hinge"
		var hinge_sign := -1.0 if str(door.hinge) == "left" else 1.0
		hinge.position.x = hinge_sign * width * 0.5
		if hold_route_doors_open:
			hinge.rotation.y = hinge_sign * PI * 0.5
		parent.add_child(hinge)
		var latch := Marker3D.new()
		latch.name = "Latch"
		latch.position = Vector3(-hinge_sign * width * 0.5, height * 0.5, 0.0)
		parent.add_child(latch)
		_box(hinge, "Leaf", Vector3(-hinge_sign * width * 0.5, height * 0.5, 0.0),
				Vector3(width, height, 0.045), "opening", not hold_route_doors_open)
		_box(parent, "FrameLeft", Vector3(-width * 0.5 - 0.045, height * 0.5, 0.0),
				Vector3(0.09, height, 0.10), "core", false)
		_box(parent, "FrameRight", Vector3(width * 0.5 + 0.045, height * 0.5, 0.0),
				Vector3(0.09, height, 0.10), "core", false)
		_box(parent, "FrameHead", Vector3(0.0, height + 0.045, 0.0),
				Vector3(width + 0.18, 0.09, 0.10), "core", false)

func _build_windows() -> void:
	for window: Dictionary in layout.get("windows", []):
		var parent := Node3D.new()
		parent.name = str(window.id)
		var y := float(level_y[window.level])
		parent.position = Vector3(float(window.center[0]), y, float(window.center[1]))
		add_child(parent)
		var width := float(window.width)
		var height := float(window.height)
		var sill := float(window.sill)
		var size := (Vector3(width, height, 0.025) if str(window.axis) == "x"
				else Vector3(0.025, height, width))
		_box(parent, "Glazing", Vector3(0.0, sill + height * 0.5, 0.0),
				size, "opening", false)
		var jamb_size := (Vector3(0.07, height, 0.10) if str(window.axis) == "x"
				else Vector3(0.10, height, 0.07))
		var offset_a := (Vector3(-width * 0.5, sill + height * 0.5, 0.0)
				if str(window.axis) == "x" else Vector3(0.0, sill + height * 0.5, -width * 0.5))
		var offset_b := -offset_a + Vector3(0.0, (sill + height * 0.5) * 2.0, 0.0)
		# The second expression above preserves the same Y while mirroring only plan offset.
		offset_b.y = offset_a.y
		_box(parent, "JambA", offset_a, jamb_size, "core", false)
		_box(parent, "JambB", offset_b, jamb_size, "core", false)

func _build_envelopes() -> void:
	for envelope: Dictionary in layout.get("envelopes", []):
		var rect: Array = envelope.rect
		var height := float(envelope.get("height", 0.02))
		var y := float(level_y[envelope.level])
		var node := _box(self, str(envelope.id), _rect_center(rect, y + height * 0.5),
				Vector3(_rect_w(rect), height, _rect_d(rect)),
				str(envelope.get("class", "unresolved")), false)
		node.set_meta("purpose", str(envelope.get("purpose", "")))

func _build_fixtures() -> void:
	for fixture: Dictionary in layout.get("fixtures", []):
		var p: Array = fixture.position
		var s: Array = fixture.size
		var node := _box(self, str(fixture.id), Vector3(float(p[0]),
				float(level_y[fixture.level]) + float(p[1]), float(p[2])),
				Vector3(float(s[0]), float(s[1]), float(s[2])),
				str(fixture.get("class", "unresolved")),
				bool(fixture.get("collision", true)))
		node.set_meta("purpose", str(fixture.get("purpose", "")))

func _build_platforms() -> void:
	var slab_t := float(layout.dimensions.slab_thickness)
	for platform: Dictionary in layout.get("platforms", []):
		var rect: Array = platform.rect
		var y := float(level_y[platform.level])
		_box(self, str(platform.id), _rect_center(rect, y - slab_t * 0.5),
				Vector3(_rect_w(rect), slab_t, _rect_d(rect)),
				str(platform.get("class", "core")), true)

func _build_lift_landings() -> void:
	for landing: Dictionary in layout.get("lift_landings", []):
		var parent := Node3D.new()
		parent.name = str(landing.id)
		parent.position = Vector3(float(landing.center[0]), float(level_y[landing.level]),
				float(landing.center[1]))
		parent.rotation.y = float(landing.yaw)
		parent.set_meta("shaft", str(landing.shaft))
		add_child(parent)
		var width := float(landing.width)
		var height := float(landing.height)
		_box(parent, "JambL", Vector3(-width * 0.5 - 0.045, height * 0.5, 0.0),
				Vector3(0.09, height, 0.10), "core", false)
		_box(parent, "JambR", Vector3(width * 0.5 + 0.045, height * 0.5, 0.0),
				Vector3(0.09, height, 0.10), "core", false)
		_box(parent, "Head", Vector3(0.0, height + 0.045, 0.0),
				Vector3(width + 0.18, 0.09, 0.10), "core", false)
		_box(parent, "Clearance", Vector3(0.0, 0.01, float(landing.clear_depth) * 0.5),
				Vector3(maxf(width, 1.5), 0.02, float(landing.clear_depth)),
				"clearance", false)

func _build_stairs() -> void:
	for stair: Dictionary in layout.stairs:
		var parent := Node3D.new()
		parent.name = str(stair.id)
		add_child(parent)
		if str(stair.get("kind", "")) == "u":
			_build_u_stair(parent, stair)

func _build_u_stair(parent: Node3D, stair: Dictionary) -> void:
	var base_y := float(level_y[stair.from])
	var rise := float(stair.rise)
	var tread := float(stair.tread)
	var count := int(stair.risers_per_flight)
	var width := float(stair.width)
	var gap := float(stair.gap)
	var x0 := float(stair.origin[0])
	var z0 := float(stair.origin[1])
	var run := tread * count
	var half_rise := rise * count
	var guard_h := float(stair.guard_height)
	for i in count:
		var step_h := rise * (i + 1)
		var z := z0 + tread * (i + 0.5)
		_box(parent, "FlightA_Step%02d" % i,
				Vector3(x0 + width * 0.5, base_y + step_h * 0.5, z),
				Vector3(width, step_h, tread), "core", true)
		_box(parent, "FlightA_Guard%02d" % i,
				Vector3(x0 + 0.025, base_y + step_h + guard_h * 0.5, z),
				Vector3(0.05, guard_h, tread), "core", false)
	_ramp_collision(parent, "FlightATraversalRamp",
			Vector3(x0 + width * 0.5, base_y + half_rise * 0.5,
					z0 + run * 0.5), width, run, half_rise, -1.0)
	var landing_depth := float(stair.landing_depth)
	# A body needs clear standing room beyond the return flight's first nosing in
	# order to execute the U-turn; the semantic depth describes the clear landing.
	var turn_clearance := 0.7
	_box(parent, "HalfLanding",
			Vector3(x0 + width + gap * 0.5, base_y + half_rise - 0.1,
					z0 + run + (landing_depth + turn_clearance) * 0.5),
			Vector3(width * 2.0 + gap, 0.2, landing_depth + turn_clearance), "core", true)
	_box(parent, "HalfLandingGuard",
			Vector3(x0 + width + gap * 0.5, base_y + half_rise + guard_h * 0.5,
					z0 + run + landing_depth + turn_clearance - 0.025),
			Vector3(width * 2.0 + gap, guard_h, 0.05), "core", false)
	var x_b := x0 + width + gap
	var north_start := z0 + run + landing_depth
	for i in count:
		var step_h := rise * (i + 1)
		var z := north_start - tread * (i + 0.5)
		_box(parent, "FlightB_Step%02d" % i,
				Vector3(x_b + width * 0.5, base_y + half_rise + step_h * 0.5, z),
				Vector3(width, step_h, tread), "core", true)
		_box(parent, "FlightB_Guard%02d" % i,
				Vector3(x_b + width - 0.025,
						base_y + half_rise + step_h + guard_h * 0.5, z),
				Vector3(0.05, guard_h, tread), "core", false)
	_ramp_collision(parent, "FlightBTraversalRamp",
			Vector3(x_b + width * 0.5, base_y + half_rise + half_rise * 0.5,
					north_start - run * 0.5), width, run, half_rise, 1.0)

func _ramp_collision(parent: Node3D, node_name: String, at: Vector3,
		width: float, run: float, rise: float, direction: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	body.rotation.x = direction * atan2(rise, run)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width - 0.04, 0.05, sqrt(run * run + rise * rise))
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)

func _build_risers() -> void:
	for riser: Dictionary in layout.risers:
		var rect: Array = riser.rect
		var y0 := float(riser.from_y)
		var y1 := float(riser.to_y)
		_box(self, str(riser.id), _rect_center(rect, (y0 + y1) * 0.5),
				Vector3(_rect_w(rect), y1 - y0, _rect_d(rect)),
				str(riser.get("class", "service")), bool(riser.get("solid", true)))

func _build_anchors() -> void:
	for anchor: Dictionary in layout.anchors:
		var node := SemanticAnchor.new()
		node.name = str(anchor.id)
		var p: Array = anchor.position
		node.position = Vector3(float(p[0]), float(level_y[anchor.level]) + float(p[1]),
				float(p[2]))
		node.rotation.y = float(anchor.get("yaw", 0.0))
		node.set_meta("anchor_kind", str(anchor.kind))
		add_child(node)
		if show_clearance_anchors and str(anchor.kind) in ["interaction", "clearance"]:
			_box(node, "Envelope", Vector3(0.0, 0.01, 0.0), Vector3(0.9, 0.02, 0.9),
					"interaction" if str(anchor.kind) == "interaction" else "clearance", false)

func _box(parent: Node, node_name: String, at: Vector3, size: Vector3,
		material_key: String, collision: bool) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = materials.get(material_key, materials.get("unresolved"))
	mesh_node.mesh = mesh
	mesh_node.position = at
	parent.add_child(mesh_node)
	if collision:
		var body := StaticBody3D.new()
		body.name = "Collision"
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		mesh_node.add_child(body)
	return mesh_node

func _rect_center(rect: Array, y: float) -> Vector3:
	return Vector3((float(rect[0]) + float(rect[2])) * 0.5, y,
			(float(rect[1]) + float(rect[3])) * 0.5)

func _rect_w(rect: Array) -> float:
	return float(rect[2]) - float(rect[0])

func _rect_d(rect: Array) -> float:
	return float(rect[3]) - float(rect[1])
