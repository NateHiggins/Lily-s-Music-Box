class_name WatchStationNetwork
extends Node
## Collects the marks a round's signal boxes have made. Nothing more.
##
## SR7-J ships ONE station. This exists so the second one is a line in
## `WatchStationProp.STATIONS` and a placement rather than a rewrite, and so
## the question "which stations were worked tonight" has one place to be asked
## instead of a caller walking the scene tree.
##
## WHAT IT DELIBERATELY IS NOT.
##
##   * NOT a save owner. The marks live in memory for the session and are gone
##     on reload. A watchman's boxes are reset every morning and the register
##     end keeps the tape; this building has no tape yet, and inventing a save
##     key for one would be inventing the evidence.
##   * NOT a route. It records the order marks arrived because that is a fact,
##     but it declares no expected order, no next station and no completion.
##     Nothing here can be missed.
##   * NOT a lifecycle owner. No `WorkOrders`, no `RealityCases`, no job, no
##     case, no objective. It never touches the props it listens to.
##
## It is a listener with a list.

## Re-emitted so one consumer can watch the whole round instead of every box.
## The record is passed through untouched.
signal station_marked(station_id: String, mark_record: Dictionary)

var _stations: Dictionary = {}
var _marks: Array[Dictionary] = []


## Adopt a box. Idempotent, so a rebuild or a double-bind costs nothing.
func register(station: Node) -> bool:
	if station == null or not station.has_signal("station_marked"):
		return false
	var id := str(station.get("station_id"))
	if id == "" or _stations.has(id):
		return false
	_stations[id] = station
	station.station_marked.connect(_on_station_marked)
	return true


func station_ids() -> Array:
	return _stations.keys()


func station_count() -> int:
	return _stations.size()


func marks() -> Array[Dictionary]:
	return _marks.duplicate(true)


func mark_count() -> int:
	return _marks.size()


func marked_stations() -> Array[String]:
	var out: Array[String] = []
	for record in _marks:
		var id := str(record.get("station_id", ""))
		if id != "" and id not in out:
			out.append(id)
	return out


func has_mark(id: String) -> bool:
	return id in marked_stations()


## The record for a station, or {} -- the FIRST one, because a box's lock-out
## pawl means there should never be a second and a network that quietly kept
## the latest would hide a box that had been worked twice.
func mark_for(id: String) -> Dictionary:
	for record in _marks:
		if str(record.get("station_id", "")) == id:
			return record.duplicate(true)
	return {}


func clear_marks() -> void:
	_marks.clear()


func _on_station_marked(id: String, record: Dictionary) -> void:
	_marks.append(record.duplicate(true))
	station_marked.emit(id, record.duplicate(true))
