extends Node
## Storeys more than one floor from the player cast no shadows (frame time, order wc1f19fbf0c21; Lily's
## ruling city_vs_frametime_20261114, "frame time first"). Floors and ceilings stop moonlight and lamplight, so
## a shadow cast inside a storey two floors away can only fall inside that storey, where the player cannot see
## it. The draw-call census at the third-floor crossing measured those storeys' shadow casting at about a third
## of the frame. The building's shell and fittings that belong to no one storey keep their shadows, and every
## storey is still drawn: only its shadow casting is switched, and only when the player changes floor.
const ORDER: Array[String] = ["B1", "F01", "F02", "F03", "F04", "F05", "F06", "ROOF"]
const CHECK_EVERY := 0.25

var player: Node3D
var _floor_y: Dictionary = {}          # storey -> world height of its floor
var _casters: Dictionary = {}          # storey -> Array of [GeometryInstance3D, original cast_shadow]
var _current := ""
var _since := 0.0
var switches := 0


## `layout`: the blockout layout ({"levels": [{"id", "y"}...]}) or the plan layout ({"floors": [{"id", "z"}...]}). Returns how many shadow casters it governs.
func setup(blockout: Node3D, who: Node3D, layout: Dictionary) -> int:
	player = who
	# ORISON_STOREY_SHADOWS=0 leaves every storey casting, for a like-for-like measurement.
	if OS.get_environment("ORISON_STOREY_SHADOWS") == "0":
		print("[STOREY SHADOWS] off by ORISON_STOREY_SHADOWS=0")
		set_process(false)
		return 0
	# The blockout layout lists "levels" with their world height (y); the plan layout lists "floors" with z.
	for row: Dictionary in layout.get("levels", []):
		if str(row.get("id", "")) in ORDER:
			_floor_y[str(row.id)] = float(row.get("y", 0.0))
	for row: Dictionary in layout.get("floors", []):
		if str(row.get("id", "")) in ORDER and not _floor_y.has(str(row.id)):
			_floor_y[str(row.id)] = GameBoot.b2g([0.0, 0.0, float(row.get("z", 0.0))]).y
	var tag := RegEx.new()
	tag.compile("^(B1|F0[0-9]|ROOF)_")
	var count := 0
	for child in blockout.get_children():
		var found := tag.search(str(child.name))
		if found == null or not _floor_y.has(found.get_string(1)):
			continue
		var storey := found.get_string(1)
		var list: Array = _casters.get(storey, [])
		for drawn: GeometryInstance3D in child.find_children("*", "GeometryInstance3D", true, false):
			if drawn.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				continue
			list.append([drawn, drawn.cast_shadow])
			count += 1
		_casters[storey] = list
	print("[STOREY SHADOWS] %d casters on %d storeys" % [count, _casters.size()])
	_update(true)
	return count


func storey_at(y: float) -> String:
	var best := ""
	for storey: String in ORDER:
		if _floor_y.has(storey) and y + 0.3 >= float(_floor_y[storey]):
			best = storey
	return best if not best.is_empty() else ORDER[0]


func _process(delta: float) -> void:
	_since += delta
	if _since >= CHECK_EVERY:
		_since = 0.0
		_update(false)


func _update(force: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	var storey := storey_at(player.global_position.y)
	if storey == _current and not force:
		return
	_current = storey
	switches += 1
	var here := ORDER.find(storey)
	for name: String in _casters:
		var near := absi(ORDER.find(name) - here) <= 1
		for pair: Array in _casters[name]:
			var drawn := pair[0] as GeometryInstance3D
			if is_instance_valid(drawn):
				drawn.cast_shadow = (int(pair[1]) as GeometryInstance3D.ShadowCastingSetting) if near else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Everything casts as it did before, e.g. for a capture or when the world is torn down.
func restore() -> void:
	for name: String in _casters:
		for pair: Array in _casters[name]:
			var drawn := pair[0] as GeometryInstance3D
			if is_instance_valid(drawn):
				drawn.cast_shadow = int(pair[1]) as GeometryInstance3D.ShadowCastingSetting
	_current = ""


func _exit_tree() -> void:
	restore()
