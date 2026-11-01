extends Node3D
## Chairs and stools, sat on by hand. The cursor finds the seat; a click grabs it,
## pulling the mouse down lowers the body onto it, and the next click lets go, which
## finishes the descent or stands back up by how far it got. Up is the same grip the
## other way, or any walking input. While seated the player still looks and reaches,
## and only walking is held. A seat holds no state of its own and is never saved.

const FURNITURE := "res://data/orison_v2/domestic_furniture.json"
const SEATING := "res://data/orison_v2/domestic_seating.json"
const STOOL_PARTS := "res://data/orison_v2/shop_seating.json"
const CHAIR_VARIANTS := ["ChairDark", "ChairOak", "Armchair"]
## The desk chair belongs to the call desk's own seated owner.
const NOT_FREE := ["4B_desk_chair"]
## Which way each counter's stools face, as player yaw. The news stool has no counter.
const STOOL_YAW := {"storm_shop_luncheonette_stool": -PI * 0.5, "storm_shop_otis___son_stool": 0.0, "retail_bar_stool": 0.0}
const CHAIR_SEAT := 0.478
## A native object with no back is a stool, and its top is the seat.
const BACKLESS_BELOW := 0.9
const REACH := 1.15
const EYE_ABOVE_SEAT := 0.62
const GESTURE_PIXELS := 170.0
const SETTLE_SPEED := 2.6
const FINISH_FROM := 0.5
## A seat has no collider of its own. Some have only a hull far bigger than the seat,
## some none at all, so the hand's ray is measured against the seat point instead.
const AIM_RADIUS := 0.26
const THROUGH_HULL := 0.7
const SUPPORT_ABOVE := 1.2
const SUPPORT_RAY := 1.5
## Anything else moving the body further than this has taken it off the seat.
const TAKEN_AWAY := 0.3

var world: Node3D
var seats: Dictionary = {}
## Seat id -> who has it. A resident's stool is not offered.
var taken: Dictionary = {}
var seat_id := ""
var _built_stools: Dictionary = {}
var travel := 0.0
var held := false
var player: PlayerController
var _stand_position := Vector3.ZERO
var _stand_yaw := 0.0
var _stand_eye := 0.0
var _expected := Vector3.ZERO


func mount(runtime: Node3D, adapter: Variant) -> bool:
	world = runtime
	var furniture: Variant = JSON.parse_string(FileAccess.get_file_as_string(FURNITURE))
	var seating: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEATING))
	if furniture is not Dictionary or seating is not Dictionary:
		return false
	for row: Dictionary in furniture.furniture:
		if str(row.kind) == "chair":
			var high := float(row.bounds[1][1])
			_add_native(adapter, str(row.id), high if high < BACKLESS_BELOW else CHAIR_SEAT)
	for row: Dictionary in seating.instances:
		if str(row.variant) in CHAIR_VARIANTS:
			_add_native(adapter, str(row.id), CHAIR_SEAT)
	_built_stools = _stools_in(load_stool_parts())
	var passage: Node3D = world.passage_region
	for floor: Dictionary in passage.source_layout.floors:
		if str(floor.id) == "F01":
			for row: Dictionary in floor.furniture:
				_add_counter_row(passage, row)
	return not seats.is_empty()


## The source layout still lists stools the shop no longer has.
func load_stool_parts() -> Array:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(STOOL_PARTS))
	return source.cells if source is Dictionary else []


func _stools_in(cells: Array) -> Dictionary:
	var built := {}
	for cell: Dictionary in cells:
		for part: Dictionary in cell.parts:
			built[str(part.name).substr(0, str(part.name).rfind("__"))] = true
	return built


func _add_native(adapter: Variant, identity: String, height: float) -> void:
	if identity in NOT_FREE or seats.has(identity):
		return
	var node := adapter.resolve(identity) as Node3D
	if node != null:
		_add(identity, node, Vector3(0.0, height, 0.0), node.global_rotation.y, true)


func _add_counter_row(passage: Node3D, row: Dictionary) -> void:
	var identity := str(row.id)
	if identity.begins_with("retail_bar_ch"):
		var at: Array = row.at
		var turned := deg_to_rad(float(row.yaw))
		_add(identity, passage, GameBoot.b2g([at[0], at[1], float(row.z0) + CHAIR_SEAT]), turned, false)
	elif identity.begins_with("retail_bar_stool") and identity.ends_with("_seat"):
		var top: Array = row.p1
		_add(identity.trim_suffix("_seat"), passage, GameBoot.b2g(top), float(STOOL_YAW.retail_bar_stool), false)
	elif identity == "storm_shop_news_cigars_stool" or (identity.begins_with("storm_shop_") and identity.ends_with("_top") and identity.contains("_stool")):
		var rect: Array = row.rect
		var name_only := identity.trim_suffix("_top")
		if name_only.contains("_stool") and name_only != "storm_shop_news_cigars_stool" and not _built_stools.has(name_only):
			return
		var yaw: Variant = null
		for prefix: String in STOOL_YAW:
			if name_only.begins_with(prefix):
				yaw = STOOL_YAW[prefix]
		_add(name_only, passage, GameBoot.b2g([(float(rect[0]) + float(rect[2])) * 0.5, (float(rect[1]) + float(rect[3])) * 0.5, float(row.z0) + float(row.h)]), yaw, false)


## Household furniture comes and goes with its streamed cell, so those seats look for
## it when aimed at. The arcade and bar fittings are always mounted, and some stools
## have no collider of their own to look for.
func _add(identity: String, parent: Node3D, local: Vector3, yaw: Variant, streamed: bool) -> void:
	var area := Marker3D.new()
	area.name = "Seat_" + identity
	parent.add_child(area)
	area.position = local
	seats[identity] = {"area": area, "yaw": yaw, "streamed": streamed}


## Not offered: a seat whose chair is not loaded, one a resident is on, or one out of
## a step's reach.
func _grip(identity: String) -> Dictionary:
	var holder := get_tree().get_first_node_in_group("player_controller") as PlayerController
	var area: Node3D = seats[identity].area
	if holder == null or taken.has(identity) or (seat_id != "" and seat_id != identity):
		return {}
	if seat_id == "":
		var apart := area.global_position - holder.global_position
		if Vector2(apart.x, apart.z).length() > REACH or (seats[identity].streamed and not _supported(area)):
			return {}
	return {"owner": self, "part": area, "frame": self, "kind": "slide", "axis": Vector3.DOWN,
		"minimum": 0.0, "maximum": 1.0, "gesture_travel_px": GESTURE_PIXELS,
		"gesture_screen_axis": Vector2.DOWN, "unobstructed_hold": true,
		"read": func(): return travel,
		"write": func(value: float):
			if held:
				travel = value
				_pose(),
		"owns": func(): return held,
		"begin": func(): return _begin(identity, holder),
		"end": func(): held = false}


## The seat the hand's ray passes over, when nothing operable took the ray first.
func aimed(origin: Vector3, direction: Vector3, hit_distance: float) -> Dictionary:
	var best := {}
	var nearest := AIM_RADIUS
	for identity: String in (seats if seat_id == "" else {seat_id: true}):
		var area: Node3D = seats[identity].area
		if not is_instance_valid(area):
			continue
		var along := (area.global_position - origin).dot(direction)
		if along <= 0.0 or along > hit_distance + THROUGH_HULL:
			continue
		var closest := origin + direction * along
		var off := closest.distance_to(area.global_position)
		if off < nearest:
			var grip := _grip(identity)
			if not grip.is_empty():
				nearest = off
				best = grip
				best["hit_position"] = closest
	return best


func _supported(area: Node3D) -> bool:
	var above := area.global_position + Vector3.UP * SUPPORT_ABOVE
	var query := PhysicsRayQueryParameters3D.create(above, above + Vector3.DOWN * SUPPORT_RAY)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _begin(identity: String, holder: PlayerController) -> bool:
	if held:
		return false
	held = true
	if seat_id == "":
		seat_id = identity
		player = holder
		travel = 0.0
		holder._set_crouched(false)
		_stand_position = holder.global_position
		_stand_yaw = holder.rotation.y
		_stand_eye = holder.camera.position.y
		_expected = holder.global_position
		holder.seated_on = self
	return true


func _pose() -> void:
	var area: Node3D = seats[seat_id].area
	var seat := area.global_position
	var at := Vector3(lerpf(_stand_position.x, seat.x, travel), _stand_position.y, lerpf(_stand_position.z, seat.z, travel))
	player.global_position = at
	_expected = at
	player.velocity = Vector3.ZERO
	var yaw: Variant = seats[seat_id].yaw
	if yaw != null:
		var turned := float(yaw) + (_bar_chair_correction() if seat_id.begins_with("retail_bar_ch") else 0.0)
		player.rotation.y = lerp_angle(_stand_yaw, turned, travel)
	player.camera.position.y = lerpf(_stand_eye, seat.y + EYE_ABOVE_SEAT - _stand_position.y, travel)


## The bar's cafe chairs are drawn turned from their source rows by this much.
func _bar_chair_correction() -> float:
	var geometry: Node = world.bar_region.get_node_or_null("RetainedBarGeometry")
	return float(geometry.get_meta("bar_cafe_yaw_correction", 0.0)) if geometry != null else 0.0


## The player's physics tick while a seat has the body.
func hold_player(delta: float) -> void:
	if player.global_position.distance_to(_expected) > TAKEN_AWAY:
		_let_go(false)
		return
	if not held:
		var walking := Input.get_vector("move_left", "move_right", "move_forward", "move_back").length_squared() > 0.0 or player.autopilot != Vector3.ZERO
		var goal := 1.0 if travel >= FINISH_FROM and not walking else 0.0
		if walking:
			travel = minf(travel, FINISH_FROM - 0.01)
		travel = move_toward(travel, goal, SETTLE_SPEED * delta)
		_pose()
		if travel <= 0.0:
			_let_go(true)


func _let_go(back_to_standing: bool) -> void:
	if back_to_standing:
		player.global_position = _stand_position
	player.camera.position.y = _stand_eye
	player.seated_on = null
	seat_id = ""
	travel = 0.0
	held = false


func sitting() -> bool:
	return seat_id != "" and travel >= 1.0 and not held
