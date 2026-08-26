class_name WatchStationNetwork
extends Node
## Collects the marks a round's signal boxes have made. Nothing more.
##
## SR7-J ships ONE station. This exists so the second one is a line in
## `WatchStationProp.STATIONS` and a placement rather than a rewrite, and so
## the question "which stations were worked tonight" has one place to be asked
## instead of a caller walking the scene tree.
##
## SR7-K MADE IT THE WIRE AS WELL, and that is the whole of the increment.
##
## The station emits a fact. This carries it. The receiver displays it. Those
## are three different things and the difference between them is the point:
##
##   * `marks()` is every fact a station handed over. It is the STATION'S
##     truth, mechanical and local, and nothing that happens to a wire can
##     take one back.
##   * `delivered()` is the subset the circuit actually carried to a receiver.
##
## On a closed line those two agree. On an OPEN line they do not, and the gap
## between them is exactly what an open circuit costs you: the box's drop is
## down and truthful, and the lobby knows nothing about it.
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
## Raised when the circuit condition changes. Nothing here acts on it; the
## receiver watches its own line so a board with no network still reads OPEN.
signal line_condition_changed(closed: bool)

## SR7-L. The guard that holds the tour key, if the building has one. The
## network does not own custody -- it knows where to ask, which is the narrow
## contract a station needs and nothing wider.
var _key_guard: Node
var _stations: Dictionary = {}
var _marks: Array[Dictionary] = []
var _delivered: Array[Dictionary] = []
var _receiver: Node
## The watchman's circuit is a CLOSED-CIRCUIT line: healthy is closed, and a
## break is the abnormal condition the board is supposed to show. Nothing in
## this file ever closes it on its own -- a wire that repaired itself would be
## the one thing worse than a wire that broke.
var line_closed := true


## Adopt a box. Idempotent, so a rebuild or a double-bind costs nothing.
func register(station: Node) -> bool:
	if station == null or not station.has_signal("station_marked"):
		return false
	var id := str(station.get("station_id"))
	if id == "" or _stations.has(id):
		return false
	_stations[id] = station
	station.station_marked.connect(_on_station_marked)
	# SR7-L: hand the box the line it is on, so it can ask about the key.
	if station.has_method("bind_line"):
		station.call("bind_line", self)
	return true


## Adopt the central receiver. One per network: a second board on the same
## line would be a second answer to the same question.
func attach_receiver(receiver: Node) -> bool:
	if receiver == null or not receiver.has_method("receive_signal"):
		return false
	if _receiver != null and is_instance_valid(_receiver):
		return false
	_receiver = receiver
	if receiver.has_method("set_line_closed"):
		receiver.call("set_line_closed", line_closed)
	return true


## SR7-L -- WHO HOLDS THE KEY QUESTION. The guard owns custody; this only
## carries the question to it, so a station never has to find a guard in the
## scene tree and a building with no guard answers honestly.
func attach_key_guard(guard: Node) -> bool:
	if guard == null or not guard.has_method("key_carried"):
		return false
	if _key_guard != null and is_instance_valid(_key_guard):
		return false
	_key_guard = guard
	return true


func has_key_guard() -> bool:
	return _key_guard != null and is_instance_valid(_key_guard)


func key_guard() -> Node:
	return _key_guard if has_key_guard() else null


## Whether the tour key is off its hook. A building with NO guard answers
## false -- which is the SR7-J condition, and the honest one: a station cannot
## be worked with a key that does not exist.
func tour_key_carried() -> bool:
	if not has_key_guard():
		return false
	return bool(_key_guard.call("key_carried"))


func has_receiver() -> bool:
	return _receiver != null and is_instance_valid(_receiver)


func receiver() -> Node:
	return _receiver if has_receiver() else null


## Open or close the line. A break is a fact about the building, not about the
## station: the box goes on working perfectly with the wire cut.
func set_line_closed(closed: bool) -> bool:
	if line_closed == closed:
		return false
	line_closed = closed
	if has_receiver() and _receiver.has_method("set_line_closed"):
		_receiver.call("set_line_closed", closed)
	line_condition_changed.emit(closed)
	return true


func station_ids() -> Array:
	return _stations.keys()


func station_count() -> int:
	return _stations.size()


func marks() -> Array[Dictionary]:
	return _marks.duplicate(true)


func mark_count() -> int:
	return _marks.size()


## The facts the CIRCUIT carried. On an open line this stays behind `marks()`,
## and the difference is the honest cost of the break.
func delivered() -> Array[Dictionary]:
	return _delivered.duplicate(true)


func delivered_count() -> int:
	return _delivered.size()


## Facts a station made that the wire never carried. Nothing consumes this; it
## exists so the gap has a name.
func undelivered_count() -> int:
	return _marks.size() - _delivered.size()


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
	_delivered.clear()


## THE WIRE. The fact is recorded and re-emitted whatever the line is doing --
## it happened, and a broken circuit does not unhappen it. Only the DELIVERY
## is conditional, because delivery is the thing a wire is for.
func _on_station_marked(id: String, record: Dictionary) -> void:
	_marks.append(record.duplicate(true))
	if line_closed and has_receiver():
		if bool(_receiver.call("receive_signal", record.duplicate(true))):
			_delivered.append(record.duplicate(true))
	station_marked.emit(id, record.duplicate(true))
